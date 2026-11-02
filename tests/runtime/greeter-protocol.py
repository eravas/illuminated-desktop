"""Native Quickshell greetd client against an explicitly simulated greetd socket.
No PAM, real accounts, credentials or compositor sessions are used."""
import json,os,pathlib,shutil,socket,struct,subprocess as sp,tempfile,threading,time
ROOT=pathlib.Path('/project');OUT=ROOT/'artifacts/portable'
def wait(f,why,seconds=8):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  try:
   if f():return
  except (AssertionError,json.JSONDecodeError):pass
  time.sleep(.04)
 raise AssertionError(why)
def run(*args):
 r=sp.run(args,capture_output=True,text=True,timeout=8);assert r.returncode==0,r.stdout+r.stderr;return r.stdout.strip()
with tempfile.TemporaryDirectory() as tmp:
 base=pathlib.Path(tmp);sock=base/'greetd.sock';sessions=base/'sessions';sessions.mkdir();cfg=base/'config';shutil.copytree(ROOT/'quickshell',cfg);shutil.copy(ROOT/'tests/runtime/greeter.qml',cfg/'greeter-test.qml')
 for name in ['Hyprland','Mango']:(sessions/(name.lower()+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+name+' fixture\nTryExec=/bin/true\nExec=/bin/true\nDesktopNames='+name+';\n')
 server=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);server.bind(str(sock));server.listen();events=[];auth_times=[];failure=[True];start_failure=[True]
 def peer():
  connection,_=server.accept()
  def recv_exact(count):
   data=b''
   while len(data)<count:
    part=connection.recv(count-len(data))
    if not part:raise EOFError()
    data+=part
   return data
  def send(value):
   payload=json.dumps(value).encode();connection.sendall(struct.pack('=I',len(payload))+payload)
  try:
   while True:
    size=struct.unpack('=I',recv_exact(4))[0];request=json.loads(recv_exact(size));kind=request['type'];events.append({'type':kind,'time':time.monotonic()})
    if kind=='create_session':send({'type':'auth_message','auth_message_type':'info','auth_message':'Fixture information prompt (not PAM)'})
    elif kind=='cancel_session':send({'type':'success'})
    elif kind=='post_auth_message_response':
     # Native Greetd must acknowledge informational prompts without user input.
     if 'response' not in request:
      send({'type':'auth_message','auth_message_type':'secret','auth_message':'Fixture challenge (not PAM)'})
      continue
     # Never retain or log the supplied response, even for this fixture.
     request.pop('response',None)
     if failure[0]:failure[0]=False;send({'type':'error','error_type':'auth_error','description':'Deliberate fixture rejection'})
     else:auth_times.append(time.monotonic());send({'type':'success'})
    elif kind=='start_session':
     assert request['cmd']==['/bin/true'];assert time.monotonic()-auth_times[-1]>.35,'session started before retraction'
     if start_failure[0]:start_failure[0]=False;send({'type':'error','error_type':'error','description':'Deliberate fixture session-start failure'})
     else:send({'type':'success'});break
  except (EOFError,OSError):pass
  finally:connection.close()
 threading.Thread(target=peer,daemon=True).start()
 env={**os.environ,'ILLUMINATED_GREETER':'1','ILLUMINATED_GREETER_TEST':'1','ILLUMINATED_GREETER_SESSION_DIR':str(sessions),'GREETD_SOCK':str(sock),'QT_LOGGING_RULES':'quickshell.service.greetd.debug=true'}
 path=str(cfg/'greeter-test.qml');log=OUT/'greeter-protocol.log'
 with log.open('w') as output:
  p=sp.Popen(['quickshell','-p',path],env=env,stdout=output,stderr=sp.STDOUT)
  try:
   def ipc(method):return run('quickshell','ipc','-p',path,'call','test',method)
   def state():return json.loads(ipc('state'))
   wait(lambda:state()['progress']>.999 and state()['sessions']==2,'flat greeter with discovered sessions')
   run('grim',str(OUT/'greeter.png'))
   run('wtype','-s','150','fixture-user','-k','Return');wait(lambda:state()['prompt'],'authentication prompt')
   run('wtype','-s','150','fixture-response-never-real','-k','Return');wait(lambda:'Deliberate fixture rejection' in state()['message'],'authentication failure')
   assert state()['progress']==1 and state()['secretLength']==0
   run('wtype','-s','150','-k','Return');wait(lambda:state()['prompt'],'retry prompt')
   run('wtype','-s','150','fixture-response-never-real','-k','Return');wait(lambda:state()['authenticated'],'mock authentication success')
   ipc('cancel');wait(lambda:state()['progress']>.999 and not state()['authenticated'],'cancel during retraction');time.sleep(.8)
   assert not any(e['type']=='start_session' for e in events)
   run('wtype','-s','150','-k','Return');wait(lambda:state()['prompt'],'final prompt')
   run('wtype','-s','150','fixture-response-never-real','-k','Return')
   wait(lambda:'session-start failure' in state()['message'] and state()['progress']>.999,'safe session-start failure recovery')
   assert state()['secretLength']==0
   run('wtype','-s','150','-k','Return');wait(lambda:state()['prompt'],'fallback prompt')
   ipc('stall')
   run('wtype','-s','150','fixture-response-never-real','-k','Return');p.wait(timeout=8)
   assert p.returncode==0 and events[-1]['type']=='start_session'
   assert 'fixture-response-never-real' not in log.read_text(),'secret appeared in logs'
   problems=[line for line in log.read_text().splitlines() if 'scene' in line and any(term in line for term in ['Error','Cannot assign','not a type','Binding loop'])]
   assert not problems,'\n'.join(problems)
   (OUT/'greeter-protocol-events.json').write_text(json.dumps(events,indent=2))
   print('PASS: native greetd protocol client with simulated authentication; discovery, informational/secret prompts, rejection, secret clearing, cancellation, session-start failure, retraction delay, stalled-animation watchdog and immediate successful exit',flush=True)
  finally:
   if p.poll() is None:p.terminate();p.wait(timeout=5)
   server.close()
