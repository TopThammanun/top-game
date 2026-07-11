extends Node

# Headless unit tests for the roguelike core (scripts/roguelike/*).
# Invoke via: <godot> --headless res://tests/roguelike_test.tscn
# Mirrors tests/combat_core_test.gd: collect failures, print PASS/FAIL, quit 0/1.

const RunStateClass = preload("res://scripts/roguelike/run_state.gd")
const CardDataClass = preload("res://scripts/roguelike/card_data.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_check_run_state()
	_check_card_data()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _check_run_state() -> void:
	var rs = RunStateClass.new({}, "maincoon_ironmane")
	_expect(rs.party_size() == 1, "starter seeds party of 1, got %d" % rs.party_size())
	_expect(rs.has_member("maincoon_ironmane"), "starter should be a member")
	_expect(rs.run_level == 1, "run starts at level 1")

	# XP curve: xp_to_next(1) = 10 + 0 + floor(1*1*0.4) = 10
	_expect(rs.xp_to_next(1) == 10, "xp_to_next(1) should be 10, got %d" % rs.xp_to_next(1))
	# xp_to_next(2) = 10 + 6 + floor(4*0.4=1.6) = 17
	_expect(rs.xp_to_next(2) == 17, "xp_to_next(2) should be 17, got %d" % rs.xp_to_next(2))

	# add_xp crosses exactly one level (10 -> level 2, 0 carry)
	var gained: int = rs.add_xp(10)
	_expect(gained == 1, "10 xp should grant 1 level, got %d" % gained)
	_expect(rs.run_level == 2, "run_level should be 2, got %d" % rs.run_level)
	_expect(rs.pending_levelups == 1, "pending_levelups should be 1, got %d" % rs.pending_levelups)

	# a big chunk can cross several levels
	var g2: int = rs.add_xp(1000)
	_expect(g2 >= 2, "1000 xp should cross multiple levels, got %d" % g2)

	# recruit arrival = floor(level*0.7), min 1
	rs.run_level = 10
	_expect(rs.recruit_arrival_level() == 7, "arrival at lvl10 should be 7, got %d" % rs.recruit_arrival_level())

	# party cap + de-dup
	for cid in ["a", "b", "c", "d", "e", "f"]:
		rs.add_member(cid)
	_expect(rs.party_size() == 5, "party caps at 5, got %d" % rs.party_size())
	rs.add_member("a")
	_expect(rs.party_size() == 5, "duplicate/over-cap add is a no-op")


func _check_card_data() -> void:
	var c = CardDataClass.from_dict({
		"id": "atk_party_s", "type": "stat", "rarity": "common", "title": "Sharpened Claws",
		"target": "party", "effect": { "stat": "atk", "mod": "percent", "value": 0.08 },
	})
	_expect(c.id == "atk_party_s", "id parsed")
	_expect(c.type == "stat" and c.is_upgrade(), "stat is an upgrade")
	_expect(float(c.effect.get("value", 0.0)) == 0.08, "effect value parsed")
	_expect(c.unit_key == "", "unbound card has empty unit_key")

	var bound = c.bind_to_unit("bengalis_wildstripe")
	_expect(bound.unit_key == "bengalis_wildstripe", "bind sets unit_key")
	_expect(c.unit_key == "", "bind does not mutate the original")

	bound.effect["value"] = 999.0
	_expect(float(c.effect.get("value", 0.0)) == 0.08, "bind_to_unit deep-copies effect; original unchanged")

	var rec = CardDataClass.from_dict({ "id": "r", "type": "recruit", "effect": { "clan_id": "x" } })
	_expect(not rec.is_upgrade(), "recruit is not an upgrade")


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
