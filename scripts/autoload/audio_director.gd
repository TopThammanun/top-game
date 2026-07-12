extends Node

# Engine layer for the audio system: owns bus volumes, player pools, and the public
# play API. The ONLY audio surface game code calls. No class_name (autoload-safe).

const BUSES := ["Master", "Music", "SFX", "Ambient", "Voice", "UI"]
const SETTINGS_PATH := "user://audio_settings.cfg"
const MIN_DB := -80.0
const POOL_SIZE := 6   # players per bus; round-robin so overlapping one-shots never allocate

var _volumes: Dictionary = {}   # bus_name -> 0..1
var _pools: Dictionary = {}      # bus_name -> Array[AudioStreamPlayer]
var _pool_idx: Dictionary = {}   # bus_name -> int
var _last_played: Dictionary = {} # cue_id -> ticks_msec


func _ready() -> void:
	for bus_name in BUSES:
		_volumes[bus_name] = 1.0
	_build_pools()
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
