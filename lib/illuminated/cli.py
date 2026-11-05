"""`illuminated` — the single entry point for running, configuring, installing and removing."""
from __future__ import annotations

import argparse
import json
import re
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from . import skin, config, generate, paths

ISOLATE = {"wallpaper": "wallpaper.qml", "chrome": "chrome-entry.qml", "cards": "cards-preview.qml", "launcher": "launcher.qml",
           "notifications": "notifications.qml",
           "media": "media.qml", "osd": "osd.qml",
           "prompts": "prompts.qml", "polkit": "polkit.qml", "lock": "lock.qml"}


def shell_qml(entry="shell.qml") -> str:
    # ILLUMINATED_CONFIG (a quickshell folder) is still honoured for side-by-side testing.
    folder = Path(os.environ["ILLUMINATED_CONFIG"]) if os.environ.get("ILLUMINATED_CONFIG") else paths.shell_dir()
    return str(folder / entry)


def launcher_path() -> str:
    """The command compositor files should run: the managed launcher when this is the installed copy."""
    installed = paths.install_dir().resolve()
    managed = paths.bin_dir() / "illuminated"
    if paths.project_root().resolve() == installed and managed.exists():
        return str(managed)
    return str(paths.project_root() / "scripts" / "illuminated")


def quickshell(*args):
    binary = shutil.which("quickshell")
    if not binary:
        sys.exit("illuminated: quickshell is not installed (see `illuminated doctor`)")
    os.execv(binary, ["quickshell", *args])


def ipc(*args):
    quickshell("ipc", "-p", shell_qml(), "call", "shell", *map(str, args))


def lock_screen() -> int:
    """Lock with the shell and return once the compositor confirms it; otherwise run the fallback.

    Never returns success unless a locker reports the screen as locked: the shell's
    `secure`, or the fallback's own exit status (swaylock --daemonize returns once locked)."""
    try:
        values = config.resolve_file().values
    except config.ConfigError:
        values = None
    settings = (values or {}).get("lock", {})
    fallback = settings.get("fallback") or ["swaylock", "--daemonize"]
    binary = shutil.which("quickshell")
    if values and values.get("features", {}).get("lock") and binary:
        call = [binary, "ipc", "-p", shell_qml(), "call", "lock"]
        def run(*args):
            try:
                return subprocess.run([*call, *args], capture_output=True, text=True, timeout=3)
            except (subprocess.TimeoutExpired, OSError):
                return None
        started = run("lock")
        if started is not None and started.returncode == 0:
            deadline = time.monotonic() + settings.get("timeout", 3000) / 1000
            while time.monotonic() < deadline:
                answer = run("status")
                try:
                    if answer is not None and json.loads(answer.stdout.strip() or "{}").get("secure"):
                        return 0
                except ValueError:
                    pass
                time.sleep(0.1)
            run("abandon")   # only drops a lock the compositor never confirmed
            print("illuminated lock: the shell did not confirm the lock; using the fallback", file=sys.stderr)
        else:
            print("illuminated lock: the shell is not answering; using the fallback", file=sys.stderr)
    try:
        os.execvp(fallback[0], fallback)
    except OSError as e:
        print(f"illuminated lock: cannot run {fallback[0]}: {e}", file=sys.stderr)
        return 1


# ── configuration ────────────────────────────────────────────────────────

def apply_config(launcher: str | None = None, check=False, diff=False) -> tuple[bool, list[str]]:
    try:
        resolved = config.resolve_file()
    except config.ConfigError as e:
        return False, [d.render() for d in e.diagnostics] + ["nothing written; the shell keeps the last good configuration"]
    messages = [d.render() for d in resolved.diagnostics]
    outputs = {"resolved.json": json.dumps(resolved.as_json(), indent=2, ensure_ascii=False) + "\n",
               **generate.everything(resolved.values, launcher or launcher_path())}
    directory = paths.generated_dir()
    changed = [name for name, text in outputs.items()
               if not (directory / name).exists() or (directory / name).read_text() != text]
    if diff:
        import difflib
        for name in changed:
            old = (directory / name).read_text().splitlines(True) if (directory / name).exists() else []
            sys.stdout.writelines(difflib.unified_diff(old, outputs[name].splitlines(True), name, name))
    if check:
        return True, messages + [f"valid; {len(changed)} generated file(s) would change"]
    directory.mkdir(parents=True, exist_ok=True)
    resolved_target = paths.resolved_json()
    for name, text in outputs.items():
        target = resolved_target if name == "resolved.json" else directory / name
        temporary = target.with_name(f".{target.name}.tmp")
        temporary.write_text(text)
        os.replace(temporary, target)
    messages += skin.merge(Path(shell_qml("skins/default")), user_skin_dir(resolved.values), directory / "skin")
    messages.append(f"applied {resolved.source or 'defaults'} → {directory}"
                    + (f" (compositor: {resolved.compositor})" if resolved.compositor else ""))
    if any(n in changed for n in ("hyprland.lua", "mango.conf")):
        messages.append("compositor files changed; reload your compositor to pick up binds/borders")
    return True, messages


def user_skin_dir(values) -> Path:
    path = (values.get("skin") or {}).get("path") or ""
    return Path(os.path.expanduser(path)) if path else paths.user_config().parent / "skin"


def _ensure_applied():
    target, source = paths.resolved_json(), paths.user_config()
    if not target.exists() or (source.exists() and source.stat().st_mtime > target.stat().st_mtime):
        ok, messages = apply_config()
        for m in messages:
            print(m, file=sys.stderr)


def watch():
    source = paths.user_config()
    last = None
    print(f"watching {source}; Ctrl+C to stop")
    while True:
        stamp = source.stat().st_mtime_ns if source.exists() else None
        if stamp != last:
            last = stamp
            ok, messages = apply_config()
            print(time.strftime("%H:%M:%S"), *messages, sep="\n  ")
        time.sleep(1)


def edit():
    source = paths.user_config()
    if not source.exists():
        from .install import STARTER
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(STARTER)
    editor = os.environ.get("VISUAL") or os.environ.get("EDITOR") or "nano"
    subprocess.call([*editor.split(), str(source)])
    ok, messages = apply_config()
    print(*messages, sep="\n")
    return 0 if ok else 1


# ── doctor ───────────────────────────────────────────────────────────────

def doctor() -> int:
    from .install import BEGIN, load_extras
    problems = 0

    def line(ok, text):
        nonlocal problems
        problems += 0 if ok else 1
        print(("  ok   " if ok else "  !!   ") + text)

    print("Locations")
    print(f"  program  {paths.project_root()}")
    print(f"  config   {paths.user_config()}{'' if paths.user_config().exists() else ' (absent: defaults only)'}")
    print(f"  output   {paths.generated_dir()}")
    try:
        resolved = config.resolve_file()
        line(True, "config.toml is valid")
        for d in resolved.diagnostics:
            print("  ..   " + d.render())
    except config.ConfigError as e:
        line(False, "config.toml has errors:")
        for d in e.diagnostics:
            print("         " + d.render())
        resolved = None
    target = paths.resolved_json()
    stale = not target.exists() or (paths.user_config().exists() and paths.user_config().stat().st_mtime > target.stat().st_mtime)
    line(not stale, "generated files are current" if not stale else "generated files are missing or stale; run `illuminated apply`")
    compositor = resolved.compositor if resolved else config.detect_compositor()
    print(f"Compositor: {compositor or 'not detected'}")
    extras = load_extras()
    for name in ("hyprland", "mango"):
        file = paths.compositor_config(name)
        if file.exists():
            present = BEGIN[name] in file.read_text()
            line(present or name != compositor, f"{name}: {file} {'loads' if present else 'does not load'} the generated file")
    values = resolved.values if resolved else config.shell_defaults()
    skin_dir = user_skin_dir(values)
    if skin_dir.is_dir():
        print(f"Your skin: {skin_dir} (docs/SKINS.md)")
        old = skin.old_format(skin_dir)
        line(not old, "QML skin" if not old else skin.OLD_FORMAT)
        merged = paths.generated_dir() / "skin"
        line(merged.is_dir(), "laid over the default skin (generated/skin)" if merged.is_dir() else "not laid over the default yet; run `illuminated apply`")
        # Your QML through qmllint, when it is installed: unknown types, missing imports, typos.
        lint = next((c for c in ("/usr/lib/qt6/bin/qmllint", "/usr/lib64/qt6/bin/qmllint") if Path(c).exists()), shutil.which("qmllint6") or shutil.which("qmllint"))
        mine = sorted(skin_dir.glob("*.qml"))
        if lint and mine and not old:
            import tempfile
            shell = Path(shell_qml(""))
            lint_problems = []
            with tempfile.TemporaryDirectory() as imports:
                # Quickshell resolves `import qs.skin` itself; qmllint needs a qs/ folder for it.
                (Path(imports) / "qs").mkdir()
                os.symlink(shell / "skin", Path(imports) / "qs" / "skin")
                # A real copy of the merged skin: qmllint follows symlinks, and your Rail.qml must
                # see the default's objects beside it, as the shell does.
                tree = Path(imports) / "skin"
                shutil.copytree(merged if merged.is_dir() else skin_dir, tree, symlinks=False,
                                ignore=lambda d, names: [n for n in names if not n.endswith(".qml") and not (Path(d) / n).is_dir()])
                for f in mine:
                    r = subprocess.run([lint, "-I", imports, "-I", "/usr/lib/qt6/qml", str(tree / f.name)], capture_output=True, text=True)
                    lint_problems += [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("Warning:") and ("is not a type" in l or "unresolved" in l or "Failed to import" in l or "not found" in l and "import" in l)]
            line(not lint_problems, "qmllint finds no unknown types or imports" + (f"; {len(lint_problems)}: " + "; ".join(lint_problems[:3]) if lint_problems else ""))
        elif not lint:
            print("  --   QML not checked (needs qmllint)")
    print("Commands")
    wanted = {"quickshell": True, "hyprctl": compositor == "hyprland", "mmsg": compositor == "mango",
              values["commands"]["lock"][0]: True, "systemctl": True, "brightnessctl": True, "wpctl": True,
              "nm-connection-editor": False, "blueman-manager": False,
              # v7: removable media (udisks2, systemd's busctl, udev), clipboard history.
              "udisksctl": bool(values["features"].get("media")), "busctl": bool(values["features"].get("media")),
              "udevadm": bool(values["features"].get("media")), "xdg-open": bool(values["features"].get("media")),
              "cliphist": False, "wl-copy": bool(values["features"].get("clipboard"))}
    for command, required in wanted.items():
        found = shutil.which(command)
        if found or required:
            line(bool(found), f"{command}: {found or 'missing'}")
        else:
            print(f"  --   {command}: missing (optional)")
    if shutil.which("quickshell"):
        print("  " + subprocess.run(["quickshell", "--version"], capture_output=True, text=True).stdout.strip())
    # The Charge card's Profile row reads power-profiles-daemon (a dependency); read-only check.
    if shutil.which("systemctl"):
        active = subprocess.run(["systemctl", "is-active", "power-profiles-daemon.service"],
                                capture_output=True, text=True).stdout.strip() == "active"
        line(active, "power-profiles-daemon is active" if active else
             "power-profiles-daemon is not active (Charge shows no real profile); "
             "install it and run `sudo systemctl enable --now power-profiles-daemon`")
    # Display faces (DESIGN.md §4): Qt silently substitutes a missing family.
    print("Fonts")
    if shutil.which("fc-list"):
        families = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True).stdout
        for key in ("blackletter", "legibility", "serif", "family"):
            name = values["typography"][key]
            line(name.lower() in families.lower(), f"{name} ({key})" + ("" if name.lower() in families.lower() else
                 " is not installed; get it from Google Fonts (OFL) into ~/.local/share/fonts, see docs/DEPENDENCIES.md"))
    else:
        print("  --   fc-list missing; fonts not checked")
    if str(paths.bin_dir()) not in os.environ.get("PATH", "").split(os.pathsep) and extras.get("launcher"):
        print(f"  ..   {paths.bin_dir()} is not on PATH (binds still work; terminals need it)")
    return 1 if problems else 0


def pending_upgrades() -> None:
    """Refuse to install packages onto a system with upgrades pending.

    `pacman -S` without `-u` is a partial upgrade. Quickshell builds against
    Qt's private API, so a newer quickshell on an older Qt (or a newer Qt base
    under older Qt modules) breaks at launch, not at install. `pacman -Qu` only
    reads the local sync database; it changes nothing. It exits 0 and lists
    packages when upgrades are pending, and exits 1 with no output when there
    are none.
    """
    result = subprocess.run(["pacman", "-Qu"], capture_output=True, text=True)
    pending = [line for line in result.stdout.splitlines() if line.strip()]
    if result.returncode == 1 and not pending:
        return
    if result.returncode == 0 and pending:
        shown = ", ".join(line.split()[0] for line in pending[:5]) + (" …" if len(pending) > 5 else "")
        raise ValueError(f"{len(pending)} system upgrade(s) pending ({shown}); run `sudo pacman -Syu` first, "
                         "then install again. Installing packages onto a partly upgraded system can break Qt.")
    raise ValueError("could not check for pending upgrades with `pacman -Qu` "
                     f"(exit {result.returncode}: {result.stderr.strip() or 'no output'}); nothing was installed")


# ── entry point ──────────────────────────────────────────────────────────

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="illuminated", description="Illuminated Desktop")
    sub = parser.add_subparsers(dest="command")
    for name, text in [("start", "start the shell"), ("stop", "stop the shell"), ("status", "shell status JSON"),
                       ("launcher", "toggle launcher"), ("hide", "close overlays"),
                       ("history", "notification history"), ("dnd", "toggle do-not-disturb"),
                       ("microphone", "toggle microphone mute"), ("watch", "re-apply whenever config.toml changes"),
                       ("minimize", "minimise the focused window (dock)"), ("clipboard", "clipboard history"),
                       ("media", "removable devices JSON"), ("lock", "lock the screen; returns once locked"),
                       ("edit", "edit config.toml, then apply"), ("doctor", "check the installation")]:
        sub.add_parser(name, help=text)
    p = sub.add_parser("defaults", help="print every option with its default")
    p.add_argument("--write-json", action="store_true", help=argparse.SUPPRESS)  # developer: regenerate defaults.json
    p = sub.add_parser("cards", help="open a group's deck"); p.add_argument("group", nargs="?", default="levels")
    p = sub.add_parser("volume"); p.add_argument("change", choices=["up", "down", "mute"])
    p = sub.add_parser("brightness"); p.add_argument("change", choices=["up", "down"])
    p = sub.add_parser("isolate", help="run one feature alone"); p.add_argument("feature", choices=sorted(ISOLATE))
    p = sub.add_parser("apply", help="validate config.toml and regenerate everything")
    p.add_argument("--check", action="store_true", help="validate only"); p.add_argument("--diff", action="store_true")
    p = sub.add_parser("install", help="install for Hyprland and/or Mango")
    p.add_argument("--compositor", choices=["auto", "hyprland", "mango", "both", "none"], default="auto")
    p.add_argument("--yes", action="store_true", help="allow the compositor config edit without asking")
    p.add_argument("--dry-run", action="store_true"); p.add_argument("--force", action="store_true")
    p.add_argument("--install-dependencies", action="store_true", help="Arch only: pacman -S --needed the runtime packages")
    p = sub.add_parser("restore", help="put back the program files replaced by the last install/update")
    p = sub.add_parser("uninstall", help="remove everything install added")
    p.add_argument("--purge", action="store_true", help="also remove config.toml and ui.json")
    p.add_argument("--dry-run", action="store_true"); p.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    command = args.command or "help"

    if command == "help":
        parser.print_help(); return 0
    if command == "start":
        _ensure_applied(); quickshell("-p", shell_qml(), "--no-duplicate")
    if command == "stop":
        quickshell("kill", "-p", shell_qml())
    if command == "isolate":
        _ensure_applied(); quickshell("-p", shell_qml(ISOLATE[args.feature]), "--no-duplicate")
    simple = {"launcher": ("toggleLauncher",), "hide": ("hide",),
              "status": ("status",), "history": ("history",), "dnd": ("dnd",), "microphone": ("microphone",),
              "minimize": ("minimize",), "clipboard": ("clipboard",), "media": ("media",)}
    if command in simple:
        ipc(*simple[command])
    if command == "lock":
        return lock_screen()
    if command == "cards":
        ipc("cards", args.group)
    if command == "volume":
        ipc(*({"up": ("volume", 0.05), "down": ("volume", -0.05), "mute": ("mute",)}[args.change]))
    if command == "brightness":
        ipc("brightness", 0.05 if args.change == "up" else -0.05)
    if command == "apply":
        ok, messages = apply_config(check=args.check, diff=args.diff)
        print(*messages, sep="\n", file=sys.stdout if ok else sys.stderr)
        return 0 if ok else 1
    if command == "watch":
        try: watch()
        except KeyboardInterrupt: return 0
    if command == "edit":
        return edit()
    if command == "defaults":
        if args.write_json:
            config.write_json(paths.shell_defaults_json(), config.shell_defaults())
            config.write_defaults_js(paths.shell_defaults_js(), config.shell_defaults())
            config.write_reading_options(paths.shell_dir() / "config/Reading.js"); return 0
        sys.stdout.write(paths.defaults_toml().read_text()); return 0
    if command == "doctor":
        return doctor()
    if command == "restore":
        from .deploy import Deployment
        from .install import payload
        try:
            Deployment(str(paths.install_dir()), False, source=paths.project_root(), payload=payload).restore(False)
        except (ValueError, OSError) as e:
            print(f"restore refused: {e}", file=sys.stderr); return 1
        print(f"restored the previous program files in {paths.install_dir()}"); return 0
    if command in ("install", "uninstall"):
        from . import install
        try:
            if command == "install" and args.install_dependencies and not args.dry_run:
                packages = ["quickshell", "qt6-declarative", "brightnessctl", "swaylock", "power-profiles-daemon",
                            "udisks2", "wl-clipboard", "cliphist", "xdg-utils"]
                if not shutil.which("pacman"):
                    raise ValueError("automatic dependencies support Arch (pacman) only; see docs/DEPENDENCIES.md")
                pending_upgrades()
                subprocess.run(["sudo", "pacman", "-S", "--needed", *packages], check=True)
            if command == "install":
                choice = args.compositor
                if choice == "auto":
                    detected = config.detect_compositor()
                    targets = [detected] if detected else [c for c in install.COMPOSITORS if paths.compositor_config(c).exists()]
                else:
                    targets = {"both": list(install.COMPOSITORS), "none": []}.get(choice, [choice])
                report = install.install(targets, args.yes, args.dry_run, args.force)
            else:
                report = install.uninstall(args.purge, args.dry_run, args.force)
        except (ValueError, OSError, subprocess.CalledProcessError) as e:
            print(f"{command} refused: {e}", file=sys.stderr); return 1
        print(*report, sep="\n"); return 0
    return 0
