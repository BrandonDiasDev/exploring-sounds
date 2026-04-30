extends Node2D
class_name GridManager

@export var cell_size: Vector2 = Vector2(512.0, 512.0)
@export var debug_mode: bool = false
@export var GRID_DEBUG_LOGS: bool = false

const GRID_SIZE_X: int = 3
const GRID_SIZE_Y: int = 3
const GRID_TOTAL: int = GRID_SIZE_X * GRID_SIZE_Y

var cells: Array[GridCell] = []
var instruments: Dictionary = {} # instrument_id -> {node, logical_x, logical_y, local_offset}
var dragging_instrument_id: String = ""

var world_offset_x: int = 0
var world_offset_y: int = 0
var prev_camera_logical: Vector2i = Vector2i.ZERO
var world_seed: int = 0

var camera_2d: Camera2D
var cells_container: Node2D
var instruments_container: Node2D

func _ready() -> void:
	add_to_group("grid_manager")
	camera_2d = get_node_or_null("../Camera2D")
	if not camera_2d:
		camera_2d = get_tree().get_first_node_in_group("camera")
	cells_container = get_node_or_null("CellsContainer")
	instruments_container = get_node_or_null("InstrumentsContainer")
	world_seed = randi()

	_init_cell_pool()
	_register_scene_instruments()

	if camera_2d:
		prev_camera_logical = get_logical_coords_at_world_position(camera_2d.global_position)
	world_offset_x = prev_camera_logical.x - 1
	world_offset_y = prev_camera_logical.y - 1
	_update_visible_window(true)

func _process(_delta: float) -> void:
	_update_camera_wrapping()
	for idx in range(cells.size()):
		var cell := cells[idx]
		cell.set_pool_index(idx)
		cell.set_debug_overlay_enabled(debug_mode)
		if debug_mode:
			cell.set_debug_text("(%d, %d)" % [cell.logical_x, cell.logical_y])

func _init_cell_pool() -> void:
	if not cells_container:
		push_error("[GridManager] Missing CellsContainer")
		return

	var found_cells: Array[GridCell] = []
	for child in cells_container.get_children():
		if child is GridCell:
			found_cells.append(child)

	found_cells.sort_custom(func(a: GridCell, b: GridCell) -> bool:
		return a.name < b.name
	)

	if found_cells.size() < GRID_TOTAL:
		push_error("[GridManager] Expected at least %d GridCell nodes, found %d" % [GRID_TOTAL, found_cells.size()])
		return

	for idx in range(found_cells.size()):
		if idx < GRID_TOTAL:
			var cell := found_cells[idx]
			cell.grid_manager = self
			cells.append(cell)
		else:
			found_cells[idx].queue_free()

func _register_scene_instruments() -> void:
	if not instruments_container:
		return
	for child in instruments_container.get_children():
		if child is Instrument:
			register_instrument(child as Instrument)

func _update_camera_wrapping() -> void:
	if not camera_2d:
		return
	var cam_logical := get_logical_coords_at_world_position(camera_2d.global_position)
	if cam_logical == prev_camera_logical:
		return

	if GRID_DEBUG_LOGS:
		print("[GridManager] camera logical changed: prev=%s current=%s world_pos=%s"
			% [prev_camera_logical, cam_logical, camera_2d.global_position])

	prev_camera_logical = cam_logical
	world_offset_x = cam_logical.x - 1
	world_offset_y = cam_logical.y - 1
	if GRID_DEBUG_LOGS:
		print("[GridManager] new world_offset=(%d,%d)" % [world_offset_x, world_offset_y])
	_update_visible_window(false)
	if GRID_DEBUG_LOGS:
		_log_grid_snapshot()
		_log_duplicate_logical_cells_if_any()
	_refresh_instrument_collisions()

func _update_visible_window(force_update: bool) -> void:
	for py in range(GRID_SIZE_Y):
		for px in range(GRID_SIZE_X):
			var cell_index := py * GRID_SIZE_X + px
			if cell_index >= cells.size():
				continue
			var cell := cells[cell_index]
			var logical_x := world_offset_x + px
			var logical_y := world_offset_y + py
			var target_world := Vector2(logical_x * cell_size.x, logical_y * cell_size.y)
			var changed := force_update or cell.logical_x != logical_x or cell.logical_y != logical_y
			cell.logical_x = logical_x
			cell.logical_y = logical_y
			cell.global_position = target_world
			if changed:
				cell.update_content(logical_x, logical_y)

func register_instrument(instr_node: Instrument) -> bool:
	if not instr_node:
		return false
	if instr_node.instrument_id in instruments:
		if GRID_DEBUG_LOGS:
			print("[GridManager] register skipped (already exists): %s" % instr_node.instrument_id)
		return true

	var world_pos := instr_node.global_position
	var logical := get_logical_coords_at_world_position(world_pos)
	var local := wrap_local_offset(world_pos - logical_to_world(logical.x, logical.y))

	instruments[instr_node.instrument_id] = {
		"node": instr_node,
		"logical_x": logical.x,
		"logical_y": logical.y,
		"local_offset": local
	}
	instr_node.set_grid_position(logical.x, logical.y)
	if GRID_DEBUG_LOGS:
		print("[GridManager] registered instrument=%s world=%s logical=%s local=%s"
			% [instr_node.instrument_id, world_pos, logical, local])
	return true

func update_instrument_world_position(instrument_id: String, world_pos: Vector2) -> void:
	if instrument_id not in instruments:
		if GRID_DEBUG_LOGS:
			print("[GridManager] update_instrument ignored (not registered): %s" % instrument_id)
		return
	var logical := get_logical_coords_at_world_position(world_pos)
	var local := wrap_local_offset(world_pos - logical_to_world(logical.x, logical.y))
	var data = instruments[instrument_id]
	data["logical_x"] = logical.x
	data["logical_y"] = logical.y
	data["local_offset"] = local
	var instr_node := data["node"] as Instrument
	if instr_node:
		instr_node.set_grid_position(logical.x, logical.y)
	if GRID_DEBUG_LOGS:
		print("[GridManager] update_instrument id=%s world=%s logical=%s local=%s"
			% [instrument_id, world_pos, logical, local])

func get_cell_at_logical(logical_x: int, logical_y: int) -> GridCell:
	var phys_x := wrapi(logical_x - world_offset_x, 0, GRID_SIZE_X)
	var phys_y := wrapi(logical_y - world_offset_y, 0, GRID_SIZE_Y)
	var cell_index := phys_y * GRID_SIZE_X + phys_x
	if cell_index >= 0 and cell_index < cells.size():
		return cells[cell_index]
	return null

func logical_to_world(logical_x: int, logical_y: int) -> Vector2:
	return Vector2(logical_x * cell_size.x, logical_y * cell_size.y)

func wrap_local_offset(local_offset: Vector2) -> Vector2:
	return Vector2(
		wrapf(local_offset.x, 0.0, cell_size.x),
		wrapf(local_offset.y, 0.0, cell_size.y)
	)

func get_logical_coords_at_world_position(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / cell_size.x)),
		int(floor(world_pos.y / cell_size.y))
	)

func start_dragging_instrument(instrument_id: String) -> void:
	dragging_instrument_id = instrument_id

func stop_dragging_instrument() -> void:
	dragging_instrument_id = ""

func is_instrument_being_dragged() -> bool:
	return dragging_instrument_id != ""

func _refresh_instrument_collisions() -> void:
	if GRID_DEBUG_LOGS:
		print("[GridManager] refreshing instrument collisions (%d registered)" % instruments.size())
	for instrument_id in instruments:
		var data = instruments[instrument_id]
		var instr_node := data["node"] as Instrument
		if instr_node:
			instr_node.refresh_collision_state()

func _log_grid_snapshot() -> void:
	var parts: Array[String] = []
	for idx in range(cells.size()):
		var cell := cells[idx]
		var wx := wrapi(cell.logical_x, 0, GRID_SIZE_X)
		var wy := wrapi(cell.logical_y, 0, GRID_SIZE_Y)
		var wrapped_id := (wy * GRID_SIZE_X) + wx
		parts.append("P%d->L(%d,%d)->W%d" % [idx, cell.logical_x, cell.logical_y, wrapped_id])
	print("[GridManager] snapshot %s" % " | ".join(parts))

func _log_duplicate_logical_cells_if_any() -> void:
	var seen: Dictionary = {}
	var duplicates: Array[String] = []
	for idx in range(cells.size()):
		var cell := cells[idx]
		var key := "%d,%d" % [cell.logical_x, cell.logical_y]
		if key in seen:
			duplicates.append("%s(P%d,P%d)" % [key, seen[key], idx])
		else:
			seen[key] = idx
	if duplicates.size() > 0:
		push_warning("[GridManager] duplicate logical cells detected: %s" % ", ".join(duplicates))

func get_world_seed() -> int:
	return world_seed

func generate_content_hash(logical_x: int, logical_y: int) -> int:
	var h := world_seed
	h = ((h << 5) - h) ^ logical_x
	h = ((h << 5) - h) ^ logical_y
	return abs(h)
