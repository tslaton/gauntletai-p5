extends CharacterBody3D

# constants
const SHIP_FOLLOW_SPEED = 5.0
const SHIP_ROTATION_SPEED = 8.0
const BULLET_SPEED = -600 # negative: toward player
const BULLET_COOLDOWN = 8 # frames
const MAX_ROTATION_DEGREES = 30  # Maximum tilt angle

# movement variables
var bullet_cooldown = 0

# references
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
	
	# Ship follows crosshair with lag
	var position_diff = crosshair_pos - global_position
	position_diff.z = 0  # Only move in X/Y plane
	
	var follow_velocity = position_diff * SHIP_FOLLOW_SPEED
	
	# Apply velocity and move
	self.velocity.x = follow_velocity.x
	self.velocity.y = follow_velocity.y
	self.velocity.z = 0
	move_and_slide()
	
	# Calculate ship rotation based on position difference
	var target_rotation = Vector3()
	target_rotation.z = clamp(-position_diff.x * 4.0, -MAX_ROTATION_DEGREES, MAX_ROTATION_DEGREES)  # Banking
	target_rotation.x = clamp(position_diff.y * 2.0, -MAX_ROTATION_DEGREES/2, MAX_ROTATION_DEGREES/2)   # Pitch
	target_rotation.y = clamp(-position_diff.x * 1.5, -MAX_ROTATION_DEGREES/2, MAX_ROTATION_DEGREES/2)  # Slight yaw
	
	# Smoothly interpolate rotation
	rotation_degrees = rotation_degrees.lerp(target_rotation, SHIP_ROTATION_SPEED * delta)
	
	# shoot
	if Input.is_action_pressed("ui_accept") and bullet_cooldown <= 0:
		bullet_cooldown = BULLET_COOLDOWN
		shoot_at_crosshair()
	
	# bullet cooldown
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
		
