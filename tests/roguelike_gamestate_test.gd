extends Node

# Drives the GameState autoload (waits for bootstrap) to check the roguelike
# seams: single-cat seed, recruit, end_run reward, endless wave past the cap.

var _failures: Array[String] = []


func _ready() -> void:
	if not GameState.is_ready:
		await GameState.state_ready
	_run_checks()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run_checks() -> void:
	# seed a single starter
	GameState.seed_run_party("maincoon_ironmane")
	_expect(GameState.party.size() == 1, "seed_run_party gives party of 1, got %d" % GameState.party.size())
	_expect(GameState.party[0].clan_id == "maincoon_ironmane", "seeded the chosen clan")

	# recruit grows the party and de-dups
	_expect(GameState.recruit_member("bengalis_wildstripe"), "recruit succeeds")
	_expect(GameState.party.size() == 2, "party grows to 2")
	_expect(not GameState.recruit_member("bengalis_wildstripe"), "duplicate recruit is rejected")

	# endless: advancing past MAX_WAVE loads a non-empty wave
	GameState.advance_to_wave(GameState.MAX_WAVE + 3)
	_expect(GameState.wave == GameState.MAX_WAVE + 3, "advanced past the cap")
	_expect(GameState.wave_state != null and GameState.wave_state.enemies.size() > 0, "endless wave has enemies")

	# end_run banks the reward and sets status
	var before: int = GameState.currency
	GameState.end_run("wiped", 40)
	_expect(GameState.currency == before + 40, "end_run adds reward")
	_expect(GameState.run_status == "wiped", "end_run sets status")


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_gamestate_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_gamestate_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
