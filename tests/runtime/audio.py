"""Native Quickshell/PipeWire/WirePlumber integration against real virtual nodes.
No physical sound output or recording is claimed."""
import os,signal,json,pathlib,subprocess as sp,shutil,tempfile,time
ROOT=pathlib.Path('/project');OUT=ROOT/'artifacts/development'
def run(*args):
 r=sp.run(args,capture_output=True,text=True,timeout=8);assert r.returncode==0,r.stdout+r.stderr;return r.stdout

def wait(check,why):
 end=time.monotonic()+8
 while time.monotonic()<end:
  if check():return
  time.sleep(.1)
 raise AssertionError(why)
with tempfile.TemporaryDirectory() as tmp:
 cfg=pathlib.Path(tmp)/'config';shutil.copytree(ROOT/'quickshell',cfg);shutil.copy(ROOT/'tests/runtime/audio.qml',cfg/'audio-test.qml');path=str(cfg/'audio-test.qml')
 with (OUT/'audio.log').open('w') as log:
  p=sp.Popen(['quickshell','-p',path],stdout=log,stderr=sp.STDOUT,env={**__import__('os').environ,'WAYLAND_DEBUG':'1'})
  try:
   time.sleep(.5)
   def ipc(method,*args):return run('quickshell','ipc','-p',path,'call','test',method,*map(str,args)).strip()
   def state():return json.loads(ipc('state'))
   wait(lambda:state()['available'],'native default sink')
   assert len(state()['outputs'])==2
   time.sleep(.8)
   card=state()['card'];x=round(card['x']+card['width']/2);y=round(card['y']+card['height']/2)
   pointer=str(ROOT/'tests/runtime/native/pointer')
   run(pointer,'1280','720','move',str(x),str(y),'down','up')
   wait(lambda:state()['muted'],'native volume card click mute')
   original=state()['volume']
   run(pointer,'1280','720','move',str(x),str(y),'down','move',str(x-35),str(y),'up')
   wait(lambda:state()['volume']<original-.1,'native volume card drag')
   assert state()['muted'],'drag must not click/unmute'
   observed=state()
   assert abs(observed['card']['width']/observed['card']['height']-1.4)<.001
   assert abs(observed['fill']['height']-observed['card']['height'])<1,'fill must span the full card height'
   assert abs(observed['fill']['width']-observed['volume']*observed['card']['width'])<1,'muted fill must retain actual native volume'
   run('grim',str(OUT/'native-volume-card.png'))
   run('wpctl','set-mute','@DEFAULT_AUDIO_SINK@','0')
   ipc('volume',.33);wait(lambda:abs(state()['volume']-.33)<.01,'QML volume')
   assert '0.33' in run('wpctl','get-volume','@DEFAULT_AUDIO_SINK@')
   run('wpctl','set-volume','@DEFAULT_AUDIO_SINK@','0.61');wait(lambda:abs(state()['volume']-.61)<.01,'external volume sync')
   ipc('mute');wait(lambda:state()['muted'],'QML mute')
   assert 'MUTED' in run('wpctl','get-volume','@DEFAULT_AUDIO_SINK@')
   run('wpctl','set-mute','@DEFAULT_AUDIO_SINK@','0');wait(lambda:not state()['muted'],'external mute sync')
   old=state()['sink'];target=next(i for i,n in enumerate(state()['outputs']) if n['name']!=old)
   ipc('output',target);wait(lambda:state()['sink']!=old,'native output selection')
   (OUT/'audio-before-mic.json').write_text(json.dumps(state(),indent=2))
   if state()['inputs']: run('wpctl','set-default',str(state()['inputs'][0]['id']))
   wait(lambda:state()['micAvailable'],'native virtual source')
   ipc('micVolume',.42);wait(lambda:abs(state()['micVolume']-.42)<.01,'microphone gain')
   assert '0.42' in run('wpctl','get-volume','@DEFAULT_AUDIO_SOURCE@')
   ipc('microphone');wait(lambda:state()['micMuted'],'microphone mute')
   assert 'MUTED' in run('wpctl','get-volume','@DEFAULT_AUDIO_SOURCE@')
   sink=next(n['id'] for n in state()['outputs'] if n['name']==state()['sink'])
   run('pw-cli','destroy',str(sink));wait(lambda:len(state()['outputs'])==1,'node removal')
   wait(lambda:state()['available'] and state()['sink']==old,'default fallback recovery')
   assert 'illuminated-osd' in (OUT/'audio.log').read_text(),'OSD surface from actual native changes'
   (OUT/'audio-state.json').write_text(json.dumps(state(),indent=2))
   print('PASS: native PipeWire/WirePlumber virtual sinks/source, volume/mute external sync, microphone, output selection, removal/recovery',flush=True)
   os.kill(int(os.environ['ILLUMINATED_PIPEWIRE_PID']),signal.SIGTERM)
   os.kill(int(os.environ['ILLUMINATED_WIREPLUMBER_PID']),signal.SIGTERM)
   wait(lambda:not state()['available'],'backend loss')
   time.sleep(.3)
   with (OUT/'pipewire-restarted.txt').open('w') as backendlog:
    backend=sp.Popen(['pipewire'],stdout=backendlog,stderr=sp.STDOUT)
    manager=None
    try:
     time.sleep(.3)
     manager=sp.Popen(['wireplumber'],stdout=backendlog,stderr=sp.STDOUT)
     time.sleep(.5)
     run('pw-cli','create-node','adapter','{ factory.name = support.null-audio-sink node.name = illuminated-restarted media.class = Audio/Sink object.linger = true audio.position = [ FL FR ] }')
     wait(lambda:state()['available'] and state()['sink']=='illuminated-restarted','native server restart recovery')
     print('PASS: actual private PipeWire/WirePlumber termination and restart recovery',flush=True)
    finally:
     if manager:manager.terminate();manager.wait(timeout=5)
     backend.terminate();backend.wait(timeout=5)
  finally:p.terminate();p.wait(timeout=5)
