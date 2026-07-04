# Full Visual Asset Refresh Flow

> Flow for replacing the prototype's old flat visuals with the cataloged Franuka
> assets already present in this repo.
> Scope: Godot runtime, asset shortcuts, named map tiles, map plan data, UI
> presentation, and smoke/visual validation.
> Refs real code as of 2026-07-05: `AssetRegistry`, `EmberhearthMapView`,
> `Taskbar`, `Main`, `data/asset_shortcuts.json`, and
> `data/maps/tile_names.json`.

## 1. Header + Design Decisions

This refresh keeps source art immutable under `asset/`, uses `asset_sliced/` only
as an offline visual reference, and makes runtime art choices through shortcut
keys and named map tiles instead of hard-coded paths or raw sheet coordinates.

Design decisions:

- Runtime pixels come from `AssetRegistry`, never from `asset_sliced/`.
- Whole-asset role swaps live in `data/asset_shortcuts.json`.
- Tile-level scene composition lives in `data/maps/tile_names.json` plus
  `data/maps/emberhearth_map_plan.json`.
- Existing placeholder `ColorRect` surfaces are allowed only as fallback when an
  asset fails to load; the normal path must render real UI/map/unit textures.
- "Delete the old visuals" means remove old runtime usage and placeholder-first
  presentation, not delete licensed source packs under `asset/`.

Related decisions:

- `agents/sage/assets/decisions/slice-sheets-at-registry-boundary.md`
- `agents/sage/assets/decisions/shortcuts-are-the-swap-layer.md`
- `agents/sage/assets/decisions/named-map-tiles-swap-layer.md`
- `agents/sage/assets/decisions/reference-slicing-and-catalog-semantics.md`

## 2. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| Player | Sees the playable battle strip, party, enemies, commands, and rewards. | Human-facing game experience. |
| Godot `Main` scene | Builds the app shell, header, map view, feed, and taskbar. | `scripts/main/main.gd` |
| `EmberhearthMapView` | Renders tile map, unit sprites, labels, HP, and combat effects. | `scripts/maps/emberhearth_map_view.gd` |
| `Taskbar` | Renders command slots and cooldown feedback. | `scripts/ui/taskbar.gd` |
| `AssetRegistry` | Loads catalog, resolves shortcuts, slices sheets, resolves named tiles. | `scripts/autoload/asset_registry.gd` |
| Asset shortcuts | Maps gameplay/UI roles to generated catalog ids. | `data/asset_shortcuts.json` |
| Named map tiles | Maps readable tile roles to atlas `[col,row]` positions. | `data/maps/tile_names.json` |
| Map plan | Chooses biome, terrain layers, roads, water, props, and battle lane layout. | `data/maps/emberhearth_map_plan.json` |
| Unit/enemy data | Chooses role shortcuts for party and enemy visuals. | `data/units/starter_party.json`, `data/combat/enemies.json` |
| Bootstrap test | Proves the asset registry, map view, and taskbar still boot. | `tests/bootstrap_test.gd` |
| Gate scripts | Run headless smoke and capture a real screenshot. | `tools/gate_check.ps1`, `tools/capture_runtime_screenshot.ps1` |

Trust boundary:

- `asset/` is the immutable source pack; runtime code must not rewrite it.
- `data/asset_catalog.json` is generated; runtime and humans may read it but must
  not hand-edit it.
- `asset_sliced/` is reference-only; runtime code must not load it.
- Scene scripts may ask for shortcut keys and tile names, but must not invent
  `res://asset/...` paths.
- If a new role or tile is needed, data owns that indirection before code uses it.

## 3. End-to-end Overview

```text
[Developer] requests full visual refresh
   |
   v inspect -> [Sage] reads asset rules, shortcuts, tile names, catalog, runtime code
   |
[Sage] plans reuse vs build
   |-- reuse: AssetRegistry.load_texture / load_sprite_frame / load_map_tile
   |-- reuse: data/asset_shortcuts.json and data/maps/tile_names.json
   |-- build: richer role shortcuts, named props, map plan, scene styling
   |
   v edit data -> [Data] asset_shortcuts + tile_names + map_plan
   |
[Godot runtime] boot
   |-- AssetRegistry loads data/asset_catalog.json
   |-- AssetRegistry loads data/asset_shortcuts.json
   |-- AssetRegistry loads data/maps/tile_names.json
   |
   v render shell -> [Main] uses real UI textures for backdrop/feed/status where possible
   |
   v render map -> [EmberhearthMapView]
   |-- loads named terrain and props through AssetRegistry.load_map_tile(...)
   |-- loads units through AssetRegistry.load_sprite_frame(unit.idle_asset, ...)
   |-- uses UI panel textures / icons for stage, badges, HP, and effects
   |
   v render commands -> [Taskbar]
   |-- loads command textures from asset shortcuts
   |-- displays cooldown/ready state without flat placeholder-first visuals
   |
   +--(A) asset resolves -> real pixels are shown
   +--(B) asset missing -> warning + localized fallback placeholder, test reports the gap
   |
   v verify -> [tests/bootstrap_test.gd] + [tools/gate_check.ps1]
   |
[Developer] gets a prettier game with old runtime placeholders removed
```

Key: the refresh is a data-led asset swap plus runtime presentation upgrade; the
game never points at `asset_sliced/` or hard-coded source paths.

## 4. Step-by-step

### STEP 1 - Load and enforce asset knowledge

**System:** Sage + `agents/sage/assets`

APIs used:

- No runtime API.

Actions:

- Read `agents/sage/assets/rules.md`.
- Read decisions for shortcut roles, named map tiles, runtime slicing, and
  reference slicing.
- Read `docs/ASSET_GUIDE.md`, `docs/ASSET_AI_PLAYBOOK.md`, and `docs/ASSET_MAP.md`.
- Quote the rules that apply before coding.

Business rules:

- When source art lives under `asset/`, do not edit or delete it.
- When a runtime role needs art, prefer shortcut -> named tile -> catalog id ->
  query.
- When a sheet is used, crop through `AssetRegistry`.
- When a map tile is used repeatedly, name it in `data/maps/tile_names.json`.

### STEP 2 - Inspect current runtime visual surface

**System:** Godot runtime scripts and data

APIs used:

- `AssetRegistry.load_texture(asset_id_or_shortcut)`
- `AssetRegistry.load_sprite_frame(asset_id_or_shortcut, column, row)`
- `AssetRegistry.load_grid_cell(asset_id_or_shortcut, column, row)`
- `AssetRegistry.load_map_tile(tile_name, tilesheet_shortcut)`

Actions:

- Inspect `scripts/main/main.gd` for flat shell/background/feed styling.
- Inspect `scripts/maps/emberhearth_map_view.gd` for tile rendering, unit
  rendering, labels, HP, effects, and placeholder paths.
- Inspect `scripts/ui/taskbar.gd` for command slot textures and flat panel style.
- Inspect `data/units/starter_party.json` and `data/combat/enemies.json` for
  current unit role shortcuts.
- Inspect `data/maps/emberhearth_map_plan.json` for map size, biome, roads, decor.

Business rules:

- Existing `ColorRect` fallback can remain as error handling, but normal rendering
  must use real texture assets.
- Enemy distinction should use role-specific sprites before color tint.
- The map should be composed from named tiles or named objects, not mystery
  coordinates.

### STEP 3 - Pick the new visual roles

**System:** `data/asset_shortcuts.json`

APIs used:

- `AssetRegistry.resolve_id(asset_id_or_shortcut)`
- `AssetRegistry.get_entry(asset_id_or_shortcut)`

Actions:

- Keep the existing generic roles that other code already uses.
- Add/retarget role shortcuts for a richer party:
  - tank/frontline -> Vanguard
  - striker/scout -> Scout
  - mage/support -> Acolyte
  - healer/worker -> Healer
- Add/retarget role shortcuts for enemies:
  - grunt -> Beast
  - mid pressure -> BeastRider or Sapper
  - boss -> Elemental or Vanguard/Siege role
- Add UI role shortcuts for panels, title banners, dividers, orbs, slot variants,
  and command button states if the runtime needs them.

Business rules:

- If the code would otherwise use a raw generated id, add a shortcut first.
- Shortcut keys are one-level dot roles such as `unit.tank_idle`, not nested JSON.
- Shortcuts do not chain to other shortcuts.

### STEP 4 - Name the needed map tiles and props

**System:** `data/maps/tile_names.json`

APIs used:

- `AssetRegistry.get_map_tile_coords(tile_name)`
- `AssetRegistry.load_map_tile(tile_name, tilesheet_shortcut)`

Actions:

- Use `asset_sliced/tiles/*/index.json` to identify useful existing objects.
- Add names for the map details the visual refresh needs:
  - alternate grass/floor/road pieces
  - water edge/deep-water pieces
  - house/market props
  - tent/banner/marker props
  - crates, barrels, potions, or hearth-like props
- Keep the `_meta` block explaining that names are biome-agnostic.

Business rules:

- Use named tiles in the map plan.
- Raw `[col,row]` pairs stay a compatibility fallback only.
- Runtime code loads through `load_map_tile`, not through `asset_sliced`.

### STEP 5 - Replace the map plan

**System:** `data/maps/emberhearth_map_plan.json`

APIs used:

- `EmberhearthMapView._load_map_plan()`
- `EmberhearthMapView._tile_for_cell(x, y)`

Actions:

- Expand the battle strip into a richer, readable scene.
- Use a warmer or more interesting biome via `tilesheet_shortcut`.
- Add terrain variation: grass variants, road pieces, water row, props.
- Keep `map_width`, `map_height`, `tile_size`, and `display_scale` compatible
  with the layout math in `EmberhearthMapView`.
- Add readable layer names if `EmberhearthMapView` is updated to support them.

Business rules:

- Party and enemies remain visible at a glance.
- Taskbar must not cover the core action.
- The wave path must stay readable.

### STEP 6 - Upgrade `EmberhearthMapView`

**System:** `scripts/maps/emberhearth_map_view.gd`

APIs used:

- `AssetRegistry.load_map_tile(tile_name, tilesheet_shortcut)`
- `AssetRegistry.load_grid_cell(asset_id_or_shortcut, column, row)`
- `AssetRegistry.load_sprite_frame(asset_id_or_shortcut, column, row)`
- `AssetRegistry.load_texture(asset_id_or_shortcut)`

Actions:

- Replace flat panel styling with real UI panel textures where Godot controls can
  display them safely.
- Use named tile loading in the normal map path.
- Support more map-plan layers without hard-coding every prop in script.
- Increase unit visual quality with frame choice, scale, shadows, badges, HP
  bars/orbs, and clearer labels.
- Replace enemy placeholder tinting with enemy-specific shortcuts while preserving
  modulate hints for subtle faction treatment.
- Keep fallback placeholder behavior for missing assets and push warnings.

Business rules:

- Runtime sheet slicing stays in `AssetRegistry`.
- Map object choice belongs in the JSON plan.
- Scene script may contain layout logic, not asset coordinate taxonomy.

### STEP 7 - Upgrade `Main` and `Taskbar`

**System:** `scripts/main/main.gd`, `scripts/ui/taskbar.gd`

APIs used:

- `AssetRegistry.load_texture(asset_id_or_shortcut)`

Actions:

- Replace old flat backdrop/feed/taskbar surfaces with UI assets where practical.
- Give command slots distinct icons or framed textures from existing UI shortcuts.
- Preserve command ids, signals, cooldown behavior, and labels.
- Keep compact layout and avoid card nesting.

Business rules:

- Visual polish must not change gameplay semantics.
- Existing `command_pressed(id)` contract remains intact.
- Text must fit within slot cells and remain readable.

### STEP 8 - Strengthen smoke tests

**System:** `tests/bootstrap_test.gd`

APIs used:

- `AssetRegistry.has_asset`
- `AssetRegistry.load_map_tile`
- `AssetRegistry.load_sprite_frame`
- Existing scene instantiation paths.

Actions:

- Assert new shortcuts resolve.
- Assert at least one newly named tile loads through `load_map_tile`.
- Assert map view renders with unit cells and tile children after `render`.
- Assert taskbar still renders command slots.

Business rules:

- Test observable behavior through public seams.
- Do not assert private implementation details that would block harmless layout
  changes.

### STEP 9 - Run verification

**System:** PowerShell + Godot

APIs used:

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/gate_check.ps1`
- If needed, `Godot --headless --path <repo> res://tests/bootstrap_test.tscn`
- If needed, `powershell -NoProfile -ExecutionPolicy Bypass -File tools/capture_runtime_screenshot.ps1`

Actions:

- Run the real headless bootstrap test.
- Capture a real runtime screenshot.
- Inspect the screenshot for blank output, old flat-dominant presentation, and
  text overlap.
- If the gate fails, fix code or tests based on the failure, then rerun.

Business rules:

- Report actual command output, not expected success.
- A nonblank screenshot alone is not enough; the main view must show the new map,
  party, enemies, and taskbar art.

## 5. State / Data Handling

| State/Data | Location | Lifecycle |
| --- | --- | --- |
| Asset catalog | `data/asset_catalog.json` | Generated by `tools/generate_asset_catalog.ps1`; read by `AssetRegistry` at boot. |
| Asset shortcuts | `data/asset_shortcuts.json` | Hand-curated; updated when a gameplay/UI role needs a stable visual choice. |
| Named map tiles | `data/maps/tile_names.json` | Hand-curated; updated when map plans need a readable tile/object name. |
| Map plan | `data/maps/emberhearth_map_plan.json` | Hand-authored scene composition; loaded every `render`. |
| Unit visual roles | `data/units/starter_party.json`, `data/combat/enemies.json` | Loaded during `GameState` bootstrap; copied into `UnitState.idle_asset`. |
| Runtime texture cache | Godot resource/image loading | Implicit per Godot load/image APIs; no custom cache added in this flow. |
| Visual fallback state | Scene nodes | Created only when a texture fails to load; should be visible enough to diagnose. |

Client trust:

- There is no network client/server trust boundary in this flow.
- Data files are local project inputs; malformed JSON must fail soft with warnings
  or fallbacks, as current code does.

## 6. API Spec - All Systems

### 6.1 Existing - `AssetRegistry.resolve_id`

```gdscript
func resolve_id(asset_id_or_shortcut: String) -> String
```

Request:

- `asset_id_or_shortcut`: shortcut key such as `unit.tank_idle` or raw catalog id.

Response:

- The matching catalog id when the shortcut exists.
- The original string when no shortcut exists.

Guard:

- Shortcuts are one-hop only.

Side effect:

- None.

### 6.2 Existing - `AssetRegistry.load_texture`

```gdscript
func load_texture(asset_id_or_shortcut: String) -> Texture2D
```

Request:

- A shortcut or generated id for an isolated texture or image-backed resource.

Response:

- `Texture2D` when the id resolves and the image/resource loads.
- `null` with warning when missing or unreadable.

Guard:

- Runtime callers should not pass `res://asset/...` paths.

Side effect:

- Loads image/resource from disk.

### 6.3 Existing - `AssetRegistry.load_sprite_frame`

```gdscript
func load_sprite_frame(asset_id_or_shortcut: String, column: int = 0, row: int = 0) -> Texture2D
```

Request:

- A unit sprite shortcut/id plus frame column and row.

Response:

- Cropped `Texture2D`.
- `null` with warning when the id is missing, grid metadata is unusable, or the
  frame is out of range.

Guard:

- Only use for sheet assets with grid metadata.

Side effect:

- Loads/crops an image through `load_grid_cell`.

### 6.4 Existing - `AssetRegistry.load_map_tile`

```gdscript
func load_map_tile(tile_name: String, tilesheet_shortcut: String = "map.default_tilesheet") -> Texture2D
```

Request:

- `tile_name`: key from `data/maps/tile_names.json`.
- `tilesheet_shortcut`: biome tilesheet shortcut.

Response:

- Cropped `Texture2D`.
- `null` with warning when the name is unknown or the tilesheet cell fails.

Guard:

- Names are biome-agnostic because all tilesheets share a layout.

Side effect:

- Loads/crops a map tile through `load_grid_cell`.

### 6.5 Existing/Changed - `EmberhearthMapView.render`

```gdscript
func render(party: Array, enemies: Array) -> void
```

Request:

- `party`: `Array[UnitState]`
- `enemies`: `Array[UnitState]`

Response:

- No returned value.
- Scene children updated to reflect the map, units, HP, and labels.

Guard:

- Returns early if the node is not inside the scene tree.

Side effect:

- Rebuilds tile and unit layers.
- Starts unit idle tweens.

### 6.6 Existing/Changed - `Taskbar.render`

```gdscript
func render() -> void
```

Request:

- Reads `data/ui/taskbar_commands.json`.

Response:

- No returned value.
- Command slots rebuilt.

Guard:

- Returns early when `_slot_row` is missing.

Side effect:

- Recreates command button nodes and stores them in `_slots_by_id`.

## 7. Status Lifecycle

There is no new gameplay status. Existing statuses remain unchanged.

| Status | Meaning | Set by |
| --- | --- | --- |
| `GameState.run_status = "idle"` | Run is ready but not currently active. | `GameState.reset_run` |
| `GameState.run_status = "running"` | Auto-battle is active. | `GameState.start_run` |
| `GameState.run_status = "won"` | Wave 10 cleared. | `GameState.mark_wave_cleared` |
| `GameState.run_status = "wiped"` | Party defeated. | `GameState.mark_wipe` |

Transition:

- Visual refresh must not add, remove, or reinterpret these statuses.

## 8. Data Model Touchpoints

| File | Role in this flow |
| --- | --- |
| `data/asset_shortcuts.json` | Adds stable role names for richer party, enemy, map, and UI visuals. |
| `data/maps/tile_names.json` | Adds readable names for selected scene props and terrain cells. |
| `data/maps/emberhearth_map_plan.json` | Replaces sparse prototype layout with richer named-tile composition. |
| `data/units/starter_party.json` | May point starter units at richer role shortcuts. |
| `data/combat/enemies.json` | Replaces tinted player/archer placeholders with enemy-specific roles. |
| `data/ui/taskbar_commands.json` | May point commands at more specific UI shortcuts. |
| `tests/bootstrap_test.gd` | Adds smoke assertions for new visual roles and map tile names. |

No database, save schema, or persistent player state changes are part of this flow.

## 9. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Shortcut points at a missing catalog id | `AssetRegistry.load_texture/load_sprite_frame` warns and returns `null`; scene renders a local fallback placeholder; smoke test should fail if core roles are missing. |
| Named map tile is missing | `AssetRegistry.load_map_tile` warns and returns `null`; map cell falls back to placeholder or default grass; smoke test should cover key names. |
| Map plan JSON malformed | `EmberhearthMapView._load_map_plan` warns and uses `_fallback_map_plan`. |
| Map plan references a raw `[col,row]` | Supported for compatibility, but new plan should use names. |
| Sheet frame is out of range | `load_grid_cell` warns and returns `null`; unit cell fallback renders without crashing. |
| UI texture missing | Button/panel renders without texture or with fallback style; smoke test should catch core command slot issues. |
| Large map overflows stage | Layout computes `_map_pixel_size` and stage min size; verify screenshot for overlap. |
| Text label too long | Labels use `clip_text` or tighter names; verify screenshot for overlap. |
| Runtime screenshot tool cannot find Godot window | Gate reports screenshot failure; headless bootstrap result remains separate evidence. |
| `asset/` not touched | Catalog regeneration is not required; if any asset file is added/renamed/deleted, generator must run. |

## 10. Security & Concurrency

Security:

- No auth, payment, PII, secrets, or external network calls are touched.
- Licensed asset source files remain in place with license files.
- No production side effects exist in this local Godot flow.

Concurrency:

- Asset data loads once at boot through `AssetRegistry`.
- Scene `render` may be called repeatedly; it should clear/rebuild visual children
  deterministically.
- Tweens are local visual effects; they must not mutate game state.
- No parallel writes to save data or generated catalog occur in this flow.

Idempotency:

- Re-running `render` with the same `party`, `enemies`, and map plan should
  produce equivalent visual state.
- Re-running tests should not depend on a previous screenshot or save file.

## 11. Build Checklist

Data:

- [ ] Add richer unit/enemy/UI shortcuts to `data/asset_shortcuts.json`.
- [ ] Add selected prop/terrain names to `data/maps/tile_names.json`.
- [ ] Replace `data/maps/emberhearth_map_plan.json` with a richer named-tile map.
- [ ] Update unit/enemy visual roles to use the new shortcuts.
- [ ] Update taskbar command visual shortcuts if needed.

Runtime:

- [ ] Update `EmberhearthMapView` to load map names through `load_map_tile`.
- [ ] Add data-driven map layer rendering for water/props without hard-coded
      coordinates in script.
- [ ] Replace flat-first map/unit presentation with asset-backed panels,
      shadows, HP bars/orbs, and clearer labels.
- [ ] Update `Main` shell surfaces to use UI texture-backed panels where safe.
- [ ] Update `Taskbar` command slots to feel like the fantasy UI pack instead of
      generic flat buttons.

Tests:

- [ ] Add bootstrap assertions for new shortcuts.
- [ ] Add bootstrap assertions for `load_map_tile` on new tile names.
- [ ] Add bootstrap assertions that map and taskbar instantiate/render with
      expected child counts.
- [ ] Run `tools/gate_check.ps1`.
- [ ] Inspect `godot_runtime_screenshot.png`.

Docs/knowledge:

- [ ] Update any touched human docs through `/sage-docs`.
- [ ] Capture a reusable decision only if this flow creates a new pattern beyond
      existing asset rules.

## 12. Verify The Flow - Should It Really Be This Way?

Skeptical review:

- The request says assets were isolated and documented; repo rules say
  `asset_sliced/` is reference-only. Therefore runtime must not load those
  isolated preview files directly. This flow follows the rule by using them only
  to select tile names/coordinates.
- The user says "delete all old ones"; deleting source packs would violate
  `asset/rules.md` and break catalog/license expectations. This flow interprets
  deletion as removing old runtime usage and placeholders.
- `AssetRegistry` already exposes the required seam. Adding crop math to
  `EmberhearthMapView` would violate `slice-sheets-at-registry-boundary`; this
  flow avoids that.
- `data/maps/tile_names.json` already exists; extending it is simpler and more
  consistent than adding a second map-object registry.
- UI individual files are isolated ready-to-use assets, so shell/taskbar polish
  should load them directly through shortcuts.
- A full Godot `TileMapLayer` would be a better long-term engine-native map, but
  the current prototype uses `GridContainer` and has tests around it. This flow
  keeps the implementation scoped to the existing renderer.

Open Questions:

1. Resolved for this run: use the existing Franuka packs and current generated
   catalog, not new AI-generated art.
2. Resolved for this run: keep source assets under `asset/`; do not delete packs,
   licenses, or generated catalog inputs.
3. Resolved for this run: use `asset_sliced/` only for choosing names/coords, not
   as runtime file paths.
4. Non-blocking: exact art direction can be refined after screenshot review.
