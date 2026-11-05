"""Configuration: one packaged defaults file, one user file, one resolved output.

defaults.toml  ← config.toml (top level) ← config.toml [host.<hostname>]
Tables merge key by key; arrays and scalars replace. The result, plus the list
of keys the user pinned, is written as resolved.json, the only configuration
file the shell reads. Nothing is written when validation finds an error.
"""
from __future__ import annotations

import copy
import difflib
import fnmatch
import json
import os
import re
import shutil
import socket
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from . import paths

FORMAT = 1
NEW_GROUP = {"glyph": "•", "label": "", "cards": [], "sheet": "", "show": "always"}
BIND_ACTIONS = re.compile(
    r"^(launcher|hide|history|dnd|microphone|status|minimize|clipboard|lock"
    r"|cards [A-Za-z0-9_-]+|volume (up|down|mute)|brightness (up|down))$")
KEY_TOKEN = re.compile(r"^[A-Za-z0-9_]+$")
MODIFIERS = {"SUPER", "SHIFT", "CTRL", "ALT"}


class ConfigError(Exception):
    """Raised when the configuration cannot be resolved; carries every problem."""

    def __init__(self, diagnostics):
        self.diagnostics = diagnostics
        super().__init__("\n".join(d.render() for d in diagnostics))


@dataclass
class Diagnostic:
    level: str          # error | warning
    key: str
    message: str
    line: int | None = None   # line in config.toml, when the key is written there

    def render(self):
        where = f" {self.key}" if self.key else ""
        where += f" (line {self.line})" if self.line else ""
        return f"{self.level}:{where}{':' if where else ''} {self.message}"

    def as_json(self):
        out = {"level": self.level, "key": self.key, "message": self.message}
        if self.line:
            out["line"] = self.line
        return out


@dataclass
class Resolved:
    values: dict
    pinned: list
    diagnostics: list = field(default_factory=list)
    host: str = ""
    compositor: str = ""
    source: str = ""

    def as_json(self):
        return {"format": FORMAT, "source": self.source, "host": self.host,
                "compositor": self.compositor, "values": self.values,
                "pinned": sorted(self.pinned),
                "diagnostics": [d.as_json() for d in self.diagnostics]}


# ── merging ──────────────────────────────────────────────────────────────

def merge(base: dict, overlay: dict) -> dict:
    """Return base deep-merged with overlay. Tables merge; everything else replaces."""
    result = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def leaves(tree: dict, prefix: str = "") -> list[str]:
    """Dotted paths of every non-table value in tree."""
    out = []
    for key, value in tree.items():
        path = f"{prefix}.{key}" if prefix else key
        if isinstance(value, dict) and value:
            out.extend(leaves(value, path))
        else:
            out.append(path)
    return out


# ── loading ──────────────────────────────────────────────────────────────

def load_defaults() -> dict:
    with open(paths.defaults_toml(), "rb") as f:
        return tomllib.load(f)


def shell_defaults(defaults: dict | None = None) -> dict:
    """What the shell sees as defaults: everything except validation rules."""
    values = copy.deepcopy(defaults if defaults is not None else load_defaults())
    values.pop("schema", None)
    return values


def load_user(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        raise ConfigError([Diagnostic("error", "", f"{path}: {e}")]) from None


# ── validation ───────────────────────────────────────────────────────────

def _kind(value):
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "table"
    return type(value).__name__


def _rules_for(rules: dict, key: str):
    """Most specific matching rule wins (fewest wildcards, then longest)."""
    matches = [(pattern.count("*"), -len(pattern), rule) for pattern, rule in rules.items()
               if fnmatch.fnmatchcase(key, pattern) and pattern.count(".") == key.count(".")]
    return sorted(matches, key=lambda m: (m[0], m[1]))[0][2] if matches else {}


def _check_value(key, value, template, rules, out):
    want, got = _kind(template), _kind(value)
    if want != got:
        out.append(Diagnostic("error", key, f"expected {want}, got {got} ({json.dumps(value)})"))
        return
    if want == "array":
        element = _kind(template[0]) if template else "string"
        bad = [v for v in value if _kind(v) != element]
        if bad:
            out.append(Diagnostic("error", key, f"every entry must be a {element}; got {json.dumps(bad)}"))
    rule = _rules_for(rules, key)
    if "enum" in rule and value not in rule["enum"]:
        out.append(Diagnostic("error", key, f"{json.dumps(value)} is not one of {', '.join(rule['enum'])}"))
    if want == "number":
        if rule.get("integer") and not isinstance(value, int):
            out.append(Diagnostic("error", key, f"{value} must be a whole number"))
        elif "min" in rule and value < rule["min"] or "max" in rule and value > rule["max"]:
            out.append(Diagnostic("error", key, f"{value} is outside {rule.get('min')}..{rule.get('max')}"))
    if "pattern" in rule and want == "string" and not re.fullmatch(rule["pattern"], value):
        out.append(Diagnostic("error", key, f"{json.dumps(value)} does not match {rule['pattern']}"))


def _walk(user, template, prefix, schema, defaults, out):
    open_tables = set(schema.get("open", []))
    rules = schema.get("rules", {})
    for key, value in user.items():
        path = f"{prefix}.{key}" if prefix else key
        if key in template:
            sub = template[key]
        elif prefix in open_tables:
            sub = _template_for_new(prefix, key, defaults)
            if sub is None:      # binds: free-form string table
                if not isinstance(value, str):
                    out.append(Diagnostic("error", path, "expected string"))
                continue
        else:
            hint = difflib.get_close_matches(key, list(template), n=1)
            suffix = f" (did you mean {prefix + '.' if prefix else ''}{hint[0]}?)" if hint else ""
            if prefix == "cards":
                suffix = " (card kinds need code; you can only change built-in kinds)"
            out.append(Diagnostic("error", path, "unknown key" + suffix))
            continue
        if isinstance(sub, dict):
            if not isinstance(value, dict):
                out.append(Diagnostic("error", path, f"expected table, got {_kind(value)}"))
            else:
                _walk(value, sub, path, schema, defaults, out)
        else:
            _check_value(path, value, sub, rules, out)


def _template_for_new(table, key, defaults):
    if table == "groups":
        return {**NEW_GROUP, "label": key}
    if table == "palettes":
        return defaults["palettes"]["dark"]
    if table == "binds":
        return None
    if table in ("dock.outputs", "media.overrides"):
        return ""
    if table == "commands.custom":
        return ["argv"]          # an argv list of strings
    return {}


def _semantic(values, schema, out):
    cards, groups = values["cards"], values["groups"]
    sheets = set(schema["sheets"])
    mode = values["appearance"]["mode"]
    if mode not in values["palettes"]:
        out.append(Diagnostic("error", "appearance.mode",
                              f"no palette named {mode!r} (have {', '.join(values['palettes'])})"))
    for name, card in cards.items():
        if card["sheet"] and card["sheet"] not in sheets:
            out.append(Diagnostic("error", f"cards.{name}.sheet", f"unknown sheet {card['sheet']!r}"))
    for name, group in groups.items():
        key = f"groups.{name}"
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            out.append(Diagnostic("error", key, "group names may use letters, digits, _ and - only"))
        for kind in group["cards"]:
            if kind not in cards and not re.fullmatch(r"skin:[A-Za-z0-9_-]+", kind):   # skin cards: docs/SKINS.md
                out.append(Diagnostic("error", key + ".cards", f"unknown card {kind!r}"))
        if len(set(group["cards"])) != len(group["cards"]):
            out.append(Diagnostic("error", key + ".cards", "a card may appear only once per group"))
        if group["sheet"] and group["sheet"] not in sheets:
            out.append(Diagnostic("error", key + ".sheet", f"unknown sheet {group['sheet']!r}"))
        if not group["cards"] and not group["sheet"]:
            out.append(Diagnostic("error", key, "needs cards or a sheet"))
        if len(group["cards"]) > 3:
            out.append(Diagnostic("warning", key + ".cards",
                                  f"{len(group['cards'])} cards exceed one page (3); the deck will paginate"))
    for name in values["rail"]["hands"]:
        if name not in groups:
            out.append(Diagnostic("error", "rail.hands", f"unknown group {name!r}"))
    commands = values["commands"]
    for name, argv in (commands.get("custom") or {}).items():
        if not (isinstance(argv, list) and argv and all(isinstance(a, str) and a for a in argv)):
            out.append(Diagnostic("error", f"commands.custom.{name}", "must be a non-empty list of strings (an argv; no shell)"))
    for action, argv in commands.items():
        if action == "custom":
            continue
        if isinstance(argv, list) and action != "logout" and not argv:
            out.append(Diagnostic("error", f"commands.{action}", "must not be empty"))
    if commands["lock"] and os.path.basename(commands["lock"][0]) == "hyprlock" and commands["lockReturnsWhenReady"]:
        out.append(Diagnostic("error", "commands.lockReturnsWhenReady",
                              "plain hyprlock keeps running until you unlock, so it never reports the screen "
                              "as locked; set commands.lockReturnsWhenReady = false (Sleep is then refused) "
                              "or use a locker that returns once locked, such as swaylock --daemonize"))
    lock = values.get("lock", {})
    fallback = lock.get("fallback") or []
    if not fallback:
        out.append(Diagnostic("error", "lock.fallback", "must not be empty: it locks when the shell cannot"))
    elif os.path.basename(fallback[0]) == "hyprlock":
        out.append(Diagnostic("error", "lock.fallback", "plain hyprlock keeps running until you unlock, so "
                              "`illuminated lock` could not return once locked; use swaylock --daemonize"))
    elif os.path.basename(fallback[0]) == "illuminated":
        out.append(Diagnostic("error", "lock.fallback", "the fallback must be a separate locker, not this shell"))
    uses_shell_lock = bool(commands["lock"]) and os.path.basename(commands["lock"][0]) == "illuminated" and commands["lock"][1:2] == ["lock"]
    if values["features"].get("lock") and not uses_shell_lock:
        out.append(Diagnostic("warning", "commands.lock", "features.lock is on but Lock and Sleep still run "
                              f"{commands['lock'][0] if commands['lock'] else 'nothing'}; set commands.lock = [\"illuminated\", \"lock\"]"))
    for chord, action in values["binds"].items():
        key = f"binds.{chord}"
        if not action:
            continue
        if not BIND_ACTIONS.match(action):
            out.append(Diagnostic("error", key, f"unknown action {action!r}"))
        elif action.startswith("cards ") and action.split(" ", 1)[1] not in groups:
            out.append(Diagnostic("error", key, f"unknown group in {action!r}"))
        try:
            parse_chord(chord)
        except ValueError as e:
            out.append(Diagnostic("error", key, str(e)))


def parse_chord(chord: str) -> tuple[list[str], str]:
    parts = [p.strip() for p in chord.split("+")]
    if not parts or any(not p for p in parts):
        raise ValueError(f"malformed chord {chord!r}")
    *mods, key = parts
    mods = [m.upper() for m in mods]
    for m in mods:
        if m not in MODIFIERS:
            raise ValueError(f"unknown modifier {m!r} (use {', '.join(sorted(MODIFIERS))})")
    if not KEY_TOKEN.match(key):
        raise ValueError(f"unsupported key {key!r}")
    return mods, key


# ── compositor detection ─────────────────────────────────────────────────

def detect_compositor(configured: str = "auto", env=None, which=shutil.which) -> str:
    if configured != "auto":
        return configured
    env = os.environ if env is None else env
    if env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "hyprland"
    desktop = (env.get("XDG_CURRENT_DESKTOP", "") + ":" + env.get("XDG_SESSION_DESKTOP", "")).lower()
    if "hyprland" in desktop:
        return "hyprland"
    if "mango" in desktop:
        return "mango"
    installed = [name for name, binary in (("hyprland", "Hyprland"), ("mango", "mango")) if which(binary)]
    return installed[0] if len(installed) == 1 else ""


# ── resolution ───────────────────────────────────────────────────────────

def resolve(user: dict, defaults: dict | None = None, hostname: str | None = None,
            source: str = "", env=None) -> Resolved:
    defaults = defaults if defaults is not None else load_defaults()
    schema = defaults["schema"]
    base = shell_defaults(defaults)
    user = copy.deepcopy(user)
    hosts = user.pop("host", {})
    hostname = hostname or socket.gethostname()
    out: list[Diagnostic] = []
    if "schema" in user:
        out.append(Diagnostic("error", "schema", "validation rules cannot be overridden"))
        user.pop("schema")
    _walk(user, base, "", schema, defaults, out)
    if not isinstance(hosts, dict):
        out.append(Diagnostic("error", "host", "expected a table of [host.<name>] tables"))
        hosts = {}
    for name, table in hosts.items():
        if not isinstance(table, dict):
            out.append(Diagnostic("error", f"host.{name}", "expected table"))
            continue
        nested = [Diagnostic(d.level, f"host.{name}.{d.key}" if d.key else f"host.{name}", d.message)
                  for d in _collect(table, base, schema, defaults)]
        out.extend(nested)
    if any(d.level == "error" for d in out):
        raise ConfigError(out)
    layer = merge(user, hosts.get(hostname, {}))
    # New groups and palettes start from their template so they are always complete.
    for table in ("groups", "palettes"):
        for name, value in layer.get(table, {}).items():
            if name not in base[table]:
                base[table][name] = _template_for_new(table, name, defaults)
    values = merge(base, layer)
    _semantic(values, schema, out)
    if any(d.level == "error" for d in out):
        raise ConfigError(out)
    compositor = detect_compositor(values["compositor"], env)
    return Resolved(values=values, pinned=leaves(layer), diagnostics=out, host=hostname,
                    compositor=compositor, source=source)


def _collect(tree, base, schema, defaults):
    out = []
    _walk(tree, base, "", schema, defaults, out)
    return out


def write_defaults_js(path: Path, value) -> None:
    """defaults.json as a QML JavaScript library, so Settings has every default
    before the first binding is evaluated (no "Unable to assign [undefined]")."""
    path.parent.mkdir(parents=True, exist_ok=True)
    text = (".pragma library\n// Generated from config/defaults.toml by `illuminated defaults --write-json`. Do not edit.\n"
            "var values = " + json.dumps(value, indent=2, ensure_ascii=False) + ";\n")
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(text)
    os.replace(temporary, path)


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    os.replace(temporary, path)


# ── line numbers ─────────────────────────────────────────────────────────

_KEY_PART = r'(?:[A-Za-z0-9_-]+|"(?:[^"\\]|\\.)*"|\'[^\']*\')'
_DOTTED = re.compile(rf"\s*({_KEY_PART}(?:\s*\.\s*{_KEY_PART})*)\s*")
_PART = re.compile(_KEY_PART)


def _parts(dotted: str) -> list[str]:
    return [p[1:-1] if p[:1] in "\"'" else p for p in _PART.findall(dotted)]


def key_lines(text: str) -> dict[str, int]:
    """Map each dotted key path written in a TOML file to its first line.

    Only runs on text tomllib has already accepted. It reads table headers and
    the key of each key = value line, and skips the inside of multi-line strings.
    """
    lines, table, in_string = {}, [], None
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if in_string:
            if line.count(in_string) % 2:
                in_string = None
            continue
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and not line.startswith("[["):
            match = _DOTTED.match(line[1:])
            if match and line[1 + match.end():].lstrip().startswith("]"):
                table = _parts(match.group(1))
                for i in range(1, len(table) + 1):
                    lines.setdefault(".".join(table[:i]), number)
            continue
        match = _DOTTED.match(line)
        if match and line[match.end():].startswith("="):
            path = table + _parts(match.group(1))
            for i in range(1, len(path) + 1):
                lines.setdefault(".".join(path[:i]), number)
            value = line[match.end() + 1:]
            for quote in ('"""', "\'\'\'"):
                if value.count(quote) % 2:
                    in_string = quote
    return lines


def locate(diagnostics, text: str, hostname: str) -> None:
    """Attach the config.toml line of each diagnostic's key (or its nearest parent)."""
    lines = key_lines(text)
    for d in diagnostics:
        for candidate in (d.key, f"host.{hostname}.{d.key}" if d.key else ""):
            parts = candidate.split(".") if candidate else []
            while parts and ".".join(parts) not in lines:
                parts.pop()
            if parts:
                d.line = lines[".".join(parts)]
                break


def resolve_file(path: Path | None = None, hostname: str | None = None, env=None) -> Resolved:
    path = path or paths.user_config()
    hostname = hostname or socket.gethostname()
    text = path.read_text() if path.exists() else ""
    try:
        resolved = resolve(load_user(path), hostname=hostname, source=str(path), env=env)
    except ConfigError as e:
        locate(e.diagnostics, text, hostname)
        raise
    locate(resolved.diagnostics, text, hostname)
    return resolved
