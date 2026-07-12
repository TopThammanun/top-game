extends Node

# Headless unit test for the audio system. Autoloads are global in any headless
# scene, so this exercises AudioRegistry/AudioDirector in isolation (no game scene).
# Invoke via: godot --headless --audio-driver Dummy res://tests/audio_system_test.tscn

const EXPECTED_BUSES := ["Master", "Music", "SFX", "Ambient", "Voice", "UI"]

var _failures: Array[String] = []


func _ready() -> void:
	_test_buses_exist()
	_test_registry_resolves_cues()
	_test_volume_round_trips()
	_test_sfx_configures_player()
	_test_reward_ladder()
	_test_music_zone_loads()
	_test_play_zone_builds_stems()
	_test_music_state_matrix()
	_test_purr_bed()
	_finish()


func _test_buses_exist() -> void:
	for bus_name in EXPECTED_BUSES:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "bus '%s' exists" % bus_name)


func _test_registry_resolves_cues() -> void:
	_expect(AudioRegistry.loaded, "AudioRegistry finished loading manifests")
	_expect(AudioRegistry.has_cue("ui_click"), "cue 'ui_click' is known")
	var cue := AudioRegistry.get_cue("ui_click")
	_expect(str(cue.get("bus", "")) == "UI", "ui_click routes to the UI bus, got '%s'" % str(cue.get("bus", "")))
	_expect(AudioRegistry.get_cue("does_not_exist").is_empty(), "unknown cue returns an empty Dictionary")
	# Missing wav degrades to null, not a crash:
	_expect(AudioRegistry.load_stream("res://asset/audio/__missing__.wav") == null, "missing wav returns null (no crash)")
	_expect(AudioRegistry.streams_for("ui_click") is Array, "streams_for always returns an Array")


func _test_volume_round_trips() -> void:
	AudioDirector.set_bus_volume("Music", 0.5)
	_expect(abs(AudioDirector.get_bus_volume("Music") - 0.5) < 0.001, "Music volume round-trips to 0.5")
	var idx := AudioServer.get_bus_index("Music")
	_expect(abs(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.01, "AudioServer Music bus reflects linear_to_db(0.5)")
	AudioDirector.set_bus_volume("Music", 0.0)
	_expect(AudioServer.get_bus_volume_db(idx) <= -79.0, "volume 0.0 floors to ~-80 dB (no -inf)")
	AudioDirector.set_bus_volume("Music", 1.0)  # restore
	_expect(AudioDirector.get_bus_volume("Nonexistent") == 1.0, "unknown bus reads default 1.0")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _test_reward_ladder() -> void:
	_expect(AudioDirector.reward(0) == null, "reward(0) is an invalid layer -> null")
	_expect(AudioDirector.reward(99) == null, "reward(99) is an invalid layer -> null")
	var p: AudioStreamPlayer = AudioDirector.reward(3)   # level_up
	_expect(p != null, "reward(3) returns a player")
	if p != null:
		_expect(p.bus == "SFX", "reward chime plays on the SFX bus (so it drives the duck), got '%s'" % p.bus)
		_expect(p.pitch_scale == 1.0, "reward chime is tuned (pitch 1.0), got %f" % p.pitch_scale)
	# The Music bus carries a Compressor keyed to SFX (the duck).
	var mi: int = AudioServer.get_bus_index("Music")
	_expect(AudioServer.get_bus_effect_count(mi) >= 1, "Music bus has at least one effect (the duck compressor)")
	var has_comp: bool = false
	for e in range(AudioServer.get_bus_effect_count(mi)):
		if AudioServer.get_bus_effect(mi, e) is AudioEffectCompressor:
			has_comp = true
	_expect(has_comp, "Music bus duck effect is an AudioEffectCompressor")


func _test_sfx_configures_player() -> void:
	# Unknown cue is a safe no-op.
	_expect(AudioDirector.sfx("does_not_exist") == null, "sfx on unknown cue returns null")

	# A texture cue is routed to its bus and pitch-jittered within a bounded range.
	var p: AudioStreamPlayer = AudioDirector.sfx("ui_click")
	_expect(p != null, "sfx('ui_click') returns a player")
	if p != null:
		_expect(p.bus == "UI", "ui_click player is on the UI bus, got '%s'" % p.bus)
		_expect(abs(p.pitch_scale - 1.0) <= 0.5, "ui_click pitch jitter stays bounded, got %f" % p.pitch_scale)

	# A tuned cue must NOT be pitch/volume jittered.
	var r: AudioStreamPlayer = AudioDirector.sfx("level_up")
	_expect(r != null, "sfx('level_up') returns a player")
	if r != null:
		_expect(r.pitch_scale == 1.0, "tuned cue has pitch_scale exactly 1.0, got %f" % r.pitch_scale)
		_expect(r.volume_db == 0.0, "tuned cue has volume_db exactly 0.0, got %f" % r.volume_db)

	# Throttle suppresses an immediate replay (ui_click throttle_ms = 40).
	AudioDirector.sfx("ui_click")
	_expect(AudioDirector.sfx("ui_click") == null, "second immediate ui_click is throttled to null")


func _test_music_zone_loads() -> void:
	var zone: Dictionary = AudioRegistry.get_zone("emberhearth")
	_expect(not zone.is_empty(), "zone 'emberhearth' is known")
	_expect(zone.has("stems") and zone.has("states"), "zone has stems + states")
	_expect(zone.get("states", {}).has("idle"), "zone has an 'idle' state")
	_expect(AudioRegistry.get_zone("nope").is_empty(), "unknown zone returns an empty Dictionary")


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


func _test_purr_bed() -> void:
	AudioDirector.purr(true)
	_expect(AudioDirector._purr_player != null, "purr(true) creates the purr player")
	if AudioDirector._purr_player != null:
		_expect(AudioDirector._purr_player.bus == "Ambient", "purr bed is on the Ambient bus, got '%s'" % AudioDirector._purr_player.bus)
		_expect(abs(AudioDirector._purr_player.volume_db - AudioDirector.PURR_DB) < 0.001, "purr(true) sets volume to PURR_DB")
	AudioDirector.purr(false)
	_expect(not AudioDirector._purr_player.playing, "purr(false) stops the bed")


func _finish() -> void:
	if _failures.is_empty():
		print("[audio_system_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[audio_system_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
