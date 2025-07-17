extends CharacterBody3D

# Movement constants
const SHIP_ACCELERATION = 4.5      # How quickly ship accelerates
const SHIP_DRAG = 4.0             # Air resistance/drag (balanced)
const SHIP_MAX_SPEED = 15.0       # Maximum velocity
const MOMENTUM_FACTOR = 0.12      # How much momentum affects overshoot

# Rotation constants
const ROTATION_SPEED = 6.0        # Base rotation speed (smoother)
const BANKING_MULTIPLIER = 12.0   # How dramatically ship banks
const PITCH_MULTIPLIER = 5.0      # How much ship pitches based on aim
const YAW_MULTIPLIER = 5.0        # How much ship yaws based on aim
const MAX_BANK_ANGLE = 50         # Maximum banking angle
const MAX_PITCH_ANGLE = 25        # Maximum pitch angle
const MAX_YAW_ANGLE = 25          # Maximum yaw angle

# Combat constants
const BULLET_SPEED = -600         # negative: toward player
const BULLET_COOLDOWN = 8         # frames

# Movement variables
var actual_velocity = Vector3()   # Current velocity with momentum
var target_velocity = Vector3()   # Where we want to go
var bullet_cooldown = 0
var current_rotation = Vector3()  # Smooth rotation tracking

# References
var guns: Array[Node3D]
var main: Node3D
var crosshair_controller: Node3D
var Bullet = load("res://bullet.tscn")

func _ready():
	guns = [$Gun1, $Gun2]
	main = get_tree().current_scene
	# Find crosshair controller in main scene
	crosshair_controller = main.get_node_or_null("CrosshairController")

func _physics_process(delta: float) -> void:
	if not crosshair_controller:
		return
		
	# Get crosshair position
	var crosshair_pos = crosshair_controller.global_position
	crosshair_pos.z = global_position.z  # Ignore Z difference
	
	# Calculate desired velocity toward crosshair
	var position_diff = crosshair_pos - global_position
	position_diff.z = 0  # Only move in X/Y plane
	
	# Set target velocity based on distance to crosshair
	target_velocity = position_diff * SHIP_ACCELERATION
	target_velocity = target_velocity.limit_length(SHIP_MAX_SPEED)
	
	# Apply physics-based acceleration with momentum
	actual_velocity = actual_velocity.lerp(target_velocity, SHIP_DRAG * delta)
	
	# Add slight momentum overshoot when changing directions
	var velocity_change = target_velocity - actual_velocity
	actual_velocity += velocity_change * MOMENTUM_FACTOR * delta
	
	# Apply velocity and move
	self.velocity = actual_velocity
	move_and_slide()
	
	# Get crosshair positions to determine aim direction
	var crosshair1 = crosshair_controller.get_node_or_null("Crosshair")
	var crosshair2 = crosshair_controller.get_node_or_null("Crosshair2")
	
	if crosshair1 and crosshair2:
		# Calculate where the crosshair is relative to ship
		var crosshair_offset = crosshair1.global_position - global_position
		crosshair_offset.z = 0  # Ignore Z for pitch/yaw calculation
		
		# Calculate pitch and yaw based on crosshair offset
		var target_rotation = Vector3()
		
		# Pitch - aim up/down based on crosshair Y offset
		target_rotation.x = clamp(crosshair_offset.y * PITCH_MULTIPLIER, -MAX_PITCH_ANGLE, MAX_PITCH_ANGLE)
		
		# Yaw - aim left/right based on crosshair X offset
		target_rotation.y = clamp(-crosshair_offset.x * YAW_MULTIPLIER, -MAX_YAW_ANGLE, MAX_YAW_ANGLE)
		
		# Banking - tilt based on horizontal velocity
		var banking = clamp(-actual_velocity.x * BANKING_MULTIPLIER / 5.0, -MAX_BANK_ANGLE, MAX_BANK_ANGLE)
		
		# Add extra banking during acceleration
		var accel_factor = (target_velocity - actual_velocity) * 0.3
		banking += clamp(-accel_factor.x, -15, 15)
		
		target_rotation.z = banking
		
		# Smoothly interpolate rotation
		current_rotation = current_rotation.lerp(target_rotation, ROTATION_SPEED * delta)
		rotation_degrees = current_rotation
	
	# Shooting
	if Input.is_action_pressed("ui_accept") and bullet_cooldown <= 0:
		bullet_cooldown = BULLET_COOLDOWN
		shoot_at_crosshair()
	
	# Bullet cooldown
	if bullet_cooldown > 0:
		bullet_cooldown -= 1

func shoot_at_crosshair():
	if not crosshair_controller:
		return
		
	# Get both crosshair positions
	var crosshair1 = crosshair_controller.get_node_or_null("Crosshair")
	var crosshair2 = crosshair_controller.get_node_or_null("Crosshair2")
	
	if not crosshair1 or not crosshair2:
		return
	
	var crosshair1_pos = crosshair1.global_position
	var crosshair2_pos = crosshair2.global_position
	
	# Calculate the direction from crosshair1 through crosshair2
	var crosshair_direction = (crosshair2_pos - crosshair1_pos).normalized()
	
	# Find where this direction intersects with z = -100 (BULLET_RECYCLE_DISTANCE)
	var target_z = -100.0
	var distance_to_target_z = (target_z - crosshair1_pos.z) / crosshair_direction.z
	var target_pos = crosshair1_pos + (crosshair_direction * distance_to_target_z)
	
	for gun in guns:
		var bullet = Bullet.instantiate()
		main.add_child(bullet)
		bullet.global_position = gun.global_position
		
		# Calculate direction from gun to the target position
		var direction = (target_pos - gun.global_position).normalized()
		
		# Set bullet velocity toward target
		bullet.velocity = direction * abs(BULLET_SPEED)
		
		# Orient bullet to face direction
		if direction.length() > 0:
			bullet.look_at(bullet.global_position + direction, Vector3.UP)
		
