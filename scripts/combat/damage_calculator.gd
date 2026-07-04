class_name DamageCalculator
extends RefCounted

# CRK-style pipeline (spec §4). Static utility; pass crit_roll >= 0 in tests
# for determinism, or -1.0 to roll randf() at runtime.

static func compute(attacker: StatSystem, defender: StatSystem, skill_ratio: float = 1.0, crit_roll: float = -1.0) -> Dictionary:
	var S := CombatEnums.StatKey
	var atk := attacker.get_stat(S.ATK)
	var deff := defender.get_stat(S.DEF)
	var raw := atk * skill_ratio

	# 1. DEF mitigation (ratio curve, diminishing returns, never negative)
	var dmg := 0.0
	if raw + deff > 0.0:
		dmg = raw * (raw / (raw + deff))

	# 2. Crit
	var is_crit := false
	var roll := crit_roll if crit_roll >= 0.0 else randf()
	if roll < attacker.get_stat(S.CRIT_CHANCE):
		is_crit = true
		dmg *= (1.0 + attacker.get_stat(S.CRIT_DMG))

	# 3. Resist (final multiplier), reduced by attacker bypass, clamped < 1
	var resist: float = clamp(
		defender.get_stat(S.DMG_RESIST) - attacker.get_stat(S.DMG_RESIST_BYPASS),
		0.0, 0.9)
	dmg *= (1.0 - resist)

	# 4. Amplify
	dmg *= (1.0 + attacker.get_stat(S.AMPLIFY))

	return { "amount": int(max(1.0, round(dmg))), "is_crit": is_crit }
