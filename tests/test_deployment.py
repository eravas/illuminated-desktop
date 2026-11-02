"""Ownership-manifest safety (lib/illuminated/deploy.py), driven like the v2 installer CLI."""
import json, os, pathlib, sys, tempfile, types, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'lib'))
from illuminated import deploy as module
def legacy_cli(dest,settings,*args):
 force='--force' in args
 try:
  d=module.Deployment(str(dest),force,source=ROOT/'quickshell')
  if '--uninstall' in args:d.uninstall('--dry-run' in args)
  elif '--restore' in args:d.restore('--dry-run' in args)
  else:
   d.deploy('--update' in args,'--backup-conflicts' in args,'--dry-run' in args)
   if '--dry-run' not in args:
    settings.mkdir(parents=True,exist_ok=True)
    if not (settings/'preferences.json').exists():(settings/'preferences.json').write_text('{}')
  return types.SimpleNamespace(returncode=0,stderr='')
 except (ValueError,OSError) as e:return types.SimpleNamespace(returncode=1,stderr=str(e))
class DeploymentTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name);self.dest=self.root/'shell';self.settings=self.root/'personal'
 def call(self,*args):
  return legacy_cli(self.dest,self.settings,*args)
 def install(self):self.assertEqual(self.call().returncode,0)
 def test_dry_run_writes_nothing(self):
  self.assertEqual(self.call('--dry-run').returncode,0);self.assertFalse(self.dest.exists());self.assertFalse(self.settings.exists());self.assertEqual(list(self.root.iterdir()),[])
 def test_idempotent_update_and_personal_preferences(self):
  self.install();prefs=self.settings/'preferences.json';prefs.write_text('{"appearance":{"mode":"light"}}');before=(self.dest/'shell.qml').stat().st_mtime_ns
  result=self.call('--update');self.assertEqual(result.returncode,0,result.stderr);self.assertEqual((self.dest/'shell.qml').stat().st_mtime_ns,before);self.assertIn('light',prefs.read_text())
 def test_modified_code_requires_explicit_backup_policy(self):
  self.install();(self.dest/'shell.qml').write_text('user modification');self.assertNotEqual(self.call('--update').returncode,0);self.assertEqual((self.dest/'shell.qml').read_text(),'user modification');self.assertEqual(self.call('--update','--force').returncode,0);self.assertEqual(self.call('--restore').returncode,0);self.assertEqual((self.dest/'shell.qml').read_text(),'user modification')
 def test_uninstall_preserves_unowned_and_restores(self):
  self.install();(self.dest/'notes.txt').write_text('personal addition');source=(self.dest/'shell.qml').read_text();self.assertEqual(self.call('--uninstall').returncode,0);self.assertFalse((self.dest/'shell.qml').exists());self.assertEqual((self.dest/'notes.txt').read_text(),'personal addition');self.assertTrue((self.settings/'preferences.json').exists());self.assertEqual(self.call('--restore').returncode,0);self.assertEqual((self.dest/'shell.qml').read_text(),source);self.assertEqual((self.dest/'notes.txt').read_text(),'personal addition')
 def test_preexisting_configuration_needs_explicit_backup(self):
  self.dest.mkdir();(self.dest/'old').write_text('untouched');self.assertNotEqual(self.call().returncode,0);self.assertEqual(self.call('--backup-conflicts').returncode,0);self.assertFalse((self.dest/'old').exists());self.assertEqual(self.call('--restore').returncode,0);self.assertEqual((self.dest/'old').read_text(),'untouched')
 def test_restore_preserves_unowned_symlink_without_reading_target(self):
  self.install();outside=self.root/'missing-private-target';link=self.dest/'personal-link';link.symlink_to(outside)
  self.assertEqual(self.call('--uninstall').returncode,0);self.assertEqual(self.call('--restore').returncode,0)
  self.assertTrue(link.is_symlink());self.assertEqual(os.readlink(link),str(outside));self.assertFalse(outside.exists())
 def test_owned_symlink_is_never_followed(self):
  self.install();outside=self.root/'outside';outside.write_text('outside');(self.dest/'shell.qml').unlink();(self.dest/'shell.qml').symlink_to(outside);self.assertNotEqual(self.call('--update','--force').returncode,0);self.assertEqual(outside.read_text(),'outside')
 def test_path_traversal_manifest_is_rejected(self):
  self.install();manifest=self.dest.parent/('.'+self.dest.name+'.illuminated.json');state=json.loads(manifest.read_text());state['files']['../victim']='hash';manifest.write_text(json.dumps(state));self.assertNotEqual(self.call('--uninstall','--force').returncode,0)
 def test_copy_failure_does_not_change_active_install(self):
  self.install();original=(self.dest/'shell.qml').read_text();deployment=module.Deployment(str(self.dest),True,source=ROOT/'quickshell')
  from unittest.mock import patch
  # Force a source revision so the update actually stages files.
  with patch.object(deployment,'source_files',return_value={'shell.qml':'new-revision'}),patch.object(module.shutil,'copy2',side_effect=OSError('injected copy failure')):
   with self.assertRaises(OSError):deployment.deploy(True,False,False)
  self.assertEqual((self.dest/'shell.qml').read_text(),original)
