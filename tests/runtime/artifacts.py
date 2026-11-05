"""Actual QML/Wayland/notification D-Bus execution. Gesture value is an explicitly injected component fixture, not audio verification."""
import json, os, pathlib, re, shutil, subprocess as sp, tempfile, time
ROOT = pathlib.Path('/project')
OUT = ROOT / 'artifacts' / 'development'
OUT.mkdir(exist_ok=True)

def run(*args):
    r = sp.run(args, capture_output=True, text=True)
    assert r.returncode == 0, str(args) + '\n' + r.stdout + r.stderr
    return r.stdout.strip()

def wait(predicate, why, seconds=8):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if predicate(): return
        time.sleep(.03)
    raise AssertionError(why)

with tempfile.TemporaryDirectory() as tmp:
    cfg=pathlib.Path(tmp)/'config'
    shutil.copytree(ROOT/'quickshell',cfg)
    shutil.copy(ROOT/'tests/runtime/artifacts.qml',cfg/'artifacts-test.qml')
    path=str(cfg/'artifacts-test.qml')
    backend=pathlib.Path(tmp)/'bin';backend.mkdir()
    helper=backend/'brightnessctl'
    helper.write_text('#!/usr/bin/env python3\nimport pathlib,sys\np=pathlib.Path(__file__).with_name("level")\nv=int(p.read_text()) if p.exists() else 50\nif "set" in sys.argv:v=int(sys.argv[-1].rstrip("%"));p.write_text(str(v))\nprint(f"fixture,backlight,50,{v}%,100")\n')
    helper.chmod(0o755)
    log=OUT/'artifacts.log'
    with log.open('w') as output:
        process=sp.Popen(['quickshell','-p',path],stdout=output,stderr=sp.STDOUT,env={**os.environ,'WAYLAND_DEBUG':'1','PATH':str(backend)+':'+os.environ['PATH']})
        try:
            wait(lambda: 'Configuration Loaded' in log.read_text() or process.poll() is not None,'configuration load')
            assert process.poll() is None,log.read_text()
            def ipc(method,*args): return run('quickshell','ipc','-p',path,'call','test',method,*map(str,args))
            def state(): return json.loads(ipc('state'))
            def settled(): return state()['phase'] > .999
            for group in ['sound','levels','battery','connections','media','notifications','power','settings']:
                ipc('group',group,240)
                wait(lambda: state()['group']==group and settled(),group+' deployment')
                s=state()
                if group=='power':run('grim',str(OUT/'v2-power-front.png'))
                if group=="sound":run("grim",str(OUT/"cards-deployed.png"))
                # One row on the hand's lane, left to right, clear of the rail.
                assert all(abs(c['y']+c['height']/2-s['lane'])<1 for c in s['cards']),s['cards']
                xs=[c['x'] for c in s['cards']];assert xs==sorted(xs) and all(x>=s['chromeLeft'] for x in xs),s['cards']
                # Power's flip test uses Shut Down; Battery's is Charge (Brightness has no back).
                idx=1 if group=='power' else 0
                if s['cards']:
                    angle=s['cards'][idx]['rotation']
                    ipc('select',idx)
                    card=s['cards'][idx]
                    pointer=str(ROOT/'tests/runtime/native/pointer')
                    # Cards whose click toggles (mute, radio, DND) turn from the dog-ear or a right-click.
                    button='right' if card['dogEar'] else 'down'
                    args=[pointer,'1280','720','move',str(round(card['x']+card['width']/2)),str(round(card['y']+card['height']/2)),button]
                    if button=='down':args.append('up')
                    run(*args)
                    wait(lambda: state()['cards'][idx]['flip']>.999,'flip completion')
                    assert state()['cards'][idx]['rotation']==angle
                    run('grim',str(OUT/('v2-'+group+'-back.png')))
                    point=json.loads(ipc('returnPoint',idx))
                    run(pointer,'1280','720','move',str(round(point['x'])),str(round(point['y'])),'down','up')
                    wait(lambda: state()['cards'][idx]['flip']<.001,'flip reverse')
                if group=='levels':
                    wait(lambda:state()['brightness']['available'],'safe brightness backend')
                    c=state()['cards'][1];x=round(c['x']+c['width']/2);y=round(c['y']+c['height']/2)
                    before=state()['brightness']['value']
                    run(pointer,'1280','720','move',str(x),str(y),'down','move',str(x+35),str(y),'up')
                    wait(lambda:state()['brightness']['value']>before+.05,'deployed brightness drag through safe CLI backend')
                    run('grim',str(OUT/'v2-brightness-fill.png'))
                if group=='power':
                    assert s['pages']==1
                    assert [c['kind'] for c in s['cards']]==['suspend','poweroff','reboot']
                    ipc('page',1);wait(lambda: state()['page']==0 and settled(),'pagination')
                    assert len(state()['cards'])==3
                ipc('close');wait(lambda: state()['phase']<.001,'retraction')
            print('PASS: real card deployment, flip/reverse, selection, pagination',flush=True)
            # v7: a hand dealt from the rail travels in from the left at the initial's height.
            ipc('hand','levels',300)
            wait(lambda: state()['group']=='levels' and settled(),'rail hand deployment')
            s=state();xs=[c['x'] for c in s['cards']]
            assert xs==sorted(xs) and min(xs)>=72,s['cards']
            assert all(abs(c['y']+c['height']/2-300)<2 or c['y']>=0 for c in s['cards']),s['cards']
            run('grim',str(OUT/'v7-rail-hand.png'))
            ipc('close');wait(lambda: state()['phase']<.001,'rail hand retraction')
            print('PASS: rail hand dealt sideways beside the rail',flush=True)
            ipc('group','sound',240);wait(settled,'devices pointer group')
            c=state()['cards'][2]
            run(pointer,'1280','720','move',str(round(c['x']+c['width']/2)),str(round(c['y']+c['height']/2)),'down','up')
            wait(lambda:state()['cards'][2]['flip']>.999,'deployed Devices left-click')
            p=json.loads(ipc('returnPoint',2))
            run(pointer,'1280','720','move',str(round(p['x'])),str(round(p['y'])),'down','up')
            wait(lambda:state()['cards'][2]['flip']<.001,'Devices Return pointer')
            run('swaymsg','output HEADLESS-1 scale 1.25');time.sleep(.4)
            assert state()['cards'] and state()['pages']>=1
            run('swaymsg','output HEADLESS-1 scale 1');time.sleep(.4)
            ipc('close');wait(lambda:state()['phase']<.001,'devices group close')
            print('PASS: deployed Devices pointer flip/Return and fractional output scale recovery',flush=True)

            ipc('group','connections',240);wait(settled,'keyboard card deployment')
            run('wtype','-s','150','-k','Right')
            wait(lambda:state()['cards'][0]['flip']>.999,'keyboard flip')
            (OUT/'focus-debug.json').write_text(ipc('focus'))
            run('wtype','-s','150','-k','Return')
            wait(lambda:state()['sheet']=='network','keyboard back action opens sheet')
            time.sleep(.45)
            run('wtype','-s','150','-k','Return')
            wait(lambda:not state()['sheet'],'focused return-to-cards control')
            time.sleep(.45)
            run('wtype','-s','150','-k','Left')
            wait(lambda:state()['cards'][0]['flip']<.001,'keyboard return to front')
            run('wtype','-s','150','-k','Down','-k','Right')
            wait(lambda:state()['cards'][1]['selected'] and state()['cards'][1]['flip']>.999,'keyboard selection transfers focus')
            run('wtype','-s','150','-k','Return')
            wait(lambda:state()['sheet']=='bluetooth','second card keyboard action')
            ipc('close');wait(lambda:state()['phase']<.001,'keyboard group close')
            print('PASS: real keyboard card selection, flip, back action, expanded-sheet focus and return-to-origin',flush=True)
            # Rapid transitions: last request wins without stale timers or destroyed models.
            for name in ['sound','power','connections','sound']:
                ipc('group',name,240);time.sleep(.05)
            wait(lambda: state()['group']=='sound' and settled(),'interrupted group')
            run('swaymsg','output HEADLESS-1 mode 320x240')
            wait(lambda:state()['pages']>1 and settled(),'responsive pagination')
            seen=[]
            for page in range(state()['pages']):
                if page:ipc('page',1);wait(lambda:state()['page']==page and settled(),'narrow page '+str(page))
                for card in state()['cards']:
                    assert card['x']>=0 and card['x']+card['width']<=320 and card['y']+card['height']<200,card
                    seen.append(card['kind'])
                if not page:run('grim',str(OUT/'cards-narrow.png'))
            assert seen==['volume','microphone','outputs'],seen
            run('swaymsg','output HEADLESS-1 mode 1280x720')
            wait(lambda:len(state()['cards'])==3,'responsive restore')
            print('PASS: actual virtual-output resize to 320x240 paginates without inaccessible cards',flush=True)
            for name in ['audio','network','bluetooth','media','history','settings','brightness']:
                ipc('expand',name);time.sleep(.45)
                assert state()['sheet']==name
            run('grim',str(OUT/'cards-expanded.png'))
            ipc('close');wait(lambda: state()['phase']<.001,'close expanded')
            print('PASS: expanded sheets load and dismiss during real transitions',flush=True)
            ipc('launch');time.sleep(.12)
            s=state()['launcher'];g=s['geometry'];assert s['progress']>0 and 0<g['reveal']<=g['width']
            x0=g['x']
            ipc('launch');time.sleep(.05);ipc('launch')
            wait(lambda: state()['launcher']['progress']>.999,'interrupted launcher open')
            s=state()['launcher'];g=s['geometry'];assert g['x']==x0 and g['reveal']==g['width']   # flat unfurl: no travel
            run('grim',str(OUT/'launcher.png'))
            run('wtype','-s','150','-k','Escape')
            wait(lambda: state()['launcher']['progress']<.001,'launcher reverse close')
            print('PASS: flat spread reveal in place, interruptions, keyboard dismissal',flush=True)
            ipc('motion','true');ipc('launch');wait(lambda:state()['launcher']['progress']==1,'reduced-motion open');ipc('launch');wait(lambda:state()['launcher']['progress']==0,'reduced-motion close');ipc('motion','false')
            print('PASS: reduced-motion state transitions',flush=True)
            pointer=str(ROOT/'tests/runtime/native/pointer')
            ipc('gesture');time.sleep(.3)
            run(pointer,'1280','720','move','130','200','down','up')
            wait(lambda: state()['clicks']==1,'pointer click')
            run(pointer,'1280','720','move','130','240','down','move','130','170','up')
            assert state()['clicks']==1 and state()['value']>.7,state()
            value=state()['value']
            run(pointer,'1280','720','move','130','200','scroll','15')
            assert state()['value']!=value
            run(pointer,'1280','720','move','130','200','right')
            wait(lambda: state()['gestureFlip']>.999,'pointer right-click flip')
            ipc('gesture')
            print('PASS: real Wayland pointer click/drag discrimination, scroll and flip (component fixture)',flush=True)
            def notify(summary,replace=0,expiry=8000):
                reply=run('gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.Notify','Artifact Test',str(replace),'',summary,'plain <b>literal</b> body',"['default', 'Open']",'{}',str(expiry))
                return int(re.search(r'uint32 (\d+)',reply)[1])
            ident=notify('Actual DBus notification')
            wait(lambda: state()['notifications']['popups']>0,'notification popup')
            ident2=notify('Replacement',ident)
            assert ident==ident2
            wait(lambda: state()['notifications']['history'][0]['summary']=='Replacement','replacement')
            assert len([row for row in state()['notifications']['history'] if row['id']==ident and row['active']])==1
            ipc('dnd');quiet=notify('Quiet actual DBus notification')
            wait(lambda: any(r['id']==quiet for r in state()['notifications']['history']),'dnd retains history')
            assert state()['notifications']['popups']==0
            ipc('dnd');ipc('dismissNotification',ident)
            wait(lambda: not any(r['id']==ident and r['active'] for r in state()['notifications']['history']),'dismiss')
            expiring=notify('Expires',0,200)
            wait(lambda: any(r['id']==expiring and not r['active'] for r in state()['notifications']['history']),'native expiry')
            print('PASS: real freedesktop notification DBus receive/replace/expire/dismiss, DND/history',flush=True)
            for action in ['lock','logout','suspend','reboot','poweroff']:
                marker=OUT/(action+'-substitute')
                marker.unlink(missing_ok=True)
                ipc('session',action,'false');assert not marker.exists()
                ipc('session',action,'true');wait(lambda:marker.exists(),action+' substitute')
            print('PASS: confirmation/cancel and lock-before-suspend using harmless command substitutes',flush=True)
            (OUT/'suspend-substitute').unlink()
            ipc('failingLock','true');ipc('session','suspend','true')
            wait(lambda:not state()['session']['busy'] and bool(state()['session']['error']),'failed lock reports error')
            assert not (OUT/'suspend-substitute').exists(),'suspend ran after lock failure'
            ipc('failingLock','false')
            print('PASS: failed locker prevents suspend (harmless command substitutes)',flush=True)
            ipc('group','power',240);wait(settled,'confirmation group')
            ipc('flip',1);wait(lambda:state()['session']['pending']=='poweroff','card confirmation selection')
            wait(lambda:state()['session']['pending']=='','confirmation expiration',seconds=8)
            wait(lambda:state()['cards'][1]['flip']<.001,'expired confirmation turns the card back')
            ipc('close');wait(lambda:state()['phase']<.001,'expired card close')
            print('PASS: actual stale-confirmation expiration without invoking a power operation',flush=True)
            (OUT/'peer-state.json').unlink(missing_ok=True)
            with (OUT/'protocol-peer.txt').open('w') as peerlog:
                peer=sp.Popen(['python',str(ROOT/'tests/runtime/protocol-peer.py')],stdout=peerlog,stderr=sp.STDOUT)
                try:
                    def peerState():
                        try:return json.loads((OUT/'peer-state.json').read_text())
                        except (FileNotFoundError,json.JSONDecodeError):return {}
                    wait(lambda:peerState().get('notification',0)>0,'protocol fixture ready')
                    wait(lambda:state()['media']['count']==1 and state()['tray']==1,'native MPRIS and SNI discovery')
                    assert state()['media']['title']=='Fixture track'
                    ipc('media');wait(lambda:peerState().get('playing',False) and state()['media']['playing'],'MPRIS PlayPause')
                    ipc('next');wait(lambda:peerState().get('next',0)==1,'MPRIS Next')
                    ipc('trayActivate');wait(lambda:peerState().get('activate',0)==1,'SNI activation')
                    ipc('trayMenu')
                    wait(lambda:(b:=json.loads(ipc('sheetBox'))) and b['progress']>=1,'tray sheet open');time.sleep(.3)
                    run('grim',str(OUT/'tray-menu.png'))
                    # The tray sheet sits beside the rail at the hand's lane; its first menu
                    # action ("Fixture action") is the row under the heading and back button.
                    box=json.loads(ipc('sheetBox'))
                    run(pointer,'1280','720','move',str(round(box['x']+240)),str(round(box['y']+155)),'down','up')
                    wait(lambda:peerState().get('menu',0)==1,'DBusMenu action through vellum sheet')
                    ipc('invoke',peerState()['notification']);wait(lambda:peerState().get('action',0)==1,'actual Notification ActionInvoked delivery')
                    print('PASS: native MPRIS, SNI/DBusMenu and notification action transport against explicit application fixtures',flush=True)
                finally:
                    peer.terminate();peer.wait(timeout=5)
                wait(lambda:state()['media']['count']==0 and state()['tray']==0,'disconnected application cleanup')
            time.sleep(.4)
            text=log.read_text()
            problems=[line for line in text.splitlines() if ('scene' in line and any(word in line for word in ['Error','is not a type','unavailable','binding loop','Cannot assign'])) or ('ERROR' in line and not any(known in line for known in ['Could not find an available backend','Failed to create pipewire context','Failed to connect pipewire context. Errno: 112']))]
            assert not problems,'\n'.join(problems)
            (OUT/'state.json').write_text(json.dumps(state(),indent=2))
            storage=pathlib.Path.home()/'.local/state/illuminated/notifications.json'
            wait(lambda:storage.exists() and len(json.loads(storage.read_text())['history'])>0,'history persistence')
            import stat
            assert stat.S_IMODE(storage.stat().st_mode)==0o600
            ipc('dnd');time.sleep(.4)
            process.terminate();process.wait(timeout=5)
            with (OUT/'history-restart.log').open('w') as restartlog:
                process=sp.Popen(['quickshell','-p',path],stdout=restartlog,stderr=sp.STDOUT)
                time.sleep(.7)
                wait(lambda:len(state()['notifications']['history'])>0,'history reload')
                assert state()['notifications']['dnd']
                assert all(not row['active'] for row in state()['notifications']['history'])
                assert state()['notifications']['popups']==0
            print('PASS: private notification history and DND persistence across actual process restart',flush=True)
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except sp.TimeoutExpired:process.kill();process.wait()
