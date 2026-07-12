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
