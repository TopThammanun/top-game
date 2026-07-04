# Asset Guide — what every asset is and how to use it

> Audience: **an AI agent (or human) that has been told to "use the art" and does
> not know what is in `asset/`.** This is the plain-language map of the two art
> packs: what each file is, whether it is a **combined sheet that must be cut**
> or an **isolated ready-to-use image**, how to load it, and a description/prompt
> for each kind.
>
> In a hurry / just need to *use* an asset? Jump to
> [ASSET_AI_PLAYBOOK.md](ASSET_AI_PLAYBOOK.md) — the "I want X → use this, load it
> this way" recipes. This guide is the deeper reference behind it.
>
> Machine-readable twin: every fact here is also a field on each entry in
> [`data/asset_catalog.json`](../data/asset_catalog.json) —
> `is_atlas`, `description`, `usage`, `prompt`, `sliced_reference`. Read the JSON
> when you need a specific file; read this guide to understand the whole library.

---

## 0. The 30-second version

- Art comes from **two Franuka packs**: `asset/map/` (Tactical RPG Overworld) and
  `asset/ui/` (Fantasy UI). Both ship in **three scales — `1x` (16px grid), `2x`
  (32px), `3x` (48px)** — the *same* art at different resolutions. Pick one scale
  and stick to it; don't mix.
- Two kinds of asset:
  - **Atlas / sheet** (`is_atlas: true`) — many things packed in one PNG. You
    **must slice it** before use (a spritesheet → animation frames, a tilesheet →
    map tiles). Never draw the whole sheet as one image.
  - **Isolated** (`is_atlas: false`) — one finished thing per PNG (a button, an
    icon, an orb). Use it directly.
- **Never hard-code `res://asset/...` paths.** Go through `AssetRegistry`
  (shortcut → id → path) — see [ASSET_MAP.md](ASSET_MAP.md).
- The **cut-up reference pieces** already exist under **`asset_sliced/`** so you
  can *see* each frame/tile. That folder is a **reference only** (regenerate with
  `tools/slice_sheets.ps1`); the running game still slices via `AssetRegistry`.

---

## 1. How to look an asset up

```text
1. data/asset_shortcuts.json   → stable gameplay roles (unit.player_idle, ui.hp_orb)
2. data/asset_catalog.json     → every file, with description/usage/prompt/is_atlas
3. docs/ASSET_GUIDE.md (here)   → what a whole category is and how to use it
4. asset_sliced/               → the sheets cut into individual pieces, to eyeball
```

Runtime loading (GDScript, via the `AssetRegistry` autoload):

```gdscript
# isolated image — use directly
var hp := AssetRegistry.load_texture("ui.hp_orb")

# spritesheet — slice a pose or a whole animation row
var pose  := AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)   # col, row
var track := AssetRegistry.load_sprite_frames("unit.player_idle", 0)      # Array of 4 frames

# tilesheet — pull one map cell
var grass := AssetRegistry.load_grid_cell("map.default_tilesheet", 12, 5) # col, row

# query by fields
var slots := AssetRegistry.find_assets({ "kind": "item_slot", "scale": "1x" })
```

---

## 2. Atlas vs isolated — how to tell, per folder

| Folder | Kind | `is_atlas` | Must cut? | Notes |
|---|---|---|---|---|
| `asset/map/*/Character sprites/*.png` | `unit_sprite` | ✅ | Yes → frames | 4×4 grid = 16 frames each |
| `asset/map/*/*Tilesheet*.png` | `tilesheet` | ✅ | Yes → tiles | 1024² atlas, 16px grid |
| `asset/map/*/FogOfWar.png` | `fog_of_war` | ✅ | Yes → tiles | small autotile overlay |
| `asset/ui/Individual files/**` | many | ❌ | No | already one item per file |
| `asset/ui/Fonts/*.ttf` | `font` | ❌ | No | load as a Font |
| `asset/ui/UI assets (Nx).png`, `Reference sheet.png` | `spritesheet` / `reference` | ✅ | — | redundant with Individual files |
| `asset/*/Examples/*.gif`, `Banner.gif` | `example` / `banner` | ❌ | — | previews, **not** game assets |
| `asset/*/License and details.txt` | `license` | ❌ | — | keep for attribution |

---

## 3. MAP pack — `asset/map/` (Tactical RPG Overworld, by Franuka)

Top-down tactical/overworld art. Everything is on a **16px grid at 1x** (32px @2x,
48px @3x). Three biomes, all built on one identical layout.

### 3.1 Character sprites — `asset/map/<scale>/Character sprites/`

- **File pattern:** `<Class>_<Variant 01-06>_<Idle|Move>.png`
  (e.g. `Soldier_01_Idle.png`, `Archer_03_Move.png`).
- **Every sprite is a 64×64 atlas at 1x = a 4×4 grid of 16px frames (16 frames).**
- **Layout:** each **row = one animation track** (a facing/pose), each **column =
  a frame** in that track (4 frames). Row 0 faces the camera (down). The units are
  the **Whisker Realm cat clans** — the Soldier is a spear-carrying cat in a blue
  hat, etc.
- **Idle** vs **Move** are separate sheets with the same 4×4 shape.
- **Cut, don't blit:** show one pose with `load_sprite_frame(id, col, row)`; play a
  loop by feeding `load_sprite_frames(id, row)` into an `AnimatedSprite2D` /
  `SpriteFrames`. Pre-cut frames + row strips: `asset_sliced/units/<scale>/<name>/`.

**Unit classes** (`unit_class` field; not all are cats — some are ships/engines):

| Class | What it is | Variants |
|---|---|---|
| Soldier | melee cat with spear (default player) | 6 |
| Vanguard | armoured frontline tank cat | 6 |
| Archer | ranged bow cat | 6 |
| Acolyte | robed mage cat with staff | 6 |
| Healer | support/heal cat | 6 |
| Scout | fast light cat | 6 |
| Sapper | demolitions cat | 6 |
| Villager | civilian/worker cat | 6 |
| BeastRider | cat riding a beast | 6 |
| Beast | wild creature / mount | 6 |
| Elemental | magic energy elemental | 4 |
| Ram | wheeled battering ram (siege) | 6 |
| Siege | catapult / siege engine | 6 |
| Battleship | large warship | 6 |
| Frigate | mid warship | 6 |
| FishingBoat | small civilian boat | 6 |
| TransportShip | troop/cargo ship | 6 |

Shortcuts already map the common roles: `unit.player_idle/move` (Soldier),
`unit.worker_*` (Villager), `unit.scout_*`, `unit.ranged_*` (Archer),
`unit.mage_*` (Acolyte). Add a shortcut when you need a new role — don't reach for
a raw id in gameplay code.

### 3.2 Tilesheets — `asset/map/<scale>/*Tilesheet*.png`

Six sheets = **3 biomes × {with water, NO WATER LAYER}**, each **1024×1024 at 1x
(64×64 tiles of 16px)**:

| id | Biome | Water |
|---|---|---|
| `map_1x_tilesheet_temperate_water` | green grassland | full water |
| `map_1x_tilesheet_temperate_no_water` | green grassland | none (bring your own) |
| `map_1x_tilesheet_desert_water` | orange desert / oasis | full water |
| `map_1x_tilesheet_desert_no_water` | orange desert | none |
| `map_1x_tilesheet_snow_water` | snow / ice | full water |
| `map_1x_tilesheet_snow_no_water` | snow / ice | none |

**Key fact:** all six share **one identical tile layout**. Only the **terrain**
(top half) is recoloured per biome; the **buildings and props (bottom half) are
byte-for-byte the same** across biomes. The `NO WATER LAYER` variants simply leave
the water rows empty so you can composite your own animated water underneath.

#### Tile-role map (1x, 16px tiles, 0-indexed rows)

Which tile is grass / tree / water / house / prop — read by the **tile row** its
top sits in. These band names are the same `role` strings used in each
`asset_sliced/tiles/<sheet>/<scale>/index.json`.

| Tile rows | Role | Contents |
|---|---|---|
| 0–1 | `nature_canopy` | tree tops, bushes, rocks/boulders, a gate/door |
| 2–6 (cols 0–12) | `terrain_swatch_foliage` | solid ground-colour swatches, hedges, foliage, grass tufts |
| 2–6 (cols 13–42) | `cliff_plateau` | tan **elevated-terrain / cliff** autotile (raised ground) |
| 7–11 | `water_autotile_shallow` | shallow water / pond autotile blocks (biome-tinted) |
| 12–16 | `sand_water_autotile` | beach: sand ↔ water transition autotile (orange edge) |
| 17–26 | `path_floor_autotile` | dirt path / road + floor checker autotiles |
| 27–32 | `deep_water_autotile` | deep water (⚠ **water sheets only**; empty on `no_water`) |
| 33–40 | `buildings_block_1` | houses set 1 — cream / orange / mint / pink / brown roofs, + walls, doors, roof edges |
| 41–49 | `buildings_block_2` | houses set 2 — white / yellow / blue / red / green roofs, + parts, chimneys, stairs |
| 50–63 | `props_objects` | sacks, barrels, crates, baskets, **potions/flasks (many colours)**, X-markers, **tents/pavilions**, banners/flags, the pink **selection cursor + range arrows**, and **number glyphs 0–9** |

Notes:
- Meaningful content sits in roughly **columns 0–42**; the right side of the sheet
  is empty. The prop/UI-marker cluster is near the bottom-right of the used area.
- "Autotile" blocks are **Wang/blob sets** — a 3×3-ish arrangement of edge/corner
  tiles meant to be assembled by a Godot `TileSet` terrain, not used as single
  16px squares.
- Compose maps with `AssetRegistry.load_grid_cell(id, col, row)`, or set the whole
  sheet up as a Godot `TileSet` and paint. Never draw the full 1024² sheet as a
  background.

#### Named map tiles — the swap layer for tiles

Raw `[col, row]` pairs are unreadable (`[12, 5]` = grass? road?). So map plans and
code reference **names** instead, resolved through
[`data/maps/tile_names.json`](../data/maps/tile_names.json) — the tile equivalent
of `data/asset_shortcuts.json`.

```gdscript
var grass := AssetRegistry.load_map_tile("grass")                 # default temperate sheet
var sand  := AssetRegistry.load_map_tile("grass", "map.desert_tilesheet")  # same name, desert look
var coords := AssetRegistry.get_map_tile_coords("road_h")         # -> [18, 4]
```

In a map plan (`data/maps/*_map_plan.json`) a `tile` may be a **name or a raw
`[col,row]`** — both work (`emberhearth_map_view.gd::_as_tile_pair` resolves names,
falls back to pairs):

```jsonc
"ground_fill": { "tile": "grass" },
"decor": [ { "x": 1, "y": 1, "tile": "tree" } ]
```

Starter names (all **biome-agnostic** — the six sheets share one layout, so a name
means the same grid cell in every biome; swap `tilesheet_shortcut` to retheme):

| Name | Tile | Name | Tile |
|---|---|---|---|
| `grass` | grassy ground fill (current default) | `tree` / `tree_2` / `tree_pine` | trees |
| `grass_plain` | clean solid grass | `sapling` / `plant` | small foliage |
| `grass_tuft` | grass detail sprig | `rock` / `rock_snow` | boulders |
| `sand` | sand/dirt fill | `bed` | bed / furniture structure |
| `water` / `water_deep` | shallow / deep water | `road` = `road_v` | stone-path centre |
| `road_h` / `road_alt` | stone-path pieces | | |

**Add new names in `tile_names.json`, never a raw `[col,row]` in game code.** Find a
tile's coordinates via `asset_sliced/tiles/<sheet>/<scale>/index.json`
(`tile_col` / `tile_row`) or a labelled render of the sheet.

### 3.3 Fog of war — `asset/map/<scale>/FogOfWar.png`

- `fog_of_war` atlas, **448×80 at 1x = 28×5 tiles**. Cloudy grey autotile pieces
  for hiding unexplored map.
- Use as an **overlay layer above terrain**, driven as an 8-way autotile.
  Slice with `load_grid_cell("map.fog_of_war", col, row)`. (The clouds overlap, so
  the connected-component slicer exports it as one blob — treat it as a grid, not
  as the single cut-out.)

### 3.4 Non-assets in the map pack

`Examples/*.gif` (animated previews), `Banner.gif` (marketing),
`License and details.txt` (Franuka attribution — keep it). None go in the game.

---

## 4. UI pack — `asset/ui/` (Fantasy UI, by Franuka)

Since pack v1.3, **every UI piece is already split into its own PNG** under
`asset/ui/Individual files/<scale>/<Group>/`. These are **isolated (`is_atlas:
false`) — use directly, no cutting.** Three scales as usual.

### 4.1 UI groups

| Group (`group`) | Kind | What it is / how to use |
|---|---|---|
| Background boxes | `background_box` | Window/menu/tooltip panels (`BGbox_01A`…`08A`). Use as **NinePatchRect** so the ornate border keeps its corners. Roles: `ui.taskbar_panel`, `ui.panel_dark`. |
| Buttons | `button` | Come as **Normal / Pressed / Selected** triplets (`Button_01A_*`). TextureButton; swap states. Roles: `ui.button_normal/_pressed/_selected`. |
| Checkboxes | `checkbox` | On / Off (± Bullet) toggles for settings. |
| Cursors | `cursor` | Mouse pointers / selection markers. `Input.set_custom_mouse_cursor()`. |
| Dividers | `divider` | Horizontal separator lines between menu sections. |
| Item slots | `item_slot` | Inventory cells in 3 frame styles (`Slot_01/02/03_*`) × 11 types: Empty, Weapon, Shield, Armor, Headgear, Gloves, Footwear, Necklace, Ring, Potion, Consumable. The typed ones show a faint ghost icon; overlay the real item on top. Roles: `ui.slot_empty/_weapon/_potion`. |
| Mini icons | `mini_icon` | Small stat/resource/action icons; many have a `_Selected` variant. Role: `ui.icon_primary`. |
| Resource orbs | `resource_orb` | HP / MP / Energy gems (`Orb_HP/MP/Energy`) + frames (`Orb_Frame_*`) + decorated frames. Pair orb + frame + fill. Roles: `ui.hp_orb/_mp_orb/_energy_orb`. |
| Sliders & Bars | `slider_bar` | Track + fill + handle for volume / HP / XP bars. Nine-slice or tile the fill. |
| Spellbook & Tabs | `spellbook_tab` | Book-style menu pages + category tabs (with open/close & page-turn frames). |
| Title banners | `title_banner` | Header ribbons for screen/menu titles; put a label on top. |

### 4.2 Fonts

- **TTF (`asset/ui/Fonts/`)** — the real fonts. Load as `FontFile`:
  - `FantasyRPGtext (size 8).ttf` → body text, use at **multiples of 8px**.
  - `FantasyRPGtitle (size 11).ttf` → titles, **multiples of 11px**.
  - `FantasyRPGtitleOutline (size 13).ttf` → outlined titles, multiples of 13px.
  - Keep integer multiples or the pixels blur. Roles: `ui.font_text`, `ui.font_title`.
- **PNG label group (`Individual files/*/Fonts/`)** — pre-rendered coloured
  word/label images (`FontText_*`, `FontTitle_*` in Brown/Gold/Red/White),
  `bitmap_font` kind. Reference/decoration, not a live font.

### 4.3 Redundant combined sheets

`UI assets (Nx).png` (`spritesheet`) and `Reference sheet.png` (`reference`) pack
everything into one image. The **Individual files are easier — prefer them.** The
reference sheet is a human catalog, not a runtime asset.

---

## 5. The reference-slicing layer — `asset_sliced/`

`tools/slice_sheets.ps1` cuts the map sheets into individual pieces so you can
*see and pick* them:

```text
asset_sliced/
  units/<scale>/<Sprite>/frame_r<row>_c<col>.png   # 16 frames per sprite
                        /row<row>_strip.png          # one animation track (4 frames)
  tiles/<biome>_<water>/<scale>/<role>_<n>_c<col>_r<row>.png
                              /index.json            # every piece: role, tile pos, px box
  tiles/fog_of_war/<scale>/...
```

- **Reference / preview only.** The running game must still slice through
  `AssetRegistry` (repo rule `slice-sheets-at-registry-boundary`). Originals in
  `asset/` are never modified. `asset_sliced/` is disposable — regenerate anytime.
- Regenerate:
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1              # 1x, everything
  powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1 -Scale 3x -What tiles
  ```
- Tiles are grouped by the same `role` names as the tile-role map in §3.2, so you
  can cross-reference a cut-out back to its purpose.

---

## 6. Writing prompts for these assets

Each catalog entry has a `prompt` — an image-generation-style description, useful
for briefing an art AI, tagging, or search. They follow one shape:

```
<subject / what it is>, <pose or state>, <grid/size facts>,
pixel art, top-down fantasy RPG, warm palette, transparent background,
Franuka overworld/UI style[, Whisker Realm cat clans].
```

Examples straight from the catalog:
- Unit: *"a sworn soldier cat in a blue cloak and hat, holding a spear, idle pose,
  single character sprite sheet, 16px tiles, 4 animation frames per row, pixel art,
  … Whisker Realm cat clans."*
- Tilesheet: *"top-down tactical RPG lush green grassland tileset, seamless 16px
  terrain autotiles, cute fantasy houses with colourful roofs, small props …"*
- UI: *"fantasy RPG UI button, normal state, beveled stone/wood key, pixel art …"*

When you add new art, keep the same shape so prompts stay consistent and greppable.

---

## 7. Keeping this current

1. Add/rename/remove files under `asset/` → **regenerate the catalog**:
   `powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1`
   (this rewrites `data/asset_catalog.json` + `docs/ASSET_INDEX.generated.md`,
   including the `description` / `usage` / `prompt` / `is_atlas` fields).
2. Changed a sheet's layout or added a biome → re-run `tools/slice_sheets.ps1` and
   update the tile-role map in §3.2.
3. New gameplay role → add a line to `data/asset_shortcuts.json` (the swap layer),
   not a raw id in code.

Source-of-truth order and the pipeline rules live in
[`agents/sage/assets/rules.md`](../agents/sage/assets/rules.md) and
[`docs/ASSET_MAP.md`](ASSET_MAP.md).
