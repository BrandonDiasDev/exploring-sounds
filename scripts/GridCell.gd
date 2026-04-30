extends Node2D
## GridCell: A single cell in the 4x3 grid pool
##
## Responsibilities:
## - Stores logical coordinates (logical_x, logical_y)
## - Detects which instruments are in this cell
## - Updates visual content based on logical position (procedural flora)
## - Handles input detection (tap/drag pass-through to instruments)
## - Manages debug visualization

class_name GridCell

# ============================================================================
# PROPERTIES
# ============================================================================

## Logical coordinates this cell represents
var logical_x: int = 0
var logical_y: int = 0

## Reference to GridManager
var grid_manager: GridManager

## Debug text overlay
var debug_text: String = ""

# Debug font for drawing debug overlay (assign in editor). If unset, debug text won't be drawn.
@export var debug_font: Font
@export var debug_font_size: int = 14

# ============================================================================
# SCENE REFERENCES
# ============================================================================

@onready var color_rect: ColorRect = $ColorRect
@onready var sprite_2d: Sprite2D = $Sprite2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Ensure we have required child nodes
	if not color_rect:
		push_error("[GridCell] Missing ColorRect child")
	if not sprite_2d:
		push_error("[GridCell] Missing Sprite2D child")
	
	# Connect input events
	if color_rect:
		color_rect.mouse_entered.connect(_on_mouse_entered)
		color_rect.mouse_exited.connect(_on_mouse_exited)


# ============================================================================
# CONTENT MANAGEMENT
# ============================================================================

func update_content(logical_x: int, logical_y: int) -> void:
	"""
	Called when this cell is recycled to a new logical position.
	Update visual content (background, procedural decorations, etc.)
	"""
	self.logical_x = logical_x
	self.logical_y = logical_y
	
	# Update background color (optional variation per cell)
	_update_background()
	
	# Clear old decoration children
	for child in get_children():
		if child is not ColorRect and child is not Sprite2D:
			child.queue_free()
	
	# Generate and place procedural content
	_generate_decorations(self.logical_x, self.logical_y)
	
	debug_text = "(%d, %d)" % [logical_x, logical_y]


func _update_background() -> void:
	"""Update cell background color with subtle variation."""
	if not color_rect:
		return
	
	# Deterministic color variation based on logical position
	if grid_manager:
		var content_hash = grid_manager.generate_content_hash(logical_x, logical_y)
		var hue_shift = float(content_hash % 10) / 100.0  # Slight hue variation
		color_rect.color = Color.from_hsv(hue_shift, 0.05, 0.95)  # Light gray with tint
	else:
		color_rect.color = Color.WHITE


func _generate_decorations(lx: int, ly: int) -> void:
	"""
	Procedurally generate decorations (flora, etc.) based on logical coordinates.
	Uses deterministic hash so same (x, y) always generates same content.
	"""
	if not grid_manager:
		return
	
	var content_hash = grid_manager.generate_content_hash(lx, ly)
	
	# Flora probability: 30%
	var flora_probability = 30
	if content_hash % 100 < flora_probability:
		_spawn_flora(lx, ly, content_hash)


func _spawn_flora(lx: int, ly: int, seed_val: int) -> void:
	"""Spawn a simple flora node (for demo purposes)."""
	
	# Simple colored circle to represent flora
	var flora = Node2D.new()
	flora.name = "Flora_%d_%d" % [lx, ly]
	add_child(flora)
	
	# Deterministic position within cell
	var local_x = (seed_val % 400) - 200
	var local_y = int(seed_val / 400) % 400 - 200
	flora.position = Vector2(local_x, local_y)
	
	# Draw a small circle
	flora.modulate = Color.GREEN.lerp(Color.YELLOW, float(seed_val % 50) / 50.0)


func set_debug_text(text: String) -> void:
	"""Set debug overlay text."""
	debug_text = text


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _on_mouse_entered() -> void:
	"""Called when mouse enters cell (for visual feedback)."""
	if color_rect:
		color_rect.modulate = Color.WHITE * 1.1


func _on_mouse_exited() -> void:
	"""Called when mouse exits cell."""
	if color_rect:
		color_rect.modulate = Color.WHITE


func _input(event: InputEvent) -> void:
	"""
	Forward input events to instruments in this cell.
	This allows instruments to handle their own tap/drag logic.
	"""
	
	# Only handle input if it's within this cell
	if not color_rect or not color_rect.get_rect().has_point(get_local_mouse_position()):
		return
	
	# Pass input to all child instruments
	for child in get_children():
		if child is Instrument:
			child._handle_input(event)


# ============================================================================
# VISUALIZATION (DEBUG)
# ============================================================================

func _draw() -> void:
	"""Draw debug overlay if needed."""
	if debug_text:
		# Use an assigned font resource for drawing. Node2D/CanvasItem does not implement
		# Control's theme helper methods like get_theme_font(), so we avoid calling them.
		if debug_font:
			draw_string(debug_font, Vector2(10, 30), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, debug_font_size, Color.BLACK)
		else:
			# No font assigned: skip drawing to avoid errors
			return
