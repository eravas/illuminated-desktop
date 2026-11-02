"""Simulated application peers over real D-Bus. These test protocol integration,
not playback by MPD or a real tray application. No hardware state is simulated."""
import asyncio,json,pathlib
from dbus_next.aio import MessageBus
from dbus_next import Variant, Message, MessageType
from dbus_next.service import ServiceInterface,dbus_property,method
from dbus_next.constants import PropertyAccess
OUT=pathlib.Path('/project/artifacts/development/peer-state.json')
state={'playing':False,'next':0,'activate':0,'menu':0,'action':0,'notification':0}
def save():OUT.write_text(json.dumps(state))
class Player(ServiceInterface):
 def __init__(self):super().__init__('org.mpris.MediaPlayer2.Player')
 @dbus_property(access=PropertyAccess.READ)
 def PlaybackStatus(self)->'s':return 'Playing' if state['playing'] else 'Paused'
 @dbus_property(access=PropertyAccess.READ)
 def Metadata(self)->'a{sv}':return {'mpris:trackid':Variant('o','/fixture/track'),'xesam:title':Variant('s','Fixture track'),'xesam:artist':Variant('as',['Fixture artist']),'mpris:length':Variant('x',120000000)}
 @dbus_property(access=PropertyAccess.READ)
 def CanControl(self)->'b':return True
 @dbus_property(access=PropertyAccess.READ)
 def CanPlay(self)->'b':return True
 @dbus_property(access=PropertyAccess.READ)
 def CanPause(self)->'b':return True
 @dbus_property(access=PropertyAccess.READ)
 def CanGoNext(self)->'b':return True
 @dbus_property(access=PropertyAccess.READ)
 def CanGoPrevious(self)->'b':return True
 @dbus_property(access=PropertyAccess.READ)
 def CanSeek(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def Position(self)->'x':return 0
 @dbus_property(access=PropertyAccess.READWRITE)
 def Volume(self)->'d':return .5
 @Volume.setter
 def Volume(self,value:'d'):pass
 @dbus_property(access=PropertyAccess.READWRITE)
 def Rate(self)->'d':return 1.
 @Rate.setter
 def Rate(self,value:'d'):pass
 @method()
 def PlayPause(self):
  state['playing']=not state['playing'];save();self.emit_properties_changed({'PlaybackStatus':self.PlaybackStatus})
 @method()
 def Play(self):
  state['playing']=True;save();self.emit_properties_changed({'PlaybackStatus':self.PlaybackStatus})
 @method()
 def Pause(self):
  state['playing']=False;save();self.emit_properties_changed({'PlaybackStatus':self.PlaybackStatus})
 @method()
 def Next(self):state['next']+=1;save()
 @method()
 def Previous(self):pass
class Media(ServiceInterface):
 def __init__(self):super().__init__('org.mpris.MediaPlayer2')
 @dbus_property(access=PropertyAccess.READ)
 def Identity(self)->'s':return 'Illuminated protocol fixture'
 @dbus_property(access=PropertyAccess.READ)
 def CanQuit(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def CanRaise(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def HasTrackList(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def SupportedUriSchemes(self)->'as':return []
 @dbus_property(access=PropertyAccess.READ)
 def SupportedMimeTypes(self)->'as':return []
class Tray(ServiceInterface):
 def __init__(self):super().__init__('org.kde.StatusNotifierItem')
 @dbus_property(access=PropertyAccess.READ)
 def Category(self)->'s':return 'ApplicationStatus'
 @dbus_property(access=PropertyAccess.READ)
 def Id(self)->'s':return 'illuminated-fixture'
 @dbus_property(access=PropertyAccess.READ)
 def Title(self)->'s':return 'Fixture tray'
 @dbus_property(access=PropertyAccess.READ)
 def Status(self)->'s':return 'Active'
 @dbus_property(access=PropertyAccess.READ)
 def WindowId(self)->'u':return 0
 @dbus_property(access=PropertyAccess.READ)
 def IconName(self)->'s':return 'folder'
 @dbus_property(access=PropertyAccess.READ)
 def IconPixmap(self)->'a(iiay)':return []
 @dbus_property(access=PropertyAccess.READ)
 def ToolTip(self)->'(sa(iiay)ss)':return ['folder',[],'Fixture tray','Protocol test only']
 @dbus_property(access=PropertyAccess.READ)
 def ItemIsMenu(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def Menu(self)->'o':return '/MenuBar'
 @method()
 def Activate(self,x:'i',y:'i'):state['activate']+=1;save()
 @method()
 def SecondaryActivate(self,x:'i',y:'i'):pass
 @method()
 def ContextMenu(self,x:'i',y:'i'):pass
 @method()
 def Scroll(self,delta:'i',orientation:'s'):pass
class Menu(ServiceInterface):
 def __init__(self):super().__init__('com.canonical.dbusmenu')
 @dbus_property(access=PropertyAccess.READ)
 def Version(self)->'u':return 3
 @dbus_property(access=PropertyAccess.READ)
 def TextDirection(self)->'s':return 'ltr'
 @dbus_property(access=PropertyAccess.READ)
 def Status(self)->'s':return 'normal'
 @dbus_property(access=PropertyAccess.READ)
 def IconThemePath(self)->'as':return []
 @method()
 def GetLayout(self,parent:'i',depth:'i',names:'as')->'u(ia{sv}av)':
  child=Variant('(ia{sv}av)',[1,{'label':Variant('s','Fixture action'),'enabled':Variant('b',True),'visible':Variant('b',True)},[]])
  return [1,[0,{},[child]]]
 @method()
 def AboutToShow(self,id:'i')->'b':return False
 @method()
 def GetGroupProperties(self,ids:'ai',names:'as')->'a(ia{sv})':return []
 @method()
 def Event(self,id:'i',event:'s',data:'v',timestamp:'u'):
  if event=='clicked':state['menu']+=1;save()
async def main():
 bus=await MessageBus().connect()
 bus.export('/org/mpris/MediaPlayer2',Media());bus.export('/org/mpris/MediaPlayer2',Player())
 bus.export('/StatusNotifierItem',Tray());bus.export('/MenuBar',Menu())
 await bus.request_name('org.mpris.MediaPlayer2.illuminated_fixture')
 await bus.request_name('org.kde.StatusNotifierItem-42-1')
 def notification_message(msg):
  if msg.interface=='org.freedesktop.Notifications' and msg.member=='ActionInvoked':state['action']+=1;save()
 bus.add_message_handler(notification_message)
 await bus.call(Message(destination='org.freedesktop.DBus',path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',member='AddMatch',signature='s',body=["type='signal',interface='org.freedesktop.Notifications'"]))
 registered=await bus.call(Message(destination='org.kde.StatusNotifierWatcher',path='/StatusNotifierWatcher',interface='org.kde.StatusNotifierWatcher',member='RegisterStatusNotifierItem',signature='s',body=['org.kde.StatusNotifierItem-42-1']))
 assert registered.message_type!=MessageType.ERROR,registered.body
 response=await bus.call(Message(destination='org.freedesktop.Notifications',path='/org/freedesktop/Notifications',interface='org.freedesktop.Notifications',member='Notify',signature='susssasa{sv}i',body=['Protocol fixture',0,'','Action fixture','Action invocation test',['default','Open'],{},0]))
 assert response.message_type!=MessageType.ERROR,response.body
 state['notification']=response.body[0];save()
 await asyncio.Future()
asyncio.run(main())
