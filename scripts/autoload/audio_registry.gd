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
# Dev fallback: when a real audio file is absent, synthesize a short placeholder tone
# so the fully-wired cue is still audible. Real assets always win (ResourceLoader.exists
# short-circuits this branch). Set false for true silence.
var use_placeholder_tones := true
# Background music/ambient beds are OFF by default — the placeholder drone was unpleasant.
# One-shot cues (clicks/chimes) still get placeholders; real music assets play regardless.
# Flip to true to also hear placeholder beds.
var use_placeholder_beds := false

const PLACEHOLDER_RATE := 22050

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
		var tone := _placeholder_for(path)
		if tone == null and not use_placeholder_tones:
			push_warning("Audio stream missing: %s" % path)
		_stream_cache[path] = tone
		return tone
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


# Decide whether a missing asset gets a placeholder tone. One-shots always do (when tones
# are on); music/ambient beds only when use_placeholder_beds is on (off by default so the
# background stays silent). Returns null for "stay silent".
func _placeholder_for(path: String) -> AudioStream:
	if not use_placeholder_tones:
		return null
	var is_bed := path.contains("/music/") or path.contains("/ambient/")
	if is_bed and not use_placeholder_beds:
		return null
	return _placeholder_stream(path)


# Synthesize a gentle sine-tone AudioStreamWAV as a stand-in for a missing asset, so the
# fully-wired cue is audible before real content lands. Bed paths (music/ambient) loop and
# sit an octave lower; one-shots are short blips. Pitch is derived from the path so each cue
# sounds distinct and the music stems layer into a chord-ish drone.
func _placeholder_stream(path: String) -> AudioStreamWAV:
	var is_bed := path.contains("/music/") or path.contains("/ambient/")
	var dur := 1.0 if is_bed else 0.14
	var freq := 220.0 * pow(2.0, float(int(abs(path.hash())) % 12) / 12.0)
	if is_bed:
		freq *= 0.5
	var n := int(PLACEHOLDER_RATE * dur)
	var amp := 0.22 if is_bed else 0.30
	var rel := 0.05
	if not is_bed:
		rel = dur * 0.35
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(PLACEHOLDER_RATE)
		var env := 1.0
		if t < 0.01:
			env = t / 0.01
		elif t > dur - rel:
			env = maxf(0.0, (dur - t) / rel)
		var s := sin(TAU * freq * t) * amp * env
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = PLACEHOLDER_RATE
	wav.stereo = false
	wav.data = bytes
	if is_bed:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav
