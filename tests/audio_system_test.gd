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


func _finish() -> void:
	if _failures.is_empty():
		print("[audio_system_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[audio_system_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
