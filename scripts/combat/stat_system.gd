class_name StatSystem
extends RefCounted

# Base + advanced stats with a modifier stack. Final value:
#   (base + sum FLAT) * (1 + sum PERCENT). Current HP tracked separately.

var _base: Dictionary = {}      # StatKey(int) -> float
var _modifiers: Array = []      # Array[StatModifier]
var current_hp: float = 0.0


func _init(base_stats: Dictionary = {}) -> void:
	for k in base_stats:
		_base[int(k)] = float(base_stats[k])
	current_hp = get_stat(CombatEnums.StatKey.HP)


func set_base(stat: int, value: float) -> void:
	_base[stat] = float(value)


func get_base(stat: int) -> float:
	return float(_base.get(stat, 0.0))


func add_modifier(mod: StatModifier) -> void:
	_modifiers.append(mod)


func remove_modifiers_from(source: String) -> void:
	_modifiers = _modifiers.filter(func(m): return m.source != source)


func get_stat(stat: int) -> float:
	var flat := 0.0
	var pct := 0.0
	for m in _modifiers:
		if m.stat != stat:
			continue
		if m.type == CombatEnums.ModifierType.FLAT:
			flat += m.value
		else:
			pct += m.value
	return (get_base(stat) + flat) * (1.0 + pct)


func tick_modifiers(delta: float) -> void:
	for m in _modifiers:
		if not m.is_permanent():
			m.duration -= delta
	_modifiers = _modifiers.filter(func(m): return m.is_permanent() or m.duration > 0.0)


func is_alive() -> bool:
	return current_hp > 0.0


func take_damage(amount: float) -> void:
	current_hp = max(0.0, current_hp - amount)


func heal(amount: float) -> void:
	current_hp = min(get_stat(CombatEnums.StatKey.HP), current_hp + amount)
