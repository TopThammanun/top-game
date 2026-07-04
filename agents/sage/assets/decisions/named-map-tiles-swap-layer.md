---
id: named-map-tiles-swap-layer
type: team_decision
title: Reference map tiles by name, not raw [col,row]
domain: assets
tags: [assets, maps, tilesheets, swap-layer, tile-names]
status: proposed
enforcement: advise
applies_to: [assets, maps, "data/maps/**", "scripts/maps/**", "scripts/autoload/asset_registry.gd"]
source: ai
supersedes: ""
related: [shortcuts-are-the-swap-layer, slice-sheets-at-registry-boundary, reference-slicing-and-catalog-semantics]
timestamp: 2026-07-05T00:00:00Z
---

Map plans used raw atlas coordinates (`"tile": [12, 5]`) that nobody could read.
Map tiles now get a **named swap layer**, the tile-level twin of
`data/asset_shortcuts.json`.

## The layer

- `data/maps/tile_names.json` — `name -> [col, row]` on the overworld grid
  (`grass`, `water_deep`, `road_h`, `tree`, `bed`, …). Hand-curated; add a name
  here, never a raw `[col,row]`, when map code needs a new tile.
- `AssetRegistry` loads it at boot (`map_tiles`) and exposes:
  `get_map_tile_coords(name) -> [col,row]`, `has_map_tile(name)`,
  `load_map_tile(name, tilesheet_shortcut = "map.default_tilesheet")`.
- Map plans (`data/maps/*_map_plan.json`) put a **name or a raw `[col,row]`** in a
  `tile` field; `emberhearth_map_view.gd::_as_tile_pair` resolves names and still
  accepts pairs, so migration is non-breaking.

## Why it holds

- **Biome-agnostic:** all six tilesheets share one layout, so a name means the same
  grid cell in every biome. Retheme a whole map by swapping the `tilesheet_shortcut`
  and keeping the names.
- **Two swap layers, same idea:** `asset_shortcuts.json` swaps *whole assets* by
  role; `tile_names.json` swaps *tiles within the overworld atlas* by role. Neither
  belongs in game code as a raw id/coordinate.

Rule of thumb: **a `[col,row]` literal in a scene/script or map plan is a smell —
give the tile a name in `tile_names.json` and reference that.**
