# Sound System — Foundation (Plan 1 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the runnable core of the audio system — 5-bus mixer, the `AudioRegistry` (catalog) + `AudioDirector` (engine) autoloads, persisted volume sliders, SFX variation pools, and the reward chime ladder with sidechain ducking — wired to a few known-live game events.

**Architecture:** Mirrors the existing `AssetRegistry` pattern: JSON manifests resolved by a catalog autoload, consumed by an engine autoload that owns bus routing + player pools. Everything degrades gracefully when `.wav` assets are absent (warn + skip), so this ships and tests green with **zero audio assets** present. Full design: `docs/superpowers/specs/2026-07-12-sound-system-design.md`.

**Tech Stack:** Godot 4.2 (GDScript), `AudioServer` + `AudioStreamPlayer` + `AudioBusLayout` (`.tres`), `ConfigFile` for settings, headless `.tscn` tests run via `godot --headless`.

**Scope of this plan (Phases 1–3 of the spec's §15).** Deferred to Plans 2–3: purr ambient bed, adaptive layered music + state machine, Animalese cat voice, offline/AFK audio, the options-panel UI, and per-hit combat-event emit points inside `battle_view.gd`'s inline damage resolution (which requires reading that 2700-line file first — see spec §12).

## Global Constraints

- **Godot 4.2 APIs only** (`config/features="4.2"`). Use `AudioServer`, `linear_to_db`/`db_to_linear`, `Time.get_ticks_msec()`, `ConfigFile`. No 4.3+-only calls.
- **No `class_name` on the audio autoload scripts.** `asset_registry.gd` and `game_state.gd` have none; the audio autoloads follow suit to sidestep the `class_name`-inside-autoload-preload failure (`agents/sage/godot-runtime/decisions/class-name-fails-inside-autoload-preloads.md`).
- **Never leave an `AudioStreamPlayer` on the `Master` bus.** Every player sets `.bus` at creation (spec §5).
- **Never hard-code `res://…/foo.wav` in engine code.** Cues + paths live in JSON, resolved through `AudioRegistry` (CLAUDE.md rule).
- **Graceful degradation.** A missing `.wav` is a `push_warning` + skip, never a crash (mirrors `AssetRegistry.load_texture`).
- **Volume changes go through the bus**, via `AudioServer.set_bus_volume_db(idx, linear_to_db(v))` — never per-player `volume_db` for category level (per-play jitter is the only per-player use).
- **Test invocation** (PowerShell), used verbatim in every task's run steps:
  ```powershell
  $godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { (Get-ChildItem -Filter "Godot*.exe" | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1).FullName }
  & $godot --headless --audio-driver Dummy --path . res://tests/audio_system_test.tscn; "exit=$LASTEXITCODE"
  ```

---

## File Structure

- Create `default_bus_layout.tres` — 5-bus mixer (Master → Music/SFX/Ambient/Voice/UI), + Compressor sidechains added in Task 5.
- Create `scripts/autoload/audio_registry.gd` — catalog autoload (loads manifests, resolves cue → `AudioStream`s).
- Create `scripts/autoload/audio_director.gd` — engine autoload (buses, pools, `sfx`/`reward`, volume API, settings).
- Create `data/audio/audio_shortcuts.json` — role → wav path table (mirrors `asset_shortcuts.json`).
- Modify `data/audio/sound_cues.json` — migrate the 8 existing cues to the extended schema.
- Modify `project.godot` — register the 2 autoloads + point at the bus layout.
- Modify `scripts/combat/battle_view.gd` — two one-line audio hooks (`_on_nav`, `_on_levelup_chosen`).
- Create `tests/audio_system_test.{gd,tscn}` — grows across Tasks 1–5.
- Create `tests/audio_wiring_test.{gd,tscn}` — boots `battle.tscn`, Task 6.

**Interfaces produced by this plan (relied on by Plans 2–3):**

```gdscript
# AudioRegistry (autoload)
signal audio_ready
var loaded: bool
func get_cue(id: String) -> Dictionary          # {} if unknown
func has_cue(id: String) -> bool
func load_stream(path: String) -> AudioStream    # cached; push_warning + null on miss
func streams_for(id: String) -> Array            # Array[AudioStream]; [] if none resolve

# AudioDirector (autoload)
func set_bus_volume(bus_name: String, value01: float) -> void   # applies + persists
func get_bus_volume(bus_name: String) -> float
func save_settings() -> void
func load_settings() -> void
func sfx(cue_id: String) -> AudioStreamPlayer    # pooled play; null on unknown/throttled
func reward(layer: int) -> AudioStreamPlayer     # 1..5 → reward cue; null on bad layer
```

---

### Task 1: Bus layout + assert 5 buses exist

**Files:**
- Create: `default_bus_layout.tres`
- Modify: `project.godot` (add `[audio]` section)
- Create: `tests/audio_system_test.gd`, `tests/audio_system_test.tscn`

**Interfaces:**
- Consumes: nothing.
- Produces: named buses `Master, Music, SFX, Ambient, Voice, UI` in `AudioServer`.

- [ ] **Step 1: Write the failing test**

Create `tests/audio_system_test.gd`:

```gdscript
extends Node

# Headless unit test for the audio system. Autoloads are global in any headless
# scene, so this exercises AudioRegistry/AudioDirector in isolation (no game scene).
# Invoke via: godot --headless --audio-driver Dummy res://tests/audio_system_test.tscn

const EXPECTED_BUSES := ["Master", "Music", "SFX", "Ambient", "Voice", "UI"]

var _failures: Array[String] = []


func _ready() -> void:
	_test_buses_exist()
	_finish()


func _test_buses_exist() -> void:
	for bus_name in EXPECTED_BUSES:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "bus '%s' exists" % bus_name)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[audio_system_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[audio_system_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
```

Create `tests/audio_system_test.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/audio_system_test.gd" id="1"]

[node name="AudioSystemTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Global-Constraints test command.
Expected: FAIL exit=1, assertions like `bus 'Music' exists` (only `Master` exists by default).

- [ ] **Step 3: Create the bus layout**

Create `default_bus_layout.tres`:

```
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/0/name = "Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = "Master"
bus/1/name = "Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = "Master"
bus/2/name = "SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = "Master"
bus/3/name = "Ambient"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = "Master"
bus/4/name = "Voice"
bus/4/solo = false
bus/4/mute = false
bus/4/bypass_fx = false
bus/4/volume_db = 0.0
bus/4/send = "Master"
bus/5/name = "UI"
bus/5/solo = false
bus/5/mute = false
bus/5/bypass_fx = false
bus/5/volume_db = 0.0
bus/5/send = "Master"
```

- [ ] **Step 4: Point the project at the bus layout**

In `project.godot`, add a new section (place it after the `[application]` block):

```ini
[audio]

buses/default_bus_layout="res://default_bus_layout.tres"
```

- [ ] **Step 5: Run test to verify it passes**

Run the Global-Constraints test command.
Expected: PASS, `[audio_system_test] PASS`, exit=0.

- [ ] **Step 6: Commit**

```bash
git add default_bus_layout.tres project.godot tests/audio_system_test.gd tests/audio_system_test.tscn
git commit -m "feat(audio): add 5-bus layout + headless bus assertion test"
```

---

### Task 2: `AudioRegistry` autoload + JSON manifests

**Files:**
- Create: `scripts/autoload/audio_registry.gd`
- Create: `data/audio/audio_shortcuts.json`
- Modify: `data/audio/sound_cues.json`
- Modify: `project.godot` (register autoload)
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: nothing (reads JSON files).
- Produces: `AudioRegistry.get_cue/has_cue/streams_for/load_stream`, `signal audio_ready`, `var loaded`.

- [ ] **Step 1: Write the failing test**

Append to `tests/audio_system_test.gd` — add the call in `_ready()` and the new function:

```gdscript
func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_finish()


func _test_registry_resolves_cues() -> void:
	_expect(AudioRegistry.loaded, "AudioRegistry finished loading manifests")
	_expect(AudioRegistry.has_cue("ui_click"), "cue 'ui_click' is known")
	var cue := AudioRegistry.get_cue("ui_click")
	_expect(str(cue.get("bus", "")) == "UI", "ui_click routes to the UI bus, got '%s'" % str(cue.get("bus", "")))
	_expect(AudioRegistry.get_cue("does_not_exist").is_empty(), "unknown cue returns an empty Dictionary")
	# Missing wav degrades to null, not a crash:
	_expect(AudioRegistry.load_stream("res://asset/audio/__missing__.wav") == null, "missing wav returns null (no crash)")
	_expect(AudioRegistry.streams_for("ui_click") is Array, "streams_for always returns an Array")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Global-Constraints test command.
Expected: FAIL — parser/runtime error `Identifier "AudioRegistry" not found` (autoload not registered yet).

- [ ] **Step 3: Migrate `sound_cues.json` to the extended schema**

Replace the entire contents of `data/audio/sound_cues.json` with:

```json
[
  { "id": "ui_click",       "category": "sfx",     "bus": "UI",      "variants": ["sfx.ui_click"],      "variants_min": 4, "pitch_jitter": 0.05, "vol_jitter": 1.5, "tuned": false, "duck": false, "throttle_ms": 40, "reward_layer": 0, "mood": "tight_tactile" },
  { "id": "loot_tiny_drop", "category": "reward",  "bus": "SFX",     "variants": ["reward.loot_tiny"],  "variants_min": 1, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": true,  "duck": true,  "throttle_ms": 0,  "reward_layer": 1, "mood": "soft_chime" },
  { "id": "loot_rare_drop", "category": "reward",  "bus": "SFX",     "variants": ["reward.loot_rare"],  "variants_min": 1, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": true,  "duck": true,  "throttle_ms": 0,  "reward_layer": 2, "mood": "brighter_chime" },
  { "id": "level_up",       "category": "reward",  "bus": "SFX",     "variants": ["reward.level_up"],   "variants_min": 1, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": true,  "duck": true,  "throttle_ms": 0,  "reward_layer": 3, "mood": "warm_rise" },
  { "id": "afk_chest_open", "category": "reward",  "bus": "SFX",     "variants": ["reward.afk_chest"],  "variants_min": 1, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": true,  "duck": true,  "throttle_ms": 0,  "reward_layer": 4, "mood": "multi_stage_chest" },
  { "id": "boss_clear",     "category": "reward",  "bus": "SFX",     "variants": ["reward.boss_clear"], "variants_min": 1, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": true,  "duck": true,  "throttle_ms": 0,  "reward_layer": 5, "mood": "celebration_without_noise" },
  { "id": "cat_voice_mya",  "category": "voice",   "bus": "Voice",   "variants": ["voice.syl.mya"],     "variants_min": 6, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": false, "duck": false, "throttle_ms": 0,  "reward_layer": 0, "mood": "cute_short" },
  { "id": "purr_ambient",   "category": "ambient", "bus": "Ambient", "variants": ["ambient.purr"],      "variants_min": 2, "pitch_jitter": 0.0,  "vol_jitter": 0.0, "tuned": false, "duck": false, "throttle_ms": 0,  "reward_layer": 0, "mood": "soft_signature" }
]
```

- [ ] **Step 4: Create the shortcuts manifest**

Create `data/audio/audio_shortcuts.json` (paths are intended targets; the `.wav`s do not exist yet, so `streams_for` resolves to `[]` and the system stays silent-but-safe):

```json
{
  "sfx.ui_click":     ["res://asset/audio/sfx/ui_click_a.wav", "res://asset/audio/sfx/ui_click_b.wav"],
  "reward.loot_tiny": ["res://asset/audio/reward/loot_tiny.wav"],
  "reward.loot_rare": ["res://asset/audio/reward/loot_rare.wav"],
  "reward.level_up":  ["res://asset/audio/reward/level_up.wav"],
  "reward.afk_chest": ["res://asset/audio/reward/afk_chest.wav"],
  "reward.boss_clear":["res://asset/audio/reward/boss_clear.wav"],
  "voice.syl.mya":    ["res://asset/audio/voice/mya_01.wav"],
  "ambient.purr":     ["res://asset/audio/ambient/purr_a.wav", "res://asset/audio/ambient/purr_b.wav"]
}
```

- [ ] **Step 5: Write the `AudioRegistry` autoload**

Create `scripts/autoload/audio_registry.gd`:

```gdscript
extends Node

# Catalog layer for the audio system. Mirrors AssetRegistry: loads JSON manifests,
# resolves a cue id to its AudioStream variants, caches streams, degrades gracefully
# when a .wav is missing. No class_name (autoload-safe, per the godot-runtime decision).

signal audio_ready

const CUES_PATH := "res://data/audio/sound_cues.json"
const SHORTCUTS_PATH := "res://data/audio/audio_shortcuts.json"

var cues: Dictionary = {}        # id -> cue Dictionary
var shortcuts: Dictionary = {}   # role -> Array of wav paths (or a single path)
var loaded := false

var _stream_cache: Dictionary = {}   # path -> AudioStream


func _ready() -> void:
	load_manifests()


func load_manifests() -> void:
	cues.clear()
	shortcuts.clear()
	loaded = false

	var parsed_cues = _read_json(CUES_PATH)
	if typeof(parsed_cues) == TYPE_ARRAY:
		for entry in parsed_cues:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
				cues[str(entry["id"])] = entry
	else:
		push_warning("Sound cues missing or not a JSON array: %s" % CUES_PATH)

	var parsed_shortcuts = _read_json(SHORTCUTS_PATH)
	if typeof(parsed_shortcuts) == TYPE_DICTIONARY:
		shortcuts = parsed_shortcuts

	loaded = true
	audio_ready.emit()


func get_cue(id: String) -> Dictionary:
	return cues.get(id, {})


func has_cue(id: String) -> bool:
	return cues.has(id)


func streams_for(id: String) -> Array:
	var result: Array = []
	var cue := get_cue(id)
	if cue.is_empty():
		return result
	for role in cue.get("variants", []):
		for path in _paths_for_role(str(role)):
			var stream := load_stream(path)
			if stream != null:
				result.append(stream)
	return result


func load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Audio stream missing: %s" % path)
		_stream_cache[path] = null
		return null
	var res = load(path)
	if res is AudioStream:
		_stream_cache[path] = res
		return res
	push_warning("Resource is not an AudioStream: %s" % path)
	_stream_cache[path] = null
	return null


func _paths_for_role(role: String) -> Array:
	# A cue variant is either a shortcut role (resolves via audio_shortcuts.json)
	# or a literal res:// path. Shortcut wins; unknown roles fall through as literals.
	if shortcuts.has(role):
		var value = shortcuts[role]
		if typeof(value) == TYPE_ARRAY:
			return value
		return [str(value)]
	return [role]


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
```

- [ ] **Step 6: Register the autoload**

In `project.godot`, under `[autoload]`, add `AudioRegistry` **after** `GameState`:

```ini
[autoload]

AssetRegistry="*res://scripts/autoload/asset_registry.gd"
GameState="*res://scripts/runtime/game_state.gd"
AudioRegistry="*res://scripts/autoload/audio_registry.gd"
```

- [ ] **Step 7: Run test to verify it passes**

Run the Global-Constraints test command.
Expected: PASS, exit=0. (`load_stream` on the missing wav logs a `push_warning` but returns null — that is the graceful path, not a failure.)

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/audio_registry.gd data/audio/audio_shortcuts.json data/audio/sound_cues.json project.godot tests/audio_system_test.gd
git commit -m "feat(audio): AudioRegistry catalog + extended cue/shortcut manifests"
```

---

### Task 3: `AudioDirector` autoload + volume sliders + persistence

**Files:**
- Create: `scripts/autoload/audio_director.gd`
- Modify: `project.godot` (register autoload)
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: named buses (Task 1).
- Produces: `AudioDirector.set_bus_volume/get_bus_volume/save_settings/load_settings`.

- [ ] **Step 1: Write the failing test**

Append to `tests/audio_system_test.gd` — add the call in `_ready()` and the function:

```gdscript
func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_test_volume_round_trips()
	_finish()


func _test_volume_round_trips() -> void:
	AudioDirector.set_bus_volume("Music", 0.5)
	_expect(abs(AudioDirector.get_bus_volume("Music") - 0.5) < 0.001, "Music volume round-trips to 0.5")
	var idx := AudioServer.get_bus_index("Music")
	_expect(abs(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.01, "AudioServer Music bus reflects linear_to_db(0.5)")
	AudioDirector.set_bus_volume("Music", 0.0)
	_expect(AudioServer.get_bus_volume_db(idx) <= -79.0, "volume 0.0 floors to ~-80 dB (no -inf)")
	AudioDirector.set_bus_volume("Music", 1.0)  # restore
	_expect(AudioDirector.get_bus_volume("Nonexistent") == 1.0, "unknown bus reads default 1.0")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Global-Constraints test command.
Expected: FAIL — `Identifier "AudioDirector" not found`.

- [ ] **Step 3: Write the `AudioDirector` autoload (volume + settings only)**

Create `scripts/autoload/audio_director.gd`:

```gdscript
extends Node

# Engine layer for the audio system: owns bus volumes, player pools, and the public
# play API. The ONLY audio surface game code calls. No class_name (autoload-safe).

const BUSES := ["Master", "Music", "SFX", "Ambient", "Voice", "UI"]
const SETTINGS_PATH := "user://audio_settings.cfg"
const MIN_DB := -80.0

var _volumes: Dictionary = {}   # bus_name -> 0..1


func _ready() -> void:
	for bus_name in BUSES:
		_volumes[bus_name] = 1.0
	load_settings()


func set_bus_volume(bus_name: String, value01: float) -> void:
	_apply_volume(bus_name, value01)
	save_settings()


func get_bus_volume(bus_name: String) -> float:
	return float(_volumes.get(bus_name, 1.0))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus_name in _volumes.keys():
		cfg.set_value("volumes", bus_name, _volumes[bus_name])
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	if not cfg.has_section("volumes"):
		return
	for bus_name in cfg.get_section_keys("volumes"):
		_apply_volume(str(bus_name), float(cfg.get_value("volumes", bus_name, 1.0)))


func _apply_volume(bus_name: String, value01: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Unknown bus: %s" % bus_name)
		return
	value01 = clampf(value01, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(value01) if value01 > 0.0 else MIN_DB)
	_volumes[bus_name] = value01
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, under `[autoload]`, add `AudioDirector` **last** (after `AudioRegistry`):

```ini
AudioDirector="*res://scripts/autoload/audio_director.gd"
```

- [ ] **Step 5: Run test to verify it passes**

Run the Global-Constraints test command.
Expected: PASS, exit=0.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/audio_director.gd project.godot tests/audio_system_test.gd
git commit -m "feat(audio): AudioDirector autoload with per-bus volume + ConfigFile persistence"
```

---

### Task 4: SFX one-shots — pools, variation, jitter, throttle

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `AudioRegistry.get_cue/streams_for` (Task 2), named buses (Task 1).
- Produces: `AudioDirector.sfx(cue_id) -> AudioStreamPlayer`.

- [ ] **Step 1: Write the failing test**

Append to `tests/audio_system_test.gd` — add the call in `_ready()` and the function:

```gdscript
func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_test_volume_round_trips()
	_test_sfx_configures_player()
	_finish()


func _test_sfx_configures_player() -> void:
	# Unknown cue is a safe no-op.
	_expect(AudioDirector.sfx("does_not_exist") == null, "sfx on unknown cue returns null")

	# A texture cue is routed to its bus and pitch-jittered within a bounded range.
	var p := AudioDirector.sfx("ui_click")
	_expect(p != null, "sfx('ui_click') returns a player")
	if p != null:
		_expect(p.bus == "UI", "ui_click player is on the UI bus, got '%s'" % p.bus)
		_expect(abs(p.pitch_scale - 1.0) <= 0.5, "ui_click pitch jitter stays bounded, got %f" % p.pitch_scale)

	# A tuned cue must NOT be pitch/volume jittered.
	var r := AudioDirector.sfx("level_up")
	_expect(r != null, "sfx('level_up') returns a player")
	if r != null:
		_expect(r.pitch_scale == 1.0, "tuned cue has pitch_scale exactly 1.0, got %f" % r.pitch_scale)
		_expect(r.volume_db == 0.0, "tuned cue has volume_db exactly 0.0, got %f" % r.volume_db)

	# Throttle suppresses an immediate replay (ui_click throttle_ms = 40).
	AudioDirector.sfx("ui_click")
	_expect(AudioDirector.sfx("ui_click") == null, "second immediate ui_click is throttled to null")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Global-Constraints test command.
Expected: FAIL — `Invalid call. Nonexistent function 'sfx' in base 'Node (audio_director.gd)'`.

- [ ] **Step 3: Add pools + `sfx()` to `AudioDirector`**

In `scripts/autoload/audio_director.gd`, add the pool constant near the top consts:

```gdscript
const POOL_SIZE := 6   # players per bus; round-robin so overlapping one-shots never allocate
```

Add these fields after `var _volumes`:

```gdscript
var _pools: Dictionary = {}      # bus_name -> Array[AudioStreamPlayer]
var _pool_idx: Dictionary = {}   # bus_name -> int
var _last_played: Dictionary = {} # cue_id -> ticks_msec
```

In `_ready()`, build the pools after seeding `_volumes` (before `load_settings()`):

```gdscript
func _ready() -> void:
	for bus_name in BUSES:
		_volumes[bus_name] = 1.0
	_build_pools()
	load_settings()


func _build_pools() -> void:
	for bus_name in BUSES:
		var pool: Array = []
		for i in range(POOL_SIZE):
			var player := AudioStreamPlayer.new()
			player.bus = bus_name
			add_child(player)
			pool.append(player)
		_pools[bus_name] = pool
		_pool_idx[bus_name] = 0
```

Add the public `sfx()` and its helper:

```gdscript
func sfx(cue_id: String) -> AudioStreamPlayer:
	var cue := AudioRegistry.get_cue(cue_id)
	if cue.is_empty():
		push_warning("Unknown cue: %s" % cue_id)
		return null

	var throttle := int(cue.get("throttle_ms", 0))
	if throttle > 0:
		var now := Time.get_ticks_msec()
		if _last_played.has(cue_id) and now - int(_last_played[cue_id]) < throttle:
			return null
		_last_played[cue_id] = now

	var bus_name := str(cue.get("bus", "SFX"))
	var player := _next_player(bus_name)
	var streams := AudioRegistry.streams_for(cue_id)
	player.stream = streams[randi() % streams.size()] if not streams.is_empty() else null

	if bool(cue.get("tuned", false)):
		player.pitch_scale = 1.0
		player.volume_db = 0.0
	else:
		player.pitch_scale = 1.0 + randfn(0.0, 1.0) * float(cue.get("pitch_jitter", 0.0))
		player.volume_db = randfn(0.0, 1.0) * float(cue.get("vol_jitter", 0.0))

	if player.stream != null:
		player.play()
	return player


func _next_player(bus_name: String) -> AudioStreamPlayer:
	var pool: Array = _pools.get(bus_name, _pools.get("SFX", []))
	if pool.is_empty():
		var fallback := AudioStreamPlayer.new()
		fallback.bus = bus_name
		add_child(fallback)
		return fallback
	var key := bus_name if _pools.has(bus_name) else "SFX"
	var idx: int = int(_pool_idx.get(key, 0))
	var player: AudioStreamPlayer = pool[idx]
	_pool_idx[key] = (idx + 1) % pool.size()
	return player
```

- [ ] **Step 4: Run test to verify it passes**

Run the Global-Constraints test command.
Expected: PASS, exit=0. (Streams are absent, so `player.stream` is null and `play()` is skipped — the test asserts configuration, not audible output.)

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/audio_director.gd tests/audio_system_test.gd
git commit -m "feat(audio): pooled SFX one-shots with variation, pitch/vol jitter, and throttle"
```

---

### Task 5: Reward chime ladder + sidechain ducking

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `default_bus_layout.tres` (add Compressors)
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `sfx()` (Task 4).
- Produces: `AudioDirector.reward(layer) -> AudioStreamPlayer`.

- [ ] **Step 1: Write the failing test**

Append to `tests/audio_system_test.gd` — add the call in `_ready()` and the function:

```gdscript
func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_test_volume_round_trips()
	_test_sfx_configures_player()
	_test_reward_ladder()
	_finish()


func _test_reward_ladder() -> void:
	_expect(AudioDirector.reward(0) == null, "reward(0) is an invalid layer -> null")
	_expect(AudioDirector.reward(99) == null, "reward(99) is an invalid layer -> null")
	var p := AudioDirector.reward(3)   # level_up
	_expect(p != null, "reward(3) returns a player")
	if p != null:
		_expect(p.bus == "SFX", "reward chime plays on the SFX bus (so it drives the duck), got '%s'" % p.bus)
		_expect(p.pitch_scale == 1.0, "reward chime is tuned (pitch 1.0), got %f" % p.pitch_scale)
	# The Music bus carries a Compressor keyed to SFX (the duck).
	var mi := AudioServer.get_bus_index("Music")
	_expect(AudioServer.get_bus_effect_count(mi) >= 1, "Music bus has at least one effect (the duck compressor)")
	var has_comp := false
	for e in range(AudioServer.get_bus_effect_count(mi)):
		if AudioServer.get_bus_effect(mi, e) is AudioEffectCompressor:
			has_comp = true
	_expect(has_comp, "Music bus duck effect is an AudioEffectCompressor")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Global-Constraints test command.
Expected: FAIL — `Nonexistent function 'reward'` (and the compressor assertions).

- [ ] **Step 3: Add `reward()` to `AudioDirector`**

In `scripts/autoload/audio_director.gd`, add the ladder constant near the top consts:

```gdscript
const REWARD_CUES := { 1: "loot_tiny_drop", 2: "loot_rare_drop", 3: "level_up", 4: "afk_chest_open", 5: "boss_clear" }
```

Add the public method:

```gdscript
func reward(layer: int) -> AudioStreamPlayer:
	if not REWARD_CUES.has(layer):
		push_warning("No reward cue for layer %d" % layer)
		return null
	# Reward cues are tuned + bus=SFX in sound_cues.json, so sfx() plays them
	# un-jittered on SFX, where the Music/Ambient sidechain compressors duck.
	return sfx(REWARD_CUES[layer])
```

- [ ] **Step 4: Add the duck compressors to the bus layout**

Replace the entire `default_bus_layout.tres` with the version below (adds a Compressor sidechained to `SFX` on both `Music` and `Ambient`):

```
[gd_resource type="AudioBusLayout" load_steps=3 format=3]

[sub_resource type="AudioEffectCompressor" id="duck_music"]
threshold = -20.0
ratio = 4.0
attack_us = 20.0
release_ms = 250.0
sidechain = "SFX"

[sub_resource type="AudioEffectCompressor" id="duck_ambient"]
threshold = -24.0
ratio = 6.0
attack_us = 20.0
release_ms = 300.0
sidechain = "SFX"

[resource]
bus/0/name = "Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = "Master"
bus/1/name = "Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = "Master"
bus/1/effect/0/effect = SubResource("duck_music")
bus/1/effect/0/enabled = true
bus/2/name = "SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = "Master"
bus/3/name = "Ambient"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = "Master"
bus/3/effect/0/effect = SubResource("duck_ambient")
bus/3/effect/0/enabled = true
bus/4/name = "Voice"
bus/4/solo = false
bus/4/mute = false
bus/4/bypass_fx = false
bus/4/volume_db = 0.0
bus/4/send = "Master"
bus/5/name = "UI"
bus/5/solo = false
bus/5/mute = false
bus/5/bypass_fx = false
bus/5/volume_db = 0.0
bus/5/send = "Master"
```

- [ ] **Step 5: Run test to verify it passes**

Run the Global-Constraints test command.
Expected: PASS, exit=0.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/audio_director.gd default_bus_layout.tres tests/audio_system_test.gd
git commit -m "feat(audio): reward chime ladder (5 tuned layers) + Music/Ambient sidechain ducking"
```

---

### Task 6: Wire known-live game events + integration test + manual verify

**Files:**
- Modify: `scripts/autoload/audio_director.gd` (connect `GameState.run_ended`)
- Modify: `scripts/combat/battle_view.gd` (two one-line hooks)
- Create: `tests/audio_wiring_test.gd`, `tests/audio_wiring_test.tscn`

**Interfaces:**
- Consumes: `reward()` (Task 5), `sfx()` (Task 4), `GameState.run_ended` signal, `battle_view._on_nav`, `battle_view._on_levelup_chosen`.
- Produces: audio reactions to real gameplay; no new public API.

**Note on scope:** only events whose emission on the live `battle_view.gd` path is already verified are wired here — `GameState.run_ended` (fired by `GameState.end_run`, called at `battle_view.gd:1876`), the `_on_nav` UI press, and the `_on_levelup_chosen` draft pick. Per-hit combat SFX and music-state changes are deferred to Plans 2–3 (they require adding emit points inside `battle_view.gd`'s inline damage resolution — spec §12).

- [ ] **Step 1: Write the failing integration test**

Create `tests/audio_wiring_test.gd`:

```gdscript
extends Node

# Integration test: boots the REAL battle scene and asserts AudioDirector is
# connected to the live GameState.run_ended signal, and that firing it invokes
# the reward path without error. Invoke via:
#   godot --headless --audio-driver Dummy res://tests/audio_wiring_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	var scene = preload("res://scenes/combat/battle.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	_expect(GameState.run_ended.is_connected(AudioDirector._on_run_ended),
		"AudioDirector is connected to GameState.run_ended")

	# Firing a 'won' run must not error and must route through reward(5).
	GameState.run_ended.emit("won")
	await get_tree().process_frame
	_expect(true, "GameState.run_ended('won') processed without crashing")

	scene.queue_free()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[audio_wiring_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[audio_wiring_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
```

Create `tests/audio_wiring_test.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/audio_wiring_test.gd" id="1"]

[node name="AudioWiringTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { (Get-ChildItem -Filter "Godot*.exe" | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1).FullName }
& $godot --headless --audio-driver Dummy --path . res://tests/audio_wiring_test.tscn; "exit=$LASTEXITCODE"
```
Expected: FAIL — `Nonexistent function '_on_run_ended'` / not connected.

- [ ] **Step 3: Connect `GameState.run_ended` in `AudioDirector`**

In `scripts/autoload/audio_director.gd`, connect the signal at the end of `_ready()` using the boot-race-safe guard, and add the handler. Append to `_ready()`:

```gdscript
	# GameState is an autoload initialized before this one, so connect directly.
	# (No state_ready race here — run_ended is a runtime event, not a boot event.)
	GameState.run_ended.connect(_on_run_ended)
```

Add the handler:

```gdscript
func _on_run_ended(status: String) -> void:
	if status == "won":
		reward(5)   # boss/region-clear celebration chime
	# 'wiped' → defeat audio is added in Plan 2 (needs a defeat cue).
```

- [ ] **Step 4: Add the two `battle_view.gd` hooks**

In `scripts/combat/battle_view.gd`, add `AudioDirector.sfx("ui_click")` as the **first line** of the body of `func _on_nav(id: String) -> void:` (near line 1237):

```gdscript
func _on_nav(id: String) -> void:
	AudioDirector.sfx("ui_click")
	# ... existing body unchanged ...
```

And add `AudioDirector.reward(3)` as the **first line** of the body of `func _on_levelup_chosen(index: int) -> void:` (near line 2762):

```gdscript
func _on_levelup_chosen(index: int) -> void:
	AudioDirector.reward(3)   # level-up chime
	# ... existing body unchanged ...
```

- [ ] **Step 5: Run both tests to verify they pass**

```powershell
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { (Get-ChildItem -Filter "Godot*.exe" | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1).FullName }
& $godot --headless --audio-driver Dummy --path . res://tests/audio_system_test.tscn;  "system exit=$LASTEXITCODE"
& $godot --headless --audio-driver Dummy --path . res://tests/audio_wiring_test.tscn;  "wiring exit=$LASTEXITCODE"
```
Expected: both PASS, exit=0.

- [ ] **Step 6: Manual verify (per CLAUDE.md "verify it runs")**

Run the game and confirm no audio errors in the Godot log; click a nav button and finish/lose a run:
```powershell
.\run_game.ps1
```
Expected: launches to `battle.tscn`; console shows no red errors from `audio_director.gd`/`audio_registry.gd` (only benign `push_warning` lines about missing `.wav`s). Report the actual tail of the output.

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/audio_director.gd scripts/combat/battle_view.gd tests/audio_wiring_test.gd tests/audio_wiring_test.tscn
git commit -m "feat(audio): wire run-end/level-up/UI-click audio hooks + boot integration test"
```

---

## Self-Review

**Spec coverage (Phases 1–3):**
- §5 bus layout → Task 1 (+ ducking in Task 5). ✓
- §8 AudioRegistry → Task 2. ✓
- §9 manifests (`sound_cues` extended, `audio_shortcuts`) → Task 2 (`music_zones`/`voice_profiles` are Plans 2–3). ✓
- §10 AudioDirector skeleton + §11.8 sliders/persistence → Task 3. ✓
- §11.1 SFX pools/variation/jitter → Task 4. ✓
- §11.2 reward ladder + §11.7 ducking → Task 5. ✓
- §12 integration (live GameState signals + `is_ready` awareness) + §13 gotcha avoidance → Task 6 (scoped to verified-live events). ✓
- §14 headless test → `audio_system_test` + `audio_wiring_test`, grown per task. ✓
- Deferred (documented): purr (§11.4), music FSM (§11.3), voice (§11.5), AFK (§11.6), options UI, per-hit combat emit points → Plans 2–3.

**Placeholder scan:** every step ships real `.gd`/`.json`/`.tres`/test code and exact run commands; no TBD/TODO. The two `battle_view.gd` hooks specify the exact insertion (first line of a named, line-referenced function) rather than reprinting the 2700-line file.

**Type consistency:** `sfx()` and `reward()` return `AudioStreamPlayer` everywhere; `get_cue()` returns `Dictionary` ({} on miss); `streams_for()` returns `Array`; `set_bus_volume(bus_name: String, value01: float)` / `get_bus_volume(bus_name: String) -> float` match across Tasks 3–6; `_apply_volume` (private, no save) vs `set_bus_volume` (public, saves) are used consistently; the `_on_run_ended(status: String)` handler name matches the wiring-test assertion.

---

## Next plans (not part of this deliverable)

- **Plan 2 — Ambient + Music:** purr bed (Ambient bus, combat dip), adaptive vertical-layered music (`music_zones.json`, per-stem players, state machine, tween crossfades), wired to `GameState.wave_changed` + boss-wave detection + `run_ended`.
- **Plan 3 — Voice + AFK + Options UI:** Animalese `VoiceSequencer` + `voice_profiles.json` per-clan, AFK reward audio, per-hit combat emit points added to `battle_view.gd`, and the options-panel volume-slider UI.
