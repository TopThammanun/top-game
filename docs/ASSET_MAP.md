# Asset Map

This project keeps the original asset packs in `asset/` and adds generated lookup files in `data/`.

> **Just want to use art?** Read [`ASSET_AI_PLAYBOOK.md`](ASSET_AI_PLAYBOOK.md) — the
> directive "I want X → use this asset, load it this way" playbook for AI and humans.
>
> **New to the art?** Read [`ASSET_GUIDE.md`](ASSET_GUIDE.md) first — it explains,
> in plain language, what every asset is, whether it is a **combined sheet that
> must be cut** or an **isolated ready-to-use image**, and how to use each kind.
> Per-asset descriptions, usage notes and prompts also live on every
> `data/asset_catalog.json` entry (`description` / `usage` / `prompt` /
> `is_atlas` / `sliced_reference`). Cut-up reference pieces: `asset_sliced/`.

## AI workflow

1. Read `data/asset_shortcuts.json` first for common gameplay roles.
2. Use `data/asset_catalog.json` when a shortcut does not exist.
3. Prefer the generated `id` field over hard-coded paths.
4. Use `AssetRegistry` in Godot code when loading resources; do not hard-code
   `res://asset/...` paths in runtime scripts.
5. Regenerate the catalog after any asset rename, addition, or removal.

## Runtime lookup

```gdscript
var idle_texture := AssetRegistry.load_texture("unit.player_idle")
var idle_frame := AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)
var idle_row_frames := AssetRegistry.load_sprite_frames("unit.player_idle", 0)
var grass_tile := AssetRegistry.load_grid_cell("map.default_tilesheet", 12, 5)
var icon_path := AssetRegistry.get_asset_path("ui.icon_primary")
var slots := AssetRegistry.find_assets({
	"category": "ui",
	"group": "Item slots",
	"scale": "1x"
})
```

## Directory overview

- `asset/map/1x`, `asset/map/2x`, `asset/map/3x`: tactical map tilesheets and fog of war.
- `asset/map/*/Character sprites`: unit spritesheets with `Idle` and `Move` animations.
- `asset/ui/Individual files/*`: UI pieces split by scale and UI group.
- `asset/ui/Fonts`: pixel TTF fonts for title, outline title, and text.
- `data/asset_catalog.json`: generated full catalog.
- `data/asset_shortcuts.json`: hand-curated stable aliases.
- `docs/ASSET_INDEX.generated.md`: generated summary for quick scanning.

## Map asset notes

The map pack includes three scales:

- `1x`: 16x16 grid.
- `2x`: 32x32 grid.
- `3x`: 48x48 grid.

Tilesheets and character sprites are source sheets, not display-ready single
textures:

- `kind = "tilesheet"` entries expose `tile_width`, `tile_height`,
  `tile_columns`, and `tile_rows`.
- `kind = "unit_sprite"` entries expose `grid_cell_width`, `grid_cell_height`,
  `grid_columns`, `grid_rows`, and `frame_count`.
- Runtime map code should compose maps from `AssetRegistry.load_grid_cell(...)`.
- Runtime character code should render a cropped pose with
  `AssetRegistry.load_sprite_frame(...)` until a real animation controller picks
  frame columns/rows over time.
- Runtime animation code can use `AssetRegistry.load_sprite_frames(...)` to split
  one sprite-sheet row into separate frame textures.

Tilesheet ids follow this pattern:

```text
map_{scale}_tilesheet_{biome}_{water|no_water}
```

Examples:

- `map_1x_tilesheet_temperate_water`
- `map_1x_tilesheet_desert_no_water`
- `map_1x_tilesheet_snow_water`

Unit sprite ids follow this pattern:

```text
map_{scale}_unit_{unit_class}_{variant}_{idle|move}
```

Examples:

- `map_1x_unit_soldier_01_idle`
- `map_1x_unit_villager_01_move`
- `map_1x_unit_archer_01_idle`

## UI asset notes

UI ids follow this pattern for individual files:

```text
ui_{scale}_{kind}_{source_file_slug}
```

Examples:

- `ui_1x_background_box_bgbox_01a`
- `ui_1x_item_slot_slot_01_empty`
- `ui_1x_button_button_01a_normal`
- `ui_1x_mini_icon_icon_01_selected`

Font ids follow:

```text
ui_font_{source_file_slug}
```

Examples:

- `ui_font_fantasyrpgtext_size_8`
- `ui_font_fantasyrpgtitle_size_11`

## TBH starter shortcuts

Use these role aliases in game code so art can be swapped later without touching scenes:

- `map.default_tilesheet`
- `map.fog_of_war`
- `unit.player_idle`
- `unit.worker_idle`
- `unit.scout_idle`
- `unit.ranged_idle`
- `unit.mage_idle`
- `ui.taskbar_panel`
- `ui.slot_empty`
- `ui.button_normal`
- `ui.icon_primary`
- `ui.hp_orb`

## License reminder

Both asset packs are by Franuka. The license files in `asset/map` and `asset/ui` allow commercial and non-commercial use and request credit/link attribution. Keep those license files with the project.
