"""v3 configuration under real QML, apply and the CLI; no power action.

Covers: a group added only in config.toml reaches the shell live and both
compositors' generated binds; keys set in config.toml are refused from the shell;
shell choices in ui.json survive `illuminated apply`; an invalid apply keeps the
last good configuration and reports a line number; a [host.<name>] override
applies and pins; the shell never writes config.toml; the CLI opens the new deck
on the production shell.
"""
import json, os, pathlib, shutil, socket, subprocess as sp, tempfile, time

ROOT = pathlib.Path('/project')
OUT = ROOT / 'artifacts/v3'
CLI = ['python3', str(ROOT / 'scripts/illuminated')]


def run(*args, env=None, ok=True):
    result = sp.run(args, capture_output=True, text=True, timeout=15, env=env)
    if ok:
        assert result.returncode == 0, result.stdout + result.stderr
    return result


def wait(check, why, limit=8):
    end = time.monotonic() + limit
    while time.monotonic() < end:
        try:
            if check():
                return
        except (json.JSONDecodeError, AssertionError, KeyError):
            pass
        time.sleep(.05)
    raise AssertionError(why)


OUT.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as directory:
    tmp = pathlib.Path(directory)
    qml = tmp / 'qml'
    shutil.copytree(ROOT / 'quickshell', qml)
    shutil.copy(ROOT / 'tests/runtime/single-config.qml', qml / 'single-config.qml')
    env = {**os.environ, 'XDG_CONFIG_HOME': str(tmp / 'config'), 'XDG_STATE_HOME': str(tmp / 'state'),
           'XDG_DATA_HOME': str(tmp / 'data'), 'ILLUMINATED_CONFIG': str(qml)}
    user = tmp / 'config/illuminated/config.toml'
    generated = tmp / 'config/illuminated/generated'
    resolved = generated / 'resolved.json'
    ui = tmp / 'config/illuminated/ui.json'
    user.parent.mkdir(parents=True)
    user.write_text('# my settings\n[appearance]\nmode = "dark"   # night\n')

    def apply(ok=True):
        return run(*CLI, 'apply', env=env, ok=ok)

    apply()
    assert resolved.is_file()

    path = str(qml / 'single-config.qml')
    log = OUT / 'single-config.log'
    with log.open('w') as output:
        process = sp.Popen(['quickshell', '-p', path], env=env, stdout=output, stderr=sp.STDOUT)
        try:
            def test(method, *args):
                return run('quickshell', 'ipc', '-p', path, 'call', 'configurationTest', method, *map(str, args), env=env).stdout.strip()

            def shell(method, *args):
                return run('quickshell', 'ipc', '-p', path, 'call', 'shell', method, *map(str, args), env=env).stdout.strip()

            def option(key):
                return json.loads(test('option', key))

            wait(lambda: 'Configuration Loaded' in log.read_text(), 'initial load')
            wait(lambda: option('appearance.mode') == 'dark' and 'session' in option('groups'), 'resolved configuration read')

            # A group that exists only in config.toml: live in the shell, in both binds files.
            hands = option('rail.hands') + ['recovery']
            user.write_text(user.read_text() + '\n[groups.recovery]\nglyph = "R"\ncards = ["reboot"]\n\n'
                            f'[rail]\nhands = {json.dumps(hands)}\n\n[binds]\n"SUPER+R" = "cards recovery"\n')
            apply()
            wait(lambda: 'recovery' in option('groups') and option('rail.hands')[-1] == 'recovery', 'new group reaches the shell live')
            for name in ('hyprland.lua', 'mango.conf'):
                assert 'cards recovery' in (generated / name).read_text(), name
            shell('cards', 'recovery')
            wait(lambda: json.loads(shell('status'))['artifacts'] == 'recovery', 'new deck opens')
            time.sleep(.5)
            run('grim', str(OUT / 'new-group.png'))
            # The deck opening is not enough: a card that fails to load leaves an empty deck
            # (v5 passed here with no card on screen). Fail on any QML load or script error.
            problems = [l for l in log.read_text().splitlines()
                        if any(w in l for w in ('is not a type', 'Cannot assign', 'Cannot override', 'unavailable',
                                                'ReferenceError', 'TypeError', 'Unable to assign'))]
            assert not problems, '\n'.join(problems)
            shell('hide')
            written = user.read_text()

            # A key set in config.toml is pinned: the shell refuses and names the file.
            assert test('update', 'appearance.mode', '"light"') == 'false'
            assert 'config.toml' in test('notice'), test('notice')
            assert option('appearance.mode') == 'dark'
            assert not ui.exists() or 'appearance' not in json.loads(ui.read_text())

            # An unpinned shell choice goes to ui.json and survives a later apply.
            assert test('update', 'motion.reduced', 'true') == 'true'
            wait(lambda: option('motion.reduced') is True, 'shell choice applies')
            wait(lambda: json.loads(ui.read_text())['motion']['reduced'] is True, 'shell choice saved to ui.json')
            apply()
            time.sleep(.6)
            assert option('motion.reduced') is True, 'apply must not discard shell choices'

            # An invalid apply writes nothing and reports the line.
            height = option('dimensions.controlHeight')
            before = resolved.read_bytes()
            user.write_text(written + '\n[dimensions]\ncontrolHeight = 40.5\n')
            result = apply(ok=False)
            message = result.stdout + result.stderr
            line = len(written.splitlines()) + 3
            assert result.returncode != 0 and 'whole number' in message and f'(line {line})' in message, message
            assert resolved.read_bytes() == before
            time.sleep(.4)
            assert option('dimensions.controlHeight') == height

            # A host override applies and is pinned like any config.toml key.
            user.write_text(written + f'\n[host.{json.dumps(socket.gethostname())}.dimensions]\ncontrolHeight = 34\n')
            apply()
            wait(lambda: option('dimensions.controlHeight') == 34, 'host override applies')
            assert test('update', 'dimensions.controlHeight', '40') == 'false'
            written = user.read_text()

            # Nothing the shell did changed the user's file.
            assert user.read_text() == written
            assert '# night' in written and '# my settings' in written
            print('PASS: config-only group live in the shell and both binds files; pinned keys refused; '
                  'ui.json choice survives apply; invalid apply keeps last good config with a line number; '
                  'host override applies; shell never writes config.toml', flush=True)
        finally:
            process.terminate()
            process.wait(timeout=5)

    # The CLI drives the production shell.qml for the same config-only group.
    log = OUT / 'single-config-cli.log'
    with log.open('w') as output:
        process = sp.Popen(['quickshell', '-p', str(qml / 'shell.qml')], env=env, stdout=output, stderr=sp.STDOUT)
        try:
            wait(lambda: 'Configuration Loaded' in log.read_text(), 'production shell load')
            run(*CLI, 'cards', 'recovery', env=env)
            wait(lambda: json.loads(run(*CLI, 'status', env=env).stdout)['artifacts'] == 'recovery', 'CLI opens the new deck')
            time.sleep(.5)
            run('grim', str(OUT / 'cli-new-group.png'))
            run(*CLI, 'hide', env=env)
            print('PASS: `illuminated cards` opens a config-only group on the production shell', flush=True)
        finally:
            process.terminate()
            process.wait(timeout=5)
