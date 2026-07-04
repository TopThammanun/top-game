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

**Cross-reference project scripts with `const XxxClass = preload("res://…")`,
not bare global `class_name`.** A newly-added `class_name` script is only
registered in `.godot/global_script_class_cache.cfg` after a filesystem
scan/import; a plain `--headless res://tests/<x>.tscn` run does NOT rescan, so a
brand-new class referenced by bare name fails to parse with
`Parse Error: Identifier "<SomeClass>" not declared in the current scope` (and,
because the scene script then fails to load, the headless process never calls
`quit()` and hangs). A full `godot --headless --import` does register it but is
very slow here (minutes, and interrupting it corrupts the cache). `preload`
resolves by **path at compile time** with no dependency on the class cache, so
the module works on a fresh checkout with no import step. This is already the
codebase convention (`game_state.gd`, `wave_state.gd`).

Concretely, `scripts/combat/*` cross-reference each other like:
```gdscript
const CombatEnumsClass = preload("res://scripts/combat/combat_enums.gd")
# ... CombatEnumsClass.StatKey.ATK, StatSystemClass.new(...), etc.
```
Keep `class_name` on the scripts (harmless, good for the editor and eventual
global use), but do not rely on it for cross-script references or in tests.
When a param's type is another combat class, leave it untyped (Variant) as the
codebase does — a `:=` local derived from an untyped value must then be given an
explicit type (`var atk: float = attacker.get_stat(...)`).

**Do NOT** "fix" the parse error by loading scripts into `Variant` locals inside
`_enter_tree`/`_ready`, and do NOT run `--import` to paper over it. A haiku
implementer burned ~90 tool calls on the `load()` route on Task 2; a later task
went BLOCKED on the unregistered new class. The preload convention removes the
whole failure mode.
