"""Real mmsg process + QML adapter under Sway; Mango state is an explicit fixture."""
import json,os,pathlib,shutil,subprocess as sp,tempfile,time
ROOT=pathlib.Path('/project');OUT=ROOT/'artifacts/portable'
def run(*args):
 r=sp.run(args,capture_output=True,text=True,timeout=8);assert r.returncode==0,r.stdout+r.stderr;return r.stdout.strip()
def wait(f,why,seconds=8):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  try:
   if f():return
  except (json.JSONDecodeError,AssertionError):pass
  time.sleep(.05)
 raise AssertionError(why)
with tempfile.TemporaryDirectory() as tmp:
 base=pathlib.Path(tmp);cfg=base/'config';shutil.copytree(ROOT/'quickshell',cfg);shutil.copy(ROOT/'tests/runtime/compositor.qml',cfg/'compositor-test.qml')
 socket=base/'mango.sock';control=base/'control.json';traffic=OUT/'mango-fixture-traffic.txt';traffic.write_text('')
 def start():return sp.Popen(['python',str(ROOT/'tests/runtime/mango-fixture.py'),str(socket),str(control),str(traffic)],stdout=sp.DEVNULL,stderr=sp.DEVNULL)
 server=start();wait(socket.exists,'fixture socket')
 env={**os.environ,'MANGO_INSTANCE_SIGNATURE':str(socket),'PATH':str(ROOT/'dev')+':'+os.environ['PATH']}
 with (OUT/'mango-adapter.log').open('w') as log:
  process=sp.Popen(['quickshell','-p',str(cfg/'compositor-test.qml')],env=env,stdout=log,stderr=sp.STDOUT)
  try:
   def ipc(method,*args):return run('quickshell','ipc','-p',str(cfg/'compositor-test.qml'),'call','test',method,*map(str,args))
   def state():return json.loads(ipc('state'))
   wait(lambda:state()['ready'],'adapter subscriptions')
   s=state();assert s['backend']=='mango' and s['capabilities']['multipleVisible'];assert s['context']['selection']==[1,3]
   assert [t['id'] for t in s['context']['spaces'] if t['active']]==[1,3]
   assert s['context']['spaces'][0]['toplevels']['values'][0]['id']==s['context']['spaces'][2]['toplevels']['values'][0]['id']==42
   ipc('activate',2,'true');wait(lambda:state()['context']['selection']==[1,2,3],'multi-tag toggle')
   ipc('activate',1,'true');wait(lambda:state()['context']['selection']==[2,3],'remove one visible tag')
   ipc('activate',4,'false');wait(lambda:state()['context']['selection']==[4],'replace tag selection')
   # Dock delegates survive title churn: one client's title changes, no entry is recreated.
   wait(lambda:json.loads(ipc('dock'))['titles']==['Mango fixture window','Second fixture window'],'dock entries')
   ipc('remember')
   control.write_text(json.dumps({'clientTitles':{'43':'Retitled second window'}}))
   wait(lambda:'Retitled second window' in json.loads(ipc('dock'))['titles'],'dock shows the new title')
   assert json.loads(ipc('dock'))['kept']==2,ipc('dock')
   control.write_text(json.dumps({'title':'Reconciled without event','broadcast':False}))
   wait(lambda:state()['context']['title']=='Reconciled without event','full reconciliation',seconds=13)
   server.terminate();server.wait(timeout=5);wait(lambda:not state()['ready'],'disconnect invalidation');assert state()['context']['spaces']==[]
   server=start();wait(lambda:state()['ready'],'reconnect');assert state()['context']['selection']==[1,3]
   ipc('provider','hyprland')
   wait(lambda:state()['backend']=='hyprland','native Hyprland adapter instantiation')
   assert not state()['ready'] and state()['context']['spaces']==[],'absent Hyprland must remain unavailable'
   ipc('provider','auto');wait(lambda:state()['backend']=='mango' and state()['ready'],'provider replacement and auto-detection recovery')
   problems=[line for line in (OUT/'mango-adapter.log').read_text().splitlines() if 'scene' in line and any(term in line for term in ['Error','Cannot assign','not a type','Binding loop'])]
   assert not problems,'\n'.join(problems)
   (OUT/'mango-adapter-state.json').write_text(json.dumps(state(),indent=2))
   print('PASS: genuine mmsg client + Mango adapter subscriptions, multi-tags, dispatch, reconciliation and reconnect against explicit IPC fixture; actual unavailable native-Hyprland adapter load and provider replacement',flush=True)
  finally:
   process.terminate();process.wait(timeout=5);server.terminate();server.wait(timeout=5)
