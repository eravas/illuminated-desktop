"""Documented Mango 0.18.4 IPC schema fixture, NOT a Mango compositor.
The production adapter runs the genuine built mmsg client against this socket."""
import json,os,pathlib,socketserver,sys,threading,time
sock,control,traffic=map(pathlib.Path,sys.argv[1:]);lock=threading.RLock();subscribers=[]
state={'monitors':[{'name':'HEADLESS-1','active':True,'active_tags':[1,3],'active_client':{'id':42,'title':'Mango fixture window','appid':'fixture'}}], 'clients':[{'id':42,'monitor':'HEADLESS-1','tags':[1,3],'title':'Mango fixture window','is_focused':True,'is_urgent':False}]}
def tag_groups():return [{'monitor':m['name'],'tags':[{'index':i,'is_active':i in m['active_tags'],'is_urgent':i==3,'client_count':sum(c['monitor']==m['name'] and i in c['tags'] for c in state['clients'])} for i in range(1,10)]} for m in state['monitors']]
def payload(channel):return {'all-monitors':{'monitors':state['monitors']},'all-tags':{'all_tags':tag_groups()},'all-clients':{'clients':state['clients']}}[channel]
def emit():
 with lock:
  for handler,channel in subscribers[:]:
   try:handler.wfile.write((json.dumps(payload(channel))+'\n').encode());handler.wfile.flush()
   except OSError:subscribers.remove((handler,channel))
class Handler(socketserver.StreamRequestHandler):
 def handle(self):
  line=self.rfile.readline().decode().strip()
  with lock:
   with traffic.open('a') as f:f.write(line+'\n')
  mode,_,arg=line.partition(' ')
  if mode in ('get','watch') and arg in ('all-monitors','all-tags','all-clients'):
   with lock:self.wfile.write((json.dumps(payload(arg))+'\n').encode());self.wfile.flush()
   if mode=='watch':
    with lock:subscribers.append((self,arg))
    try:self.rfile.read()
    finally:
     with lock:
      if (self,arg) in subscribers:subscribers.remove((self,arg))
  elif mode=='dispatch':
   parts=arg.split(',')
   if parts[0]=='viewcrossmon' and len(parts)==3:
    with lock:
     monitor=next(m for m in state['monitors'] if m['name']==parts[2]);monitor['active_tags']=list(map(int,parts[1].split('|')))
    emit();self.wfile.write(b'{"success":true}\n')
   else:self.wfile.write(b'{"error":"unsupported fixture command"}\n')
  else:self.wfile.write(b'{"error":"unknown fixture request"}\n')
class Server(socketserver.ThreadingUnixStreamServer):daemon_threads=True
sock.unlink(missing_ok=True)
server=Server(str(sock),Handler)
def controls():
 last=''
 while True:
  try:text=control.read_text()
  except FileNotFoundError:text=''
  if text and text!=last:
   data=json.loads(text)
   with lock:
    if 'title' in data:state['monitors'][0]['active_client']['title']=data['title']
   if data.get('broadcast',True):emit()
   last=text
  time.sleep(.05)
threading.Thread(target=controls,daemon=True).start();server.serve_forever()
