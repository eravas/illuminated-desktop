"""Configuration resolution, validation and single-source guarantees."""
import json
import pathlib
import re
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
from illuminated import config, paths  # noqa: E402

ENV = {}  # no compositor environment


def resolve(user, host="testhost"):
    return config.resolve(user, hostname=host, env=ENV)


def errors(user):
    with unittest.TestCase().assertRaises(config.ConfigError) as caught:
        resolve(user)
    return caught.exception.diagnostics


class Merge(unittest.TestCase):
    def test_partial_table_override_keeps_siblings(self):
        # v2 bug: overriding one menu wiped every other group.
        values = resolve({"groups": {"power": {"cards": ["lock", "poweroff"]}}}).values
        self.assertEqual(values["groups"]["power"]["cards"], ["lock", "poweroff"])
        self.assertEqual(values["groups"]["sound"]["cards"], ["volume", "microphone", "outputs"])
        self.assertEqual(values["groups"]["power"]["glyph"], "P")

    def test_arrays_replace(self):
        values = resolve({"rail": {"hands": ["power"]}}).values
        self.assertEqual(values["rail"]["hands"], ["power"])

    def test_host_overrides_only_on_that_host(self):
        user = {"appearance": {"mode": "light"}, "host": {"laptop": {"appearance": {"mode": "dark"}}}}
        self.assertEqual(resolve(user, "laptop").values["appearance"]["mode"], "dark")
        self.assertEqual(resolve(user, "desktop").values["appearance"]["mode"], "light")

    def test_pinned_lists_user_leaves_only(self):
        pinned = resolve({"appearance": {"mode": "light"}, "rail": {"hands": ["power"]}}).pinned
        self.assertEqual(sorted(pinned), ["appearance.mode", "rail.hands"])

    def test_new_group_and_palette_are_completed_from_templates(self):
        values = resolve({"groups": {"quick": {"cards": ["dnd", "lock"]}}, "rail": {"hands": ["quick"]},
                          "palettes": {"ink": {"paper": "#000000"}}, "appearance": {"mode": "ink"}}).values
        self.assertEqual(values["groups"]["quick"]["show"], "always")
        self.assertEqual(values["groups"]["quick"]["label"], "quick")
        self.assertEqual(values["palettes"]["ink"]["paper"], "#000000")
        self.assertEqual(values["palettes"]["ink"]["ink"], values["palettes"]["dark"]["ink"])


class Validation(unittest.TestCase):
    def assertError(self, user, key, fragment=""):
        found = errors(user)
        self.assertTrue(any(d.key == key and fragment in d.message for d in found),
                        f"no {key!r} error containing {fragment!r} in {[d.render() for d in found]}")

    def test_wrong_type_is_reported_not_ignored(self):
        self.assertError({"dimensions": {"controlHeight": "40"}}, "dimensions.controlHeight", "expected number")

    def test_unknown_key_suggests(self):
        self.assertError({"dimensions": {"controlHieght": 40}}, "dimensions.controlHieght", "did you mean dimensions.controlHeight")

    def test_ranges_enums_patterns(self):
        self.assertError({"motion": {"deploy": 99999}}, "motion.deploy", "outside")
        self.assertError({"motion": {"easing": "bounce"}}, "motion.easing", "not one of")
        self.assertError({"palettes": {"dark": {"ink": "white"}}}, "palettes.dark.ink", "does not match")
        self.assertError({"semantic": {"volume": "pink"}}, "semantic.volume", "does not match")
        self.assertError({"confirm": {"armDelay": 5000}}, "confirm.armDelay", "outside")

    def test_unknown_mode_names_the_palettes(self):
        self.assertError({"appearance": {"mode": "highContrast"}}, "appearance.mode", "have dark, light")

    def test_semantic_colours_are_one_table_for_every_mode(self):
        defaults = config.load_defaults()
        self.assertEqual(sorted(defaults["palettes"]), ["dark", "light"])
        for palette in defaults["palettes"].values():
            self.assertFalse(set(palette) & set(defaults["semantic"]), "a semantic colour is mode-dependent")
        self.assertEqual(set(defaults["palettes"]["dark"]), set(defaults["palettes"]["light"]))

    def test_card_behaviour_is_not_configuration(self):
        # Orientation, interaction and Sleep's menu live in quickshell/artifacts/kinds/.
        for key in ("orientation", "interaction", "alternatives"):
            self.assertError({"cards": {"volume": {key: "toggle"}}}, f"cards.volume.{key}", "unknown key")

    def test_default_session_deck(self):
        values = resolve({}).values
        self.assertEqual(values["groups"]["power"]["cards"], ["suspend", "poweroff", "reboot"])
        self.assertFalse(values["cards"]["suspend"]["confirm"])
        self.assertFalse(values["cards"]["lock"]["confirm"])
        for kind in ("poweroff", "reboot", "logout"):
            self.assertTrue(values["cards"][kind]["confirm"], kind)
        titles = {k: values["cards"][k]["title"] for k in ("volume", "brightness", "battery", "wifi", "suspend", "poweroff", "logout")}
        self.assertEqual(titles, {"volume": "Sound", "brightness": "Light", "battery": "Charge", "wifi": "Network",
                                  "suspend": "Sleep", "poweroff": "Shut Down", "logout": "Log Out"})

    def test_each_number_has_its_own_range(self):
        self.assertError({"dimensions": {"controlHeight": 4000}}, "dimensions.controlHeight", "outside 24..72")
        self.assertError({"deck": {"width": 10}}, "deck.width", "outside 90..320")
        self.assertError({"typography": {"size": 200}}, "typography.size", "outside 8..48")

    def test_whole_numbers_reject_fractions(self):
        self.assertError({"dimensions": {"controlHeight": 40.5}}, "dimensions.controlHeight", "whole number")
        self.assertError({"motion": {"deploy": 290.0}}, "motion.deploy", "whole number")
        self.assertError({"greeter": {"authTimeout": 3e4}}, "greeter.authTimeout", "whole number")
        values = resolve({"deck": {"selectionLift": 6.5, "dragThreshold": 7.5}}).values
        self.assertEqual(values["deck"]["selectionLift"], 6.5)

    def test_every_numeric_option_has_an_explicit_rule(self):
        defaults = config.load_defaults()
        rules = defaults["schema"]["rules"]
        for key in config.leaves(config.shell_defaults(defaults)):
            value = defaults
            for part in key.split("."):
                value = value[part]
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                continue
            self.assertIn(key, rules, f"{key} needs its own range in [schema.rules]")
            self.assertIn("min", rules[key], key)
            self.assertIn("max", rules[key], key)
            self.assertTrue(rules[key]["min"] <= value <= rules[key]["max"], f"default {key}={value} outside its range")

    def test_integer_rules_match_qml_property_types(self):
        rules = config.load_defaults()["schema"]["rules"]
        text = (paths.shell_dir() / "config/Settings.qml").read_text()
        found = re.findall(r'property (int|real) \w+: option\("([^"]+)"\)', text)
        self.assertTrue(found)
        for qml_type, key in found:
            self.assertEqual(bool(rules.get(key, {}).get("integer")), qml_type == "int",
                             f"{key} is a QML {qml_type}; set integer accordingly in [schema.rules]")

    def test_new_card_kinds_need_code(self):
        self.assertError({"cards": {"weather": {"title": "Weather"}}}, "cards.weather", "need code")

    def test_cross_references(self):
        self.assertError({"groups": {"sound": {"cards": ["volume", "nonsense"]}}}, "groups.sound.cards", "unknown card")
        self.assertError({"rail": {"hands": ["nowhere"]}}, "rail.hands", "unknown group")
        self.assertError({"appearance": {"mode": "sepia"}}, "appearance.mode", "no palette")
        self.assertError({"binds": {"SUPER+X": "cards nowhere"}}, "binds.SUPER+X", "unknown group")
        self.assertError({"binds": {"HYPER+X": "launcher"}}, "binds.HYPER+X", "unknown modifier")
        self.assertError({"binds": {"SUPER+X": "rm -rf /"}}, "binds.SUPER+X", "unknown action")
        self.assertError({"groups": {"empty": {"cards": []}}}, "groups.empty", "needs cards or a sheet")

    def test_host_errors_are_found_on_every_machine(self):
        self.assertError({"host": {"elsewhere": {"typo": 1}}}, "host.elsewhere.typo", "unknown key")

    def test_large_group_warns_but_resolves(self):
        result = resolve({"groups": {"power": {"cards": ["lock", "suspend", "poweroff", "reboot"]}}})
        self.assertTrue(any(d.level == "warning" and "paginate" in d.message for d in result.diagnostics))

    def test_toml_syntax_error_has_location(self):
        path = pathlib.Path(self.id().replace(".", "_") + ".toml")
        tmp = pathlib.Path(__import__("tempfile").mkdtemp()) / path
        tmp.write_text("[bar\n")
        with self.assertRaises(config.ConfigError) as caught:
            config.load_user(tmp)
        self.assertIn("line 1", str(caught.exception))


class Locker(unittest.TestCase):
    def test_plain_hyprlock_needs_the_flag(self):
        found = errors({"commands": {"lock": ["hyprlock"]}})
        self.assertTrue(any(d.key == "commands.lockReturnsWhenReady" and "hyprlock" in d.message for d in found))
        found = errors({"commands": {"lock": ["/usr/bin/hyprlock", "--immediate"]}})
        self.assertTrue(any(d.key == "commands.lockReturnsWhenReady" for d in found))

    def test_hyprlock_with_the_flag_off_resolves(self):
        values = resolve({"commands": {"lock": ["hyprlock"], "lockReturnsWhenReady": False}}).values
        self.assertFalse(values["commands"]["lockReturnsWhenReady"])

    def test_flag_is_a_boolean_not_a_command(self):
        resolve({"commands": {"lockReturnsWhenReady": False}})   # not flagged as an empty command
        found = errors({"commands": {"lockReturnsWhenReady": "no"}})
        self.assertTrue(any(d.key == "commands.lockReturnsWhenReady" and "expected boolean" in d.message for d in found))

    def test_shell_lock_fallback_must_return_once_locked(self):
        found = errors({"lock": {"fallback": ["hyprlock"]}})
        self.assertTrue(any(d.key == "lock.fallback" for d in found))
        found = errors({"lock": {"fallback": ["illuminated", "lock"]}})
        self.assertTrue(any(d.key == "lock.fallback" for d in found))
        found = errors({"lock": {"fallback": []}})
        self.assertTrue(any(d.key == "lock.fallback" for d in found))

    def test_shell_lock_warns_until_commands_lock_uses_it(self):
        result = resolve({"features": {"lock": True}})
        self.assertTrue(any(d.key == "commands.lock" and d.level == "warning" for d in result.diagnostics))
        result = resolve({"features": {"lock": True}, "commands": {"lock": ["illuminated", "lock"]}})
        self.assertFalse(any(d.key == "commands.lock" for d in result.diagnostics))

    def test_lock_qml_unlocks_only_on_success_or_unconfirmed_abandon(self):
        lock = (paths.shell_dir() / "lock.qml").read_text()
        sites = [line.strip() for line in lock.splitlines() if "session.locked = false" in line]
        self.assertEqual(len(sites), 2, sites)
        self.assertTrue(any("PamResult.Success" in line for line in sites))
        self.assertTrue(any("!session.secure" in line for line in sites))

    def test_qml_guards_sleep_and_never_times_out_a_blocking_locker(self):
        session = (paths.shell_dir() / "services/SessionState.qml").read_text()
        self.assertIn('action === "suspend" && !Settings.lockReturnsWhenReady', session)
        self.assertIn('action === "lock" && !Settings.lockReturnsWhenReady ? 0 : 15000', session)
        command = (paths.shell_dir() / "services/CommandAction.qml").read_text()
        self.assertIn("if (timeoutMs > 0) deadline.start();", command)


class LineNumbers(unittest.TestCase):
    TEXT = (
        '# my settings\n'
        'hardware.backlightDevice = "intel_backlight"\n'
        '[dimensions] # sizes\n'
        'controlHeight = "40"\n'
        'notes = """\n'
        'barHieght = 1\n'
        '"""\n'
        '[host."my box".appearance]\n'
        'mode = "dark"\n'
        '[ groups . quick ]\n'
        'glyph = "*"\n'
        'cards = ["dnd", "weather"]\n')

    def test_key_lines(self):
        lines = config.key_lines(self.TEXT)
        self.assertEqual(lines["hardware.backlightDevice"], 2)
        self.assertEqual(lines["dimensions"], 3)
        self.assertEqual(lines["dimensions.controlHeight"], 4)
        self.assertNotIn("dimensions.barHieght", lines, "text inside a multi-line string is not a key")
        self.assertEqual(lines["host.my box.appearance.mode"], 9)
        self.assertEqual(lines["groups.quick.cards"], 12)

    def test_diagnostics_carry_lines_through_resolve_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = pathlib.Path(tmp) / "config.toml"
            file.write_text('[dimensions]\nspacing = 8\ncontrolHeight = 40.5\n')
            with self.assertRaises(config.ConfigError) as caught:
                config.resolve_file(file, hostname="h", env=ENV)
            found = {d.key: d for d in caught.exception.diagnostics}
            self.assertEqual(found["dimensions.controlHeight"].line, 3)
            self.assertIn("(line 3)", found["dimensions.controlHeight"].render())
            self.assertEqual(found["dimensions.controlHeight"].as_json()["line"], 3)
            # Cross-reference errors (checked once types are valid) get lines too.
            file.write_text('[appearance]\nmode = "dark"\n\n[groups.quick]\ncards = ["dnd", "weather"]\n')
            with self.assertRaises(config.ConfigError) as caught:
                config.resolve_file(file, hostname="h", env=ENV)
            found = {d.key: d for d in caught.exception.diagnostics}
            self.assertEqual(found["groups.quick.cards"].line, 5)

    def test_host_value_errors_point_at_the_host_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = pathlib.Path(tmp) / "config.toml"
            file.write_text('[appearance]\nmode = "dark"\n\n[host.h.dimensions]\ncontrolHeight = 9000\n')
            with self.assertRaises(config.ConfigError) as caught:
                config.resolve_file(file, hostname="h", env=ENV)
        self.assertEqual([d.line for d in caught.exception.diagnostics if d.key == "host.h.dimensions.controlHeight"], [5])

    def test_keys_absent_from_the_file_have_no_line(self):
        d = config.Diagnostic("error", "dimensions.radius", "x")
        config.locate([d], "[appearance]\nmode = 'dark'\n", "h")
        self.assertIsNone(d.line)
        self.assertNotIn("line", d.as_json())


class SingleSource(unittest.TestCase):
    def test_defaults_js_is_generated_from_toml(self):
        text = paths.shell_defaults_js().read_text()
        self.assertTrue(text.startswith(".pragma library\n"))
        body = text.split("var values = ", 1)[1].rstrip().rstrip(";")
        self.assertEqual(json.loads(body), config.shell_defaults(), "run: python3 scripts/illuminated defaults --write-json")

    def test_defaults_json_is_generated_from_toml(self):
        self.assertEqual(json.loads(paths.shell_defaults_json().read_text()), config.shell_defaults(),
                         "run `illuminated defaults --write-json`")

    def test_defaults_resolve_cleanly(self):
        result = resolve({})
        self.assertEqual([d for d in result.diagnostics if d.level == "error"], [])

    def test_qml_has_no_default_literals(self):
        for name in ["config/Settings.qml", "theme/Theme.qml", "artifacts/Motion.qml", "artifacts/ServiceCard.qml", "greeter/Greeter.qml"]:
            text = (paths.shell_dir() / name).read_text()
            self.assertIsNone(re.search(r'Settings\.(color|option)\("[^"]+",\s*["#\d]', text), name)

    def test_qml_group_and_card_lists_are_not_hardcoded(self):
        for name in ["rail/Rail.qml", "artifacts/CardsLayer.qml", "artifacts/ServiceCard.qml", "shell.qml"]:
            text = (paths.shell_dir() / name).read_text()
            self.assertNotIn('"connections", "media"', text, name)
            self.assertNotIn('Navigation.expand(({', text, name)

    def test_sheet_registry_matches_qml(self):
        sheets = set(config.load_defaults()["schema"]["sheets"])
        text = (paths.shell_dir() / "artifacts/CardsLayer.qml").read_text()
        mapped = set(re.findall(r"(\w+): \w+Page", re.search(r"sourceComponent: \(\{([^}]*)\}\)", text)[1]))
        self.assertEqual(sheets, mapped)

    def test_qml_paths_match_python_paths(self):
        text = (paths.shell_dir() / "config/Settings.qml").read_text()
        self.assertIn('"/illuminated/generated/resolved.json"', text)
        self.assertIn('"/illuminated/ui.json"', text)
        self.assertEqual(paths.resolved_json().relative_to(paths.config_home()).as_posix(), "illuminated/generated/resolved.json")


class Documentation(unittest.TestCase):
    def test_documented_examples_are_valid(self):
        import tomllib
        from illuminated.install import STARTER
        doc = (ROOT / "docs/CONFIGURATION.md").read_text()
        for block in re.findall(r"```toml\n(.*?)```", doc, re.S) + [STARTER]:
            resolve(tomllib.loads(block), host="inspiron")


class Detection(unittest.TestCase):
    def test_compositor_detection(self):
        none = lambda _: None
        self.assertEqual(config.detect_compositor("auto", {"HYPRLAND_INSTANCE_SIGNATURE": "x"}, none), "hyprland")
        self.assertEqual(config.detect_compositor("auto", {"XDG_CURRENT_DESKTOP": "mango"}, none), "mango")
        self.assertEqual(config.detect_compositor("mango", {"HYPRLAND_INSTANCE_SIGNATURE": "x"}, none), "mango")
        self.assertEqual(config.detect_compositor("auto", {}, lambda b: "/usr/bin/" + b if b == "mango" else None), "mango")
        self.assertEqual(config.detect_compositor("auto", {}, lambda b: "/usr/bin/" + b), "")


if __name__ == "__main__":
    unittest.main()


class V7Options(unittest.TestCase):
    """Rail, dock, reading presets and media options validate (docs/V7.md)."""

    def resolve(self, user):
        from illuminated import config as c
        return c.resolve(user, hostname="x", env={})

    def test_open_tables_take_enumerated_strings(self):
        r = self.resolve({"dock": {"outputs": {"eDP-1": "autohide"}}, "media": {"overrides": {"1209:abcd": "ereader"}}})
        self.assertEqual(r.values["dock"]["outputs"], {"eDP-1": "autohide"})
        self.assertEqual(r.values["media"]["overrides"], {"1209:abcd": "ereader"})

    def test_rejections(self):
        from illuminated import config as c
        for bad in ({"dock": {"outputs": {"eDP-1": "sometimes"}}}, {"media": {"overrides": {"1209:abcd": "toaster"}}},
                    {"reading": {"options": {"face": "comic"}}}, {"rail": {"hands": ["nope"]}}, {"pixel": {"logical": 1.5}}):
            with self.assertRaises(c.ConfigError, msg=bad):
                self.resolve(bad)

    def test_removed_compatibility_keys_are_rejected(self):
        from illuminated import config as c
        for gone in ({"appearance": {"highLegibility": True}}, {"battery": {"lowChargeNumeral": True}},
                     {"deck": {"aligned": True}}, {"deck": {"rotation": 2}}, {"confirm": {"timeout": 8000}}):
            with self.assertRaises(c.ConfigError, msg=gone):
                self.resolve(gone)
