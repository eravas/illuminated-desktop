"""Isolated production entries and feature switches under actual headless Wayland."""
import json,os,pathlib,shutil,subprocess as sp,tempfile,time
ROOT=pathlib.Path('/project');OUT=ROOT/'artifacts/development'
allowed=['Could not find an available backend','Failed to create pipewire context','Failed to connect pipewire context. Errno: 112']
def check(entry,config,suffix):
 path=str(config/entry);log=OUT/(suffix+'.log')
 with log.open('w') as output:
  p=sp.Popen(['quickshell','-p',path],stdout=output,stderr=sp.STDOUT,env={**os.environ, **({'ILLUMINATED_SETTINGS':str(config/'fixture-preferences.json')} if (config/'fixture-preferences.json').exists() else {})})
  try:
   end=time.monotonic()+5
   while 'Configuration Loaded' not in log.read_text() and p.poll() is None and time.monotonic()<end:time.sleep(.05)
   assert p.poll() is None and 'Configuration Loaded' in log.read_text(),log.read_text()
   time.sleep(.25)
   text=log.read_text()
   problems=[l for l in text.splitlines() if ('ERROR' in l and not any(a in l for a in allowed)) or ('scene' in l and any(a in l for a in ['Error','not a type','unavailable','Cannot assign','Binding loop']))]
   assert not problems,'\n'.join(problems)
   if entry=='shell.qml':
    r=sp.run(['quickshell','ipc','-p',path,'call','shell','status'],capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
    (OUT/(suffix+'.json')).write_text(r.stdout)
    key={'Rail':'rail','Dock':'dock','Media':'media','Launcher':'launcher','Cards':'cards','Notifications':'notifications','Tray':'tray','Osd':'osd'}[suffix.removeprefix('disabled-')]
    assert json.loads(r.stdout)[key] is False,r.stdout
  finally:
   p.terminate()
   try:p.wait(timeout=5)
   except sp.TimeoutExpired:p.kill();p.wait()
 print('PASS:',suffix,flush=True)
for entry in ['cards-preview.qml','media.qml','osd.qml','notifications.qml','chrome-entry.qml']:
 check(entry,ROOT/'quickshell','isolated-'+entry)
for feature in ['Rail','Dock','Media','Launcher','Cards','Notifications','Tray','Osd']:
 with tempfile.TemporaryDirectory() as tmp:
  cfg=pathlib.Path(tmp)/'config';shutil.copytree(ROOT/'quickshell',cfg)
  (cfg/'fixture-preferences.json').write_text(json.dumps({'features':{'notifications':True,feature[0].lower()+feature[1:]:False}}))
  check('shell.qml',cfg,'disabled-'+feature)
