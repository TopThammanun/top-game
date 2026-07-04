# Taskbar Battle Strip Layout - Map And Character Structure

> This flow reshapes the playable TBH prototype from a dashboard-like map plus
> separate combat rows into a compact taskbar companion battle strip. It uses
> public Steam positioning language for TBH only as product-category context:
> tiny idle RPG, desktop companion, pixel heroes, party-based auto battler.
> Refs real code as of 2026-07-04.

## Header + Design Decisions

The current prototype already has the correct systems: `Main` composes the
screen, `EmberhearthMapView` renders map/units/effects, `Taskbar` renders
commands, `BattleEngine` emits combat events, and `GameState` owns session
numbers. The change should therefore be layout-only: the map view becomes a
single horizontal battle stage with the tile map as background and party/enemies
anchored on top of it. No combat math, save state, asset id, or wave data moves.

Design decisions:

- Keep `GameState` as the single owner of wave, HP, currency, rewards, and run
  status.
- Keep `BattleEngine` as the source of combat events; it still knows nothing
  about screen positions.
- Keep all asset loads behind `AssetRegistry`.
- Keep effects presenter-owned and best-effort.
- Replace the separate party/enemy dashboard row with unit cells positioned on
  the map lane.
- Keep labels short and attached to units so the player can scan a tiny window.
- Give repeated enemy spawns unique runtime instance ids so layout/effect lookup
  never collapses duplicate archetypes.
- Keep taskbar visible at the bottom on the default 1280x720 gate screenshot.

## 1. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| Player | Watches the auto-battle and presses taskbar commands. | Human input only. |
| `Main` | Composes header, feed, map view, and taskbar. | Screen routing. |
| `EmberhearthMapView` | Renders the battle strip, unit anchors, HP labels, and effects. | Presentation layout. |
| `Taskbar` | Renders command buttons and cooldown/readiness feedback. | Command surface. |
| `GameState` | Holds party, wave, enemies, currency, save snapshot. | Gameplay state source of truth. |
| `BattleEngine` | Emits damage, defeat, and boss telegraph signals. | Combat simulation. |
| `WaveState` | Creates per-wave enemy unit instances. | Runtime enemy identity. |
| `data/maps/emberhearth_map_plan.json` | Defines the tile map plan used as the stage background. | Map data. |
| `tests/bootstrap_test.gd` | Instantiates map/taskbar and calls effect APIs. | Regression gate. |

### Trust Boundary

- `GameState` owns gameplay numbers.
- `EmberhearthMapView` may read unit ids, HP, role, and display names.
- `EmberhearthMapView` must not compute combat outcomes.
- `Main` may route events into visual methods.
- `Taskbar` may emit command ids; command effects are still resolved by
  `BattleEngine` / `GameState`.
- Public TBH references inform category and layout direction only; no external
  art, exact screenshot composition, or proprietary UI is copied.

## 2. End-to-end Overview

```text
[Main] _ready()
   |
   v waits for AssetRegistry.loaded + GameState.is_ready
   |
[Main] _populate()
   |-- GameState.start_run()
   |-- BattleEngine.start()
   |-- MapView.render(GameState.party, GameState.wave_state.enemies)
   |
   v
[EmberhearthMapView] render()
   |-- read data/maps/emberhearth_map_plan.json
   |-- build TileGrid as stage background
   |-- create Party and Monster unit cells
   |-- position cells on one horizontal battle lane
   |-- store _cells_by_unit_id for effects
   |
   v
[BattleEngine] damage_dealt(source_id, target_id, amount)
   |
   v
[Main] _on_damage_dealt()
   |-- MapView.play_attack(source_id, target_id)
   |-- MapView.play_hit(target_id, amount)
   |-- MapView.play_heal(target_id, abs(amount)) when amount < 0
   |
   v
[EmberhearthMapView] effect methods
   |-- find unit cell from _cells_by_unit_id
   |-- animate the sprite inside the battle strip
   |-- no-op when a cell is missing
   |
   v
[Taskbar] command_pressed(id)
   |
   v
[Main] routes id to BattleEngine/GameState + MapView pulse
```

**Key:** the map becomes the combat surface. Unit cells are still presenter
nodes, but they now sit on the tile lane instead of below it.

## 3. Step-by-step

### STEP 1 - Keep shell composition stable

**System:** `Main`.

- Reuse the existing header, status label, feed panel, map view, and taskbar.
- Keep `_wait_for_runtime_ready()` unchanged.
- Keep `_populate()` as the only place that calls `MapView.render(...)` after
  both autoloads are ready.
- Make only small spacing/text changes if the new battle strip needs room.

### STEP 2 - Build a stage inside `EmberhearthMapView`

**System:** `EmberhearthMapView`.

- Replace the current `TileGrid + Combatants HBoxContainer` composition with:
  - a title row,
  - a `Stage` `Control`,
  - a `TileGrid` child used as the background,
  - a `UnitLayer` child used for manually positioned party/monster cells,
  - small `Party` and `Monsters` tags inside the stage.
- `Stage` owns a fixed minimum height so taskbar remains visible.
- `TileGrid` still loads cells from `AssetRegistry.load_grid_cell(...)`.
- `UnitLayer` never computes combat; it only positions visible cells.

### STEP 3 - Anchor party and enemies onto the lane

**System:** `EmberhearthMapView`.

- Build one unit cell per party/enemy using the existing sprite + name + HP +
  role labels.
- Position party cells from left to center using `starter_position` order already
  represented in `GameState.party`.
- Position enemy cells from right toward center using wave enemy order.
- Use each enemy instance `id` for lookup; keep the source archetype in
  `enemy_id`.
- Re-layout cells whenever:
  - `render()` creates a new wave,
  - the stage resizes after Godot layout,
  - the map grid size changes.
- Keep `_cells_by_unit_id` as the lookup table for effects.

### STEP 4 - Preserve current effects

**System:** `Main`, `EmberhearthMapView`, `Taskbar`.

- `play_attack`, `play_hit`, `play_heal`, `play_skill_pulse`,
  `play_boss_warning`, and `play_reward_burst` keep their public signatures.
- Effects use the same sprite lookup methods after cells move into the stage.
- Floating labels remain children of the sprite or a non-layout overlay.
- Taskbar button feedback stays unchanged.

### STEP 5 - Verify visual fit

**System:** `tests/bootstrap_test.gd`, `tools/gate_check.ps1`.

- Bootstrap test still instantiates the map view and calls effect methods.
- Full gate must capture `godot_runtime_screenshot.png`.
- Visual pass must confirm:
  - the taskbar is visible,
  - map and characters are in one battle stage,
  - labels do not overlap core action,
  - header text does not clip,
  - reward/effect nodes do not push layout.

## 4. State / Data Handling

| State | Where it lives | Lifecycle |
| --- | --- | --- |
| Party/enemy HP | `GameState` / `UnitState` | Created/restored by `GameState`, read by MapView. |
| Wave and enemies | `GameState.wave_state` | Re-rendered by MapView on `wave_changed`. |
| Enemy archetype | `UnitState.enemy_id` | Preserved from `data/combat/enemies.json`. |
| Enemy instance id | `UnitState.id` | Generated by `WaveState` per spawn; unique within the wave. |
| Map tiles | `data/maps/emberhearth_map_plan.json` + `AssetRegistry` | Loaded per render; no hard-coded asset paths. |
| Unit cell anchors | `EmberhearthMapView._cells_by_unit_id` | Rebuilt on render; used by effects. |
| Effect tweens/labels | Presenter nodes | Created per event; freed after tween. |
| Taskbar cooldowns | `Taskbar._cooldowns` | Presentation-only command readiness. |

## 5. API Spec

No public API or data contract is added.

### Existing MapView API - reuse

```gdscript
func render(party: Array, enemies: Array) -> void
func refresh_hp() -> void
func play_attack(source_id: String, target_id: String) -> void
func play_hit(target_id: String, amount: int) -> void
func play_heal(target_id: String, amount: int) -> void
func play_skill_pulse(skill_id: String) -> void
func play_boss_warning() -> void
func play_reward_burst(text: String) -> void
```

Guards:

- When a unit id has no visible cell, return.
- When a sprite is missing, no-op for sprite-only effects.
- When map plan JSON is missing/malformed, use `_fallback_map_plan()`.

## 6. Status Lifecycle

Status lifecycle is unchanged.

| Status | Meaning | Set by |
| --- | --- | --- |
| `running` | Auto-battle is active. | `GameState.start_run()`. |
| `won` | Wave 10 boss was cleared. | `GameState` run resolution. |
| `wiped` | Party died before clearing the run. | `GameState` run resolution. |

## 7. Data Model Touchpoints

| File | Role in this flow | Change |
| --- | --- | --- |
| `scripts/maps/emberhearth_map_view.gd` | Main stage and unit placement. | Edit. |
| `scripts/runtime/wave_state.gd` | Unique runtime ids for repeated enemy spawns. | Edit. |
| `scripts/main/main.gd` | Shell spacing/status only if needed. | Edit if needed. |
| `scripts/ui/taskbar.gd` | Command bar visual fit. | Edit if needed. |
| `tests/bootstrap_test.gd` | Effect/layout smoke coverage. | Reuse unless API changes. |
| `docs/systems/MAP_AND_TASKBAR.md` | Human docs for layout model. | Update. |
| `docs/production/STEAM_READINESS_ROADMAP.md` | Prototype status. | Update if result changes. |

## 8. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Stage resizes after unit cells are created | Call `_layout_stage()` deferred and on `Stage.resized`. |
| Wave has one enemy or three enemies | Enemy positions are calculated from count, centered on the right lane. |
| Wave repeats the same enemy archetype | `WaveState` assigns unique instance ids; `enemy_id` keeps the archetype. |
| Unit dies during effect | `refresh_hp()` greys the sprite; effect lookups guard missing nodes. |
| Row re-renders while labels are active | Old cells and child labels are freed with the row/layer. |
| Map JSON is missing | `_fallback_map_plan()` keeps a readable strip. |
| Default screenshot viewport is short | Stage height and taskbar height stay bounded. |
| Reward burst overlaps stage | Reward burst stays root-level and short-lived. |

## 9. Security & Concurrency

- No network calls, credentials, auth, or PII.
- No save format or persistence changes.
- Tweens run on the Godot main thread.
- Effects and layout must be idempotent under repeated render calls.
- Missing cells must no-op instead of crashing during wave transitions.

## 10. Build Checklist

### `EmberhearthMapView`

- [x] Add `Stage`, `UnitLayer`, and stage tag nodes.
- [x] Move party and monster cells onto the map lane.
- [x] Add `_layout_stage()` and count-aware cell placement.
- [x] Keep all public effect methods working.
- [x] Keep map tile loading through `AssetRegistry`.

### `Main` / `Taskbar`

- [x] Adjust spacing only if default viewport clips.
- [x] Keep taskbar visible and command feedback intact.

### Verification

- [x] Run `tools/gate_check.ps1`.
- [x] Inspect `godot_runtime_screenshot.png`.
- [x] Update docs and Sage knowledge if a reusable pattern appears.

## 11. Open Questions

None block implementation.

- Exact external TBH screenshots are not copied. This project uses the observed
  product category and repo docs to create an original Whisker Realm battle
  strip.

## Verify Pass - Should It Really Be This Way?

- This is the smallest change that satisfies the request: it changes spatial
  hierarchy without touching combat state.
- It follows existing rules: asset lookup remains through `AssetRegistry`, state
  remains in `GameState`, and effects remain presenter-owned.
- A more exact clone would create copyright/design risk and is unnecessary for
  the prototype's identity.
- A full TileMapLayer conversion would be premature because there is still no
  collision/pathing requirement in this slice.
