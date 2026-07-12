extends Node

# Engine layer for the audio system: owns bus volumes, player pools, and the public
# play API. The ONLY audio surface game code calls. No class_name (autoload-safe).

const BUSES := ["Master", "Music", "SFX", "Ambient", "Voice", "UI"]
const SETTINGS_PATH := "user://audio_settings.cfg"
const MIN_DB := -80.0
const POOL_SIZE := 6   # players per bus; round-robin so overlapping one-shots never allocate
const REWARD_CUES := { 1: "loot_tiny_drop", 2: "loot_rare_drop", 3: "level_up", 4: "afk_chest_open", 5: "boss_clear" }
const DEFAULT_ZONE := "emberhearth"
const MUSIC_FADE_S := 1.5
const BOSS_EVERY := 5
const PURR_DB := -27.0   # low-volume signature bed; combat ducking handled by the Ambient sidechain compressor

var _volumes: Dictionary = {}   # bus_name -> 0..1
var _pools: Dictionary = {}      # bus_name -> Array[AudioStreamPlayer]
var _pool_idx: Dictionary = {}   # bus_name -> int
var _last_played: Dictionary = {} # cue_id -> ticks_msec
var _music_players: Dictionary = {}   # stem_name -> AudioStreamPlayer (Music bus)
var _stem_tweens: Dictionary = {}      # stem_name -> Tween
var _stem_targets: Dictionary = {}     # stem_name -> target linear 0..1 (synchronous test seam)
var _current_zone: String = ""
var _music_state: String = ""
var _purr_player: AudioStreamPlayer = null


func _ready() -> void:
	for bus_name in BUSES:
		_volumes[bus_name] = 1.0
	_build_pools()
	load_settings()
	# GameState is an autoload initialized before this one, so connect directly.
	# (No state_ready race here — run_ended is a runtime event, not a boot event.)
	GameState.run_ended.connect(_on_run_ended)


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


func reward(layer: int) -> AudioStreamPlayer:
	if not REWARD_CUES.has(layer):
		push_warning("No reward cue for layer %d" % layer)
		return null
	# Reward cues are tuned + bus=SFX in sound_cues.json, so sfx() plays them
	# un-jittered on SFX, where the Music/Ambient sidechain compressors duck.
	return sfx(REWARD_CUES[layer])


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


func _on_run_ended(status: String) -> void:
	if status == "won":
		reward(5)   # boss/region-clear celebration chime
	# 'wiped' → defeat audio is added in Plan 2 (needs a defeat cue).


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
