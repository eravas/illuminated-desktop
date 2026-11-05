"""QML skins (docs/SKINS.md): lay your skin's files over the default skin's, by name.

`illuminated apply` builds generated/skin/: a symlink to every file of the default skin, then
your skin's files in their place (and any it adds). The shell loads Rail.qml, DockChrome.qml
and Cards.qml from there, so `Vial.qml` in your skin replaces only the vial. Symlinks keep your
edits live; a file you add or remove needs another apply. A skin in the pre-QML format
(skin.json with elements, rail.items or dock lists) is ignored as a whole, with a warning.
"""
from __future__ import annotations

import json
import os
import shutil
from pathlib import Path

OLD_FORMAT = "skin.json is in the old skin format (elements, rail.items, dock); it is ignored and the default skin is used. See docs/SKINS.md."


def old_format(skin_dir: Path) -> bool:
    try:
        data = json.loads((skin_dir / "skin.json").read_text())
    except (OSError, ValueError):
        return False
    if not isinstance(data, dict):
        return False
    rail, dock = data.get("rail") or {}, data.get("dock") or {}
    return ("elements" in data or (isinstance(rail, dict) and "items" in rail)
            or (isinstance(dock, dict) and ("before" in dock or "after" in dock)))


def files(directory: Path) -> dict[str, Path]:
    """Every file under directory, by its path relative to it (hidden files skipped)."""
    out = {}
    if directory.is_dir():
        for path in sorted(directory.rglob("*")):
            rel = path.relative_to(directory)
            if path.is_file() and not any(part.startswith(".") for part in rel.parts):
                out[rel.as_posix()] = path
    return out


def merge(default_dir: Path, user_dir: Path | None, out_dir: Path) -> list[str]:
    """Build out_dir; return messages (warnings) for the user."""
    messages = []
    use_user = user_dir is not None and user_dir.is_dir()
    if use_user and old_format(user_dir):
        messages.append(f"warning: {user_dir / 'skin.json'}: {OLD_FORMAT}")
        use_user = False
    layers = files(default_dir)
    if use_user:
        layers.update(files(user_dir))
    temporary = out_dir.with_name(f".{out_dir.name}.tmp")
    shutil.rmtree(temporary, ignore_errors=True)
    for rel, source in layers.items():
        link = temporary / rel
        link.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(source.resolve(), link)
    shutil.rmtree(out_dir, ignore_errors=True)
    if temporary.exists():
        os.replace(temporary, out_dir)
    return messages
