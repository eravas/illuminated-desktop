"""Real Quickshell/Wayland tests; no service or compositor mocks."""
import json
import os
import shutil
import tempfile
from pathlib import Path
import subprocess as sp
import time

ROOT = Path('/project')
OUT = ROOT / 'artifacts'

def command(*args):
    result = sp.run(args, text=True, stdout=sp.PIPE, stderr=sp.STDOUT)
    assert result.returncode == 0, str(args) + "\n" + result.stdout
    return result.stdout

def wait(predicate, message, seconds=8):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if predicate():
            return
        time.sleep(.1)
    raise AssertionError(message)

def capture(name):
    result = sp.run(["grim", str(OUT / name)], capture_output=True, text=True)
    (OUT / (name + ".txt")).write_text(result.stdout + result.stderr)
    if result.returncode:
        print("NOT CAPTURED:", name, result.stderr.strip(), flush=True)

def tree():
    return command('swaymsg', '-t', 'get_tree')

def run_entry(entry, check, config=ROOT / "quickshell", suffix=""):
    path = str(config / entry)
    log = OUT / (entry + suffix + '.log')
    with log.open('w') as f:
        process = sp.Popen(['quickshell', '-p', path, '--no-duplicate'], stdout=f, stderr=sp.STDOUT,
                           env={**os.environ, 'WAYLAND_DEBUG': '1', **({'ILLUMINATED_SETTINGS': str(config/'fixture-preferences.json')} if (config/'fixture-preferences.json').exists() else {})})
        try:
            wait(lambda: 'Configuration Loaded' in log.read_text() or process.poll() is not None, 'load timeout')
            assert process.poll() is None, log.read_text()
            check(path, log, process)
            text = log.read_text()
            errors = [line for line in text.splitlines() if 'ERROR' in line
                      and 'Network will not work. Could not find an available backend.' not in line
                      and 'Failed to create pipewire context.' not in line
                      and 'Failed to connect pipewire context. Errno: 112' not in line]
            assert not errors and 'TypeError:' not in text and 'ReferenceError:' not in text and 'is not a type' not in text and not any('scene' in line and 'unavailable' in line for line in text.splitlines()), "\n".join(errors) or text
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except sp.TimeoutExpired:
                process.kill(); process.wait()
    print('PASS:', entry, flush=True)

def panel(path, log, process):
    wait(lambda: 'get_layer_surface' in log.read_text(), 'panel surface not created')

def shell(path, log, process):
    def ipc(*operation):   # through the `illuminated` wrapper, as a keybind would
        result = sp.run(['python3', str(ROOT / 'scripts/illuminated'), *operation], env={**os.environ, 'ILLUMINATED_CONFIG': str(Path(path).parent)}, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
    def status():
        return json.loads(command('quickshell', 'ipc', '-p', path, 'call', 'shell', 'status'))
    import re as _re
    def layer_surfaces(namespace):   # (created, destroyed) layer surfaces of a namespace so far
        # Wayland reuses object ids, so a destroy counts only after its own creation.
        text = log.read_text(); made = gone = 0
        for m in _re.finditer(r'new id zwlr_layer_surface_v1#(\d+),[^\n]*"' + namespace + '"', text):
            made += 1
            nxt = _re.search(r'zwlr_layer_surface_v1#' + m.group(1) + r'\.destroy\(\)', text[m.end():])
            gone += nxt is not None
        return made, gone
    def launcher_surfaces(): return layer_surfaces('illuminated-launcher')
    for _ in range(3):
        before = launcher_surfaces()[0]
        ipc('launcher')
        wait(lambda: launcher_surfaces()[0] > before, 'launcher not reopened')
        command('wtype', '-s', '150', '-k', 'Escape')
        # Closed means the surface is gone (after the closing animation), not a fixed delay.
        wait(lambda: launcher_surfaces()[1] == launcher_surfaces()[0], 'Escape did not close the launcher')
    # A hand opened over IPC; hide dismisses it. (Replaces the v2 Controls window probe.)
    ipc('cards', 'levels')
    wait(lambda: status()['artifacts'] == 'levels', 'cards IPC did not deal a hand')
    capture('shell-hand.png')
    ipc('hide')
    wait(lambda: status()['artifacts'] == '', 'hide did not dismiss the hand')
    # Until the hand has retracted its surface keeps the keyboard; Sway does not pass the focus to
    # a layer surface mapped meanwhile (Inspiron checklist: launcher right after a hand).
    wait(lambda: layer_surfaces('illuminated-cards')[0] == layer_surfaces('illuminated-cards')[1], 'the hand did not retract')
    # Duplicate start must exit while the original remains alive.
    sp.run(['quickshell', '-p', path, '--no-duplicate'], timeout=5, check=True, capture_output=True)
    assert process.poll() is None
    # hide also closes the launcher without stopping the shell.
    ipc('launcher')
    wait(lambda: status()['launcherOpen'], 'launcher did not open for hide')
    ipc('hide')
    wait(lambda: not status()['launcherOpen'], 'hide did not close the launcher')
    assert process.poll() is None
    # Real virtual-output discovery/removal exercises production Variants/PanelWindow.
    # v7: the rail (and its reservation) replaces the bar on every output.
    before = log.read_text().count('"illuminated-rail"')
    command('swaymsg', 'create_output')
    wait(lambda: log.read_text().count('"illuminated-rail"') == before + 1, 'rail not created on new output')
    import re
    surface = re.findall(r'new id zwlr_layer_surface_v1#(\d+).*"illuminated-rail"', log.read_text())[-1]
    command('swaymsg', 'output HEADLESS-2 disable')
    wait(lambda: 'HEADLESS-2' not in command('swaymsg', '-t', 'get_outputs', '-r') or not any(o['active'] for o in json.loads(command('swaymsg', '-t', 'get_outputs', '-r')) if o['name'] == 'HEADLESS-2'), 'output not disabled')
    wait(lambda: 'zwlr_layer_surface_v1#' + surface + '.destroy()' in log.read_text(), 'removed output retained its rail surface')
    assert 'set_exclusive_zone(72)' in log.read_text()   # rail reservation: inset 3 + 64 + 5
    # A safe real desktop entry writes a marker. Search/Enter executes it, once the launcher has
    # the keyboard (keys typed before the compositor's enter event are lost).
    def launcher_focused():
        text = log.read_text()
        made = list(_re.finditer(r'new id zwlr_layer_surface_v1#\d+, (wl_surface#\d+),[^\n]*"illuminated-launcher"', text))
        return bool(made) and _re.search(r'wl_keyboard#\d+\.enter\(\d+, ' + made[-1].group(1) + r'\b', text[made[-1].end():]) is not None
    # Sway leaves seat focus on the output just disabled; give it back to the remaining one, or
    # no layer surface gets the keyboard.
    command('swaymsg', 'focus output HEADLESS-1')
    ipc('launcher')
    wait(launcher_focused, 'launcher took the keyboard', seconds=25)   # after output hotplug: new chrome paints first
    command('wtype', '-s', '150', 'Illuminated Integration Probe')
    command('wtype', '-s', '150', '-k', 'Return')
    wait(lambda: (OUT / 'launched').exists(), 'desktop application not executed')

OUT.mkdir(exist_ok=True)
(OUT / 'launched').unlink(missing_ok=True)
apps = Path.home() / '.local/share/applications'
apps.mkdir(parents=True, exist_ok=True)
(apps / 'illuminated-test.desktop').write_text('[Desktop Entry]\nType=Application\nName=Illuminated Integration Probe\nExec=/usr/bin/touch /project/artifacts/launched\n')
for entry, check in [('chrome-entry.qml', panel), ('launcher.qml', panel), ('shell.qml', shell)]:
    run_entry(entry, check)
# Quickshell deliberately blackholes imports outside its configuration root.
fixture_temp = tempfile.TemporaryDirectory()
fixture_config = Path(fixture_temp.name) / "config"
shutil.copytree(ROOT / "quickshell", fixture_config)
for fixture in ("commands.qml", "features.qml"):
    shutil.copy(ROOT / "tests/runtime" / fixture, fixture_config / fixture)
result = sp.run(['quickshell', '-p', str(fixture_config / 'commands.qml')], capture_output=True, text=True, timeout=15)
(OUT / 'commands.log').write_text(result.stdout + result.stderr)
assert result.returncode == 0 and 'PASS: native command lifecycle' in result.stdout + result.stderr and 'FAIL:' not in result.stdout + result.stderr, result.stdout + result.stderr
print('PASS: native command lifecycle', flush=True)

# Disabled features must not instantiate their windows; IPC remains safe.
for feature in ("Rail", "Launcher", "Cards"):
    with tempfile.TemporaryDirectory() as temp:
        config = Path(temp) / "config"
        shutil.copytree(ROOT / "quickshell", config)
        (config/'fixture-preferences.json').write_text(json.dumps({'features':{feature[0].lower()+feature[1:]:False}}))
        def disabled(path, log, process):
            for call in (("toggleLauncher",), ("cards", "levels"), ("hide",)):
                command("quickshell", "ipc", "-p", path, "call", "shell", *call)
            text = log.read_text()
            namespace = {"Rail": "illuminated-rail", "Launcher": "illuminated-launcher", "Cards": "illuminated-cards"}[feature]
            assert '"' + namespace + '"' not in text
        run_entry("shell.qml", disabled, config, "-disabled-" + feature)

def features(path, log, process):
    def ipc(method):
        return command('quickshell', 'ipc', '-p', path, 'call', 'test', method).strip()
    def state():
        return json.loads(ipc('state'))
    assert state()['launcher'] is False
    ipc('showLauncher')
    wait(lambda: state()['launcher'], 'launcher show')
    command('wtype', '-s', '150', 'NoApplicationCanMatchThisUniqueQuery')
    wait(lambda: state()['matches'] == 0, 'search not filtered')
    command('wtype', '-s', '150', '-k', 'Return')
    assert state()['launcher'], 'empty result Enter must not dismiss'
    command('wtype', '-s', '150', '-k', 'Escape')
    wait(lambda: not state()['launcher'], 'Escape did not hide')
    ipc('showLauncher')
    wait(lambda: state()['matches'] > 0, 'search not reset on reopening')
    command('wtype', '-s', '150', '-k', 'Escape')
run_entry('features.qml', features, fixture_config)
fixture_temp.cleanup()
