"""Every filesystem location the project uses, in one place.

User-owned:   ~/.config/illuminated/config.toml   (you edit this)
              ~/.config/illuminated/ui.json       (the shell's own saved choices)
Generated:    ~/.config/illuminated/generated/    (rewritten by `illuminated apply`)
Installed:    ~/.local/share/illuminated/         (managed program files)
              ~/.local/bin/illuminated            (managed launcher)
The QML side computes the resolved.json and ui.json paths the same way
(quickshell/config/Settings.qml); keep both in step.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _xdg(variable: str, fallback: str) -> Path:
    value = os.environ.get(variable)
    return Path(value) if value and os.path.isabs(value) else Path.home() / fallback


def project_root() -> Path:
    return ROOT


def defaults_toml() -> Path:
    return ROOT / "config" / "defaults.toml"


def shell_dir() -> Path:
    return ROOT / "quickshell"


def shell_defaults_json() -> Path:
    return shell_dir() / "config" / "defaults.json"


def shell_defaults_js() -> Path:
    """The same defaults as a JS module: the shell imports it synchronously."""
    return shell_dir() / "config" / "defaults.js"


def config_home() -> Path:
    return _xdg("XDG_CONFIG_HOME", ".config")


def user_dir() -> Path:
    return config_home() / "illuminated"


def user_config() -> Path:
    return Path(os.environ["ILLUMINATED_CONFIG_FILE"]) if os.environ.get("ILLUMINATED_CONFIG_FILE") else user_dir() / "config.toml"


def ui_state() -> Path:
    return user_dir() / "ui.json"


def generated_dir() -> Path:
    return user_dir() / "generated"


def resolved_json() -> Path:
    return Path(os.environ["ILLUMINATED_RESOLVED"]) if os.environ.get("ILLUMINATED_RESOLVED") else generated_dir() / "resolved.json"


def install_dir() -> Path:
    return _xdg("XDG_DATA_HOME", ".local/share") / "illuminated"


def bin_dir() -> Path:
    return Path.home() / ".local" / "bin"


def compositor_config(name: str) -> Path:
    return {"hyprland": config_home() / "hypr" / "hyprland.lua",
            "mango": config_home() / "mango" / "config.conf"}[name]

