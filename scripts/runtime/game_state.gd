extends Node

const UnitStateClass = preload("res://scripts/runtime/unit_state.gd")
const WaveStateClass = preload("res://scripts/runtime/wave_state.gd")

signal state_ready
signal party_changed
signal wave_changed(wave: int)
signal wave_cleared(wave: int)
signal run_ended(status: String)
signal currency_changed(new_value: int)
signal progression_changed
signal loot_event(message: String)
signal save_changed

const CLANS_PATH := "res://data/units/clans.json"
const STARTER_PARTY_PATH := "res://data/units/starter_party.json"
const ENEMIES_PATH := "res://data/combat/enemies.json"
const WAVES_PATH := "res://data/combat/mvp_waves.json"
const MAX_WAVE := 10
const CURRENT_SAVE_SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"
const STARTER_AFK_GRACE_SECONDS := 300
const AFK_REWARD_PER_MINUTE := 12
const AFK_REWARD_CAP := 240
const BASE_UPGRADE_COST := 25
const UPGRADE_COST_STEP := 15
const UPGRADE_ATK_STEP := 1
const UPGRADE_HP_STEP := 5

var is_ready: bool = false
var party: Array = []                # Array of UnitState
var wave: int = 1
var wave_state = null                # WaveState
var currency: int = 0
var best_wave: int = 1
var upgrade_level: int = 0
var last_afk_unix: int = 0
var run_status: String = "idle"      # idle | running | won | wiped
var recent_events: Array = []
var save_path: String = DEFAULT_SAVE_PATH

var _clans_by_id: Dictionary = {}
var _enemies_by_id: Dictionary = {}
var _waves_catalog: Array = []


func _ready() -> void:
	if AssetRegistry.loaded:
		_bootstrap_state()
	else:
		AssetRegistry.catalog_ready.connect(_bootstrap_state, CONNECT_ONE_SHOT)


func _bootstrap_state() -> void:
	if is_ready:
		return
	_load_clans()
	_load_enemies()
	_load_waves_catalog()
	load_save()
	_load_party()
	_load_wave(1)
	if party.size() < 1:
		push_warning("Party bootstrapped empty; a run must seed a starter cat")
	best_wave = max(best_wave, wave)
	is_ready = true
	state_ready.emit()


func _load_clans() -> void:
	_clans_by_id.clear()
	for row in _read_json_array(CLANS_PATH):
		if row.has("id"):
			_clans_by_id[str(row["id"])] = row


func _load_enemies() -> void:
	_enemies_by_id.clear()
	for row in _read_json_array(ENEMIES_PATH):
		if row.has("id"):
			_enemies_by_id[str(row["id"])] = row


func _load_waves_catalog() -> void:
	_waves_catalog = _read_json_array(WAVES_PATH)


func _load_party() -> void:
	party.clear()
	for row in _read_json_array(STARTER_PARTY_PATH):
		var clan_id := str(row.get("clan_id", ""))
		if not _clans_by_id.has(clan_id):
			push_error("Starter unit %s references unknown clan_id: %s" % [row.get("id", "?"), clan_id])
			continue
		party.append(UnitStateClass.from_starter(row, _clans_by_id[clan_id]))
	_apply_upgrade_bonus_to_party(true)
	party_changed.emit()


func _load_wave(n: int) -> void:
	wave = n
	wave_state = WaveStateClass.for_wave(n, _waves_catalog, _enemies_by_id)
	wave_changed.emit(n)


func start_run() -> void:
	if not is_ready:
		return
	reset_run()
	run_status = "running"
	_push_event("Run started: Wave 1")


func advance_to_wave(n: int) -> void:
	_load_wave(n)


func add_currency(delta: int) -> void:
	currency = max(0, currency + delta)
	currency_changed.emit(currency)


func reset_run() -> void:
	_apply_upgrade_bonus_to_party(true)
	for u in party:
		u.hp_current = u.hp_max
		u.alive = true
	_load_wave(1)
	run_status = "idle"
	party_changed.emit()


func get_unit_by_id(id: String):
	for u in party:
		if u.id == id:
			return u
	return null


func alive_party() -> Array:
	var out: Array = []
	for u in party:
		if u.alive:
			out.append(u)
	return out


func mark_wave_cleared() -> void:
	wave_cleared.emit(wave)
	best_wave = max(best_wave, wave)
	progression_changed.emit()
	var reward := _reward_soft_currency_for(wave)
	add_currency(reward)
	if wave >= MAX_WAVE:
		run_status = "won"
		_push_event("Boss chest opened: +%d Pawcoins" % reward)
		save_game()
		run_ended.emit("won")
		return
	_push_event("Wave %d cleared: +%d Pawcoins" % [wave, reward])
	save_game()
	advance_to_wave(wave + 1)


func mark_wipe() -> void:
	run_status = "wiped"
	best_wave = max(best_wave, wave)
	progression_changed.emit()
	_push_event("Party wiped on wave %d. Upgrade and replay." % wave)
	save_game()
	run_ended.emit("wiped")


func upgrade_cost() -> int:
	return BASE_UPGRADE_COST + (upgrade_level * UPGRADE_COST_STEP)


func try_buy_upgrade() -> Dictionary:
	var cost := upgrade_cost()
	if currency < cost:
		return {
			"ok": false,
			"reason": "not_enough_currency",
			"cost": cost,
			"currency": currency
		}

	add_currency(-cost)
	upgrade_level += 1
	_apply_upgrade_bonus_to_party(false)
	party_changed.emit()
	progression_changed.emit()
	_push_event("Party reweave +1: ATK +%d, HP +%d" % [UPGRADE_ATK_STEP, UPGRADE_HP_STEP])
	save_game()
	return {
		"ok": true,
		"cost": cost,
		"upgrade_level": upgrade_level
	}


func claim_afk_chest() -> int:
	var now := _now_unix()
	var elapsed: int = max(0, now - last_afk_unix)
	var reward := _afk_reward_for_elapsed(elapsed)
	last_afk_unix = now
	if reward > 0:
		add_currency(reward)
		_push_event("AFK chest claimed: +%d Pawcoins" % reward)
	else:
		_push_event("AFK chest is still filling.")
	save_game()
	return reward


func snapshot() -> Dictionary:
	return {
		"schema_version": CURRENT_SAVE_SCHEMA_VERSION,
		"currency": currency,
		"best_wave": best_wave,
		"upgrade_level": upgrade_level,
		"last_afk_unix": last_afk_unix
	}


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save for write: %s (error %s)" % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	save_changed.emit()
	return true


func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		_seed_new_save_clock()
		return

	var text := FileAccess.get_file_as_string(save_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is not a JSON object: %s" % save_path)
		_seed_new_save_clock()
		return

	var schema_version := int(parsed.get("schema_version", 0))
	if schema_version > CURRENT_SAVE_SCHEMA_VERSION:
		push_warning("Save file schema %d is newer than supported schema %d" % [
			schema_version,
			CURRENT_SAVE_SCHEMA_VERSION
		])
		_seed_new_save_clock()
		return

	currency = max(0, int(parsed.get("currency", 0)))
	best_wave = max(1, int(parsed.get("best_wave", 1)))
	upgrade_level = max(0, int(parsed.get("upgrade_level", 0)))
	last_afk_unix = int(parsed.get("last_afk_unix", 0))
	if last_afk_unix <= 0:
		_seed_new_save_clock()


func _apply_upgrade_bonus_to_party(restore_full: bool) -> void:
	for u in party:
		var old_max: int = u.hp_max
		u.atk = u.base_atk + (upgrade_level * UPGRADE_ATK_STEP)
		u.hp_max = u.base_hp_max + (upgrade_level * UPGRADE_HP_STEP)
		if restore_full:
			u.hp_current = u.hp_max
		else:
			var gained_hp: int = max(0, u.hp_max - old_max)
			u.hp_current = min(u.hp_max, u.hp_current + gained_hp)


func _push_event(message: String) -> void:
	recent_events.push_front(message)
	while recent_events.size() > 5:
		recent_events.pop_back()
	loot_event.emit(message)


func _afk_reward_for_elapsed(seconds: int) -> int:
	var minutes := int(floor(float(seconds) / 60.0))
	if minutes <= 0:
		return 0
	return min(AFK_REWARD_CAP, minutes * AFK_REWARD_PER_MINUTE)


func _seed_new_save_clock() -> void:
	last_afk_unix = _now_unix() - STARTER_AFK_GRACE_SECONDS


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _reward_soft_currency_for(w: int) -> int:
	# simple scale: wave * 10 + boss bonus
	if w >= MAX_WAVE:
		return 200
	return 10 * w


func get_clan_row(clan_id: String):
	return _clans_by_id.get(clan_id)


func _party_has_clan(clan_id: String) -> bool:
	for u in party:
		if u.clan_id == clan_id:
			return true
	return false


func seed_run_party(clan_id: String) -> void:
	party.clear()
	if _clans_by_id.has(clan_id):
		party.append(UnitStateClass.from_clan(_clans_by_id[clan_id]))
	else:
		push_error("seed_run_party: unknown clan_id %s" % clan_id)
	_apply_upgrade_bonus_to_party(true)
	party_changed.emit()


func recruit_member(clan_id: String) -> bool:
	if _clans_by_id.has(clan_id) and not _party_has_clan(clan_id):
		party.append(UnitStateClass.from_clan(_clans_by_id[clan_id]))
		_apply_upgrade_bonus_to_party(false)
		party_changed.emit()
		return true
	return false


func end_run(result: String, reward: int) -> void:
	run_status = result
	best_wave = max(best_wave, wave)
	add_currency(max(0, reward))
	progression_changed.emit()
	save_game()
	run_ended.emit(result)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Data file missing: %s" % path)
		return []
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Data file is not a JSON array: %s" % path)
		return []
	return parsed
