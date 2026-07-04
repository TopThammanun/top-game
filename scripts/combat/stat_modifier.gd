class_name StatModifier
extends RefCounted

# One flat or percent modifier applied to a StatSystem stat.
# duration <= 0 means permanent (e.g. gear); > 0 counts down via tick_modifiers.

var stat: int          # CombatEnums.StatKey
var type: int          # CombatEnums.ModifierType
var value: float
var source: String
var duration: float


func _init(p_stat: int, p_type: int, p_value: float, p_source: String = "", p_duration: float = 0.0) -> void:
	stat = p_stat
	type = p_type
	value = p_value
	source = p_source
	duration = p_duration


func is_permanent() -> bool:
	return duration <= 0.0
