---
id: id-naming-scheme
type: team_decision
title: Asset ids are hierarchical, slug-derived, and generated
domain: assets
tags: [naming, ids, catalog]
status: proposed
enforcement: block
applies_to: [assets, "data/asset_catalog.json", "data/asset_shortcuts.json"]
source: ai
related: [catalog-generator-schema, shortcuts-are-the-swap-layer]
timestamp: 2026-07-04T00:00:00Z
---

Every catalog id follows one of these shapes. Do not invent ids by hand —
generate them and reference them.

## Map ids

- Tilesheets: `map_{scale}_tilesheet_{biome}_{water|no_water}`
  e.g. `map_1x_tilesheet_temperate_water`, `map_1x_tilesheet_desert_no_water`.
- Unit sprites: `map_{scale}_unit_{unit_class_slug}_{variant}_{idle|move}`
  e.g. `map_1x_unit_soldier_01_idle`, `map_2x_unit_archer_02_move`.
- Fog of war: `map_{scale}_fog_of_war`.
- Examples/marketing/legal: `map_example_{slug}`, `map_banner`, `map_license`.

## UI ids

- Individual files: `ui_{scale}_{kind}_{source_slug}`
  e.g. `ui_1x_button_button_01a_normal`, `ui_1x_item_slot_slot_01_empty`.
- Full spritesheets: `ui_{scale}_spritesheet`.
- Fonts: `ui_font_{source_slug}` — no scale; the slug carries a `size_{n}` from
  the parenthesised `(size N)` in the filename.
- Reference sheet: `ui_reference_sheet`. Examples/legal: `ui_example_{slug}`,
  `ui_license`.

## Slug rules (`Convert-ToSlug`)

- Lowercase.
- `(No Water Layer)` → `no_water`, `(size N)` → `size_N`.
- Every non `[a-z0-9]` run collapses to `_`.
- Repeated `_` collapse; leading/trailing `_` trimmed.

## Why "block"

The whole runtime depends on ids being stable across regenerations. Handwritten
ids in game code or shortcuts will silently drift when the generator changes
casing, punctuation, or hierarchy. If you need an id, run the generator and
copy the id out of `data/asset_catalog.json` — don't guess.
