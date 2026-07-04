class_name Taskbar
extends PanelContainer

signal command_pressed(id: String)

const COMMANDS_PATH := "res://data/ui/taskbar_commands.json"

var _slot_row: HBoxContainer
var _commands: Array = []
var _slots_by_id: Dictionary = {}
var _cooldowns: Dictionary = {}    # id -> seconds remaining
var _ready_flashes: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0, 92)
	_build()
	if AssetRegistry.loaded:
		render()
	else:
		AssetRegistry.catalog_ready.connect(render, CONNECT_ONE_SHOT)
	set_process(true)


func _build() -> void:
	add_theme_stylebox_override("panel", _panel_style("", Color(0.12, 0.095, 0.075), 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 8)
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_slot_row)


func render() -> void:
	if _slot_row == null:
		return
	for child in _slot_row.get_children():
		child.queue_free()
	_slots_by_id.clear()
	_commands = _load_commands()
	for cmd in _commands:
		var slot := _build_slot(cmd)
		_slot_row.add_child(slot)
		_slots_by_id[str(cmd.get("id", ""))] = slot


func start_cooldown(id: String, seconds: float) -> void:
	_cooldowns[id] = seconds
	_ready_flashes.erase(id)
	play_command_feedback(id, Color(0.55, 0.68, 0.85))
	_refresh_slot_visual(id)


func play_command_feedback(id: String, color: Color = Color.WHITE) -> void:
	if not _slots_by_id.has(id):
		return
	var slot: Control = _slots_by_id[id]
	var btn: TextureButton = slot.find_child("Btn", true, false) as TextureButton
	if btn == null:
		return
	var base_modulate := btn.modulate
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.08)
	tween.parallel().tween_property(btn, "modulate", color, 0.08)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(btn, "modulate", base_modulate, 0.12)


func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	var ids_to_clear: Array = []
	for id in _cooldowns.keys():
		_cooldowns[id] = max(0.0, _cooldowns[id] - delta)
		if _cooldowns[id] == 0.0:
			ids_to_clear.append(id)
		_refresh_slot_visual(id)
	for id in ids_to_clear:
		_play_ready_feedback(str(id))
		_cooldowns.erase(id)


func _refresh_slot_visual(id: String) -> void:
	if not _slots_by_id.has(id):
		return
	var slot: Control = _slots_by_id[id]
	var btn: TextureButton = slot.find_child("Btn", true, false) as TextureButton
	var cd_label: Label = slot.get_node_or_null("CooldownLabel")
	var remaining: float = _cooldowns.get(id, 0.0)
	if btn != null:
		btn.disabled = remaining > 0.0
		btn.modulate = Color(0.6, 0.6, 0.6) if remaining > 0.0 else Color.WHITE
	if cd_label != null:
		cd_label.text = ("%.1fs" % remaining) if remaining > 0.0 else ""


func _load_commands() -> Array:
	if not FileAccess.file_exists(COMMANDS_PATH):
		push_error("Missing %s" % COMMANDS_PATH)
		return []
	var text := FileAccess.get_file_as_string(COMMANDS_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Taskbar commands must be a JSON array")
		return []
	return parsed


func _build_slot(cmd: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(72, 78)
	cell.add_theme_constant_override("separation", 3)

	var holder := Control.new()
	holder.name = "IconHolder"
	holder.custom_minimum_size = Vector2(58, 52)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(holder)

	var frame := TextureRect.new()
	frame.name = "SlotFrame"
	frame.position = Vector2(5, 2)
	frame.size = Vector2(48, 48)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = AssetRegistry.load_texture("ui.slot_empty")
	holder.add_child(frame)

	var btn := TextureButton.new()
	btn.name = "Btn"
	btn.position = Vector2(7, 4)
	btn.size = Vector2(44, 44)
	btn.custom_minimum_size = Vector2(44, 44)
	btn.pivot_offset = Vector2(22, 22)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var shortcut := str(cmd.get("asset_shortcut", ""))
	var tex := AssetRegistry.load_texture(shortcut)
	if tex != null:
		btn.texture_normal = tex
	var cmd_id := str(cmd.get("id", ""))
	btn.pressed.connect(_on_slot_pressed.bind(cmd_id))
	holder.add_child(btn)

	var label := Label.new()
	label.name = "CommandLabel"
	label.text = str(cmd.get("label", cmd_id))
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.modulate = Color(0.94, 0.90, 0.80)
	cell.add_child(label)

	var cd_label := Label.new()
	cd_label.name = "CooldownLabel"
	cd_label.text = ""
	cd_label.add_theme_font_size_override("font_size", 9)
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.modulate = Color(0.7, 0.85, 1.0)
	cell.add_child(cd_label)

	return cell


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


func _on_slot_pressed(id: String) -> void:
	if _cooldowns.get(id, 0.0) > 0.0:
		return
	command_pressed.emit(id)


func _play_ready_feedback(id: String) -> void:
	if _ready_flashes.has(id):
		return
	_ready_flashes[id] = true
	play_command_feedback(id, Color(0.85, 1.0, 0.55))
