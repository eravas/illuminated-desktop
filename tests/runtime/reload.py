"""Actual watched-file reload, notification continuity and surface accounting."""
import json,os,pathlib,re,shutil,subprocess as sp,tempfile,time
ROOT=pathlib.Path('/project');OUT=ROOT/'artifacts/development'
def run(*args):
 r=sp.run(args,capture_output=True,text=True,timeout=8);assert r.returncode==0,r.stdout+r.stderr;return r.stdout

def wait(check,why):
 end=time.monotonic()+8
 while time.monotonic()<end:
  try:
   if check():return
  except (json.JSONDecodeError,AssertionError):pass
  time.sleep(.05)
 raise AssertionError(why)
def surfaces(text):
 active={}
 for line in text.splitlines():
  create=re.search(r'get_layer_surface\(new id zwlr_layer_surface_v1#(\d+).*"([^"]+)"',line)
  if create:active[create[1]]=create[2]
  destroy=re.search(r'zwlr_layer_surface_v1#(\d+)\.destroy\(\)',line)
  if destroy:active.pop(destroy[1],None)
 return list(active.values())
with tempfile.TemporaryDirectory() as tmp:
 cfg=pathlib.Path(tmp)/'config';shutil.copytree(ROOT/'quickshell',cfg)
 settings=cfg/'fixture-preferences.json';settings.write_text(json.dumps({'features':{'notifications':True}}))
 path=str(cfg/'shell.qml');log=OUT/'reload.log'
 with log.open('w') as output:
  p=sp.Popen(['quickshell','-p',path],stdout=output,stderr=sp.STDOUT,env={**os.environ,'WAYLAND_DEBUG':'1','ILLUMINATED_SETTINGS':str(settings),'ILLUMINATED_RESOLVED':str(cfg/'resolved.json')})
  try:
   wait(lambda:'Configuration Loaded' in log.read_text(),'initial load')
   def ipc(method,*args):return run('quickshell','ipc','-p',path,'call','shell',method,*map(str,args)).strip()
   def state():return json.loads(ipc('status'))
   wait(lambda:state()['notifications'],'notification daemon ready')
   reply=run('gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.Notify','Reload fixture','0','','Retained across reload','Body','[]','{}','0')
   ident=re.search(r'uint32 (\d+)',reply)[1]
   wait(lambda:state()['historyCount']>=1,'history before reload')
   ipc('toggleLauncher');time.sleep(.12)
   settings.write_text(json.dumps({'features':{'notifications':True},'appearance':{'mode':'light'}}))
   wait(lambda:state()['appearance']=='light','reactive personal preferences')
   # resolved.json is what `illuminated apply` writes from config.toml; pinned keys beat ui.json.
   machine=cfg/'resolved.json';machine.write_text(json.dumps({'format':1,'values':{'appearance':{'mode':'dark'}},'pinned':['appearance.mode'],'diagnostics':[]}))
   wait(lambda:state()['appearance']=='dark','config.toml (pinned) precedence over ui.json')
   settings.write_text('{ invalid JSON')
   wait(lambda:bool(state()['configurationError']),'invalid preferences surfaced')
   assert state()['appearance']=='dark'
   settings.write_text(json.dumps({'features':{'notifications':True},'appearance':{'mode':'light'}}))
   wait(lambda:not state()['configurationError'],'valid preferences clear error')
   machine.unlink()
   wait(lambda:state()['appearance']=='light','removed config pin restores ui choice')
   theme=cfg/'theme/Theme.qml';theme.write_text(theme.read_text()+'\n// actual source reload fixture\n')
   wait(lambda:log.read_text().count('Configuration Loaded')>=2,'actual watched-file reload')
   wait(lambda:state()['notifications'],'IPC after reload')
   time.sleep(.6)
   assert state()['historyCount']>=1
   assert surfaces(log.read_text()).count('illuminated-rail')==1,surfaces(log.read_text())
   run('gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.CloseNotification',ident)
   ipc('toggleLauncher');time.sleep(.6);assert state()['launcherOpen']
   ipc('hide');time.sleep(.6);assert not state()['launcherOpen']
   problems=[l for l in log.read_text().splitlines() if 'scene' in l and any(word in l for word in ['Error','not a type','unavailable','Cannot assign'])]
   assert not problems,'\n'.join(problems)
   print('PASS: reactive JSON preferences, machine precedence/removal, invalid-file recovery, actual QML reload during launcher motion; IPC, single rail surface and notification continuity',flush=True)
  finally:p.terminate();p.wait(timeout=5)
