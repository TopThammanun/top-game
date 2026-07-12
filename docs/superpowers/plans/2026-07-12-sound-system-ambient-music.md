# Sound System — Ambient + Music (Plan 2 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two ambient/music subsystems on top of the Plan 1 foundation — a purr ambient bed and adaptive vertical-layered music with a state machine — wired to the live `GameState` wave/run signals.

**Architecture:** Extends the existing `AudioRegistry` (add `music_zones.json` + `get_zone`) and `AudioDirector` (add `play_zone` / `set_music_state` / `purr` + boot wiring). Music is one persistent `AudioStreamPlayer` per stem on the Music bus, all playing in sync; a state matrix tweens per-stem volumes (no track swaps). Everything degrades gracefully with zero `.ogg`/`.wav` assets present (stems load null, `play()` is skipped, target volumes are still computed and asserted). Full design: `docs/superpowers/specs/2026-07-12-sound-system-design.md` §11.3 (music), §11.4 (purr), §12 (boot seam).

**Tech Stack:** Godot 4.7 (GDScript), `AudioStreamPlayer` + `Tween` + `AudioServer`, headless `.tscn` tests.

**Scope of this plan (Phases 4–5 of the spec).** Deferred to Plan 3: Animalese cat voice, offline/AFK reward audio, per-hit combat emit points in `battle_view.gd`, and the options-panel volume-slider UI.

## Global Constraints

- **Godot 4.2 APIs only** (binary is 4.7). `AudioStreamPlayer`, `Tween` (`create_tween`/`tween_property`), `linear_to_db`, `clampf`, `AudioServer`.
- **No `class_name`** on `audio_director.gd` / `audio_registry.gd` (autoload-safe rule).
- **Music stems live on the `Music` bus; the purr bed on the `Ambient` bus.** Never `Master`.
- **Graceful degradation.** Missing stem/purr asset → `push_warning` + skip `play()`, never crash. This plan ships and tests green with NO audio assets.
- **No track swaps — only per-stem volume crossfades** (spec §11.3). All stems share the zone's bpm/key/loop length.
- **`set_music_state` must expose a synchronous test seam** (`_stem_targets`) — do not force tests to await 1.5 s tweens.
- **Boot uses the `GameState.is_ready` guard** (spec §12) — `state_ready` may fire before `AudioDirector._ready`, so guard: `if not GameState.is_ready: state_ready.connect(_boot_audio, CONNECT_ONE_SHOT) else: _boot_audio()`.
- **Test invocation** (PowerShell/Bash), used verbatim in every task. NOTE the Godot exe is NESTED inside a directory named `Godot_v4.7-stable_win64.exe`; use the CONSOLE exe:
  ```
  ./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --audio-driver Dummy --path . res://tests/audio_system_test.tscn ; echo "exit=$?"
  ```
  PASS prints `[audio_system_test] PASS`, exit 0. The plain GUI exe detaches from the console in headless (no stdout/exit) — always use the console exe. A headless test that errors BEFORE `get_tree().quit()` (the RED phase) HANGS — run in the foreground, treat the hang as the RED signal.

## Current state (post Plan 1, HEAD dacd9bb — do NOT re-implement)

- `scripts/autoload/audio_registry.gd` — `cues`/`shortcuts`/`loaded`/`_stream_cache`; `get_cue`/`has_cue`/`streams_for`/`load_stream`/`load_manifests`/`_paths_for_role`/`_read_json`; `signal audio_ready`; consts `CUES_PATH`/`SHORTCUTS_PATH`.
- `scripts/autoload/audio_director.gd` — consts `BUSES`/`SETTINGS_PATH`/`MIN_DB`/`POOL_SIZE`/`REWARD_CUES`; fields `_volumes`/`_pools`/`_pool_idx`/`_last_played`; `_ready` (seeds volumes, `_build_pools`, `load_settings`, connects `GameState.run_ended`); `set_bus_volume`/`get_bus_volume`/`save_settings`/`load_settings`/`_apply_volume`/`_build_pools`/`sfx`/`reward`/`_on_run_ended`/`_next_player`.
- `data/audio/sound_cues.json` has a `purr_ambient` cue (bus `Ambient`, variants `["ambient.purr"]`); `data/audio/audio_shortcuts.json` maps `ambient.purr` → two purr wavs (missing on disk = fine).
- `tests/audio_system_test.gd` grows across tasks; `tests/audio_wiring_test.gd` boots `scenes/combat/battle.tscn`.
- The 6 buses + the Ambient/Music sidechain compressors already exist in `default_bus_layout.tres`.

**Interfaces produced by this plan (relied on by Plan 3 / the game):**

```gdscript
# AudioRegistry
func get_zone(zone_id: String) -> Dictionary          # {} if unknown

# AudioDirector
func play_zone(zone_id: String) -> void               # build per-stem Music players (silent), play in sync
func set_music_state(state: String) -> void           # tween stems to the zone's state matrix
func purr(on: bool) -> void                            # start/stop the Ambient purr bed
# plus internal _boot_audio(), _on_wave_changed(wave), _clear_music()
```

---

## File Structure

- Create `data/audio/music_zones.json` — per-zone stems + state→stem-volume matrix.
- Modify `scripts/autoload/audio_registry.gd` — add `ZONES_PATH`/`zones`/`get_zone`, load in `load_manifests`.
- Modify `scripts/autoload/audio_director.gd` — add music + purr subsystems + boot/wave wiring.
- Modify `tests/audio_system_test.gd` — unit tests for zone/play_zone/state/purr (Tasks 1–4).
- Modify `tests/audio_wiring_test.gd` — boot + wave-state integration (Task 6).

---

### Task 1: `music_zones.json` + `AudioRegistry.get_zone()`

**Files:**
- Create: `data/audio/music_zones.json`
- Modify: `scripts/autoload/audio_registry.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Produces: `AudioRegistry.get_zone(zone_id) -> Dictionary`, `var zones`, `const ZONES_PATH`.

- [ ] **Step 1: Write the failing test** — append the call in `_ready()` and the function to `tests/audio_system_test.gd`:

```gdscript
func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_test_volume_round_trips()
	_test_sfx_configures_player()
	_test_reward_ladder()
	_test_music_zone_loads()
	_finish()


func _test_music_zone_loads() -> void:
	var zone := AudioRegistry.get_zone("emberhearth")
	_expect(not zone.is_empty(), "zone 'emberhearth' is known")
	_expect(zone.has("stems") and zone.has("states"), "zone has stems + states")
	_expect(zone.get("states", {}).has("idle"), "zone has an 'idle' state")
	_expect(AudioRegistry.get_zone("nope").is_empty(), "unknown zone returns an empty Dictionary")
```

- [ ] **Step 2: Run test to verify it fails** — run the Global-Constraints test command. Expected: FAIL — `Nonexistent function 'get_zone'`.

- [ ] **Step 3: Create `data/audio/music_zones.json`:**

```json
{
  "emberhearth": {
    "bpm": 84,
    "key": "D_dorian",
    "loop_len_s": 72,
    "stems": {
      "ambient_bed": "res://asset/audio/music/ember_ambient.ogg",
      "warm_chords": "res://asset/audio/music/ember_chords.ogg",
      "melody": "res://asset/audio/music/ember_melody.ogg",
      "soft_percussion": "res://asset/audio/music/ember_perc.ogg",
      "tension": "res://asset/audio/music/ember_tension.ogg"
    },
    "states": {
      "idle":            {"ambient_bed": 1.0, "warm_chords": 0.7, "melody": 0.5, "soft_percussion": 0.0, "tension": 0.0},
      "wave_pressure":   {"ambient_bed": 1.0, "warm_chords": 0.9, "melody": 0.7, "soft_percussion": 0.8, "tension": 0.3},
      "boss":            {"ambient_bed": 0.8, "warm_chords": 1.0, "melody": 0.9, "soft_percussion": 1.0, "tension": 1.0},
      "reward":          {"ambient_bed": 1.0, "warm_chords": 1.0, "melody": 1.0, "soft_percussion": 0.6, "tension": 0.0},
      "region_restored": {"ambient_bed": 1.0, "warm_chords": 1.0, "melody": 1.0, "soft_percussion": 0.7, "tension": 0.0}
    }
  }
}
```

- [ ] **Step 4: Extend `AudioRegistry`.** In `scripts/autoload/audio_registry.gd`:

Add the const after `SHORTCUTS_PATH`:
```gdscript
const ZONES_PATH := "res://data/audio/music_zones.json"
```
Add the field after `var shortcuts`:
```gdscript
var zones: Dictionary = {}       # zone_id -> zone Dictionary
```
In `load_manifests()`, add `zones.clear()` to the top clear block (with `cues.clear()`/`shortcuts.clear()`), and after the shortcuts-parse block add:
```gdscript
	var parsed_zones = _read_json(ZONES_PATH)
	if typeof(parsed_zones) == TYPE_DICTIONARY:
		zones = parsed_zones
```
Add the method (next to `get_cue`):
```gdscript
func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})
```

- [ ] **Step 5: Run test to verify it passes** — Global-Constraints test command. Expected: PASS, exit 0.

- [ ] **Step 6: Commit**
```bash
git add data/audio/music_zones.json scripts/autoload/audio_registry.gd tests/audio_system_test.gd
git commit -m "feat(audio): music_zones manifest + AudioRegistry.get_zone()"
```

---

### Task 2: `play_zone()` — per-stem Music players

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `AudioRegistry.get_zone` (Task 1), `AudioRegistry.load_stream`.
- Produces: `AudioDirector.play_zone(zone_id) -> void`, `_music_players`, `_current_zone`, `_clear_music()`.

- [ ] **Step 1: Write the failing test** — append the call in `_ready()` and the function to `tests/audio_system_test.gd`:

```gdscript
func _test_play_zone_builds_stems() -> void:
	AudioDirector.play_zone("emberhearth")
	_expect(AudioDirector._current_zone == "emberhearth", "current zone set to emberhearth")
	_expect(AudioDirector._music_players.size() == 5, "5 stem players built, got %d" % AudioDirector._music_players.size())
	for stem_name in AudioDirector._music_players.keys():
		var p: AudioStreamPlayer = AudioDirector._music_players[stem_name]
		_expect(p.bus == "Music", "stem '%s' is on the Music bus, got '%s'" % [stem_name, p.bus])
	# Rebuild is idempotent (no duplicate players):
	AudioDirector.play_zone("emberhearth")
	_expect(AudioDirector._music_players.size() == 5, "replaying the zone keeps 5 players, not 10")
	# Unknown zone is a safe no-op that does not disturb the current zone:
	AudioDirector.play_zone("does_not_exist")
	_expect(AudioDirector._current_zone == "emberhearth", "unknown zone is a no-op; current zone unchanged")
```

Wire it into `_ready()` after `_test_music_zone_loads()`:
```gdscript
	_test_play_zone_builds_stems()
```

- [ ] **Step 2: Run test to verify it fails** — Global-Constraints command. Expected: FAIL — `Nonexistent function 'play_zone'`.

- [ ] **Step 3: Add music consts + fields + `play_zone`/`_clear_music`.** In `scripts/autoload/audio_director.gd`:

Add consts after `REWARD_CUES`:
```gdscript
const DEFAULT_ZONE := "emberhearth"
const MUSIC_FADE_S := 1.5
const BOSS_EVERY := 5
```
Add fields after `var _last_played`:
```gdscript
var _music_players: Dictionary = {}   # stem_name -> AudioStreamPlayer (Music bus)
var _stem_tweens: Dictionary = {}      # stem_name -> Tween
var _stem_targets: Dictionary = {}     # stem_name -> target linear 0..1 (synchronous test seam)
var _current_zone: String = ""
var _music_state: String = ""
```
Add the methods (below `reward()`):
```gdscript
func play_zone(zone_id: String) -> void:
	var zone := AudioRegistry.get_zone(zone_id)
	if zone.is_empty():
		push_warning("Unknown music zone: %s" % zone_id)
		return
	_clear_music()
	var stems: Dictionary = zone.get("stems", {})
	for stem_name in stems.keys():
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = MIN_DB   # start silent; set_music_state fades stems up
		var stream := AudioRegistry.load_stream(str(stems[stem_name]))
		player.stream = stream
		add_child(player)
		if stream != null:
			player.play()
		_music_players[str(stem_name)] = player
	_current_zone = zone_id
	_music_state = ""


func _clear_music() -> void:
	for stem_name in _music_players.keys():
		var t = _stem_tweens.get(stem_name, null)
		if t != null and t.is_valid():
			t.kill()
		var p: AudioStreamPlayer = _music_players[stem_name]
		if is_instance_valid(p):
			p.queue_free()
	_music_players.clear()
	_stem_tweens.clear()
	_stem_targets.clear()
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS, exit 0. (Stems load null — no `.ogg` yet — so `play()` is skipped; the test asserts player construction + bus, not audio.)

- [ ] **Step 5: Commit**
```bash
git add scripts/autoload/audio_director.gd tests/audio_system_test.gd
git commit -m "feat(audio): play_zone builds per-stem Music players (synced, silent until faded)"
```

---

### Task 3: `set_music_state()` — vertical-layering state matrix + crossfade

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `play_zone`/`_music_players`/`_stem_tweens` (Task 2), `AudioRegistry.get_zone`.
- Produces: `AudioDirector.set_music_state(state) -> void`, `_stem_targets`, `_music_state`.

- [ ] **Step 1: Write the failing test** — append the call in `_ready()` and the function:

```gdscript
func _test_music_state_matrix() -> void:
	AudioDirector.play_zone("emberhearth")
	AudioDirector.set_music_state("boss")
	_expect(AudioDirector._music_state == "boss", "music state set to boss")
	# boss matrix: ambient_bed 0.8, warm_chords 1.0, melody 0.9, soft_percussion 1.0, tension 1.0
	_expect(abs(float(AudioDirector._stem_targets.get("tension", -1)) - 1.0) < 0.001, "boss drives tension to 1.0")
	_expect(abs(float(AudioDirector._stem_targets.get("ambient_bed", -1)) - 0.8) < 0.001, "boss sets ambient_bed to 0.8")
	AudioDirector.set_music_state("idle")
	_expect(abs(float(AudioDirector._stem_targets.get("tension", -1)) - 0.0) < 0.001, "idle drives tension to 0.0")
	# invalid state is a no-op that keeps the last state
	AudioDirector.set_music_state("bogus")
	_expect(AudioDirector._music_state == "idle", "invalid state is a no-op; state stays 'idle'")
```
Wire into `_ready()` after `_test_play_zone_builds_stems()`:
```gdscript
	_test_music_state_matrix()
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `Nonexistent function 'set_music_state'`.

- [ ] **Step 3: Add `set_music_state`.** In `scripts/autoload/audio_director.gd`, below `_clear_music()`:

```gdscript
func set_music_state(state: String) -> void:
	if _current_zone == "":
		return
	var zone := AudioRegistry.get_zone(_current_zone)
	var states: Dictionary = zone.get("states", {})
	if not states.has(state):
		push_warning("Music zone '%s' has no state '%s'" % [_current_zone, state])
		return
	var targets: Dictionary = states[state]
	for stem_name in _music_players.keys():
		var target: float = clampf(float(targets.get(stem_name, 0.0)), 0.0, 1.0)
		_stem_targets[stem_name] = target
		var player: AudioStreamPlayer = _music_players[stem_name]
		var old_t = _stem_tweens.get(stem_name, null)
		if old_t != null and old_t.is_valid():
			old_t.kill()
		var tw := create_tween()
		tw.tween_property(player, "volume_db", (linear_to_db(target) if target > 0.0 else MIN_DB), MUSIC_FADE_S)
		_stem_tweens[stem_name] = tw
	_music_state = state
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS, exit 0. (`_stem_targets` is set synchronously; the 1.5 s tween runs but the test asserts the target seam, not the animated value.)

- [ ] **Step 5: Commit**
```bash
git add scripts/autoload/audio_director.gd tests/audio_system_test.gd
git commit -m "feat(audio): set_music_state tweens stems to the zone state matrix (vertical layering)"
```

---

### Task 4: Purr ambient bed — `purr()`

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `AudioRegistry.streams_for("purr_ambient")`.
- Produces: `AudioDirector.purr(on: bool) -> void`, `_purr_player`.

- [ ] **Step 1: Write the failing test** — append the call in `_ready()` and the function:

```gdscript
func _test_purr_bed() -> void:
	AudioDirector.purr(true)
	_expect(AudioDirector._purr_player != null, "purr(true) creates the purr player")
	if AudioDirector._purr_player != null:
		_expect(AudioDirector._purr_player.bus == "Ambient", "purr bed is on the Ambient bus, got '%s'" % AudioDirector._purr_player.bus)
		_expect(abs(AudioDirector._purr_player.volume_db - AudioDirector.PURR_DB) < 0.001, "purr(true) sets volume to PURR_DB")
	AudioDirector.purr(false)
	_expect(not AudioDirector._purr_player.playing, "purr(false) stops the bed")
```
Wire into `_ready()` after `_test_music_state_matrix()`:
```gdscript
	_test_purr_bed()
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `Nonexistent function 'purr'` (and `Invalid access ... 'PURR_DB'`).

- [ ] **Step 3: Add purr.** In `scripts/autoload/audio_director.gd`:

Add const after `BOSS_EVERY`:
```gdscript
const PURR_DB := -27.0   # low-volume signature bed; combat ducking handled by the Ambient sidechain compressor
```
Add field after `var _music_state`:
```gdscript
var _purr_player: AudioStreamPlayer = null
```
Add the method (below `set_music_state`):
```gdscript
func purr(on: bool) -> void:
	if _purr_player == null:
		_purr_player = AudioStreamPlayer.new()
		_purr_player.bus = "Ambient"
		add_child(_purr_player)
	if on:
		var streams := AudioRegistry.streams_for("purr_ambient")
		_purr_player.stream = streams[0] if not streams.is_empty() else null
		_purr_player.volume_db = PURR_DB
		if _purr_player.stream != null and not _purr_player.playing:
			_purr_player.play()
	else:
		_purr_player.stop()
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS, exit 0. (No purr `.wav` → stream null → `play()` skipped; the test asserts bus + volume + stop, not audio. Note: combat dip to ~-40 dB is handled by the existing Ambient sidechain compressor, not by `purr()`.)

- [ ] **Step 5: Commit**
```bash
git add scripts/autoload/audio_director.gd tests/audio_system_test.gd
git commit -m "feat(audio): purr ambient bed on the Ambient bus (combat dip via existing sidechain)"
```

---

### Task 5: Boot music+purr and wire `wave_changed` / `run_ended`

**Files:**
- Modify: `scripts/autoload/audio_director.gd`
- Modify: `tests/audio_system_test.gd`

**Interfaces:**
- Consumes: `play_zone`/`set_music_state`/`purr` (Tasks 2–4), `GameState.wave_changed`/`state_ready`/`is_ready`/`run_ended`.
- Produces: `_boot_audio()`, `_on_wave_changed(wave)`; extends `_on_run_ended`.

- [ ] **Step 1: Write the failing test** — append the call in `_ready()` and the function. This test drives the handlers directly (no game scene needed) after manually booting a zone:

```gdscript
func _test_wave_changed_drives_state() -> void:
	AudioDirector.play_zone("emberhearth")
	AudioDirector._on_wave_changed(3)
	_expect(AudioDirector._music_state == "wave_pressure", "non-boss wave -> wave_pressure, got '%s'" % AudioDirector._music_state)
	AudioDirector._on_wave_changed(5)   # BOSS_EVERY = 5
	_expect(AudioDirector._music_state == "boss", "wave 5 (boss) -> boss, got '%s'" % AudioDirector._music_state)
	AudioDirector._on_run_ended("won")
	_expect(AudioDirector._music_state == "region_restored", "run won -> region_restored, got '%s'" % AudioDirector._music_state)
```
Wire into `_ready()` after `_test_purr_bed()`:
```gdscript
	_test_wave_changed_drives_state()
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `Nonexistent function '_on_wave_changed'`.

- [ ] **Step 3: Add boot + wave handler; extend `_ready` and `_on_run_ended`.** In `scripts/autoload/audio_director.gd`:

Extend `_ready()` — after the existing `GameState.run_ended.connect(_on_run_ended)` line, add:
```gdscript
	GameState.wave_changed.connect(_on_wave_changed)
	# state_ready may fire before this autoload's _ready — guard it (spec §12).
	if not GameState.is_ready:
		GameState.state_ready.connect(_boot_audio, CONNECT_ONE_SHOT)
	else:
		_boot_audio()
```
Add the boot + wave handler (below `_on_run_ended`):
```gdscript
func _boot_audio() -> void:
	play_zone(DEFAULT_ZONE)
	set_music_state("idle")
	purr(true)


func _on_wave_changed(wave: int) -> void:
	if _current_zone == "":
		return   # music not booted yet
	set_music_state("boss" if wave % BOSS_EVERY == 0 else "wave_pressure")
```
Replace the existing `_on_run_ended` body with:
```gdscript
func _on_run_ended(status: String) -> void:
	if status == "won":
		reward(5)                          # boss/region-clear celebration chime
		set_music_state("region_restored")
	elif status == "wiped":
		set_music_state("idle")            # soften on defeat (a defeat cue is a later plan)
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS, exit 0. (In this bare test scene `_boot_audio` may run at autoload init or never — the test calls `play_zone` itself and drives the handlers directly, so it does not depend on boot timing.)

- [ ] **Step 5: Commit**
```bash
git add scripts/autoload/audio_director.gd tests/audio_system_test.gd
git commit -m "feat(audio): boot music+purr (is_ready guard) and drive music state from wave_changed/run_ended"
```

---

### Task 6: Boot integration test + regression + manual verify

**Files:**
- Modify: `tests/audio_wiring_test.gd`

**Interfaces:**
- Consumes: everything above; `GameState.wave_changed`.

- [ ] **Step 1: Extend the failing integration test.** In `tests/audio_wiring_test.gd`, after the existing `run_ended` assertions (before `scene.queue_free()`), add:

```gdscript
	# Music + purr booted when the real scene came up (via _boot_audio / is_ready guard):
	_expect(AudioDirector._current_zone == "emberhearth", "music zone booted to emberhearth, got '%s'" % AudioDirector._current_zone)
	_expect(AudioDirector._purr_player != null, "purr bed booted")
	_expect(GameState.wave_changed.is_connected(AudioDirector._on_wave_changed), "AudioDirector is connected to GameState.wave_changed")
	# A live wave change drives the music state machine:
	GameState.wave_changed.emit(5)
	await get_tree().process_frame
	_expect(AudioDirector._music_state == "boss", "wave_changed(5) drove music to boss, got '%s'" % AudioDirector._music_state)
```

- [ ] **Step 2: Run test to verify it fails** — run the wiring test:
```
./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --audio-driver Dummy --path . res://tests/audio_wiring_test.tscn ; echo "exit=$?"
```
Expected: FAIL — `AudioDirector._current_zone` is `""` if the code from Tasks 1–5 is not yet present; if you run this task after Task 5, the failure is instead a stale assertion — re-run after confirming Task 5 committed. (If Tasks 1–5 are in, this test should already have its dependencies; the RED here is the newly-added assertions before this step's edit is saved.)

- [ ] **Step 3: (No new production code — Tasks 1–5 already implement it.)** Confirm the wiring assertions pass.

- [ ] **Step 4: Run BOTH audio suites + the regression suite to GREEN:**
```
G=./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe
$G --headless --audio-driver Dummy --path . res://tests/audio_system_test.tscn ; echo "sys=$?"
$G --headless --audio-driver Dummy --path . res://tests/audio_wiring_test.tscn ; echo "wiring=$?"
$G --headless --audio-driver Dummy --path . res://tests/roguelike_loop_test.tscn ; echo "rogue=$?"
```
Expected: all three PASS, exit 0 (`roguelike_loop_test` boots `battle.tscn` and must still pass — regression guard for the new boot wiring).

- [ ] **Step 5: Manual verify (headless boot smoke — a GUI click isn't feasible for an autonomous agent; state this explicitly):**
```
./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/combat/battle.tscn --quit-after 200 ; echo "boot=$?"
```
Expected: boot exit 0; no red `ERROR`/`SCRIPT ERROR` from `audio_*.gd`; only benign missing-asset warnings. Report the actual tail.

- [ ] **Step 6: Commit**
```bash
git add tests/audio_wiring_test.gd
git commit -m "test(audio): integration coverage for music/purr boot + wave-driven music state"
```

---

## Self-Review

**Spec coverage (Phases 4–5):**
- §11.3 adaptive vertical layering + state machine → Tasks 2 (stems), 3 (state matrix + crossfade), 5 (wave/run drive states). ✓
- §11.4 purr ambient bed → Task 4 (bus, PURR_DB); combat dip via the existing Ambient sidechain (Plan 1 Task 5) — documented. ✓
- §9.3 `music_zones.json` → Task 1. ✓
- §8 `get_zone` → Task 1. ✓
- §12 boot seam (`is_ready` guard) → Task 5. ✓
- §14 testing → grows `audio_system_test` (Tasks 1–5) + `audio_wiring_test` (Task 6) + regression on `roguelike_loop_test`. ✓
- Deferred (documented): voice (§11.5), AFK (§11.6), per-hit combat emit points, options UI → Plan 3.

**Placeholder scan:** every step ships real `.json`/`.gd`/test code + exact commands. The one illustrative line in Task 2 Step 1 is explicitly corrected in the same step to the real two-line assertion.

**Type consistency:** `get_zone`/`_stem_targets`/`_music_players` are `Dictionary`; `play_zone`/`set_music_state`/`purr`/`_boot_audio`/`_on_wave_changed` return `void`; `_music_state`/`_current_zone` are `String`; `PURR_DB`/`MUSIC_FADE_S`/`MIN_DB` are floats; `BOSS_EVERY` int. `set_music_state` uses `_current_zone`/`_music_players`/`_stem_tweens` exactly as Task 2 defines them. `_on_wave_changed(wave: int)` matches the `GameState.wave_changed(wave: int)` signal signature.

---

## Next plan (not part of this deliverable)

- **Plan 3 — Voice + AFK + Options UI:** Animalese `VoiceSequencer` + `voice_profiles.json` per-clan (`AudioRegistry.get_voice`, `AudioDirector.voice`), offline/AFK reward audio, per-hit combat emit points added to `battle_view.gd`, and the options-panel volume-slider UI.
