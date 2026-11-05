"""QML skins: lay a skin's files over the default's (lib/illuminated/skin.py)."""
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
from illuminated import skin  # noqa: E402


class Merge(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.default, self.user, self.out = self.tmp / "default", self.tmp / "user", self.tmp / "generated" / "skin"
        for rel in ("Rail.qml", "Vial.qml", "elements/vial.png", "skin.json"):
            (self.default / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.default / rel).write_text("default " + rel)
        self.user.mkdir()

    def test_a_file_replaces_only_its_namesake(self):
        (self.user / "Vial.qml").write_text("mine")
        (self.user / "elements").mkdir()
        (self.user / "elements" / "seal.png").write_text("added")
        self.assertEqual(skin.merge(self.default, self.user, self.out), [])
        self.assertEqual((self.out / "Vial.qml").read_text(), "mine")
        self.assertEqual((self.out / "Rail.qml").read_text(), "default Rail.qml")
        self.assertEqual((self.out / "elements" / "vial.png").read_text(), "default elements/vial.png")
        self.assertEqual((self.out / "elements" / "seal.png").read_text(), "added")
        self.assertTrue((self.out / "Vial.qml").is_symlink(), "edits stay live")

    def test_old_format_is_ignored_with_a_warning(self):
        (self.user / "Vial.qml").write_text("mine")
        for old in ({"elements": {}}, {"rail": {"items": []}}, {"dock": {"after": []}}):
            (self.user / "skin.json").write_text(json.dumps(old))
            messages = skin.merge(self.default, self.user, self.out)
            self.assertTrue(messages and "old skin format" in messages[0], old)
            self.assertEqual((self.out / "Vial.qml").read_text(), "default Vial.qml")
        (self.user / "skin.json").write_text(json.dumps({"devices": {}}))
        self.assertEqual(skin.merge(self.default, self.user, self.out), [])

    def test_stamp_changes_only_with_the_qml(self):
        stamp = self.out.with_name("skin.stamp")
        skin.merge(self.default, self.user, self.out)
        first = stamp.read_text()
        skin.merge(self.default, self.user, self.out)
        self.assertEqual(stamp.read_text(), first, "a config-only apply must not reload the shell")
        (self.user / "Vial.qml").write_text("edited")
        skin.merge(self.default, self.user, self.out)
        self.assertNotEqual(stamp.read_text(), first)

    def test_no_user_skin(self):
        self.assertEqual(skin.merge(self.default, self.tmp / "missing", self.out), [])
        self.assertEqual((self.out / "Rail.qml").read_text(), "default Rail.qml")


if __name__ == "__main__":
    unittest.main()
