extends Node3D

# Constants
const CROSSHAIR_SPEED = 40
const SCREEN_BOUNDS_X = 15
const SCREEN_BOUNDS_Y = 10
const CROSSHAIR2_DISTANCE = 35.0  # Distance between crosshair1 and crosshair2

# References
var crosshair1: Sprite3D
var crosshair2: Sprite3D
var player: CharacterBody3D

# Movement
var input_vector = Vector3()
var crosshair_position = Vector3()

func _ready():
	# Get references
	crosshair1 = $Crosshair
	crosshair2 = $Crosshair2
	
	# Find player in parent
	player = get_parent().get_node("player")
	
	# Initialize position
	if player:
		crosshair_position = player.transform.origin
		crosshair_position.z = 0  # Keep crosshair at consistent Z

func _physics_process(delta: float) -> void:
	# Read inputs
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	
	# Update crosshair position
	crosshair_position.x += input_vector.x * CROSSHAIR_SPEED * delta
	crosshair_position.y += input_vector.y * CROSSHAIR_SPEED * delta
	
	# Clamp to bounds
	crosshair_position.x = clamp(crosshair_position.x, -SCREEN_BOUNDS_X, SCREEN_BOUNDS_X)
	crosshair_position.y = clamp(crosshair_position.y, -SCREEN_BOUNDS_Y, SCREEN_BOUNDS_Y)
	
	# Update visual positions
	transform.origin = crosshair_position
	
	# Update crosshair2 position along the aim direction
	if player:
		update_crosshair2_position()

func update_crosshair2_position():
	# Get player's average gun position for aiming
	var player_pos = player.global_position
	var crosshair1_pos = crosshair1.global_position
	
	# Calculate direction from player to crosshair1
	var aim_direction = (crosshair1_pos - player_pos).normalized()
	
	# Position crosshair2 along the aim direction
	crosshair2.global_position = crosshair1_pos + (aim_direction * CROSSHAIR2_DISTANCE)

func get_world_position() -> Vector3:
	return global_position

func get_crosshair1_position() -> Vector3:
	return crosshair1.global_position
