extends Node2D
## GridCell: A single cell in the 3x3 grid pool
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
var debug_overlay_enabled: bool = false
var pool_index: int = -1

# Debug font for drawing debug overlay (assign in editor). If unset, debug text won't be drawn.
@export var debug_font: Font
@export var debug_font_size: int = 14

# ============================================================================
# SCENE REFERENCES
# ============================================================================

@onready var color_rect: ColorRect = $ColorRect
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var debug_label: Label = get_node_or_null("DebugLabel")

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
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not debug_label:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.position = Vector2(12, 8)
		debug_label.z_index = 200
		add_child(debug_label)
	debug_label.visible = false


# ============================================================================
# CONTENT MANAGEMENT
# ============================================================================

func update_content(new_logical_x: int, new_logical_y: int) -> void:
	"""
	Called when this cell is recycled to a new logical position.
	Update visual content (background, procedural decorations, etc.)
	"""
	self.logical_x = new_logical_x
	self.logical_y = new_logical_y
	
	# Update background color (optional variation per cell)
	_update_background()
	
	# Clear old decoration children
	for child in get_children():
		if child is not ColorRect and child is not Sprite2D and child is not Label:
			child.queue_free()
	
	# Generate and place procedural content
	_generate_decorations(self.logical_x, self.logical_y)
	
	debug_text = "(%d, %d)" % [new_logical_x, new_logical_y]
	_update_debug_overlay()


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
	var local_y = int(floor(float(seed_val) / 400.0)) % 400 - 200
	flora.position = Vector2(local_x, local_y)
	
	# Draw a small circle
	flora.modulate = Color.GREEN.lerp(Color.YELLOW, float(seed_val % 50) / 50.0)


func set_debug_text(text: String) -> void:
	"""Set debug overlay text."""
	debug_text = text
	_update_debug_overlay()

func set_pool_index(index: int) -> void:
	pool_index = index
	_update_debug_overlay()

func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
	_update_debug_overlay()


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


# ============================================================================
# VISUALIZATION (DEBUG)
# ============================================================================

func _draw() -> void:
	"""No-op; debug text now uses persistent Label child."""
	return

func _update_debug_overlay() -> void:
	if not debug_label:
		return
	debug_label.visible = debug_overlay_enabled
	if not debug_overlay_enabled:
		return
	var cell_num := pool_index + 1
	var wx := wrapi(logical_x, 0, 3)
	var wy := wrapi(logical_y, 0, 3)
	var wrapped_id := (wy * 3) + wx
	debug_label.text = "P%d | W%d\nL(%d,%d)" % [cell_num, wrapped_id, logical_x, logical_y]
