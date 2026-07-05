class_name CharacterFactory
extends RefCounted

# Pure-logic bridge: JSON (clans/enemies/archetypes/skills) -> battle-ready
# profiles. No scene deps. Cross-references combat classes via preload consts
# (see agents/sage/godot-runtime/decisions/headless-global-class-cache.md).

const CombatEnumsClass = preload("res://scripts/combat/combat_enums.gd")
const StatSystemClass = preload("res://scripts/combat/stat_system.gd")
const CombatSkillClass = preload("res://scripts/combat/combat_skill.gd")

const ARCHETYPES_PATH := "res://data/combat/archetypes.json"
const SKILLS_PATH := "res://data/combat/skills.json"
const CLANS_PATH := "res://data/units/clans.json"
const ENEMIES_PATH := "res://data/combat/enemies.json"

var _archetypes: Dictionary = {}
var _skills: Dictionary = {}
var _clans: Dictionary = {}
var _enemies: Dictionary = {}


func load_all() -> void:
	_archetypes = _index(_read_array(ARCHETYPES_PATH), "archetype")
	_skills = _index(_read_array(SKILLS_PATH), "id")
	_clans = _index(_read_array(CLANS_PATH), "id")
	_enemies = _index(_read_array(ENEMIES_PATH), "id")


func archetype_ids() -> Array:
	return _archetypes.keys()


func clan_ids() -> Array:
	return _clans.keys()


func enemy_ids() -> Array:
	return _enemies.keys()


func has_clan(id: String) -> bool:
	return _clans.has(id)


func has_enemy(id: String) -> bool:
	return _enemies.has(id)


func build_from_clan(clan_id: String) -> Dictionary:
	return _build(_clans.get(clan_id, {}))


func build_from_enemy(enemy_id: String) -> Dictionary:
	return _build(_enemies.get(enemy_id, {}))


func _build(row: Dictionary) -> Dictionary:
	var arch_id := str(row.get("archetype", "front_charge"))
	var arch: Dictionary = _archetypes.get(arch_id, {})
	var weights: Dictionary = arch.get("weights", {})

	var S := CombatEnumsClass.StatKey
	var base_hp := float(row.get("base_hp", 100.0)) * float(weights.get("hp", 1.0))
	var base_atk := float(row.get("base_atk", 10.0)) * float(weights.get("atk", 1.0))
	var base_def := float(row.get("base_def", 5.0)) * float(weights.get("def", 1.0))
	var base_stats := {
		S.HP: round(base_hp), S.ATK: round(base_atk), S.DEF: round(base_def),
	}
	for src in [arch.get("advanced", {}), row.get("advanced", {})]:
		for key in src:
			var sk: int = CombatEnumsClass.stat_key_from_string(str(key))
			if sk != -1:
				base_stats[sk] = float(src[key])

	var stats := StatSystemClass.new(base_stats)

	var skill = null
	var skill_id := str(row.get("skill_id", ""))
	if skill_id != "" and _skills.has(skill_id):
		skill = CombatSkillClass.new(_skills[skill_id])

	return {
		"stats": stats,
		"archetype": CombatEnumsClass.archetype_from_string(arch_id),
		"lane": CombatEnumsClass.lane_from_string(str(arch.get("lane", "front"))),
		"attack_range": float(arch.get("attack_range", 100.0)),
		"move_speed": float(arch.get("move_speed", 70.0)),
		"idle_shortcut": str(arch.get("idle_shortcut", "")),
		"move_shortcut": str(arch.get("move_shortcut", "")),
		"skill": skill,
	}


func _index(rows: Array, key: String) -> Dictionary:
	var out: Dictionary = {}
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and r.has(key):
			out[str(r[key])] = r
	return out


func _read_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("CharacterFactory: missing data file %s" % path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_ARRAY else []
