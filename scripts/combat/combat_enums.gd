class_name CombatEnums
extends RefCounted

# Shared combat enums + JSON string parsers. Pure data, no scene deps.

enum FsmState { IDLE, MOVE, BASIC_ATTACK, CAST_SKILL, STUNNED, DEAD }
enum Archetype { FRONT_DEFENSE, FRONT_CHARGE, MID_MAGIC, AMBUSH, BOMBER, RANGED, SUPPORT, HEALER }
enum Lane { FRONT, MIDDLE, REAR }
enum StatKey { HP, ATK, DEF, CRIT_CHANCE, CRIT_DMG, ATK_SPD, COOLDOWN_REDUCTION, DMG_RESIST, DMG_RESIST_BYPASS, AMPLIFY }
enum ModifierType { FLAT, PERCENT }
enum BattlePhase { INIT, WAVE_SPAWNING, FIGHTING, TRANSITIONING, BOSS_ENCOUNTER, VICTORY, DEFEAT }


static func stat_key_from_string(s: String) -> int:
	match s.to_lower():
		"hp": return StatKey.HP
		"atk": return StatKey.ATK
		"def": return StatKey.DEF
		"crit_chance": return StatKey.CRIT_CHANCE
		"crit_dmg": return StatKey.CRIT_DMG
		"atk_spd": return StatKey.ATK_SPD
		"cooldown_reduction": return StatKey.COOLDOWN_REDUCTION
		"dmg_resist": return StatKey.DMG_RESIST
		"dmg_resist_bypass": return StatKey.DMG_RESIST_BYPASS
		"amplify": return StatKey.AMPLIFY
	return -1


static func archetype_from_string(s: String) -> int:
	match s.to_lower():
		"front_defense": return Archetype.FRONT_DEFENSE
		"front_charge": return Archetype.FRONT_CHARGE
		"mid_magic": return Archetype.MID_MAGIC
		"ambush": return Archetype.AMBUSH
		"bomber": return Archetype.BOMBER
		"ranged": return Archetype.RANGED
		"support": return Archetype.SUPPORT
		"healer": return Archetype.HEALER
	return -1


static func lane_from_string(s: String) -> int:
	match s.to_lower():
		"front": return Lane.FRONT
		"middle": return Lane.MIDDLE
		"rear": return Lane.REAR
	return -1
