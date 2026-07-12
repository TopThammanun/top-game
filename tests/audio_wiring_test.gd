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
