# Asset AI Playbook — tell the AI what to use, and how

> **Read this before you place, draw, or load ANY art in this project.**
> It answers one question fast: *"I want X on screen — which asset do I use and
> how do I load it?"* If you follow the recipes below you will never hard-code an
> art path, never mis-use a sheet, and always pick the right piece.
>
> Deeper reference: [ASSET_GUIDE.md](ASSET_GUIDE.md) (what every asset is) ·
> [ASSET_MAP.md](ASSET_MAP.md) (the pipeline) · machine data:
> `data/asset_catalog.json`, `data/asset_shortcuts.json`, `data/maps/tile_names.json`.

---

## 0. The five rules (never break these)

1. **Never hard-code `res://asset/...` paths in game code.** Always go through the
   `AssetRegistry` autoload.
2. **Prefer, in this order:** a **shortcut** (`unit.player_idle`) → a **named map
   tile** (`"grass"`) → a **catalog id** (`ui_1x_button_button_01a_normal`) →
   a **filter** (`find_assets({...})`). Reach for the lower option only when the
   higher one doesn't exist — and if you had to use a raw id in code, add a
   shortcut for it instead.
3. **Check `is_atlas` first.** `true` = a combined sheet → **you must slice it**
   (frame or tile). `false` = a finished image → **use it directly**. Never draw a
   whole sheet as one picture.
4. **Pick one scale (`1x`/`2x`/`3x`) and stay on it.** They are the same art at
   different resolution. `1x` (16px grid) is the default.
5. **If you added/renamed/removed anything under `asset/`,** regenerate the catalog
   (`tools/generate_asset_catalog.ps1`) before you call the task done.

---

## 1. "I want ___ " → use this (intent recipes)

| I want to… | Use | How (GDScript) |
|---|---|---|
| Show a **player / enemy unit** (still pose) | shortcut `unit.player_idle` (also `unit.worker_*`, `unit.scout_*`, `unit.ranged_*`, `unit.mage_*`) | `AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)` |
| **Animate** a unit | same shortcut, `_Move` variant for walking | `for f in AssetRegistry.load_sprite_frames("unit.player_move", 0): frames.add_frame(...)` → `AnimatedSprite2D` |
| A specific unit class not covered by a shortcut | catalog id `map_1x_unit_<class>_<01-06>_<idle|move>` | `AssetRegistry.load_sprite_frame("map_1x_unit_archer_02_idle", 0, 0)` — then add a shortcut |
| Put **one map tile** (grass, water, road, tree…) | **named tile** via `data/maps/tile_names.json` | `AssetRegistry.load_map_tile("grass")` / `load_map_tile("water_deep")` |
| Build a **whole map** | a map plan `data/maps/*_map_plan.json` using tile **names** | see §3; renderer resolves names to cells |
| **Fog of war** overlay | shortcut `map.fog_of_war` | `AssetRegistry.load_grid_cell("map.fog_of_war", col, row)` on a layer above terrain |
| A **window / panel / tooltip / taskbar** | `ui.taskbar_panel` or `ui.panel_dark` | load, wrap in a **`NinePatchRect`** so the border keeps its corners |
| A **button** | `ui.button_normal` / `ui.button_pressed` / `ui.button_selected` | `TextureButton`; swap the three state textures |
| **HP / MP / Energy** readout | `ui.hp_orb` / `ui.mp_orb` / `ui.energy_orb` | load directly; pair with a bar/fill |
| An **inventory slot** | `ui.slot_empty` (or `ui.slot_weapon`, `ui.slot_potion`) | load directly; overlay the real item icon on top |
| A small **icon** (stat/action/resource) | `ui.icon_primary` (+ `_selected` state) | load directly |
| **Text / titles** | fonts `ui.font_text` (body) / `ui.font_title` (titles) | load as `FontFile`; sizes at multiples of **8** (text) / **11** (title) |

If nothing above fits, go to §4 (search the catalog).

---

For multi-tile map objects such as houses, tents, and market props, add a
readable name for the object's top-left tile in `data/maps/tile_names.json`, then
place it in the map plan as a stamp:
`{ "tile": "house_orange", "width": 3, "height": 3, "mode": "stamp" }`.
The renderer calls `AssetRegistry.load_map_tile_offset(...)` for each stamp cell;
do not point runtime code at `asset_sliced/`.

## 2. Which loader for which kind

Decide by the entry's `kind` / `is_atlas` (both are in `data/asset_catalog.json`):

| Asset kind | `is_atlas` | Loader to call |
|---|---|---|
| `unit_sprite` (character sheet) | true | `load_sprite_frame(id, col, row)` (one pose) · `load_sprite_frames(id, row)` (a track) |
| `tilesheet` (map atlas) | true | `load_grid_cell(id, col, row)` — or `load_map_tile(name)` for a named cell |
| `fog_of_war` | true | `load_grid_cell(id, col, row)` |
| any UI `background_box`/`button`/`checkbox`/`cursor`/`divider`/`item_slot`/`mini_icon`/`resource_orb`/`slider_bar`/`spellbook_tab`/`title_banner` | false | `load_texture(id)` — **use directly** |
| `font` (`.ttf`) | false | load as `FontFile` (not `load_texture`) |
| `example` / `banner` / `reference` / `license` | — | **do not use in game** (previews / legal only) |

Rule: **`is_atlas: true` → you must crop it. `is_atlas: false` → never crop it.**

---

## 3. Maps: name your tiles, don't use raw coordinates

A `[col, row]` literal is unreadable. In map plans and code, reference a **name**
from `data/maps/tile_names.json`:

```jsonc
// data/maps/emberhearth_map_plan.json
"tile_layers": {
  "ground_fill": { "tile": "grass" },
  "roads":       [ { "x": 0, "y": 3, "width": 24, "height": 1, "tile": "road_h" } ],
  "decor":       [ { "x": 1, "y": 1, "tile": "tree" } ]
}
```

For multi-tile objects, name the **top-left** tile once and stamp it with
`width`/`height`:

```jsonc
"stamps": [
  { "x": 3, "y": 0, "width": 3, "height": 3, "tile": "house_orange", "mode": "stamp" }
]
```

The running game still slices through `AssetRegistry`; never point runtime code
at `asset_sliced/`.

Available names include: `grass`, `grass_plain`, `grass_tuft`, `sand`, `water`,
`water_deep`, `road` / `road_h` / `road_v` / `road_alt`, `tree` / `tree_2` /
`tree_pine`, `sapling`, `plant`, `rock` / `rock_snow`, `bed`.

- **Need a tile with no name yet?** Add it to `tile_names.json` (find its
  `col,row` in `asset_sliced/tiles/<sheet>/<scale>/index.json`). Do **not** put a
  raw `[col,row]` in game code.
- **Retheme a whole map to desert/snow:** keep the names, swap the sheet —
  `load_map_tile("grass", "map.desert_tilesheet")`, or set the plan's
  `tilesheet_shortcut` to `map.desert_tilesheet` / `map.snow_tilesheet`. The names
  mean the same cell in every biome.

---

## 4. When there's no shortcut / name yet

Query the catalog by fields instead of guessing a path:

```gdscript
# every 1x weapon inventory slot
var slots := AssetRegistry.find_assets({ "kind": "item_slot", "scale": "1x" })
# just the ids
var ids := AssetRegistry.ids_for({ "unit_class": "Archer", "animation": "idle" })
# fuzzy
var reds := AssetRegistry.find_assets({ "name_contains": "red" })
```

Filter keys: any entry field (`category`, `kind`, `group`, `scale`, `biome`,
`unit_class`, `animation`, `state`, `is_atlas`, …) plus `name_contains`, `tag`,
`tags_all`, `tags_any`. Once you pick one, **add a shortcut or tile name** so the
next caller doesn't repeat the search.

---

## 5. Paste-in preamble for prompting an AI

When you instruct an AI to build UI or maps in this repo, drop this at the top so
it uses assets correctly:

```text
Assets: never hard-code res://asset/... paths — load through the AssetRegistry
autoload. Prefer a shortcut (data/asset_shortcuts.json) → a named map tile
(data/maps/tile_names.json) → a catalog id (data/asset_catalog.json) → a
find_assets({...}) filter. Check is_atlas: true means a sheet you must slice
(load_sprite_frame / load_grid_cell / load_map_tile), false means use load_texture
directly. Map tiles go by name ("grass", "road_h", "water_deep"), never raw
[col,row]. Fonts load as FontFile at multiples of 8 (text) / 11 (title). Stay on
one scale (1x). Full recipes: docs/ASSET_AI_PLAYBOOK.md. If I add art under
asset/, run tools/generate_asset_catalog.ps1.
```

---

## 6. Before you say "done"

- Touched `asset/`? → `powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1`.
- Added a runtime asset choice in code? → it should be a **shortcut** or **tile
  name**, not a raw id/path.
- The game must still boot: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/capture_runtime_screenshot.ps1`.
