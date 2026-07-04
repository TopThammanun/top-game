class_name StatModifier
extends RefCounted

# One flat or percent modifier applied to a StatSystem stat.
# A modifier created with duration <= 0 is permanent (e.g. gear); one created
# with duration > 0 counts down via StatSystem.tick_modifiers and is removed
# when it expires. Permanence is captured at creation so a temporary whose
# duration decrements past 0 is never mistaken for permanent.

var stat: int          # CombatEnums.StatKey
var type: int          # CombatEnums.ModifierType
var value: float
var source: String
var duration: float
var permanent: bool


func _init(p_stat: int, p_type: int, p_value: float, p_source: String = "", p_duration: float = 0.0) -> void:
	stat = p_stat
	type = p_type
	value = p_value
	source = p_source
	duration = p_duration
	permanent = p_duration <= 0.0


func is_permanent() -> bool:
	return permanent
