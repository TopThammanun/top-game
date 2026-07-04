---
id: map-object-stamps-use-named-top-left
type: team_decision
title: Stamp multi-tile map objects from a named top-left tile
domain: assets
tags: [assets, maps, tilesheets, map-plan, object-stamps]
status: proposed
enforcement: advise
applies_to: [assets, maps, "data/maps/**", "scripts/maps/**", "scripts/autoload/asset_registry.gd"]
source: ai
supersedes: ""
related: [named-map-tiles-swap-layer, slice-sheets-at-registry-boundary, reference-slicing-and-catalog-semantics]
timestamp: 2026-07-05T00:00:00Z
---

When a map needs a multi-tile object from the overworld atlas, name the object's
top-left tile in `data/maps/tile_names.json` and place it in the map plan as a
stamp with `width`, `height`, `tile`, and `mode: "stamp"`.

Runtime renderers should ask `AssetRegistry` for each offset cell from that
named top-left tile. Do not point runtime code at `asset_sliced/`, and do not put
raw `[col,row]` object coordinates directly in scene scripts.

Do:

- Use `asset_sliced/tiles/.../index.json` or labeled atlas previews to choose the
  object top-left once.
- Capture that top-left as a readable name such as `house_orange` or
  `market_canopy`.
- Let the map plan decide placement and dimensions.
- Keep the sheet slicing call at the registry boundary, e.g.
  `AssetRegistry.load_map_tile_offset(name, dx, dy, tilesheet_shortcut)`.

Avoid:

- Loading generated cut-out PNGs from `asset_sliced/` in the running game.
- Repeating object coordinate math across scene scripts.
- Creating one shortcut per visual placement; shortcuts name whole asset roles,
  tile names name atlas cells.
