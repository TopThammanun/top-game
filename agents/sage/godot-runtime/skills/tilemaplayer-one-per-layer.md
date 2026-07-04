---
id: tilemaplayer-one-per-layer
type: skill
title: Use TileMapLayer (Godot 4.3+) — one node per layer
domain: godot-runtime
status: proposed
source: ai
enforcement: advise
tags: [tilemap, godot-4, maps, architecture]
---

Godot 4.3 deprecated the multi-layer `TileMap` node in favour of
`TileMapLayer` — one node per layer, composed into a scene. It gives cleaner
z-ordering, independent modulation (useful for fog-of-war), and simpler
per-layer collision and navigation. Since this project's asset pipeline
already emits `map_1x_tilesheet_temperate_water`,
`map_1x_tilesheet_desert_no_water`, and `map_1x_fog_of_war` as separate ids,
each id naturally maps to its own `TileMapLayer`.

**Version note:** `project.godot` currently declares
`config/features=PackedStringArray("4.2")`. Bump the project feature to
`4.3` (or `4.4`+) before adopting `TileMapLayer` — the node does not exist
on 4.2. This is the tracking action if the team hasn't already picked an
engine version for the map work.

Recommend a canonical map scene tree: `Ground`, `Overlay`, `Fog`, `Entities`.
Each is a `TileMapLayer` sharing a `TileSet` resource — the tileset is the
authored data, the layers are the composition.

**Do:**

- Author one `TileSet` resource per biome (`temperate`, `desert`, `snow`) and
  reuse it across layers.
- Load the tileset texture via `AssetRegistry.load_texture` in an editor tool
  script; save the `TileSet` `.tres` in `resources/`.
- Modulate the `Fog` `TileMapLayer.self_modulate` for reveal transitions —
  no shader needed for the MVP look.
- Put entity spawn markers on their own `TileMapLayer` set to `visible=false`
  in-game; runtime code queries `.get_used_cells()`.

**Avoid:**

- The legacy `TileMap` node — deprecated in 4.3+; new projects should start on
  `TileMapLayer`.
- Baking multiple biomes into one `TileSet`; you lose the ability to swap sheets.
- Hard-coding tile coordinates in scripts; expose them as named custom-data
  fields on the tileset and query by name.
