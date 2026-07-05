extends Node2D

# Real-time auto-battler presentation (Plan B, first visual slice). Keeps the
# TBH/Whisker Realm roster but renders a side-scrolling clash driven by the Plan A
# combat core (StatSystem / DamageCalculator / CombatSkill / SkillEffect via
# CharacterFactory). Controller-tuned by screenshot; see the pivot spec.
#
# Combat classes are referenced via preload consts (headless-safe path — see
# agents/sage/godot-runtime/decisions/headless-global-class-cache.md).

const CharacterFactoryClass = preload("res://scripts/combat/character_factory.gd")
const CombatEnumsClass = preload("res://scripts/combat/combat_enums.gd")
const DamageCalculatorClass = preload("res://scripts/combat/damage_calculator.gd")
const SkillEffectClass = preload("res://scripts/combat/skill_effect.gd")

const SPRITE_SCALE := 2.8                 # 3x source frame (48px) -> ~134px tall hero
const FRAME_W := 48.0
const SPRITE_H := FRAME_W * SPRITE_SCALE
const GROUND_Y_RATIO := 0.74              # ground line as a fraction of view height
const IDLE_FRAME_SECONDS := 0.22
const WALK_FRAME_SECONDS := 0.12
const ANIM_ROW := 1                       # side-facing track in the 4x4 sheet
const HP_MULT := 2.4                      # fatten the HP pool so fights are watchable
const CADENCE_BASE := 1.5                 # seconds-per-attack scalar (higher = slower)

var _factory
var _units: Array = []                    # Array of unit dictionaries
var _bg_layer: CanvasLayer
var _hud_layer: CanvasLayer
var _sky: TextureRect
var _ground: ColorRect
var _horizon: ColorRect
var _title_label: Label
var _wave_label: Label
var _banner_label: Label
var _view_size: Vector2
var _wave: int = 1
var _phase: String = "boot"               # boot | fighting | won | lost
var _post_timer: float = 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_build_layers()
	if not AssetRegistry.loaded:
		AssetRegistry.catalog_ready.connect(_try_start, CONNECT_ONE_SHOT)
	if not GameState.is_ready:
		GameState.state_ready.connect(_try_start, CONNECT_ONE_SHOT)
	_try_start()
	get_viewport().size_changed.connect(_on_resize)


func _try_start() -> void:
	if _phase != "boot":
		return
	if not AssetRegistry.loaded or not GameState.is_ready:
		return
	_phase = "fighting"
	_factory = CharacterFactoryClass.new()
	_factory.load_all()
	_view_size = get_viewport().get_visible_rect().size
	_layout_background()
	_spawn_wave()


# ---------------------------------------------------------------- scene scaffold

func _build_layers() -> void:
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -10
	add_child(_bg_layer)

	_sky = TextureRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_layer.add_child(_sky)

	_ground = ColorRect.new()
	_ground.color = Color(0.20, 0.16, 0.17)
	_bg_layer.add_child(_ground)

	_horizon = ColorRect.new()
	_horizon.color = Color(0.62, 0.44, 0.42, 0.55)
	_bg_layer.add_child(_horizon)

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_title_label = _hud_label(26, Color(0.98, 0.93, 0.82))
	_hud_layer.add_child(_title_label)
	_wave_label = _hud_label(18, Color(0.86, 0.80, 0.92))
	_hud_layer.add_child(_wave_label)

	_banner_label = _hud_label(44, Color(1.0, 0.9, 0.55))
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.visible = false
	_hud_layer.add_child(_banner_label)


func _hud_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _on_resize() -> void:
	_view_size = get_viewport().get_visible_rect().size
	if _phase != "boot":
		_layout_background()


func _layout_background() -> void:
	var w := _view_size.x
	var h := _view_size.y
	var ground_y := h * GROUND_Y_RATIO

	var grad := Gradient.new()
	grad.set_color(0, Color(0.13, 0.15, 0.26))
	grad.set_color(1, Color(0.44, 0.30, 0.36))
	grad.add_point(0.72, Color(0.52, 0.34, 0.36))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 8
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_sky.texture = gt

	_ground.position = Vector2(0, ground_y)
	_ground.size = Vector2(w, h - ground_y)
	_horizon.position = Vector2(0, ground_y - 4)
	_horizon.size = Vector2(w, 8)

	_title_label.text = "Emberhearth · Pawmont"
	_title_label.position = Vector2(28, 20)
	_wave_label.position = Vector2(30, 56)
	_banner_label.size = Vector2(w, 60)
	_banner_label.position = Vector2(0, h * 0.36)
	_refresh_wave_label()


func _refresh_wave_label() -> void:
	_wave_label.text = "Wave %d / %d   ·   auto-battle" % [_wave, GameState.MAX_WAVE]


# ---------------------------------------------------------------- wave spawning

func _spawn_wave() -> void:
	_clear_units()
	var ground_y := _view_size.y * GROUND_Y_RATIO

	var party: Array = GameState.party
	var allies: Array = []
	for u in party:
		allies.append(_build_unit(_factory.build_from_clan(str(u.clan_id)), str(u.display_name), "ally", str(u.idle_asset), str(u.move_asset)))

	var enemies: Array = []
	if GameState.wave_state != null:
		for e in GameState.wave_state.enemies:
			enemies.append(_build_unit(_factory.build_from_enemy(str(e.enemy_id)), str(e.display_name), "enemy", str(e.idle_asset), str(e.move_asset)))

	_place_side(allies, true, ground_y)
	_place_side(enemies, false, ground_y)
	_units = allies + enemies
	_refresh_wave_label()


func _place_side(side_units: Array, is_ally: bool, ground_y: float) -> void:
	# Clean 3-lane diagonal: front is nearest the centre line and lowest (drawn in
	# front); rear is furthest out and highest (drawn behind). Extra units in the
	# same lane stack downward with a slight inward step.
	var dir := -1.0 if is_ally else 1.0
	var center_x := _view_size.x * 0.5
	var lane_depth := {
		CombatEnumsClass.Lane.FRONT: 0,
		CombatEnumsClass.Lane.MIDDLE: 1,
		CombatEnumsClass.Lane.REAR: 2,
	}
	var per_lane: Dictionary = {}
	for unit in side_units:
		var lane: int = int(unit["lane"])
		var d: int = int(lane_depth.get(lane, 1))
		var k: int = int(per_lane.get(lane, 0))
		per_lane[lane] = k + 1
		var x: float = center_x + dir * (150.0 + float(d) * 128.0) - dir * float(k) * 40.0
		var y: float = ground_y - 32.0 - float(d) * 44.0 + float(k) * 96.0
		var sprite: Sprite2D = unit["sprite"]
		sprite.position = Vector2(x, y)
		sprite.flip_h = is_ally  # source frames face left; flip allies to face right
		unit["home_x"] = x
		_update_overlay(unit)


func _build_unit(profile: Dictionary, display_name: String, side: String, idle_asset: String, move_asset: String) -> Dictionary:
	var idle_frames := _resolve_frames(idle_asset, profile.get("idle_shortcut", ""))
	var move_frames := _resolve_frames(move_asset, profile.get("move_shortcut", ""))
	if move_frames.is_empty():
		move_frames = idle_frames

	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.offset = Vector2(0, -FRAME_W * 0.5)   # feet sit on sprite.position
	if not idle_frames.is_empty():
		sprite.texture = idle_frames[0]
	if side == "enemy":
		sprite.modulate = Color(1.0, 0.72, 0.70)
	add_child(sprite)

	var name_label := _hud_label(13, Color(0.95, 0.92, 0.82) if side == "ally" else Color(1.0, 0.82, 0.80))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = display_name.split(" ")[0]
	_hud_layer.add_child(name_label)

	var stats = profile.get("stats")
	var hp_max: float = 1.0
	if stats != null:
		stats.set_base(CombatEnumsClass.StatKey.HP, stats.get_base(CombatEnumsClass.StatKey.HP) * HP_MULT)
		stats.current_hp = stats.get_stat(CombatEnumsClass.StatKey.HP)
		hp_max = max(1.0, stats.get_stat(CombatEnumsClass.StatKey.HP))

	return {
		"name": display_name,
		"side": side,
		"lane": int(profile.get("lane", CombatEnumsClass.Lane.FRONT)),
		"stats": stats,
		"skill": profile.get("skill"),
		"atk_range": float(profile.get("attack_range", 100.0)),
		"move_speed": float(profile.get("move_speed", 70.0)),
		"hp_max": hp_max,
		"sprite": sprite,
		"name_label": name_label,
		"idle_frames": idle_frames,
		"move_frames": move_frames,
		"frame_i": 0,
		"frame_t": 0.0,
		"anim": "idle",
		"anim_time": randf() * 2.0,
		"atk_t": randf() * 0.6,
		"alive": true,
		"home_x": 0.0,
		"base_mod": (Color(1.0, 0.72, 0.70) if side == "enemy" else Color.WHITE),
	}


func _resolve_frames(asset_id: String, fallback_shortcut: String) -> Array:
	# Prefer the crisp 3x sheet of whatever the roster/archetype points at.
	# Resolve the shortcut to its catalog id FIRST, then swap 1x -> 3x.
	var candidates: Array = []
	for src in [asset_id, fallback_shortcut]:
		if src == "":
			continue
		var cid: String = AssetRegistry.resolve_id(src)
		var big := _to_3x(cid)
		if big != "":
			candidates.append(big)
		candidates.append(cid)
	for c in candidates:
		var frames: Array = AssetRegistry.load_sprite_frames(c, ANIM_ROW)
		if frames.is_empty():
			frames = AssetRegistry.load_sprite_frames(c, 0)
		if not frames.is_empty():
			return frames
	return []


func _to_3x(catalog_id: String) -> String:
	if catalog_id.find("_1x_") != -1:
		var swapped := catalog_id.replace("_1x_", "_3x_")
		if AssetRegistry.has_asset(swapped):
			return swapped
	return ""


func _clear_units() -> void:
	for u in _units:
		var s = u.get("sprite")
		if s != null and is_instance_valid(s):
			s.queue_free()
		var nl = u.get("name_label")
		if nl != null and is_instance_valid(nl):
			nl.queue_free()
	_units.clear()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _phase == "boot":
		return
	if _phase == "won" or _phase == "lost":
		_post_timer -= delta
		queue_redraw()
		return

	for u in _units:
		_animate(u, delta)
		if u["alive"]:
			_act(u, delta)
		_update_overlay(u)

	_check_wave_end(delta)
	queue_redraw()


func _animate(u: Dictionary, delta: float) -> void:
	var sprite: Sprite2D = u["sprite"]
	u["anim_time"] += delta
	var frames: Array = u["move_frames"] if u["anim"] == "move" else u["idle_frames"]
	if frames.size() <= 1:
		return
	var step := WALK_FRAME_SECONDS if u["anim"] == "move" else IDLE_FRAME_SECONDS
	u["frame_t"] += delta
	if u["frame_t"] >= step:
		u["frame_t"] = 0.0
		u["frame_i"] = (int(u["frame_i"]) + 1) % frames.size()
		sprite.texture = frames[int(u["frame_i"])]


func _act(u: Dictionary, delta: float) -> void:
	var target = _nearest_enemy(u)
	if target == null:
		u["anim"] = "idle"
		return
	var sprite: Sprite2D = u["sprite"]
	var tsprite: Sprite2D = target["sprite"]
	var dx: float = tsprite.position.x - sprite.position.x
	var dist: float = abs(dx)
	var dir: float = sign(dx)

	if dist > float(u["atk_range"]):
		u["anim"] = "move"
		sprite.position.x += dir * float(u["move_speed"]) * delta
	else:
		u["anim"] = "idle"
		# skill first if ready
		var skill = u["skill"]
		if skill != null and skill.is_ready():
			_cast_skill(u, skill)
			skill.trigger()
			return
		if skill != null:
			skill.tick(delta, float(u["stats"].get_stat(CombatEnumsClass.StatKey.COOLDOWN_REDUCTION)))
		# basic attack on cadence
		u["atk_t"] += delta
		var cadence: float = CADENCE_BASE / max(0.5, float(u["stats"].get_stat(CombatEnumsClass.StatKey.ATK_SPD)))
		if u["atk_t"] >= cadence:
			u["atk_t"] = 0.0
			_basic_attack(u, target)


func _basic_attack(u: Dictionary, target: Dictionary) -> void:
	var r := DamageCalculatorClass.compute(u["stats"], target["stats"], 1.0)
	target["stats"].take_damage(float(r.amount))
	_lunge(u, target)
	_hit(target, r.amount, r.is_crit, false)
	if not target["stats"].is_alive():
		_kill(target)


func _cast_skill(u: Dictionary, skill) -> void:
	var targets: Array = []
	var pool: Array = _living(u["side"]) if skill.target_side != "enemy" else _living_enemies(u)
	for t in pool:
		targets.append(t["stats"])
	SkillEffectClass.apply(skill, u["stats"], targets)
	_skill_flash(u)
	for t in pool:
		if skill.effect_type == "heal":
			_hit(t, 0, false, true)
		elif skill.effect_type == "aoe_damage":
			_hit(t, 0, false, false)
		if not t["stats"].is_alive():
			_kill(t)


# ---------------------------------------------------------------- targeting

func _nearest_enemy(u: Dictionary):
	var best = null
	var best_d := INF
	for other in _units:
		if not other["alive"] or other["side"] == u["side"]:
			continue
		var d: float = abs(other["sprite"].position.x - u["sprite"].position.x)
		if d < best_d:
			best_d = d
			best = other
	return best


func _living(side: String) -> Array:
	var out: Array = []
	for u in _units:
		if u["alive"] and u["side"] == side:
			out.append(u)
	return out


func _living_enemies(u: Dictionary) -> Array:
	var out: Array = []
	for other in _units:
		if other["alive"] and other["side"] != u["side"]:
			out.append(other)
	return out


# ---------------------------------------------------------------- fx

func _lunge(u: Dictionary, target: Dictionary) -> void:
	var sprite: Sprite2D = u["sprite"]
	var dir: float = sign(target["sprite"].position.x - sprite.position.x)
	if dir == 0.0:
		dir = 1.0
	var home := sprite.position
	var tw := create_tween()
	tw.tween_property(sprite, "position", home + Vector2(dir * 20.0, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", home, 0.14).set_trans(Tween.TRANS_SINE)


func _hit(target: Dictionary, amount: int, is_crit: bool, is_heal: bool) -> void:
	var sprite: Sprite2D = target["sprite"]
	var flash := Color(0.4, 1.0, 0.55) if is_heal else Color(1.0, 0.35, 0.30)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", flash, 0.05)
	tw.tween_property(sprite, "modulate", target["base_mod"], 0.16)
	if amount > 0:
		_float_number(sprite.position + Vector2(0, -FRAME_W * SPRITE_SCALE), "-%d" % amount, Color(1.0, 0.85, 0.3) if is_crit else Color(1.0, 0.5, 0.4), is_crit)


func _skill_flash(u: Dictionary) -> void:
	var sprite: Sprite2D = u["sprite"]
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(SPRITE_SCALE * 1.18, SPRITE_SCALE * 1.18), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.18)
	_float_number(sprite.position + Vector2(0, -FRAME_W * SPRITE_SCALE - 18), "SKILL!", Color(1.0, 0.9, 0.4), true)


func _float_number(world_pos: Vector2, text: String, color: Color, big: bool) -> void:
	var l := _hud_label(20 if big else 15, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = text
	l.position = world_pos - Vector2(24, 0)
	l.size = Vector2(48, 24)
	_hud_layer.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -34), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(l.queue_free)


func _kill(target: Dictionary) -> void:
	if not target["alive"]:
		return
	target["alive"] = false
	target["anim"] = "idle"
	var sprite: Sprite2D = target["sprite"]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_property(sprite, "rotation", deg_to_rad(80.0 if target["side"] == "enemy" else -80.0), 0.5)
	tw.tween_property(sprite, "position:y", sprite.position.y + 10.0, 0.5)
	target["name_label"].visible = false


# ---------------------------------------------------------------- overlay + draw

func _update_overlay(u: Dictionary) -> void:
	var nl: Label = u["name_label"]
	if not u["alive"]:
		nl.visible = false
		return
	var sprite: Sprite2D = u["sprite"]
	var top := sprite.position.y - SPRITE_H
	nl.size = Vector2(140, 18)
	nl.position = Vector2(sprite.position.x - 70, top - 34)


func _draw() -> void:
	if _phase == "boot":
		return
	# shadows + hp bars, drawn under the sprite nodes (parent draws first)
	var order := _units.duplicate()
	order.sort_custom(func(a, b): return a["sprite"].position.y < b["sprite"].position.y)
	for u in order:
		var sprite: Sprite2D = u["sprite"]
		var pos: Vector2 = sprite.position
		if u["alive"]:
			# soft elliptical feet shadow
			draw_set_transform(pos, 0.0, Vector2(1.0, 0.34))
			draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.16))
			draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.20))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# hp bar above head
			_draw_hp(u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp(u: Dictionary) -> void:
	var sprite: Sprite2D = u["sprite"]
	var stats = u["stats"]
	var frac: float = clamp(stats.current_hp / float(u["hp_max"]), 0.0, 1.0)
	var w := 78.0
	var h := 9.0
	var top := sprite.position.y - SPRITE_H - 12
	var origin := Vector2(sprite.position.x - w * 0.5, top)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(w + 4, h + 4)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0.10, 0.08, 0.09))
	var fill_col := Color(0.42, 0.85, 0.40) if u["side"] == "ally" else Color(0.90, 0.42, 0.40)
	if frac < 0.34:
		fill_col = Color(0.95, 0.72, 0.30)
	draw_rect(Rect2(origin, Vector2(w * frac, h)), fill_col)


# ---------------------------------------------------------------- wave flow

func _check_wave_end(delta: float) -> void:
	var allies_alive := _living("ally").size()
	var enemies_alive := _living("enemy").size()
	if allies_alive == 0:
		_end("lost")
	elif enemies_alive == 0:
		if _wave >= GameState.MAX_WAVE:
			_end("won")
		else:
			_advance_wave()


func _advance_wave() -> void:
	_wave += 1
	GameState.advance_to_wave(_wave)
	_spawn_wave()


func _end(result: String) -> void:
	_phase = result
	_post_timer = 3.0
	_banner_label.visible = true
	if result == "won":
		_banner_label.text = "VICTORY!"
		_banner_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	else:
		_banner_label.text = "DEFEATED"
		_banner_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
