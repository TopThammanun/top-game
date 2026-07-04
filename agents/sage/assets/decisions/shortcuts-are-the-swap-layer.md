---
id: shortcuts-are-the-swap-layer
type: convention
title: Gameplay roles live in shortcuts, never in code
domain: assets
tags: [shortcuts, roles, indirection]
status: proposed
enforcement: advise
applies_to: [assets, "data/asset_shortcuts.json", "scripts/**"]
source: ai
related: [id-naming-scheme]
timestamp: 2026-07-04T00:00:00Z
---

`data/asset_shortcuts.json` is a **`{"dot.role": "catalog_id"}`** map — one
level, no nesting. It's the team's abstraction layer between "what does the
player-idle unit *look like*" and "what's the current art id".

## Rules

- Shortcut keys use dot notation and describe **roles**, not looks:
  `unit.player_idle`, `ui.taskbar_panel`, `map.default_tilesheet`.
- When runtime code would otherwise reference a raw catalog id
  (`map_1x_unit_soldier_01_idle`), stop — add a shortcut instead and pass the
  shortcut to `AssetRegistry`.
- Every role that maps to a single catalog id belongs here; roles that need to
  pick from a *set* of ids belong in a data resource (future `resources/units`).
- Shortcuts never chain — `resolve_id` looks up **once**; `dict.get(x, x)`
  returns the value or `x` unchanged. Don't build shortcut-to-shortcut aliases.

## Why "advise" not "block"

There are legitimate cases for using a raw catalog id (a tool script that lists
every button, a one-off generator). The rule is a strong default for runtime
game code, but not literally universal.
