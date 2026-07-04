extends Control

const BattleEngineClass = preload("res://scripts/runtime/battle_engine.gd")
const TASKBAR_SCENE := "res://scenes/ui/taskbar.tscn"
const MAP_VIEW_SCENE := "res://scenes/maps/emberhearth_map_view.tscn"

var _header_title: Label
var _wave_label: Label
var _currency_label: Label
var _best_wave_label: Label
var _upgrade_label: Label
var _run_status_label: Label
var _loot_feed: VBoxContainer
var _safe_area: MarginContainer
var _feed_panel: PanelContainer
var _map_view                            # EmberhearthMapView
var _taskbar                             # Taskbar
var _battle                              # BattleEngine

var _populated: bool = false


func _ready() -> void:
	_build_shell()
	_battle = BattleEngineClass.new()
	_battle.name = "BattleEngine"
	_battle.damage_dealt.connect(_on_damage_dealt)
	_battle.unit_defeated.connect(_on_unit_defeated)
	_battle.boss_telegraph.connect(_on_boss_telegraph)
	add_child(_battle)

	_wait_for_runtime_ready()


func _wait_for_runtime_ready() -> void:
	if not AssetRegistry.loaded:
		AssetRegistry.catalog_ready.connect(_try_populate, CONNECT_ONE_SHOT)
	if not GameState.is_ready:
		GameState.state_ready.connect(_try_populate, CONNECT_ONE_SHOT)
	_try_populate()


func _try_populate() -> void:
	if _populated:
		return
	if not AssetRegistry.loaded or not GameState.is_ready:
		return
	_populated = true
	_populate()


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.055, 0.067, 0.082)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe_area.add_theme_constant_override("margin_left", 18)
	_safe_area.add_theme_constant_override("margin_top", 16)
	_safe_area.add_theme_constant_override("margin_right", 18)
	_safe_area.add_theme_constant_override("margin_bottom", 14)
	add_child(_safe_area)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	_safe_area.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	_header_title = _make_label("TBH: Whisker Realm", 18)
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_title.clip_text = true
	header.add_child(_header_title)

	_currency_label = _make_label("0 PC", 14)
	header.add_child(_currency_label)

	_wave_label = _make_label("W1/10", 14)
	header.add_child(_wave_label)

	_best_wave_label = _make_label("Best 1", 12)
	header.add_child(_best_wave_label)

	_upgrade_label = _make_label("Rw+0", 12)
	header.add_child(_upgrade_label)

	_run_status_label = _make_label("Loading...", 12)
	_run_status_label.modulate = Color(0.75, 0.85, 0.95)
	layout.add_child(_run_status_label)

	_feed_panel = PanelContainer.new()
	_feed_panel.name = "LootFeedPanel"
	_feed_panel.custom_minimum_size = Vector2(0, 42)
	_feed_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.075, 0.085, 0.10)))
	layout.add_child(_feed_panel)

	var feed_margin := MarginContainer.new()
	feed_margin.add_theme_constant_override("margin_left", 10)
	feed_margin.add_theme_constant_override("margin_top", 6)
	feed_margin.add_theme_constant_override("margin_right", 10)
	feed_margin.add_theme_constant_override("margin_bottom", 6)
	_feed_panel.add_child(feed_margin)

	_loot_feed = VBoxContainer.new()
	_loot_feed.name = "LootFeed"
	_loot_feed.add_theme_constant_override("separation", 2)
	feed_margin.add_child(_loot_feed)

	_map_view = load(MAP_VIEW_SCENE).instantiate()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_map_view)

	_taskbar = load(TASKBAR_SCENE).instantiate()
	_taskbar.command_pressed.connect(_on_command_pressed)
	layout.add_child(_taskbar)


func _populate() -> void:
	_refresh_header()
	if GameState.wave_state != null:
		_map_view.render(GameState.party, GameState.wave_state.enemies)
	_render_event_feed()
	_set_status("Auto-battle running. Use Burst, Heal, AFK Chest, Upgrade, or Replay.", Color(0.75, 0.85, 0.95))
	GameState.party_changed.connect(_on_party_changed)
	GameState.wave_changed.connect(_on_wave_changed)
	GameState.currency_changed.connect(_on_currency_changed)
	GameState.progression_changed.connect(_on_progression_changed)
	GameState.loot_event.connect(_on_loot_event)
	GameState.run_ended.connect(_on_run_ended)
	GameState.start_run()
	_battle.start()


func _on_party_changed() -> void:
	if _map_view != null:
		_map_view.refresh_hp()
	_refresh_header()


func _on_wave_changed(wave_number: int) -> void:
	_refresh_header()
	if GameState.wave_state != null and _map_view != null:
		_map_view.render(GameState.party, GameState.wave_state.enemies)
	if wave_number == GameState.MAX_WAVE:
		_set_status("Boss wave: Hollowmew Captain is ahead.", Color(0.95, 0.78, 1.0))


func _on_currency_changed(_new_value: int) -> void:
	_refresh_header()
	_pulse_control(_currency_label, Color(0.92, 0.70, 0.18))


func _on_progression_changed() -> void:
	_refresh_header()


func _on_loot_event(message: String) -> void:
	_render_event_feed()
	_pulse_control(_feed_panel, Color(0.38, 0.30, 0.12))
	if message.contains("+"):
		_play_reward_burst(message)


func _on_damage_dealt(source_id: String, target_id: String, amount: int) -> void:
	if _map_view != null:
		if amount < 0:
			_map_view.play_heal(target_id, abs(amount))
		else:
			_map_view.play_attack(source_id, target_id)
			_map_view.play_hit(target_id, amount)
			_screen_bump(1.5)
		_map_view.refresh_hp()


func _on_unit_defeated(unit_id: String) -> void:
	if _map_view != null:
		_map_view.refresh_hp()
	_set_status("Defeated: %s" % _display_name_for_unit(unit_id), Color(0.88, 0.82, 0.65))


func _on_boss_telegraph(message: String) -> void:
	_set_status(message, Color(1.0, 0.72, 0.95))
	_pulse_control(_run_status_label, Color(0.55, 0.18, 0.58))
	if _map_view != null:
		_map_view.play_boss_warning()
	_screen_bump(4.0)


func _on_run_ended(status: String) -> void:
	if status == "won":
		_set_status("Victory! Boss chest claimed. Upgrade, then Replay stronger.", Color(0.7, 0.95, 0.7))
		_play_reward_burst("Boss chest!")
		_map_view.play_reward_burst("Boss chest!")
		_screen_bump(2.0)
	elif status == "wiped":
		_set_status("Party wiped. Claim AFK Chest, Upgrade, then Replay.", Color(0.95, 0.7, 0.6))
		_pulse_control(_run_status_label, Color(0.5, 0.14, 0.10))


func _on_command_pressed(id: String) -> void:
	_taskbar.play_command_feedback(id, _command_feedback_color(id))
	match id:
		"skill_1":
			_battle.trigger_skill_1_wildstripe_burst()
			_taskbar.start_cooldown("skill_1", 12.0)
			_map_view.play_skill_pulse("skill_1")
			_set_status("Wildstripe burst active (3s): party attacks x2.", Color(0.95, 0.85, 0.6))
			_pulse_control(_run_status_label, Color(0.38, 0.28, 0.08))
		"skill_2":
			_battle.trigger_skill_2_cloudfur_heal()
			_taskbar.start_cooldown("skill_2", 10.0)
			_map_view.play_skill_pulse("skill_2")
			_set_status("Cloudfur heal cast: party recovered.", Color(0.75, 0.95, 0.75))
			_pulse_control(_run_status_label, Color(0.08, 0.30, 0.13))
		"afk_chest":
			var reward := GameState.claim_afk_chest()
			if reward > 0:
				_set_status("Claimed AFK chest: +%d Pawcoins." % reward, Color(0.95, 0.9, 0.55))
				_play_reward_burst("+%d Pawcoins" % reward)
				_map_view.play_reward_burst("+%d Pawcoins" % reward)
			else:
				_set_status("AFK chest is still filling.", Color(0.8, 0.82, 0.9))
		"upgrade":
			_try_upgrade()
		"replay":
			GameState.start_run()
			_battle.start()
			_set_status("Replay started at Reweave +%d." % GameState.upgrade_level, Color(0.8, 0.92, 1.0))
			_pulse_control(_wave_label, Color(0.12, 0.24, 0.34))
		"inventory":
			_set_status("Inventory opens in a later equipment slice.", Color(0.75, 0.75, 0.85))
		"quest":
			_set_status("Quest log is tracking Emberhearth prototype goals.", Color(0.75, 0.75, 0.85))
		_:
			print("[taskbar] pressed: %s" % id)


func _try_upgrade() -> void:
	var result := GameState.try_buy_upgrade()
	if not bool(result.get("ok", false)):
		_set_status("Need %d Pawcoins to reweave (have %d)." % [
			int(result.get("cost", 0)),
			int(result.get("currency", 0))
		], Color(0.85, 0.7, 0.65))
		return

	_set_status("Party reweave +%d purchased for %d Pawcoins." % [
		int(result.get("upgrade_level", 0)),
		int(result.get("cost", 0))
	], Color(0.75, 0.95, 0.75))
	_pulse_control(_upgrade_label, Color(1.0, 0.48, 0.22))
	if _map_view != null:
		_map_view.play_skill_pulse("skill_1")
	if GameState.run_status != "running":
		GameState.start_run()
		_battle.start()


func _refresh_header() -> void:
	if _wave_label != null:
		_wave_label.text = "W%d/%d" % [GameState.wave, GameState.MAX_WAVE]
	if _currency_label != null:
		_currency_label.text = "%d PC" % GameState.currency
	if _best_wave_label != null:
		_best_wave_label.text = "Best %d" % GameState.best_wave
	if _upgrade_label != null:
		_upgrade_label.text = "Rw+%d" % GameState.upgrade_level


func _render_event_feed() -> void:
	if _loot_feed == null:
		return
	for child in _loot_feed.get_children():
		child.queue_free()
	if GameState.recent_events.is_empty():
		_loot_feed.add_child(_make_label("Loot feed ready.", 10))
		return
	var shown: int = min(3, GameState.recent_events.size())
	for i in range(shown):
		var event_text := str(GameState.recent_events[i])
		var label := _make_label(event_text, 10)
		label.modulate = Color(0.88, 0.84, 0.70)
		_loot_feed.add_child(label)


func _display_name_for_unit(unit_id: String) -> String:
	var unit = GameState.get_unit_by_id(unit_id)
	if unit != null:
		return unit.display_name
	if GameState.wave_state != null:
		for enemy in GameState.wave_state.enemies:
			if enemy.id == unit_id:
				return enemy.display_name
	return unit_id


func _set_status(text: String, color: Color) -> void:
	_run_status_label.text = text
	_run_status_label.modulate = color


func _command_feedback_color(id: String) -> Color:
	match id:
		"skill_1":
			return Color(1.0, 0.74, 0.24)
		"skill_2":
			return Color(0.45, 1.0, 0.58)
		"afk_chest":
			return Color(1.0, 0.82, 0.30)
		"upgrade":
			return Color(1.0, 0.46, 0.22)
		"replay":
			return Color(0.55, 0.78, 1.0)
		_:
			return Color(0.85, 0.82, 0.72)


func _pulse_control(control: Control, color: Color) -> void:
	if control == null:
		return
	var original_modulate := control.modulate
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", color.lightened(0.25), 0.08)
	tween.tween_property(control, "modulate", original_modulate, 0.22)


func _screen_bump(strength: float) -> void:
	if _safe_area == null:
		return
	var start_position := _safe_area.position
	var tween := create_tween()
	tween.tween_property(_safe_area, "position", start_position + Vector2(strength, 0), 0.035)
	tween.tween_property(_safe_area, "position", start_position - Vector2(strength, 0), 0.035)
	tween.tween_property(_safe_area, "position", start_position, 0.045)


func _play_reward_burst(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color(1.0, 0.78, 0.24)
	var viewport_size := get_viewport_rect().size
	label.position = Vector2(max(36.0, viewport_size.x - 320.0), 116.0)
	label.scale = Vector2(0.7, 0.7)
	add_child(label)
	label.move_to_front()
	var start_position := label.position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.14)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.42)
	tween.tween_property(label, "position", start_position + Vector2(0, -26), 0.26)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.26)
	tween.tween_callback(label.queue_free)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(0.94, 0.90, 0.80)
	return label


func _make_panel_style(bg_color: Color, shortcut: String = "") -> StyleBox:
	if not shortcut.is_empty() and AssetRegistry.loaded and AssetRegistry.has_asset(shortcut):
		var tex := AssetRegistry.load_texture(shortcut)
		if tex != null:
			var texture_style := StyleBoxTexture.new()
			texture_style.texture = tex
			texture_style.set_texture_margin_all(8)
			texture_style.set_content_margin_all(8)
			texture_style.draw_center = true
			return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.33, 0.27, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
