class_name BattleEngine
extends Node

signal tick_processed
signal damage_dealt(source_id: String, target_id: String, amount: int)
signal unit_defeated(unit_id: String)
signal skill_used(skill_id: String)
signal boss_telegraph(message: String)

const PARTY_TICK_SECONDS := 1.4
const ENEMY_TICK_SECONDS := 1.9

var _party_timer: Timer
var _enemy_timer: Timer
var _rng := RandomNumberGenerator.new()
var _telegraphed_wave: int = 0

# Slice-3 buffs kept simple — flat scalar on next N basic attacks
var _party_damage_multiplier: float = 1.0
var _party_damage_buff_remaining: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_party_timer = _make_timer(PARTY_TICK_SECONDS, _on_party_tick)
	_enemy_timer = _make_timer(ENEMY_TICK_SECONDS, _on_enemy_tick)
	add_child(_party_timer)
	add_child(_enemy_timer)


func start() -> void:
	if GameState.wave <= 1:
		_telegraphed_wave = 0
	_party_timer.start()
	_enemy_timer.start()


func stop() -> void:
	_party_timer.stop()
	_enemy_timer.stop()


func _process(delta: float) -> void:
	if _party_damage_buff_remaining > 0.0:
		_party_damage_buff_remaining -= delta
		if _party_damage_buff_remaining <= 0.0:
			_party_damage_buff_remaining = 0.0
			_party_damage_multiplier = 1.0


func trigger_skill_1_wildstripe_burst() -> void:
	# 100% damage buff for 3 seconds on all party basic attacks
	_party_damage_multiplier = 2.0
	_party_damage_buff_remaining = 3.0
	skill_used.emit("skill_1")


func trigger_skill_2_cloudfur_heal() -> void:
	for u in GameState.alive_party():
		var amount: int = int(u.hp_max * 0.25)
		u.heal(amount)
		damage_dealt.emit("skill_heal", u.id, -amount)
	skill_used.emit("skill_2")
	GameState.party_changed.emit()


func _on_party_tick() -> void:
	if GameState.run_status != "running":
		return
	if GameState.wave_state == null:
		return
	var alive_enemies: Array = GameState.wave_state.alive_enemies()
	if alive_enemies.is_empty():
		return
	for hero in GameState.alive_party():
		var target = _lowest_hp(alive_enemies)
		if target == null:
			break
		var raw: int = int(round(hero.atk * _party_damage_multiplier))
		var dealt: int = target.take_damage(raw)
		damage_dealt.emit(hero.id, target.id, dealt)
		if not target.alive:
			unit_defeated.emit(target.id)
			alive_enemies = GameState.wave_state.alive_enemies()
			if alive_enemies.is_empty():
				break
	tick_processed.emit()
	_check_end_conditions()


func _on_enemy_tick() -> void:
	if GameState.run_status != "running":
		return
	if GameState.wave_state == null:
		return
	if _maybe_pause_for_boss_telegraph():
		tick_processed.emit()
		return
	var alive_heroes: Array = GameState.alive_party()
	if alive_heroes.is_empty():
		return
	for enemy in GameState.wave_state.alive_enemies():
		var target = _pick_hero_target(alive_heroes)
		if target == null:
			break
		var dealt: int = target.take_damage(enemy.atk)
		damage_dealt.emit(enemy.id, target.id, dealt)
		if not target.alive:
			unit_defeated.emit(target.id)
			alive_heroes = GameState.alive_party()
			if alive_heroes.is_empty():
				break
	tick_processed.emit()
	_check_end_conditions()


func _maybe_pause_for_boss_telegraph() -> bool:
	if GameState.wave != GameState.MAX_WAVE:
		return false
	if _telegraphed_wave == GameState.wave:
		return false
	if GameState.wave_state.alive_enemies().is_empty():
		return false
	_telegraphed_wave = GameState.wave
	boss_telegraph.emit("Hollowmew gathers Hushweave - heal or burst before the strike.")
	return true


func _pick_hero_target(alive_heroes: Array):
	# prefer front lane, then middle, then rear
	for lane in ["front", "front_middle", "middle", "rear"]:
		for h in alive_heroes:
			if h.lane == lane:
				return h
	return alive_heroes[0] if alive_heroes.size() > 0 else null


func _lowest_hp(units: Array):
	var best = null
	for u in units:
		if best == null or u.hp_current < best.hp_current:
			best = u
	return best


func _check_end_conditions() -> void:
	if GameState.wave_state != null and GameState.wave_state.all_defeated():
		GameState.mark_wave_cleared()
		if GameState.run_status == "won":
			stop()
		return
	if GameState.alive_party().is_empty():
		GameState.mark_wipe()
		stop()


func _make_timer(interval: float, cb: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = interval
	t.autostart = false
	t.one_shot = false
	t.timeout.connect(cb)
	return t
