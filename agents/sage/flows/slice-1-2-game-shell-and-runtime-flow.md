# Slice 1+2 — Game Shell + Unit Runtime Data (Godot main scene)

> This flow turns `main.tscn` from an **asset preview** into a **game shell** and
> then instantiates the party of four heroes plus the wave-1 enemy from JSON
> data. It spans two slices of `docs/production/PLAYABLE_GAME_BUILD_PLAN.md`:
> Slice 1 (shell) and Slice 2 (runtime unit/wave state). No combat logic yet —
> Slice 3 owns that. Refs real code as of 2026-07-04. Doc type: `architecture`
> + `frontend` (Godot Control tree).

---

## 1. Actors & Systems

| System | Responsibility | Ownership |
| --- | --- | --- |
| `AssetRegistry` (autoload, existing) | Read `data/asset_catalog.json` + `data/asset_shortcuts.json` on `_ready()`; resolve shortcut → catalog id → `godot_path` → `Texture2D`. | Runtime asset boundary. Owns art paths. |
| `GameState` (autoload, new) | Own the mutable game session — currency, current wave, party (4 units), spawned enemies, run status. Single source of truth for numbers. | Runtime simulation boundary. Owns HP, currency, wave index. |
| `scenes/main/main.tscn` + `scripts/main/main.gd` (rewritten) | Compose the top-level Control tree: header (title + currency label + wave label) → body (map view + optional inspector) → taskbar. Await `AssetRegistry.catalog_ready`, then instantiate `MapView` and `Taskbar`. | Presentation composition. Does not own numbers. |
| `scenes/maps/emberhearth_map_view.tscn` + `scripts/maps/emberhearth_map_view.gd` (new) | Show the Emberhearth map background (tilesheet from `map.default_tilesheet`) + party sprites (row of 4) + enemy sprite (single, wave 1). Render party from `GameState.party`. | Map presentation. Reads `GameState`, never writes. |
| `scenes/ui/taskbar.tscn` + `scripts/ui/taskbar.gd` (new) | Render the taskbar panel (background from `ui.taskbar_panel`) with command slots built from `data/ui/taskbar_commands.json`. Buttons are stubs in this slice — click is logged, no combat effect. | UI presentation. Reads `data/ui/taskbar_commands.json`. |
| `scripts/runtime/game_state.gd` (autoload target) | Load `data/units/starter_party.json` → build `UnitState` array for party. Load `data/combat/mvp_waves.json` → build `WaveState` for wave 1. Expose `party`, `wave`, `currency`, `run_status` + signals `state_ready`, `party_changed`. | Runtime state, no rendering. |
| `scripts/runtime/unit_state.gd` (data class, new) | Per-unit runtime: `id`, `display_name`, `clan_id`, `party_role`, `lane`, `idle_asset`, `hp_current`, `hp_max`, `atk`, `def`, `affinity`, `alive`. | Pure data. No node dependency. |
| `scripts/runtime/wave_state.gd` (data class, new) | Per-wave runtime: `wave`, `type`, `enemies` (array of `UnitState`), `reward_id`, `goal`. Wave 1 has one enemy in this slice. | Pure data. |
| `data/*.json` (existing, read-only in this slice) | `data/units/starter_party.json`, `data/combat/mvp_waves.json`, `data/combat/affinities.json`, `data/ui/taskbar_commands.json`, `data/asset_shortcuts.json`. | Design data. Never written from code. |
| `tools/gate_check.ps1` (new) | Run GUT tests + `capture_runtime_screenshot.ps1` in one command; pass if both exit 0 and the screenshot is non-blank. | Local verification gate. |

### Trust boundary

- **`GameState` owns numbers.** `MapView` and `Taskbar` read `GameState`; they never mutate it. Slice 3 will introduce mutations via `GameState.apply_damage()` etc.
- **`AssetRegistry` owns art paths.** No scene may hard-code `res://asset/...`. Only shortcut ids or catalog ids ever leave gameplay code.
- **Data JSON is read-only** in this slice. Changing party composition = edit `data/units/starter_party.json`, not code.
- **The screen the user sees on boot is a game shell, not an asset preview.** If `AssetRegistry` fails to load (missing catalog), the shell renders with placeholder colored rects and pushes a warning — never crashes.

---

## 2. End-to-end overview

```text
[Godot Engine] launches project.godot → main_scene = scenes/main/main.tscn
   │
   ▼ engine loads autoloads in order:
   │  1. AssetRegistry._ready()  → load_catalog() → emit catalog_ready
   │  2. GameState._ready()      → wait for AssetRegistry.catalog_ready (one-shot)
   │                             → load_starter_party() from data/units/starter_party.json
   │                             → load_wave(1) from data/combat/mvp_waves.json
   │                             → currency = 0, wave = 1, run_status = "idle"
   │                             → emit state_ready
   │
[main.gd] _ready()
   │  ── build_shell(): Backdrop + SafeArea + VBox(Header, Body, Taskbar)
   │  ── Header: title label + currency label + wave label
   │  ── Body: MapView (from scenes/maps/emberhearth_map_view.tscn)
   │  ── Taskbar: Taskbar (from scenes/ui/taskbar.tscn)
   │
   ├─(A) if AssetRegistry.loaded AND GameState.ready → populate() immediately
   └─(B) else → connect GameState.state_ready one-shot → populate() when fired
   │
[main.gd] populate()
   │  ── Header labels bind to GameState (wave, currency)
   │  ── MapView.render(GameState.party, GameState.wave.enemies)
   │        └─ AssetRegistry.load_texture("map.default_tilesheet") → background
   │        └─ for unit in party: AssetRegistry.load_texture(unit.idle_asset) → sprite
   │        └─ for enemy in wave.enemies: AssetRegistry.load_texture(enemy.idle_asset)
   │  ── Taskbar.render(data/ui/taskbar_commands.json)
   │        └─ for cmd in commands: build slot with AssetRegistry.load_texture(cmd.asset_shortcut)
   │        └─ connect pressed → prints "[taskbar] pressed: <id>" (stub, Slice 4 wires effect)
   │
[User] sees: Emberhearth map background · 4 hero sprites in a row · 1 enemy sprite ·
             HP labels ("100/100") next to each · taskbar with 6 command slots ·
             header showing "Wave 1" and "Currency 0"
   │
   ▼ tools/gate_check.ps1
   │  ── run GUT test suite (asserts autoloads present, party.size == 4, wave.enemies.size >= 1)
   │  ── run capture_runtime_screenshot.ps1 (launch, screenshot, kill)
   │  └─ pass if both exit 0 AND screenshot pixel-variance > threshold (not solid black)
```

**Key / หัวใจ:** `GameState` is the single owner of gameplay numbers from day one.
`main.gd` and every future scene are **readers**. Getting the ownership boundary
right in Slice 2 is the reason Slices 3–8 will not need a rewrite.

---

## 3. Step-by-step

### STEP 1 — Engine boots, autoloads register

**System:** Godot engine + `project.godot`.

- `project.godot` `[autoload]` block declares `AssetRegistry` (existing) and will declare `GameState` (new): `GameState="*res://scripts/runtime/game_state.gd"`.
- Autoload order matters: `AssetRegistry` before `GameState` (GameState waits on catalog_ready).
- `run/main_scene` stays `res://scenes/main/main.tscn`.
- No new engine features — Godot 4.2 baseline stays.

**Business rule:** Autoload order is declared by the order of the `[autoload]` block; the flow above depends on `AssetRegistry` being listed first.

### STEP 2 — `AssetRegistry._ready()` loads catalog

**System:** `scripts/autoload/asset_registry.gd` (existing).

- Reads `res://data/asset_catalog.json` (array) and `res://data/asset_shortcuts.json` (dict).
- Populates `entries`, `by_id`, `shortcuts`; sets `loaded = true`; emits `catalog_ready`.
- On missing catalog: `push_warning`; `loaded` stays `false`. Downstream must degrade gracefully.
- **Reuse:** no code change.

### STEP 3 — `GameState._ready()` waits for catalog, then loads data

**System:** `scripts/runtime/game_state.gd` (new autoload).

- If `AssetRegistry.loaded` → call `_bootstrap_state()` immediately.
- Else → `AssetRegistry.catalog_ready.connect(_bootstrap_state, CONNECT_ONE_SHOT)`.
- `_bootstrap_state()`:
  - Load three data files in this order (all read-only, all mandatory):
    - `res://data/units/clans.json` → build `clans_by_id: Dictionary` for stat lookup.
    - `res://data/units/starter_party.json` → the 4 party rows.
    - `res://data/combat/enemies.json` → build `enemies_by_id: Dictionary` for wave enemy lookup.
    - `res://data/combat/mvp_waves.json` → find entry `wave == 1`.
  - For each starter row: construct a `UnitState` by joining on `clan_id` — pull `base_hp`, `base_atk`, `base_def`, `affinity` from the matching clan row. `hp_current = hp_max`. `idle_asset` comes from the starter row.
  - For each id in wave 1's `enemies` array: look up in `enemies_by_id`, construct an enemy `UnitState` using its own `base_hp`/`base_atk`/`base_def`/`affinity`/`idle_asset`.
  - `currency = 0`, `wave = 1`, `run_status = "idle"`, `ready = true`, emit `state_ready`.
- **Guard:** if any JSON is missing/malformed → `push_error` naming the file, `ready = false`, emit `state_ready` anyway with empty party+enemies so the shell still renders and the failure is visible in-window.
- **Guard:** if a starter row references a `clan_id` not present in clans.json → `push_error`, skip that unit (do NOT invent stats). Same for a wave enemy id not in enemies.json.

**Business rule (stat lookup):** All numbers come from data files. No stats are ever declared in GDScript. If a designer wants to rebalance, they edit `data/units/clans.json` or `data/combat/enemies.json` — never the runtime code.

**Field default:** `UnitState.modulate_hint` defaults to `""` for heroes (the field is absent from `starter_party.json`; `from_starter()` sets `""`). Enemies always have an explicit `modulate_hint` in `enemies.json`.

### STEP 4 — `main.gd` builds the shell

**System:** `scripts/main/main.gd` (rewritten from asset preview).

- `_ready()`:
  - `_build_shell()` composes Control tree: Backdrop + SafeArea + VBox(Header, Body, Taskbar). Reuse `_make_panel`, `_make_margin`, `_make_label`, `_make_texture_rect` helpers from the current file (already project-idiomatic).
  - **Header:** HBox with title `TBH: Task Bar Hero` + spacer + currency label (`"Pawcoins 0"` — soft-currency name from `data/economy/currencies.json` id `soft_currency`) + wave label (`"Wave 1 / 10"`).
  - **Body:** `MapView` instance loaded from `scenes/maps/emberhearth_map_view.tscn`, `SIZE_EXPAND_FILL`.
  - **Taskbar:** `Taskbar` instance loaded from `scenes/ui/taskbar.tscn`, fixed height 132px (matches current preview).
- After building the shell, decide readiness:
  - if `AssetRegistry.loaded and GameState.ready` → `_populate()`.
  - else → connect `GameState.state_ready.connect(_populate, CONNECT_ONE_SHOT)`.
- **Deleted from old main.gd:** `UNIT_PREVIEW_IDS`, `SLOT_PREVIEW_IDS`, `_fill_preview_row`, `_short_label`, unit_preview_row/slot_preview_row/status_label/map_preview/taskbar_skin fields (replaced by MapView + Taskbar instances).

### STEP 5 — `MapView.render()` shows Emberhearth + party + wave-1 enemy

**System:** `scripts/maps/emberhearth_map_view.gd` (new).

- Scene shape (built in code from a stub `.tscn`):
  - `PanelContainer` with a StyleBoxFlat (reuse the `Color(0.33, 0.27, 0.18)` accent border — see `godot-runtime/rules.md`).
  - `MarginContainer(14)` → `VBoxContainer(separation=10)` → header label `"Emberhearth"` (Whisker Realm world identity per `docs/PROJECT_IDENTITY.md`) + tilesheet backdrop (`TextureRect`, `map.default_tilesheet`, `EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`) + party row + enemy row.
- `render(party: Array, enemies: Array)`:
  - **Party row** (`HBoxContainer`, one cell per unit): sprite (idle texture via `AssetRegistry.load_texture(unit.idle_asset)`, min 64×64) + name label (`unit.display_name`, 11pt) + HP label (formatted `"%d/%d" % [hp_current, hp_max]`). Order by `starter_position`.
  - **Enemy row** (below party): same shape but one column per enemy (wave-1 has one).
  - **Modulate by hint:** after setting texture, apply `sprite.modulate` from `unit.modulate_hint`: `"enemy_red"` → `Color(1.0, 0.55, 0.55)`, `"boss_purple"` → `Color(0.75, 0.55, 1.0)`, `""` (heroes — default) → no tint. Any unknown value → no tint + warning.
  - If a texture is null → placeholder ColorRect (`Color(0.4, 0.15, 0.15)`), don't crash. Push a warning naming the missing shortcut.
- **Does NOT** own numbers or start any timer. Pure presenter.

### STEP 6 — `Taskbar.render()` builds command slots

**System:** `scripts/ui/taskbar.gd` (new).

- Scene shape:
  - `PanelContainer` (StyleBoxFlat, same border color).
  - `TextureRect` background using `ui.taskbar_panel` at the left (150×88 like the existing preview) — decorative.
  - `HBoxContainer` of command slots — one per entry in `data/ui/taskbar_commands.json`.
- Per-command slot:
  - `VBoxContainer` → `TextureButton` (up: `AssetRegistry.load_texture(cmd.asset_shortcut)`) + label (`cmd.label`, 9pt).
  - `pressed` signal → `emit_signal("command_pressed", cmd.id)`. `main.gd` connects and prints `"[taskbar] pressed: %s"` for now.
- **Slice-3+ hook:** the `command_pressed` signal is the seam where Slice 4 wires skills. Not wired to `GameState` yet.

### STEP 7 — `main.gd` populate binds labels + wires taskbar signal

**System:** `main.gd`.

- Wave label = `"Wave %d / 10" % GameState.wave`.
- Currency label = `"%s" % GameState.currency`.
- `MapView.render(GameState.party, GameState.wave_state.enemies)`.
- `Taskbar.render(commands_json)`; `Taskbar.command_pressed.connect(_on_command_pressed)`.
- `_on_command_pressed(id)`: `print("[taskbar] pressed: %s" % id)` — stub.
- Reconnect on `GameState.party_changed` (future-proof for Slice 3 that will mutate HP).

### STEP 8 — `tools/gate_check.ps1` verifies

**System:** local dev machine.

- Command form: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate_check.ps1`.
- Steps in order:
  1. Locate Godot (same resolver as `run_game.ps1`: `-GodotPath` arg → `$env:GODOT_EXE` → `Godot*.exe` in repo root → `godot` on PATH → common install dirs).
  2. Run GUT in headless mode: `& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Fail on non-zero exit or "0 asserts run".
  3. Run `tools/capture_runtime_screenshot.ps1`. Fail on non-zero exit.
  4. Assert `godot_runtime_screenshot.png` exists AND `Length > 3000` bytes. A solid-color 1280×720 PNG compresses to well under 3 KB; the current shot is ~40 KB. This is the cheap "not blank" proxy — no GDI+ pixel-loading required.
- Output on pass: `[gate] OK — <N> tests, <M> asserts, screenshot <bytes> bytes`.
- Output on fail: `[gate] FAIL — <which step> · <actual stderr/stdout tail>`. Non-zero exit for CI-ability.

---

## 4. State / data lifecycle

| State | Where it lives | Lifecycle |
| --- | --- | --- |
| `AssetRegistry.entries` / `by_id` / `shortcuts` | Memory of the `AssetRegistry` autoload. | Loaded once on `_ready()`. Never reloaded in this slice (a `reload_catalog()` method will come with future asset hot-reload). |
| `GameState.party` (Array of `UnitState`) | Memory of the `GameState` autoload. | Built once on `_bootstrap_state()`. Never mutated in Slice 2 — Slice 3 introduces `apply_damage()` etc. |
| `GameState.wave_state` (`WaveState`) | Memory of the `GameState` autoload. | Built for wave 1 on bootstrap. `advance_to_wave(n)` method exists but is only called by Slice 3+. |
| `GameState.currency` (int) | Memory of the `GameState` autoload. | Init 0. Mutated only through `GameState.add_currency(delta)` (introduced Slice 5). |
| `GameState.wave` (int) | Memory of the `GameState` autoload. | Init 1. Mutated only through `advance_to_wave()`. |
| `GameState.run_status` (String) | Memory of the `GameState` autoload. | `"idle"` in this slice. Will be `"running" | "won" | "wiped"` from Slice 3+. |
| Screen labels (`Wave`, `Currency`) | Node theme text on `main.gd`'s Header children. | Updated on `state_ready` and on `party_changed`. Cleared on scene tear-down. |
| No persistence yet | No file on disk. | Save/Load = Slice 6. |

**Must NOT be trusted client-side:** N/A in this slice (single-process, no network).

---

## 5. API spec — internal (Godot signals + method contracts)

There is no HTTP API in this slice; the "API spec" is the **GDScript method +
signal contract** of the new autoloads/scenes so every future slice can plug in.

### 5.1 `AssetRegistry` (existing) — reuse

```gdscript
# already implemented — see scripts/autoload/asset_registry.gd
signal catalog_ready
var loaded: bool
func resolve_id(id_or_shortcut: String) -> String
func get_entry(id_or_shortcut: String) -> Dictionary
func has_asset(id_or_shortcut: String) -> bool
func get_asset_path(id_or_shortcut: String) -> String
func load_texture(id_or_shortcut: String) -> Texture2D
func find_assets(filters: Dictionary = {}) -> Array
func ids_for(filters: Dictionary = {}) -> PackedStringArray
```

### 5.2 `GameState` (new autoload) — build

```gdscript
extends Node

signal state_ready
signal party_changed          # emitted when any unit's stats change
signal wave_changed(wave: int)
signal currency_changed(new_value: int)

var ready: bool = false
var party: Array[UnitState] = []      # exactly 4 entries after _bootstrap_state()
var wave: int = 1
var wave_state: WaveState = null
var currency: int = 0
var run_status: String = "idle"       # "idle" | "running" | "won" | "wiped"

# Post-bootstrap invariant: assert party.size() == 4 in _bootstrap_state() so a
# bad starter_party.json fails loud instead of silently rendering 3 heroes.

func _ready() -> void
    # waits for AssetRegistry.catalog_ready or fires _bootstrap_state immediately

func _bootstrap_state() -> void
    # loads party + wave 1, emits state_ready

func get_unit_by_id(id: String) -> UnitState
func advance_to_wave(n: int) -> void       # Slice 3+ uses this
func add_currency(delta: int) -> void      # Slice 5 uses this
func reset_run() -> void                   # Slice 3+ (on wipe)
```

**Guard:** `advance_to_wave(n)` is a no-op if `n > 10` (MVP cap) — emit a warning and stay at wave 10.

**Side effects:** `_bootstrap_state()` emits `state_ready` exactly once per session. Multiple subscribers are OK (main.gd + future MapView).

### 5.3 `UnitState` (new — `class_name`)

Runtime state for one hero or enemy. Mutable. Not a `Resource` — pure `RefCounted` so it can hold live HP without persisting to disk. If Slice 3+ needs designer-inspector editing of definitions, a companion `UnitDef extends Resource` may be introduced then (per the `resources-for-data-not-scripts` skill, `advise` enforcement).

```gdscript
class_name UnitState
extends RefCounted

var id: String
var display_name: String
var clan_id: String            # "" for enemies
var enemy_id: String           # "" for heroes
var party_role: String         # "tank" | "dps" | "support" | "healer" | "enemy"
var lane: String               # "front" | "middle" | "rear" | "enemy"
var idle_asset: String         # shortcut key, e.g. "unit.player_idle"
var modulate_hint: String      # "" (heroes) or e.g. "enemy_red" | "boss_purple"
var hp_max: int
var hp_current: int
var atk: int
var def: int
var affinity: String           # matches data/combat/affinities.json ids
var alive: bool = true
var starter_position: int = 0

static func from_starter(row: Dictionary, clan: Dictionary) -> UnitState
    # Joins starter row (id/clan_id/party_role/lane/idle_asset/starter_position)
    # with clan row (base_hp/base_atk/base_def/affinity).

static func from_enemy(enemy: Dictionary) -> UnitState
    # Enemy rows are self-contained (base_hp/base_atk/base_def/affinity/idle_asset).
```

### 5.4 `WaveState` (new)

```gdscript
class_name WaveState
extends RefCounted

var wave: int
var type: String              # "basic" | "mixed" | "affinity" | "milestone" | "pressure" | "boss"
var goal: String
var reward_id: String
var enemies: Array            # Array of UnitState

static func for_wave(wave_number: int, waves_catalog: Array, enemies_by_id: Dictionary) -> WaveState
    # Reads mvp_waves.json entry, resolves each enemy id via enemies_by_id.
```

### 5.5 `Taskbar` (new scene) — signal contract

```gdscript
signal command_pressed(id: String)      # id is from data/ui/taskbar_commands.json
func render(commands: Array) -> void    # rebuilds slot row from the JSON array
```

### 5.6 `MapView` (new scene) — signal contract

```gdscript
signal unit_selected(unit_id: String)   # future — currently unused
func render(party: Array, enemies: Array) -> void
```

---

## 6. Status lifecycle

`GameState.run_status`:

| Code | Meaning | Set by |
| --- | --- | --- |
| `idle` | Party loaded, no combat running. Boot state. | `_bootstrap_state()` |
| `running` | Slice 3+: a run is in progress. | `advance_to_wave(1)` (Slice 3) |
| `won` | Slice 3+: player cleared wave 10 boss. | Slice 3 combat resolver |
| `wiped` | Slice 3+: all party HP == 0. | Slice 3 combat resolver |

**Transitions in Slice 2:** none — status stays `idle` until Slice 3 lands.

---

## 7. Data model touchpoints

| File | Role in this flow | Change? |
| --- | --- | --- |
| `data/units/starter_party.json` | Source of 4 hero definitions (`id`, `clan_id`, `party_role`, `lane`, `idle_asset`, `starter_position`). | Read-only. |
| `data/units/clans.json` | Source of per-clan `base_hp`, `base_atk`, `base_def`, `affinity`. **Extended in this slice** to add those four fields per row. | Edit — already done ahead of coding. |
| `data/combat/enemies.json` | Source of enemy definitions (`id`, `display_name`, `idle_asset`, `base_hp`, `base_atk`, `base_def`, `affinity`, `modulate_hint`). **New file** created for this slice. | New. |
| `data/combat/mvp_waves.json` | Source of wave metadata + enemy ids. **Extended** to add `enemies: [enemy_id]` per wave. | Edit — already done ahead of coding. |
| `data/combat/affinities.json` | Reference for `affinity` field values. | Read-only. |
| `data/economy/currencies.json` | Source of the `Pawcoins` label (soft currency `name`). | Read-only. |
| `data/ui/taskbar_commands.json` | Source of taskbar slot definitions. | Read-only. |
| `data/asset_shortcuts.json` | Referenced through `AssetRegistry` only. | Read-only. |
| `data/asset_catalog.json` | Generated. Referenced through `AssetRegistry` only. | Regenerate only if we add assets — not planned this slice. |
| `data/design_sources.json` | Folder contract. **Add `scripts/runtime` and `tests` entries.** | Edit. |
| `agents/sage/godot-runtime/rules.md` | Standing rules. **Add `scripts/runtime` bullet.** | Edit. |
| `project.godot` | **Add `GameState="*res://scripts/runtime/game_state.gd"` to `[autoload]`.** | Edit. |

---

## 8. Edge cases & error handling

| Case | Handling |
| --- | --- |
| `AssetRegistry` catalog missing | `push_warning`; `loaded = false`. `GameState._bootstrap_state()` still runs (it doesn't need the catalog); textures return `null` → `MapView` uses colored placeholders. Screen is not blank. |
| `data/units/starter_party.json` missing/malformed | `push_error`; `party = []`; `ready = false`; emit `state_ready` anyway. Header shows "Wave 1 / 10", MapView shows "No party loaded — check data/units/starter_party.json". |
| `data/combat/mvp_waves.json` missing/malformed | `push_error`; `wave_state = WaveState.empty()`; emit `state_ready`. MapView shows no enemy row. |
| Shortcut in `starter_party.json` (`idle_asset`) is not in `asset_shortcuts.json` | `AssetRegistry.load_texture` returns `null` + warning naming the shortcut. `MapView` renders placeholder rect. |
| Taskbar command references missing shortcut | Same — placeholder rect + warning; the slot is still clickable and prints its id. |
| `main.tscn` opened before autoloads (edge in the editor) | Godot always loads autoloads before `main`; irrelevant at runtime. Editor-time script errors are prevented by static typing. |
| GUT tests fail | `gate_check.ps1` exits non-zero, prints the failing assertion path. |
| Screenshot fully black | `gate_check.ps1` computes mean pixel intensity; below threshold → fail with "screenshot appears blank". |
| User has no Godot on PATH | `gate_check.ps1` uses the same fallback resolver as `run_game.ps1` (accepts `-GodotPath`, reads `$env:GODOT_EXE`, then the local `Godot_v4.7-stable_win64.exe`). |
| Double-click on a taskbar button | `pressed` fires twice, prints twice. Fine for Slice 2 — Slice 4 introduces cooldown. |

---

## 9. Security & concurrency

- **No network** in this slice — no authz, no external calls. Save/Load is Slice 6.
- **Single-threaded Godot main loop** — no race conditions.
- **`state_ready` idempotency** — `_bootstrap_state()` guards with `if ready: return` at the top. Multiple subscribers OK.
- **File reads are synchronous** — `FileAccess.get_file_as_string`. Blocking is fine because it runs in `_ready()` before any frame renders.
- **No secrets, no PII.** Data files ship with the game.

---

## 10. Build checklist

### `scripts/runtime/` (new folder)

- [ ] Create `scripts/runtime/game_state.gd` (autoload) — signals + state fields + bootstrap + guards.
- [ ] Create `scripts/runtime/unit_state.gd` — `class_name UnitState` with `from_starter_json` / `from_enemy_spec` factories.
- [ ] Create `scripts/runtime/wave_state.gd` — `class_name WaveState` with `for_wave` factory reading `mvp_waves.json`.
- [ ] Add `GameState="*res://scripts/runtime/game_state.gd"` to `project.godot` `[autoload]` block **after** `AssetRegistry`.

### `scenes/ui/` (new)

- [ ] Create `scenes/ui/taskbar.tscn` — root `PanelContainer` extending `scripts/ui/taskbar.gd`.
- [ ] Create `scripts/ui/taskbar.gd` — `command_pressed` signal + `render(commands)` builder.

### `scenes/maps/` (new)

- [ ] Create `scenes/maps/emberhearth_map_view.tscn` — root `PanelContainer` extending `scripts/maps/emberhearth_map_view.gd`.
- [ ] Create `scripts/maps/emberhearth_map_view.gd` — `render(party, enemies)` + placeholder handling for missing textures.

### `scripts/main/`

- [ ] Rewrite `scripts/main/main.gd` — delete preview code; add shell + populate + taskbar wiring.
- [ ] Keep `_make_panel` / `_make_margin` / `_make_label` / `_make_texture_rect` helpers (still used by shell).

### Design contract

- [ ] Extend `data/design_sources.json` `folder_contracts` with `"scripts/runtime": "pure game state and simulation, no scene/UI code"` and `"tests": "GUT test suite"`.
- [ ] Extend `agents/sage/godot-runtime/rules.md` folder contract section with the same entries.

### Tests + gate

- [ ] Install GUT addon under `addons/gut/` (from official release).
- [ ] Create `tests/` folder with `test_bootstrap.gd`: asserts `AssetRegistry` loaded, `GameState.ready`, `GameState.party.size() == 4`, `GameState.wave_state.enemies.size() >= 1`.
- [ ] Create `tools/gate_check.ps1` — runs GUT headless + screenshot smoke + non-blank check.

### Sage knowledge (Step 5 of the pipeline)

- [x] `agents/sage/godot-runtime/decisions/game-state-is-single-owner-of-session-numbers.md` — pattern: `GameState` is the single mutable owner of session numbers; presenters read only. **Already landed with this flow.**
- [ ] `agents/sage/godot-runtime/decisions/runtime-folder-added-to-contract.md` — pattern: new folders under `scripts/` require a `data/design_sources.json` + `rules.md` update in the same change. Land with the code.
- [ ] `agents/sage/godot-runtime/skills/gut-boot-smoke.md` — skill: how to write a minimum-viable GUT test that boots autoloads and asserts state readiness. Land with the tests.

---

## 11. Open questions

After the scrutinize + rework pass, all previously-open questions were either
answered by existing data or resolved with sane defaults. None block coding.
Kept here as a record so a later reader knows how each was resolved.

- **Q1 — Wave-1 enemy sprite: RESOLVED.** `data/combat/enemies.json` now defines `tangleborn_yarnling` with `idle_asset = "unit.ranged_idle"` + `modulate_hint = "enemy_red"`. `MapView` applies red modulate when `modulate_hint == "enemy_red"`.
- **Q2 — Stat numbers: RESOLVED.** Per-clan stats now live in `data/units/clans.json`; enemy stats in `data/combat/enemies.json`. Numbers picked to give role identity (tank has 140 HP / low atk; mages have 80 HP / high atk); they are the balance-team's job to iterate, not the coder's.
- **Q3 — Currency icon: DEFAULT APPLIED.** Header shows plain text `"Pawcoins 0"` for Slice 2. A dedicated coin sprite is a Slice 5 concern (rewards + upgrade).
- **Q4 — Currency name: RESOLVED.** `Pawcoins` from `data/economy/currencies.json` id `soft_currency`. This was already in the data — original doc missed the grep.
- **Q5 — HP display: DEFAULT APPLIED.** Show numeric `"H/M"` label only for Slice 2. `TextureProgressBar` overlay lands in Slice 3 with combat (avoids a rebuild).
- **Q6 — Taskbar layout: DEFAULT APPLIED.** Flat row of 6 slots. Grouping deferred to Slice 4.
- **Q7 — Test folder name: DEFAULT APPLIED.** `tests/` (plural, GUT convention). Added to folder contract.
- **Q8 — GUT install method: DEFAULT APPLIED.** Vendor into `addons/gut/` (committed). Editor-time Asset Library import is not scriptable; submodule adds git complexity for zero benefit here.

**Non-blocking (decided during coding without human input):** scene file naming
(`emberhearth_map_view.tscn`), no `SubViewportContainer` for the map (overkill),
reuse existing StyleBoxFlat colors.

---

## Verify pass (self-review — Sage `plan-flow` step 2)

Checked against the doc-style template's verify list:

- [x] Every arrow in §2 has a matching STEP in §3. (8 hops → 8 STEPs.)
- [x] Every error in the state/lifecycle section has an entry in §8 (catalog missing, party JSON missing, wave JSON missing, shortcut missing).
- [x] Every storage write / external call is named. (No writes in Slice 2. Reads: 4 JSON files + `AssetRegistry` texture loads.)
- [x] Trust boundaries are correct: `GameState` owns numbers; presenters read only; `AssetRegistry` owns art paths.
- [x] Every uncertain decision is in §11 Open Questions. 8 raised; questions #1, #4, and #8 are the ones I most want you to answer before I start — the other five have safe defaults.

**Cross-check against `godot-runtime/rules.md`:**

- [x] "Always go through `AssetRegistry`" — MapView + Taskbar do exactly this.
- [x] "Static typing everywhere" — every method signature above has types.
- [x] "Default texture filter is 0 (nearest)" — no change proposed.
- [x] "Add a new folder only when it maps to one of the domains above; if it doesn't fit, extend `data/design_sources.json` first" — done: step 1 of the checklist is exactly this.
- [x] Signals use `CONNECT_ONE_SHOT` on `catalog_ready` and `state_ready` (STEP 3, STEP 4).
- [x] `push_warning` for recoverable gaps, `push_error` for contract violations (§8).

**Cross-check against `assets/rules.md`:**

- [x] Ids are never invented in code — every reference goes through `asset_shortcuts.json`.
- [x] Shortcut keys use dot notation (`unit.player_idle` etc.).
- [x] Q #1 respects the "add a new shortcut whenever runtime code would otherwise reach for a raw catalog id" rule — that's why (b) is presented alongside (a).

**Weak point I want to name explicitly:** placeholder stats (Q #2) are the biggest risk to Slice 3. If we pick numbers now that are far from combat-balanced, Slice 3 will have to rebalance immediately. Recommend answering Q #2 with intent to move stats to a dedicated `data/units/stat_tables.json` in Slice 3.
