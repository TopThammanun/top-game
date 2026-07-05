class_name EmberhearthMapView
extends PanelContainer

signal unit_selected(unit_id: String)

const ENEMY_RED := Color(1.0, 0.55, 0.55)
const BOSS_PURPLE := Color(0.75, 0.55, 1.0)
const HERO_TINT := Color.WHITE
const PLACEHOLDER := Color(0.4, 0.15, 0.15)
const MAP_PLAN_PATH := "res://data/maps/emberhearth_map_plan.json"
const DAMAGE_COLOR := Color(1.0, 0.34, 0.24)
const HEAL_COLOR := Color(0.35, 1.0, 0.62)
const REWARD_COLOR := Color(1.0, 0.78, 0.24)
const BOSS_WARNING_COLOR := Color(0.92, 0.45, 1.0)
const UNIT_CELL_SIZE := Vector2(94, 104)
const UNIT_PORTRAIT_SIZE := Vector2(70, 64)
const UNIT_SPRITE_SIZE := Vector2(64, 64)
const UNIT_STEP := 88.0
const UNIT_ANIMATION_ROW := 1
const IDLE_FRAME_SECONDS := 0.22
const WALK_FRAME_SECONDS := 0.12
const MELEE_CONTACT_OVERLAP := 18.0
const MELEE_WALK_PIXELS_PER_SECOND := 720.0
const MELEE_MIN_WALK_SECONDS := 0.34
const MELEE_MAX_WALK_SECONDS := 0.72
const MELEE_STRIKE_SECONDS := 0.12
const RANGED_PROJECTILE_SECONDS := 0.24
const PARTY_SPRITES_FLIP_H := true
const ENEMY_SPRITES_FLIP_H := true

var _map_grid: GridContainer
var _region_label: Label
var _wave_goal_label: Label
var _effects_layer: Control
var _stage: Control
var _unit_layer: Control
var _lane_shadow: ColorRect
var _party_tag: Label
var _enemy_tag: Label
var _cells_by_unit_id: Dictionary = {}
var _map_plan: Dictionary = {}
var _party_units: Array = []
var _enemy_units: Array = []
var _map_pixel_size := Vector2.ZERO
var _lane_positions_by_unit_id: Dictionary = {}
var _attack_tweens_by_unit_id: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	add_theme_stylebox_override("panel", _panel_style("", Color(0.11, 0.13, 0.15), 2))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_effects_layer = Control.new()
	_effects_layer.name = "EffectsLayer"
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_layer.custom_minimum_size = Vector2.ZERO
	_effects_layer.size = Vector2.ZERO
	add_child(_effects_layer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	_region_label = _label("Emberhearth · Pawmont", 18, Color(0.94, 0.90, 0.80))
	column.add_child(_region_label)

	_wave_goal_label = _label("", 11, Color(0.75, 0.72, 0.60))
	column.add_child(_wave_goal_label)

	_stage = Control.new()
	_stage.name = "BattleStripStage"
	_stage.clip_contents = false
	_stage.custom_minimum_size = Vector2(896, 340)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.resized.connect(_layout_stage)
	column.add_child(_stage)

	_map_grid = GridContainer.new()
	_map_grid.name = "TileGrid"
	_map_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_grid.add_theme_constant_override("h_separation", 0)
	_map_grid.add_theme_constant_override("v_separation", 0)
	_stage.add_child(_map_grid)

	_lane_shadow = ColorRect.new()
	_lane_shadow.name = "BattleLane"
	_lane_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lane_shadow.color = Color(0.06, 0.05, 0.05, 0.34)
	_stage.add_child(_lane_shadow)

	_party_tag = _label("Party", 12, Color(0.90, 0.90, 0.76))
	_party_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_party_tag)

	_enemy_tag = _label("Monsters", 12, Color(0.95, 0.76, 0.72))
	_enemy_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_enemy_tag)

	_unit_layer = Control.new()
	_unit_layer.name = "UnitLayer"
	_unit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_layer.clip_contents = false
	_stage.add_child(_unit_layer)

	set_process(true)


func render(party: Array, enemies: Array) -> void:
	if not is_inside_tree():
		return
	_map_plan = _load_map_plan()
	_render_tile_map()
	if GameState.wave_state != null:
		_wave_goal_label.text = "Wave %d · %s · %s" % [
			GameState.wave,
			GameState.wave_state.type,
			GameState.wave_state.goal
		]
	_cells_by_unit_id.clear()
	_lane_positions_by_unit_id.clear()
	_party_units = party
	_enemy_units = enemies
	_fill_units(party)
	_fill_units(enemies)
	_layout_stage()
	call_deferred("_layout_stage")


func _process(delta: float) -> void:
	if _cells_by_unit_id.is_empty():
		return
	for unit_id in _cells_by_unit_id.keys():
		var sprite := _sprite_for_unit(str(unit_id))
		if sprite != null:
			_advance_sprite_animation(sprite, delta)


func refresh_hp() -> void:
	for unit_id in _cells_by_unit_id.keys():
		var cell: Control = _cells_by_unit_id[unit_id]
		var u = _find_unit(unit_id)
		if u == null or not is_instance_valid(cell):
			continue
		_paint_cell_hp(cell, u)


func play_attack(source_id: String, target_id: String) -> void:
	var source_cell := _cell_for_unit(source_id)
	var source_sprite := _sprite_for_unit(source_id)
	if source_sprite == null:
		return
	var target_cell := _cell_for_unit(target_id)
	if source_cell != null and target_cell != null and _is_melee_unit(source_id):
		_play_melee_attack(source_id, target_id, source_cell, source_sprite, target_cell)
		return

	_play_ranged_attack(source_id, target_id, source_sprite, target_cell)


func _play_melee_attack(
	source_id: String,
	target_id: String,
	source_cell: Control,
	source_sprite: TextureRect,
	target_cell: Control
) -> void:
	_cancel_attack_tween(source_id)

	var return_position := _lane_position_for_unit(source_id, source_cell.position)
	var source_center := source_cell.position + (UNIT_CELL_SIZE * 0.5)
	var target_center := target_cell.position + (UNIT_CELL_SIZE * 0.5)
	var direction: float = sign(target_center.x - source_center.x)
	if direction == 0.0:
		direction = 1.0

	var max_x: float = max(0.0, _stage.size.x - UNIT_CELL_SIZE.x)
	var contact_gap: float = UNIT_CELL_SIZE.x - MELEE_CONTACT_OVERLAP
	var approach_x: float = clamp(target_cell.position.x - (direction * contact_gap), 0.0, max_x)
	var approach_position := Vector2(approach_x, return_position.y - 2.0)
	var approach_seconds := _walk_duration(source_cell.position.distance_to(approach_position))
	var return_seconds := _walk_duration(approach_position.distance_to(return_position))

	_set_unit_animation(source_id, "move")
	source_cell.z_index = 20
	var tween := create_tween()
	_attack_tweens_by_unit_id[source_id] = tween
	tween.tween_property(source_cell, "position", approach_position, approach_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_set_unit_animation.bind(source_id, "idle"))
	tween.tween_property(source_sprite, "scale", Vector2(1.16, 1.16), MELEE_STRIKE_SECONDS * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_spawn_spark_at_unit.bind(target_id, Color(1.0, 0.84, 0.38), 18.0))
	tween.tween_property(source_sprite, "scale", Vector2.ONE, MELEE_STRIKE_SECONDS * 0.55)
	tween.tween_interval(0.04)
	tween.tween_callback(_set_unit_animation.bind(source_id, "move"))
	tween.tween_property(source_cell, "position", return_position, return_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_set_unit_animation.bind(source_id, "idle"))
	tween.tween_callback(_reset_attack_visual.bind(source_id))
	tween.tween_callback(_clear_attack_tween.bind(source_id, tween))


func _play_ranged_attack(source_id: String, target_id: String, source_sprite: TextureRect, target_cell: Control) -> void:
	var direction := 1.0
	if target_cell != null:
		var source_center := source_sprite.get_global_rect().get_center()
		var target_center := target_cell.get_global_rect().get_center()
		direction = sign(target_center.x - source_center.x)
		if direction == 0.0:
			direction = 1.0
	_set_unit_animation(source_id, "idle")
	var start_position := source_sprite.position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_sprite, "position", start_position + Vector2(-5.0 * direction, -3.0), 0.08)
	tween.tween_property(source_sprite, "position", start_position, 0.12)
	if target_cell != null:
		_spawn_projectile_between_units(source_id, target_id, Color(1.0, 0.84, 0.38), 10.0)
	else:
		_spawn_spark_at_unit(target_id, Color(1.0, 0.84, 0.38), 18.0)


func play_hit(target_id: String, amount: int) -> void:
	var sprite := _sprite_for_unit(target_id)
	if sprite != null:
		var base_modulate := _base_modulate_for_sprite(sprite)
		var start_position := sprite.position
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.18, 0.12), 0.05)
		tween.parallel().tween_property(sprite, "position", start_position + Vector2(-4, 0), 0.04)
		tween.tween_property(sprite, "position", start_position + Vector2(4, 0), 0.04)
		tween.tween_property(sprite, "position", start_position, 0.05)
		tween.parallel().tween_property(sprite, "modulate", base_modulate, 0.12)
	_spawn_float_text(target_id, "-%d" % amount, DAMAGE_COLOR)


func play_heal(target_id: String, amount: int) -> void:
	var sprite := _sprite_for_unit(target_id)
	if sprite != null:
		var base_modulate := _base_modulate_for_sprite(sprite)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.45, 1.0, 0.58), 0.08)
		tween.tween_property(sprite, "modulate", base_modulate, 0.18)
	_spawn_float_text(target_id, "+%d" % amount, HEAL_COLOR)


func play_skill_pulse(skill_id: String) -> void:
	var target_ids: Array = []
	if skill_id == "skill_1" or skill_id == "skill_2":
		for unit in GameState.alive_party():
			target_ids.append(unit.id)
	for unit_id in target_ids:
		var sprite := _sprite_for_unit(str(unit_id))
		if sprite == null:
			continue
		var base_modulate := _base_modulate_for_sprite(sprite)
		var pulse_color := Color(1.0, 0.82, 0.26) if skill_id == "skill_1" else HEAL_COLOR
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.22, 1.22), 0.10)
		tween.parallel().tween_property(sprite, "modulate", pulse_color, 0.10)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.16)
		tween.parallel().tween_property(sprite, "modulate", base_modulate, 0.16)
		_spawn_spark_at_unit(str(unit_id), pulse_color, 14.0)


func play_boss_warning() -> void:
	if GameState.wave_state == null:
		return
	for enemy in GameState.wave_state.alive_enemies():
		var sprite := _sprite_for_unit(enemy.id)
		if sprite == null:
			continue
		var base_modulate := _base_modulate_for_sprite(sprite)
		var tween := create_tween()
		tween.set_loops(3)
		tween.tween_property(sprite, "scale", Vector2(1.32, 1.32), 0.16)
		tween.parallel().tween_property(sprite, "modulate", BOSS_WARNING_COLOR, 0.16)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.16)
		tween.parallel().tween_property(sprite, "modulate", base_modulate, 0.16)
		_spawn_spark_at_unit(enemy.id, BOSS_WARNING_COLOR, 24.0)


func play_reward_burst(text: String) -> void:
	if _map_grid == null:
		return
	var original_modulate := _map_grid.modulate
	var tween := create_tween()
	tween.tween_property(_map_grid, "modulate", REWARD_COLOR.lightened(0.20), 0.08)
	tween.tween_property(_map_grid, "modulate", original_modulate, 0.22)


func _find_unit(id: String):
	for u in GameState.party:
		if u.id == id:
			return u
	if GameState.wave_state != null:
		for e in GameState.wave_state.enemies:
			if e.id == id:
				return e
	return null


func _load_animation_frames(asset_id: String) -> Array:
	if asset_id == "":
		return []
	var frames: Array = AssetRegistry.load_sprite_frames(asset_id, UNIT_ANIMATION_ROW)
	if frames.is_empty() and UNIT_ANIMATION_ROW != 0:
		frames = AssetRegistry.load_sprite_frames(asset_id, 0)
	return frames


func _advance_sprite_animation(sprite: TextureRect, delta: float) -> void:
	var state := str(sprite.get_meta("animation_state", "idle"))
	var frames := _frames_for_sprite_state(sprite, state)
	if frames.size() <= 1:
		return

	var frame_seconds := WALK_FRAME_SECONDS if state == "move" else IDLE_FRAME_SECONDS
	var accum := float(sprite.get_meta("frame_accum", 0.0)) + delta
	if accum < frame_seconds:
		sprite.set_meta("frame_accum", accum)
		return

	var advance_count := int(floor(accum / frame_seconds))
	accum = fmod(accum, frame_seconds)
	var frame_index := int(sprite.get_meta("frame_index", 0))
	frame_index = (frame_index + advance_count) % frames.size()
	var texture := frames[frame_index] as Texture2D
	if texture != null:
		sprite.texture = texture
	sprite.set_meta("frame_index", frame_index)
	sprite.set_meta("frame_accum", accum)


func _frames_for_sprite_state(sprite: TextureRect, state: String) -> Array:
	var key := "move_frames" if state == "move" else "idle_frames"
	var frames = sprite.get_meta(key, [])
	if typeof(frames) == TYPE_ARRAY:
		return frames
	return []


func _set_unit_animation(unit_id: String, state: String) -> void:
	var sprite := _sprite_for_unit(unit_id)
	if sprite == null:
		return
	var normalized_state := "move" if state == "move" else "idle"
	if str(sprite.get_meta("animation_state", "idle")) == normalized_state:
		return
	sprite.set_meta("animation_state", normalized_state)
	sprite.set_meta("frame_index", 0)
	sprite.set_meta("frame_accum", 0.0)
	var frames := _frames_for_sprite_state(sprite, normalized_state)
	if frames.is_empty():
		return
	var texture := frames[0] as Texture2D
	if texture != null:
		sprite.texture = texture


func _is_melee_unit(unit_id: String) -> bool:
	var unit = _find_unit(unit_id)
	if unit == null:
		return false
	return ["tank", "dps", "enemy"].has(str(unit.party_role))


func _walk_duration(distance: float) -> float:
	return clamp(distance / MELEE_WALK_PIXELS_PER_SECOND, MELEE_MIN_WALK_SECONDS, MELEE_MAX_WALK_SECONDS)


func _lane_position_for_unit(unit_id: String, fallback: Vector2) -> Vector2:
	if _lane_positions_by_unit_id.has(unit_id):
		return _lane_positions_by_unit_id[unit_id]
	return fallback


func _cancel_attack_tween(unit_id: String) -> void:
	if not _attack_tweens_by_unit_id.has(unit_id):
		return
	var tween = _attack_tweens_by_unit_id[unit_id]
	if tween != null and is_instance_valid(tween):
		tween.kill()
	_attack_tweens_by_unit_id.erase(unit_id)
	_reset_attack_visual(unit_id)


func _clear_attack_tween(unit_id: String, tween: Tween) -> void:
	if _attack_tweens_by_unit_id.get(unit_id) == tween:
		_attack_tweens_by_unit_id.erase(unit_id)


func _reset_attack_visual(unit_id: String) -> void:
	var cell := _cell_for_unit(unit_id)
	if cell != null:
		cell.z_index = 0
	var sprite := _sprite_for_unit(unit_id)
	if sprite != null:
		sprite.scale = Vector2.ONE
	_set_unit_animation(unit_id, "idle")


func _fill_units(units: Array) -> void:
	if _unit_layer == null:
		return
	if _cells_by_unit_id.is_empty():
		for child in _unit_layer.get_children():
			child.queue_free()
	for u in units:
		var cell := _build_unit_cell(u)
		_unit_layer.add_child(cell)
		_cells_by_unit_id[u.id] = cell


func _build_unit_cell(u) -> Control:  # u: UnitState
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = UNIT_CELL_SIZE
	cell.size = UNIT_CELL_SIZE
	cell.clip_contents = false
	cell.add_theme_constant_override("separation", 1)
	cell.name = "Cell_" + u.id
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait := Control.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = UNIT_PORTRAIT_SIZE
	portrait.size = UNIT_PORTRAIT_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(portrait)

	var shadow := ColorRect.new()
	shadow.name = "SpriteShadow"
	shadow.position = Vector2(8, 55)
	shadow.size = Vector2(54, 8)
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	portrait.add_child(shadow)

	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.position = Vector2(3, -2)
	sprite.size = UNIT_SPRITE_SIZE
	sprite.custom_minimum_size = UNIT_SPRITE_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.flip_h = _should_flip_unit_sprite(u)
	var idle_frames := _load_animation_frames(str(u.idle_asset))
	var move_asset_id := str(u.move_asset)
	if move_asset_id == "":
		move_asset_id = str(u.idle_asset)
	var move_frames := _load_animation_frames(move_asset_id)
	if move_frames.is_empty():
		move_frames = idle_frames
	if not idle_frames.is_empty():
		sprite.texture = idle_frames[0]
	else:
		var tex := AssetRegistry.load_sprite_frame(u.idle_asset, 0, 0)
		if tex != null:
			sprite.texture = tex
			idle_frames = [tex]
			move_frames = [tex]
		else:
			var placeholder := ColorRect.new()
			placeholder.custom_minimum_size = UNIT_SPRITE_SIZE
			placeholder.size = UNIT_SPRITE_SIZE
			placeholder.color = PLACEHOLDER
			portrait.add_child(placeholder)
			cell.add_child(_label(u.display_name, 10, Color(0.94, 0.90, 0.80)))
			return cell

	if sprite.texture == null:
		var placeholder := ColorRect.new()
		placeholder.custom_minimum_size = UNIT_SPRITE_SIZE
		placeholder.size = UNIT_SPRITE_SIZE
		placeholder.color = PLACEHOLDER
		portrait.add_child(placeholder)
		cell.add_child(_label(u.display_name, 10, Color(0.94, 0.90, 0.80)))
		return cell

	match u.modulate_hint:
		"enemy_red":
			sprite.modulate = ENEMY_RED.lightened(0.12)
		"boss_purple":
			sprite.modulate = BOSS_PURPLE.lightened(0.10)
		"":
			sprite.modulate = HERO_TINT
		_:
			push_warning("Unknown modulate_hint: %s" % u.modulate_hint)
			sprite.modulate = HERO_TINT
	sprite.pivot_offset = UNIT_SPRITE_SIZE * 0.5
	sprite.set_meta("base_modulate", sprite.modulate)
	sprite.set_meta("idle_frames", idle_frames)
	sprite.set_meta("move_frames", move_frames)
	sprite.set_meta("animation_state", "idle")
	sprite.set_meta("frame_index", 0)
	sprite.set_meta("frame_accum", 0.0)
	portrait.add_child(sprite)

	var name_label := _label(_short_unit_name(u), 10, Color(0.94, 0.90, 0.80))
	name_label.custom_minimum_size = Vector2(UNIT_CELL_SIZE.x, 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.name = "NameLabel"
	cell.add_child(name_label)

	var hp_label := _label("", 10, Color(0.7, 0.9, 0.7))
	hp_label.name = "HpLabel"
	hp_label.custom_minimum_size = Vector2(UNIT_CELL_SIZE.x, 12)
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(hp_label)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(74, 7)
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hp_bar.add_theme_stylebox_override("background", _flat_bar_style(Color(0.08, 0.05, 0.05), Color(0.18, 0.10, 0.08)))
	hp_bar.add_theme_stylebox_override("fill", _flat_bar_style(Color(0.36, 0.86, 0.38), Color(0.16, 0.36, 0.16)))
	cell.add_child(hp_bar)

	_paint_cell_hp(cell, u)
	return cell


func _load_map_plan() -> Dictionary:
	if not FileAccess.file_exists(MAP_PLAN_PATH):
		push_warning("Missing map plan: %s" % MAP_PLAN_PATH)
		return _fallback_map_plan()

	var text := FileAccess.get_file_as_string(MAP_PLAN_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Map plan must be a JSON object: %s" % MAP_PLAN_PATH)
		return _fallback_map_plan()

	return parsed


func _fallback_map_plan() -> Dictionary:
	return {
		"tilesheet_shortcut": "map.default_tilesheet",
		"tile_size": 16,
		"display_scale": 2,
		"map_width": 12,
		"map_height": 4,
		"tile_layers": {
			"ground_fill": {"tile": "grass"},
			"roads": [
				{"x": 0, "y": 2, "width": 12, "height": 1, "tile": "road_h"}
			],
			"decor": [
				{"x": 1, "y": 1, "tile": "tree"},
				{"x": 10, "y": 1, "tile": "bed"}
			]
		}
	}


func _render_tile_map() -> void:
	if _map_grid == null:
		return

	for child in _map_grid.get_children():
		child.queue_free()

	var map_width := int(_map_plan.get("map_width", 12))
	var map_height := int(_map_plan.get("map_height", 4))
	var tile_size := int(_map_plan.get("tile_size", 16))
	var display_scale := int(_map_plan.get("display_scale", 2))
	var display_size: int = max(1, tile_size * display_scale)
	var tilesheet_shortcut := str(_map_plan.get("tilesheet_shortcut", "map.default_tilesheet"))

	_map_grid.columns = map_width
	_map_pixel_size = Vector2(map_width * display_size, map_height * display_size)
	_map_grid.custom_minimum_size = _map_pixel_size
	if _stage != null:
		_stage.custom_minimum_size = Vector2(_map_pixel_size.x, max(268.0, _map_pixel_size.y + 86.0))

	for y in range(map_height):
		for x in range(map_width):
			var cell := Control.new()
			cell.custom_minimum_size = Vector2(display_size, display_size)
			cell.size = Vector2(display_size, display_size)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for tile_choice in _tile_stack_for_cell(x, y):
				_add_tile_to_cell(cell, tile_choice, display_size, tilesheet_shortcut)
			if cell.get_child_count() == 0:
				var placeholder := ColorRect.new()
				placeholder.custom_minimum_size = Vector2(display_size, display_size)
				placeholder.size = Vector2(display_size, display_size)
				placeholder.color = PLACEHOLDER
				cell.add_child(placeholder)
			_map_grid.add_child(cell)


func _tile_stack_for_cell(x: int, y: int) -> Array:
	var layers = _map_plan.get("tile_layers", {})
	if typeof(layers) != TYPE_DICTIONARY:
		return [_tile_choice("grass")]

	var stack: Array = [_tile_choice(_ground_tile_name(layers))]
	var ground = layers.get("ground_fill", {})
	if typeof(ground) == TYPE_DICTIONARY:
		stack[0] = _tile_choice(str(ground.get("tile", "grass")))

	for layer_name in ["patches", "roads", "water"]:
		_apply_repeating_layer(stack, layers.get(layer_name, []), x, y)

	for decor in layers.get("decor", []):
		if typeof(decor) != TYPE_DICTIONARY:
			continue
		if int(decor.get("x", -1)) == x and int(decor.get("y", -1)) == y:
			stack.append(_tile_choice(str(decor.get("tile", "grass"))))

	for stamp in layers.get("stamps", []):
		if typeof(stamp) != TYPE_DICTIONARY:
			continue
		var sx := int(stamp.get("x", 0))
		var sy := int(stamp.get("y", 0))
		var sw := int(stamp.get("width", 0))
		var sh := int(stamp.get("height", 0))
		if x >= sx and x < sx + sw and y >= sy and y < sy + sh:
			stack.append(_tile_choice(str(stamp.get("tile", "grass")), x - sx, y - sy))

	return stack


func _ground_tile_name(layers: Dictionary) -> String:
	var ground = layers.get("ground_fill", {})
	if typeof(ground) == TYPE_DICTIONARY:
		return str(ground.get("tile", "grass"))
	return "grass"


func _apply_repeating_layer(stack: Array, layer_entries, x: int, y: int) -> void:
	if typeof(layer_entries) != TYPE_ARRAY:
		return
	for entry in layer_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rx := int(entry.get("x", 0))
		var ry := int(entry.get("y", 0))
		var rw := int(entry.get("width", 0))
		var rh := int(entry.get("height", 0))
		if x >= rx and x < rx + rw and y >= ry and y < ry + rh:
			stack[0] = _tile_choice(str(entry.get("tile", "grass")))


func _tile_choice(tile_name: String, offset_x: int = 0, offset_y: int = 0) -> Dictionary:
	return {
		"tile": tile_name,
		"offset_x": offset_x,
		"offset_y": offset_y
	}


func _add_tile_to_cell(cell: Control, tile_choice: Dictionary, display_size: int, tilesheet_shortcut: String) -> void:
	var tile_name := str(tile_choice.get("tile", "grass"))
	var offset_x := int(tile_choice.get("offset_x", 0))
	var offset_y := int(tile_choice.get("offset_y", 0))
	var tex := AssetRegistry.load_map_tile_offset(tile_name, offset_x, offset_y, tilesheet_shortcut)
	if tex == null:
		return
	var tile := TextureRect.new()
	tile.custom_minimum_size = Vector2(display_size, display_size)
	tile.size = Vector2(display_size, display_size)
	tile.position = Vector2.ZERO
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.texture = tex
	cell.add_child(tile)


func _as_tile_pair(value) -> Array:
	# A tile can be a named tile ("grass") resolved via AssetRegistry, or a raw
	# [column, row] pair. Named tiles are preferred; raw pairs stay supported.
	if typeof(value) == TYPE_STRING:
		var named := AssetRegistry.get_map_tile_coords(value)
		if not named.is_empty():
			return named
		push_warning("Unknown map tile name in plan: %s" % value)
		return [12, 5]
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return [12, 5]
	return [int(value[0]), int(value[1])]


func _paint_cell_hp(cell: Control, u) -> void:  # u: UnitState
	var hp_label: Label = cell.get_node_or_null("HpLabel")
	var hp_bar: ProgressBar = cell.get_node_or_null("HpBar")
	var sprite: TextureRect = cell.find_child("Sprite", true, false) as TextureRect
	if hp_label != null:
		hp_label.text = "%d/%d" % [u.hp_current, u.hp_max]
		if u.hp_current == 0:
			hp_label.modulate = Color(0.85, 0.35, 0.35)
		elif u.hp_current < u.hp_max / 3:
			hp_label.modulate = Color(0.95, 0.7, 0.4)
		else:
			hp_label.modulate = Color(0.7, 0.9, 0.7)
	if hp_bar != null:
		hp_bar.max_value = max(1, u.hp_max)
		hp_bar.value = clamp(u.hp_current, 0, u.hp_max)
	if sprite != null:
		if not u.alive:
			sprite.modulate = Color(0.35, 0.35, 0.35, 0.7)
		elif sprite.has_meta("base_modulate"):
			sprite.modulate = sprite.get_meta("base_modulate")


func _cell_for_unit(unit_id: String) -> Control:
	if not _cells_by_unit_id.has(unit_id):
		return null
	var cell: Control = _cells_by_unit_id[unit_id]
	if not is_instance_valid(cell):
		return null
	return cell


func _sprite_for_unit(unit_id: String) -> TextureRect:
	var cell := _cell_for_unit(unit_id)
	if cell == null:
		return null
	return cell.find_child("Sprite", true, false) as TextureRect


func _layout_stage() -> void:
	if _stage == null or _map_grid == null:
		return
	if _map_pixel_size == Vector2.ZERO:
		return

	var stage_width: float = max(_stage.size.x, _map_pixel_size.x)
	var map_origin := Vector2(max(0.0, (stage_width - _map_pixel_size.x) * 0.5), 8.0)
	_map_grid.position = map_origin
	_map_grid.size = _map_pixel_size

	if _lane_shadow != null:
		_lane_shadow.position = map_origin + Vector2(0, max(0.0, _map_pixel_size.y - 94.0))
		_lane_shadow.size = Vector2(_map_pixel_size.x, 58)

	if _party_tag != null:
		_party_tag.position = map_origin + Vector2(10, 10)
	if _enemy_tag != null:
		_enemy_tag.position = map_origin + Vector2(_map_pixel_size.x - 86, 10)

	if _unit_layer != null:
		_unit_layer.position = Vector2.ZERO
		_unit_layer.size = _stage.size

	var lane_y := map_origin.y + _map_pixel_size.y - UNIT_CELL_SIZE.y - 14.0
	_position_units(_party_units, map_origin.x + 76.0, lane_y)

	var enemy_count := _enemy_units.size()
	var enemy_total_width: float = UNIT_CELL_SIZE.x
	if enemy_count > 1:
		enemy_total_width += float(enemy_count - 1) * UNIT_STEP
	var enemy_start := map_origin.x + _map_pixel_size.x - 76.0 - enemy_total_width
	_position_units(_enemy_units, enemy_start, lane_y)


func _position_units(units: Array, start_x: float, y: float) -> void:
	for i in range(units.size()):
		var u = units[i]
		var cell := _cell_for_unit(u.id)
		if cell == null:
			continue
		var lane_position := Vector2(start_x + (float(i) * UNIT_STEP), y)
		_lane_positions_by_unit_id[u.id] = lane_position
		cell.position = lane_position
		cell.size = UNIT_CELL_SIZE


func _spawn_float_text(unit_id: String, text: String, color: Color) -> void:
	var sprite := _sprite_for_unit(unit_id)
	if sprite == null:
		return
	var label := _make_effect_label(text, color, 13)
	sprite.add_child(label)
	var start := Vector2(14, -14)
	label.position = start
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", start + Vector2(0, -26), 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)


func _spawn_spark_at_unit(unit_id: String, color: Color, size: float) -> void:
	var sprite := _sprite_for_unit(unit_id)
	if sprite == null:
		return
	var spark := ColorRect.new()
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.color = color
	spark.modulate.a = 0.65
	spark.size = Vector2(size, size)
	sprite.add_child(spark)
	spark.position = Vector2(24, 24) - (spark.size * 0.5)
	var tween := create_tween()
	tween.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.22)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.22)
	tween.tween_callback(spark.queue_free)


func _spawn_projectile_between_units(source_id: String, target_id: String, color: Color, size: float) -> void:
	if _stage == null:
		_spawn_spark_at_unit(target_id, color, 18.0)
		return
	var stage_to_local: Transform2D = _stage.get_global_transform().affine_inverse()
	var source_local: Vector2 = stage_to_local * _unit_anchor_global(source_id)
	var target_local: Vector2 = stage_to_local * _unit_anchor_global(target_id)
	var projectile := ColorRect.new()
	projectile.name = "RangedProjectile"
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.color = color
	projectile.modulate.a = 0.82
	projectile.size = Vector2(size, size)
	projectile.position = source_local - (projectile.size * 0.5)
	projectile.z_index = 30
	_stage.add_child(projectile)

	var tween := create_tween()
	tween.tween_property(projectile, "position", target_local - (projectile.size * 0.5), RANGED_PROJECTILE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(projectile, "scale", Vector2(1.35, 1.35), RANGED_PROJECTILE_SECONDS)
	tween.tween_callback(_spawn_spark_at_unit.bind(target_id, color, 18.0))
	tween.tween_callback(projectile.queue_free)


func _base_modulate_for_sprite(sprite: TextureRect) -> Color:
	if sprite.has_meta("base_modulate"):
		return sprite.get_meta("base_modulate")
	return HERO_TINT


func _unit_anchor_global(unit_id: String) -> Vector2:
	var sprite := _sprite_for_unit(unit_id)
	if sprite != null:
		return sprite.get_global_rect().get_center()
	var cell := _cell_for_unit(unit_id)
	if cell != null:
		return cell.get_global_rect().get_center()
	return get_global_rect().get_center()


func _make_effect_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _short_unit_name(u) -> String:
	var parts := str(u.display_name).split(" ", false)
	if parts.size() > 0:
		return str(parts[0])
	return str(u.display_name)


func _should_flip_unit_sprite(u) -> bool:
	if str(u.party_role) == "enemy":
		return ENEMY_SPRITES_FLIP_H
	return PARTY_SPRITES_FLIP_H


func _panel_style(shortcut: String, fallback_color: Color, border_width: int = 1) -> StyleBox:
	if AssetRegistry.loaded and AssetRegistry.has_asset(shortcut):
		var tex := AssetRegistry.load_texture(shortcut)
		if tex != null:
			var texture_style := StyleBoxTexture.new()
			texture_style.texture = tex
			texture_style.set_texture_margin_all(8)
			texture_style.set_content_margin_all(8)
			texture_style.draw_center = true
			return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = fallback_color
	style.border_color = Color(0.33, 0.27, 0.18)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


func _flat_bar_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.modulate = color
	return l
