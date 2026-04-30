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

# ============================================================================
# STATE
# ============================================================================

## Reference to GridManager
var grid_manager: GridManager

## Current camera velocity
var camera_velocity: Vector2 = Vector2.ZERO

## Previous input direction
var prev_input_dir: Vector2 = Vector2.ZERO

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
		if CAMERA_DEBUG_LOGS:
			print("[CameraController] Freeze: dragging active, pos=%s" % global_position)
		return
	
	# Get input
	var input_dir = _get_input_direction()
	
	# Apply smoothing
	input_dir = prev_input_dir.lerp(input_dir, smoothing)
	prev_input_dir = input_dir
	
	# Calculate desired velocity
	var desired_velocity = input_dir * pan_speed
	
	# Smooth velocity change
	camera_velocity = camera_velocity.lerp(desired_velocity, smoothing)
	
	# Update camera position
	global_position += camera_velocity * delta
	
	if debug_mode or CAMERA_DEBUG_LOGS:
		print("[CameraController] pos=%s, vel=%s, dragging=%s" 
			% [global_position, camera_velocity, grid_manager.is_instrument_being_dragged() if grid_manager else false])


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
