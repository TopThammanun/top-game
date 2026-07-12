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
