"""The `illuminated` command dispatches to quickshell with fixed argv (no shell strings)."""
import json, os, pathlib, subprocess, sys, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "illuminated"


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        d = pathlib.Path(self.tmp.name)
        fake = d / "quickshell"
        fake.write_text("#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n"); fake.chmod(0o755)
        (d / "home").mkdir()
        self.env = {"HOME": str(d / "home"), "PATH": f"{d}:{os.environ['PATH']}"}
        self.shell = str(ROOT / "quickshell")

    def call(self, *args):
        return json.loads(subprocess.check_output([sys.executable, str(SCRIPT), *args], env=self.env, text=True))

    def test_ipc(self):
        for args, tail in [(("launcher",), ["toggleLauncher"]), (("hide",), ["hide"]),
                           (("cards", "power"), ["cards", "power"]), (("volume", "up"), ["volume", "0.05"]),
                           (("volume", "mute"), ["mute"]), (("brightness", "down"), ["brightness", "-0.05"])]:
            with self.subTest(args=args):
                self.assertEqual(self.call(*args), ["ipc", "-p", self.shell + "/shell.qml", "call", "shell", *tail])

    def test_start_stop_isolate_need_no_environment(self):
        self.assertEqual(self.call("start"), ["-p", self.shell + "/shell.qml", "--no-duplicate"])
        self.assertTrue((pathlib.Path(self.env["HOME"]) / ".config/illuminated/generated/resolved.json").exists(),
                        "start applies the configuration first")
        self.assertEqual(self.call("stop"), ["kill", "-p", self.shell + "/shell.qml"])
        self.assertEqual(self.call("isolate", "chrome"), ["-p", self.shell + "/chrome-entry.qml", "--no-duplicate"])
        self.assertNotEqual(subprocess.run([sys.executable, str(SCRIPT), "isolate", "invalid"], env=self.env,
                                           capture_output=True).returncode, 0)

    def test_side_by_side_override(self):
        env = dict(self.env, ILLUMINATED_CONFIG="/x/path with spaces")
        out = json.loads(subprocess.check_output([sys.executable, str(SCRIPT), "launcher"], env=env, text=True))
        self.assertEqual(out[:3], ["ipc", "-p", "/x/path with spaces/shell.qml"])


if __name__ == "__main__":
    unittest.main()
