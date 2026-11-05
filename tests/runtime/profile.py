"""Relative paint costs of the production shell under the software renderer (docs/STATUS.md).

Not a pass/fail suite. Run under headless Sway with the audio session:
  dbus-run-session -- bash dev/headless.sh bash dev/audio-session.sh python tests/runtime/profile.py [label]
Writes artifacts/profile-<label>.json. Times are wall-clock milliseconds on this machine;
compare runs on the same machine only. `responsive` is when an IPC round trip (served on the
GUI thread) first returns after the action, so it includes any paint that blocks the thread.
"""
import json
import os
import re
import subprocess as sp
import sys
import time
from pathlib import Path

ROOT = Path('/project')
OUT = ROOT / 'artifacts'
label = sys.argv[1] if len(sys.argv) > 1 else 'current'
path = str(ROOT / 'quickshell/shell.qml')
log = OUT / f'profile-{label}.log'


def ipc(*args, timeout=30):
    return sp.run(['quickshell', 'ipc', '-p', path, 'call', 'shell', *args], text=True,
                  capture_output=True, timeout=timeout).stdout


def status():
    try:
        return json.loads(ipc('status'))
    except (json.JSONDecodeError, sp.TimeoutExpired):
        return None


def until(predicate, seconds=30):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(.02)
    raise AssertionError('timeout')


def paints(since):
    rows = [line for line in log.read_text().splitlines()[since:] if 'illuminated-profile paint' in line]
    total = sum(int(m[1]) + int(m[2]) for m in (re.search(r'ensure=(\d+) paint=(\d+)', r) for r in rows) if m)
    kinds = {}
    for r in rows:
        m = re.search(r'paint (\S+) (\d+x\d+) ensure=(\d+) paint=(\d+)', r)
        if m:
            k = kinds.setdefault(m[1], [0, 0])
            k[0] += 1
            k[1] += int(m[3]) + int(m[4])
    return {'paints': len(rows), 'paintMs': total, 'byKind': kinds}


def lines():
    return len(log.read_text().splitlines())


def alive():
    found = re.findall(r'illuminated-profile alive (\d+)', log.read_text())
    return int(found[-1]) if found else 0


def measure(name, action, done):
    mark = lines()
    start = time.monotonic()
    action()
    until(done)
    responsive = (time.monotonic() - start) * 1000
    time.sleep(1.5)   # let deferred paints land
    results[name] = {'responsiveMs': round(responsive), **paints(mark)}


results = {}
with log.open('w') as f:
    start = time.monotonic()
    process = sp.Popen(['quickshell', '-p', path, '--no-duplicate'], stdout=f, stderr=sp.STDOUT,
                       env={**os.environ, 'ILLUMINATED_PROFILE': '1'})
    try:
        until(lambda: (s := status()) and s.get('ready'), 60)
        results['startup'] = {'responsiveMs': round((time.monotonic() - start) * 1000)}
        time.sleep(3)
        results['startup'].update(paints(0))
        results['idleCanvasAlive'] = alive()
        measure('firstLauncherOpen', lambda: ipc('toggleLauncher'), lambda: (s := status()) and s['launcherOpen'])
        ipc('hide'); time.sleep(1)
        measure('firstHandDeal', lambda: ipc('cards', 'levels'), lambda: (s := status()) and s['artifacts'] == 'levels')
        results['handCanvasAlive'] = alive()
        mark = lines()
        t = time.monotonic()
        for i in range(20):   # a 2-second volume drag, 10 steps up and 10 down
            ipc('volume', '0.02' if i < 10 else '-0.02')
            time.sleep(max(0, t + (i + 1) * .1 - time.monotonic()))
        until(status)
        results['volumeDrag2s'] = {'wallMs': round((time.monotonic() - t) * 1000), **paints(mark)}
        ipc('hide'); time.sleep(1)
        results['idleCanvasAliveAfter'] = alive()
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except sp.TimeoutExpired:
            process.kill()
(OUT / f'profile-{label}.json').write_text(json.dumps(results, indent=1))
print(json.dumps({k: ({kk: vv for kk, vv in v.items() if kk != 'byKind'} if isinstance(v, dict) else v) for k, v in results.items()}, indent=1))
