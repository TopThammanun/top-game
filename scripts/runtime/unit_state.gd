class_name UnitState
extends RefCounted

var id: String = ""
var display_name: String = ""
var clan_id: String = ""
var enemy_id: String = ""
var party_role: String = ""
var lane: String = ""
var idle_asset: String = ""
var move_asset: String = ""
var modulate_hint: String = ""
var base_hp_max: int = 0
var base_atk: int = 0
var base_def: int = 0
var hp_max: int = 0
var hp_current: int = 0
var atk: int = 0
var def: int = 0
var affinity: String = ""
var alive: bool = true
var starter_position: int = 0


static func from_starter(row: Dictionary, clan: Dictionary):
	var u = new()
	u.id = str(row.get("id", ""))
	u.display_name = str(row.get("display_name", ""))
	u.clan_id = str(row.get("clan_id", ""))
	u.party_role = str(row.get("party_role", ""))
	u.lane = str(row.get("lane", ""))
	u.idle_asset = str(row.get("idle_asset", ""))
	u.move_asset = _move_asset_from_row(row, u.idle_asset)
	u.modulate_hint = ""
	u.starter_position = int(row.get("starter_position", 0))
	u.base_hp_max = int(clan.get("base_hp", 100))
	u.base_atk = int(clan.get("base_atk", 10))
	u.base_def = int(clan.get("base_def", 5))
	u.hp_max = u.base_hp_max
	u.hp_current = u.hp_max
	u.atk = u.base_atk
	u.def = u.base_def
	u.affinity = str(clan.get("affinity", "emberweave"))
	return u


static func from_enemy(row: Dictionary):
	var u = new()
	u.id = str(row.get("id", ""))
	u.enemy_id = u.id
	u.display_name = str(row.get("display_name", ""))
	u.party_role = "enemy"
	u.lane = "enemy"
	u.idle_asset = str(row.get("idle_asset", ""))
	u.move_asset = _move_asset_from_row(row, u.idle_asset)
	u.modulate_hint = str(row.get("modulate_hint", ""))
	u.base_hp_max = int(row.get("base_hp", 40))
	u.base_atk = int(row.get("base_atk", 6))
	u.base_def = int(row.get("base_def", 2))
	u.hp_max = u.base_hp_max
	u.hp_current = u.hp_max
	u.atk = u.base_atk
	u.def = u.base_def
	u.affinity = str(row.get("affinity", "hushweave"))
	return u


static func _move_asset_from_row(row: Dictionary, idle_asset_id: String) -> String:
	var configured := str(row.get("move_asset", ""))
	if configured != "":
		return configured
	if idle_asset_id.ends_with("_idle"):
		return idle_asset_id.replace("_idle", "_move")
	return ""


func take_damage(amount: int) -> int:
	var mitigated: int = max(1, amount - def)
	hp_current = max(0, hp_current - mitigated)
	if hp_current == 0:
		alive = false
	return mitigated


func heal(amount: int) -> int:
	var before := hp_current
	hp_current = min(hp_max, hp_current + amount)
	return hp_current - before
