extends Node
## AudioManager: Singleton/Autoload for audio playback
##
## Responsibilities:
## - Register and play instrument audio
## - Handle short-press (one-shot) vs long-press (sustained/looped)
## - Spatial audio (panning, volume)
## - Audio preloading and caching

## Do not register as a global script class to avoid hiding the Autoload singleton
# class_name AudioManager

# ============================================================================
# CONFIGURATION
# ============================================================================

## Fade-out duration when stopping audio (seconds)
@export var fade_out_duration: float = 0.2

# ============================================================================
# STATE
# ============================================================================

## Cache for loaded audio streams
var audio_cache: Dictionary = {}

## Active audio players per instrument
var active_players: Dictionary = {}  # instrument_id → AudioStreamPlayer2D

## Reference to GridManager (for spatial calculations)
var grid_manager: GridManager

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# This script should be set as Autoload in Project Settings → Autoload
	# Ensure it's named "AudioManager" for easy access
	
	# Find GridManager
	grid_manager = get_tree().get_first_node_in_group("grid_manager")
	
	print("[AudioManager] Ready. Cache size: %d" % audio_cache.size())


# ============================================================================
# PUBLIC API
# ============================================================================

func play_instrument(instrument_id: String, params: Dictionary = {}) -> void:
	"""
	Play audio for an instrument.
	
	Args:
		instrument_id: Unique instrument ID
		params: Optional parameters
			- "type": "short" (one-shot) or "long" (loop), default "short"
			- "volume_db": dB adjustment, default 0
	"""
	
	var audio_type = params.get("type", "short")
	var volume_db = params.get("volume_db", 0.0)
	
	# Stop any existing playback for this instrument
	stop_instrument(instrument_id, 0.0)
	
	# Create or reuse audio player
	var player = _get_or_create_player(instrument_id)
	if not player:
		return
	
	# Load audio stream (use mock path; replace with real audio in production)
	var audio_stream = _get_audio_stream(instrument_id)
	if not audio_stream:
		# For demo: create a placeholder
		audio_stream = AudioStreamGenerator.new()
	
	player.stream = audio_stream
	player.volume_db = volume_db
	player.bus = "Master"  # Use "Master" bus or create "Instruments" bus
	
	# Set looping only on stream types that actually support it.
	# Placeholder streams use AudioStreamGenerator, which should be left alone.
	var should_loop = audio_type == "long"
	if audio_stream is AudioStreamWAV:
		(audio_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = should_loop
	elif audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = should_loop
	
	# Start playback
	player.play()
	active_players[instrument_id] = player


func stop_instrument(instrument_id: String, fade_duration: float = -1.0) -> void:
	"""
	Stop audio for an instrument.
	
	Args:
		instrument_id: Unique instrument ID
		fade_duration: Fade-out time in seconds. Use -1 for config default.
	"""
	
	if instrument_id not in active_players:
		return
	
	var player = active_players[instrument_id]
	
	if fade_duration < 0:
		fade_duration = fade_out_duration
	
	if fade_duration > 0:
		# Fade out
		var tween = create_tween()
		tween.tween_property(player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(func(): player.stop())
	else:
		# Stop immediately
		player.stop()
	
	active_players.erase(instrument_id)


func preload_audio(file_paths: Array[String]) -> void:
	"""
	Preload and cache audio files.
	
	Args:
		file_paths: Array of paths to .ogg or .wav files
	"""
	for path in file_paths:
		if ResourceLoader.exists(path):
			var stream = ResourceLoader.load(path)
			audio_cache[path] = stream
			print("[AudioManager] Preloaded: %s" % path)


func set_spatial_position(instrument_id: String, world_position: Vector2) -> void:
	"""
	Update spatial audio position (for panning).
	
	Args:
		instrument_id: Unique instrument ID
		world_position: World position of instrument
	"""
	
	if instrument_id not in active_players:
		return
	
	var player = active_players[instrument_id]
	
	# Calculate panning based on instrument position relative to camera
	if grid_manager and grid_manager.camera_2d:
		var camera_pos = grid_manager.camera_2d.global_position
		var pan = (world_position.x - camera_pos.x) / 512.0  # Normalize to [-1, 1]
		pan = clamp(pan, -1.0, 1.0)
		
		# Apply panning (simple left-right balance)
		player.pan = pan


# ============================================================================
# CALLBACKS FROM INSTRUMENTS
# ============================================================================

func on_instrument_short_press(instrument_id: String) -> void:
	"""Called when instrument detects short-press."""
	var params = {"type": "short"}
	play_instrument(instrument_id, params)


func on_instrument_long_press(instrument_id: String) -> void:
	"""Called when instrument detects long-press."""
	var params = {"type": "long"}
	play_instrument(instrument_id, params)


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _get_or_create_player(instrument_id: String) -> AudioStreamPlayer2D:
	"""Get or create an AudioStreamPlayer2D for an instrument."""
	
	if instrument_id in active_players:
		return active_players[instrument_id]
	
	# Create new player
	var player = AudioStreamPlayer2D.new()
	player.name = "AudioPlayer_%s" % instrument_id
	add_child(player)
	
	active_players[instrument_id] = player
	return player


func _get_audio_stream(instrument_id: String) -> AudioStream:
	"""
	Load audio stream for instrument.
	
	In production, replace this with actual audio file loading.
	This is a placeholder that looks for files named:
	  res://assets/audio/instruments/{instrument_id}.ogg
	"""
	
	# Try cache first
	if instrument_id in audio_cache:
		return audio_cache[instrument_id]
	
	# Try to load from standard location
	var possible_path = "res://assets/audio/instruments/%s.ogg" % instrument_id
	if ResourceLoader.exists(possible_path):
		var stream = ResourceLoader.load(possible_path)
		audio_cache[instrument_id] = stream
		return stream
	
	# Fallback: create silence
	var silent_stream = AudioStreamGenerator.new()
	silent_stream.mix_rate = 22050
	return silent_stream


# ============================================================================
# DEBUG
# ============================================================================

func get_active_instruments() -> Array[String]:
	"""Return list of currently playing instruments."""
	return active_players.keys()
