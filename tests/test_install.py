"""Install/uninstall round trips in a throwaway HOME; never touches this host's files."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = ROOT / "scripts" / "illuminated"
sys.path.insert(0, str(ROOT / "lib"))
from illuminated import config, generate, install  # noqa: E402

HYPR = "-- my hyprland config\nhl.bind(\"SUPER + RETURN\", hl.dsp.exec_cmd(\"foot\"))"   # no trailing newline
MANGO = "# my mango config\nbind=SUPER,Return,spawn,foot\n"


class Home(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="illuminated home ")
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name)
        self.env = {"HOME": str(self.home), "PATH": os.environ["PATH"], "LANG": "C.UTF-8"}

    def run_cli(self, *args, check=True):
        result = subprocess.run([sys.executable, str(CLI), *args], env=self.env, capture_output=True, text=True,
                                stdin=subprocess.DEVNULL)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def write(self, rel, text):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path


class RoundTrip(Home):
    def round_trip(self, compositor, rel, original):
        target = self.write(rel, original)
        out = self.run_cli("install", "--compositor", compositor, "--yes").stdout
        self.assertIn(f"{compositor}: integrated", out)
        share = self.home / ".local/share/illuminated"
        self.assertTrue((share / "quickshell/shell.qml").is_file())
        self.assertTrue((share / "lib/illuminated/cli.py").is_file())
        launcher = self.home / ".local/bin/illuminated"
        self.assertTrue(os.access(launcher, os.X_OK))
        generated = self.home / ".config/illuminated/generated"
        for name in ("resolved.json", "hyprland.lua", "mango.conf", "foot.ini", "kitty.conf", "gtk.css"):
            self.assertTrue((generated / name).is_file(), name)
        self.assertIn(str(launcher), (generated / f"{compositor}.{'lua' if compositor == 'hyprland' else 'conf'}").read_text())
        self.assertTrue((self.home / ".config/illuminated/config.toml").is_file())
        text = target.read_text()
        self.assertTrue(text.startswith(original))
        self.assertEqual(text.count(install.BEGIN[compositor]), 1)
        guard = "pcall(run, " if compositor == "hyprland" else "\nsource_optional="
        self.assertIn(guard, text, "a missing generated file must not break the compositor config")
        # Second install is idempotent: one block, file unchanged.
        self.run_cli("install", "--compositor", compositor, "--yes")
        self.assertEqual(target.read_text(), text)
        # The installed launcher works on its own (no source tree, no env vars).
        result = subprocess.run([str(launcher), "apply", "--check"], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.run_cli("uninstall")
        self.assertEqual(target.read_text(), original, "compositor config must be byte-identical after uninstall")
        self.assertFalse(launcher.exists())
        self.assertFalse(generated.exists())
        self.assertFalse((share / "quickshell/shell.qml").exists())
        self.assertTrue((self.home / ".config/illuminated/config.toml").exists(), "settings kept without --purge")
        self.run_cli("uninstall", "--purge")
        self.assertFalse((self.home / ".config/illuminated").exists())
        leftovers = [p for p in (self.home / ".local/share").rglob("*")]
        self.assertEqual(leftovers, [], "--purge must leave no trace")

    def test_hyprland(self):
        self.round_trip("hyprland", ".config/hypr/hyprland.lua", HYPR)

    def test_mango(self):
        self.round_trip("mango", ".config/mango/config.conf", MANGO)

    def test_dry_run_writes_nothing(self):
        self.write(".config/hypr/hyprland.lua", HYPR)
        self.run_cli("install", "--compositor", "hyprland", "--dry-run")
        self.assertFalse((self.home / ".local").exists())
        self.assertEqual((self.home / ".config/hypr/hyprland.lua").read_text(), HYPR)
        self.assertFalse((self.home / ".config/illuminated").exists())

    def test_no_consent_no_edit(self):
        target = self.write(".config/mango/config.conf", MANGO)
        out = self.run_cli("install", "--compositor", "mango").stdout   # stdin is not a tty
        self.assertIn("skipped", out)
        self.assertEqual(target.read_text(), MANGO)

    def test_missing_compositor_config_is_not_created(self):
        out = self.run_cli("install", "--compositor", "hyprland", "--yes").stdout
        self.assertIn("no ", out)
        self.assertFalse((self.home / ".config/hypr").exists())

    def test_foreign_launcher_is_left_alone(self):
        self.write(".local/bin/illuminated", "#!/bin/sh\necho mine\n")
        out = self.run_cli("install", "--compositor", "none").stdout
        self.assertIn("not ours", out)
        self.assertEqual((self.home / ".local/bin/illuminated").read_text(), "#!/bin/sh\necho mine\n")
        self.run_cli("uninstall")
        self.assertTrue((self.home / ".local/bin/illuminated").exists())

    def test_refused_uninstall_removes_nothing(self):
        target = self.write(".config/hypr/hyprland.lua", HYPR)
        self.run_cli("install", "--compositor", "hyprland", "--yes")
        installed = target.read_text()
        share = self.home / ".local/share/illuminated"
        launcher = self.home / ".local/bin/illuminated"
        generated = self.home / ".config/illuminated/generated"
        edited = share / "quickshell/shell.qml"
        edited.write_text(edited.read_text() + "// local edit\n")
        for args in (("uninstall",), ("uninstall", "--purge")):
            result = self.run_cli(*args, check=False)
            self.assertNotEqual(result.returncode, 0, args)
            self.assertIn("local changes", result.stdout + result.stderr)
            self.assertEqual(target.read_text(), installed, "hook must stay until uninstall can finish")
            self.assertTrue(launcher.exists())
            self.assertTrue(generated.exists())
            self.assertTrue((self.home / ".config/illuminated/config.toml").exists())
            self.assertIn("// local edit", edited.read_text())
        result = subprocess.run([str(launcher), "uninstall", "--force"], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_text(), HYPR)
        self.assertFalse(launcher.exists())
        self.assertFalse(generated.exists())
        self.assertFalse(edited.exists())

    def test_user_text_around_block_survives(self):
        target = self.write(".config/mango/config.conf", MANGO)
        self.run_cli("install", "--compositor", "mango", "--yes")
        target.write_text(target.read_text() + "bind=SUPER,e,spawn,thunar\n")   # user adds after the block
        self.run_cli("uninstall")
        self.assertEqual(target.read_text(), MANGO + "bind=SUPER,e,spawn,thunar\n")


class Dependencies(Home):
    """`--install-dependencies` with stand-in pacman/sudo; no real package is touched."""

    def fake_pacman(self, qu_exit, qu_output=""):
        bin_dir = self.home / "fakebin"
        bin_dir.mkdir()
        log = self.home / "pacman.log"
        (bin_dir / "pacman").write_text(
            "#!/bin/sh\n"
            f'echo "$*" >> "{log}"\n'
            f'if [ "$1" = "-Qu" ]; then printf \'{qu_output}\'; exit {qu_exit}; fi\n'
            "exit 0\n")
        (bin_dir / "sudo").write_text('#!/bin/sh\nexec "$@"\n')
        for tool in ("pacman", "sudo"):
            (bin_dir / tool).chmod(0o755)
        self.env["PATH"] = f"{bin_dir}{os.pathsep}{self.env['PATH']}"
        return log

    def test_pending_upgrades_refuse_before_anything_is_installed(self):
        log = self.fake_pacman(0, "qt6-base 6.11.0-1 -> 6.12.0-3\\nquickshell 0.3.1-2 -> 0.3.2-1\\n")
        result = self.run_cli("install", "--compositor", "none", "--install-dependencies", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("2 system upgrade(s) pending (qt6-base, quickshell)", result.stderr)
        self.assertIn("sudo pacman -Syu", result.stderr)
        self.assertEqual(log.read_text().split("\n")[:-1], ["-Qu"], "pacman -S must not run")
        self.assertFalse((self.home / ".local/share/illuminated").exists())

    def test_up_to_date_system_installs_only_the_rice_packages(self):
        log = self.fake_pacman(1)
        self.run_cli("install", "--compositor", "none", "--install-dependencies")
        self.assertEqual(log.read_text().split("\n")[:-1],
                         ["-Qu", "-S --needed quickshell qt6-declarative brightnessctl swaylock power-profiles-daemon udisks2 wl-clipboard cliphist xdg-utils"])
        self.assertTrue((self.home / ".local/share/illuminated/quickshell/shell.qml").is_file())

    def test_unreadable_upgrade_state_refuses(self):
        log = self.fake_pacman(2)
        result = self.run_cli("install", "--compositor", "none", "--install-dependencies", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not check for pending upgrades", result.stderr)
        self.assertEqual(log.read_text().split("\n")[:-1], ["-Qu"])
        self.assertFalse((self.home / ".local/share/illuminated").exists())

    def test_dry_run_checks_nothing(self):
        log = self.fake_pacman(0, "qt6-base 6.11.0-1 -> 6.12.0-3\\n")
        self.run_cli("install", "--compositor", "none", "--install-dependencies", "--dry-run")
        self.assertFalse(log.exists())


class Apply(Home):
    def test_invalid_config_keeps_last_good_output(self):
        self.write(".config/illuminated/config.toml", '[appearance]\nmode = "light"\n')
        self.run_cli("apply")
        resolved = self.home / ".config/illuminated/generated/resolved.json"
        good = resolved.read_text()
        self.assertEqual(json.loads(good)["values"]["appearance"]["mode"], "light")
        self.write(".config/illuminated/config.toml", '[appearance]\nmode = 3\n')
        result = self.run_cli("apply", check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("appearance.mode", result.stderr)
        self.assertEqual(resolved.read_text(), good)

    def test_new_group_flows_everywhere(self):
        """Adding a group in config.toml alone gives it a trigger, a deck and a keybind."""
        self.write(".config/illuminated/config.toml",
                   '[groups.quick]\nglyph = "✦"\ncards = ["dnd", "lock"]\n'
                   '[rail]\nhands = ["levels", "quick"]\n[binds]\n"SUPER+Q" = "cards quick"\n')
        self.run_cli("apply")
        out = self.home / ".config/illuminated/generated"
        values = json.loads((out / "resolved.json").read_text())["values"]
        self.assertEqual(values["groups"]["quick"]["cards"], ["dnd", "lock"])
        self.assertIn("quick", values["rail"]["hands"])
        self.assertIn('hl.bind("SUPER + Q"', (out / "hyprland.lua").read_text())
        self.assertIn("bind=SUPER,q,spawn,", (out / "mango.conf").read_text())
        self.assertTrue((out / "hyprland.lua").read_text().rstrip().endswith("} } })"))

class Generators(unittest.TestCase):
    def test_golden_snippets(self):
        values = config.resolve({}, hostname="h", env={}).values
        hypr = generate.hyprland(values, "/home/u/.local/bin/illuminated")
        self.assertIn('hl.on("hyprland.start", function()\n    hl.exec_cmd("/home/u/.local/bin/illuminated start")\nend)', hypr)
        self.assertIn('hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("/home/u/.local/bin/illuminated cards power"))', hypr)
        self.assertIn('hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/home/u/.local/bin/illuminated volume up"), { repeating = true })', hypr)
        self.assertIn('active_border = "rgba(fa7a45ff)"', hypr)
        mango = generate.mango(values, "/home/u/.local/bin/illuminated")
        self.assertIn("exec_once=/home/u/.local/bin/illuminated start", mango)
        self.assertNotIn("exec-once", mango)  # Mango spells it exec_once
        self.assertIn("bind=SUPER,space,spawn,/home/u/.local/bin/illuminated launcher", mango)
        self.assertIn("bind=NONE,XF86MonBrightnessUp,spawn,/home/u/.local/bin/illuminated brightness up", mango)
        self.assertIn("focus_color=0xfa7a45ff", mango)

    def test_paths_with_spaces_are_quoted(self):
        values = config.resolve({}, hostname="h", env={}).values
        self.assertIn("'/home/a b/illuminated' launcher", generate.mango(values, "/home/a b/illuminated"))
        self.assertIn('"\'/home/a b/illuminated\' launcher"', generate.hyprland(values, "/home/a b/illuminated"))

    def test_integration_switches(self):
        values = config.resolve({"integration": {"autostart": False, "binds": False, "borders": False}}, hostname="h", env={}).values
        self.assertNotIn("bind=", generate.mango(values, "x"))
        self.assertNotIn("exec_once", generate.mango(values, "x"))
        self.assertNotIn("hl.", generate.hyprland(values, "x"))

    def test_dropping_a_default_bind(self):
        values = config.resolve({"binds": {"SUPER+N": ""}}, hostname="h", env={}).values
        self.assertNotIn("history", generate.mango(values, "x"))


class Blocks(unittest.TestCase):
    def test_block_insertion_is_reversible_and_idempotent(self):
        for compositor in install.COMPOSITORS:
            for original in ["", "a", "a\n", "a\n\n"]:
                once, added = install.with_block(original, compositor)
                twice, _ = install.with_block(once, compositor)
                self.assertEqual(once, twice)
                restored, found = install.without_block(once, compositor, added)
                self.assertTrue(found)
                self.assertEqual(restored, original, (compositor, original))


if __name__ == "__main__":
    unittest.main()
