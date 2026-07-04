# Playable Party Combat MVP - Save, Boss, Rewards, UI Proof

> This flow closes the first playable TBH loop after the asset pipeline and
> shell work: the player sees a four-hero party fight Tangleborn monsters,
> uses taskbar skills, receives visible loot and boss feedback, upgrades the
> party, and returns with saved progress. It refs real code as of 2026-07-04:
> `GameState`, `BattleEngine`, `EmberhearthMapView`, `Taskbar`, and the authored
> JSON data under `data/`.

## Header + Design Decisions

The current project already has the core combat skeleton: `GameState` loads the
starter party and wave catalog, `BattleEngine` runs timed hero/enemy attacks,
`EmberhearthMapView` renders the party and enemies from asset shortcuts, and
`Taskbar` emits command ids. The remaining MVP gap is not another preview; it is
closing the player loop with persistent progress, clear combat UI, a wave-10
boss moment, and reward/upgrades that survive restart.

Related rules and decisions:

- `agents/sage/godot-runtime/decisions/asset-registry-is-only-runtime-lookup.md`
- `agents/sage/godot-runtime/decisions/wait-for-catalog-ready.md`
- `agents/sage/godot-runtime/decisions/game-state-is-single-owner-of-session-numbers.md`
- `agents/sage/assets/decisions/slice-sheets-at-registry-boundary.md`
- `agents/sage/persistence/skills/save-schema-versioning.md`

## 1. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| Player | Watches the party auto-fight, presses taskbar skills, claims rewards, upgrades, restarts. | Human intent only. No source-of-truth state. |
| `AssetRegistry` autoload | Resolves art shortcuts and crops sprite/tile frames. | Only runtime boundary allowed to touch `asset/` files. |
| `GameState` autoload | Owns currency, wave, best wave, upgrade level, party HP/stats, wave enemies, run status, loot feed. | Single mutable owner of session and persisted game numbers. |
| `BattleEngine` node | Advances combat ticks, applies party/enemy attacks, applies active skills, emits combat feedback. | Simulation driver. Calls `GameState` mutators; does not own persistent state. |
| `Main` scene/script | Composes header, status, map, loot feed, taskbar, and save-aware controls. | Presentation coordinator. Reads state and connects signals. |
| `EmberhearthMapView` | Displays tile map, party, monsters, HP labels, boss/monster status. | Presentation only. No mutation. |
| `Taskbar` | Displays command slots and cooldown labels from `data/ui/taskbar_commands.json`. | Command surface only. Emits ids to `Main`. |
| `user://save.json` | JSON save mirror for prototype persistence. | Local save artifact. `GameState` writes and reads it. |
| `tests/bootstrap_test.gd` | Headless proof that runtime data and asset rendering contracts still boot. | Regression gate. |
| `tools/gate_check.ps1` | Runs headless test and runtime screenshot smoke. | Local verification gate. |

### Trust Boundary

- `GameState` computes and stores gameplay numbers. Presenters never keep a
  parallel currency, wave, upgrade, or HP value.
- `BattleEngine` may request state changes through named `GameState` methods,
  but it does not persist its own combat result.
- `AssetRegistry` is the only system that resolves texture paths. Runtime code
  uses shortcuts such as `unit.player_idle` and `ui.button_normal`.
- `user://save.json` is trusted only as local prototype state. It has
  `schema_version` from day one so later migrations have an anchor.

## 2. End-to-end Overview

```text
[Godot Engine] starts project.godot
   |
   v
[AssetRegistry] load_catalog()
   |-- reads data/asset_catalog.json
   |-- reads data/asset_shortcuts.json
   |-- emits catalog_ready
   |
   v
[GameState] _bootstrap_state()
   |-- loads clans, starter_party, enemies, mvp_waves
   |-- loads user://save.json if present
   |-- applies saved currency, best_wave, upgrade_level, last_afk_unix
   |-- loads wave 1 and applies upgrade stats to party
   |-- emits state_ready
   |
   v
[Main] _populate()
   |-- renders header: wave, best wave, Pawcoins, upgrade level
   |-- renders MapView: party + monsters + HP + wave goal
   |-- renders LootFeed: recent rewards and combat events
   |-- renders Taskbar: skills, upgrade, AFK chest, replay controls
   |-- starts GameState run + BattleEngine
   |
   v
[BattleEngine] timers tick while run_status == "running"
   |-- party tick: alive heroes attack the lowest-HP monster
   |-- enemy tick: monsters attack front-lane party members
   |-- boss wave: emits telegraph before Hushweave strike window
   |-- every hit/defeat emits UI feedback signals
   |
   +-- when all monsters defeated:
   |     GameState.mark_wave_cleared()
   |       |-- awards wave reward
   |       |-- updates best_wave
   |       |-- if wave < 10: loads next wave
   |       |-- if wave == 10: run_status = "won"; awards boss chest; saves
   |
   +-- when all heroes defeated:
         GameState.mark_wipe()
           |-- run_status = "wiped"
           |-- saves best_wave/currency/upgrade state
           |-- Main prompts AFK chest or upgrade/retry
   |
   v
[Player] presses taskbar commands
   |-- Skill 1: Wildstripe burst, cooldown, visible status line
   |-- Skill 2: Cloudfur heal, cooldown, visible HP recovery
   |-- AFK Chest: claim accrued local reward, save immediately
   |-- Upgrade: spend Pawcoins, increase upgrade_level, apply stats, save
   |-- Replay: reset party/wave and restart stronger
   |
   v
[tools/gate_check.ps1]
   |-- headless bootstrap test proves data/assets/state contracts
   |-- screenshot smoke proves playable screen is nonblank
```

**Key:** this is a single-process prototype, but it still has two hard
ownership lines: `GameState` owns numbers and `AssetRegistry` owns art lookup.
Everything else is a reader, a command surface, or a simulation driver.

## 3. Step-by-step

### STEP 1 - Runtime boot gates on assets and state

**System:** `AssetRegistry`, `GameState`.

- `AssetRegistry._ready()` reads generated catalog + shortcuts and emits
  `catalog_ready`.
- `GameState._ready()` uses the required pattern:
  - when `AssetRegistry.loaded` is true -> `_bootstrap_state()`
  - else -> connect `AssetRegistry.catalog_ready` with `CONNECT_ONE_SHOT`
- `_bootstrap_state()` is idempotent: when `is_ready` is already true, return.
- The data bootstrap loads:
  - `data/units/clans.json`
  - `data/units/starter_party.json`
  - `data/combat/enemies.json`
  - `data/combat/mvp_waves.json`
- After authored data loads, `GameState` attempts local save restore from
  `user://save.json`.

### STEP 2 - GameState restores prototype persistence

**System:** `GameState`.

- `CURRENT_SAVE_SCHEMA_VERSION = 1`.
- `SAVE_PATH = "user://save.json"`.
- If the file is missing, default values remain:
  - `currency = 0`
  - `best_wave = 1`
  - `upgrade_level = 0`
  - `last_afk_unix = now`
- If the file exists:
  - parse JSON as dictionary
  - reject newer schema versions with `push_warning` and keep defaults
  - read known fields only
  - clamp negative currency/upgrade values to 0
- Restore never mutates source JSON under `data/`.
- Restore emits state signals after party/wave are ready so UI has one coherent
  snapshot.

### STEP 3 - Party and monster state are built from authored data

**System:** `GameState`, `UnitState`, `WaveState`.

- `GameState._load_party()` creates exactly four `UnitState` rows from
  `data/units/starter_party.json` joined with clan base stats.
- `GameState._load_wave(n)` creates monster `UnitState` rows from
  `data/combat/mvp_waves.json` joined with `data/combat/enemies.json`.
- Saved `upgrade_level` applies as a derived stat bonus after party creation:
  - `atk += upgrade_level`
  - `hp_max += upgrade_level * 5`
  - `hp_current = hp_max` when a run resets
- The saved upgrade is not written into the source party data; it is runtime
  progression only.

### STEP 4 - Main scene renders the playable command surface

**System:** `Main`, `MapView`, `Taskbar`.

- `Main._build_shell()` owns the top-level layout only.
- Header displays:
  - title
  - current wave out of 10
  - best wave
  - Pawcoins
  - upgrade level
- Status line displays the current action, skill result, wipe, victory, or boss
  telegraph.
- Loot feed displays the newest combat/reward events; it should be short and
  scan-friendly, not a wall of instructions.
- `MapView.render(GameState.party, GameState.wave_state.enemies)` shows party
  and monsters from cropped sprite frames.
- `Taskbar` renders commands and cooldown labels; it does not know what each
  command does.

### STEP 5 - BattleEngine advances auto-combat

**System:** `BattleEngine`.

- `start()` starts party and enemy timers.
- A party tick:
  - exits unless `GameState.run_status == "running"`
  - gets alive monsters from `GameState.wave_state.alive_enemies()`
  - each alive hero hits the lowest-HP monster
  - emits `damage_dealt(hero.id, monster.id, amount)`
  - emits `unit_defeated(monster.id)` when a monster reaches 0 HP
  - calls `_check_end_conditions()`
- An enemy tick:
  - exits unless run is running
  - chooses front-lane hero first, then middle, then rear
  - each alive monster hits that target
  - emits the same damage/defeat signals
  - calls `_check_end_conditions()`
- A boss tick on wave 10:
  - emits a telegraph event before the next heavy strike window
  - gives the player a readable status line to heal/burst
  - uses existing monster HP/ATK values; the first implementation may be a
    stronger attack cadence instead of a complex new skill system

### STEP 6 - Wave clear, wipe, and victory mutate only GameState

**System:** `GameState`.

- `mark_wave_cleared()`:
  - emits `wave_cleared(wave)`
  - adds wave reward currency through `add_currency()`
  - appends a loot feed entry
  - updates `best_wave = max(best_wave, wave)`
  - when `wave < MAX_WAVE`, advances to the next wave
  - when `wave == MAX_WAVE`, sets `run_status = "won"`, awards boss chest,
    emits `run_ended("won")`, and saves
- `mark_wipe()`:
  - sets `run_status = "wiped"`
  - emits `run_ended("wiped")`
  - saves currency/best wave/upgrade/AFK timestamp
- `add_currency(delta)`:
  - clamps currency to `>= 0`
  - emits `currency_changed(currency)`
  - does not save on every combat tick; reward and player actions save

### STEP 7 - Taskbar commands give the player agency

**System:** `Main`, `Taskbar`, `BattleEngine`, `GameState`.

- `skill_1` triggers Wildstripe burst:
  - `BattleEngine.trigger_skill_1_wildstripe_burst()`
  - taskbar cooldown starts at 12 seconds
  - loot/status feed records "Wildstripe burst active"
- `skill_2` triggers Cloudfur heal:
  - heals alive party members by 25% max HP
  - taskbar cooldown starts at 10 seconds
  - UI refreshes HP immediately
- `afk_chest` claims local idle reward:
  - reward = elapsed seconds since `last_afk_unix`, capped to MVP-safe value
  - reward is visible in loot feed
  - save immediately
- `upgrade` spends Pawcoins:
  - cost scales from current `upgrade_level`
  - when insufficient, status line says exact missing cost
  - when successful, increment `upgrade_level`, apply stats, save
- `replay` or equivalent retry behavior:
  - resets party HP
  - loads wave 1
  - starts run stronger

### STEP 8 - Tests and screenshot prove the loop

**System:** `tests/bootstrap_test.gd`, `tools/gate_check.ps1`.

- Headless test asserts:
  - AssetRegistry loaded
  - party size is 4
  - wave 1 has at least one monster
  - sprite frame and tile crop APIs return 16x16 textures
  - save snapshot has schema version 1 and required fields
  - upgrade mutator changes stats and currency consistently
- Screenshot smoke asserts:
  - game window launches
  - `godot_runtime_screenshot.png` is produced
  - file size is above the nonblank threshold

## 4. State / Data Lifecycle

| State | Where it lives | Lifecycle |
| --- | --- | --- |
| `party` | `GameState.party` | Built from data on boot; reset HP on replay; stat bonuses re-applied from `upgrade_level`. |
| `wave` | `GameState.wave` | Starts at 1; increments on clear; resets to 1 on replay. |
| `wave_state.enemies` | `GameState.wave_state` | Rebuilt from data every wave so monster HP starts fresh. |
| `currency` | `GameState.currency` | Loaded from save; changes through `add_currency`; saved after rewards/upgrades. |
| `best_wave` | `GameState.best_wave` | Loaded from save; maxed on clear; displayed in header. |
| `upgrade_level` | `GameState.upgrade_level` | Loaded from save; increments through upgrade command; drives derived party stat bonuses. |
| `last_afk_unix` | `GameState.last_afk_unix` | Loaded from save; updated after AFK chest claim and save. |
| `recent_events` | `GameState.recent_events` | In-memory rolling list for UI; not required to persist. |
| cooldown timers | `Taskbar._cooldowns` | Presentation-only command lockouts; reset on scene load. |
| `user://save.json` | Local user data | Written by `GameState.save_game()`; never committed. |

## 5. API Spec - Internal GDScript Contracts

### 5.1 `GameState` - existing and extended

```gdscript
signal state_ready
signal party_changed
signal wave_changed(wave: int)
signal wave_cleared(wave: int)
signal run_ended(status: String)
signal currency_changed(new_value: int)
signal loot_event(message: String)
signal save_changed

var currency: int
var best_wave: int
var upgrade_level: int
var last_afk_unix: int
var recent_events: Array[String]

func start_run() -> void
func reset_run() -> void
func advance_to_wave(n: int) -> void
func add_currency(delta: int) -> void
func mark_wave_cleared() -> void
func mark_wipe() -> void
func claim_afk_chest() -> int
func try_buy_upgrade() -> Dictionary
func save_game() -> bool
func load_save() -> void
func snapshot() -> Dictionary
```

Expected `try_buy_upgrade()` response:

```jsonc
// success
{
  "ok": true,
  "cost": 25,
  "upgrade_level": 1
}

// insufficient currency
{
  "ok": false,
  "reason": "not_enough_currency",
  "cost": 25,
  "currency": 10
}
```

### 5.2 Save snapshot schema

```jsonc
{
  "schema_version": 1,
  "currency": 85,
  "best_wave": 7,
  "upgrade_level": 2,
  "last_afk_unix": 1783159200
}
```

Guard:

- missing file -> defaults
- malformed JSON -> warning + defaults
- newer schema -> warning + defaults
- negative numbers -> clamp to safe minimums

Side effect:

- `save_game()` writes JSON to `user://save.json`.

### 5.3 `BattleEngine` - extended events

```gdscript
signal tick_processed
signal damage_dealt(source_id: String, target_id: String, amount: int)
signal unit_defeated(unit_id: String)
signal skill_used(skill_id: String)
signal boss_telegraph(message: String)
```

Behavior:

- No direct save writes.
- All currency/wave/end-state changes call `GameState`.
- Boss telegraph is observable UI feedback and may also append a loot/status
  event through `Main`.

### 5.4 `Taskbar`

```gdscript
signal command_pressed(id: String)
func render() -> void
func start_cooldown(id: String, seconds: float) -> void
```

Behavior:

- Command ids come from `data/ui/taskbar_commands.json`.
- Cooldowns disable their buttons and display seconds remaining.
- A disabled cooldown click emits nothing.

### 5.5 `EmberhearthMapView`

```gdscript
signal unit_selected(unit_id: String)
func render(party: Array, enemies: Array) -> void
func refresh_hp() -> void
```

Behavior:

- Reads `GameState.wave_state` only to display current wave text.
- Uses `AssetRegistry.load_grid_cell` and `load_sprite_frame`.
- Does not mutate party or monster state.

## 6. Status Lifecycle

| Code | Meaning | Set by |
| --- | --- | --- |
| `idle` | State loaded; no run is currently progressing. | `_bootstrap_state()`, `reset_run()` before start. |
| `running` | Auto-battle timers may mutate HP and waves. | `start_run()`. |
| `won` | Wave 10 boss cleared and boss chest awarded. | `mark_wave_cleared()` when `wave >= MAX_WAVE`. |
| `wiped` | All party members reached 0 HP. | `mark_wipe()`. |

Transitions:

- `idle -> running` when `Main._populate()` or replay starts the run.
- `running -> running` when a non-boss wave clears and next wave loads.
- `running -> won` when wave 10 clears.
- `running -> wiped` when no party members are alive.
- `won -> running` or `wiped -> running` when player upgrades/replays.

## 7. Data Model Touchpoints

| File | Role in this flow | Change |
| --- | --- | --- |
| `scripts/runtime/game_state.gd` | Persistence, rewards, upgrade level, best wave, AFK chest, loot events. | Edit. |
| `scripts/runtime/battle_engine.gd` | Boss telegraph event and cleaner combat feedback. | Edit. |
| `scripts/main/main.gd` | Header, status, loot feed, save-aware command handling. | Edit. |
| `scripts/maps/emberhearth_map_view.gd` | Monster label/HP clarity and boss display. | Edit. |
| `scripts/ui/taskbar.gd` | Command readiness polish where needed. | Maybe edit. |
| `data/ui/taskbar_commands.json` | Add replay/retry command if needed. | Maybe edit. |
| `tests/bootstrap_test.gd` | Add persistence and upgrade assertions. | Edit. |
| `docs/production/PLAYABLE_GAME_BUILD_PLAN.md` | Reflect which MVP slices are now landed. | Update post-code. |
| `docs/production/STEAM_READINESS_ROADMAP.md` | Update current state/remaining work. | Update post-code. |

## 8. Edge Cases & Error Handling

| Case | Handling |
| --- | --- |
| Save file missing | Use defaults and write a save after the first reward/action. |
| Save file malformed | `push_warning`, use defaults, do not crash boot. |
| Save schema is newer | `push_warning`, use defaults; future UI can show "please update". |
| Player upgrades without enough currency | Return structured failure; status line names cost and current currency. |
| Player claims AFK chest twice immediately | Second claim returns a small or zero reward, updates message, never goes negative. |
| Run reaches wave 11 by bug | `advance_to_wave()` warns and stays at `MAX_WAVE`; boss clear ends run. |
| Boss telegraph fires after boss defeated | Boss tick exits when no alive enemies. |
| A taskbar shortcut is missing | Existing Taskbar leaves empty texture but command still works. |
| A monster asset shortcut is missing | MapView placeholder renders; test still proves state. |
| Screenshot tool cannot find Godot window | `gate_check.ps1` reports failure; no success claim. |

## 9. Security & Concurrency

- No network, no auth, no PII, no payment.
- `user://save.json` is editable by the player. That is acceptable for a local
  prototype; do not use it for leaderboard authority.
- Timer callbacks run on Godot's main thread. Race risk is low, but end-state
  methods must be idempotent because party and enemy timers can fire close
  together.
- Save writes happen on reward/upgrade/end-state actions, not every `_process`
  frame.
- AFK reward uses local clock; clock tampering is accepted for prototype only.

## 10. Build Checklist

### Runtime

- [x] Add schema-versioned JSON save/load to `GameState`.
- [x] Add `best_wave`, `upgrade_level`, `last_afk_unix`, and `recent_events`.
- [x] Add `snapshot()`, `save_game()`, `load_save()`, `try_buy_upgrade()`,
      `claim_afk_chest()`, and event helpers.
- [x] Apply upgrade level to party stats after party load and replay reset.
- [x] Ensure wave clear, wipe, victory, AFK claim, and upgrade save progress.

### Combat

- [x] Add boss telegraph signal to `BattleEngine`.
- [x] Emit boss message during wave 10 before/around heavy pressure.
- [x] Keep existing Skill 1 and Skill 2 effects wired through Taskbar.

### UI

- [x] Add best wave and upgrade level to the header/status area.
- [x] Add compact loot/combat feed.
- [x] Add clear boss/win/wipe messages.
- [x] Add or reuse a replay path so the player can restart stronger.

### Tests + Verification

- [x] Extend `tests/bootstrap_test.gd` with save snapshot and upgrade coverage.
- [x] Run `tools/gate_check.ps1`.
- [x] Inspect or capture the runtime screenshot and ensure the main screen shows
      party, monsters, taskbar, and readable status.

### Docs + Knowledge

- [x] Update affected docs under `docs/production/`.
- [x] Capture reusable save boundary knowledge if not covered by existing Sage
      persistence skills.

## 11. Open Questions

None block coding.

- Production save format may later become `.res` plus JSON mirror per the
  persistence skill. For this prototype flow, JSON primary is acceptable because
  the acceptance only requires local persistence and inspectable test evidence.
- Boss mechanics can get deeper later. The MVP needs a visible wave-10 telegraph
  and reward, not a full encounter scripting system.
- Audio is documented but no runtime audio bus or imported SFX is required for
  this specific goal; visual/status feedback is the acceptance path here.

## Verify Pass - Should It Really Be This Way?

- The flow follows `GameState` single ownership. `Main`, `MapView`, and
  `Taskbar` remain readers/command surfaces.
- The flow follows the asset boundary. Every visual still reaches art through
  `AssetRegistry` and shortcut ids.
- Save/load belongs in `GameState` because it serializes the same values
  `GameState` owns; putting it in `Main` would create a second owner of session
  numbers.
- JSON primary save is a deliberate prototype compromise. Existing Sage
  persistence knowledge advises `.res` plus JSON mirror, but this goal asks for
  playable MVP progress, and the project currently has no save Resource class.
- The weak point is timer-based combat rather than the priority-queue scheduler.
  That is acceptable for this MVP because the existing code and roadmap already
  describe timer ticks; the scheduler skill remains an advise-level future
  improvement.
- No human decision is required before coding: all remaining choices are MVP
  implementation details with safe defaults already supported by docs.
