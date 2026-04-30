extends Node2D
## GridManager: Orchestrates the 4x3 infinite-grid system (12 cells)
## 
## Responsibilities:
## - Maintains pool of 12 GridCell nodes (4x3, covers viewport + margin)
## - Detects camera movement and recycles cells as needed
## - Tracks instrument positions and reparents on recycle
## - Provides mapping from logical → physical cells
##
## Coordinate systems:
## - LOGICAL: Unbounded integers (camera logical position)
## - PHYSICAL: Fixed 4x3 pool (cells[0..11])
## - VISUAL: World pixels (cell.global_position)

class_name GridManager

# ============================================================================
# CONFIGURATION
# ============================================================================

## Cell size in pixels (e.g., 512x512 or 1024x1024)
@export var cell_size: Vector2 = Vector2(512.0, 512.0)

## Grid dimensions (4x3 pool covers viewport: 1920÷512=3.75≈4 cols, 1080÷512=2.1≈3 rows)
const GRID_SIZE_X: int = 4
const GRID_SIZE_Y: int = 3
const GRID_TOTAL: int = 12

## Debug mode: draw logical coordinates on cells + print recycling
@export var debug_mode: bool = false

## Verbose debug logging for drag/recycle flow
@export var GRID_DEBUG_LOGS: bool = true

# ============================================================================
# STATE VARIABLES
# ============================================================================

## Pool of 12 cell nodes (4x3, never changes in size)
var cells: Array[GridCell] = []

## Instruments registry: instrument_id → {node, logical_x, logical_y, cell_node, local_offset}
var instruments: Dictionary = {}

## Currently dragging instrument (null if not dragging)
var dragging_instrument_id: String = ""

## Logical coordinate of top-left cell in pool
var world_offset_x: int = 0
var world_offset_y: int = 0

## Previous camera logical position (for detecting movement)
var prev_camera_logical_x: int = 0
var prev_camera_logical_y: int = 0

## World seed for procedural content
var world_seed: int = 0

## References to scene nodes
var camera_2d: Camera2D
var cells_container: Node2D
var instruments_container: Node2D

# ============================================================================
# UTILITIES: Reparenting
# ============================================================================

func safe_reparent(node: Node, new_parent: Node) -> void:
	"""Safely reparent a node while preserving its global_position."""
	if not node or not new_parent:
		return
	var saved_global_pos = node.global_position
	if node.get_parent() != new_parent:
		new_parent.add_child(node)
	node.global_position = saved_global_pos
	if GRID_DEBUG_LOGS:
		print("[GridManager] safe_reparent: node=%s, new_parent=%s, preserved_global_pos=%s" 
			% [node.name, new_parent.name, saved_global_pos])

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Register this GridManager in a group for easy access
	add_to_group("grid_manager")
	
	# Find scene node references
	camera_2d = get_node_or_null("../Camera2D")
	if not camera_2d:
		camera_2d = get_tree().get_first_node_in_group("camera")
	
	cells_container = get_node("CellsContainer")
	instruments_container = get_node("InstrumentsContainer")
	
	# Generate world seed (one per session)
	world_seed = randi()
	
	# Initialize 12 cells from pool
	_init_cell_pool()

	# Register instruments already placed in the scene
	_register_scene_instruments()
	
	# Initialize camera logical position
	_update_camera_position()
	
	print("[GridManager] Ready. Grid pool: %dx%d (%d cells), world_seed: %d, cell_size: %s" 
		% [GRID_SIZE_X, GRID_SIZE_Y, cells.size(), world_seed, cell_size])
	if GRID_DEBUG_LOGS:
		print("[GridManager] DEBUG LOGS ENABLED. Tracking drag/recycle flow.")
	if not camera_2d:
		print("[GridManager] WARNING: Camera2D not found! Recycling will not work.")


func _process(delta: float) -> void:
	# Check if camera moved to new logical cell
	_update_camera_position()
	
	# Update dragging instruments (visual follow)
	_update_dragging_instruments(delta)
	
	# Debug visualization
	if debug_mode:
		_draw_debug_info()


# ============================================================================
# CELL POOL INITIALIZATION
# ============================================================================

func _init_cell_pool() -> void:
	"""
	Create 12 GridCell instances (4x3 pool) from cells_container's children.
	Assumes CellsContainer already has 12 GridCell nodes named GridCell_00..GridCell_11
	"""
	cells.clear()
	
	# Collect 12 cell nodes from CellsContainer
	for child in cells_container.get_children():
		if child is GridCell and cells.size() < GRID_TOTAL:
			cells.append(child)
	
	if cells.size() != GRID_TOTAL:
		push_error("[GridManager] Expected %d cells, found %d" % [GRID_TOTAL, cells.size()])
		return
	
	# Position cells in 4x3 grid
	# Initial world_offset = (-2, -1), so cells represent logical [-2,-1] to [1,1]
	world_offset_x = -2
	world_offset_y = -1
	
	for idx in range(GRID_TOTAL):
		var col = idx % GRID_SIZE_X
		var row = idx / GRID_SIZE_X
		
		var logical_x = world_offset_x + col
		var logical_y = world_offset_y + row
		
		var cell = cells[idx]
		cell.grid_manager = self
		cell.logical_x = logical_x
		cell.logical_y = logical_y
		cell.global_position = Vector2(logical_x * cell_size.x, logical_y * cell_size.y)
		cell.update_content(logical_x, logical_y)


func _register_scene_instruments() -> void:
	"""Register instruments that are already placed in InstrumentsContainer."""
	if not instruments_container:
		return

	for child in instruments_container.get_children():
		if child is not Instrument:
			continue

		var instr_node := child as Instrument
		var logical_coords := get_logical_coords_at_world_position(instr_node.global_position)
		add_instrument(instr_node.instrument_id, logical_coords.x, logical_coords.y)


# ============================================================================
# CAMERA TRACKING & RECYCLING
# ============================================================================

func _update_camera_position() -> void:
	"""
	Check if camera moved to a new logical cell.
	If so, trigger recycling.
	"""
	if not camera_2d:
		return
	
	var camera_world_pos = camera_2d.global_position
	
	# Calculate logical cell (always use floor to avoid drift)
	var camera_logical_x = int(floor(camera_world_pos.x / cell_size.x))
	var camera_logical_y = int(floor(camera_world_pos.y / cell_size.y))
	
	# Detect shift
	var dx_cells = camera_logical_x - prev_camera_logical_x
	var dy_cells = camera_logical_y - prev_camera_logical_y
	
	if dx_cells != 0 or dy_cells != 0:
		if GRID_DEBUG_LOGS:
			print("[GridManager] _update_camera_position: camera moved! dx_cells=%d, dy_cells=%d, cam_logical=(%d,%d)" 
				% [dx_cells, dy_cells, camera_logical_x, camera_logical_y])
		_recycle_rows_cols(dx_cells, dy_cells)
		
		if debug_mode:
			print("[GridManager] Recycled: dx=%d, dy=%d, cam_logical=(%d,%d), offset=(%d,%d)" 
				% [dx_cells, dy_cells, camera_logical_x, camera_logical_y, world_offset_x, world_offset_y])
	
	prev_camera_logical_x = camera_logical_x
	prev_camera_logical_y = camera_logical_y


func _recycle_rows_cols(dx_cells: int, dy_cells: int) -> void:
	"""
	Recycle cells as camera moves.
	
	Strategy:
	- For each X shift, recycle one column (left or right edge)
	- For each Y shift, recycle one row (top or bottom edge)
	- Update instruments in recycled cells
	"""
	
	# Handle horizontal recycling
	if dx_cells > 0:
		for i in range(dx_cells):
			_recycle_column_right()
	elif dx_cells < 0:
		for i in range(-dx_cells):
			_recycle_column_left()
	
	# Handle vertical recycling
	if dy_cells > 0:
		for i in range(dy_cells):
			_recycle_row_bottom()
	elif dy_cells < 0:
		for i in range(-dy_cells):
			_recycle_row_top()


func _recycle_column_right() -> void:
	"""Recycle leftmost column to rightmost position."""
	var new_logical_x = world_offset_x + GRID_SIZE_X
	
	if GRID_DEBUG_LOGS:
		print("[GridManager] _recycle_column_right: moving col from x=%d to x=%d" 
			% [world_offset_x, new_logical_x])
	
	for row in range(GRID_SIZE_Y):
		var cell_index = row * GRID_SIZE_X + 0  # Leftmost column
		var cell = cells[cell_index]
		var old_logical_x = cell.logical_x
		var old_logical_y = cell.logical_y
		
		# Update instruments in this cell (preserve global position)
		_reparent_instruments_for_recycle(cell, new_logical_x, world_offset_y + row)
		
		# Update cell logical position
		cell.logical_x = new_logical_x
		cell.logical_y = world_offset_y + row
		
		# Update cell visual position
		cell.global_position = Vector2(new_logical_x * cell_size.x, cell.logical_y * cell_size.y)
		
		if GRID_DEBUG_LOGS:
			print("  → Cell [row %d]: (%d,%d) → (%d,%d), world_pos=%s" 
				% [row, old_logical_x, old_logical_y, cell.logical_x, cell.logical_y, cell.global_position])
		
		# Update content (flora, decoration, etc.)
		cell.update_content(cell.logical_x, cell.logical_y)
	
	world_offset_x += 1
	if debug_mode or GRID_DEBUG_LOGS:
		print("  → Column RIGHT recycled: world_offset now (%d,%d)" % [world_offset_x, world_offset_y])


func _recycle_column_left() -> void:
	"""Recycle rightmost column to leftmost position."""
	var new_logical_x = world_offset_x - 1
	
	if GRID_DEBUG_LOGS:
		print("[GridManager] _recycle_column_left: moving col from x=%d to x=%d" 
			% [world_offset_x + (GRID_SIZE_X - 1), new_logical_x])
	
	for row in range(GRID_SIZE_Y):
		var cell_index = row * GRID_SIZE_X + (GRID_SIZE_X - 1)  # Rightmost column
		var cell = cells[cell_index]
		var old_logical_x = cell.logical_x
		var old_logical_y = cell.logical_y
		
		# Update instruments
		_reparent_instruments_for_recycle(cell, new_logical_x, world_offset_y + row)
		
		# Update cell
		cell.logical_x = new_logical_x
		cell.logical_y = world_offset_y + row
		cell.global_position = Vector2(new_logical_x * cell_size.x, cell.logical_y * cell_size.y)
		
		if GRID_DEBUG_LOGS:
			print("  → Cell [row %d]: (%d,%d) → (%d,%d), world_pos=%s" 
				% [row, old_logical_x, old_logical_y, cell.logical_x, cell.logical_y, cell.global_position])
		
		cell.update_content(cell.logical_x, cell.logical_y)
	
	world_offset_x -= 1
	if debug_mode or GRID_DEBUG_LOGS:
		print("  → Column LEFT recycled: world_offset now (%d,%d)" % [world_offset_x, world_offset_y])


func _recycle_row_bottom() -> void:
	"""Recycle top row to bottom position."""
	var new_logical_y = world_offset_y + GRID_SIZE_Y
	
	if GRID_DEBUG_LOGS:
		print("[GridManager] _recycle_row_bottom: moving row from y=%d to y=%d" 
			% [world_offset_y, new_logical_y])
	
	for col in range(GRID_SIZE_X):
		var cell_index = 0 * GRID_SIZE_X + col  # Top row
		var cell = cells[cell_index]
		var old_logical_x = cell.logical_x
		var old_logical_y = cell.logical_y
		
		# Update instruments
		_reparent_instruments_for_recycle(cell, world_offset_x + col, new_logical_y)
		
		# Update cell
		cell.logical_x = world_offset_x + col
		cell.logical_y = new_logical_y
		cell.global_position = Vector2(cell.logical_x * cell_size.x, new_logical_y * cell_size.y)
		
		if GRID_DEBUG_LOGS:
			print("  → Cell [col %d]: (%d,%d) → (%d,%d), world_pos=%s" 
				% [col, old_logical_x, old_logical_y, cell.logical_x, cell.logical_y, cell.global_position])
		
		cell.update_content(cell.logical_x, cell.logical_y)
	
	world_offset_y += 1
	if debug_mode or GRID_DEBUG_LOGS:
		print("  → Row BOTTOM recycled: world_offset now (%d,%d)" % [world_offset_x, world_offset_y])


func _recycle_row_top() -> void:
	"""Recycle bottom row to top position."""
	var new_logical_y = world_offset_y - 1
	
	if GRID_DEBUG_LOGS:
		print("[GridManager] _recycle_row_top: moving row from y=%d to y=%d" 
			% [world_offset_y + (GRID_SIZE_Y - 1), new_logical_y])
	
	for col in range(GRID_SIZE_X):
		var cell_index = (GRID_SIZE_Y - 1) * GRID_SIZE_X + col  # Bottom row
		var cell = cells[cell_index]
		var old_logical_x = cell.logical_x
		var old_logical_y = cell.logical_y
		
		# Update instruments
		_reparent_instruments_for_recycle(cell, world_offset_x + col, new_logical_y)
		
		# Update cell
		cell.logical_x = world_offset_x + col
		cell.logical_y = new_logical_y
		cell.global_position = Vector2(cell.logical_x * cell_size.x, new_logical_y * cell_size.y)
		
		if GRID_DEBUG_LOGS:
			print("  → Cell [col %d]: (%d,%d) → (%d,%d), world_pos=%s" 
				% [col, old_logical_x, old_logical_y, cell.logical_x, cell.logical_y, cell.global_position])
		
		cell.update_content(cell.logical_x, cell.logical_y)
	
	world_offset_y -= 1
	if debug_mode or GRID_DEBUG_LOGS:
		print("  → Row TOP recycled: world_offset now (%d,%d)" % [world_offset_x, world_offset_y])


func _reparent_instruments_for_recycle(cell: GridCell, new_logical_x: int, new_logical_y: int) -> void:
	"""
	When a cell is recycled, update all instruments in it.
	Preserve global_position to avoid jitter.
	"""
	var instruments_here = _get_instruments_in_cell(cell)
	
	if GRID_DEBUG_LOGS and instruments_here.size() > 0:
		print("[GridManager] _reparent_instruments_for_recycle: cell=%s, new_logical=(%d,%d), num_instruments=%d" 
			% [cell.name, new_logical_x, new_logical_y, instruments_here.size()])
	
	for instr_id in instruments_here:
		if instr_id not in instruments:
			continue
		
		var instr_data = instruments[instr_id]
		var instr_node = instr_data["node"] as Instrument
		
		if not instr_node:
			continue
		
		# CRITICAL: Preserve global position during reparent
		var saved_global_pos = instr_node.global_position
		var old_logical_x = instr_data["logical_x"]
		var old_logical_y = instr_data["logical_y"]
		
		if GRID_DEBUG_LOGS:
			print("  → Reparenting %s: old_logical=(%d,%d), new_logical=(%d,%d), global_pos=%s" 
				% [instr_id, old_logical_x, old_logical_y, new_logical_x, new_logical_y, saved_global_pos])
		
		safe_reparent(instr_node, cell)
		
		# Update instrument's logical position
		instr_data["logical_x"] = new_logical_x
		instr_data["logical_y"] = new_logical_y
		
		# Update local_offset for next time
		instr_data["local_offset"] = instr_node.position
		instr_data["cell_node"] = cell
		
		if GRID_DEBUG_LOGS:
			var restored_global_pos = instr_node.global_position
			print("  → Reparent complete: %s, restored_global_pos=%s (diff: %.2f)" 
				% [instr_id, restored_global_pos, saved_global_pos.distance_to(restored_global_pos)])


# ============================================================================
# INSTRUMENT MANAGEMENT
# ============================================================================

func add_instrument(instrument_id: String, logical_x: int, logical_y: int) -> bool:
	"""Register a new instrument and add it to the correct cell."""
	if instrument_id in instruments:
		push_error("[GridManager] Instrument %s already exists" % instrument_id)
		return false
	
	var cell = get_cell_at_logical(logical_x, logical_y)
	if not cell:
		push_error("[GridManager] No cell at logical (%d, %d)" % [logical_x, logical_y])
		return false
	
	# Find the instrument node by ID (should be in InstrumentsContainer)
	var instr_node: Instrument = null
	for child in instruments_container.get_children():
		if child is Instrument and child.instrument_id == instrument_id:
			instr_node = child
			break
	
	if not instr_node:
		push_error("[GridManager] Instrument node with ID %s not found" % instrument_id)
		return false
	
	# Register in tracking dictionary
	instruments[instrument_id] = {
		"node": instr_node,
		"logical_x": logical_x,
		"logical_y": logical_y,
		"cell_node": cell,
		"local_offset": Vector2.ZERO
	}
	
	# Parent to cell and position
	var saved_global_pos = instr_node.global_position
	if instr_node.get_parent() != cell:
		instr_node.reparent(cell)
	
	instr_node.global_position = saved_global_pos
	
	# Notify instrument
	instr_node.set_grid_position(logical_x, logical_y)
	instruments[instrument_id]["local_offset"] = instr_node.position
	
	return true


func move_instrument(instrument_id: String, new_logical_x: int, new_logical_y: int) -> bool:
	"""Move an instrument to a new logical cell."""
	if instrument_id not in instruments:
		push_error("[GridManager] Instrument %s not found" % instrument_id)
		return false
	
	var instr_data = instruments[instrument_id]
	var instr_node = instr_data["node"] as Instrument
	var old_cell = instr_data["cell_node"] as GridCell
	var old_logical_x = instr_data["logical_x"]
	var old_logical_y = instr_data["logical_y"]
	
	var new_cell = get_cell_at_logical(new_logical_x, new_logical_y)
	if not new_cell:
		push_error("[GridManager] No cell found at logical (%d, %d)" % [new_logical_x, new_logical_y])
		return false
	
	if GRID_DEBUG_LOGS:
		print("[GridManager] move_instrument: %s from logical=(%d,%d) to (%d,%d), world_pos=%s" 
			% [instrument_id, old_logical_x, old_logical_y, new_logical_x, new_logical_y, instr_node.global_position])
	
	# Update logical position
	instr_data["logical_x"] = new_logical_x
	instr_data["logical_y"] = new_logical_y
	
	# Reparent if cell changed
	if new_cell != old_cell:
		if GRID_DEBUG_LOGS:
			print("  → Cell changed: old_cell=%s, new_cell=%s" % [old_cell.name, new_cell.name])
		safe_reparent(instr_node, new_cell)
		instr_data["local_offset"] = instr_node.position
		instr_data["cell_node"] = new_cell
	else:
		if GRID_DEBUG_LOGS:
			print("  → Cell unchanged, updating only logical position")
	
	# Update instrument's awareness
	instr_node.set_grid_position(new_logical_x, new_logical_y)
	
	if GRID_DEBUG_LOGS:
		print("  → move_instrument complete: %s, new world_pos=%s" % [instrument_id, instr_node.global_position])
	
	return true


func get_cell_at_logical(logical_x: int, logical_y: int) -> GridCell:
	"""Map logical coordinates to physical cell node."""
	var phys_x = ((logical_x - world_offset_x) % GRID_SIZE_X + GRID_SIZE_X) % GRID_SIZE_X
	var phys_y = ((logical_y - world_offset_y) % GRID_SIZE_Y + GRID_SIZE_Y) % GRID_SIZE_Y
	
	var cell_index = phys_y * GRID_SIZE_X + phys_x
	if cell_index >= 0 and cell_index < cells.size():
		return cells[cell_index]
	return null

func get_logical_coords_at_world_position(world_pos: Vector2) -> Vector2i:
	"""Convert world position to logical cell coordinates."""
	var logical_x = int(floor(world_pos.x / cell_size.x))
	var logical_y = int(floor(world_pos.y / cell_size.y))
	return Vector2i(logical_x, logical_y)


func start_dragging_instrument(instrument_id: String) -> void:
	"""Called when instrument drag begins."""
	dragging_instrument_id = instrument_id
	if GRID_DEBUG_LOGS or debug_mode:
		print("[GridManager] START dragging: %s" % instrument_id)


func stop_dragging_instrument() -> void:
	"""Called when instrument drag ends."""
	if (GRID_DEBUG_LOGS or debug_mode) and dragging_instrument_id != "":
		print("[GridManager] STOP dragging: %s" % dragging_instrument_id)
	dragging_instrument_id = ""


func is_instrument_being_dragged() -> bool:
	"""Check if any instrument is currently being dragged."""
	return dragging_instrument_id != ""


func _update_dragging_instruments(delta: float) -> void:
	"""Update dragging instruments (check for cell transitions)."""
	if not dragging_instrument_id or dragging_instrument_id not in instruments:
		return
	
	var instr_data = instruments[dragging_instrument_id]
	var instr_node = instr_data["node"] as Instrument
	
	# Check if instrument moved to a different logical cell
	var new_logical = get_logical_coords_at_world_position(instr_node.global_position)
	
	if new_logical.x != instr_data["logical_x"] or new_logical.y != instr_data["logical_y"]:
		move_instrument(dragging_instrument_id, new_logical.x, new_logical.y)


func _get_instruments_in_cell(cell: GridCell) -> Array[String]:
	"""Return list of instrument IDs in a given cell."""
	var result: Array[String] = []
	
	for instr_id in instruments:
		var data = instruments[instr_id]
		if data["cell_node"] == cell:
			result.append(instr_id)
	
	return result


# ============================================================================
# DEBUG & VISUALIZATION
# ============================================================================

func _draw_debug_info() -> void:
	"""Draw debug overlay on cells (if debug_mode enabled)."""
	for cell in cells:
		cell.set_debug_text("(%d, %d)" % [cell.logical_x, cell.logical_y])

# ============================================================================
# UTILITIES: Coordinate Mapping & World Info
# ============================================================================

func get_world_seed() -> int:
	return world_seed


func generate_content_hash(logical_x: int, logical_y: int) -> int:
	"""Deterministic hash for procedural content."""
	var h = world_seed
	h = ((h << 5) - h) ^ logical_x
	h = ((h << 5) - h) ^ logical_y
	return abs(h)
