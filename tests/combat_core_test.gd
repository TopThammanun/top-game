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

var _failures: Array[String] = []


func _ready() -> void:
	_check_stat_system()
	_check_damage()
	_check_skill()
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


func _finish() -> void:
	if _failures.is_empty():
		print("[combat_core_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[combat_core_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
