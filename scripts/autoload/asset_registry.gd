extends Node

signal catalog_ready

const CATALOG_PATH := "res://data/asset_catalog.json"
const SHORTCUTS_PATH := "res://data/asset_shortcuts.json"
const MAP_TILES_PATH := "res://data/maps/tile_names.json"
const DEFAULT_TILESHEET := "map.default_tilesheet"

var entries: Array = []
var by_id: Dictionary = {}
var shortcuts: Dictionary = {}
var map_tiles: Dictionary = {}
var loaded := false


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	entries.clear()
	by_id.clear()
	shortcuts.clear()
	map_tiles.clear()
	loaded = false

	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Asset catalog is missing: %s" % CATALOG_PATH)
		return

	var catalog_text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed_catalog = JSON.parse_string(catalog_text)
	if typeof(parsed_catalog) != TYPE_ARRAY:
		push_error("Asset catalog must be a JSON array: %s" % CATALOG_PATH)
		return

	for raw_entry in parsed_catalog:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		entries.append(raw_entry)
		if raw_entry.has("id"):
			by_id[str(raw_entry["id"])] = raw_entry

	if FileAccess.file_exists(SHORTCUTS_PATH):
		var shortcuts_text := FileAccess.get_file_as_string(SHORTCUTS_PATH)
		var parsed_shortcuts = JSON.parse_string(shortcuts_text)
		if typeof(parsed_shortcuts) == TYPE_DICTIONARY:
			shortcuts = parsed_shortcuts
		else:
			push_warning("Asset shortcuts must be a JSON object: %s" % SHORTCUTS_PATH)

	if FileAccess.file_exists(MAP_TILES_PATH):
		var map_tiles_text := FileAccess.get_file_as_string(MAP_TILES_PATH)
		var parsed_map_tiles = JSON.parse_string(map_tiles_text)
		if typeof(parsed_map_tiles) == TYPE_DICTIONARY:
			map_tiles = parsed_map_tiles
		else:
			push_warning("Map tile names must be a JSON object: %s" % MAP_TILES_PATH)

	loaded = true
	catalog_ready.emit()


func resolve_id(asset_id_or_shortcut: String) -> String:
	return str(shortcuts.get(asset_id_or_shortcut, asset_id_or_shortcut))


func get_entry(asset_id_or_shortcut: String) -> Dictionary:
	var asset_id := resolve_id(asset_id_or_shortcut)
	return by_id.get(asset_id, {})


func has_asset(asset_id_or_shortcut: String) -> bool:
	return not get_entry(asset_id_or_shortcut).is_empty()


func get_asset_path(asset_id_or_shortcut: String) -> String:
	var entry := get_entry(asset_id_or_shortcut)
	return str(entry.get("godot_path", ""))


func load_texture(asset_id_or_shortcut: String) -> Texture2D:
	var path := get_asset_path(asset_id_or_shortcut)
	if path.is_empty():
		push_warning("Missing asset id or shortcut: %s" % asset_id_or_shortcut)
		return null

	if _is_image_file(path):
		return _load_image_texture(path, asset_id_or_shortcut)

	var resource := load(path)
	if resource is Texture2D:
		return resource

	return _load_image_texture(path, asset_id_or_shortcut)


func get_sheet_grid(asset_id_or_shortcut: String) -> Dictionary:
	var entry := get_entry(asset_id_or_shortcut)
	if entry.is_empty():
		push_warning("Missing asset id or shortcut: %s" % asset_id_or_shortcut)
		return {}

	var kind := str(entry.get("kind", ""))
	var width := int(entry.get("width", 0))
	var height := int(entry.get("height", 0))
	var cell_width := 0
	var cell_height := 0
	var columns := 0
	var rows := 0

	if kind == "unit_sprite":
		cell_width = int(entry.get("grid_cell_width", 0))
		cell_height = int(entry.get("grid_cell_height", 0))
		columns = int(entry.get("grid_columns", 0))
		rows = int(entry.get("grid_rows", 0))
	elif kind == "tilesheet" or kind == "fog_of_war":
		cell_width = int(entry.get("tile_width", 0))
		cell_height = int(entry.get("tile_height", 0))
		columns = int(entry.get("tile_columns", 0))
		rows = int(entry.get("tile_rows", 0))

	if cell_width <= 0 or cell_height <= 0:
		var inferred_size := _map_grid_size_for_scale(str(entry.get("scale", "")))
		cell_width = inferred_size
		cell_height = inferred_size

	if cell_width <= 0 or cell_height <= 0 or width <= 0 or height <= 0:
		push_warning("Asset has no usable sheet grid metadata: %s" % asset_id_or_shortcut)
		return {}

	if columns <= 0:
		columns = int(width / cell_width)
	if rows <= 0:
		rows = int(height / cell_height)

	if columns <= 0 or rows <= 0:
		push_warning("Asset sheet grid is empty: %s" % asset_id_or_shortcut)
		return {}

	return {
		"cell_width": cell_width,
		"cell_height": cell_height,
		"columns": columns,
		"rows": rows
	}


func load_texture_region(asset_id_or_shortcut: String, region: Rect2i) -> Texture2D:
	var path := get_asset_path(asset_id_or_shortcut)
	if path.is_empty():
		push_warning("Missing asset id or shortcut: %s" % asset_id_or_shortcut)
		return null

	var image := _load_image(path, asset_id_or_shortcut)
	if image == null:
		return null

	var end_x := region.position.x + region.size.x
	var end_y := region.position.y + region.size.y
	if region.size.x <= 0 or region.size.y <= 0:
		push_warning("Invalid empty texture region for %s: %s" % [asset_id_or_shortcut, region])
		return null
	if region.position.x < 0 or region.position.y < 0 or end_x > image.get_width() or end_y > image.get_height():
		push_warning("Texture region out of bounds for %s: %s in %dx%d" % [
			asset_id_or_shortcut,
			region,
			image.get_width(),
			image.get_height()
		])
		return null

	var cropped := image.get_region(region)
	return ImageTexture.create_from_image(cropped)


func load_grid_cell(asset_id_or_shortcut: String, column: int, row: int) -> Texture2D:
	var grid := get_sheet_grid(asset_id_or_shortcut)
	if grid.is_empty():
		return null

	var columns := int(grid.get("columns", 0))
	var rows := int(grid.get("rows", 0))
	if column < 0 or row < 0 or column >= columns or row >= rows:
		push_warning("Grid cell out of range for %s: column=%d row=%d grid=%dx%d" % [
			asset_id_or_shortcut,
			column,
			row,
			columns,
			rows
		])
		return null

	var cell_width := int(grid.get("cell_width", 0))
	var cell_height := int(grid.get("cell_height", 0))
	var region := Rect2i(column * cell_width, row * cell_height, cell_width, cell_height)
	return load_texture_region(asset_id_or_shortcut, region)


func load_sprite_frame(asset_id_or_shortcut: String, column: int = 0, row: int = 0) -> Texture2D:
	return load_grid_cell(asset_id_or_shortcut, column, row)


func has_map_tile(tile_name: String) -> bool:
	return map_tiles.has(tile_name)


# Resolve a named map tile (from data/maps/tile_names.json) to its [column, row]
# on the tilesheet grid. Returns [] when the name is unknown.
func get_map_tile_coords(tile_name: String) -> Array:
	var value = map_tiles.get(tile_name, null)
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return [int(value[0]), int(value[1])]
	return []


# Load a named map tile as a cropped texture. Names are biome-agnostic, so pass a
# different tilesheet shortcut to retheme (map.desert_tilesheet / map.snow_tilesheet).
func load_map_tile(tile_name: String, tilesheet_shortcut: String = DEFAULT_TILESHEET) -> Texture2D:
	var coords := get_map_tile_coords(tile_name)
	if coords.is_empty():
		push_warning("Unknown map tile name: %s" % tile_name)
		return null
	return load_grid_cell(tilesheet_shortcut, coords[0], coords[1])


func load_map_tile_offset(tile_name: String, offset_column: int = 0, offset_row: int = 0, tilesheet_shortcut: String = DEFAULT_TILESHEET) -> Texture2D:
	var coords := get_map_tile_coords(tile_name)
	if coords.is_empty():
		push_warning("Unknown map tile name: %s" % tile_name)
		return null
	return load_grid_cell(tilesheet_shortcut, coords[0] + offset_column, coords[1] + offset_row)


func load_sprite_frames(asset_id_or_shortcut: String, row: int = 0) -> Array:
	var frames: Array = []
	var grid := get_sheet_grid(asset_id_or_shortcut)
	if grid.is_empty():
		return frames

	var columns := int(grid.get("columns", 0))
	var rows := int(grid.get("rows", 0))
	if row < 0 or row >= rows:
		push_warning("Sprite frame row out of range for %s: row=%d rows=%d" % [
			asset_id_or_shortcut,
			row,
			rows
		])
		return frames

	for column in range(columns):
		var frame := load_grid_cell(asset_id_or_shortcut, column, row)
		if frame != null:
			frames.append(frame)
	return frames


func _is_image_file(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension in ["png", "jpg", "jpeg", "webp", "bmp", "tga"]


func _load_image_texture(path: String, asset_id_or_shortcut: String) -> Texture2D:
	var image := _load_image(path, asset_id_or_shortcut)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _load_image(path: String, asset_id_or_shortcut: String) -> Image:
	var image := Image.new()
	var image_error := image.load(path)
	if image_error == OK:
		return image

	push_warning("Asset is not a Texture2D and could not be loaded as an image: %s (%s)" % [asset_id_or_shortcut, path])
	return null


func _map_grid_size_for_scale(scale: String) -> int:
	match scale:
		"1x":
			return 16
		"2x":
			return 32
		"3x":
			return 48
		_:
			return 0


func find_assets(filters: Dictionary = {}) -> Array:
	var results: Array = []
	for entry in entries:
		var matched := true
		for key in filters.keys():
			if not _entry_matches(entry, str(key), filters[key]):
				matched = false
				break
		if matched:
			results.append(entry)
	return results


func ids_for(filters: Dictionary = {}) -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in find_assets(filters):
		ids.append(str(entry.get("id", "")))
	return ids


func _entry_matches(entry: Dictionary, key: String, expected) -> bool:
	if key == "name_contains":
		var haystack := "%s %s %s" % [
			str(entry.get("id", "")),
			str(entry.get("name", "")),
			str(entry.get("source_path", ""))
		]
		return haystack.to_lower().contains(str(expected).to_lower())

	if key == "tag":
		return _entry_tags(entry).has(str(expected))

	if key == "tags_all":
		for tag in expected:
			if not _entry_tags(entry).has(str(tag)):
				return false
		return true

	if key == "tags_any":
		for tag in expected:
			if _entry_tags(entry).has(str(tag)):
				return true
		return false

	if not entry.has(key):
		return false

	var actual = entry[key]
	if typeof(expected) == TYPE_ARRAY:
		for candidate in expected:
			if str(actual) == str(candidate):
				return true
		return false

	return str(actual) == str(expected)


func _entry_tags(entry: Dictionary) -> PackedStringArray:
	var tags := PackedStringArray()
	for tag in entry.get("tags", []):
		tags.append(str(tag))
	return tags
