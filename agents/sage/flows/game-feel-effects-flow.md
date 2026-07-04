# Game Feel Effects - Animation And Impact Layer

> This flow makes the playable TBH prototype feel like a real game without
> changing the combat state model. It adds visual response around the existing
> `BattleEngine` signals: idle sprite animation, attack lunges, hit flashes,
> floating numbers, skill pulses, boss warning effects, reward bursts, and
> taskbar button feedback. Refs real code as of 2026-07-04.

## Header + Design Decisions

The existing loop already emits enough events to drive moment-to-moment feel:
`damage_dealt`, `unit_defeated`, `skill_used`, `boss_telegraph`, `wave_changed`,
`wave_cleared`, and `run_ended`. The animation layer should be presenter-owned
and disposable: it reads unit ids and amounts from signals, finds the matching
cell in `EmberhearthMapView`, and creates tweens/temporary controls. It must not
store HP, currency, wave, or battle results.

Design decisions:

- `GameState` remains the single owner of gameplay numbers.
- `BattleEngine` keeps simulating combat; it does not know about tweens.
- `EmberhearthMapView` owns unit-local effects: idle bob, attack lunge, hit
  flash, floating numbers, defeat fade, boss warning ring.
- `Main` owns screen-level effects: status pulse, loot feed pulse, reward burst,
  light screen shake.
- `Taskbar` owns command feedback: press pop, cooldown pulse, ready glow.
- Effects use Godot `Tween`, `Label`, `ColorRect`, and existing cropped sprite
  textures. No new source assets are created.

## 1. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| Player | Sees and feels moment-to-moment feedback while combat continues. | Human perception only. |
| `BattleEngine` | Emits combat events with source id, target id, amount, skill id, and boss warning text. | Simulation events. |
| `GameState` | Emits wave/reward/run signals and owns state values. | State source of truth. |
| `EmberhearthMapView` | Maps unit ids to visible unit cells and plays unit-local effects. | Presentation effects. |
| `Main` | Wires events into MapView/Taskbar and plays global UI feedback. | Presentation coordinator. |
| `Taskbar` | Animates command slots and cooldown/readiness. | Command surface. |
| `tests/bootstrap_test.gd` | Asserts effect API exists and still boots headless. | Regression gate. |
| `tools/gate_check.ps1` | Runs headless test and screenshot smoke. | Verification gate. |

### Trust Boundary

- Unit ids and numbers come from events; the visual layer never recomputes combat.
- Effects are best-effort. If a cell has been re-rendered or a unit is gone, the
  effect method returns without crashing.
- Runtime art still comes only through `AssetRegistry`; this flow uses existing
  loaded textures and built-in Control nodes.

## 2. End-to-end Overview

```text
[BattleEngine] emits damage_dealt(source_id, target_id, amount)
   |
   v
[Main] _on_damage_dealt()
   |-- MapView.play_attack(source_id, target_id)
   |-- MapView.play_hit(target_id, amount)
   |-- if amount < 0: MapView.play_heal(target_id, -amount)
   |-- status and loot feed stay short
   |
   v
[EmberhearthMapView]
   |-- finds source/target cells from _cells_by_unit_id
   |-- attack lunge on source sprite
   |-- hit flash + shake on target sprite
   |-- floating number above target
   |-- refresh_hp()

[Main] receives skill_used or taskbar command
   |
   v
[Taskbar] press slot pop + cooldown pulse
   |
   v
[MapView] skill effect
   |-- burst: warm slash/flash around party
   |-- heal: green lift/glow over party

[BattleEngine] emits boss_telegraph(message)
   |
   v
[Main] status pulse + MapView.play_boss_warning()
   |
   v
[MapView] boss cell pulses purple warning ring

[GameState] emits wave_cleared/run_ended/currency_changed
   |
   v
[Main] reward burst + loot feed pulse + header pulse
```

**Key:** animation is driven by signals and thrown away. No effect node becomes
authoritative gameplay state.

## 3. Step-by-step

### STEP 1 - MapView keeps effect anchors per unit

**System:** `EmberhearthMapView`.

- `_cells_by_unit_id` already maps unit id to the `VBoxContainer` cell.
- Add helper getters:
  - `_cell_for_unit(unit_id: String) -> Control`
  - `_sprite_for_unit(unit_id: String) -> TextureRect`
- When a row re-renders, old effect nodes are freed with the old cells.
- Each cell gets `clip_contents = false` when possible so floating labels can
  rise without being clipped.

### STEP 2 - Idle animation runs while units are visible

**System:** `EmberhearthMapView`.

- After each sprite is created, call `_start_idle_bob(sprite, unit_id)`.
- Idle bob uses a looping tween:
  - move sprite up/down by 3 pixels
  - slightly vary duration by stable unit id hash so all sprites do not bob in
    perfect lockstep
- On defeated units, stop bright motion by lowering alpha/greying the sprite;
  the bob can remain subtle or be killed by re-render.

### STEP 3 - Damage and healing become visible

**System:** `EmberhearthMapView`, `Main`.

- `Main._on_damage_dealt()` routes:
  - positive amount -> `play_attack(source_id, target_id)` and
    `play_hit(target_id, amount)`
  - negative amount -> `play_heal(target_id, abs(amount))`
- `play_attack()` lunges the source sprite horizontally toward the target and
  returns it to its start position.
- `play_hit()` flashes target red/white, shakes it slightly, and spawns a red
  floating label `-N`.
- `play_heal()` flashes green and spawns `+N`.

### STEP 4 - Skills get readable, satisfying effects

**System:** `Main`, `Taskbar`, `EmberhearthMapView`.

- On `skill_1`:
  - Taskbar button pops immediately.
  - MapView pulses all living party sprites warm/gold.
  - Main status label pulses once.
- On `skill_2`:
  - Taskbar button pops immediately.
  - MapView plays green upward heal labels for each living party member from
    the existing `damage_dealt("skill_heal", id, -amount)` events.
- Cooldown labels remain numeric but disabled slots pulse once at start and
  glow when ready.

### STEP 5 - Boss telegraph becomes an effect, not just text

**System:** `BattleEngine`, `Main`, `MapView`.

- Existing `boss_telegraph(message)` signal remains.
- Main sets the text, pulses the status label, and calls
  `MapView.play_boss_warning()`.
- MapView finds alive boss/enemy cells on wave 10 and applies a purple scale +
  flash effect around the sprite.

### STEP 6 - Reward events feel like a reward

**System:** `Main`.

- On `currency_changed`, pulse the currency label.
- On `loot_event`, pulse the loot feed panel and spawn a short `+ Pawcoins`
  burst near the top-right header when the text contains a reward.
- On `run_ended("won")`, play a larger gold reward burst.
- On `run_ended("wiped")`, use a softer red status pulse, not a reward burst.

### STEP 7 - Taskbar gets command feedback

**System:** `Taskbar`.

- Add public `play_command_feedback(id: String, color: Color) -> void`.
- When the command is pressed, scale the button up and back down.
- When cooldown starts, disabled slot dims but also pulses once so the click is
  acknowledged.
- When cooldown reaches zero, slot briefly glows to show readiness.

### STEP 8 - Verification proves effects exist and screen stays usable

**System:** `tests/bootstrap_test.gd`, `tools/gate_check.ps1`.

- Headless test instantiates `EmberhearthMapView`, renders party/enemies, and
  asserts effect methods exist by calling them with known ids.
- Headless test instantiates `Taskbar`, renders commands, and asserts feedback
  method can be called without crashing.
- Gate screenshot remains the visual proof that layout is not blank or clipped.

## 4. State / Data Lifecycle

| State | Where it lives | Lifecycle |
| --- | --- | --- |
| Combat numbers | `GameState` / `UnitState` | Unchanged. Effects read only. |
| Timers/tweens | Scene nodes created by presenters | Created on effect start; auto-killed/free on finish or row re-render. |
| Floating labels | Temporary children under unit sprites or `Main` | Created per event; tween up/fade; `queue_free()` on finish. |
| Cooldown values | `Taskbar._cooldowns` | Existing presentation state; unchanged except ready feedback. |
| Effect colors | Constants in presenter scripts | UI-only palette. |

## 5. API Spec - Internal Contracts

### `EmberhearthMapView`

```gdscript
func play_attack(source_id: String, target_id: String) -> void
func play_hit(target_id: String, amount: int) -> void
func play_heal(target_id: String, amount: int) -> void
func play_skill_pulse(skill_id: String) -> void
func play_boss_warning() -> void
func play_reward_burst(text: String) -> void
```

Guards:

- If a unit id has no visible cell, return.
- If a sprite is missing because asset load failed, use the cell as the anchor.

### `Taskbar`

```gdscript
func play_command_feedback(id: String, color: Color = Color.WHITE) -> void
```

Guards:

- If slot id is missing, return.

### `Main`

Main stays the event router:

- `damage_dealt` -> MapView attack/hit/heal.
- `skill_used` or command press -> taskbar and skill pulse.
- `boss_telegraph` -> status pulse and boss warning.
- `loot_event`/`currency_changed`/`run_ended` -> reward/status feedback.

## 6. Status Lifecycle

Gameplay status lifecycle does not change. Visual effects layer reacts to
existing statuses only:

- `running` -> idle bob, attack/hit effects.
- `won` -> victory reward burst.
- `wiped` -> wipe status pulse.

## 7. Data Model Touchpoints

| File | Role in this flow | Change |
| --- | --- | --- |
| `scripts/maps/emberhearth_map_view.gd` | Unit-local effects and idle animation. | Edit. |
| `scripts/main/main.gd` | Signal routing and screen-level effects. | Edit. |
| `scripts/ui/taskbar.gd` | Command press/cooldown/ready feedback. | Edit. |
| `tests/bootstrap_test.gd` | Headless effect API smoke. | Edit. |
| `README.md` | Usage note for richer prototype controls/effects. | Update. |
| `docs/production/STEAM_READINESS_ROADMAP.md` | Current prototype status. | Update. |

## 8. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Unit dies and row re-renders during an effect | Old node is freed; new event methods guard missing nodes. |
| Multiple hits land in one tick | Multiple labels can stack; use small x offsets or let them rise together. |
| Skill heal emits negative damage | Main routes negative amount to heal effect. |
| Boss telegraph arrives when boss cell is gone | Return without error. |
| Cooldown completes after slot re-render | `_slots_by_id` lookup returns current slot or no-ops. |
| Headless tests have no visible window | Tweens/effect methods still create nodes safely; screenshot gate covers real window. |

## 9. Security & Concurrency

- No network, no secrets, no persistence changes.
- Effects use Godot main-thread tweens only.
- No user-generated input enters file paths or asset ids.
- Effects must not mutate HP/currency/wave.

## 10. Build Checklist

### MapView

- [x] Add idle bob for unit sprites.
- [x] Add attack lunge, hit flash, heal flash, floating numbers.
- [x] Add skill pulse and boss warning effect.
- [x] Add safe helpers for looking up unit cells/sprites.

### Main

- [x] Route damage/heal/skill/boss/reward events to effects.
- [x] Add status/header/feed pulse helpers.
- [x] Add screen-level reward burst for currency and victory.

### Taskbar

- [x] Add command press pop.
- [x] Add cooldown-start and cooldown-ready feedback.

### Verification

- [x] Extend bootstrap test to call effect APIs.
- [x] Run `tools/gate_check.ps1`.
- [x] Inspect screenshot for visible, unclipped UI.

## 11. Open Questions

None block coding.

- Audio is still deferred. This pass focuses on visual game feel.
- Animation art remains sprite-frame based. Full frame cycling can come later
  through `AssetRegistry.load_sprite_frames(...)`, but current motion/tween
  effects should already remove the static prototype feel.

## Verify Pass - Should It Really Be This Way?

- The design follows the current signal architecture instead of adding polling.
- State ownership remains unchanged: `GameState` owns values, presenters own
  throwaway effects.
- No new assets are needed, so the asset catalog does not need regeneration.
- Effects are allowed to be best-effort because gameplay correctness comes from
  the headless test and `GameState`, not from tweens completing.
