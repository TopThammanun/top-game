class_name CombatSkill
extends RefCounted

# One skill instance owned by an entity. Implements the CRK "Starting Cooldown":
# remaining begins at starting_cooldown, not 0 and not full cooldown.

var id: String
var starting_cooldown: float
var cooldown: float
var skill_ratio: float
var effect_type: String
var effect_params: Dictionary
var target_side: String     # "enemy" | "ally" | "self"
var max_targets: int        # 0 = all valid targets
var remaining: float


func _init(config: Dictionary = {}) -> void:
	id = str(config.get("id", ""))
	starting_cooldown = float(config.get("starting_cooldown", 3.0))
	cooldown = float(config.get("cooldown", 8.0))
	skill_ratio = float(config.get("skill_ratio", 1.0))
	effect_type = str(config.get("effect_type", "aoe_damage"))
	effect_params = config.get("effect_params", {})
	target_side = str(config.get("target_side", "enemy"))
	max_targets = int(config.get("max_targets", 0))
	remaining = starting_cooldown


func tick(delta: float, cooldown_reduction: float) -> void:
	remaining = max(0.0, remaining - delta * (1.0 + cooldown_reduction))


func is_ready() -> bool:
	return remaining <= 0.0


func trigger() -> void:
	remaining = cooldown
