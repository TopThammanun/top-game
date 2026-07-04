extends Node

# Boot smoke test: runs headless, verifies AssetRegistry + GameState come up
# with the expected shape, then quits with 0 (pass) or 1 (fail).
# Invoke via: godot --headless res://tests/bootstrap_test.tscn


func _ready() -> void:
	if not GameState.is_ready:
		await GameState.state_ready

	var failures: Array[String] = []

	if not AssetRegistry.loaded:
		failures.append("AssetRegistry.loaded is false")

	if AssetRegistry.entries.size() == 0:
		failures.append("AssetRegistry has 0 entries")

	if GameState.party.size() != 4:
		failures.append("expected 4 party members, got %d" % GameState.party.size())

	for u in GameState.party:
		if u.hp_max <= 0:
			failures.append("party unit %s has hp_max <= 0 (clan lookup broken)" % u.id)
		if u.affinity == "":
			failures.append("party unit %s has empty affinity" % u.id)
		if u.move_asset == "":
			failures.append("party unit %s has empty move_asset" % u.id)

	if GameState.wave_state == null:
		failures.append("GameState.wave_state is null")
	elif GameState.wave_state.enemies.size() < 1:
		failures.append("expected wave-1 to have at least 1 enemy, got 0")
	else:
		for e in GameState.wave_state.enemies:
			if e.hp_max <= 0:
				failures.append("enemy %s has hp_max <= 0" % e.id)
			if e.move_asset == "":
				failures.append("enemy %s has empty move_asset" % e.id)

	if AssetRegistry.load_texture("map.default_tilesheet") == null:
		failures.append("map.default_tilesheet did not resolve to a texture")

	if AssetRegistry.load_texture("unit.player_idle") == null:
		failures.append("unit.player_idle did not resolve to a texture")

	var unit_frame := AssetRegistry.load_sprite_frame("unit.player_idle", 0, 0)
	if unit_frame == null:
		failures.append("unit.player_idle did not crop to a sprite frame")
	elif unit_frame.get_width() != 16 or unit_frame.get_height() != 16:
		failures.append("expected unit.player_idle frame to be 16x16, got %dx%d" % [
			unit_frame.get_width(),
			unit_frame.get_height()
		])

	var unit_frames := AssetRegistry.load_sprite_frames("unit.player_idle", 0)
	if unit_frames.size() != 4:
		failures.append("expected unit.player_idle row 0 to crop into 4 frames, got %d" % unit_frames.size())

	var walk_frames := AssetRegistry.load_sprite_frames("unit.tank_move", 1)
	if walk_frames.size() != 4:
		failures.append("expected unit.tank_move row 1 to crop into 4 walk frames, got %d" % walk_frames.size())

	var map_tile := AssetRegistry.load_grid_cell("map.default_tilesheet", 12, 5)
	if map_tile == null:
		failures.append("map.default_tilesheet did not crop to a map tile")
	elif map_tile.get_width() != 16 or map_tile.get_height() != 16:
		failures.append("expected map.default_tilesheet tile to be 16x16, got %dx%d" % [
			map_tile.get_width(),
			map_tile.get_height()
		])

	if AssetRegistry.load_grid_cell("map.default_tilesheet", 999, 999) != null:
		failures.append("out-of-range map.default_tilesheet grid cell should return null")

	for shortcut in [
		"unit.tank_idle",
		"unit.tank_move",
		"unit.striker_idle",
		"unit.striker_move",
		"unit.support_idle",
		"unit.support_move",
		"unit.healer_idle",
		"unit.healer_move",
		"unit.enemy_grunt_idle",
		"unit.enemy_grunt_move",
		"unit.enemy_brute_idle",
		"unit.enemy_brute_move",
		"unit.enemy_boss_idle",
		"unit.enemy_boss_move",
		"ui.panel_dark",
		"ui.taskbar_panel",
		"ui.title_banner"
	]:
		if not AssetRegistry.has_asset(shortcut):
			failures.append("expected visual shortcut to resolve: %s" % shortcut)

	for tile_name in ["path_light", "house_orange", "market_canopy", "tent_orange", "banner_pink"]:
		if not AssetRegistry.has_map_tile(tile_name):
			failures.append("expected named map tile to exist: %s" % tile_name)
		elif AssetRegistry.load_map_tile(tile_name) == null:
			failures.append("expected named map tile to load: %s" % tile_name)

	if AssetRegistry.load_map_tile_offset("house_orange", 2, 2) == null:
		failures.append("house_orange offset tile should load through AssetRegistry")

	var original_save_path: String = GameState.save_path
	var test_save_path := "user://bootstrap_test_save.json"
	var user_dir := DirAccess.open("user://")
	if user_dir != null and user_dir.file_exists("bootstrap_test_save.json"):
		user_dir.remove("bootstrap_test_save.json")

	GameState.save_path = test_save_path
	GameState.currency = 0
	GameState.best_wave = 1
	GameState.upgrade_level = 0
	GameState.last_afk_unix = int(Time.get_unix_time_from_system()) - 300
	GameState.reset_run()

	if GameState.party.is_empty():
		failures.append("upgrade test requires at least one party unit")
	else:
		var first_unit = GameState.party[0]
		var before_atk: int = first_unit.atk
		var before_hp: int = first_unit.hp_max
		GameState.add_currency(50)
		var upgrade_result := GameState.try_buy_upgrade()
		if not bool(upgrade_result.get("ok", false)):
			failures.append("try_buy_upgrade should succeed with 50 Pawcoins")
		if GameState.upgrade_level != 1:
			failures.append("expected upgrade_level 1 after upgrade, got %d" % GameState.upgrade_level)
		if GameState.currency != 25:
			failures.append("expected currency 25 after 25-cost upgrade, got %d" % GameState.currency)
		if first_unit.atk != before_atk + 1:
			failures.append("expected first unit atk to increase by 1, got %d -> %d" % [before_atk, first_unit.atk])
		if first_unit.hp_max != before_hp + 5:
			failures.append("expected first unit hp_max to increase by 5, got %d -> %d" % [before_hp, first_unit.hp_max])

	var chest_reward := GameState.claim_afk_chest()
	if chest_reward <= 0:
		failures.append("claim_afk_chest should award starter AFK reward, got %d" % chest_reward)

	var snapshot := GameState.snapshot()
	if int(snapshot.get("schema_version", 0)) != 1:
		failures.append("save snapshot schema_version should be 1")
	if not FileAccess.file_exists(test_save_path):
		failures.append("save_game should write %s" % test_save_path)
	else:
		var saved = JSON.parse_string(FileAccess.get_file_as_string(test_save_path))
		if typeof(saved) != TYPE_DICTIONARY:
			failures.append("saved JSON should parse to a dictionary")
		elif int(saved.get("upgrade_level", -1)) != GameState.upgrade_level:
			failures.append("saved upgrade_level should match GameState.upgrade_level")

	var saved_currency: int = GameState.currency
	var saved_best_wave: int = GameState.best_wave
	var saved_upgrade_level: int = GameState.upgrade_level
	var saved_last_afk_unix: int = GameState.last_afk_unix
	GameState.currency = 0
	GameState.best_wave = 1
	GameState.upgrade_level = 0
	GameState.last_afk_unix = 0
	GameState.load_save()
	if GameState.currency != saved_currency:
		failures.append("load_save should restore currency %d, got %d" % [saved_currency, GameState.currency])
	if GameState.best_wave != saved_best_wave:
		failures.append("load_save should restore best_wave %d, got %d" % [saved_best_wave, GameState.best_wave])
	if GameState.upgrade_level != saved_upgrade_level:
		failures.append("load_save should restore upgrade_level %d, got %d" % [saved_upgrade_level, GameState.upgrade_level])
	if GameState.last_afk_unix != saved_last_afk_unix:
		failures.append("load_save should restore last_afk_unix")

	GameState.currency = 0
	GameState.best_wave = 1
	GameState.upgrade_level = 0
	GameState.reset_run()
	GameState.mark_wave_cleared()
	if GameState.wave != 2:
		failures.append("expected duplicate-enemy id check to reach wave 2, got %d" % GameState.wave)
	elif GameState.wave_state != null:
		var seen_enemy_ids: Dictionary = {}
		for enemy in GameState.wave_state.enemies:
			if seen_enemy_ids.has(enemy.id):
				failures.append("wave 2 enemy instance id is duplicated: %s" % enemy.id)
			seen_enemy_ids[enemy.id] = true
	GameState.currency = 0
	GameState.best_wave = 1
	GameState.upgrade_level = 0
	GameState.reset_run()
	for expected_wave in range(1, GameState.MAX_WAVE):
		if GameState.wave != expected_wave:
			failures.append("expected wave %d before clear, got %d" % [expected_wave, GameState.wave])
			break
		GameState.mark_wave_cleared()
	if GameState.wave != GameState.MAX_WAVE:
		failures.append("expected to advance to boss wave %d, got %d" % [GameState.MAX_WAVE, GameState.wave])
	GameState.mark_wave_cleared()
	if GameState.run_status != "won":
		failures.append("clearing wave %d should set run_status won, got %s" % [GameState.MAX_WAVE, GameState.run_status])
	if GameState.best_wave != GameState.MAX_WAVE:
		failures.append("boss clear should set best_wave %d, got %d" % [GameState.MAX_WAVE, GameState.best_wave])
	if GameState.currency <= 0:
		failures.append("wave and boss clears should award currency")

	var map_view = load("res://scenes/maps/emberhearth_map_view.tscn").instantiate()
	add_child(map_view)
	await get_tree().process_frame
	map_view.render(GameState.party, GameState.wave_state.enemies)
	await get_tree().process_frame
	var tile_grid: GridContainer = map_view.find_child("TileGrid", true, false) as GridContainer
	if tile_grid == null:
		failures.append("MapView should contain TileGrid")
	elif tile_grid.get_child_count() != 224:
		failures.append("expected TileGrid to render 224 cells for the 28x8 map, got %d" % tile_grid.get_child_count())
	elif tile_grid.get_theme_constant("h_separation") != 0 or tile_grid.get_theme_constant("v_separation") != 0:
		failures.append("TileGrid h/v separation should be 0 so background blocks are flush")

	var unit_layer: Control = map_view.find_child("UnitLayer", true, false) as Control
	if unit_layer == null:
		failures.append("MapView should contain UnitLayer")
	elif unit_layer.get_child_count() < 1:
		failures.append("UnitLayer should render at least one unit cell")
	else:
		var animated_sprite: TextureRect = unit_layer.find_child("Sprite", true, false) as TextureRect
		if animated_sprite == null:
			failures.append("UnitLayer should render animated Sprite nodes")
		elif not animated_sprite.has_meta("idle_frames") or not animated_sprite.has_meta("move_frames"):
			failures.append("MapView sprites should carry idle_frames and move_frames animation metadata")

	if not GameState.party.is_empty() and GameState.wave_state != null and not GameState.wave_state.enemies.is_empty():
		var hero_id: String = GameState.party[0].id
		var enemy_id: String = GameState.wave_state.enemies[0].id
		map_view.play_attack(hero_id, enemy_id)
		map_view.play_hit(enemy_id, 7)
		map_view.play_heal(hero_id, 5)
		map_view.play_skill_pulse("skill_1")
		map_view.play_boss_warning()
		map_view.play_reward_burst("+10 Pawcoins")
	map_view.queue_free()

	var taskbar = load("res://scenes/ui/taskbar.tscn").instantiate()
	add_child(taskbar)
	await get_tree().process_frame
	taskbar.render()
	if taskbar.find_child("Btn", true, false) == null:
		failures.append("Taskbar should render at least one command button")
	taskbar.play_command_feedback("skill_1", Color(1.0, 0.8, 0.3))
	taskbar.start_cooldown("skill_1", 0.1)
	taskbar.queue_free()

	if user_dir != null and user_dir.file_exists("bootstrap_test_save.json"):
		user_dir.remove("bootstrap_test_save.json")
	GameState.save_path = original_save_path

	if failures.is_empty():
		print("[bootstrap_test] PASS — %d heroes, %d wave-1 enemies, %d catalog entries" % [
			GameState.party.size(),
			GameState.wave_state.enemies.size(),
			AssetRegistry.entries.size()
		])
		get_tree().quit(0)
	else:
		printerr("[bootstrap_test] FAIL — %d assertion(s) failed:" % failures.size())
		for f in failures:
			printerr("  - " + f)
		get_tree().quit(1)
