# Compositor include evidence

Two short excerpts of upstream compositor source, kept to back the include lines
`illuminated install` adds. They were captured from the tagged upstream sources
during an earlier evaluation build (candidate C of v3). They were not re-fetched
for this revision, so compare them with the tagged sources before relying on them
for anything beyond these two conclusions.

| File | Upstream source | What it shows |
| --- | --- | --- |
| `hyprland-0.57.0-ConfigManager.cpp.excerpt` | Hyprland v0.57.0, `src/config/lua/ConfigManager.cpp` (BSD-3-Clause) | The config's Lua state calls `luaL_openlibs`, which loads Lua's base library, including `dofile` and `loadfile`. Only `debug.sethook`/`gethook` are removed, and `require` is wrapped. |
| `mango-0.18.4-option_defs.c.excerpt` | Mango 0.18.4, `src/config/option_defs.c` (GPL-3.0) | `source_optional` is parsed with `must_exist = false` and `source` with `true`. |

Conclusions used by the installer:

- Hyprland: `dofile` is available, so the `pcall(dofile …)` block runs the
  generated file; `pcall` still lets Hyprland start if that file is missing.
- Mango: the block uses `source_optional=`, so a missing generated file is
  skipped rather than failing.

This is evidence from source, not a run of either compositor. Live acceptance on
Hyprland and Mango is still required (docs/TESTING-GUIDE.md §15).
