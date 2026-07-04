---
id: headless-global-class-cache
type: convention
title: "Headless: 'Identifier not declared' for a global class_name = stale .godot cache, not a code bug"
domain: godot-runtime
tags: [godot, headless, class_name, tests, tooling]
status: proposed
enforcement: warn
applies_to: [godot-runtime, "tests/**", "scripts/combat/**"]
source: ai
supersedes: ""
related: [presenter-owned-game-feel-effects]
timestamp: 2026-07-05T00:00:00Z
---

When a headless run (`Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe
--headless res://tests/<x>.tscn`) prints
`Parse Error: Identifier "<SomeClass>" not declared in the current scope` for a
script that references a project **global `class_name`** (e.g. `CombatEnums`,
`StatSystem`), the cause is almost always a **stale or half-built
`.godot/global_script_class_cache.cfg`**, not a code defect. Godot rebuilds that
cache during a normal project boot; a normal `--headless res://...` run resolves
global class names fine once the cache is intact.

**Do NOT** "fix" it by rewriting the code to `load()`/`preload()` the scripts
into `Variant` locals — that masks the real usage path (the game and the Plan B
scene layer reference these classes by global `class_name`), loses type safety,
and gives false test confidence. A haiku implementer burned ~90 tool calls doing
exactly this on Task 2 of the combat-core plan; the workaround was reverted.

**Do instead:**
- Reference project classes by their global `class_name`, typed, in both game
  code and tests — consistent with the game/Plan B path.
- If you hit the parse error, let the project import cleanly and re-run. Do not
  interrupt `godot --headless --import` — a killed import can leave the class
  cache half-written and transiently break global-name resolution (this is what
  produced the phantom error).
- The existing codebase's alternative for hard cross-script deps is
  `const XxxClass = preload("res://…")` (see `game_state.gd`, `wave_state.gd`);
  use that only when a genuine load-order need exists, not to paper over a cache
  glitch.
