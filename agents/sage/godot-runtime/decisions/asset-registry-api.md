---
id: asset-registry-api
type: convention
title: AssetRegistry export surface
domain: godot-runtime
tags: [autoload, assets, api]
status: proposed
enforcement: advise
applies_to: [godot-runtime, "scripts/**", "scenes/**"]
source: ai
related: [asset-registry-is-only-runtime-lookup, wait-for-catalog-ready]
timestamp: 2026-07-04T00:00:00Z
---

`AssetRegistry` is registered as an autoload (`*res://scripts/autoload/asset_registry.gd`),
so callers use it as a global singleton — `AssetRegistry.<member>` from anywhere.
This is the **only** sanctioned runtime API for reading `asset/`; do not open
files directly.

## State

| Member | Type | Purpose |
| --- | --- | --- |
| `entries` | `Array` (of `Dictionary`) | Every asset catalog row, in load order. |
| `by_id` | `Dictionary[String, Dictionary]` | Fast lookup by catalog `id`. |
| `shortcuts` | `Dictionary[String, String]` | Shortcut id → catalog id (from `data/asset_shortcuts.json`). |
| `loaded` | `bool` | `true` once the catalog JSON parsed successfully. |

## Signals

| Signal | Fires |
| --- | --- |
| `catalog_ready` | Once, after `_ready()` finishes loading and shortcuts (or on manual `load_catalog()` reload). |

## Functions

| Function | Signature | Notes |
| --- | --- | --- |
| `load_catalog()` | `() -> void` | Reloads catalog + shortcuts from disk. Clears state first. Emits `catalog_ready` on success. Warns / errors on missing or malformed files. |
| `resolve_id(x)` | `(String) -> String` | Returns the underlying catalog id for a shortcut, or `x` unchanged if it's already an id. |
| `get_entry(x)` | `(String) -> Dictionary` | Accepts an id **or** a shortcut. Returns `{}` if not found — never `null`. |
| `has_asset(x)` | `(String) -> bool` | Convenience wrapper — `true` iff `get_entry(x)` is non-empty. |
| `get_asset_path(x)` | `(String) -> String` | Returns the `godot_path` (`res://…`) or `""`. |
| `load_texture(x)` | `(String) -> Texture2D` | Returns a `Texture2D` for id/shortcut, or `null` (with `push_warning`) if missing. Falls back to raw `Image.load` + `ImageTexture.create_from_image` for extensions `.png/.jpg/.jpeg/.webp/.bmp/.tga`. |
| `get_sheet_grid(x)` | `(String) -> Dictionary` | Returns grid facts for sheet-like assets: `cell_width`, `cell_height`, `columns`, `rows`. Uses catalog metadata first, then map scale fallback (`1x=16`, `2x=32`, `3x=48`). |
| `load_texture_region(x, region)` | `(String, Rect2i) -> Texture2D` | Crops a source image region in memory and returns it as a texture. Warns and returns `null` for empty/out-of-bounds regions. |
| `load_grid_cell(x, column, row)` | `(String, int, int) -> Texture2D` | Crops one grid cell from a tilesheet or sprite sheet using `get_sheet_grid`. |
| `load_sprite_frame(x, column = 0, row = 0)` | `(String, int, int) -> Texture2D` | Semantic wrapper for unit sprite frames; current static presenters use `(0, 0)` until animation state chooses frames. |
| `load_sprite_frames(x, row = 0)` | `(String, int) -> Array` | Crops every column in one sprite-sheet row into separate frame textures for future animation playback. |
| `find_assets(filters)` | `(Dictionary = {}) -> Array` | Filters `entries`. See "Filter language" below. |
| `ids_for(filters)` | `(Dictionary = {}) -> PackedStringArray` | Same as `find_assets` but returns just the ids. |

Underscore functions (`_is_image_file`, `_load_image_texture`, `_load_image`,
`_map_grid_size_for_scale`, `_entry_matches`, `_entry_tags`) are internal and
MUST NOT be called from outside the autoload.

## Filter language for `find_assets` / `ids_for`

Filters are a `Dictionary`. Every filter must match (AND). Recognised keys:

| Key | Value | Match rule |
| --- | --- | --- |
| `name_contains` | `String` | Case-insensitive substring on `id + " " + name + " " + source_path`. |
| `tag` | `String` | Entry's `tags` includes this exact tag. |
| `tags_all` | `Array[String]` | Every tag in the array is present on the entry. |
| `tags_any` | `Array[String]` | At least one tag in the array is present. |
| any other key | scalar or `Array` | Entry must have the key; scalar → string-equality; `Array` → any-of. |

`find_assets` covers a wider surface than its name suggests — it does substring
search, tag intersections, and multi-value equality all in the same call.
Reach for it before writing a new filter loop.

## Idiomatic use

```gdscript
if AssetRegistry.loaded:
    _populate_assets()
else:
    AssetRegistry.catalog_ready.connect(_populate_assets, CONNECT_ONE_SHOT)

var idle := AssetRegistry.load_texture("unit.player_idle")     # shortcut
var pose := AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)
var pose_row := AssetRegistry.load_sprite_frames("unit.player_idle", 0)
var grass := AssetRegistry.load_grid_cell("map.default_tilesheet", 12, 5)
var slots := AssetRegistry.find_assets({
    "category": "ui",
    "group": "Item slots",
    "scale": "1x",
})
```
