---
id: asset-registry-is-only-runtime-lookup
type: team_decision
title: AssetRegistry is the only sanctioned runtime asset lookup
domain: godot-runtime
tags: [assets, autoload, hard-coded-paths]
status: proposed
enforcement: block
applies_to: [godot-runtime, "scripts/**", "scenes/**"]
source: ai
related: [asset-registry-api]
timestamp: 2026-07-04T00:00:00Z
---

Runtime code MUST load textures, fonts, and any file under `asset/` through
`AssetRegistry`. Never hard-code `res://asset/...` paths in `.gd`, and never
`preload()` an asset by path.

**Prefer shortcut ids** (`"unit.player_idle"`, `"ui.taskbar_panel"`) over raw
catalog ids (`"map_1x_unit_soldier_01_idle"`) so art can be swapped by editing
`data/asset_shortcuts.json` without touching a single scene or script.

Why this rule:

- The asset catalog is regenerated from `tools/generate_asset_catalog.ps1`; ids
  are stable-by-slug, paths are not — a rename in `asset/` won't move the id,
  it will move the path.
- Missing assets fail through `push_warning` from `AssetRegistry` rather than a
  hard resource-load crash on scene entry.
- The shortcuts layer is the team's abstraction for "what does *this role* look
  like right now" — bypassing it defeats the point.

Exceptions:

- Editor-time TileSet/TileMap `.tres` files that must reference a `res://...`
  texture in Godot's inspector — those go through the editor, not runtime code.
- `project.godot` itself (default font, icon) — that's engine config, not runtime.
