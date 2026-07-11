extends Node

# Headless unit tests for the roguelike core (scripts/roguelike/*).
# Invoke via: <godot> --headless res://tests/roguelike_test.tscn
# Mirrors tests/combat_core_test.gd: collect failures, print PASS/FAIL, quit 0/1.

const RunStateClass = preload("res://scripts/roguelike/run_state.gd")
const CardDataClass = preload("res://scripts/roguelike/card_data.gd")
const CardSystemClass = preload("res://scripts/roguelike/card_system.gd")
const CharacterFactoryClass = preload("res://scripts/combat/character_factory.gd")
const UnitStateClass = preload("res://scripts/runtime/unit_state.gd")
const WaveStateClass = preload("res://scripts/runtime/wave_state.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_check_run_state()
	_check_card_data()
	_check_card_system()
	_check_roster()
	_check_waves()
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


func _check_card_system() -> void:
	# recruit weight curve
	_expect(abs(CardSystemClass.recruit_weight(1) - 0.39) < 0.001, "recruit_weight(1) ~ 0.39")
	_expect(abs(CardSystemClass.recruit_weight(5) - 0.15) < 0.001, "recruit_weight(5) ~ 0.15")
	_expect(CardSystemClass.recruit_weight(8) == 0.0, "recruit_weight(8) clamps to 0")

	var rows: Array = [
		{ "id": "s1", "type": "stat", "rarity": "common", "target": "party",
		  "effect": { "stat": "atk", "mod": "percent", "value": 0.08 } },
		{ "id": "u1", "type": "stat", "rarity": "rare", "target": "unit",
		  "effect": { "stat": "hp", "mod": "percent", "value": 0.2 } },
		{ "id": "rk", "type": "recruit", "rarity": "rare", "title": "Kilo",
		  "effect": { "clan_id": "kilo" } },
		{ "id": "rz", "type": "recruit", "rarity": "rare", "title": "Zulu",
		  "effect": { "clan_id": "zulu" } },
	]
	var cs = CardSystemClass.new()
	cs.load_from_array(rows)

	var roster: Array = ["alpha", "kilo", "zulu"]
	var run = RunStateClass.new({}, "alpha")

	# candidates: 1 party stat + 1 unit-expanded (party has 1 member) + 2 recruits = 4
	var cand: Array = cs.candidates(run, roster)
	_expect(cand.size() == 4, "candidates should be 4, got %d" % cand.size())

	# fill the party -> no recruit candidates remain
	for cid in ["kilo", "zulu", "b", "c"]:
		run.add_member(cid)
	var cand_full: Array = cs.candidates(run, roster)
	for c in cand_full:
		_expect(c.type != "recruit", "no recruit candidates when party is full")

	# draw: 3 distinct cards, deterministic under a seeded rng, >=1 upgrade
	var run2 = RunStateClass.new({}, "alpha")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var drawn: Array = cs.draw(run2, roster, rng)
	_expect(drawn.size() == 3, "draw returns 3, got %d" % drawn.size())
	var ids := {}
	for c in drawn:
		ids[c.id + c.unit_key] = true
	_expect(ids.size() == 3, "drawn cards are distinct")
	var has_up := false
	for c in drawn:
		if c.is_upgrade():
			has_up = true
	_expect(has_up, "draw guarantees at least one upgrade")

	# resolve shapes
	var stat_card = CardDataClass.from_dict(rows[0])
	var r1: Dictionary = cs.resolve(stat_card, run2)
	_expect(str(r1.get("kind", "")) == "stat" and str(r1.get("scope", "")) == "party", "party stat resolves")
	var rec_card = CardDataClass.from_dict(rows[2])
	var r2: Dictionary = cs.resolve(rec_card, run2)
	_expect(str(r2.get("kind", "")) == "recruit" and str(r2.get("clan_id", "")) == "kilo", "recruit resolves clan_id")

	# guarantee branch: a recruit-heavy pool must still yield >=1 upgrade every draw
	var gpool: Array = [
		{ "id": "ga", "type": "recruit", "rarity": "rare", "title": "A", "effect": { "clan_id": "ga" } },
		{ "id": "gb", "type": "recruit", "rarity": "rare", "title": "B", "effect": { "clan_id": "gb" } },
		{ "id": "gc", "type": "recruit", "rarity": "rare", "title": "C", "effect": { "clan_id": "gc" } },
		{ "id": "gs", "type": "stat", "rarity": "common", "target": "party",
		  "effect": { "stat": "atk", "mod": "percent", "value": 0.08 } },
	]
	var gcs = CardSystemClass.new()
	gcs.load_from_array(gpool)
	var groster: Array = ["ga", "gb", "gc"]
	for s in 60:
		var grun = RunStateClass.new({}, "z")
		var grng := RandomNumberGenerator.new()
		grng.seed = s
		var gd: Array = gcs.draw(grun, groster, grng)
		var gup: bool = false
		var gids: Dictionary = {}
		for c in gd:
			gids[c.id + c.unit_key] = true
			if c.is_upgrade():
				gup = true
		_expect(gup, "guarantee: every draw yields >=1 upgrade (seed %d)" % s)
		_expect(gids.size() == gd.size(), "draw cards distinct (seed %d)" % s)

	# resolve() skill + passive shapes (keys field/op and passive_id)
	var skill_card = CardDataClass.from_dict({
		"id": "sk", "type": "skill", "target": "unit",
		"effect": { "field": "cooldown", "op": "mul", "value": 0.75 } }).bind_to_unit("alpha")
	var rs_sk: Dictionary = cs.resolve(skill_card, run2)
	_expect(str(rs_sk.get("kind", "")) == "skill" and str(rs_sk.get("field", "")) == "cooldown" and str(rs_sk.get("op", "")) == "mul", "skill resolves field/op")
	_expect(abs(float(rs_sk.get("value", 0.0)) - 0.75) < 0.001 and str(rs_sk.get("unit_key", "")) == "alpha", "skill resolves value/unit_key")
	var pass_card = CardDataClass.from_dict({
		"id": "pa", "type": "passive",
		"effect": { "passive_id": "might", "stat": "atk", "mod": "percent", "value": 0.12 } })
	var rs_pa: Dictionary = cs.resolve(pass_card, run2)
	_expect(str(rs_pa.get("kind", "")) == "passive" and str(rs_pa.get("passive_id", "")) == "might", "passive resolves passive_id")
	_expect(str(rs_pa.get("stat", "")) == "atk" and abs(float(rs_pa.get("value", 0.0)) - 0.12) < 0.001, "passive resolves stat/value")


func _check_roster() -> void:
	var f = CharacterFactoryClass.new()
	f.load_all()
	for cid in ["abyssian_quillwhisker", "devonrex_tinkertail"]:
		_expect(f.has_clan(cid), "clan %s should exist" % cid)
		var p: Dictionary = f.build_from_clan(cid)
		var stats = p.get("stats")
		_expect(stats != null and stats.get_stat(CombatEnumsForRoster().HP) > 0.0, "clan %s has HP>0" % cid)
		_expect(p.get("skill") != null, "clan %s has a skill" % cid)

	# from_clan builds a party unit with a sprite shortcut
	var rows := _read_clans()
	var iron: Dictionary = {}
	for r in rows:
		if str(r.get("id", "")) == "maincoon_ironmane":
			iron = r
	var u = UnitStateClass.from_clan(iron)
	_expect(u.clan_id == "maincoon_ironmane", "from_clan sets clan_id")
	_expect(u.idle_asset == "unit.tank_idle", "from_clan reads sprite_shortcut, got %s" % u.idle_asset)
	_expect(u.move_asset == "unit.tank_move", "from_clan derives move shortcut, got %s" % u.move_asset)
	_expect(u.base_hp_max > 0, "from_clan sets base hp")


func CombatEnumsForRoster():
	return preload("res://scripts/combat/combat_enums.gd").StatKey


func _read_clans() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/clans.json"))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _check_waves() -> void:
	var enemies_by_id := _enemies_index()
	# past the authored catalog (>10) it must generate, not error/empty
	var w11 = WaveStateClass.for_wave(11, [], enemies_by_id)
	_expect(w11.enemies.size() > 0, "wave 11 generates enemies, got %d" % w11.enemies.size())
	# boss cadence: wave 15 (15 %% 5 == 0) includes the boss id
	var w15 = WaveStateClass.for_wave(15, [], enemies_by_id)
	var has_boss := false
	for e in w15.enemies:
		if str(e.enemy_id).begins_with("hollowmew_captain"):
			has_boss = true
	_expect(has_boss, "wave 15 is a boss wave")
	# non-boss wave has no boss id
	var w12 = WaveStateClass.for_wave(12, [], enemies_by_id)
	var boss12 := false
	for e in w12.enemies:
		if str(e.enemy_id).begins_with("hollowmew_captain"):
			boss12 = true
	_expect(not boss12, "wave 12 is not a boss wave")


func _enemies_index() -> Dictionary:
	var out: Dictionary = {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/enemies.json"))
	if typeof(parsed) == TYPE_ARRAY:
		for r in parsed:
			if typeof(r) == TYPE_DICTIONARY and r.has("id"):
				out[str(r["id"])] = r
	return out


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
