class_name WaveState
extends RefCounted

const UnitStateClass = preload("res://scripts/runtime/unit_state.gd")

var wave: int = 0
var type: String = ""
var goal: String = ""
var reward_id: String = ""
var enemies: Array = []              # Array of UnitState


static func empty():
	return new()


static func for_wave(wave_number: int, waves_catalog: Array, enemies_by_id: Dictionary):
	var ws = new()
	ws.wave = wave_number
	for row in waves_catalog:
		if int(row.get("wave", -1)) == wave_number:
			ws.type = str(row.get("type", ""))
			ws.goal = str(row.get("goal", ""))
			ws.reward_id = str(row.get("reward", ""))
			var spawn_index: int = 0
			for enemy_id in row.get("enemies", []):
				var enemy_row = enemies_by_id.get(str(enemy_id))
				if enemy_row == null:
					push_error("Wave %d references unknown enemy id: %s" % [wave_number, enemy_id])
					continue
				spawn_index += 1
				var enemy = UnitStateClass.from_enemy(enemy_row)
				enemy.id = "%s_%02d" % [enemy.enemy_id, spawn_index]
				ws.enemies.append(enemy)
			return ws
	push_error("Wave not found in catalog: %d" % wave_number)
	return ws


func all_defeated() -> bool:
	if enemies.is_empty():
		return true
	for e in enemies:
		if e.alive:
			return false
	return true


func alive_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if e.alive:
			out.append(e)
	return out
