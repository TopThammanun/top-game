extends Node

# Headless integration test: drives the REAL battle scene
# (scenes/combat/battle.tscn) through starter-pick -> fighting -> a forced
# level-up -> card pick, end-to-end. This exercises the scene-wiring
# (battle_view.gd hooks into RunState/CardSystem/DraftView) that the pure-logic
# suites (roguelike_test.gd, roguelike_gamestate_test.gd) cannot reach, since
# those only construct RunState/CardSystem/GameState directly.
#
# Invoke via: godot --headless res://tests/roguelike_loop_test.tscn

const MAX_POLL_FRAMES := 600

var _failures: Array[String] = []


func _ready() -> void:
	var scene = preload("res://scenes/combat/battle.tscn").instantiate()
	add_child(scene)

	var reached_starter_pick: bool = false
	for i in range(MAX_POLL_FRAMES):
		if scene._phase == "levelup" and scene._picking_starter == true:
			reached_starter_pick = true
			break
		await get_tree().process_frame
	_expect(reached_starter_pick, "reached the starter-pick draft within %d frames" % MAX_POLL_FRAMES)

	if reached_starter_pick:
		await _drive_starter_pick(scene)

	scene.queue_free()
	_finish()


func _drive_starter_pick(scene) -> void:
	scene._on_draft_chosen(0)
	_expect(GameState.party.size() == 1, "starter pick seeds a party of 1, got %d" % GameState.party.size())
	_expect(scene._run != null, "scene._run is created after the starter pick")
	_expect(scene._phase == "fighting", "phase is 'fighting' after the starter pick, got '%s'" % str(scene._phase))

	if scene._run != null:
		await _force_level_up(scene)


func _force_level_up(scene) -> void:
	var need: int = scene._run.xp_to_next(scene._run.run_level)
	scene._run.add_xp(need)

	# _process() picks up pending_levelups on its next tick, but exactly which
	# frame that lands on is a signal-ordering detail we shouldn't hardcode —
	# poll a small bounded window instead of assuming a single frame suffices.
	var opened: bool = false
	for i in range(10):
		await get_tree().process_frame
		if scene._phase == "levelup":
			opened = true
			break
	_expect(opened, "forced level-up opens the draft within 10 frames, phase='%s'" % str(scene._phase))
	_expect(scene._pending_cards.size() >= 1, "draft opened with at least 1 pending card, got %d" % scene._pending_cards.size())

	if scene._phase == "levelup" and scene._pending_cards.size() >= 1:
		_pick_a_card(scene)


func _pick_a_card(scene) -> void:
	var upgrades_before: int = scene._run.upgrades.size()
	var pending_before: int = scene._run.pending_levelups
	var party_before: int = GameState.party.size()

	scene._on_draft_chosen(0)

	_expect(scene._run.pending_levelups < pending_before,
		"pending_levelups decreased after the pick (%d -> %d)" % [pending_before, scene._run.pending_levelups])
	var applied: bool = scene._run.upgrades.size() > upgrades_before or GameState.party.size() > party_before
	_expect(applied, "the pick applied an upgrade or grew the party")
	_expect(scene._phase == "fighting" or scene._phase == "levelup",
		"phase settles back to fighting (or stays levelup if more picks pending), got '%s'" % str(scene._phase))


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_loop_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_loop_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
