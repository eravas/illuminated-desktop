#!/usr/bin/env python3
"""Discover installed Wayland session metadata without a shell or fixed session list.
Production accepts only root-owned, non-writable metadata and ancestor directories.
--fixtures exists solely for unprivileged protocol tests and must not be used by greetd."""
import argparse,configparser,json,os,pathlib,shlex,shutil,stat,sys

def trusted(path):
    for part in [path.resolve(),*path.resolve().parents]:
        value=part.stat()
        if value.st_uid!=0 or value.st_mode & 0o022:return False
    return True

def discover(directories,fixtures=False):
    sessions=[];seen=set()
    for directory in directories:
        root=pathlib.Path(directory)
        if not root.is_dir() or (not fixtures and not trusted(root)):continue
        for file in sorted(root.glob('*.desktop')):
            if file.name in seen or (not fixtures and not trusted(file)):continue
            parser=configparser.ConfigParser(interpolation=None,strict=False)
            try:
                parser.read(file,encoding='utf-8');entry=parser['Desktop Entry']
                if entry.get('Type','Application')!='Application' or entry.get('Hidden','false').lower()=='true' or entry.get('NoDisplay','false').lower()=='true':continue
                argv=shlex.split(entry.get('Exec',''));name=entry.get('Name',file.stem);desktop=entry.get('DesktopNames','').rstrip(';')
                if not argv or not any(t in (name+' '+desktop+' '+file.stem+' '+argv[0]).lower() for t in ['hyprland','mango']):continue
                check=entry.get('TryExec',argv[0])
                if not shutil.which(check) or not shutil.which(argv[0]):continue
                cleaned=[]
                for argument in argv:
                    if argument in ('%f','%F','%u','%U','%i'):continue
                    argument=argument.replace('%%','\0').replace('%k',str(file)).replace('%c',name)
                    if '%' in argument:raise ValueError('Unsupported Exec field code')
                    cleaned.append(argument.replace('\0','%'))
                sessions.append({'id':file.name,'name':name,'command':cleaned,'desktop':desktop or ('mango' if 'mango' in name.lower() else 'Hyprland')})
                seen.add(file.name)
            except (OSError,ValueError,KeyError,configparser.Error):continue
    return sessions
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--directory',action='append');p.add_argument('--fixtures',action='store_true');a=p.parse_args()
    print(json.dumps(discover(a.directory or ['/usr/local/share/wayland-sessions','/usr/share/wayland-sessions'],a.fixtures)))
