extends Node

# Catalog layer for the audio system. Mirrors AssetRegistry: loads JSON manifests,
# resolves a cue id to its AudioStream variants, caches streams, degrades gracefully
# when a .wav is missing. No class_name (autoload-safe, per the godot-runtime decision).

signal audio_ready

const CUES_PATH := "res://data/audio/sound_cues.json"
const SHORTCUTS_PATH := "res://data/audio/audio_shortcuts.json"
const ZONES_PATH := "res://data/audio/music_zones.json"

var cues: Dictionary = {}        # id -> cue Dictionary
var shortcuts: Dictionary = {}   # role -> Array of wav paths (or a single path)
var zones: Dictionary = {}       # zone_id -> zone Dictionary
var loaded := false

var _stream_cache: Dictionary = {}   # path -> AudioStream


func _ready() -> void:
	load_manifests()


func load_manifests() -> void:
	cues.clear()
	shortcuts.clear()
	zones.clear()
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

	var parsed_zones = _read_json(ZONES_PATH)
	if typeof(parsed_zones) == TYPE_DICTIONARY:
		zones = parsed_zones

	loaded = true
	audio_ready.emit()


func get_cue(id: String) -> Dictionary:
	return cues.get(id, {})


func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})


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
