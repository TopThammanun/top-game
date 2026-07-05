extends Node

# Headless unit tests for the pure-logic combat core (scripts/combat/*).
# Invoke via: <godot> --headless res://tests/combat_core_test.tscn
# Mirrors tests/bootstrap_test.gd: collect failures, print PASS/FAIL, quit 0/1.
#
# Combat classes are pulled in via preload consts (project convention) so the
# test resolves headless without needing the .godot global-class-cache rebuilt.
# See agents/sage/godot-runtime/decisions/headless-global-class-cache.md

const CombatEnumsClass = preload("res://scripts/combat/combat_enums.gd")
const StatSystemClass = preload("res://scripts/combat/stat_system.gd")
const StatModifierClass = preload("res://scripts/combat/stat_modifier.gd")
const DamageCalculatorClass = preload("res://scripts/combat/damage_calculator.gd")
const CombatSkillClass = preload("res://scripts/combat/combat_skill.gd")
const SkillEffectClass = preload("res://scripts/combat/skill_effect.gd")
const CharacterFactoryClass = preload("res://scripts/combat/character_factory.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_check_stat_system()
	_check_damage()
	_check_skill()
	_check_effect()
	_check_factory()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return abs(a - b) <= eps


func _check_stat_system() -> void:
	var S := CombatEnumsClass.StatKey
	var s := StatSystemClass.new({ S.HP: 100.0, S.ATK: 20.0, S.DEF: 5.0 })
	_expect(_approx(s.get_stat(S.ATK), 20.0), "base ATK should be 20, got %f" % s.get_stat(S.ATK))
	_expect(_approx(s.current_hp, 100.0), "current_hp should init to max HP 100, got %f" % s.current_hp)

	# flat + percent stack: (20 + 10) * (1 + 0.5) = 45
	s.add_modifier(StatModifierClass.new(S.ATK, CombatEnumsClass.ModifierType.FLAT, 10.0, "buffA"))
	s.add_modifier(StatModifierClass.new(S.ATK, CombatEnumsClass.ModifierType.PERCENT, 0.5, "buffB"))
	_expect(_approx(s.get_stat(S.ATK), 45.0), "flat+percent ATK should be 45, got %f" % s.get_stat(S.ATK))

	# remove by source
	s.remove_modifiers_from("buffA")
	_expect(_approx(s.get_stat(S.ATK), 30.0), "after removing flat, ATK should be 30, got %f" % s.get_stat(S.ATK))

	# duration expiry — (20 + 100) * (1 + 0.5) = 180 while active
	s.add_modifier(StatModifierClass.new(S.ATK, CombatEnumsClass.ModifierType.FLAT, 100.0, "temp", 1.0))
	_expect(_approx(s.get_stat(S.ATK), 180.0), "temp buff active should give 180, got %f" % s.get_stat(S.ATK))
	s.tick_modifiers(1.5)
	_expect(_approx(s.get_stat(S.ATK), 30.0), "temp buff should expire back to 30, got %f" % s.get_stat(S.ATK))

	# hp
	s.take_damage(40.0)
	_expect(_approx(s.current_hp, 60.0), "hp after 40 dmg should be 60, got %f" % s.current_hp)
	s.heal(1000.0)
	_expect(_approx(s.current_hp, 100.0), "heal should cap at max HP 100, got %f" % s.current_hp)
	s.take_damage(1000.0)
	_expect(not s.is_alive(), "unit should be dead after lethal damage")


func _check_damage() -> void:
	var S := CombatEnumsClass.StatKey
	# ATK 100 vs DEF 100, no crit (crit_roll = 1.0 forces no crit):
	# raw=100, mitigated = 100 * (100/200) = 50
	var atkr := StatSystemClass.new({ S.ATK: 100.0 })
	var deff := StatSystemClass.new({ S.HP: 999.0, S.DEF: 100.0 })
	var r := DamageCalculatorClass.compute(atkr, deff, 1.0, 1.0)
	_expect(r.amount == 50, "100 ATK vs 100 DEF should be 50, got %d" % r.amount)
	_expect(r.is_crit == false, "forced crit_roll 1.0 should not crit")

	# crit doubles when CRIT_DMG = 1.0 and crit_roll below CRIT_CHANCE
	var critr := StatSystemClass.new({ S.ATK: 100.0, S.CRIT_CHANCE: 0.5, S.CRIT_DMG: 1.0 })
	var rc := DamageCalculatorClass.compute(critr, deff, 1.0, 0.0)
	_expect(rc.amount == 100, "crit (x2) on 50 base should be 100, got %d" % rc.amount)
	_expect(rc.is_crit == true, "crit_roll 0.0 < 0.5 should crit")

	# resist reduces; bypass negates it. DEF 0 so raw passes: raw=100.
	var noDef := StatSystemClass.new({ S.HP: 999.0, S.DEF: 0.0, S.DMG_RESIST: 0.5 })
	var plain := StatSystemClass.new({ S.ATK: 100.0 })
	_expect(DamageCalculatorClass.compute(plain, noDef, 1.0, 1.0).amount == 50,
		"50% resist should halve 100 to 50")
	var piercer := StatSystemClass.new({ S.ATK: 100.0, S.DMG_RESIST_BYPASS: 0.5 })
	_expect(DamageCalculatorClass.compute(piercer, noDef, 1.0, 1.0).amount == 100,
		"0.5 bypass vs 0.5 resist should negate resist -> 100")

	# resist clamps at 0.9 (never 100% immune)
	var wall := StatSystemClass.new({ S.HP: 999.0, S.DEF: 0.0, S.DMG_RESIST: 5.0 })
	_expect(DamageCalculatorClass.compute(plain, wall, 1.0, 1.0).amount == 10,
		"resist clamps at 0.9 -> 100 becomes 10, got %d" % DamageCalculatorClass.compute(plain, wall, 1.0, 1.0).amount)

	# floor at 1
	var tiny := StatSystemClass.new({ S.ATK: 1.0 })
	var tank := StatSystemClass.new({ S.HP: 999.0, S.DEF: 10000.0 })
	_expect(DamageCalculatorClass.compute(tiny, tank, 1.0, 1.0).amount >= 1, "damage floors at 1")


func _check_skill() -> void:
	var sk := CombatSkillClass.new({
		"id": "wildstripe_burst", "starting_cooldown": 3.0, "cooldown": 8.0,
		"skill_ratio": 2.0, "effect_type": "aoe_damage",
	})
	_expect(_approx(sk.remaining, 3.0), "skill should start on starting_cooldown 3.0, got %f" % sk.remaining)
	_expect(not sk.is_ready(), "skill should not be ready at battle start")

	# CDR scales the tick: 1.0s of delta at 0.5 CDR ticks 1.5s
	sk.tick(1.0, 0.5)
	_expect(_approx(sk.remaining, 1.5), "3.0 - 1.0*(1.5) should be 1.5, got %f" % sk.remaining)
	sk.tick(2.0, 0.5)
	_expect(sk.is_ready(), "skill should be ready after enough ticks (remaining clamps at 0)")
	_expect(_approx(sk.remaining, 0.0), "remaining should clamp at 0, got %f" % sk.remaining)

	# trigger resets to full cooldown (not starting cooldown)
	sk.trigger()
	_expect(_approx(sk.remaining, 8.0), "trigger should set remaining to cooldown 8.0, got %f" % sk.remaining)


func _check_effect() -> void:
	var S := CombatEnumsClass.StatKey

	# aoe_damage hits every target and mutates their hp
	var caster := StatSystemClass.new({ S.ATK: 100.0 })
	var e1 := StatSystemClass.new({ S.HP: 999.0, S.DEF: 100.0 })
	var e2 := StatSystemClass.new({ S.HP: 999.0, S.DEF: 100.0 })
	var dmg_skill := CombatSkillClass.new({ "effect_type": "aoe_damage", "skill_ratio": 1.0 })
	var results := SkillEffectClass.apply(dmg_skill, caster, [e1, e2], 1.0)
	_expect(results.size() == 2, "aoe should return one result per target, got %d" % results.size())
	_expect(_approx(e1.current_hp, 949.0), "e1 should take 50 dmg (999->949), got %f" % e1.current_hp)
	_expect(_approx(e2.current_hp, 949.0), "e2 should take 50 dmg (999->949), got %f" % e2.current_hp)

	# heal scales off caster ATK
	var healer := StatSystemClass.new({ S.ATK: 40.0 })
	var wounded := StatSystemClass.new({ S.HP: 100.0 })
	wounded.take_damage(60.0)  # -> 40
	var heal_skill := CombatSkillClass.new({ "effect_type": "heal", "skill_ratio": 1.0, "target_side": "ally" })
	SkillEffectClass.apply(heal_skill, healer, [wounded])
	_expect(_approx(wounded.current_hp, 80.0), "heal 40 should bring 40 -> 80, got %f" % wounded.current_hp)

	# buff adds a percent modifier from a string stat key
	var ally := StatSystemClass.new({ S.ATK: 100.0 })
	var buff_skill := CombatSkillClass.new({
		"effect_type": "buff", "target_side": "ally",
		"effect_params": { "stat": "atk", "value": 0.3, "duration": 5.0 },
	})
	SkillEffectClass.apply(buff_skill, ally, [ally])
	_expect(_approx(ally.get_stat(S.ATK), 130.0), "atk buff +30%% should give 130, got %f" % ally.get_stat(S.ATK))

	# ward/bulwark: a FLAT buff to a fractional stat (dmg_resist) must be additive,
	# not percent (percent would scale a 0 base to 0). type:"flat" drives this.
	var guard := StatSystemClass.new({ S.DMG_RESIST: 0.0 })
	var ward_skill := CombatSkillClass.new({
		"effect_type": "buff", "target_side": "ally",
		"effect_params": { "stat": "dmg_resist", "value": 0.2, "duration": 4.0, "type": "flat" },
	})
	SkillEffectClass.apply(ward_skill, guard, [guard])
	_expect(_approx(guard.get_stat(S.DMG_RESIST), 0.2), "flat dmg_resist ward on 0 base should give +0.2, got %f" % guard.get_stat(S.DMG_RESIST))

	# stun returns a control descriptor, mutates no stats
	var target := StatSystemClass.new({ S.HP: 100.0 })
	var stun_skill := CombatSkillClass.new({ "effect_type": "stun", "effect_params": { "duration": 1.5 } })
	var stun_res := SkillEffectClass.apply(stun_skill, caster, [target])
	_expect(stun_res.size() == 1 and _approx(stun_res[0].get("stun", 0.0), 1.5), "stun should report 1.5s descriptor")
	_expect(_approx(target.current_hp, 100.0), "stun should not damage the target")


func _check_factory() -> void:
	var f := CharacterFactoryClass.new()
	f.load_all()

	_expect(f.archetype_ids().size() == 8, "expected 8 archetypes, got %d" % f.archetype_ids().size())

	var clan_ids := f.clan_ids()
	_expect(clan_ids.size() >= 1, "expected at least one clan to build from")
	for cid in clan_ids:
		var p := f.build_from_clan(cid)
		var stats = p.get("stats")
		_expect(stats != null, "clan %s should produce a StatSystem" % cid)
		_expect(stats != null and stats.get_stat(CombatEnumsClass.StatKey.HP) > 0.0, "clan %s should have HP > 0" % cid)
		_expect(int(p.get("lane", -1)) in [CombatEnumsClass.Lane.FRONT, CombatEnumsClass.Lane.MIDDLE, CombatEnumsClass.Lane.REAR], "clan %s should map to a valid lane" % cid)
		_expect(str(p.get("idle_shortcut", "")) != "", "clan %s should carry an idle_shortcut" % cid)
		_expect(float(p.get("attack_range", 0.0)) > 0.0, "clan %s should have attack_range > 0" % cid)

	for eid in f.enemy_ids():
		var pe := f.build_from_enemy(eid)
		var es = pe.get("stats")
		_expect(es != null and es.get_stat(CombatEnumsClass.StatKey.HP) > 0.0, "enemy %s should have HP > 0" % eid)


func _finish() -> void:
	if _failures.is_empty():
		print("[combat_core_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[combat_core_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
