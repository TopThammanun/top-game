class_name SkillEffect
extends RefCounted

# Resolves a CombatSkill's effect against StatSystem targets. Stat-only effects
# (damage/heal/buff) mutate targets directly; control effects (stun) return a
# descriptor for the entity/FSM layer (Plan B) to act on.
#
# Cross-references via preload consts (see
# agents/sage/godot-runtime/decisions/headless-global-class-cache.md).

const CombatEnumsClass = preload("res://scripts/combat/combat_enums.gd")
const DamageCalculatorClass = preload("res://scripts/combat/damage_calculator.gd")
const StatModifierClass = preload("res://scripts/combat/stat_modifier.gd")


static func apply(skill, caster, targets: Array, crit_roll: float = -1.0) -> Array:
	var out: Array = []
	match skill.effect_type:
		"aoe_damage":
			for i in targets.size():
				var t = targets[i]
				var r := DamageCalculatorClass.compute(caster, t, skill.skill_ratio, crit_roll)
				t.take_damage(float(r.amount))
				out.append({ "target_index": i, "amount": r.amount, "is_crit": r.is_crit })
		"heal":
			var amount: int = int(round(caster.get_stat(CombatEnumsClass.StatKey.ATK) * skill.skill_ratio))
			for i in targets.size():
				var t = targets[i]
				t.heal(float(amount))
				out.append({ "target_index": i, "heal": amount })
		"buff":
			var stat_key: int = CombatEnumsClass.stat_key_from_string(str(skill.effect_params.get("stat", "atk")))
			var value := float(skill.effect_params.get("value", 0.3))
			var duration := float(skill.effect_params.get("duration", 5.0))
			for i in targets.size():
				var t = targets[i]
				t.add_modifier(StatModifierClass.new(stat_key, CombatEnumsClass.ModifierType.PERCENT, value, "skill:%s" % skill.id, duration))
				out.append({ "target_index": i, "buff": value })
		"stun":
			var stun_duration := float(skill.effect_params.get("duration", 1.5))
			for i in targets.size():
				out.append({ "target_index": i, "stun": stun_duration })
	return out
