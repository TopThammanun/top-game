# Asset Sheet Slicing — Sprite Frames + Tile Map Composition (Godot runtime)

> This flow fixes the current asset-rendering problem: source files under
> `asset/map` are atlases, not display-ready single images. Character PNGs are
> 4x4 sprite sheets on the pack grid, and map PNGs are 1024x1024 tile sheets on
> the same grid. Refs real code as of 2026-07-04. Doc type: `architecture` +
> `frontend`.

---

## Header + Design Decisions

The runtime keeps original assets untouched and adds a reusable slicing boundary
inside `AssetRegistry`. Scene code still asks for shortcut ids such as
`unit.player_idle` and `map.default_tilesheet`, but when it needs a character
pose or a map tile it requests a grid cell or frame region instead of drawing the
whole texture. The first static unit pose uses column `0`, row `0` from the
4x4 sheet until a later animation system chooses frames over time.

Related decisions:

- `agents/sage/assets/decisions/id-naming-scheme.md`
- `agents/sage/assets/decisions/shortcuts-are-the-swap-layer.md`
- `agents/sage/godot-runtime/decisions/asset-registry-is-only-runtime-lookup.md`
- `agents/sage/godot-runtime/decisions/wait-for-catalog-ready.md`

## 1. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| `asset/map/License and details.txt` | Declares the map pack grid: `1x = 16x16`, `2x = 32x32`, `3x = 48x48`. | Source asset facts. |
| `tools/generate_asset_catalog.ps1` | Reads source image width/height and emits generated metadata. | Catalog generation. |
| `data/asset_catalog.json` | Generated catalog rows with ids, dimensions, and sheet facts. | Machine-readable asset index. |
| `data/asset_shortcuts.json` | Maps gameplay roles to catalog ids. | Art swap layer. |
| `AssetRegistry` | Loads source textures and crops regions/cells/frames by asset id or shortcut. | Runtime asset boundary. |
| `data/maps/emberhearth_map_plan.json` | Owns the MVP map layout as tile coordinates into the default tilesheet. | Map composition data. |
| `EmberhearthMapView` | Draws a composed tile grid and cropped unit frames. | Presentation only. |
| `tests/bootstrap_test.gd` | Proves the registry can crop a unit frame and map tile at the declared size. | Regression gate. |

### Trust Boundary

- Source image files are trusted for pixels and dimensions only; game code does
  not rewrite or split them on disk.
- `AssetRegistry` is the only runtime code allowed to open `asset/` paths.
- `MapView` can choose tile coordinates for presentation, but it must not know
  source file paths or implement image-cropping logic.
- `data/asset_catalog.json` is generated. Hand edits are not a valid fix.

## 2. End-to-end Overview

```text
[Developer] keeps original source assets under asset/
   |
   v run generator when generator/source asset metadata changes
[tools/generate_asset_catalog.ps1]
   |-- reads image width/height
   |-- detects scale from folder/name
   |-- for map spritesheets: records grid_cell_width/grid_cell_height + grid_columns/grid_rows
   |-- for map tilesheets: records tile_width/tile_height + tile_columns/tile_rows
   |
   v writes generated outputs
[data/asset_catalog.json] + [docs/ASSET_INDEX.generated.md]
   |
   v Godot boot
[AssetRegistry.load_catalog()]
   |-- loads catalog rows
   |-- loads shortcuts
   |-- emits catalog_ready
   |
   v MapView.render()
[EmberhearthMapView]
   |-- AssetRegistry.load_grid_cell("map.default_tilesheet", tile_x, tile_y)
   |     -> draws each map tile into a grid
   |-- AssetRegistry.load_sprite_frame(unit.idle_asset, 0, 0)
   |     -> draws one cropped 16x16 pose per unit
   |
   v User sees composed map + individual unit frames, not full atlases
```

**Key:** the sheet stays whole on disk; the runtime slices regions in memory at
the `AssetRegistry` boundary.

## 3. Step-by-step

### STEP 1 — Generator records sheet facts

**System:** `tools/generate_asset_catalog.ps1`.

- When a map asset has scale `1x`, set the base cell to `16x16`.
- When scale is `2x`, set the base cell to `32x32`.
- When scale is `3x`, set the base cell to `48x48`.
- When `kind == "unit_sprite"`:
  - add `grid_cell_width`, `grid_cell_height`
  - add `grid_columns = width / grid_cell_width`
  - add `grid_rows = height / grid_cell_height`
  - add `frame_count = grid_columns * grid_rows`
- When `kind == "tilesheet"` or `kind == "fog_of_war"`:
  - add `tile_width`, `tile_height`
  - add `tile_columns = width / tile_width`
  - add `tile_rows = height / tile_height`
- When dimensions are missing or not divisible by the scale grid, omit derived
  counts and let runtime fallback checks warn on use.

### STEP 2 — Registry loads full textures once per request and crops regions

**System:** `scripts/autoload/asset_registry.gd`.

- Reuse `get_entry()` and `get_asset_path()`; no caller reads catalog JSON.
- Add `get_sheet_grid(asset_id_or_shortcut) -> Dictionary`.
- Add `load_texture_region(asset_id_or_shortcut, region: Rect2i) -> Texture2D`.
- Add `load_grid_cell(asset_id_or_shortcut, column: int, row: int) -> Texture2D`.
- Add `load_sprite_frame(asset_id_or_shortcut, column: int = 0, row: int = 0) -> Texture2D`.
- Add `load_sprite_frames(asset_id_or_shortcut, row: int = 0) -> Array`.
- Guard invalid region requests:
  - when width/height are missing -> `push_warning`, return `null`
  - when region falls outside the image -> `push_warning`, return `null`
  - when the source image cannot load -> existing image warning path, return `null`

### STEP 3 — Map plan owns tile coordinates

**System:** `data/maps/emberhearth_map_plan.json`.

- Add `tile_scale = "1x"` and `tile_size = 16`.
- Add `tile_layers` as data, not code constants:
  - `ground` is a rectangular grid of tile coordinates into `map.default_tilesheet`.
  - `decor` is a sparse array of placed tiles with `x`, `y`, `tile_x`, `tile_y`.
- Keep the map small enough for the current UI: 24 columns by 8 rows at 2x or 3x
  visual scale.
- If a tile coordinate is wrong, the map looks wrong but no runtime code changes
  are needed; edit JSON.

### STEP 4 — MapView draws tiles from cropped regions

**System:** `scripts/maps/emberhearth_map_view.gd`.

- Replace the old `_tilesheet_bg: TextureRect` full-atlas display with a tile
  viewport container.
- Load `data/maps/emberhearth_map_plan.json`.
- For every map cell:
  - call `AssetRegistry.load_grid_cell(plan.tilesheet_shortcut, tile_x, tile_y)`
  - create a `TextureRect` with fixed `tile_size * display_scale`
  - assign the cropped texture, nearest filter remains project default
- Draw sparse decor after ground so decor appears above base tiles.
- On missing/invalid tile, draw a placeholder color rect and push a warning with
  the failing tile coordinate.

### STEP 5 — Unit cells draw one sprite frame

**System:** `scripts/maps/emberhearth_map_view.gd`.

- Replace `AssetRegistry.load_texture(u.idle_asset)` in `_build_unit_cell`.
- Call `AssetRegistry.load_sprite_frame(u.idle_asset, 0, 0)`.
- Use fixed display dimensions so a 16x16 source frame scales to a readable
  64x64 or 48x48 slot without showing neighboring frames.
- Preserve existing modulate behavior for enemies and defeated units.

### STEP 6 — Tests prove cropped dimensions

**System:** `tests/bootstrap_test.gd` + `tools/gate_check.ps1`.

- Assert `AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)` returns a
  texture whose size is `16x16`.
- Assert `AssetRegistry.load_grid_cell("map.default_tilesheet", x, y)` returns a
  texture whose size is `16x16`.
- Assert invalid out-of-range grid cells return `null`.
- Continue running the screenshot smoke; it proves the app still renders.

## 4. State / Data Handling

| State | Where it lives | Lifecycle |
| --- | --- | --- |
| Sheet metadata | `data/asset_catalog.json` | Generated from source image dimensions. Recreated by the generator. |
| Shortcut role mapping | `data/asset_shortcuts.json` | Hand-curated. No change needed for slicing. |
| Tile map layout | `data/maps/emberhearth_map_plan.json` | Hand-authored MVP map composition. Read on `MapView.render()`. |
| Cropped textures | In-memory `ImageTexture` objects returned by `AssetRegistry` | Created on demand; no disk output. |
| Unit animation frame choice | `MapView` static call `load_sprite_frame(..., 0, 0)` | Temporary static pose until animation state exists. |

## 5. API Spec — Internal GDScript Contracts

### 5.1 Existing — `AssetRegistry.load_texture`

```gdscript
func load_texture(asset_id_or_shortcut: String) -> Texture2D
```

Guard:

- when id/shortcut is missing -> warn and return `null`
- when path cannot load as image/texture -> warn and return `null`

Side effect:

- loads the whole source texture

### 5.2 New — `AssetRegistry.get_sheet_grid`

```gdscript
func get_sheet_grid(asset_id_or_shortcut: String) -> Dictionary
```

Response:

```jsonc
// unit sprite
{
  "cell_width": 16,
  "cell_height": 16,
  "columns": 4,
  "rows": 4
}

// map tilesheet
{
  "cell_width": 16,
  "cell_height": 16,
  "columns": 64,
  "rows": 64
}
```

Guard:

- when metadata is absent -> infer from `scale` for map assets and image size
- when the asset is not a grid sheet -> return `{}`

### 5.3 New — `AssetRegistry.load_texture_region`

```gdscript
func load_texture_region(asset_id_or_shortcut: String, region: Rect2i) -> Texture2D
```

Response:

```jsonc
// success
Texture2D // size == region.size

// failure
null
```

Guard:

- `region.size.x > 0`
- `region.size.y > 0`
- `region.position.x >= 0`
- `region.position.y >= 0`
- `region.end.x <= image.width`
- `region.end.y <= image.height`

Side effect:

- creates an `ImageTexture` from `Image.get_region(region)`

### 5.4 New — `AssetRegistry.load_grid_cell`

```gdscript
func load_grid_cell(asset_id_or_shortcut: String, column: int, row: int) -> Texture2D
```

Behavior:

- reads `get_sheet_grid()`
- computes `Rect2i(column * cell_width, row * cell_height, cell_width, cell_height)`
- delegates to `load_texture_region()`

### 5.5 New — `AssetRegistry.load_sprite_frame`

```gdscript
func load_sprite_frame(asset_id_or_shortcut: String, column: int = 0, row: int = 0) -> Texture2D
```

Behavior:

- delegates to `load_grid_cell()`
- semantic wrapper so future animation code can target sprite sheets without
  knowing the grid details

### 5.6 New — `AssetRegistry.load_sprite_frames`

```gdscript
func load_sprite_frames(asset_id_or_shortcut: String, row: int = 0) -> Array
```

Behavior:

- reads `get_sheet_grid()`
- crops every column in the requested row into a separate `Texture2D`
- returns an empty array and warns when the row is out of range

## 6. Status Lifecycle

No gameplay status values change in this flow.

## 7. Data Model Touchpoints

| File | Role in this flow | Change |
| --- | --- | --- |
| `tools/generate_asset_catalog.ps1` | Adds derived sheet/tile metadata. | Edit. |
| `data/asset_catalog.json` | Receives generated metadata. | Regenerate. |
| `docs/ASSET_INDEX.generated.md` | Human generated summary. | Regenerate. |
| `scripts/autoload/asset_registry.gd` | Adds region/cell/frame loading APIs. | Edit. |
| `data/maps/emberhearth_map_plan.json` | Adds tile layout data. | Edit. |
| `scripts/maps/emberhearth_map_view.gd` | Uses cropped map tiles and sprite frames. | Edit. |
| `tests/bootstrap_test.gd` | Adds crop regression assertions. | Edit. |
| `docs/ASSET_MAP.md` | Documents the slicing contract. | Update via `/sage-docs`/docs refresh. |

## 8. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Unit sheet is missing metadata | `get_sheet_grid()` infers from `scale` + `width`/`height`; if it cannot, warn and return `{}`. |
| Unit frame column/row out of range | `load_grid_cell()` warns and returns `null`; `MapView` draws the existing placeholder. |
| Map tile coordinate out of range | Same: warning plus placeholder tile. |
| `data/maps/emberhearth_map_plan.json` missing | `MapView` falls back to a small built-in coordinate grid and warns. |
| Catalog not loaded yet | Existing `catalog_ready` gate remains; `MapView.render()` is called only after game state/registry readiness. |
| Generator changes catalog format | `tests/bootstrap_test.gd` catches missing crop behavior by asserting returned texture sizes. |
| Source asset dimensions are not divisible by grid size | Generator omits derived counts or records truncated counts; runtime out-of-range guard prevents crashes. |

## 9. Security & Concurrency

- No network, credentials, PII, or payments.
- Cropping runs synchronously on the Godot main thread for small 16px regions.
- No persistent output is created from cropped textures, so no redistributable
  derived asset files are introduced.
- Source assets remain under their license path.

## 10. Build Checklist

### Asset Catalog

- [ ] Add grid metadata helpers to `tools/generate_asset_catalog.ps1`.
- [ ] Regenerate `data/asset_catalog.json` and `docs/ASSET_INDEX.generated.md`.

### Runtime

- [ ] Add `get_sheet_grid`, `load_texture_region`, `load_grid_cell`, and `load_sprite_frame` to `AssetRegistry`.
- [ ] Update `EmberhearthMapView` to draw map tiles from `data/maps/emberhearth_map_plan.json`.
- [ ] Update unit sprite rendering to use `load_sprite_frame(..., 0, 0)`.

### Tests + Docs

- [ ] Extend `tests/bootstrap_test.gd` with cropped texture assertions.
- [ ] Run `tools/gate_check.ps1`.
- [ ] Update asset docs to explain grid slicing.
- [ ] Capture the reusable sheet-slicing rule in Sage knowledge.

## 11. Open Questions

None block coding.

- Future animation still needs a direction/animation state model. This flow only
  fixes static display by cropping a single frame from the existing sheets.
- The exact production map art direction is still design work. This flow creates
  a data-driven MVP tile composition so the atlas is no longer shown raw.

---

## Verify Pass — "Should it really be this way?"

- Every overview hop maps to a step: generator metadata, registry load, map
  composition, unit frame crop, test gate.
- The design follows the block rule that runtime code routes all `asset/` access
  through `AssetRegistry`.
- The design avoids editing source assets and avoids generating cropped image
  files that could drift from the source pack.
- The risky choice is the static frame coordinate `(0, 0)`. It is acceptable for
  this fix because the game currently displays static units; animation state can
  later choose columns/rows through the same API.
- The map plan is data-driven rather than hard-coded in `MapView`, so wrong tile
  choices can be corrected without changing runtime code.
