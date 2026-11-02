"""Ownership-manifest deployment of a directory tree (moved from scripts/install.py).

Installs a copy, records a digest per file, refuses to overwrite local changes
without --force, keeps a snapshot of whatever it replaces, and removes only the
files it owns. Used by `illuminated install` for ~/.local/share/illuminated.
"""
import hashlib, json, os, pathlib, shutil, tempfile, time, uuid
from . import paths
P=pathlib.Path
RELEASE='illuminated-v3'

def digest(path):
    if path.is_symlink() or not path.is_file(): return None
    return hashlib.sha256(path.read_bytes()).hexdigest()

def atomic_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile('w',dir=path.parent,delete=False) as f:
        json.dump(value,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno());temporary=P(f.name)
    os.chmod(temporary,0o600);os.replace(temporary,path)

def relative(value):
    p=pathlib.PurePosixPath(value)
    if p.is_absolute() or '..' in p.parts or not p.parts: raise ValueError('Unsafe manifest path')
    return p

def check_link_parents(root,path):
    current=root
    for part in relative(path).parts:
        current=current/part
        if current.is_symlink():raise ValueError('Refusing managed symlink: '+str(current))

class Deployment:
    def __init__(self,destination,force=False,source=None,payload=None):
        if not destination or P(destination).expanduser().absolute()==P('/'):raise ValueError('Choose a new configuration directory, not / or an empty path')
        self.dest=P(destination).expanduser().absolute();self.force=force
        self.statepath=self.dest.parent/('.'+self.dest.name+'.illuminated.json')
        self.backups=self.dest.parent/'.illuminated-backups'
        if self.dest.is_symlink() or self.statepath.is_symlink() or self.backups.is_symlink():raise ValueError('Refusing installation, state or backup symlink')
        self.source=P(source) if source else paths.shell_dir()
        self.payload=payload or (lambda root: [f for f in root.rglob('*')])
        self.state=None
        if self.statepath.exists():
            self.state=json.loads(self.statepath.read_text())
            if self.state.get('version')!=1 or self.state.get('destination')!=str(self.dest):raise ValueError('Manifest does not match this installation')
            for path in self.state.get('files',{}):relative(path)
    def conflicts(self):
        return [name for name,sha in (self.state or {}).get('files',{}).items() if digest(self.dest/name)!=sha]
    def source_files(self):
        files={}
        for file in self.payload(self.source):
            if file.is_symlink():raise ValueError('Source symlinks are not deployed')
            if file.is_file():files[file.relative_to(self.source).as_posix()]=digest(file)
        return files
    def snapshot(self):
        self.backups.mkdir(mode=0o700,parents=True,exist_ok=True)
        name=time.strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex[:10]
        # Sidecar has no recursive embedded snapshots; older snapshots remain addressable.
        atomic_json(self.backups/(name+'.json'),self.state)
        return name
    def commit(self,stage,state):
        backup=self.snapshot() if self.dest.exists() else None
        if backup:os.replace(self.dest,self.backups/backup)
        try:
            os.replace(stage,self.dest)
            state['backups']=(self.state or {}).get('backups',[])+([backup] if backup else [])
            state['last_backup']=backup or (self.state or {}).get('last_backup')
            atomic_json(self.statepath,state)
        except BaseException:
            if self.dest.exists():os.replace(self.dest,stage)
            if backup:os.replace(self.backups/backup,self.dest)
            raise
        self.state=state
    def deploy(self,update,backup_conflicts,dry):
        files=self.source_files()
        if self.dest.exists() and not update and not backup_conflicts:raise ValueError('Existing destination refused. Use a new directory, --update for managed installs, or explicit --backup-conflicts')
        if update and (not self.state or self.state.get('status')!='active'):raise ValueError('Update requires an active ownership manifest')
        changes=self.conflicts() if update else []
        if changes and not self.force:raise ValueError('Locally changed/missing managed files: '+', '.join(changes)+'. Restore them or use --force after reviewing the backup policy.')
        if update:
            for name in files:
                check_link_parents(self.dest,name)
                if (self.dest/name).exists() and name not in self.state['files'] and not self.force:raise ValueError('Unowned file conflict: '+name)
        plan={'action':'update' if update else 'install','destination':str(self.dest),'files':len(files),'backup_existing':self.dest.exists(),'manifest':str(self.statepath)}
        if dry:return plan
        if update and files==self.state['files'] and not changes:return {**plan,'result':'already up to date'}
        self.dest.parent.mkdir(parents=True,exist_ok=True)
        stage=P(tempfile.mkdtemp(prefix='.illuminated-stage-',dir=self.dest.parent))
        try:
            if update:shutil.copytree(self.dest,stage,dirs_exist_ok=True,symlinks=True)
            for old in (self.state or {}).get('files',{}) if update else []:
                if old not in files and (stage/old).exists():check_link_parents(stage,old);(stage/old).unlink()
            for name in files:
                target=stage/name;check_link_parents(stage,name);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(self.source/name,target)
            state={'version':1,'destination':str(self.dest),'status':'active','files':files,'release':RELEASE,'source':str(self.source)}
            self.commit(stage,state)
        finally:
            if stage.exists():shutil.rmtree(stage)
        return {**plan,'result':'deployed'}
    def uninstall(self,dry):
        if not self.state or self.state.get('status')!='active':raise ValueError('No active ownership manifest')
        modified=self.conflicts()
        if modified and not self.force:raise ValueError('Uninstall would encounter local changes; review them, or use --force to preserve a snapshot and remove managed files')
        plan={'action':'uninstall','destination':str(self.dest),'managed_files':len(self.state['files']),'preserve_unowned':True}
        if dry:return plan
        stage=P(tempfile.mkdtemp(prefix='.illuminated-stage-',dir=self.dest.parent))
        try:
            if self.dest.exists():shutil.copytree(self.dest,stage,dirs_exist_ok=True,symlinks=True)
            for name in self.state['files']:
                check_link_parents(stage,name)
                if (stage/name).is_file():(stage/name).unlink()
            for directory in sorted((x for x in stage.rglob('*') if x.is_dir() and not x.is_symlink()),key=lambda x:len(x.parts),reverse=True):
                try:directory.rmdir()
                except OSError:pass
            self.commit(stage,{'version':1,'destination':str(self.dest),'status':'uninstalled','files':{}})
        finally:
            if stage.exists():shutil.rmtree(stage)
        return plan
    def restore(self,dry):
        name=(self.state or {}).get('last_backup')
        if not name or P(name).name!=name:raise ValueError('No valid backup to restore')
        backup=self.backups/name
        if backup.is_symlink() or not backup.is_dir():raise ValueError('Backup missing or unsafe')
        prior=json.loads((self.backups/(name+'.json')).read_text())
        if self.conflicts() and not self.force:raise ValueError('Current managed files changed; refusing restore without --force')
        plan={'action':'restore','destination':str(self.dest),'backup':name}
        if dry:return plan
        stage=P(tempfile.mkdtemp(prefix='.illuminated-stage-',dir=self.dest.parent))
        try:
            shutil.copytree(backup,stage,dirs_exist_ok=True,symlinks=True)
            # Preserve files outside the ownership manifest, including personal additions.
            for file in self.dest.rglob('*'):
                rel=file.relative_to(self.dest).as_posix()
                if (file.is_file() or file.is_symlink()) and rel not in self.state.get('files',{}):
                    if rel in (prior or {}).get('files',{}) and not self.force:raise ValueError('Unowned addition conflicts with restored implementation: '+rel)
                    # Preserve an unowned link itself; never read its target during restoration.
                    target=stage/rel
                    check_link_parents(stage,str(pathlib.PurePosixPath(rel).parent)) if pathlib.PurePosixPath(rel).parent != pathlib.PurePosixPath('.') else None
                    target.parent.mkdir(parents=True,exist_ok=True)
                    if target.is_symlink():target.unlink()
                    if file.is_symlink():
                        if target.exists():target.unlink()
                        target.symlink_to(os.readlink(file))
                    else:shutil.copy2(file,target)
            restored=prior or {'version':1,'destination':str(self.dest),'status':'restored-unmanaged','files':{}}
            self.commit(stage,restored)
        finally:
            if stage.exists():shutil.rmtree(stage)
        return plan

