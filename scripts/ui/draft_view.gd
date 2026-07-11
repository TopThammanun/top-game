class_name DraftView
extends CanvasLayer

# The level-up draft overlay. Modal: a full-rect dim (MOUSE_FILTER_STOP) covers
# the whole screen (including the top nav) so combat/nav can't be touched while
# time_scale is 0. Also reused for the pre-run starter pick (same card UI).
# Presentation only — the battle scene supplies the card views and applies picks.

signal chosen(index: int)

const RARITY_COL := {
	"common": Color(0.60, 0.62, 0.67), "rare": Color(0.37, 0.68, 1.0),
	"epic": Color(0.73, 0.55, 1.0), "legendary": Color(1.0, 0.82, 0.40),
}

var _root: Control


func _init() -> void:
	layer = 18   # above the nav screen layer (16), below the warp flash (20)


func show_cards(views: Array, view_size: Vector2) -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var title := _label("LEVEL UP — choose one", 28, Color(1.0, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, view_size.y * 0.14)
	title.size = Vector2(view_size.x, 40)
	_root.add_child(title)

	var n := views.size()
	var card_w := 200.0
	var card_h := 300.0
	var gap := 28.0
	var total := float(n) * card_w + float(max(0, n - 1)) * gap
	var start_x := view_size.x * 0.5 - total * 0.5
	var y := view_size.y * 0.26
	for i in n:
		_build_card(views[i], start_x + float(i) * (card_w + gap), y, card_w, card_h, i)


func _build_card(v: Dictionary, x: float, y: float, w: float, h: float, index: int) -> void:
	var frame := NinePatchRect.new()
	var frame_tex := AssetRegistry.load_texture("ui.card_frame")
	if frame_tex != null:
		frame.texture = frame_tex
	else:
		var bg := ColorRect.new()   # fallback if the shortcut is missing
		bg.color = Color(0.16, 0.12, 0.22)
		bg.position = Vector2(x, y)
		bg.size = Vector2(w, h)
		_root.add_child(bg)
	frame.position = Vector2(x, y)
	frame.size = Vector2(w, h)
	_root.add_child(frame)

	var ribbon := ColorRect.new()   # rarity tint
	ribbon.color = RARITY_COL.get(str(v.get("rarity", "common")), Color.WHITE)
	ribbon.position = Vector2(x + 14.0, y + 14.0)
	ribbon.size = Vector2(w - 28.0, 8.0)
	_root.add_child(ribbon)

	var shortcut := str(v.get("sprite_shortcut", ""))
	if shortcut != "":
		var portrait := TextureRect.new()
		var ptex := AssetRegistry.load_sprite_frame(shortcut, 0, 0)   # idle, frame 0
		if ptex != null:
			portrait.texture = ptex
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.position = Vector2(x + w * 0.5 - 48.0, y + 40.0)
		portrait.size = Vector2(96.0, 96.0)
		_root.add_child(portrait)

	var name_lbl := _label(str(v.get("title", "")), 16, Color(0.22, 0.13, 0.07))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(x + 10.0, y + 150.0)
	name_lbl.size = Vector2(w - 20.0, 24.0)
	_root.add_child(name_lbl)

	var desc_lbl := _label(str(v.get("desc", "")), 12, Color(0.30, 0.20, 0.12))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.position = Vector2(x + 12.0, y + 180.0)
	desc_lbl.size = Vector2(w - 24.0, 60.0)
	_root.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "PICK"
	btn.position = Vector2(x + w * 0.5 - 45.0, y + h - 46.0)
	btn.size = Vector2(90.0, 32.0)
	btn.pressed.connect(func() -> void: chosen.emit(index))
	_root.add_child(btn)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func close() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
