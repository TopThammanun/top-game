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
	# Past the authored catalog: generate procedurally (endless mode).
	return _procedural(wave_number, enemies_by_id)


static func _procedural(wave_number: int, enemies_by_id: Dictionary):
	var ws = new()
	ws.wave = wave_number
	var is_boss: bool = wave_number % 5 == 0
	var comp: Array = []
	if is_boss:
		ws.type = "boss"
		comp.append("hollowmew_captain")
		var grunts: int = 2 + int(wave_number / 10)
		for i in grunts:
			comp.append("tangleborn_yarnling")
	else:
		ws.type = "endless"
		var count: int = 3 + int(wave_number / 2)
		for i in count:
			comp.append("tangleborn_snarlbeast" if i % 3 == 0 else "tangleborn_yarnling")
	var spawn_index: int = 0
	for enemy_id in comp:
		var enemy_row = enemies_by_id.get(str(enemy_id))
		if enemy_row == null:
			continue
		spawn_index += 1
		var enemy = UnitStateClass.from_enemy(enemy_row)
		enemy.id = "%s_%02d" % [enemy.enemy_id, spawn_index]
		ws.enemies.append(enemy)
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
