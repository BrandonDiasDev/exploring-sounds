extends Node2D
## Instrument: Base class for all interactive instruments
##
## Responsibilities:
## - Detect touch input (press, long-press, drag)
## - Manage drag movement (update GridManager position)
## - Emit signals for audio playback
## - Provide haptic feedback
## - Maintain identity (instrument_id) and logical position

class_name Instrument

# ============================================================================
# SIGNALS
# ============================================================================

signal short_press_requested(instrument_id: String)
signal long_press_requested(instrument_id: String)
signal press_released(instrument_id: String)
signal drag_started(instrument_id: String)
signal drag_ended(instrument_id: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

## Unique identifier for this instrument
@export var instrument_id: String = "instrument_default"

## Threshold for long-press detection (seconds)
@export var long_press_threshold: float = 0.4

## Haptic vibration duration (milliseconds)
@export var haptic_duration_short: int = 50
@export var haptic_duration_long: int = 100

## Enable drag functionality
@export var allow_dragging: bool = true

## Debug logging for drag operations
@export var INSTR_DEBUG_LOGS: bool = false

# ============================================================================
# STATE VARIABLES
# ============================================================================

## Current logical position (updated by GridManager)
var logical_x: int = 0
var logical_y: int = 0

## Touch state
var is_pressed: bool = false
var press_start_time: float = 0.0
var is_long_press_fired: bool = false

## Drag state
var is_dragging: bool = false
var drag_pointer_start_world: Vector2 = Vector2.ZERO
var drag_instrument_start_world: Vector2 = Vector2.ZERO

## Reference to GridManager
var grid_manager: GridManager

## Reference to AudioManager (autoload)
var audio_manager: Node

# ============================================================================
# SCENE REFERENCES
# ============================================================================

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Find GridManager
	grid_manager = get_tree().get_first_node_in_group("grid_manager")
	if not grid_manager:
		grid_manager = get_parent().get_node_or_null("../GridManager")
	
	# Find AudioManager (should be autoload)
	audio_manager = get_node_or_null("/root/AudioManager")
	if not audio_manager:
		audio_manager = get_tree().root.get_node_or_null("AudioManager")
	
	# Connect Area2D signals
	if area_2d:
		area_2d.input_event.connect(_on_area_input_event)
	
	print("[Instrument] Ready: id=%s, logical=(%d,%d)" % [instrument_id, logical_x, logical_y])
	if INSTR_DEBUG_LOGS:
		print("[Instrument] DEBUG LOGS ENABLED for %s, grid_manager=%s" % [instrument_id, "FOUND" if grid_manager else "NULL!"])
	else:
		if not grid_manager:
			print("[Instrument] WARNING: grid_manager is NULL for %s" % instrument_id)
	
	if grid_manager and grid_manager.has_method("register_instrument"):
		grid_manager.register_instrument(self)
	else:
		call_deferred("_late_register_with_grid")


func _process(_delta: float) -> void:
	# Check for long-press timeout
	if is_pressed and not is_long_press_fired:
		var elapsed = Time.get_ticks_msec() / 1000.0 - press_start_time
		if elapsed >= long_press_threshold:
			_fire_long_press()


# ============================================================================
# TOUCH INPUT HANDLING
# ============================================================================

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	"""Handle input events from Area2D.input_event (viewport, event, shape_idx)."""
	if INSTR_DEBUG_LOGS:
		print("[Instrument] %s input_event received: %s" % [instrument_id, event.get_class()])
	_handle_input(event)


func _handle_input(event: InputEvent) -> void:
	"""
	Handle mouse/touch input:
	- Press: Start timer
	- Release: Fire short-press or stop long-press
	- Motion (with button pressed): Drag
	"""
	
	if event is InputEventMouseButton:
		if INSTR_DEBUG_LOGS:
			print("[Instrument] %s mouse_button: pressed=%s pos=%s"
				% [instrument_id, event.pressed, event.position])
		if event.pressed:
			_on_press_start(event.position)
		else:
			_on_press_end(event.position)
	
	elif event is InputEventScreenTouch:
		if INSTR_DEBUG_LOGS:
			print("[Instrument] %s screen_touch: pressed=%s pos=%s"
				% [instrument_id, event.pressed, event.position])
		if event.pressed:
			_on_press_start(event.position)
		else:
			_on_press_end(event.position)
	
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_pressed and allow_dragging:
			_on_drag_update(event.position)


func _on_press_start(input_position: Vector2) -> void:
	"""Called when touch/mouse pressed."""
	is_pressed = true
	press_start_time = Time.get_ticks_msec() / 1000.0
	is_long_press_fired = false
	drag_pointer_start_world = _screen_to_world(input_position)
	drag_instrument_start_world = global_position
	
	if INSTR_DEBUG_LOGS:
		print("[Instrument] %s _on_press_start: input_pos=%s, world_pos=%s, logical=(%d,%d)" 
			% [instrument_id, input_position, global_position, logical_x, logical_y])
	
	# Visual feedback: slight scale up
	_set_visual_feedback(true)


func _on_press_end(_position: Vector2) -> void:
	"""Called when touch/mouse released."""
	if INSTR_DEBUG_LOGS:
		print("[Instrument] %s _on_press_end: world_pos=%s, logical=(%d,%d), is_dragging=%s" 
			% [instrument_id, global_position, logical_x, logical_y, is_dragging])
	
	is_pressed = false
	
	# Visual feedback: reset
	_set_visual_feedback(false)
	
	if is_dragging:
		# End drag
		_end_drag()
	elif not is_long_press_fired:
		# Short press fired
		_fire_short_press()
	
	# Emit release signal
	press_released.emit(instrument_id)


func _ensure_grid_manager() -> bool:
	"""Lazily initialize grid_manager if not yet found (handles init order issues)."""
	if grid_manager:
		return true
	
	# Try again to find GridManager
	grid_manager = get_tree().get_first_node_in_group("grid_manager")
	if not grid_manager:
		grid_manager = get_parent().get_node_or_null("../GridManager")
	
	if INSTR_DEBUG_LOGS and not grid_manager:
		print("[Instrument] WARNING: grid_manager still not found for %s on retry" % instrument_id)
	
	return grid_manager != null


func _on_drag_update(input_position: Vector2) -> void:
	"""Called when mouse/touch moves while pressed."""
	if not allow_dragging:
		return
	
	var pointer_world := _screen_to_world(input_position)
	var drag_delta_world := pointer_world - drag_pointer_start_world
	
	# Start drag if offset exceeds threshold
	if not is_dragging and drag_delta_world.length() > 10.0:
		_start_drag()
	
	# Update position during drag
	if is_dragging:
		var new_global_pos = drag_instrument_start_world + drag_delta_world
		global_position = new_global_pos
		
		if INSTR_DEBUG_LOGS:
			print("[Instrument] %s _on_drag_update: drag_delta_world=%s, new_global_pos=%s" 
				% [instrument_id, drag_delta_world, new_global_pos])
		
		# Notify GridManager of new world position.
		if _ensure_grid_manager():
			grid_manager.update_instrument_world_position(instrument_id, global_position)
			if INSTR_DEBUG_LOGS:
				print("[Instrument] %s grid sync ok: world_pos=%s logical=(%d,%d)"
					% [instrument_id, global_position, logical_x, logical_y])
		else:
			push_error("[Instrument] %s grid_manager STILL NULL after retry!" % instrument_id)


func _fire_short_press() -> void:
	"""Fire short-press event."""
	short_press_requested.emit(instrument_id)
	_vibrate(haptic_duration_short)
	
	if audio_manager:
		if audio_manager.has_method("on_instrument_short_press"):
			audio_manager.on_instrument_short_press(instrument_id)


func _fire_long_press() -> void:
	"""Fire long-press event (only once per press)."""
	is_long_press_fired = true
	long_press_requested.emit(instrument_id)
	_vibrate(haptic_duration_long)
	
	if audio_manager:
		if audio_manager.has_method("on_instrument_long_press"):
			audio_manager.on_instrument_long_press(instrument_id)


func _start_drag() -> void:
	"""Begin drag operation."""
	is_dragging = true
	_vibrate(50)
	drag_started.emit(instrument_id)
	
	if INSTR_DEBUG_LOGS:
		print("[Instrument] %s _start_drag: world_pos=%s, logical=(%d,%d)" 
			% [instrument_id, global_position, logical_x, logical_y])
	
	if _ensure_grid_manager():
		grid_manager.update_instrument_world_position(instrument_id, global_position)
		grid_manager.start_dragging_instrument(instrument_id)
	else:
		push_error("[Instrument] %s cannot start drag - grid_manager not found!" % instrument_id)


func _end_drag() -> void:
	"""End drag operation."""
	if INSTR_DEBUG_LOGS:
		print("[Instrument] %s _end_drag: world_pos=%s, logical=(%d,%d)" 
			% [instrument_id, global_position, logical_x, logical_y])
	
	is_dragging = false
	drag_ended.emit(instrument_id)
	
	if _ensure_grid_manager():
		grid_manager.update_instrument_world_position(instrument_id, global_position)
		grid_manager.stop_dragging_instrument()
	else:
		push_error("[Instrument] %s cannot stop drag - grid_manager not found!" % instrument_id)


# ============================================================================
# GRIDMANAGER INTERFACE
# ============================================================================

func set_grid_position(grid_logical_x: int, grid_logical_y: int) -> void:
	"""Called by GridManager when instrument's logical position changes."""
	self.logical_x = grid_logical_x
	self.logical_y = grid_logical_y

func refresh_collision_state() -> void:
	"""Refresh Area2D broad-phase registration to avoid seam ghost collisions."""
	if not area_2d:
		return
	area_2d.set_deferred("monitoring", false)
	area_2d.set_deferred("monitoring", true)


# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _set_visual_feedback(active: bool) -> void:
	"""Apply visual feedback when pressed."""
	if not sprite_2d:
		return
	
	if active:
		# Scale up slightly
		create_tween().tween_property(sprite_2d, "scale", Vector2(1.1, 1.1), 0.1)
		# Emit light/glow effect
		sprite_2d.modulate = Color.WHITE * 1.2
	else:
		# Scale back down
		create_tween().tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), 0.1)
		sprite_2d.modulate = Color.WHITE


# ============================================================================
# HAPTIC FEEDBACK
# ============================================================================

func _vibrate(duration_ms: int) -> void:
	"""Request haptic vibration (if supported)."""
	# Use ClassDB to check for and call the static method dynamically to avoid
	# compile-time errors when the API is not present in the running build/editor.
	if ClassDB.class_exists("Input") and ClassDB.class_has_method("Input", "vibrate_handheld"):
		Input.vibrate_handheld(duration_ms)
		return
	# Otherwise no-op (editor/desktop without haptics)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return screen_pos
	# Godot 4.x: convert viewport/screen coordinates to world canvas coordinates.
	return viewport.get_canvas_transform().affine_inverse() * screen_pos

func _late_register_with_grid() -> void:
	if not _ensure_grid_manager():
		return
	if grid_manager.has_method("register_instrument"):
		grid_manager.register_instrument(self)
