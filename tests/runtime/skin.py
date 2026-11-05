"""QML skins (docs/SKINS.md) on the production rail and dock, under headless Sway with the
private PipeWire session: the default skin's objects, pointer clicks, scrolls and hover tags on
them, the example skin laid over it by `illuminated apply`, a one-file override, and an
old-format skin that is ignored."""
import json, os, pathlib, shutil, subprocess as sp, tempfile, time
ROOT = pathlib.Path('/project'); OUT = ROOT / 'artifacts' / 'development'; OUT.mkdir(parents=True, exist_ok=True)
POINTER = str(ROOT / 'tests/runtime/native/pointer')


def run(*args, env=None):
    r = sp.run(args, capture_output=True, text=True, timeout=20, env=env)
    assert r.returncode == 0, str(args) + '\n' + r.stdout + r.stderr
    return r.stdout.strip()


def wait(check, why, seconds=15):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        try:
            if check(): return
        except (json.JSONDecodeError, AssertionError, sp.TimeoutExpired):
            pass
        time.sleep(.1)
    raise AssertionError(why)


def session(name, skin=None, extra=None, config=''):
    """A temporary home whose config applies `skin` (a folder copied in as the user's skin), and
    a running test entry. Returns (ipc, log, process, apply output)."""
    home = pathlib.Path(tempfile.mkdtemp()) / name
    cfg = home / 'qml'; shutil.copytree(ROOT / 'quickshell', cfg); shutil.copy(ROOT / 'tests/runtime/skin.qml', cfg / 'skin-test.qml')
    conf = home / 'config' / 'illuminated'; conf.mkdir(parents=True)
    (conf / 'config.toml').write_text(config)
    if skin:
        shutil.copytree(skin, conf / 'skin')
        for f, text in (extra or {}).items(): (conf / 'skin' / f).write_text(text)
    env = {**os.environ, 'XDG_CONFIG_HOME': str(home / 'config'), 'XDG_STATE_HOME': str(home / 'state'), 'ILLUMINATED_CONFIG': str(cfg)}
    applied = run('python3', str(ROOT / 'scripts/illuminated'), 'apply', env=env)
    log = OUT / f'skin-{name}.log'
    process = sp.Popen(['quickshell', '-p', str(cfg / 'skin-test.qml')], stdout=log.open('w'), stderr=sp.STDOUT, env=env)
    path = str(cfg / 'skin-test.qml')
    def ipc(method, *args): return run('quickshell', 'ipc', '-p', path, 'call', 'skin', method, *map(str, args), env=env)
    wait(lambda: 'Configuration Loaded' in log.read_text() or process.poll() is not None, 'load')
    assert process.poll() is None, log.read_text()
    return ipc, log, process, applied


def where(ipc, name):
    return json.loads(ipc('where', name))


def stop(process, log):
    process.terminate(); process.wait(timeout=5)
    bad = [l for l in log.read_text().splitlines() if 'scene' in l and any(t in l for t in ('TypeError', 'ReferenceError', 'is not a type', 'Binding loop', 'not found'))]
    assert not bad, '\n'.join(bad)


# 1. The default skin: every rail object, a click, a scroll and a hover.
ipc, log, process, _ = session('default')
try:
    for name in ('tray', 'nib', 'vial', 'antenna', 'matchbox', 'paper', 'paperclip'):
        wait(lambda: where(ipc, name), f'{name} on the rail')
    assert where(ipc, 'converter') is None, 'no battery here: the converter is hidden'
    run('grim', str(OUT / 'skin-default-rail.png'))
    wait(lambda: json.loads(ipc('state'))['available'], 'PipeWire sink')
    v = where(ipc, 'vial')
    # Hover lasts while the virtual pointer exists: hold it there while asking.
    holder = sp.Popen([POINTER, '1280', '720', 'move', str(round(v['x'])), str(round(v['y'])), 'wait', '6000'])
    try:
        wait(lambda: json.loads(ipc('state'))['tag'] == 'Levels', 'hover shows the vial\'s tag')
        assert where(ipc, 'vial')['hovered']
    finally:
        holder.kill(); holder.wait()
    before = json.loads(ipc('state'))['volume']
    run(POINTER, '1280', '720', 'move', str(round(v['x'])), str(round(v['y'])), 'scroll', '10')
    wait(lambda: json.loads(ipc('state'))['volume'] < before - .03, 'scrolling down on the vial lowers the volume (PipeWire virtual sink)')
    run(POINTER, '1280', '720', 'move', str(round(v['x'])), str(round(v['y'])), 'down', 'up')
    wait(lambda: json.loads(ipc('state'))['group'] == 'levels' and json.loads(ipc('state'))['phase'] > .999, 'a click on the vial deals Levels')
    run('grim', str(OUT / 'skin-levels-hand.png'))
    ipc('close')
    print('PASS: default QML skin: rail objects present, hover tag, scroll changes the volume, click deals Levels', flush=True)
finally:
    stop(process, log)

# 2. The example skin over the default: the seal deals Desk, with the skin's own card.
ipc, log, process, _ = session('example', ROOT / 'quickshell/skins/example', config='[dock]\nmode = "permanent"\n[features]\nnotifications = true\n')
try:
    wait(lambda: where(ipc, 'seal'), 'the example seal replaces the tray mark')
    assert where(ipc, 'tray') is not None, 'the tray mark is on the paper now'
    assert where(ipc, 'vial') is not None and where(ipc, 'quiet') is not None, 'default objects stay; the dock gets a button'
    s = where(ipc, 'seal')
    run(POINTER, '1280', '720', 'move', str(round(s['x'])), str(round(s['y'])), 'down', 'up')
    wait(lambda: json.loads(ipc('state'))['group'] == 'desk' and json.loads(ipc('state'))['phase'] > .999, 'the seal deals the Desk hand')
    st = json.loads(ipc('state'))
    assert st['kinds'] == ['skin:inkwell', 'volume'], st['kinds']
    wait(lambda: json.loads(ipc('state'))['cork'], 'the skin card renders its face')
    run('grim', str(OUT / 'skin-example-desk.png'))
    ipc('close')
    q = where(ipc, 'quiet'); dnd = json.loads(ipc('state'))['dnd']
    run(POINTER, '1280', '720', 'move', str(round(q['x'])), str(round(q['y'])), 'down', 'up')
    wait(lambda: json.loads(ipc('state'))['dnd'] != dnd, 'the dock button toggles Do Not Disturb')
    print('PASS: example skin laid over the default: seal deals a hand with the skin card; dock button', flush=True)
finally:
    stop(process, log)

# 3. One file overridden: only that object changes.
mine = (ROOT / 'quickshell/skins/default/Vial.qml').read_text().replace('size: [17, 9]', 'size: [17, 9]\n    property bool mine: true')
ipc, log, process, _ = session('override', ROOT / 'tests/runtime/empty-skin', {'Vial.qml': mine})
try:
    wait(lambda: where(ipc, 'vial') and where(ipc, 'vial')['mine'], 'the user Vial.qml replaces the vial')
    for name in ('tray', 'nib', 'antenna', 'matchbox', 'paper'):
        w = where(ipc, name)
        assert w is not None and not w['mine'], f'{name} still comes from the default skin'
    print('PASS: a one-file override replaces only that object', flush=True)
finally:
    stop(process, log)

# 4. An old-format skin is ignored, with a warning, and the default stands.
ipc, log, process, applied = session('old', ROOT / 'tests/runtime/empty-skin', {'skin.json': '{"elements": {"nib": {}}, "rail": {"items": []}}', 'Rail.qml': 'import QtQuick\nItem {}\n'})
try:
    assert 'old skin format' in applied, applied
    wait(lambda: where(ipc, 'nib') and where(ipc, 'tray'), 'the default skin stands in')
    wait(lambda: 'old skin format' in log.read_text(), 'the shell warns too')
    print('PASS: an old-format skin warns (apply and shell) and the default skin is used', flush=True)
finally:
    process.terminate(); process.wait(timeout=5)
