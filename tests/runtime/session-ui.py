"""Session deck (Sleep, Shut Down, Reboot) on deployed cards with real Wayland input; harmless commands only.

At 1280x720 and 1366x768:
- the deck fits on one page;
- Shut Down turns on a click to "Confirm?"; a click before the arming delay is ignored;
  Escape, a click on the desk and the confirmation timeout each turn it back, and
  nothing runs;
- Reboot confirms with a second click once armed, and the deck closes;
- Sleep turns to Sleep / Lock / Log Out with nothing pending; Log Out confirms inline
  ("Log out?"), expires back to "Log Out", and runs on an armed second click; Lock
  runs at once; Sleep locks, then suspends.
Then the locker guard: with commands.lockReturnsWhenReady off, Sleep is refused and a
locker that runs until unlock is never killed by the 15-second command limit.
"""
import json, pathlib, shutil, subprocess as sp, tempfile, time

ROOT = pathlib.Path('/project')
OUT = ROOT / 'artifacts/v3'
DEV = ROOT / 'artifacts/development'
MARKERS = ('lock', 'logout', 'suspend', 'reboot', 'poweroff')


def run(*args):
    result = sp.run(args, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout.strip()


def wait(check, why, limit=8):
    end = time.monotonic() + limit
    while time.monotonic() < end:
        try:
            if check():
                return
        except (json.JSONDecodeError, AssertionError, KeyError, IndexError, TypeError):
            pass
        time.sleep(.05)
    raise AssertionError(why)


def marker(name):
    return DEV / f'{name}-substitute'


def clear_markers():
    for name in MARKERS:
        marker(name).unlink(missing_ok=True)


OUT.mkdir(parents=True, exist_ok=True)
DEV.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as directory:
    qml = pathlib.Path(directory) / 'qml'
    shutil.copytree(ROOT / 'quickshell', qml)
    shutil.copy(ROOT / 'tests/runtime/artifacts.qml', qml / 'session-test.qml')
    path = str(qml / 'session-test.qml')
    log = OUT / 'session-ui.log'
    with log.open('w') as output:
        process = sp.Popen(['quickshell', '-p', path], stdout=output, stderr=sp.STDOUT)
        try:
            wait(lambda: 'Configuration Loaded' in log.read_text(), 'load')

            def ipc(method, *args):
                return run('quickshell', 'ipc', '-p', path, 'call', 'test', method, *map(str, args))

            def state():
                return json.loads(ipc('state'))

            def card(index):
                return state()['cards'][index]

            def point(index, label):
                return json.loads(ipc('buttonPoint', index, label))

            for width, height in [(1280, 720), (1366, 768)]:
                clear_markers()
                run('swaymsg', f'output HEADLESS-1 mode {width}x{height}')
                time.sleep(.4)

                def click(x, y):
                    run(str(ROOT / 'tests/runtime/native/pointer'), str(width), str(height),
                        'move', str(round(x)), str(round(y)), 'down', 'up')

                def click_card(index):
                    c = card(index)
                    click(c['x'] + c['width'] / 2, c['y'] + c['height'] / 2)

                def open_deck():
                    ipc('group', 'session', width / 2)
                    wait(lambda: state()['phase'] > .999, 'deploy')

                def turn(index):
                    click_card(index)
                    wait(lambda: card(index)['flip'] > .999, f'card {index} turns')

                def turned_back(index, why):
                    wait(lambda: card(index)['flip'] < .001 and state()['session']['pending'] == '', why)

                open_deck()
                assert state()['pages'] == 1, state()['pages']
                assert [c['kind'] for c in state()['cards']] == ['suspend', 'poweroff', 'reboot']
                assert not any(c['dogEar'] for c in state()['cards']), 'action cards flip on a click; no dog-ear'
                run('grim', str(OUT / f'session-{width}-front.png'))

                # Shut Down: a click before the arming delay is ignored. The window is long
                # because the pointer, screenshot and IPC calls below take seconds in CI.
                ipc('armDelay', 10000)
                turn(1)
                assert state()['session']['pending'] == 'poweroff'
                time.sleep(.35)   # let the compositor commit the final frame
                run('grim', str(OUT / f'shutdown-{width}-back.png'))
                click_card(1)
                time.sleep(.4)
                assert not card(1)['armed'] and not marker('poweroff').exists(), 'unarmed click confirmed'
                ipc('armDelay', 400)
                # Escape turns it back and cancels.
                run('wtype', '-s', '100', '-k', 'Escape')
                turned_back(1, 'Escape turns Shut Down back')
                assert state()['phase'] > .999, 'Escape with a flipped card must not close the deck'
                # A click on the desk turns it back without closing the deck.
                turn(1)
                click(8, height - 8)
                turned_back(1, 'a desk click turns Shut Down back')
                assert state()['phase'] > .999
                # Untouched, the confirmation expires and the card turns back.
                ipc('confirmTimeout', 2000)
                turn(1)
                turned_back(1, 'confirmation timeout turns Shut Down back')
                ipc('confirmTimeout', 5000)
                assert not marker('poweroff').exists()

                # Reboot: armed second click confirms; the deck closes.
                turn(2)
                time.sleep(.35)
                run('grim', str(OUT / f'reboot-{width}-back.png'))
                wait(lambda: card(2)['armed'], 'Reboot arms')
                click_card(2)
                wait(lambda: marker('reboot').exists(), 'Reboot runs after an armed click')
                wait(lambda: state()['phase'] < .001, 'deck closes after the action starts')

                # Sleep: turns to a list with nothing pending.
                open_deck()
                turn(0)
                assert state()['session']['pending'] == '', 'turning Sleep selects nothing'
                time.sleep(.35)
                run('grim', str(OUT / f'sleep-{width}-back.png'))
                for label in ('Sleep', 'Lock', 'Log Out'):
                    assert point(0, label), f'{label} is not on the Sleep back at {width}x{height}'
                # Log Out confirms inline, then expires back.
                ipc('confirmTimeout', 2000)
                p = point(0, 'Log Out')
                click(p['x'], p['y'])
                wait(lambda: state()['session']['pending'] == 'logout' and point(0, 'Log out?'), 'Log Out asks inline')
                wait(lambda: state()['session']['pending'] == '' and point(0, 'Log Out'), 'inline confirmation expires')
                ipc('confirmTimeout', 5000)
                assert not marker('logout').exists()
                # ... and runs on an armed second click.
                p = point(0, 'Log Out')
                click(p['x'], p['y'])
                wait(lambda: point(0, 'Log out?'), 'Log Out asks again')
                time.sleep(.6)
                p = point(0, 'Log out?')
                click(p['x'], p['y'])
                wait(lambda: marker('logout').exists(), 'Log Out runs after an armed second click')
                wait(lambda: state()['phase'] < .001, 'deck closes after Log Out')
                # Lock acts at once.
                open_deck()
                turn(0)
                p = point(0, 'Lock')
                click(p['x'], p['y'])
                wait(lambda: marker('lock').exists(), 'Lock runs at once')
                wait(lambda: state()['phase'] < .001, 'deck closes after Lock')
                marker('lock').unlink()
                # Sleep locks first, then suspends.
                open_deck()
                turn(0)
                p = point(0, 'Sleep')
                click(p['x'], p['y'])
                wait(lambda: marker('suspend').exists(), 'Sleep suspends after locking')
                assert marker('lock').exists(), 'Sleep must lock before suspending'
                wait(lambda: state()['phase'] < .001 and not state()['session']['busy'], 'deck closes after Sleep')
                assert not marker('poweroff').exists(), 'Shut Down ran'
            clear_markers()
            print('PASS: 1280x720 and 1366x768 one-page Session deck; Shut Down ignores unarmed clicks and turns back '
                  'on Escape, a desk click and timeout; armed Reboot runs; Sleep menu: Log Out confirms inline and '
                  'expires, Lock acts at once, Sleep locks then suspends; Shut Down never ran', flush=True)

            # Locker guard.
            ipc('lockReady', 'false')
            ipc('session', 'suspend', 'true')
            wait(lambda: 'Sleep needs a locker' in state()['session']['error'], 'Sleep refused')
            time.sleep(.5)
            assert not marker('lock').exists() and not marker('suspend').exists()
            started, ended = OUT / 'blocking-lock-started', OUT / 'blocking-lock-ended'
            started.unlink(missing_ok=True)
            ended.unlink(missing_ok=True)
            ipc('blockingLock')
            ipc('session', 'lock', 'true')
            wait(lambda: started.exists(), 'blocking locker starts')
            time.sleep(16.5)   # past the 15-second limit that applies to other commands
            session = state()['session']
            assert session['busy'] and 'timed out' not in session['error'], session
            wait(lambda: ended.exists() and not state()['session']['busy'], 'locker ends on its own', limit=6)
            assert state()['session']['error'] == '', state()['session']
            ipc('lockReady', 'true')
            ipc('failingLock', 'false')
            print('PASS: with commands.lockReturnsWhenReady off, Sleep is refused and a locker that runs '
                  'until unlock is not killed by the command time limit', flush=True)
        finally:
            process.terminate()
            process.wait(timeout=5)
