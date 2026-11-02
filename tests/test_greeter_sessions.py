import importlib.util,pathlib,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('greeter_sessions',ROOT/'quickshell/greeter/sessions.py');sessions=importlib.util.module_from_spec(spec);spec.loader.exec_module(sessions)
class SessionDiscoveryTests(unittest.TestCase):
 def test_discovery_uses_installed_executable_metadata(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp)
   for name,extra in [('Hyprland',''),('Mango',''),('Mango missing','TryExec=/nonexistent/compositor\n'),('Hyprland hidden','Hidden=true\n')]:
    (root/(name+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec=/bin/true\n'+extra)
   result=sessions.discover([tmp],True);self.assertEqual([s['name'] for s in result],['Hyprland','Mango']);self.assertTrue(all(s['command']==['/bin/true'] for s in result))
 def test_user_writable_metadata_is_rejected_in_production(self):
  with tempfile.TemporaryDirectory() as tmp:
   (pathlib.Path(tmp)/'mango.desktop').write_text('[Desktop Entry]\nName=Mango\nExec=/bin/true\n')
   self.assertEqual(sessions.discover([tmp],False),[])
 def test_exec_field_codes_are_expanded_without_shell(self):
  with tempfile.TemporaryDirectory() as tmp:
   (pathlib.Path(tmp)/'mango.desktop').write_text('[Desktop Entry]\nName=Mango\nExec=/bin/true "%c" %% %f\n')
   self.assertEqual(sessions.discover([tmp],True)[0]['command'],['/bin/true','Mango','%'])
