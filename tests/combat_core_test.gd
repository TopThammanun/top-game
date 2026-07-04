extends Node

# Headless unit tests for the pure-logic combat core (scripts/combat/*).
# Invoke via: <godot> --headless res://tests/combat_core_test.tscn
# Mirrors tests/bootstrap_test.gd: collect failures, print PASS/FAIL, quit 0/1.

var _failures: Array[String] = []


func _ready() -> void:
	_check_stat_system()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return abs(a - b) <= eps


func _check_stat_system() -> void:
	var S := CombatEnums.StatKey
	var s := StatSystem.new({ S.HP: 100.0, S.ATK: 20.0, S.DEF: 5.0 })
	_expect(_approx(s.get_stat(S.ATK), 20.0), "base ATK should be 20, got %f" % s.get_stat(S.ATK))
	_expect(_approx(s.current_hp, 100.0), "current_hp should init to max HP 100, got %f" % s.current_hp)

	# flat + percent stack: (20 + 10) * (1 + 0.5) = 45
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.FLAT, 10.0, "buffA"))
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.PERCENT, 0.5, "buffB"))
	_expect(_approx(s.get_stat(S.ATK), 45.0), "flat+percent ATK should be 45, got %f" % s.get_stat(S.ATK))

	# remove by source
	s.remove_modifiers_from("buffA")
	_expect(_approx(s.get_stat(S.ATK), 30.0), "after removing flat, ATK should be 30, got %f" % s.get_stat(S.ATK))

	# duration expiry
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.FLAT, 100.0, "temp", 1.0))
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


func _finish() -> void:
	if _failures.is_empty():
		print("[combat_core_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[combat_core_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
