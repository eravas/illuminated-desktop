"""Install and remove the whole desktop with one command each.

install    copies the program to ~/.local/share/illuminated (ownership manifest),
           writes the ~/.local/bin/illuminated launcher, creates a starter
           config.toml if none exists, runs `apply`, and — with consent — adds
           one marked block to your compositor config that loads the generated
           file. Nothing else in your compositor config is touched.
uninstall  removes the marked block (restoring the file byte for byte), the
           launcher, generated files and the managed program files. Your
           config.toml and ui.json stay unless --purge.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import os
import shutil
import sys
import time
from pathlib import Path

from . import paths
from .deploy import Deployment, atomic_json

BEGIN = {"hyprland": "-- >>> illuminated (added by `illuminated install`; `illuminated uninstall` removes it)",
         "mango": "# >>> illuminated (added by `illuminated install`; `illuminated uninstall` removes it)"}
END = {"hyprland": "-- <<< illuminated", "mango": "# <<< illuminated"}
COMPOSITORS = ("hyprland", "mango")
PAYLOAD_DIRS = ("quickshell", "lib/illuminated", "config", "integration/greetd")
PAYLOAD_FILES = ("scripts/illuminated", "README.md", "CHANGELOG.md", "docs/CONFIGURATION.md")


def payload(root: Path):
    for name in PAYLOAD_FILES:
        if (root / name).is_file():
            yield root / name
    for directory in PAYLOAD_DIRS:
        for file in sorted((root / directory).rglob("*")):
            if "__pycache__" in file.parts or file.suffix == ".pyc":
                continue
            yield file


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def extras_path() -> Path:
    return paths.install_dir().parent / ".illuminated.extras.json"


def load_extras() -> dict:
    path = extras_path()
    return json.loads(path.read_text()) if path.exists() else {"version": 1, "launcher": None, "blocks": {}}


def launcher_text(install: Path) -> str:
    target = str(install / "scripts" / "illuminated").replace("'", "'\\''")
    return ("#!/bin/sh\n# Managed by `illuminated install`; removed by `illuminated uninstall`.\n"
            f"exec python3 -B '{target}' \"$@\"\n")


def block(compositor: str) -> str:
    generated = str(paths.generated_dir() / f"{compositor}.{'lua' if compositor == 'hyprland' else 'conf'}")
    if compositor == "hyprland":
        quoted = generated.replace("\\", "\\\\").replace('"', '\\"')
        # Hyprland 0.57 opens the standard Lua libraries, so dofile exists; loadfile
        # stays as a fallback. pcall keeps Hyprland starting if the file is missing.
        # Evidence: docs/evidence/compositor-includes/.
        body = (f'do local run = dofile or function(p) return assert(loadfile(p))() end '
                f'local ok, err = pcall(run, "{quoted}") '
                'if not ok then print("illuminated: " .. tostring(err)) end end')
    else:
        # source_optional skips a missing file instead of failing (Mango 0.18.4
        # parses it with must_exist = false); the Mango equivalent of pcall above.
        body = f"source_optional={generated}"
    return f"{BEGIN[compositor]}\n{body}\n{END[compositor]}\n"


def with_block(text: str, compositor: str) -> tuple[str, bool]:
    """Return text containing exactly one current block, and whether a newline was added."""
    stripped, _ = without_block(text, compositor, False)
    added = bool(stripped) and not stripped.endswith("\n")
    return stripped + ("\n" if added else "") + block(compositor), added


def without_block(text: str, compositor: str, added_newline: bool) -> tuple[str, bool]:
    lines = text.splitlines(keepends=True)
    try:
        start = next(i for i, l in enumerate(lines) if l.rstrip("\n") == BEGIN[compositor])
        end = next(i for i in range(start, len(lines)) if lines[i].rstrip("\n") == END[compositor])
    except StopIteration:
        return text, False
    result = "".join(lines[:start] + lines[end + 1:])
    if added_newline and end == len(lines) - 1 and result.endswith("\n"):
        result = result[:-1]
    return result, True


def _confirm(question: str, yes: bool) -> bool:
    if yes:
        return True
    if not sys.stdin.isatty():
        print(f"{question} — skipped (not interactive; pass --yes to allow)")
        return False
    return input(f"{question} [y/N] ").strip().lower() in ("y", "yes")


def _backup(file: Path) -> Path:
    backups = paths.install_dir().parent / ".illuminated-backups"
    backups.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = backups / f"{file.name}.{time.strftime('%Y%m%dT%H%M%S')}"
    shutil.copy2(file, target)
    return target


def integrate(compositor: str, extras: dict, yes: bool, dry: bool) -> str:
    file = paths.compositor_config(compositor)
    if not file.exists():
        return f"{compositor}: no {file}; start {compositor} once (or create the file), then run `illuminated install` again"
    if file.is_symlink():
        resolved = file.resolve()
        print(f"{compositor}: {file} is a symlink to {resolved}; editing the target")
        file = resolved
    before = file.read_text()
    after, added = with_block(before, compositor)
    if after == before:
        return f"{compositor}: already integrated"
    diff = "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), str(file), str(file)))
    print(diff)
    if dry:
        return f"{compositor}: would add the block above"
    if not _confirm(f"Add this block to {file}?", yes):
        return f"{compositor}: not integrated; add the block above yourself if you prefer"
    backup = _backup(file)
    temporary = file.with_name(f".{file.name}.illuminated-tmp")
    temporary.write_text(after)
    shutil.copymode(file, temporary)
    os.replace(temporary, file)
    previous = extras["blocks"].get(compositor, {})
    extras["blocks"][compositor] = {"file": str(file), "added_newline": added or previous.get("added_newline", False),
                                    "backup": str(backup)}
    return f"{compositor}: integrated {file} (backup {backup})"


def disintegrate(compositor: str, record: dict, dry: bool) -> str:
    file = Path(record["file"])
    if not file.exists():
        return f"{compositor}: {file} no longer exists"
    before = file.read_text()
    after, found = without_block(before, compositor, record.get("added_newline", False))
    if not found:
        return f"{compositor}: block already absent from {file}"
    if dry:
        return f"{compositor}: would remove the illuminated block from {file}"
    temporary = file.with_name(f".{file.name}.illuminated-tmp")
    temporary.write_text(after)
    shutil.copymode(file, temporary)
    os.replace(temporary, file)
    return f"{compositor}: removed block from {file}"


STARTER = """\
# Illuminated Desktop — your configuration.
#
# Only write what you want to change; everything else comes from the packaged
# defaults. See every option, with comments:   illuminated defaults
# After editing:                               illuminated apply
# (or keep `illuminated watch` running, or use `illuminated edit`)
#
# Tables merge key by key; arrays replace. Examples:
#
# [appearance]
# mode = "light"
#
# [reading]
# preset = "legibility"
#
# [rail]
# hands = ["levels", "connections", "power"]
#
# [groups.power]
# cards = ["suspend", "poweroff"]      # drop Reboot from the hand
#
# [binds]
# "SUPER+A" = "cards sound"
# "SUPER+SHIFT+Q" = ""          # drop a default bind
#
# [host.my-laptop]              # only on the machine named my-laptop
# hardware.backlightDevice = "intel_backlight"
"""


def install(compositors, yes=False, dry=False, force=False, update=None) -> list[str]:
    report = []
    dest = paths.install_dir()
    root = paths.project_root()
    if root.resolve() == dest.resolve():
        raise ValueError("Run install from the source tree, not from the installed copy (use `illuminated install` from the project)")
    deployment = Deployment(str(dest), force, source=root, payload=payload)
    active = bool(deployment.state and deployment.state.get("status") == "active")
    plan = deployment.deploy(update=active if update is None else update, backup_conflicts=False, dry=dry)
    report.append(f"program: {plan.get('result', plan['action'])} → {dest} ({plan['files']} files)")
    extras = load_extras()
    launcher = paths.bin_dir() / "illuminated"
    text = launcher_text(dest)
    owned = extras.get("launcher") and launcher.exists() and _sha(launcher.read_text()) == extras["launcher"]["sha"]
    if launcher.exists() and not owned and not force:
        report.append(f"launcher: {launcher} exists and is not ours; left alone (use --force to replace)")
    elif not dry:
        launcher.parent.mkdir(parents=True, exist_ok=True)
        launcher.write_text(text)
        launcher.chmod(0o755)
        extras["launcher"] = {"path": str(launcher), "sha": _sha(text)}
        report.append(f"launcher: {launcher}")
    config = paths.user_config()
    if not config.exists() and not dry:
        config.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        config.write_text(STARTER)
        report.append(f"config: created {config}")
    else:
        report.append(f"config: {config} ({'kept' if config.exists() else 'would create'})")
    if not dry:
        from .cli import apply_config
        ok, messages = apply_config(launcher=str(launcher))
        report.extend("apply: " + m for m in messages)
        if not ok:
            report.append("apply failed; fix config.toml and run `illuminated apply`")
    for compositor in compositors:
        report.append(integrate(compositor, extras, yes, dry))
    if not dry:
        atomic_json(extras_path(), extras)
    if str(paths.bin_dir()) not in os.environ.get("PATH", "").split(os.pathsep):
        report.append(f"note: {paths.bin_dir()} is not on PATH; compositor binds use the full path, but add it for your terminal")
    return report


def uninstall(purge=False, dry=False, force=False) -> list[str]:
    report = []
    extras = load_extras()
    dest = paths.install_dir()
    deployment = Deployment(str(dest), force, source=paths.project_root(), payload=payload)
    program_active = bool(deployment.state and deployment.state.get("status") == "active")
    if program_active:
        # Refuse before anything is removed: a dry run raises on hand-changed
        # program files, so a refusal leaves the hook, launcher and generated
        # files in place and `illuminated uninstall --force` still works.
        deployment.uninstall(True)
    for compositor, record in list(extras.get("blocks", {}).items()):
        report.append(disintegrate(compositor, record, dry))
        if not dry:
            extras["blocks"].pop(compositor)
    launcher_record = extras.get("launcher")
    if launcher_record:
        launcher = Path(launcher_record["path"])
        if launcher.exists() and _sha(launcher.read_text()) != launcher_record["sha"] and not force:
            report.append(f"launcher: {launcher} was modified; left alone (use --force)")
        elif not dry:
            launcher.unlink(missing_ok=True)
            extras["launcher"] = None
            report.append(f"launcher: removed {launcher}")
    generated = paths.generated_dir()
    if generated.exists():
        if not dry:
            shutil.rmtree(generated)
        report.append(f"generated: removed {generated}")
    if program_active:
        deployment.uninstall(dry)
        report.append(f"program: removed managed files from {dest}")
    if dest.exists() and not dry:
        for directory in sorted((d for d in dest.rglob("*") if d.is_dir() and not d.is_symlink()), key=lambda d: len(d.parts), reverse=True):
            try: directory.rmdir()
            except OSError: pass
        try: dest.rmdir()
        except OSError: report.append(f"program: kept unowned files in {dest}")
    backups = dest.parent / ".illuminated-backups"
    if purge:
        for leftover in (backups, deployment.statepath, extras_path()):
            if leftover.exists() and not dry:
                shutil.rmtree(leftover) if leftover.is_dir() else leftover.unlink()
        report.append("purge: removed backups and install records")
        extras = None
    elif backups.exists():
        report.append(f"backups kept in {backups} (use --purge to remove)")
    if purge:
        for file in (paths.user_config(), paths.ui_state()):
            if file.exists():
                if not dry:
                    file.unlink()
                report.append(f"purge: removed {file}")
        if not dry and paths.user_dir().exists() and not any(paths.user_dir().iterdir()):
            paths.user_dir().rmdir()
    else:
        report.append(f"kept your settings in {paths.user_dir()} (use --purge to remove)")
    if not dry and extras is not None:
        atomic_json(extras_path(), extras)
    return report
