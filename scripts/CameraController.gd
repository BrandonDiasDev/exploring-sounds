extends Camera2D
## CameraController: Smart camera that scrolls when NOT touching instruments
##
## Behavior:
## - Detect touch/input from mouse
## - If touching an instrument: freeze camera
## - If NOT touching: scroll based on input (arrow keys, WASD, or swipe)
## - Smooth camera movement

class_name CameraController

# ============================================================================
# CONFIGURATION
# ============================================================================

## Camera pan speed (pixels per second)
@export var pan_speed: float = 300.0

## Input smoothing (0-1, higher = smoother)
@export var smoothing: float = 0.1

## Enable debug overlay
@export var debug_mode: bool = false

## Verbose debug logging for camera movement
@export var CAMERA_DEBUG_LOGS: bool = false
@export var allow_mouse_drag_pan: bool = true

# ============================================================================
# STATE
# ============================================================================

## Reference to GridManager
var grid_manager: GridManager

## Current camera velocity
var camera_velocity: Vector2 = Vector2.ZERO

## Previous input direction
var prev_input_dir: Vector2 = Vector2.ZERO
var is_mouse_panning: bool = false
var mouse_pan_delta: Vector2 = Vector2.ZERO

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Find GridManager
	grid_manager = get_tree().get_first_node_in_group("grid_manager")
	
	# Enable smoothing
	enabled = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	# Only move camera if NOT dragging an instrument
	if grid_manager and grid_manager.is_instrument_being_dragged():
		# Freeze camera; apply damping to stop momentum
		camera_velocity = camera_velocity.lerp(Vector2.ZERO, 0.1)
		is_mouse_panning = false
		mouse_pan_delta = Vector2.ZERO
		return
	
	# Get input
	var input_dir = _get_input_direction()
	
	# Apply smoothing
	input_dir = prev_input_dir.lerp(input_dir, smoothing)
	prev_input_dir = input_dir
	
	# Calculate desired velocity (keyboard + mouse pan)
	var desired_velocity = input_dir * pan_speed
	if allow_mouse_drag_pan and is_mouse_panning:
		var zoom_x = max(zoom.x, 0.0001)
		var zoom_y = max(zoom.y, 0.0001)
		var mouse_velocity = Vector2(-mouse_pan_delta.x * zoom_x, -mouse_pan_delta.y * zoom_y) / max(delta, 0.0001)
		desired_velocity += mouse_velocity
		mouse_pan_delta = Vector2.ZERO
	
	# Smooth velocity change
	camera_velocity = camera_velocity.lerp(desired_velocity, smoothing)
	
	# Update camera position
	global_position += camera_velocity * delta
	


# ============================================================================
# INPUT
# ============================================================================

func _get_input_direction() -> Vector2:
	"""
	Detect input direction from:
	- Arrow keys
	- WASD keys
	- Mouse scroll
	"""
	
	var direction = Vector2.ZERO
	
	# Keyboard input
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	
	# WASD alternative
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		direction.x += 1
	
	# Normalize to prevent faster diagonal movement
	if direction.length() > 0:
		direction = direction.normalized()
	
	return direction


func _input(event: InputEvent) -> void:
	"""Handle special input events (debug keys, etc.)."""
	
	# Toggle debug mode
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_F1:
			debug_mode = not debug_mode
			if grid_manager:
				grid_manager.debug_mode = debug_mode
			if CAMERA_DEBUG_LOGS:
				print("[CameraController] F1 debug toggle: camera_debug=%s grid_debug=%s"
					% [debug_mode, grid_manager.debug_mode if grid_manager else false])
	
	if not allow_mouse_drag_pan:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not (grid_manager and grid_manager.is_instrument_being_dragged()):
				is_mouse_panning = true
				mouse_pan_delta = Vector2.ZERO
				if CAMERA_DEBUG_LOGS:
					print("[CameraController] Mouse pan START")
		else:
			if is_mouse_panning and CAMERA_DEBUG_LOGS:
				print("[CameraController] Mouse pan END")
			is_mouse_panning = false
			mouse_pan_delta = Vector2.ZERO
	elif event is InputEventMouseMotion:
		if is_mouse_panning and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_pan_delta += event.relative
