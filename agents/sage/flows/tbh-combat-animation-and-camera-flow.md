# TBH Combat Animation And Camera Flow

> Flow for tightening the battle strip into a Task Bar Hero-like side-on stage:
> idle/walk frame animation, melee units walking into range before the hit
> effect, flush background blocks, and a lower side camera. Refs real code as of
> 2026-07-05: `EmberhearthMapView`, `UnitState`, `BattleEngine`,
> `AssetRegistry`, starter/enemy data, and bootstrap gate.

## 1. Header + Design Decisions

The combat simulation already emits `damage_dealt(source_id, target_id, amount)`
and `Main` already routes that event to `EmberhearthMapView.play_attack()` and
`play_hit()`. This change should therefore be a presenter-only upgrade. The
view decides which animation to show and where to move a visible cell; combat
timing, HP mutation, target selection, wave progression, and rewards stay owned
by `BattleEngine` and `GameState`.

Design decisions:

- `UnitState` carries both `idle_asset` and `move_asset` so data can choose
  matching sprite sheets for each unit role.
- `EmberhearthMapView` loads animation rows through
  `AssetRegistry.load_sprite_frames(...)`; it never crops sheets itself.
- Idle and walk animation use the same `TextureRect` node by swapping textures
  over time in `_process`.
- Melee approach moves the unit cell on the presenter layer, not gameplay
  coordinates.
- Melee approach plays before the local spark effect, then returns the unit to
  its lane slot.
- Non-melee roles keep a short ranged pulse so healers/support do not all walk
  into the enemy pack.
- Tile grid separation is set to zero so background blocks touch each other.
- The camera is represented by stage composition: lower lane, side-facing sprite
  rows, compact unit cells, and a horizontal battle strip.
- External TBH screenshots are category/layout references only; no art, exact UI
  composition, or proprietary layout is copied.

Related decisions:

- `agents/sage/assets/decisions/slice-sheets-at-registry-boundary.md`
- `agents/sage/godot-runtime/decisions/presenter-owned-game-feel-effects.md`
- `agents/sage/flows/taskbar-battle-strip-layout-flow.md`
- `agents/sage/flows/full-visual-asset-refresh-flow.md`

## 2. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| Player | Watches a compact auto-battle strip and reads hit feedback. | Human-facing experience. |
| `Main` | Routes battle signals to the map view. | Screen composition and event wiring. |
| `BattleEngine` | Chooses attackers/targets and mutates HP through `UnitState`. | Combat simulation source of truth. |
| `GameState` | Owns party, wave, enemies, HP, rewards, and run status. | Gameplay state. |
| `UnitState` | Carries unit identity, stats, current HP, and visual role ids. | Runtime unit data. |
| `EmberhearthMapView` | Renders map, units, animation frames, approach tweens, and effects. | Presentation. |
| `AssetRegistry` | Resolves shortcuts and returns cropped sprite/map textures. | Asset boundary. |
| Starter/enemy JSON | Selects idle/move role shortcuts for visible units. | Data configuration. |
| `tests/bootstrap_test.gd` | Proves registry, unit data, map view, and effect APIs boot. | Regression gate. |

### Trust Boundary

- `BattleEngine` and `GameState` are trusted for combat outcomes.
- `EmberhearthMapView` may read unit roles and ids to choose a visual animation.
- `EmberhearthMapView` must not change HP, wave status, currency, cooldowns, or
  combat target selection.
- `AssetRegistry` owns sheet slicing and shortcut resolution.
- Data files may choose shortcut keys; scene code must not use source asset
  filesystem paths.
- Animation timing is visual only. If a new damage-timing contract is needed
  later, it must be explicit in `BattleEngine`/`Main`; this flow does not add it.

## 3. End-to-end Overview

```text
[GameState] loads party/enemies
   |-- UnitState.from_starter(row, clan)
   |      idle_asset <- row.idle_asset
   |      move_asset <- row.move_asset
   |-- UnitState.from_enemy(row)
          idle_asset <- row.idle_asset
          move_asset <- row.move_asset or derived fallback
   |
   v
[Main] MapView.render(party, enemies)
   |
   v
[EmberhearthMapView]
   |-- read data/maps/emberhearth_map_plan.json
   |-- render TileGrid with h/v separation 0
   |-- build one side-strip unit cell per UnitState
   |-- load idle frames through AssetRegistry.load_sprite_frames(idle_asset, row)
   |-- load walk frames through AssetRegistry.load_sprite_frames(move_asset, row)
   |-- set sprite metadata: animation_state, frame_index, frame_accum, frames
   |-- layout party/enemies on one lower horizontal lane
   |
   v every frame
[EmberhearthMapView._process(delta)]
   |-- find each visible sprite
   |-- advance current state's frame clock
   |-- swap TextureRect.texture to the next idle/walk frame
   |
   v combat event
[BattleEngine] damage_dealt(source_id, target_id, amount)
   |
   v
[Main] _on_damage_dealt(...)
   |-- MapView.play_attack(source_id, target_id)
   |-- MapView.play_hit(target_id, amount)
   |
   v
[EmberhearthMapView.play_attack]
   |-- if melee: set source animation=walk, tween cell toward target, spark,
                 tween back, set animation=idle
   |-- if ranged/support: pulse sprite and spark without lane crossing
```

Key: `damage_dealt` remains the gameplay event. The walk-in is a local rendering
interpretation of that event.

## 4. Step-by-step

### STEP 1 - Extend unit visual data

**System:** `UnitState`, starter/enemy JSON.

- Add `move_asset: String` to `UnitState`.
- In `from_starter`, copy `row.move_asset`.
- In `from_enemy`, copy `row.move_asset`.
- When enemy data lacks `move_asset`, derive a safe fallback by replacing
  `_idle` with `_move` only when the idle shortcut follows that naming pattern.
- If no move sheet is available, fall back to idle frames so rendering never
  crashes.
- Add `move_asset` to enemy JSON for the current enemy roles.

Outcome:

- Party and enemies expose matching idle/move shortcuts to the presenter.
- Existing save snapshots do not change because `UnitState` is runtime state in
  this flow.

### STEP 2 - Build frame metadata in unit cells

**System:** `EmberhearthMapView`.

- Replace the previous bob-only idle feel with real frame cycling.
- Load side-facing rows from idle and move sheets using
  `AssetRegistry.load_sprite_frames(shortcut, UNIT_ANIMATION_ROW)`.
- Store frames on the sprite node metadata:
  - `idle_frames: Array`
  - `move_frames: Array`
  - `animation_state: String`
  - `frame_index: int`
  - `frame_accum: float`
- Use the first idle frame as the initial texture.
- Keep `base_modulate` metadata so damage/heal/boss effects can restore colors.
- Keep placeholder fallback when a texture cannot load.

Outcome:

- Visible units animate while standing still.
- The same sprite node can switch to walk frames during approach.

### STEP 3 - Advance frames every process tick

**System:** `EmberhearthMapView`.

- Enable processing for the view after `_build`.
- In `_process(delta)`, iterate visible unit ids from `_cells_by_unit_id`.
- Resolve each sprite through `_sprite_for_unit`.
- Read its current state and matching frame array.
- When `frame_accum >= frame_duration`, advance `frame_index` modulo frame
  count and assign `sprite.texture`.
- Use a short duration for walk frames and a slightly slower duration for idle.
- If the frame list has zero or one texture, leave it unchanged.

Outcome:

- Animation is deterministic, lightweight, and isolated to the view.
- Missing frames degrade to a still sprite.

### STEP 4 - Make melee attacks walk into range

**System:** `EmberhearthMapView`.

- Keep `play_attack(source_id, target_id)` public signature unchanged.
- Decide visual melee from role:
  - `tank`, `dps`, and `enemy` are melee for this prototype.
  - `support` and `healer` stay ranged/support visuals.
- For melee:
  - find source and target cells,
  - compute direction from source center to target center,
  - approach to a point just outside the target cell,
  - switch source to `move`,
  - tween the source cell to the approach point,
  - switch to `idle` briefly at contact,
  - spawn the spark on the target,
  - switch back to `move`,
  - tween source cell back to its lane slot,
  - switch back to `idle`.
- For ranged/support:
  - keep source in place,
  - pulse scale/position briefly,
  - spawn the spark on the target.

Outcome:

- Close attackers visibly close distance before the hit effect.
- Ranged/support roles do not crowd the lane.
- Gameplay state remains unchanged.

### STEP 5 - Tighten background blocks

**System:** `EmberhearthMapView`.

- Set `GridContainer` `h_separation` and `v_separation` to `0`.
- Keep each map cell's `custom_minimum_size`, `size`, and child `TextureRect`
  exactly equal to the computed display size.
- Keep tile `TextureRect.position = Vector2.ZERO`.
- Do not use margins between map cells.

Outcome:

- Background blocks touch edge-to-edge.
- Existing map plan remains compatible.

### STEP 6 - Shift composition toward TBH side camera

**System:** `EmberhearthMapView`, map plan.

- Stage units lower on the tile map, closer to a side-view floor.
- Reduce unit cell/card footprint and make the sprite the dominant element.
- Keep labels and HP bars compact so they do not occlude the main action.
- Use side-facing sprite rows rather than top-down front-facing rows.
- Keep the map as one horizontal strip with party left and enemies right.
- Update the map plan visual goal labels to describe a side-strip battle floor.

Outcome:

- The first read is a horizontal taskbar battle scene rather than a top-down map
  panel with portraits.

### STEP 7 - Verify through the existing gate

**System:** tests and tools.

- Add bootstrap assertions for move shortcuts and `UnitState.move_asset`.
- Keep map tile count assertion in sync with the map plan.
- Instantiate `EmberhearthMapView` and call `play_attack`, `play_hit`,
  `play_heal`, `play_skill_pulse`, `play_boss_warning`, and
  `play_reward_burst`.
- Run `tools/gate_check.ps1` with the local Godot binary.
- Inspect `godot_runtime_screenshot.png` for:
  - nonblank stage,
  - taskbar visible,
  - tile cells flush,
  - units on a lower side lane,
  - no unreadable overlap in labels/HP.

Outcome:

- The behavior is validated by the same headless and screenshot gate used by
  prior visual work.

## 5. State / Data Handling

| State/Data | Location | Lifecycle |
| --- | --- | --- |
| `idle_asset` | `UnitState` from starter/enemy JSON | Loaded at run/wave creation; read by MapView. |
| `move_asset` | `UnitState` from starter/enemy JSON | Loaded at run/wave creation; read by MapView. |
| Animation frames | Sprite node metadata | Built when cell is created; freed with the cell. |
| Animation state | Sprite node metadata | Set to `idle` by default; temporarily changed by `play_attack`. |
| Frame clock/index | Sprite node metadata | Advanced in `_process`; reset when state changes. |
| Lane slot position | Cell `position` in `UnitLayer` | Recomputed by `_layout_stage`; used as return point. |
| Approach tween | Godot tween on source cell | Created per attack effect; does not persist. |
| Tile separation | `GridContainer` theme constants | Set during `_build`; stable for all renders. |

Not trusted client-side:

- HP and alive/dead state are not inferred from animation.
- A walk tween finishing does not decide whether damage happened.
- Dead units may still have a sprite node briefly during transition; HP/alive
  comes from `UnitState`.

## 6. API Spec - All Systems

### 6.1 Existing - `AssetRegistry.load_sprite_frames`

```gdscript
func load_sprite_frames(asset_id_or_shortcut: String, row: int = 0) -> Array[Texture2D]
```

Use:

- Called with `idle_asset` and `move_asset`.
- Row is the side-facing animation row selected by `EmberhearthMapView`.

Response:

- Returns an array of cropped textures.
- Returns an empty array on missing/bad asset.

Side effects:

- Loads and crops textures through the registry boundary.

### 6.2 Changed - `UnitState.from_starter`

```gdscript
static func from_starter(row: Dictionary, clan: Dictionary)
```

New handling:

- Reads `move_asset` from starter JSON.
- Leaves it empty when data does not provide it.

Side effects:

- None beyond constructing the runtime unit object.

### 6.3 Changed - `UnitState.from_enemy`

```gdscript
static func from_enemy(row: Dictionary)
```

New handling:

- Reads `move_asset` from enemy JSON.
- Derives `_move` fallback from `_idle` naming when data is missing.

Side effects:

- None beyond constructing the runtime unit object.

### 6.4 Existing/Changed - `EmberhearthMapView.play_attack`

```gdscript
func play_attack(source_id: String, target_id: String) -> void
```

Behavior:

- Missing source or target cell: no-op or local pulse only.
- Melee source: walks in, sparks target, walks back.
- Ranged/support source: pulses in place and sparks target.

Side effects:

- Visual tweens and frame-state metadata only.

## 7. Status Lifecycle

No gameplay status changes are added.

| Status | Meaning | Set by |
| --- | --- | --- |
| `idle` animation | Unit is standing on its lane slot. | `EmberhearthMapView` on cell creation or effect end. |
| `move` animation | Unit is visually walking during approach/return. | `EmberhearthMapView.play_attack`. |
| `running` run status | Auto-battle is active. | `GameState`. |
| `won`/`wiped` run status | Run is resolved. | `GameState`. |

Legal animation transitions:

```text
idle -> move -> idle -> move -> idle
idle -> idle   (ranged/support pulse)
any  -> idle   (missing frames, missing cell, or effect cleanup)
```

Animation status must never be used to infer gameplay status.

## 8. Data Model Touchpoints

| File | Role in this flow |
| --- | --- |
| `scripts/runtime/unit_state.gd` | Adds runtime `move_asset` field and data loading. |
| `data/combat/enemies.json` | Adds enemy move shortcuts. |
| `data/units/starter_party.json` | Reuses existing move shortcuts. |
| `scripts/maps/emberhearth_map_view.gd` | Implements frame cycling, melee approach, tighter grid, side composition. |
| `data/maps/emberhearth_map_plan.json` | Updates visual goals for the side battle strip if needed. |
| `tests/bootstrap_test.gd` | Adds move asset and smoke coverage. |
| `docs/systems/MAP_AND_TASKBAR.md` | Human docs if the documented flow changed. |

No database, network schema, or save-file migration is part of this flow.

## 9. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Unit has no `move_asset` | Use idle frames for walk state. |
| `move_asset` shortcut is missing | Registry returns empty/null; use idle frames or still texture. |
| Sprite is missing during effect | Effect no-ops; combat state is already resolved elsewhere. |
| Target cell missing | Source gets a local pulse/lunge, no crash. |
| Source and target overlap | Direction falls back to `1.0`. |
| Attack tween overlaps with another attack | New tween uses the current cell position and returns to the current lane slot. |
| Unit dies during approach | `refresh_hp()` greys sprite; visual tween may finish without changing state. |
| Map plan width changes | Tile count assertion updates; `_layout_stage` uses computed `_map_pixel_size`. |
| Text labels collide at small viewports | Keep compact labels; verify screenshot before closing. |
| `AssetRegistry` not loaded yet | Existing `Main` readiness gate remains responsible before render. |

## 10. Security & Concurrency

Security:

- No auth, payment, PII, secrets, or network calls are touched.
- No source assets under `asset/` are edited or deleted.
- External reference screenshots are not copied.

Concurrency:

- Godot tweens and `_process` run on the main thread.
- Multiple attacks may queue visual tweens; each one must be best-effort and
  presenter-only.
- Rendering a new wave clears old cells; missing old cells must no-op.

Idempotency:

- Re-running `render()` should create equivalent cells and animation metadata.
- Re-running the gate should not depend on previous screenshots or saves.

## 11. Build Checklist

Runtime data:

- [ ] Add `move_asset` to `UnitState`.
- [ ] Load `move_asset` in starter and enemy constructors.
- [ ] Add enemy move shortcuts to `data/combat/enemies.json`.

Map view:

- [ ] Set tile grid `h_separation` and `v_separation` to `0`.
- [ ] Load idle/walk frame arrays through `AssetRegistry`.
- [ ] Add frame advancement in `_process`.
- [ ] Add `_set_unit_animation` and helpers for frame state.
- [ ] Replace bob-only idle with real idle frame cycling.
- [ ] Add melee-role detection.
- [ ] Change melee `play_attack` to approach, strike, and return.
- [ ] Keep ranged/support pulse in place.
- [ ] Move the unit lane lower and reduce portrait/card dominance.

Verification:

- [ ] Add bootstrap coverage for move shortcuts and unit move data.
- [ ] Run the Godot gate.
- [ ] Inspect screenshot for nonblank, flush background, side lane, and taskbar.
- [ ] Update docs if the documented battle strip behavior changed.
- [ ] Capture one reusable knowledge decision only if no existing rule covers it.

## 12. Verify The Flow - Should It Really Be This Way?

Skeptical review:

- The user asked for animation and melee movement, not changed combat balance.
  Presenter-only animation is therefore the safer boundary.
- The existing signal timing emits damage before the visual attack starts. This
  flow keeps that contract instead of delaying HP mutation, because delaying
  damage would require a combat/event contract change and more tests.
- `AssetRegistry.load_sprite_frames` already exists. Re-adding crop math in
  `EmberhearthMapView` would violate the asset boundary rule.
- The current `UnitState` lacks `move_asset`; putting it in runtime data is
  better than guessing visual pairs inside the map view.
- The current tile grid uses `GridContainer`; setting theme separation to zero is
  the direct fix for visible gaps without replacing the renderer.
- A full pathfinding or navigation layer would be overbuilt because melee walk
  here is a fixed visual approach in a one-lane battle strip.
- A perfect TBH clone would be inappropriate and unnecessary. The repo should
  keep its own asset pack and identity while using the side-on taskbar battle
  readability pattern.

Open Questions:

1. Resolved for this run: use existing Franuka/unit shortcut assets, not new
   generated art.
2. Resolved for this run: make melee walk visual-only; do not change damage
   timing or HP math.
3. Resolved for this run: use role-based melee detection for the prototype:
   `tank`, `dps`, and `enemy` walk in; `support` and `healer` stay ranged.
4. Non-blocking: exact side-facing row may be refined after screenshot review if
   the pack orientation reads better on a different row.
