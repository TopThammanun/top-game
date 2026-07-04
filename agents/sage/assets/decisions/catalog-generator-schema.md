---
id: catalog-generator-schema
type: convention
title: Asset catalog entry schema
domain: assets
tags: [catalog, schema, powershell, generator]
status: proposed
enforcement: advise
applies_to: [assets, "data/asset_catalog.json", "tools/generate_asset_catalog.ps1"]
source: ai
related: [id-naming-scheme, slice-sheets-at-registry-boundary]
timestamp: 2026-07-04T00:00:00Z
---

`tools/generate_asset_catalog.ps1` walks `asset/` and emits an array of entry
objects to `data/asset_catalog.json`. Every entry has this shape (all lowercase
keys, ordered as below):

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `string` | Stable slug id - the primary key. See `id-naming-scheme.md`. |
| `category` | `string` | Top pack bucket: `map` or `ui`. |
| `pack` | `string` | Sub-pack: `tactical_overworld` or `fantasy_ui`. |
| `kind` | `string` | Semantic kind (`tilesheet`, `unit_sprite`, `button`, `item_slot`, `mini_icon`, `resource_orb`, `bitmap_font`, `title_banner`, ...). |
| `group` | `string` | Original folder / UI group name (`Character sprites`, `Buttons`, `Item slots`, `Fonts`, `Fog of war`, `Legal`, `Marketing`, `Unsorted`). |
| `scale` | `string` or `null` | `1x` / `2x` / `3x` where the file belongs to a scale; `null` for fonts, licenses, banners. |
| `name` | `string` | Original filename without extension. |
| `extension` | `string` | Lowercased, includes the dot: `.png`, `.gif`, `.ttf`, `.txt`. |
| `source_path` | `string` | Repo-relative path with forward slashes (`asset/ui/...`). |
| `godot_path` | `string` | `res://` + `source_path`. Runtime callers still go through `AssetRegistry`. |
| `file_size` | `int` | Bytes. |
| `width`, `height` | `int` or `null` | From `System.Drawing.Image`; populated for `.png/.gif` only. |
| `tags` | `string[]` | Deduped slug list built from `category`, `pack`, `kind`, `group`, `scale`, plus every `Extra` value. |

Kind-specific extras are added into the entry object alongside the base fields:

| Kind | Extras |
| --- | --- |
| `unit_sprite` | `unit_class` (raw name), `variant` (`01`, `02`, ...), `animation` (`idle` / `move`), `grid_cell_width`, `grid_cell_height`, `grid_columns`, `grid_rows`, `frame_count` |
| `tilesheet` | `biome` (`temperate` / `desert` / `snow`), `includes_water` (`bool`), `tile_width`, `tile_height`, `tile_columns`, `tile_rows` |
| `fog_of_war` | `tile_width`, `tile_height`, `tile_columns`, `tile_rows` |
| `button`, `checkbox`, `mini_icon`, ... | `state` if the filename ends in `Normal`, `Pressed`, `Selected`, `On`, `Off`, `Bullet`, or `Outline`. |

For tactical map assets, grid size comes from the pack license:
`1x = 16x16`, `2x = 32x32`, `3x = 48x48`. The generator records those values so
runtime code can crop sheets through `AssetRegistry` instead of guessing.

## Alongside Outputs

The generator also writes `docs/ASSET_INDEX.generated.md` with counts by
category / scale / kind / group and a "TBH quick ids" list. Both outputs are
UTF-8 without BOM; the script uses `System.Text.UTF8Encoding($false)`
explicitly, so do not switch it to `Out-File`.

## Extending The Generator

- Add a new UI kind: extend `Get-UiKind`'s switch (matches the folder name).
- Add a new state suffix: extend `Get-StateFromName`.
- Add a new pack: add a new `if ($repoPath -like "asset/<pack>/*")` block
  mirroring the map/ui branches; fall through to the `unknown` / `Unsorted`
  bucket at the end so nothing goes missing.
- Adding an `Extra` field automatically adds its slug to `tags`; that is the hook
  for making a new attribute searchable via `AssetRegistry.find_assets`.
