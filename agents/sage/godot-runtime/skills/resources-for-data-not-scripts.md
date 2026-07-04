---
id: resources-for-data-not-scripts
type: skill
title: Model units/skills/items as Resources, not hard-coded scripts
domain: godot-runtime
status: proposed
source: ai
enforcement: advise
tags: [resources, tres, data, godot, designers]
---

Godot's `Resource` (saved as `.tres`) is the idiomatic way to describe a unit,
skill, item, or drop table. A `UnitDef extends Resource` with typed
`@export`ed fields (clan, role, base_hp, base_atk, skill: SkillDef) becomes
editable in the inspector, diffable in git, and swappable without recompile.
This maps directly to the folder contract already in
`data/design_sources.json` — `resources/units` and `resources/commands` are
reserved for exactly this pattern.

For an RPG with 6 clans × multiple units × 5 magic schools × dozens of items,
putting stats in code turns every balance tweak into a script edit. Putting
them in `.tres` files means designers (and future you) can rebalance without
touching GDScript.

**Do:**

- Define one `Resource` subclass per data kind (`UnitDef`, `SkillDef`,
  `ItemDef`, `DropTableDef`); use typed `@export` on every field.
- Reference other resources by `@export var skill: SkillDef` — Godot handles
  the load and reload.
- Load lists via `ResourceLoader.load()` + a directory scan, or catalog them
  through `AssetRegistry`-style shortcuts.
- Version your resource schema — add a `@export var schema_version := 1`
  field so migrations have a hook.

**Avoid:**

- `const UNITS = { "player": {"hp": 100, ...} }` dictionaries in GDScript —
  no editor UI, no reload, no reuse.
- One giant `game_data.json` — hurts diffs and puts unrelated data in the
  same conflict.
- Storing player-owned state (level, gear) in the *definition* resource; keep
  definitions immutable and runtime state in a separate save object.
