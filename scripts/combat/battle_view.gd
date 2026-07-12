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
const RunStateClass = preload("res://scripts/roguelike/run_state.gd")
const CardSystemClass = preload("res://scripts/roguelike/card_system.gd")
const DraftViewClass = preload("res://scripts/ui/draft_view.gd")
const StatModifierClass = preload("res://scripts/combat/stat_modifier.gd")

const BASE_STARTER_IDS := [
	"maincoon_ironmane", "shorthold_emberpaw", "bengalis_wildstripe",
	"siamheart_voicecasters", "persephone_silkpaw", "ragdollan_cloudfur",
]

const SPRITE_SCALE := 2.5                 # 3x source frame (48px) -> ~120px tall hero
const FRAME_W := 48.0
const SPRITE_H := FRAME_W * SPRITE_SCALE
const GROUND_Y_RATIO := 0.74              # ground line as a fraction of view height
const IDLE_FRAME_SECONDS := 0.22
const WALK_FRAME_SECONDS := 0.12
const ANIM_ROW := 1                       # side-facing track in the 4x4 sheet
const HP_MULT := 2.4                      # fatten the HP pool so fights are watchable
const CADENCE_BASE := 1.5                 # seconds-per-attack scalar (higher = slower)
const HORIZ_STEP := 120.0                 # horizontal spacing along the battle lane
const MAP_PLAN_PATH := "res://data/maps/emberhearth_map_plan.json"
const AUTO_CAST_GRACE := 2.2              # a ready skill waits this long for a tap, then auto-fires
const GROUND_LAYERS := ["patches", "roads", "beach", "water"]  # override order (later wins)
const WALK_SPEED_SCALE := 1.8             # multiplies profile move_speed for on-screen approach
const SPEED_STEPS := [1.0, 2.0, 3.0]      # battle-speed cycle (Engine.time_scale)

# Skill id -> mini-icon number (falls back to effect_type, see _skill_icon_texture).
const SKILL_ICONS := {
	"wildstripe_burst": 9,    # sword
	"ironmane_bulwark": 10,   # shield
	"silkpaw_ward": 1,        # star ward
	"cloudfur_mend": 14,      # heal cross
	"voicecaster_chord": 13,  # magic note
	"emberpaw_dash": 9,       # sword
}

# --- reference-driven UI maps (fantasy-twilight battle chrome) ---
const SKILL_ROLE := {
	"ironmane_bulwark": "GUARDIAN", "wildstripe_burst": "STRIKER",
	"silkpaw_ward": "WEAVER", "cloudfur_mend": "MENDER",
	"voicecaster_chord": "STRIKER", "emberpaw_dash": "STRIKER",
}
const SKILL_NAME := {
	"ironmane_bulwark": "Bulwark Roar", "wildstripe_burst": "Thornslash",
	"silkpaw_ward": "Silkbind", "cloudfur_mend": "Mendmoon",
	"voicecaster_chord": "Chord", "emberpaw_dash": "Ember Dash",
}
const ROLE_ICON := { "GUARDIAN": "shield", "STRIKER": "sword", "WEAVER": "spindle", "MENDER": "plus" }
const CLAN_LEVEL := { "Ironmane": 24, "Wildstripe": 22, "Silkpaw": 21, "Cloudfur": 23, "Voicecasters": 20 }
const NAV_ITEMS := [
	{ "id": "fight", "label": "FIGHT", "icon": "fight" },
	{ "id": "map", "label": "MAP", "icon": "map" },
	{ "id": "party", "label": "PARTY", "icon": "book" },
	{ "id": "base", "label": "BASE", "icon": "house" },
	{ "id": "summon", "label": "SUMMON", "icon": "orb" },
	{ "id": "hero", "label": "HERO", "icon": "star" },
]
const TOP_BAR_H := 72.0

# twilight palette
const COL_PANEL := Color(0.141, 0.102, 0.243)
const COL_OUTLINE := Color(0.078, 0.039, 0.141)
const COL_BEVEL := Color(0.290, 0.239, 0.494)
const COL_INSET := Color(0.070, 0.047, 0.141)
const COL_GOLD := Color(1.0, 0.824, 0.478)
const COL_GOLD2 := Color(1.0, 0.878, 0.639)
const COL_TEAL := Color(0.373, 0.878, 0.784)
const COL_VIOLET := Color(0.725, 0.545, 1.0)
const COL_ROSE := Color(1.0, 0.435, 0.561)
const COL_LAV := Color(0.702, 0.651, 0.839)
const COL_HP_A := Color(0.498, 0.910, 0.404)
const COL_CTA_A := Color(1.0, 0.808, 0.329)
const COL_CTA_B := Color(0.949, 0.584, 0.235)

# pixel-icon grids (8x8), rendered to ImageTextures at runtime (see _build_icons)
const ICON_GRIDS := {
	"coin": ["..CCCC..", "CCLLCCCC", "CLHLLHLC", "CLLLLLLC", "CLHLLHLC", "CLLLLLLC", "CCLLCCCC", "..CCCC.."],
	"gem": ["...GG...", ".GGGGGG.", "GHGGGGHG", "GGGGGGGG", ".GGGGGG.", "..GGGG..", "...GG...", "........"],
	"yarn": ["..RRRR..", ".RHRRRR.", "RRRHRRRR", "RHRRRHRR", "RRHRRRHR", "RRRHRRRR", ".RRRHRR.", "..RRRR.."],
	"shield": [".OOOOOO.", "OBBBBBBO", "OBHBBHBO", "OBBBBBBO", "OBBHHBBO", "OBBBBBBO", ".OBBBBO.", "..OOOO.."],
	"sword": ["......OO", ".....OWO", "....OWO.", "O.OWWO..", "OWWWO...", ".OWO.O..", "OWO..OO.", "OO....O."],
	"spindle": ["...OO...", "..OWWO..", "..OWWO..", "OOOWWOOO", ".OWWWWO.", "..OWWO..", "..OWWO..", "..OOOO.."],
	"plus": ["...OO...", "...WW...", "...WW...", "OOWWWWOO", "OWWWWWWO", "OOWWWWOO", "...WW...", "...OO..."],
	"star": ["...OO...", "...WW...", "..OWWO..", "OWWWWWWO", ".OWWWWO.", "..OWWO..", "..O..O..", "........"],
	"house": ["...OO...", "..OWWO..", ".OWWWWO.", "OWWWWWWO", "OWGGWGWO", "OWWGGWWO", "OWWGGWWO", "OOOOOOOO"],
	"map": ["OOOOOOOO", "OWLWWLWO", "OWLWWLWO", "OWWGGWWO", "OWWGGWWO", "OWLWWLWO", "OWLWWLWO", "OOOOOOOO"],
	"orb": ["..OOOO..", ".OWWWWO.", "OWHWWWWO", "OWWWWWWO", "OWWWWWWO", "OWWWWWWO", ".OWWWWO.", "..OOOO.."],
	"fight": [".O....O.", "OWO..OWO", ".OWOOWO.", "..OWWO..", "..OWWO..", ".OWOOWO.", "OWO..OWO", ".O....O."],
	"book": ["OOOOOOOO", "OLLOLLLO", "OLLOLLLO", "OLLOLLLO", "OLLOLLLO", "OLLOLLLO", "OLLOLLLO", "OOOOOOOO"],
	"crest": ["...OO...", "..OGGO..", ".OGWWGO.", "OGWLLWGO", "OGWLLWGO", ".OGWWGO.", "..OGGO..", "...OO..."],
}

# --- screen data (Purralia) ---
const DECK_D := 84.0                    # CRK skill-deck portrait diameter
const RARITY_COL := {
	"legend": Color(1.0, 0.824, 0.478), "epic": Color(0.725, 0.545, 1.0),
	"rare": Color(0.373, 0.878, 0.784), "common": Color(0.541, 0.498, 0.690),
}
const SKILL_DESC := {
	"ironmane_bulwark": "Raises a stoneweave bulwark — shields the whole party and taunts the front foe.",
	"wildstripe_burst": "A blur of claws: five rapid strikes on the front enemy, each with a chance to crit.",
	"silkpaw_ward": "Moonlit threads ensnare the front foe, sapping its defense and slowing its step.",
	"cloudfur_mend": "Soft blossom-light rains down, healing every ally for a large amount.",
	"voicecaster_chord": "A resonant chord bursts across the enemy line for arcane damage.",
	"emberpaw_dash": "Dashes clean through the foe, leaving embers that burn over time.",
}
const REGION_DATA := [
	{ "n": 1, "name": "Emberhearth", "sub": "Pawmont · Chapter 1 — cleared 8/10", "status": "current" },
	{ "n": 2, "name": "Tanglefen Mire", "sub": "Mistmarsh · Chapter 2 — unlocked", "status": "enter" },
	{ "n": 3, "name": "Frostwhisker Peaks", "sub": "Chapter 3 — clear Emberhearth to unlock", "status": "locked" },
	{ "n": 4, "name": "Gildengrove", "sub": "Chapter 4 — locked", "status": "locked" },
	{ "n": 5, "name": "Duskmoon Hollow", "sub": "Chapter 5 — the final loom", "status": "locked" },
]
const BUILDING_DATA := [
	{ "id": "spinnery", "name": "Yarn Spinnery", "icon": "yarn", "prod": "+120 Yarn / 4h", "res": "yarn", "amt": 120, "init": "ready" },
	{ "id": "goldmill", "name": "Gilded Mill", "icon": "coin", "prod": "+200 Gold / 6h", "res": "gold", "amt": 200, "init": "producing" },
	{ "id": "geode", "name": "Gem Geode", "icon": "gem", "prod": "+5 Gems / 12h", "res": "gems", "amt": 5, "init": "producing" },
	{ "id": "cafe", "name": "Cat Café", "icon": "house", "prod": "+80 Gold / 2h", "res": "gold", "amt": 80, "init": "ready" },
]
const GACHA_POOL := [
	{ "name": "Aurelune", "rarity": "legend", "shortcut": "unit.support_idle" },
	{ "name": "Nightsilk", "rarity": "epic", "shortcut": "unit.mage_idle" },
	{ "name": "Tidecaller", "rarity": "epic", "shortcut": "unit.ranged_idle" },
	{ "name": "Cinderpaw", "rarity": "rare", "shortcut": "unit.striker_idle" },
	{ "name": "Fernlily", "rarity": "rare", "shortcut": "unit.healer_idle" },
	{ "name": "Pippin", "rarity": "common", "shortcut": "unit.worker_idle" },
	{ "name": "Sootmuffin", "rarity": "common", "shortcut": "unit.scout_idle" },
]
const EQUIP_SLOTS := [
	{ "slot": "Weapon", "icon": "sword", "item": "Emberfang Maul", "rarity": "legend" },
	{ "slot": "Armor", "icon": "shield", "item": "Bulwark Plate", "rarity": "epic" },
	{ "slot": "Collar", "icon": "star", "item": "Oathbound Collar", "rarity": "rare" },
	{ "slot": "Charm", "icon": "spindle", "item": "Warmstone Charm", "rarity": "rare" },
	{ "slot": "Trinket", "icon": "orb", "item": "—", "rarity": "common" },
]
const PITY_MAX := 90

var _factory
var _units: Array = []                    # Array of unit dictionaries
var _bg_layer: CanvasLayer
var _hud_layer: CanvasLayer
var _sky: TextureRect
var _map_root: Control
var _title_label: Label
var _wave_label: Label
var _banner_label: Label
var _skill_bar: Control                   # bottom row of hero cards
var _taskbar: Control                     # top bar (crest + region + currencies + nav) and sub-header
var _menu_panel: Control
var _speed_btn: Button
var _speed_idx: int = 0
var _warp_layer: CanvasLayer
var _warp_rect: ColorRect
var _warp_tween: Tween = null             # active wave-swap flash tween, if any
var _hp_frame_tex: Texture2D              # slider-frame art for unit HP bars
var _book_layer: CanvasLayer              # book-style party menu (Spellbook art)
var _book: Control
var _view_size: Vector2
var _battle_y: float = 0.0
var _wave: int = 1
var _phase: String = "boot"               # boot | fighting | won | lost
var _post_timer: float = 0.0
var _font: Font

# --- roguelike run state ---
var _run                                   # RunState
var _card_system                           # CardSystem
var _draft                                 # DraftView
var _roster_ids: Array = []                # clan_ids recruitable this run
var _rng: RandomNumberGenerator
var _pending_cards: Array = []             # CardData currently shown in the draft
var _picking_starter: bool = false
var _starter_ids_cache: Array = []

# --- new twilight HUD state ---
var _cards: Array = []                     # hero cards: {unit, hp_fill, hp_w, hp_txt, name, skbtn, cd, cd_w, cd_h, sk_txt, ready}
var _gems: int = 53                        # cosmetic currencies (Gold = GameState.currency)
var _yarn: int = 15
var _curr_labels: Dictionary = {}          # kind -> value Label
var _wave_fill: ColorRect
var _wave_fill_w: float = 0.0
var _tangles_label: Label
var _auto_dot: ColorRect
var _wave_enemy_count: int = 0
var _toast_layer: CanvasLayer
var _icon_cache: Dictionary = {}
var _tex_cache: Dictionary = {}            # generated disc/ring/gradient textures

# --- screen overlay system (MAP / PARTY / HERO / BASE / SUMMON) ---
var _screen_layer: CanvasLayer
var _screen_root: Control
var _current_screen: String = ""
var _hero_focus                            # unit dict shown on the HERO screen
var _region_status: Array = []             # mutable copy of REGION_DATA statuses
var _building_state: Dictionary = {}       # building id -> "ready" | "producing"
var _pity: int = 37
var _gacha_busy: bool = false
var _sel_slot: int = -1                    # selected formation slot on the PARTY screen
var _nav_by_id: Dictionary = {}            # nav id -> Button (for active-state restyling)
var _pity_fill: ColorRect                  # SUMMON screen pity bar fill
var _pity_lbl: Label
var _reveal_box: Control                   # SUMMON screen pull-result container


func _ready() -> void:
	Engine.time_scale = 1.0
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_font = ThemeDB.fallback_font
	_build_icons()
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
	if GameState.currency < 100:               # seed a reference-like treasury for the demo
		GameState.add_currency(3990 - GameState.currency)
	for r in REGION_DATA:
		_region_status.append(str(r["status"]))
	for b in BUILDING_DATA:
		_building_state[str(b["id"])] = str(b["init"])
	_hp_frame_tex = _ui_texture("ui.hp_bar_frame", "1x")
	_view_size = get_viewport().get_visible_rect().size
	_layout_background()
	_card_system = CardSystemClass.new()
	_card_system.load_all()
	_roster_ids = _factory.clan_ids()
	_begin_starter_pick()


# ---------------------------------------------------------------- scene scaffold

func _build_layers() -> void:
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -10
	add_child(_bg_layer)

	_sky = TextureRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_layer.add_child(_sky)

	_map_root = Control.new()          # holds the tiled village battlefield
	_map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(_map_root)

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

	_skill_bar = Control.new()
	_skill_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the buttons catch input
	_hud_layer.add_child(_skill_bar)

	_taskbar = Control.new()
	_taskbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_taskbar)

	_warp_layer = CanvasLayer.new()                        # full-screen warp flash, above HUD
	_warp_layer.layer = 20
	add_child(_warp_layer)
	_warp_rect = ColorRect.new()
	_warp_rect.color = Color(0.62, 0.86, 1.0)
	_warp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warp_rect.modulate.a = 0.0
	_warp_layer.add_child(_warp_rect)

	# Taskbar background is translucent — keep it behind the title/wave labels and
	# banner (which were added earlier) so they stay crisp on top of the bar.
	_hud_layer.move_child(_taskbar, 0)

	_book_layer = CanvasLayer.new()            # book-style party menu, above the HUD
	_book_layer.layer = 15
	add_child(_book_layer)
	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.visible = false
	_book_layer.add_child(_book)

	_screen_layer = CanvasLayer.new()          # full-screen nav overlays (map/party/hero/base/summon)
	_screen_layer.layer = 16
	add_child(_screen_layer)
	_screen_root = Control.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # top-bar nav stays clickable behind screens
	_screen_root.visible = false
	_screen_layer.add_child(_screen_root)

	_toast_layer = CanvasLayer.new()           # transient toasts, above everything
	_toast_layer.layer = 25
	add_child(_toast_layer)


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
		_build_skill_bar()


func _layout_background() -> void:
	var w := _view_size.x
	var h := _view_size.y

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

	_render_map()

	_banner_label.size = Vector2(w, 60)
	_banner_label.position = Vector2(0, h * 0.36)
	_build_taskbar()
	_refresh_wave_label()


func _refresh_wave_label() -> void:
	_wave_label.text = "WAVE %d / %d" % [_wave, GameState.MAX_WAVE]
	_update_wave_progress()


# ---------------------------------------------------------------- map background

func _render_map() -> void:
	for c in _map_root.get_children():
		c.queue_free()
	var plan := _load_map_plan()
	var mw: int = int(plan.get("map_width", 28))
	var mh: int = int(plan.get("map_height", 8))
	var layers = plan.get("tile_layers", {})
	if typeof(layers) != TYPE_DICTIONARY or mw <= 0 or mh <= 0:
		_battle_y = _view_size.y * GROUND_Y_RATIO
		return
	var tile_px: float = _view_size.x / float(mw)
	var map_h: float = tile_px * float(mh)
	var y_off: float = _view_size.y - map_h            # village sits along the bottom
	_battle_y = y_off + map_h * 0.55                   # the battle lane (on the road band)
	# Opaque ground behind the tiles: these autotile tiles have scalloped transparent
	# corners, so without a base fill the sky gradient bleeds through as murky gaps.
	var land_h: float = map_h * 0.84
	var base := ColorRect.new()
	base.color = Color(0.44, 0.62, 0.28)               # grass green
	base.position = Vector2(0, y_off)
	base.size = Vector2(_view_size.x, land_h)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_root.add_child(base)
	var shore := ColorRect.new()
	shore.color = Color(0.20, 0.42, 0.52)              # shallow water under the coast
	shore.position = Vector2(0, y_off + land_h)
	shore.size = Vector2(_view_size.x, map_h - land_h)
	shore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_root.add_child(shore)
	for y in mh:
		for x in mw:
			for t in _cell_tiles(layers, x, y):
				var tex = _load_tile(str(t["name"]), int(t["ox"]), int(t["oy"]))
				if tex == null:
					continue
				var tr := TextureRect.new()
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.position = Vector2(float(x) * tile_px, y_off + float(y) * tile_px)
				tr.size = Vector2(tile_px + 1.0, tile_px + 1.0)  # +1 hides seams
				_map_root.add_child(tr)


func _cell_tiles(layers: Dictionary, x: int, y: int) -> Array:
	var out: Array = []
	var ground = layers.get("ground_fill", {})
	var ground_name := "grass"
	if typeof(ground) == TYPE_DICTIONARY:
		ground_name = str(ground.get("tile", "grass"))
	for lname in GROUND_LAYERS:
		for e in layers.get(lname, []):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			if _in_rect(x, y, e):
				ground_name = str(e.get("tile", ground_name))
	out.append({ "name": ground_name, "ox": 0, "oy": 0 })
	for d in layers.get("decor", []):
		if typeof(d) == TYPE_DICTIONARY and int(d.get("x", -1)) == x and int(d.get("y", -1)) == y:
			out.append({ "name": str(d.get("tile", "")), "ox": 0, "oy": 0 })
	for s in layers.get("stamps", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if _in_rect(x, y, s):
			out.append({ "name": str(s.get("tile", "")), "ox": x - int(s.get("x", 0)), "oy": y - int(s.get("y", 0)) })
	return out


func _in_rect(x: int, y: int, e: Dictionary) -> bool:
	var rx := int(e.get("x", 0))
	var ry := int(e.get("y", 0))
	var rw := int(e.get("width", 1))
	var rh := int(e.get("height", 1))
	return x >= rx and x < rx + rw and y >= ry and y < ry + rh


func _load_tile(tile_name: String, ox: int, oy: int):
	if tile_name == "":
		return null
	if ox == 0 and oy == 0:
		return AssetRegistry.load_map_tile(tile_name)
	return AssetRegistry.load_map_tile_offset(tile_name, ox, oy)


func _load_map_plan() -> Dictionary:
	if not FileAccess.file_exists(MAP_PLAN_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_PLAN_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# ---------------------------------------------------------------- wave spawning

func _spawn_wave() -> void:
	_clear_units()
	var ground_y: float = _battle_y if _battle_y > 0.0 else _view_size.y * GROUND_Y_RATIO

	var party: Array = GameState.party
	var allies: Array = []
	for u in party:
		var au := _build_unit(_factory.build_from_clan(str(u.clan_id)), str(u.display_name), "ally", str(u.idle_asset), str(u.move_asset))
		au["clan_id"] = str(u.clan_id)
		allies.append(au)
	# Allies are rebuilt each wave from fresh StatSystems, so re-apply the run's
	# accumulated upgrades (this also makes recruits inherit party upgrades).
	if _run != null:
		for res in _run.upgrades:
			_apply_one_upgrade(res, allies)
		for a in allies:
			a["stats"].current_hp = a["stats"].get_stat(CombatEnumsClass.StatKey.HP)
			a["hp_max"] = maxf(1.0, a["stats"].get_stat(CombatEnumsClass.StatKey.HP))

	var enemies: Array = []
	if GameState.wave_state != null:
		for e in GameState.wave_state.enemies:
			var eu := _build_unit(_factory.build_from_enemy(str(e.enemy_id)), str(e.display_name), "enemy", str(e.idle_asset), str(e.move_asset))
			_scale_enemy(eu, _wave)
			enemies.append(eu)

	_place_side(allies, true, ground_y)
	_place_side(enemies, false, ground_y)
	_units = allies + enemies
	_wave_enemy_count = enemies.size()
	_build_skill_bar()
	_refresh_wave_label()


func _place_side(side_units: Array, is_ally: bool, battle_y: float) -> void:
	# Original TBH layout: one horizontal battle lane. Party lines up left-to-right
	# on the left, monsters on the right, both on the same lane, facing each other.
	# They hold the line and lunge to strike.
	var n := side_units.size()
	# Order by lane so the front line stands nearest the enemy and the backline
	# (ranged/support/healer) sits behind it — allies fight rightward, enemies leftward.
	var ordered := side_units.duplicate()
	ordered.sort_custom(func(a, b): return (a["lane"] > b["lane"]) if is_ally else (a["lane"] < b["lane"]))
	var total := float(max(0, n - 1)) * HORIZ_STEP
	var start_x: float = _view_size.x * 0.15 if is_ally else _view_size.x * 0.85 - total
	for i in n:
		var unit: Dictionary = ordered[i]
		var x := start_x + float(i) * HORIZ_STEP
		# Gentle vertical stagger so units stay readable when they converge on a target.
		var y := battle_y + (float(i) - float(n - 1) * 0.5) * 9.0
		var sprite: Sprite2D = unit["sprite"]
		sprite.position = Vector2(x, y)
		sprite.flip_h = is_ally  # source frames face left; flip allies to face right
		unit["home_x"] = x
		unit["home_y"] = y
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
		"ready_hold": 0.0,
		"alive": true,
		"home_x": 0.0,
		"base_mod": (Color(1.0, 0.72, 0.70) if side == "enemy" else Color.WHITE),
		"clan_id": "",
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
		if _phase == "fighting" and u["alive"]:
			_act(u, delta)
		_update_overlay(u)

	_update_skill_bar()
	if _phase == "fighting" and _run != null and _run.pending_levelups > 0:
		_open_draft()
		return
	if _phase == "fighting":
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
	# Approach then strike: walk toward the nearest enemy until inside attack_range,
	# then hold and attack on cadence. Melee (small range) close in; ranged stay back.
	var target = _nearest_enemy(u)
	if target == null:
		u["anim"] = "idle"
		return
	var dx: float = target["sprite"].position.x - u["sprite"].position.x
	var dist: float = absf(dx)
	var rng: float = float(u["atk_range"])
	if dist > rng:
		_walk_toward(u, dx, dist - rng, delta)
		var sk = u["skill"]   # keep the skill cooling while marching in
		if sk != null and not sk.is_ready():
			sk.tick(delta, float(u["stats"].get_stat(CombatEnumsClass.StatKey.COOLDOWN_REDUCTION)))
		return

	u["anim"] = "idle"
	u["sprite"].flip_h = dx > 0.0
	var skill = u["skill"]
	if skill != null:
		if skill.is_ready():
			# Hand it to the player first: hold ready for a grace window, then auto-fire.
			u["ready_hold"] = float(u["ready_hold"]) + delta
			if u["ready_hold"] >= AUTO_CAST_GRACE:
				_do_cast(u, skill)
				return
		else:
			u["ready_hold"] = 0.0
			skill.tick(delta, float(u["stats"].get_stat(CombatEnumsClass.StatKey.COOLDOWN_REDUCTION)))
	u["atk_t"] += delta
	var cadence: float = CADENCE_BASE / max(0.5, float(u["stats"].get_stat(CombatEnumsClass.StatKey.ATK_SPD)))
	if u["atk_t"] >= cadence:
		u["atk_t"] = 0.0
		_basic_attack(u, target)


func _walk_toward(u: Dictionary, dx: float, remaining: float, delta: float) -> void:
	u["anim"] = "move"
	var sprite: Sprite2D = u["sprite"]
	sprite.flip_h = dx > 0.0   # source frames face left; flip to face travel direction
	var step: float = minf(float(u["move_speed"]) * WALK_SPEED_SCALE * delta, remaining)
	if step > 0.0:
		sprite.position.x += signf(dx) * step


func _basic_attack(u: Dictionary, target: Dictionary) -> void:
	var r := DamageCalculatorClass.compute(u["stats"], target["stats"], 1.0)
	target["stats"].take_damage(float(r.amount))
	_lunge(u, target)
	_hit(target, r.amount, r.is_crit, false)
	if not target["stats"].is_alive():
		_kill(target)


func _do_cast(u: Dictionary, skill) -> void:
	_cast_skill(u, skill)
	skill.trigger()
	u["ready_hold"] = 0.0


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


# ---------------------------------------------------------------- skill menu

func _build_skill_bar() -> void:
	# CRK-style skill deck: a centered row of circular hero portraits with a radial
	# cooldown sweep and a gold glow when the skill is ready. Tap the portrait to cast.
	if _skill_bar == null:
		return
	for c in _skill_bar.get_children():
		c.queue_free()
	_cards.clear()

	var allies: Array = []
	for u in _units:
		if u["side"] == "ally":
			allies.append(u)
	if allies.is_empty():
		return

	var n := allies.size()
	var slot_w := DECK_D + 40.0
	var total := float(n) * slot_w
	var start_x := (_view_size.x - total) * 0.5 + (slot_w - DECK_D) * 0.5
	var cy := _view_size.y - DECK_D - 44.0

	# soft deck tray behind the portraits
	var tray_w := total + 26.0
	var tray := _deco_panel(Vector2((_view_size.x - tray_w) * 0.5, cy - 18.0),
		Vector2(tray_w, DECK_D + 60.0), Color(0.17, 0.12, 0.30), Color(0.10, 0.07, 0.19))
	_skill_bar.add_child(tray)

	for i in n:
		var x: float = start_x + float(i) * slot_w
		_build_skill_slot(allies[i], x, cy, DECK_D)
	_update_skill_bar()


func _jrpg_window(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.19, 0.92)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.58, 0.64, 0.85)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_skill_slot(u: Dictionary, x: float, y: float, d: float) -> void:
	var di := int(d)
	var rar := _rarity_of(u)

	# ready glow (behind everything, pulses when castable)
	var glow := TextureRect.new()
	glow.texture = _circle_tex(int(d + 24.0), Color(1.0, 0.85, 0.45))
	glow.position = Vector2(x - 12.0, y - 12.0)
	glow.size = Vector2(d + 24.0, d + 24.0)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	_skill_bar.add_child(glow)

	# dark disc backing + portrait
	var disc := TextureRect.new()
	disc.texture = _circle_tex(di, Color(0.10, 0.07, 0.18))
	disc.position = Vector2(x, y)
	disc.size = Vector2(d, d)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(disc)
	var frames: Array = u["idle_frames"]
	if not frames.is_empty():
		var spr := TextureRect.new()
		spr.texture = frames[0]
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var inset := d * 0.15
		spr.position = Vector2(x + inset, y + inset - 5.0)
		spr.size = Vector2(d - inset * 2.0, d - inset * 2.0)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skill_bar.add_child(spr)

	# radial cooldown sweep (dark wedge over the portrait; value = fraction remaining)
	var cool := TextureProgressBar.new()
	cool.texture_progress = _circle_tex(di, Color(0.05, 0.03, 0.11, 0.80))
	cool.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	cool.min_value = 0.0
	cool.max_value = 1.0
	cool.value = 0.0
	cool.position = Vector2(x, y)
	cool.size = Vector2(d, d)
	cool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(cool)

	# rarity/gold ring frame
	var ring := TextureRect.new()
	ring.texture = _ring_tex(di, 5.0, RARITY_COL.get(rar, COL_GOLD))
	ring.position = Vector2(x, y)
	ring.size = Vector2(d, d)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(ring)

	# Lv badge
	var lv := _hud_label(8, Color.WHITE)
	lv.add_theme_constant_override("outline_size", 3)
	lv.text = "L%d" % _hero_level(u)
	lv.position = Vector2(x + 5.0, y + 3.0)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(lv)

	# cooldown seconds (center)
	var secs := _hud_label(17, Color.WHITE)
	secs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secs.position = Vector2(x, y + d * 0.30)
	secs.size = Vector2(d, 26)
	secs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(secs)

	# name + skill name below
	var name_l := _hud_label(9, COL_GOLD2)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text = str(u["name"]).split(" ")[0]
	name_l.position = Vector2(x - 14.0, y + d + 2.0)
	name_l.size = Vector2(d + 28.0, 14)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(name_l)
	var sk = u["skill"]
	var sk_l := _hud_label(8, COL_LAV)
	sk_l.add_theme_constant_override("outline_size", 2)
	sk_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sk_l.text = _skill_display_name(sk) if sk != null else "—"
	sk_l.position = Vector2(x - 18.0, y + d + 16.0)
	sk_l.size = Vector2(d + 36.0, 14)
	sk_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.add_child(sk_l)

	# tap = cast
	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(x, y)
	btn.size = Vector2(d, d)
	btn.focus_mode = Control.FOCUS_NONE
	if sk != null:
		btn.pressed.connect(_on_skill_pressed.bind(u))
	_skill_bar.add_child(btn)

	_cards.append({ "unit": u, "cool": cool, "secs": secs, "ring": ring, "glow": glow, "disc": disc, "ready": false })


func _rarity_of(u: Dictionary) -> String:
	match str(u["name"]).split(" ")[0]:
		"Ironmane", "Cloudfur":
			return "legend"
		"Wildstripe", "Silkpaw":
			return "epic"
		_:
			return "rare"


func _stars(rar: String) -> String:
	var n: int = {"legend": 5, "epic": 4, "rare": 3, "common": 2}.get(rar, 3)
	var s := ""
	for i in 5:
		s += "★" if i < n else "☆"
	return s


func _hero_role(u: Dictionary) -> String:
	var skill = u["skill"]
	if skill != null and SKILL_ROLE.has(str(skill.id)):
		return String(SKILL_ROLE[str(skill.id)])
	return "STRIKER"


func _hero_level(u: Dictionary) -> int:
	if u.has("level"):
		return int(u["level"])
	var nm := str(u["name"]).split(" ")[0]
	return int(CLAN_LEVEL.get(nm, 20 + GameState.upgrade_level))


func _skill_icon_name(skill) -> String:
	if skill == null:
		return "star"
	var role := String(SKILL_ROLE.get(str(skill.id), ""))
	if ROLE_ICON.has(role):
		return String(ROLE_ICON[role])
	match str(skill.effect_type):
		"heal": return "plus"
		"aoe_damage": return "sword"
		"buff": return "spindle"
		_: return "star"


func _skill_display_name(skill) -> String:
	if skill == null:
		return "Skill"
	return String(SKILL_NAME.get(str(skill.id), "Skill"))


func _update_skill_bar() -> void:
	# currency chips
	if _curr_labels.has("coin"):
		_curr_labels["coin"].text = str(GameState.currency)
	if _curr_labels.has("gem"):
		_curr_labels["gem"].text = str(_gems)
	if _curr_labels.has("yarn"):
		_curr_labels["yarn"].text = str(_yarn)
	# AUTO pulse (unscaled clock so it beats independently of battle speed)
	if _auto_dot != null and is_instance_valid(_auto_dot):
		var tt := float(Time.get_ticks_msec()) * 0.005
		_auto_dot.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(tt))
	_update_wave_progress()
	# CRK skill deck: radial cooldown + gold glow when ready
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
	for card in _cards:
		var u: Dictionary = card["unit"]
		var alive: bool = u["alive"]
		var skill = u["skill"]
		var cool: TextureProgressBar = card["cool"]
		var secs: Label = card["secs"]
		var ring: TextureRect = card["ring"]
		var glow: TextureRect = card["glow"]
		var disc: TextureRect = card["disc"]
		if not alive:
			cool.value = 1.0
			secs.text = ""
			glow.visible = false
			ring.modulate = Color(0.5, 0.5, 0.55)
			disc.modulate = Color(0.5, 0.5, 0.55)
			continue
		disc.modulate = Color.WHITE
		if skill == null:
			cool.value = 0.0
			secs.text = ""
			glow.visible = false
			continue
		if skill.is_ready():
			cool.value = 0.0
			secs.text = ""
			glow.visible = true
			glow.modulate.a = 0.30 + 0.45 * pulse
			ring.modulate = Color(1.0 + 0.4 * pulse, 0.92, 0.58)   # gold shimmer
		else:
			cool.value = clampf(skill.remaining / max(0.01, skill.cooldown), 0.0, 1.0)
			secs.text = "%d" % int(ceil(skill.remaining))
			glow.visible = false
			ring.modulate = Color.WHITE
		card["ready"] = skill.is_ready()


func _update_wave_progress() -> void:
	if _wave_fill == null or not is_instance_valid(_wave_fill):
		return
	var enemies_alive := _living("enemy").size()
	var total: int = _wave_enemy_count if _wave_enemy_count > 0 else max(1, enemies_alive)
	var cleared: float = float(total - enemies_alive) / float(total)
	var frac: float = (float(_wave - 1) + cleared) / float(GameState.MAX_WAVE)
	_wave_fill.size.x = _wave_fill_w * clampf(frac, 0.0, 1.0)
	if _tangles_label != null and is_instance_valid(_tangles_label):
		_tangles_label.text = "%d %s remaining" % [enemies_alive, ("tangle" if enemies_alive == 1 else "tangles")]


func _on_skill_pressed(u: Dictionary) -> void:
	if not u["alive"]:
		return
	var skill = u["skill"]
	if skill == null or not skill.is_ready():
		return
	if skill.target_side == "enemy" and _living_enemies(u).is_empty():
		return
	_do_cast(u, skill)


func _skill_icon_texture(skill_id: String, effect_type: String) -> Texture2D:
	var n: int = SKILL_ICONS.get(skill_id, 0)
	if n == 0:
		n = {"aoe_damage": 9, "heal": 14, "buff": 10}.get(effect_type, 1)
	for sc in ["2x", "1x"]:
		var cid := "ui_%s_mini_icon_icon_%02d" % [sc, n]
		if AssetRegistry.has_asset(cid):
			return AssetRegistry.load_texture(cid)
	return null


# ---------------------------------------------------------------- command taskbar

func _build_taskbar() -> void:
	if _taskbar == null:
		return
	for c in _taskbar.get_children():
		c.queue_free()
	_speed_btn = null
	_curr_labels.clear()
	var w := _view_size.x

	# --- chunky twilight top bar (gradient + gold divider) ---
	var bar := _deco_panel(Vector2.ZERO, Vector2(w, TOP_BAR_H), Color(0.22, 0.16, 0.40), Color(0.11, 0.08, 0.22))
	_taskbar.add_child(bar)
	var divider := ColorRect.new()
	divider.color = COL_GOLD
	divider.position = Vector2(0, TOP_BAR_H - 3.0)
	divider.size = Vector2(w, 3)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taskbar.add_child(divider)

	# crest (click -> game menu)
	var crest := Button.new()
	crest.flat = true
	crest.position = Vector2(14, (TOP_BAR_H - 46.0) * 0.5)
	crest.size = Vector2(46, 46)
	crest.focus_mode = Control.FOCUS_NONE
	crest.add_theme_stylebox_override("normal", _inset_sbox(false))
	crest.add_theme_stylebox_override("hover", _inset_sbox(true))
	crest.add_theme_stylebox_override("pressed", _inset_sbox(true))
	crest.pressed.connect(_toggle_menu)
	_taskbar.add_child(crest)
	var crest_ic := _icon_rect("crest", 32)
	crest_ic.position = Vector2(7, 7)
	crest.add_child(crest_ic)

	# region name + sub (reuse _title_label)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", COL_GOLD2)
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.text = "EMBERHEARTH"
	_title_label.position = Vector2(72, 11)
	var sub := _hud_label(12, COL_LAV)
	sub.add_theme_constant_override("outline_size", 3)
	sub.text = "Pawmont · Chapter 1"
	sub.position = Vector2(74, 42)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taskbar.add_child(sub)

	# currency chips (start well clear of the region title)
	var chip_x := 300.0
	for kind in ["coin", "gem", "yarn"]:
		var chip := _currency_chip(kind, chip_x)
		_taskbar.add_child(chip)
		chip_x += 108.0

	# nav (right-aligned)
	var nb_w := 60.0
	var gap := 7.0
	var total_nav := float(NAV_ITEMS.size()) * nb_w + float(NAV_ITEMS.size() - 1) * gap
	var nx := w - 14.0 - total_nav
	_nav_by_id.clear()
	for spec in NAV_ITEMS:
		var nb := _nav_button(spec, nb_w)
		nb.position = Vector2(nx, (TOP_BAR_H - 60.0) * 0.5)
		_taskbar.add_child(nb)
		_nav_by_id[str(spec["id"])] = nb
		nx += nb_w + gap

	_build_subheader(w)
	_build_menu_panel()
	_refresh_nav_active()


func _currency_chip(kind: String, x: float) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, (TOP_BAR_H - 32.0) * 0.5)
	p.size = Vector2(100, 32)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _inset_sbox(false))
	var ic := _icon_rect(kind, 20)
	ic.position = Vector2(8, 6)
	p.add_child(ic)
	var v := str(GameState.currency) if kind == "coin" else (str(_gems) if kind == "gem" else str(_yarn))
	var l := _hud_label(12, Color.WHITE)
	l.add_theme_constant_override("outline_size", 3)
	l.text = v
	l.position = Vector2(36, 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_curr_labels[kind] = l
	return p


func _nav_button(spec: Dictionary, w: float) -> Button:
	var b := Button.new()
	b.size = Vector2(w, 60)
	b.custom_minimum_size = Vector2(w, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _nav_sbox(false, false))
	b.add_theme_stylebox_override("hover", _nav_sbox(false, true))
	b.add_theme_stylebox_override("pressed", _nav_sbox(false, true))
	b.pressed.connect(_on_nav.bind(str(spec["id"])))
	var ic := _icon_rect(str(spec["icon"]), 24)
	ic.position = Vector2((w - 24.0) * 0.5, 9)
	b.add_child(ic)
	var l := _hud_label(9, COL_LAV)
	l.name = "lbl"
	l.add_theme_constant_override("outline_size", 3)
	l.text = str(spec["label"])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 38)
	l.size = Vector2(w, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


func _refresh_nav_active() -> void:
	var active_id := _current_screen if _current_screen != "" else "fight"
	for id in _nav_by_id:
		var b: Button = _nav_by_id[id]
		if not is_instance_valid(b):
			continue
		var act: bool = id == active_id
		b.add_theme_stylebox_override("normal", _nav_sbox(act, false))
		b.add_theme_stylebox_override("hover", _nav_sbox(act, true))
		b.add_theme_stylebox_override("pressed", _nav_sbox(act, true))
		var lbl := b.get_node_or_null("lbl")
		if lbl != null:
			lbl.add_theme_color_override("font_color", COL_GOLD2 if act else COL_LAV)


func _build_subheader(w: float) -> void:
	var y := TOP_BAR_H + 8.0
	var h := 34.0
	# subtle backing strip so the sub-header reads over the battlefield
	var strip := Panel.new()
	strip.position = Vector2(0, TOP_BAR_H)
	strip.size = Vector2(w, 50)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.055, 0.039, 0.109, 0.62)
	strip.add_theme_stylebox_override("panel", ss)
	_taskbar.add_child(strip)

	_wave_label.add_theme_font_size_override("font_size", 15)
	_wave_label.add_theme_color_override("font_color", COL_GOLD2)
	_wave_label.add_theme_constant_override("outline_size", 4)
	_wave_label.position = Vector2(16, y + 7)

	var bar_x := 150.0
	var bar_w := w - bar_x - 300.0
	var frame := Panel.new()
	frame.position = Vector2(bar_x, y)
	frame.size = Vector2(bar_w, h)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _inset_sbox(false))
	_taskbar.add_child(frame)
	_wave_fill = ColorRect.new()
	_wave_fill.color = COL_CTA_A
	_wave_fill.position = Vector2(bar_x + 3.0, y + 3.0)
	_wave_fill.size = Vector2(0, h - 6.0)
	_wave_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taskbar.add_child(_wave_fill)
	_wave_fill_w = bar_w - 6.0
	_tangles_label = _hud_label(11, Color(0.16, 0.09, 0.02))
	_tangles_label.add_theme_constant_override("outline_size", 0)
	_tangles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tangles_label.position = Vector2(bar_x, y + 9.0)
	_tangles_label.size = Vector2(bar_w, 20)
	_tangles_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taskbar.add_child(_tangles_label)

	# AUTO pill
	var ap := Panel.new()
	ap.position = Vector2(bar_x + bar_w + 12.0, y)
	ap.size = Vector2(94, h)
	ap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap.add_theme_stylebox_override("panel", _inset_sbox(false))
	_taskbar.add_child(ap)
	_auto_dot = ColorRect.new()
	_auto_dot.color = COL_HP_A
	_auto_dot.position = Vector2(12, (h - 12.0) * 0.5)
	_auto_dot.size = Vector2(12, 12)
	_auto_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap.add_child(_auto_dot)
	var al := _hud_label(11, COL_HP_A)
	al.text = "AUTO"
	al.position = Vector2(32, 9)
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap.add_child(al)

	# speed toggle
	_speed_btn = Button.new()
	_speed_btn.position = Vector2(bar_x + bar_w + 114.0, y)
	_speed_btn.size = Vector2(124, h)
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.text = _speed_text()
	_speed_btn.add_theme_font_size_override("font_size", 12)
	_speed_btn.add_theme_color_override("font_color", COL_GOLD2)
	_speed_btn.add_theme_color_override("font_color_hover", Color.WHITE)
	_speed_btn.add_theme_stylebox_override("normal", _stone_sbox(false))
	_speed_btn.add_theme_stylebox_override("hover", _stone_sbox(true))
	_speed_btn.add_theme_stylebox_override("pressed", _stone_sbox(true))
	_speed_btn.pressed.connect(_cycle_speed)
	_taskbar.add_child(_speed_btn)


func _on_nav(id: String) -> void:
	AudioDirector.sfx("ui_click")
	if id == "fight":
		_close_screen()
	else:
		if id == "hero":
			_hero_focus = null
		_open_screen(id)


func _toast(msg: String) -> void:
	if _toast_layer == null:
		return
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _gold_sbox())
	var tw_w: float = _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	p.size = Vector2(tw_w + 44.0, 40)
	p.position = Vector2((_view_size.x - p.size.x) * 0.5, 94)
	var l := _hud_label(13, Color(0.23, 0.12, 0.03))
	l.add_theme_constant_override("outline_size", 0)
	l.text = msg
	l.position = Vector2(22, 11)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_toast_layer.add_child(p)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# --- pixel-icon engine (string grid -> ImageTexture) + stylebox helpers ---
func _build_icons() -> void:
	var pals := {
		"coin": {"C": Color.html("f2953c"), "L": Color.html("ffd27a"), "H": Color.html("fff4d0")},
		"gem": {"G": Color.html("5fe0c8"), "H": Color.html("dffff7")},
		"yarn": {"R": Color.html("ff6f8f"), "H": Color.html("ffd0da")},
		"shield": {"O": Color.html("160c28"), "B": Color.html("5fe0c8"), "H": Color.html("eafffb")},
		"sword": {"O": Color.html("160c28"), "W": Color.html("e6dcff")},
		"spindle": {"O": Color.html("160c28"), "W": Color.html("d9c2ff")},
		"plus": {"O": Color.html("160c28"), "W": Color.html("a9f39a")},
		"star": {"O": Color.html("160c28"), "W": Color.html("ffe0a3")},
		"house": {"O": Color.html("160c28"), "W": Color.html("d9c2ff"), "G": Color.html("ffd27a")},
		"map": {"O": Color.html("160c28"), "W": Color.html("cdbff0"), "L": Color.html("9a8dc0"), "G": Color.html("7fe867")},
		"orb": {"O": Color.html("160c28"), "W": Color.html("d9c2ff"), "H": Color.html("ffffff")},
		"fight": {"O": Color.html("160c28"), "W": Color.html("ffd0da")},
		"book": {"O": Color.html("160c28"), "L": Color.html("5fe0c8")},
		"crest": {"O": Color.html("160c28"), "G": Color.html("ffd27a"), "W": Color.html("fff4d0"), "L": Color.html("f2953c")},
	}
	for name in ICON_GRIDS:
		_icon_cache[name] = _pixel_icon(ICON_GRIDS[name], pals.get(name, {}), 4)


func _pixel_icon(rows: Array, pal: Dictionary, scale: int) -> Texture2D:
	var gh := rows.size()
	var gw := String(rows[0]).length()
	var img := Image.create(gw * scale, gh * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for j in gh:
		var row := String(rows[j])
		for i in gw:
			var ch := row[i]
			if not pal.has(ch):
				continue
			var col: Color = pal[ch]
			for yy in scale:
				for xx in scale:
					img.set_pixel(i * scale + xx, j * scale + yy, col)
	return ImageTexture.create_from_image(img)


func _icon(name: String) -> Texture2D:
	return _icon_cache.get(name, null)


func _icon_rect(name: String, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _icon(name)
	tr.size = Vector2(px, px)
	tr.custom_minimum_size = Vector2(px, px)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _inset_sbox(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.09, 0.24) if hover else COL_INSET
	s.set_border_width_all(3)
	s.border_color = COL_OUTLINE
	return s


func _stone_sbox(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.26, 0.21, 0.42) if hover else Color(0.18, 0.137, 0.322)
	s.set_border_width_all(3)
	s.border_color = COL_OUTLINE
	s.set_corner_radius_all(2)
	return s


func _nav_sbox(active: bool, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(3)
	s.set_border_width_all(3)
	if active:
		s.bg_color = Color(0.35, 0.29, 0.12)
		s.border_color = COL_GOLD
		s.shadow_color = Color(1.0, 0.82, 0.48, 0.55)
		s.shadow_size = 8
	else:
		s.bg_color = Color(0.26, 0.21, 0.42) if hover else Color(0.18, 0.137, 0.322)
		s.border_color = COL_OUTLINE
	return s


func _gold_sbox() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COL_CTA_A
	s.set_border_width_all(3)
	s.border_color = COL_OUTLINE
	return s


# --- generated textures (circles, rings, gradients) for the CRK deck + screens ---
func _circle_tex(diam: int, color: Color) -> Texture2D:
	var key := "circ_%d_%s" % [diam, color.to_html()]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(diam, diam, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diam - 1) * 0.5
	var r := diam * 0.5
	for y in diam:
		for x in diam:
			var dx := float(x) - c
			var dy := float(y) - c
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _ring_tex(diam: int, thickness: float, color: Color) -> Texture2D:
	var key := "ring_%d_%d_%s" % [diam, int(thickness), color.to_html()]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(diam, diam, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diam - 1) * 0.5
	var r := diam * 0.5
	var r_in := r - thickness
	for y in diam:
		for x in diam:
			var dx := float(x) - c
			var dy := float(y) - c
			var d2 := dx * dx + dy * dy
			if d2 <= r * r and d2 >= r_in * r_in:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _grad_tex(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	return gt


func _grad_rect(pos: Vector2, size: Vector2, top: Color, bottom: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _grad_tex(top, bottom)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# Prettier panel: dark bevel border + drop shadow + vertical gradient sheen + top highlight.
func _deco_panel(pos: Vector2, size: Vector2, top_col: Color, bottom_col: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = bottom_col
	s.set_border_width_all(3)
	s.border_color = COL_OUTLINE
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	p.add_theme_stylebox_override("panel", s)
	var grad := _grad_rect(Vector2(3, 3), Vector2(size.x - 6.0, size.y - 6.0), top_col, bottom_col)
	p.add_child(grad)
	var hi := ColorRect.new()
	hi.color = COL_BEVEL
	hi.position = Vector2(3, 3)
	hi.size = Vector2(size.x - 6.0, 2)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hi)
	return p


func _bar_button(text: String, h: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.86, 0.90, 1.0))
	b.add_theme_color_override("font_color_hover", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_color_pressed", Color(0.80, 0.86, 1.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.29, 0.96)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.46, 0.52, 0.72)
	b.add_theme_stylebox_override("normal", sb)
	var hb: StyleBoxFlat = sb.duplicate()
	hb.bg_color = Color(0.26, 0.30, 0.46, 0.99)
	hb.border_color = Color(0.72, 0.78, 0.98)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	b.size = Vector2(tw + 28.0, h)
	return b


# --- UI-art helpers: load the Franuka UI kit (parchment panels, wooden buttons,
# banners) from asset/ui via curated shortcuts; prefer the 2x variant for crispness.

func _ui_texture(shortcut: String, scale: String = "2x") -> Texture2D:
	var id := AssetRegistry.resolve_id(shortcut)
	var scaled := id.replace("_1x_", "_%s_" % scale)
	if AssetRegistry.has_asset(scaled):
		return AssetRegistry.load_texture(scaled)
	return AssetRegistry.load_texture(id)


func _speed_text() -> String:
	return "%dx  SPEED" % int(SPEED_STEPS[_speed_idx])


func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEED_STEPS.size()
	Engine.time_scale = SPEED_STEPS[_speed_idx]
	if _speed_btn != null and is_instance_valid(_speed_btn):
		_speed_btn.text = _speed_text()


func _toggle_book() -> void:
	if _book == null:
		return
	if _book.visible:
		_book.visible = false
		return
	if _menu_panel != null:
		_menu_panel.visible = false
	_build_book_content()
	_book.visible = true


func _toggle_menu() -> void:
	if _menu_panel == null:
		return
	_menu_panel.visible = not _menu_panel.visible
	if _book != null:
		_book.visible = false


func _hide_menus() -> void:
	if _book != null:
		_book.visible = false
	if _menu_panel != null:
		_menu_panel.visible = false


func _build_menu_panel() -> void:
	_menu_panel = _dropdown_panel(Vector2(14.0, TOP_BAR_H + 6.0), Vector2(196, 92))
	var restart := _bar_button("Restart run", 32.0)
	restart.position = Vector2(10, 10)
	restart.size.x = 176
	restart.pressed.connect(_restart_run)
	_menu_panel.add_child(restart)
	var quit := _bar_button("Quit", 32.0)
	quit.position = Vector2(10, 50)
	quit.size.x = 176
	quit.pressed.connect(func() -> void: get_tree().quit())
	_menu_panel.add_child(quit)
	_menu_panel.visible = false
	_taskbar.add_child(_menu_panel)


func _build_book_content() -> void:
	# RPG book menu: an open Spellbook holding the party roster (icon + name + HP bar).
	for c in _book.get_children():
		c.queue_free()
	var view := _view_size

	var dim := Button.new()   # dim backdrop; click outside the book to close
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0, 0, 0, 0.5)
	dim.add_theme_stylebox_override("normal", dsb)
	dim.add_theme_stylebox_override("hover", dsb)
	dim.add_theme_stylebox_override("pressed", dsb)
	dim.focus_mode = Control.FOCUS_NONE
	dim.pressed.connect(func() -> void: _book.visible = false)
	_book.add_child(dim)

	var bw := minf(760.0, view.x * 0.64)
	var bh := bw * 160.0 / 256.0
	var bx := (view.x - bw) * 0.5
	var by := (view.y - bh) * 0.5 - 8.0

	var book_img := TextureRect.new()
	book_img.texture = _ui_texture("ui.book", "3x")
	book_img.stretch_mode = TextureRect.STRETCH_SCALE
	book_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book_img.position = Vector2(bx, by)
	book_img.size = Vector2(bw, bh)
	book_img.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the book don't close it
	_book.add_child(book_img)

	var title := _hud_label(26, Color(0.74, 0.29, 0.16))
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "PARTY"
	title.position = Vector2(bx, by + bh * 0.07)
	title.size = Vector2(bw, 32)
	_book.add_child(title)

	var allies: Array = []
	for u in _units:
		if u["side"] == "ally":
			allies.append(u)
	var page_x := [bx + bw * 0.11, bx + bw * 0.57]
	var row_y := by + bh * 0.27
	var row_gap := bh * 0.30
	for i in allies.size():
		var col := 0 if i < 2 else 1
		_book_hero_row(allies[i], page_x[col], row_y + float(i % 2) * row_gap, bw * 0.32)

	var close := _bar_button("Close", 34.0)
	close.position = Vector2(view.x * 0.5 - close.size.x * 0.5, by + bh + 4.0)
	close.pressed.connect(func() -> void: _book.visible = false)
	_book.add_child(close)


func _book_hero_row(u: Dictionary, x: float, y: float, w: float) -> void:
	var alive: bool = u["alive"]
	var skill = u["skill"]
	if skill != null:
		var icon := TextureRect.new()
		icon.texture = _skill_icon_texture(str(skill.id), str(skill.effect_type))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(x, y)
		icon.size = Vector2(42, 42)
		icon.modulate = Color.WHITE if alive else Color(0.5, 0.5, 0.5, 0.7)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book.add_child(icon)
	var name_l := _hud_label(17, Color(0.30, 0.18, 0.12) if alive else Color(0.52, 0.22, 0.18))
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.text = str(u["name"]).split(" ")[0] + ("" if alive else "  (down)")
	name_l.position = Vector2(x + 52, y - 2)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(name_l)
	var stats = u["stats"]
	var frac: float = clampf(stats.current_hp / float(u["hp_max"]), 0.0, 1.0) if alive else 0.0
	var bar := _hp_bar_node(frac, w - 52.0, 16.0)
	bar.position = Vector2(x + 52, y + 22)
	_book.add_child(bar)
	var hp_l := _hud_label(12, Color(0.34, 0.22, 0.14))
	hp_l.add_theme_constant_override("outline_size", 0)
	hp_l.text = "%d / %d" % [int(stats.current_hp) if alive else 0, int(u["hp_max"])]
	hp_l.position = Vector2(x + 52, y + 40)
	hp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(hp_l)


func _hp_bar_node(frac: float, w: float, h: float) -> Control:
	var root := Control.new()
	root.size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hp_frame_tex != null:
		var frame := TextureRect.new()
		frame.texture = _hp_frame_tex
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.size = Vector2(w, h)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(frame)
	var inset := 4.0
	var fill := ColorRect.new()
	fill.color = _hp_fill_color(frac, true)
	fill.position = Vector2(inset, inset)
	fill.size = Vector2((w - 2.0 * inset) * frac, h - 2.0 * inset)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	return root


func _dropdown_panel(pos: Vector2, size: Vector2) -> Control:
	var p := _jrpg_window(Rect2(pos, size))
	p.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks from falling through
	return p


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
	if target["side"] == "enemy":
		var reward: int = 6 + _wave * 2       # gold ticks up in the top bar
		GameState.add_currency(reward)
		_float_number(sprite.position + Vector2(0, -FRAME_W * SPRITE_SCALE - 6), "+%d" % reward, COL_GOLD2, false)
		if randf() < 0.3:
			_yarn += 1
		if _run != null:
			_run.add_xp(1)
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
			draw_circle(Vector2.ZERO, SPRITE_SCALE * 11.0, Color(0, 0, 0, 0.15))
			draw_circle(Vector2.ZERO, SPRITE_SCALE * 7.5, Color(0, 0, 0, 0.20))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# hp bar above head
			_draw_hp(u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp(u: Dictionary) -> void:
	var sprite: Sprite2D = u["sprite"]
	var stats = u["stats"]
	var frac: float = clamp(stats.current_hp / float(u["hp_max"]), 0.0, 1.0)
	var w := 84.0
	var h := 15.0
	var top := sprite.position.y - SPRITE_H - 14
	var origin := Vector2(sprite.position.x - w * 0.5, top)
	# ornate slider frame (has its own dark track); colored fill drawn inside it.
	if _hp_frame_tex != null:
		draw_texture_rect(_hp_frame_tex, Rect2(origin, Vector2(w, h)), false)
	else:
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(w + 4, h + 4)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(origin, Vector2(w, h)), Color(0.10, 0.08, 0.09))
	var fill_col := _hp_fill_color(frac, u["side"] == "ally")
	var inset := 4.0
	draw_rect(Rect2(origin + Vector2(inset, inset), Vector2((w - 2.0 * inset) * frac, h - 2.0 * inset)), fill_col)


func _hp_fill_color(frac: float, is_ally: bool) -> Color:
	if frac < 0.34:
		return Color(0.96, 0.74, 0.28)      # low HP -> amber
	return Color(0.40, 0.82, 0.38) if is_ally else Color(0.87, 0.40, 0.36)


# ---------------------------------------------------------------- wave flow

func _check_wave_end(delta: float) -> void:
	var allies_alive := _living("ally").size()
	var enemies_alive := _living("enemy").size()
	if allies_alive == 0:
		_end("lost")
	elif enemies_alive == 0:
		_advance_wave()


func _advance_wave() -> void:
	# Warp to the next stage: survivors march offscreen right, a flash covers the
	# swap, then the party walks in from the left to meet the new wave.
	_phase = "warp"
	# Survivors march offscreen-right (0.6s). The swap frees these sprites at ~0.8s,
	# so the march finishes first — no tween runs on a freed node.
	for u in _living("ally"):
		u["anim"] = "move"
		u["sprite"].flip_h = true
		var march := create_tween()
		march.tween_property(u["sprite"], "position:x", u["sprite"].position.x + 320.0, 0.6) \
			.set_trans(Tween.TRANS_SINE)
	var warp := create_tween()
	_warp_tween = warp
	warp.tween_interval(0.5)
	warp.tween_property(_warp_rect, "modulate:a", 1.0, 0.3)   # flash covers the swap (~0.8s)
	warp.tween_callback(_do_wave_swap)
	warp.tween_property(_warp_rect, "modulate:a", 0.0, 0.4)


func _do_wave_swap() -> void:
	_wave += 1
	GameState.advance_to_wave(_wave)
	_spawn_wave()
	# Drop the party in at the left edge and let _act walk them into range (owns
	# position.x, so no tween fights the approach).
	for u in _living("ally"):
		u["sprite"].position.x = maxf(24.0, float(u["home_x"]) - 150.0)
		u["anim"] = "move"
		u["sprite"].flip_h = true
	_refresh_wave_label()
	if _run != null:
		_run.add_xp(5 + _wave)
	_phase = "fighting"


func _restart_run() -> void:
	_hide_menus()
	GameState.reset_run()
	_wave = 1
	_run = null
	_banner_label.visible = false
	_warp_rect.modulate.a = 0.0
	Engine.time_scale = SPEED_STEPS[_speed_idx]
	_begin_starter_pick()


func _end(result: String) -> void:
	_phase = result
	_post_timer = 3.0
	if _run != null:
		GameState.end_run(result, _wave * 8)
	_banner_label.visible = true
	if result == "won":
		_gems += 5                             # boss chest gems
		_banner_label.text = "VICTORY!"
		_banner_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	else:
		_banner_label.text = "DEFEATED"
		_banner_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))


# ================================================================ nav screens
# Full-screen overlays reached from the top-bar nav. Each dims the battle and
# builds a themed panel with a BACK button. Battle keeps ticking behind.

func _open_screen(id: String) -> void:
	if id == "fight":
		_close_screen()
		return
	_hide_menus()
	_current_screen = id
	for c in _screen_root.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.58)
	dim.position = Vector2(0, TOP_BAR_H)                      # leave the top-bar nav uncovered
	dim.size = Vector2(_view_size.x, _view_size.y - TOP_BAR_H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_root.add_child(dim)
	match id:
		"map": _screen_map()
		"party": _screen_party()
		"hero": _screen_hero()
		"base": _screen_base()
		"summon": _screen_summon()
	_screen_root.visible = true
	_refresh_nav_active()


func _close_screen() -> void:
	_current_screen = ""
	if _screen_root != null:
		_screen_root.visible = false
		for c in _screen_root.get_children():
			c.queue_free()
	_refresh_nav_active()


func _open_hero(u) -> void:
	_hero_focus = u
	_open_screen("hero")


func _screen_header(title: String, x: float, y: float, w: float) -> void:
	var head := _deco_panel(Vector2(x, y), Vector2(w, 52), Color(0.22, 0.16, 0.40), Color(0.13, 0.09, 0.24))
	_screen_root.add_child(head)
	var back := Button.new()
	back.text = "‹ BACK"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 11)
	back.add_theme_color_override("font_color", COL_GOLD2)
	back.add_theme_stylebox_override("normal", _stone_sbox(false))
	back.add_theme_stylebox_override("hover", _stone_sbox(true))
	back.add_theme_stylebox_override("pressed", _stone_sbox(true))
	back.position = Vector2(x + 10, y + 9)
	back.size = Vector2(96, 34)
	back.pressed.connect(_close_screen)
	_screen_root.add_child(back)
	var crest := _icon_rect("crest", 26)
	crest.position = Vector2(x + 120, y + 13)
	_screen_root.add_child(crest)
	var t := _hud_label(16, COL_GOLD2)
	t.text = title
	t.position = Vector2(x + 154, y + 16)
	_screen_root.add_child(t)


func _screen_bounds() -> Rect2:
	var m := 40.0
	return Rect2(m, 92.0, _view_size.x - m * 2.0, _view_size.y - 92.0 - 34.0)


# ---------------------------------------------------------------- WORLD MAP
func _screen_map() -> void:
	var b := _screen_bounds()
	_screen_header("PURRALIA · WORLD MAP", b.position.x, b.position.y, b.size.x)
	var panel := _deco_panel(Vector2(b.position.x, b.position.y + 60.0),
		Vector2(b.size.x, b.size.y - 60.0), Color(0.15, 0.11, 0.28), Color(0.09, 0.06, 0.18))
	_screen_root.add_child(panel)
	var row_y := 18.0
	var row_h := 74.0
	for i in REGION_DATA.size():
		_map_row(panel, REGION_DATA[i], _region_status[i], 18.0, row_y, b.size.x - 36.0, row_h)
		row_y += row_h + 12.0


func _map_row(parent: Control, data: Dictionary, status: String, x: float, y: float, w: float, h: float) -> void:
	var fill_top := Color(0.20, 0.15, 0.36) if status != "locked" else Color(0.13, 0.10, 0.22)
	var row := _deco_panel(Vector2(x, y), Vector2(w, h), fill_top, Color(0.11, 0.08, 0.20))
	parent.add_child(row)
	if status == "locked":
		row.modulate = Color(0.62, 0.60, 0.68)
	var node := TextureRect.new()
	node.texture = _circle_tex(52, Color(0.29, 0.24, 0.49))
	node.position = Vector2(14, (h - 52.0) * 0.5)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(node)
	if status == "current":
		var rr := TextureRect.new()
		rr.texture = _ring_tex(52, 4.0, COL_GOLD)
		rr.position = node.position
		rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rr)
	var num := _hud_label(15, COL_GOLD2 if status == "current" else Color.WHITE)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.text = str(data["n"])
	num.position = Vector2(14, (h - 52.0) * 0.5 + 16.0)
	num.size = Vector2(52, 24)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num)
	var nm := _hud_label(13, Color.WHITE)
	nm.text = str(data["name"])
	nm.position = Vector2(86, 14)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nm)
	var sub := _hud_label(11, COL_LAV)
	sub.add_theme_constant_override("outline_size", 2)
	sub.text = str(data["sub"])
	sub.position = Vector2(86, 40)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sub)
	var tag := _hud_label(9, COL_LAV)
	tag.add_theme_constant_override("outline_size", 3)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.position = Vector2(w - 156.0, (h - 16.0) * 0.5)
	tag.size = Vector2(136, 18)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status == "current":
		tag.text = "CURRENT"
		tag.add_theme_color_override("font_color", COL_HP_A)
	elif status == "enter":
		tag.text = "ENTER ›"
		tag.add_theme_color_override("font_color", COL_GOLD2)
	else:
		tag.text = "LOCKED"
	row.add_child(tag)
	if status != "locked":
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_enter_region.bind(int(data["n"])))
		row.add_child(btn)


func _enter_region(n: int) -> void:
	var idx := n - 1
	if idx < 0 or idx >= _region_status.size():
		return
	if _region_status[idx] == "locked":
		return
	if _region_status[idx] == "current":
		_close_screen()
		return
	for i in _region_status.size():
		if _region_status[i] == "current":
			_region_status[i] = "enter"
	_region_status[idx] = "current"
	_title_label.text = str(REGION_DATA[idx]["name"]).to_upper()
	_close_screen()
	_toast("Marching into " + str(REGION_DATA[idx]["name"]))


# ---------------------------------------------------------------- PARTY
func _screen_party() -> void:
	var b := _screen_bounds()
	_screen_header("PARTY & FORMATION", b.position.x, b.position.y, b.size.x)
	var allies: Array = []
	for u in _units:
		if u["side"] == "ally":
			allies.append(u)
	var strip := _deco_panel(Vector2(b.position.x, b.position.y + 60.0), Vector2(b.size.x, 214.0),
		Color(0.17, 0.32, 0.26), Color(0.10, 0.20, 0.16))
	_screen_root.add_child(strip)
	var labels := ["FRONT", "MIDDLE", "MIDDLE", "REAR"]
	var slot_w := 152.0
	var gap := 28.0
	var total := float(allies.size()) * slot_w + float(max(0, allies.size() - 1)) * gap
	var sx := (b.size.x - total) * 0.5
	for i in allies.size():
		var lbl: String = labels[i] if i < labels.size() else "REAR"
		_formation_slot(strip, allies[i], lbl, sx + float(i) * (slot_w + gap), 18.0, slot_w)
	var res := _deco_panel(Vector2(b.position.x, b.position.y + 288.0),
		Vector2(b.size.x, b.size.y - 288.0), Color(0.15, 0.11, 0.28), Color(0.09, 0.06, 0.18))
	_screen_root.add_child(res)
	var rl := _hud_label(11, COL_GOLD2)
	rl.text = "RESERVE HEROES"
	rl.position = Vector2(18, 12)
	res.add_child(rl)
	var hint := _hud_label(11, COL_LAV)
	hint.add_theme_constant_override("outline_size", 2)
	hint.text = "Recruit more cats through Woven Fates to fill the bench."
	hint.position = Vector2(190, 14)
	res.add_child(hint)
	var cols := 6
	var cw := (res.size.x - 40.0 - float(cols - 1) * 12.0) / float(cols)
	for i in cols:
		_reserve_slot(res, 20.0 + float(i) * (cw + 12.0), 42.0, cw)


func _formation_slot(parent: Control, u: Dictionary, label: String, x: float, y: float, w: float) -> void:
	var lbl := _hud_label(9, Color(0.90, 1.0, 0.95))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = label
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, 14)
	parent.add_child(lbl)
	var tile := _deco_panel(Vector2(x, y + 18.0), Vector2(w, 152.0), Color(0.21, 0.16, 0.40), Color(0.11, 0.08, 0.22))
	parent.add_child(tile)
	var rar := _rarity_of(u)
	tile.modulate = Color.WHITE
	var frames: Array = u["idle_frames"]
	if not frames.is_empty():
		var spr := TextureRect.new()
		spr.texture = frames[0]
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(10, 10)
		spr.size = Vector2(w - 20.0, 108.0)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(spr)
	var stars := _hud_label(9, RARITY_COL.get(rar, COL_GOLD))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.text = _stars(rar)
	stars.position = Vector2(0, 6)
	stars.size = Vector2(w, 14)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(stars)
	var ric := _icon_rect(String(ROLE_ICON.get(_hero_role(u), "star")), 20)
	ric.position = Vector2(w - 28.0, 8.0)
	tile.add_child(ric)
	var nm := _hud_label(9, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text = str(u["name"]).split(" ")[0]
	nm.position = Vector2(0, 126.0)
	nm.size = Vector2(w, 16)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(nm)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_open_hero.bind(u))
	tile.add_child(btn)


func _reserve_slot(parent: Control, x: float, y: float, w: float) -> void:
	var tile := _deco_panel(Vector2(x, y), Vector2(w, 122.0), Color(0.13, 0.11, 0.22), Color(0.08, 0.06, 0.15))
	parent.add_child(tile)
	tile.modulate = Color(0.72, 0.70, 0.78)
	var q := _hud_label(30, COL_LAV)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.text = "?"
	q.position = Vector2(0, 28.0)
	q.size = Vector2(w, 44)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(q)
	var l := _hud_label(8, COL_LAV)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = "RECRUIT"
	l.position = Vector2(0, 98.0)
	l.size = Vector2(w, 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(l)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_nav.bind("summon"))
	tile.add_child(btn)


# ---------------------------------------------------------------- HERO DETAIL
func _screen_hero() -> void:
	var u = _hero_focus
	if u == null:
		for x in _units:
			if x["side"] == "ally":
				u = x
				break
	if u == null:
		_close_screen()
		return
	var b := _screen_bounds()
	_screen_header("HERO", b.position.x, b.position.y, b.size.x)
	var top := b.position.y + 60.0
	var bh := b.size.y - 60.0
	var lw := 340.0
	var left := _deco_panel(Vector2(b.position.x, top), Vector2(lw, bh), Color(0.24, 0.17, 0.44), Color(0.11, 0.07, 0.20))
	_screen_root.add_child(left)
	var rar := _rarity_of(u)
	var frames: Array = u["idle_frames"]
	if not frames.is_empty():
		var spr := TextureRect.new()
		spr.texture = frames[0]
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(50, 28)
		spr.size = Vector2(lw - 100.0, 200.0)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(spr)
	var stars := _hud_label(15, RARITY_COL.get(rar, COL_GOLD))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.text = _stars(rar)
	stars.position = Vector2(0, 236)
	stars.size = Vector2(lw, 22)
	left.add_child(stars)
	var nm := _hud_label(18, COL_GOLD2)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text = str(u["name"]).split(" ")[0]
	nm.position = Vector2(0, 262)
	nm.size = Vector2(lw, 24)
	left.add_child(nm)
	var meta := _hud_label(12, COL_LAV)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.text = "Lv %d · %s" % [_hero_level(u), _hero_role(u).capitalize()]
	meta.position = Vector2(0, 290)
	meta.size = Vector2(lw, 18)
	left.add_child(meta)
	var lvup := Button.new()
	lvup.text = "LEVEL UP"
	lvup.focus_mode = Control.FOCUS_NONE
	lvup.add_theme_font_size_override("font_size", 11)
	lvup.add_theme_color_override("font_color", Color.WHITE)
	lvup.add_theme_stylebox_override("normal", _stone_sbox(false))
	lvup.add_theme_stylebox_override("hover", _stone_sbox(true))
	lvup.add_theme_stylebox_override("pressed", _stone_sbox(true))
	lvup.position = Vector2(24, bh - 52.0)
	lvup.size = Vector2(lw * 0.5 - 34.0, 40)
	lvup.pressed.connect(_hero_level_up)
	left.add_child(lvup)
	var asc := Button.new()
	asc.text = "ASCEND ★"
	asc.focus_mode = Control.FOCUS_NONE
	asc.add_theme_font_size_override("font_size", 11)
	asc.add_theme_color_override("font_color", Color(0.23, 0.12, 0.03))
	asc.add_theme_stylebox_override("normal", _gold_sbox())
	asc.add_theme_stylebox_override("hover", _gold_sbox())
	asc.add_theme_stylebox_override("pressed", _gold_sbox())
	asc.position = Vector2(lw * 0.5 + 10.0, bh - 52.0)
	asc.size = Vector2(lw * 0.5 - 34.0, 40)
	asc.pressed.connect(_hero_ascend)
	left.add_child(asc)

	var rx := b.position.x + lw + 16.0
	var rw := b.size.x - lw - 16.0
	# stats
	var sp := _deco_panel(Vector2(rx, top), Vector2(rw, 176), Color(0.16, 0.12, 0.30), Color(0.10, 0.07, 0.19))
	_screen_root.add_child(sp)
	var sl := _hud_label(11, COL_GOLD2)
	sl.text = "STATS"
	sl.position = Vector2(16, 12)
	sp.add_child(sl)
	var st = u["stats"]
	var keys = CombatEnumsClass.StatKey
	_stat_bar(sp, "HP", int(u["hp_max"]), 1200, Color(0.50, 0.86, 0.40), 16, 42, rw - 32.0)
	_stat_bar(sp, "ATK", int(st.get_stat(keys.ATK)), 120, Color(0.95, 0.58, 0.24), 16, 74, rw - 32.0)
	_stat_bar(sp, "DEF", int(st.get_stat(keys.DEF)), 60, Color(0.37, 0.88, 0.78), 16, 106, rw - 32.0)
	_stat_bar(sp, "SPD", int(u["move_speed"]), 140, Color(0.73, 0.55, 1.0), 16, 138, rw - 32.0)
	# skill card
	var sk = u["skill"]
	var kp := _deco_panel(Vector2(rx, top + 188.0), Vector2(rw, 96), Color(0.16, 0.12, 0.30), Color(0.10, 0.07, 0.19))
	_screen_root.add_child(kp)
	var kico := TextureRect.new()
	kico.texture = _icon(_skill_icon_name(sk))
	kico.position = Vector2(16, 20)
	kico.size = Vector2(56, 56)
	kico.stretch_mode = TextureRect.STRETCH_SCALE
	kico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	kico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kp.add_child(kico)
	var kn := _hud_label(12, COL_TEAL)
	kn.text = _skill_display_name(sk)
	kn.position = Vector2(84, 14)
	kp.add_child(kn)
	var kd := _hud_label(11, Color(0.84, 0.80, 0.94))
	kd.add_theme_constant_override("outline_size", 2)
	kd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kd.text = String(SKILL_DESC.get(str(sk.id), "")) if sk != null else ""
	kd.position = Vector2(84, 38)
	kd.size = Vector2(rw - 100.0, 50)
	kp.add_child(kd)
	# equipment
	var ep := _deco_panel(Vector2(rx, top + 296.0), Vector2(rw, bh - 296.0), Color(0.16, 0.12, 0.30), Color(0.10, 0.07, 0.19))
	_screen_root.add_child(ep)
	var el := _hud_label(11, COL_GOLD2)
	el.text = "EQUIPMENT"
	el.position = Vector2(16, 12)
	ep.add_child(el)
	var cols := EQUIP_SLOTS.size()
	var cw := (rw - 32.0 - float(cols - 1) * 10.0) / float(cols)
	for i in cols:
		_equip_slot(ep, EQUIP_SLOTS[i], 16.0 + float(i) * (cw + 10.0), 40.0, cw)


func _stat_bar(parent: Control, name: String, val: int, maxv: int, col: Color, x: float, y: float, w: float) -> void:
	var nl := _hud_label(9, COL_LAV)
	nl.text = name
	nl.position = Vector2(x, y + 2)
	parent.add_child(nl)
	var bx := x + 46.0
	var bw := w - 46.0 - 60.0
	var bg := Panel.new()
	bg.position = Vector2(bx, y)
	bg.size = Vector2(bw, 16)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _inset_sbox(false))
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2(bx + 3.0, y + 3.0)
	fill.size = Vector2((bw - 6.0) * clampf(float(val) / float(maxv), 0.05, 1.0), 10.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var vl := _hud_label(10, Color.WHITE)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.text = str(val)
	vl.position = Vector2(x + w - 56.0, y + 2)
	vl.size = Vector2(56, 16)
	parent.add_child(vl)


func _equip_slot(parent: Control, data: Dictionary, x: float, y: float, w: float) -> void:
	var rar := str(data["rarity"])
	var tile := _deco_panel(Vector2(x, y), Vector2(w, 96), Color(0.12, 0.09, 0.22), Color(0.08, 0.06, 0.15))
	parent.add_child(tile)
	var ring := Panel.new()
	ring.position = Vector2((w - 50.0) * 0.5, 8)
	ring.size = Vector2(50, 50)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.06, 0.04, 0.12)
	rs.set_border_width_all(3)
	rs.border_color = RARITY_COL.get(rar, COL_LAV)
	ring.add_theme_stylebox_override("panel", rs)
	tile.add_child(ring)
	var ic := _icon_rect(str(data["icon"]), 30)
	ic.position = Vector2((w - 30.0) * 0.5, 18.0)
	tile.add_child(ic)
	var sn := _hud_label(7, COL_LAV)
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sn.text = str(data["slot"]).to_upper()
	sn.position = Vector2(0, 62)
	sn.size = Vector2(w, 12)
	tile.add_child(sn)
	var it := _hud_label(8, Color.WHITE)
	it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	it.add_theme_constant_override("outline_size", 2)
	it.text = str(data["item"])
	it.position = Vector2(2, 78)
	it.size = Vector2(w - 4.0, 14)
	tile.add_child(it)


func _hero_level_up() -> void:
	var u = _hero_focus
	if u == null:
		return
	if GameState.currency < 200:
		_toast("Need 200 gold")
		return
	GameState.add_currency(-200)
	u["level"] = _hero_level(u) + 1
	u["hp_max"] = float(u["hp_max"]) * 1.06
	var st = u["stats"]
	var keys = CombatEnumsClass.StatKey
	st.set_base(keys.ATK, st.get_base(keys.ATK) * 1.05)
	st.set_base(keys.HP, float(u["hp_max"]))
	st.current_hp = minf(st.get_stat(keys.HP), st.current_hp + float(u["hp_max"]) * 0.06)
	_open_screen("hero")
	_toast("%s reached Lv %d" % [str(u["name"]).split(" ")[0], _hero_level(u)])


func _hero_ascend() -> void:
	_toast("Ascension needs duplicate shards — pull in Woven Fates")


# ---------------------------------------------------------------- LOOMSTEAD
func _screen_base() -> void:
	var b := _screen_bounds()
	_screen_header("THE LOOMSTEAD", b.position.x, b.position.y, b.size.x)
	var ground := _deco_panel(Vector2(b.position.x, b.position.y + 60.0), Vector2(b.size.x, b.size.y - 60.0),
		Color(0.17, 0.32, 0.26), Color(0.10, 0.20, 0.16))
	_screen_root.add_child(ground)
	var pad := 22.0
	var gap := 20.0
	var pw := (ground.size.x - pad * 2.0 - gap) * 0.5
	var ph := (ground.size.y - pad * 2.0 - gap) * 0.5
	for i in BUILDING_DATA.size():
		var col := i % 2
		var rrow := i / 2
		_plot(ground, BUILDING_DATA[i], pad + float(col) * (pw + gap), pad + float(rrow) * (ph + gap), pw, ph)


func _plot(parent: Control, data: Dictionary, x: float, y: float, w: float, h: float) -> void:
	var id := str(data["id"])
	var state: String = str(_building_state.get(id, "producing"))
	var tile := _deco_panel(Vector2(x, y), Vector2(w, h), Color(0.20, 0.15, 0.36), Color(0.11, 0.08, 0.22))
	parent.add_child(tile)
	var iconbg := Panel.new()
	iconbg.position = Vector2(16, (h - 84.0) * 0.5)
	iconbg.size = Vector2(84, 84)
	iconbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iconbg.add_theme_stylebox_override("panel", _inset_sbox(false))
	tile.add_child(iconbg)
	var ic := _icon_rect(str(data["icon"]), 52)
	ic.position = Vector2(16.0 + 16.0, (h - 84.0) * 0.5 + 16.0)
	tile.add_child(ic)
	var nm := _hud_label(12, Color.WHITE)
	nm.text = str(data["name"])
	nm.position = Vector2(116, 22)
	tile.add_child(nm)
	var prod := _hud_label(11, COL_TEAL)
	prod.add_theme_constant_override("outline_size", 2)
	prod.text = str(data["prod"])
	prod.position = Vector2(116, 48)
	tile.add_child(prod)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.position = Vector2(116, h - 52.0)
	btn.size = Vector2(150, 38)
	if state == "ready":
		btn.text = "COLLECT"
		btn.add_theme_color_override("font_color", Color(0.23, 0.12, 0.03))
		btn.add_theme_stylebox_override("normal", _gold_sbox())
		btn.add_theme_stylebox_override("hover", _gold_sbox())
		btn.add_theme_stylebox_override("pressed", _gold_sbox())
		btn.pressed.connect(_collect_building.bind(id))
	else:
		btn.text = "PRODUCING…"
		btn.disabled = true
		btn.add_theme_color_override("font_color", COL_LAV)
		btn.add_theme_stylebox_override("normal", _stone_sbox(false))
		btn.add_theme_stylebox_override("disabled", _stone_sbox(false))
	tile.add_child(btn)


func _collect_building(id: String) -> void:
	if str(_building_state.get(id, "")) != "ready":
		return
	var b = null
	for x in BUILDING_DATA:
		if str(x["id"]) == id:
			b = x
			break
	if b == null:
		return
	var res := str(b["res"])
	var amt := int(b["amt"])
	if res == "gold":
		GameState.add_currency(amt)
	elif res == "gems":
		_gems += amt
	else:
		_yarn += amt
	_building_state[id] = "producing"
	_open_screen("base")
	_toast("+%d %s" % [amt, res.to_upper()])


# ---------------------------------------------------------------- WOVEN FATES
func _screen_summon() -> void:
	var b := _screen_bounds()
	_screen_header("WOVEN FATES", b.position.x, b.position.y, b.size.x)
	var banner := _deco_panel(Vector2(b.position.x, b.position.y + 60.0), Vector2(b.size.x, b.size.y - 60.0),
		Color(0.36, 0.24, 0.62), Color(0.14, 0.08, 0.26))
	_screen_root.add_child(banner)
	var t := _hud_label(16, COL_GOLD2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "Threadbound Banner"
	t.position = Vector2(0, 18)
	t.size = Vector2(banner.size.x, 24)
	banner.add_child(t)
	var bsub := _hud_label(12, COL_VIOLET)
	bsub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bsub.text = "✦ 5★ rate up ✦"
	bsub.position = Vector2(0, 46)
	bsub.size = Vector2(banner.size.x, 18)
	banner.add_child(bsub)
	# spindle
	var spin := TextureRect.new()
	spin.texture = _icon("orb")
	spin.size = Vector2(120, 120)
	spin.position = Vector2((banner.size.x - 120.0) * 0.5, 78)
	spin.pivot_offset = Vector2(60, 60)
	spin.stretch_mode = TextureRect.STRETCH_SCALE
	spin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(spin)
	var sp_tw := spin.create_tween().set_loops()
	sp_tw.tween_property(spin, "rotation", TAU, 7.0).as_relative()
	# reveal container (over the spindle area)
	_reveal_box = Control.new()
	_reveal_box.position = Vector2(0, 78)
	_reveal_box.size = Vector2(banner.size.x, 150)
	_reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(_reveal_box)
	# pity bar
	var py := banner.size.y - 150.0
	var pl := _hud_label(9, COL_LAV)
	pl.text = "PITY TO GUARANTEED 5★"
	pl.position = Vector2(banner.size.x * 0.5 - 260.0, py)
	banner.add_child(pl)
	_pity_lbl = _hud_label(9, COL_GOLD2)
	_pity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pity_lbl.text = "%d / %d" % [_pity, PITY_MAX]
	_pity_lbl.position = Vector2(banner.size.x * 0.5 + 60.0, py)
	_pity_lbl.size = Vector2(200, 14)
	banner.add_child(_pity_lbl)
	var pbar := Panel.new()
	pbar.position = Vector2(banner.size.x * 0.5 - 260.0, py + 18.0)
	pbar.size = Vector2(520, 16)
	pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbar.add_theme_stylebox_override("panel", _inset_sbox(false))
	banner.add_child(pbar)
	_pity_fill = ColorRect.new()
	_pity_fill.color = COL_VIOLET
	_pity_fill.position = Vector2(banner.size.x * 0.5 - 257.0, py + 21.0)
	_pity_fill.size = Vector2(514.0 * clampf(float(_pity) / float(PITY_MAX), 0.0, 1.0), 10.0)
	_pity_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(_pity_fill)
	# summon buttons
	var by := banner.size.y - 108.0
	var b1 := _summon_button("SUMMON ×1", "5 gems", banner.size.x * 0.5 - 240.0, by, 220.0, false)
	b1.pressed.connect(_do_summon.bind(1))
	banner.add_child(b1)
	var b10 := _summon_button("SUMMON ×10", "50 gems · guaranteed ≥1 4★", banner.size.x * 0.5 + 20.0, by, 220.0, true)
	b10.pressed.connect(_do_summon.bind(10))
	banner.add_child(b10)
	# rates + note
	var rates := _hud_label(9, COL_LAV)
	rates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates.text = "5★ 1.5%     4★ 8.5%     3★ 30%     2★ 60%"
	rates.position = Vector2(0, banner.size.y - 44.0)
	rates.size = Vector2(banner.size.x, 16)
	banner.add_child(rates)
	var note := _hud_label(9, COL_LAV)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_constant_override("outline_size", 2)
	note.text = "Fates are kind here — hard pity at 90, generous free pulls, every dupe weaves into ascension shards."
	note.position = Vector2(0, banner.size.y - 26.0)
	note.size = Vector2(banner.size.x, 16)
	banner.add_child(note)


func _summon_button(title: String, sub: String, x: float, y: float, w: float, gold: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(x, y)
	b.size = Vector2(w, 60)
	b.add_theme_font_size_override("font_size", 12)
	var fc: Color = Color(0.23, 0.12, 0.03) if gold else COL_GOLD2
	if gold:
		b.add_theme_color_override("font_color", fc)
		b.add_theme_stylebox_override("normal", _gold_sbox())
		b.add_theme_stylebox_override("hover", _gold_sbox())
		b.add_theme_stylebox_override("pressed", _gold_sbox())
	else:
		b.add_theme_color_override("font_color", fc)
		b.add_theme_stylebox_override("normal", _stone_sbox(false))
		b.add_theme_stylebox_override("hover", _stone_sbox(true))
		b.add_theme_stylebox_override("pressed", _stone_sbox(true))
	var tl := _hud_label(11, fc)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.text = title
	tl.position = Vector2(0, 10)
	tl.size = Vector2(w, 16)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tl)
	var sl := _hud_label(8, fc)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.add_theme_constant_override("outline_size", 2)
	sl.text = sub
	sl.position = Vector2(4, 34)
	sl.size = Vector2(w - 8.0, 14)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sl)
	return b


func _do_summon(n: int) -> void:
	if _gacha_busy:
		return
	var cost := 50 if n == 10 else 5
	if _gems < cost:
		_toast("Not enough gems")
		return
	_gems -= cost
	var results: Array = []
	var got4 := false
	for i in n:
		_pity += 1
		var rar := ""
		if _pity >= PITY_MAX:
			rar = "legend"
			_pity = 0
		else:
			rar = _roll_rarity()
			if rar == "legend":
				_pity = 0
		if rar == "legend" or rar == "epic":
			got4 = true
		results.append(_pick_by_rarity(rar))
	if n == 10 and not got4:
		results[9] = _pick_by_rarity("epic")
	if _pity_lbl != null and is_instance_valid(_pity_lbl):
		_pity_lbl.text = "%d / %d" % [_pity, PITY_MAX]
	if _pity_fill != null and is_instance_valid(_pity_fill):
		_pity_fill.size.x = 514.0 * clampf(float(_pity) / float(PITY_MAX), 0.0, 1.0)
	_reveal_pulls(results)


func _roll_rarity() -> String:
	var r := randf() * 100.0
	if r < 1.5:
		return "legend"
	if r < 10.0:
		return "epic"
	if r < 40.0:
		return "rare"
	return "common"


func _pick_by_rarity(rar: String) -> Dictionary:
	var pool: Array = []
	for c in GACHA_POOL:
		if str(c["rarity"]) == rar:
			pool.append(c)
	if pool.is_empty():
		return GACHA_POOL[GACHA_POOL.size() - 1]
	return pool[randi() % pool.size()]


func _reveal_pulls(results: Array) -> void:
	if _reveal_box == null or not is_instance_valid(_reveal_box):
		return
	for c in _reveal_box.get_children():
		c.queue_free()
	var n := results.size()
	var cw := 104.0
	var gap := 12.0
	var total := float(n) * cw + float(n - 1) * gap
	var sx := (_reveal_box.size.x - total) * 0.5
	for i in n:
		_pull_card(results[i], sx + float(i) * (cw + gap), 0.0, cw, float(i) * 0.06)


func _pull_card(data: Dictionary, x: float, y: float, w: float, delay: float) -> void:
	var rar := str(data["rarity"])
	var card := _deco_panel(Vector2(x, y), Vector2(w, 132), Color(0.18, 0.13, 0.32), Color(0.10, 0.07, 0.19))
	_reveal_box.add_child(card)
	var pp := Panel.new()
	pp.position = Vector2(8, 8)
	pp.size = Vector2(w - 16.0, 88)
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.05, 0.14)
	ps.set_border_width_all(3)
	ps.border_color = RARITY_COL.get(rar, COL_LAV)
	pp.add_theme_stylebox_override("panel", ps)
	card.add_child(pp)
	var frames := _resolve_frames("", str(data["shortcut"]))
	if not frames.is_empty():
		var spr := TextureRect.new()
		spr.texture = frames[0]
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(12, 12)
		spr.size = Vector2(w - 40.0, 80)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pp.add_child(spr)
	var stars := _hud_label(9, RARITY_COL.get(rar, COL_LAV))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.text = _stars(rar)
	stars.position = Vector2(0, 100)
	stars.size = Vector2(w, 14)
	card.add_child(stars)
	var nm := _hud_label(8, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text = str(data["name"])
	nm.position = Vector2(0, 116)
	nm.size = Vector2(w, 14)
	card.add_child(nm)
	# pop-in
	card.pivot_offset = Vector2(w * 0.5, 66)
	card.scale = Vector2.ZERO
	var tw := card.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- roguelike run

func _ensure_draft() -> void:
	if _draft == null:
		_draft = DraftViewClass.new()
		add_child(_draft)
		_draft.chosen.connect(_on_draft_chosen)


func _begin_starter_pick() -> void:
	_phase = "levelup"                       # freeze the boot frame; no combat yet
	_picking_starter = true
	_starter_ids_cache = []
	var views: Array = []
	for cid in BASE_STARTER_IDS:
		var row = GameState.get_clan_row(str(cid))
		if row == null:
			continue
		_starter_ids_cache.append(str(cid))
		views.append({
			"title": str(row.get("public_name", cid)),
			"desc": "Start as %s" % str(row.get("role", "")),
			"rarity": "rare",
			"sprite_shortcut": str(row.get("sprite_shortcut", "")),
		})
	_ensure_draft()
	_draft.show_cards(views, _view_size)


func _on_draft_chosen(index: int) -> void:
	if _picking_starter:
		_finish_starter_pick(index)
	else:
		_on_levelup_chosen(index)


func _finish_starter_pick(index: int) -> void:
	if index < 0 or index >= _starter_ids_cache.size():
		return
	var cid: String = str(_starter_ids_cache[index])
	GameState.seed_run_party(cid)
	_run = RunStateClass.new({}, cid)
	_picking_starter = false
	_draft.close()
	_phase = "fighting"
	_spawn_wave()


func _open_draft() -> void:
	_phase = "levelup"
	# A level-up can land right as a wave-swap flash is fading out. Setting
	# time_scale = 0 (below) would freeze that tween, leaving the light-blue
	# _warp_rect stuck full-screen over the draft. The swap itself (_do_wave_swap)
	# has already run by the time this gate fires (_phase was "warp" until then),
	# so the only unfinished step is the cosmetic fade-out — cancel it and clear
	# the flash so the draft is never covered.
	if _warp_tween != null and _warp_tween.is_valid():
		_warp_tween.kill()
	_warp_tween = null
	_warp_rect.modulate.a = 0.0
	Engine.time_scale = 0.0
	_pending_cards = _card_system.draw(_run, _roster_ids, _rng)
	if _pending_cards.is_empty():
		_run.pending_levelups = max(0, _run.pending_levelups - 1)
		Engine.time_scale = SPEED_STEPS[_speed_idx]
		_phase = "fighting"
		return
	var views: Array = []
	for c in _pending_cards:
		views.append({
			"title": c.title,
			"desc": _card_system.describe(c),
			"rarity": c.rarity,
			"sprite_shortcut": _card_sprite(c),
		})
	_ensure_draft()
	_draft.show_cards(views, _view_size)


func _on_levelup_chosen(index: int) -> void:
	AudioDirector.reward(3)   # level-up chime
	if index < 0 or index >= _pending_cards.size():
		return
	_apply_pick(_card_system.resolve(_pending_cards[index], _run))
	_run.pending_levelups = max(0, _run.pending_levelups - 1)
	_draft.close()
	if _run.pending_levelups > 0:
		_open_draft()
	else:
		Engine.time_scale = SPEED_STEPS[_speed_idx]
		_phase = "fighting"


func _card_sprite(card) -> String:
	# recruit -> the recruited clan's sprite; unit-bound -> that ally's sprite;
	# party/passive -> the first party member's sprite as a stand-in.
	var cid: String = ""
	if card.type == "recruit":
		cid = str(card.effect.get("clan_id", ""))
	elif card.unit_key != "":
		cid = card.unit_key
	elif _run != null and _run.party_size() > 0:
		cid = str(_run.party_ids[0])
	var row = GameState.get_clan_row(cid)
	return str(row.get("sprite_shortcut", "")) if row != null else ""


func _apply_pick(res: Dictionary) -> void:
	if str(res.get("kind", "")) == "recruit":
		_apply_recruit(res)
		return
	_run.upgrades.append(res)
	if str(res.get("kind", "")) == "passive":
		_run.passives.append(res)
	_apply_one_upgrade(res, _living("ally"))


func _apply_recruit(res: Dictionary) -> void:
	var clan_id: String = str(res.get("clan_id", ""))
	if clan_id == "":
		return
	if GameState.recruit_member(clan_id):
		_run.add_member(clan_id)   # the recruit spawns next wave via _do_wave_swap


func _apply_one_upgrade(res: Dictionary, allies: Array) -> void:
	match str(res.get("kind", "")):
		"stat", "passive":
			_apply_stat_mod(res, allies)
		"skill":
			_apply_skill_mod(res, allies)


func _apply_stat_mod(res: Dictionary, allies: Array) -> void:
	var stat_key: int = CombatEnumsClass.stat_key_from_string(str(res.get("stat", "atk")))
	if stat_key == -1:
		return
	var mod_type: int = (CombatEnumsClass.ModifierType.PERCENT
		if str(res.get("mod", "percent")) == "percent"
		else CombatEnumsClass.ModifierType.FLAT)
	var value: float = float(res.get("value", 0.1))
	var scope: String = str(res.get("scope", "party"))
	var key: String = str(res.get("unit_key", ""))
	var source: String = "draft" if str(res.get("kind", "")) == "stat" else "passive"
	for u in allies:
		if scope == "unit" and str(u.get("clan_id", "")) != key:
			continue
		u["stats"].add_modifier(StatModifierClass.new(stat_key, mod_type, value, source, 0.0))
		if stat_key == CombatEnumsClass.StatKey.HP:
			u["hp_max"] = maxf(1.0, u["stats"].get_stat(CombatEnumsClass.StatKey.HP))


func _apply_skill_mod(res: Dictionary, allies: Array) -> void:
	var key: String = str(res.get("unit_key", ""))
	var field: String = str(res.get("field", "cooldown"))
	var op: String = str(res.get("op", "mul"))
	var value: float = float(res.get("value", 0.9))
	for u in allies:
		if key != "" and str(u.get("clan_id", "")) != key:
			continue
		var sk = u["skill"]
		if sk == null:
			continue
		match field:
			"cooldown":
				sk.cooldown = maxf(0.5, sk.cooldown * value) if op == "mul" else maxf(0.5, sk.cooldown + value)
			"skill_ratio":
				sk.skill_ratio = sk.skill_ratio * value if op == "mul" else sk.skill_ratio + value
			"max_targets":
				sk.max_targets = int(sk.max_targets + value)


func _scale_enemy(eu: Dictionary, wave: int) -> void:
	if eu["stats"] == null:
		return
	var mult: float = pow(1.12, float(max(0, wave - 1)))
	if mult <= 1.0:
		return
	var pct: float = mult - 1.0
	eu["stats"].add_modifier(StatModifierClass.new(CombatEnumsClass.StatKey.HP, CombatEnumsClass.ModifierType.PERCENT, pct, "wavescale", 0.0))
	eu["stats"].add_modifier(StatModifierClass.new(CombatEnumsClass.StatKey.ATK, CombatEnumsClass.ModifierType.PERCENT, pct, "wavescale", 0.0))
	eu["stats"].current_hp = eu["stats"].get_stat(CombatEnumsClass.StatKey.HP)
	eu["hp_max"] = maxf(1.0, eu["stats"].get_stat(CombatEnumsClass.StatKey.HP))
