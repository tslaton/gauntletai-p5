extends CharacterBody3D

@export var player_id: int = 1
@export var player_number: int = 1  # 1 or 2 for visual ship model

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

# Health system
@export var max_health: int = 200
@export var current_health: int = 200

@export var bullet_damage: int = 10  # Damage dealt by player bullets
signal health_changed(new_health: int, max_health: int)
signal player_died()

# Score system
var score: int = 0
signal score_changed(new_score: int)

# Weapon system
var laser_stage: float = 1.0  # Current laser upgrade level (1-3, can be 0.5 increments in multiplayer)
signal laser_upgraded(new_stage: float)

# Movement variables
var actual_velocity = Vector3()   # Current velocity with momentum
var target_velocity = Vector3()   # Where we want to go
var bullet_cooldown = 0
var current_rotation = Vector3()  # Smooth rotation tracking

# Hit flash variables
var hit_flash_timer: float = 0.0
var mesh_instances: Array[MeshInstance3D] = []
var original_materials: Array[Material] = []
const HIT_FLASH_DURATION: float = 0.1

# Invulnerability system
var invulnerable_timer: float = 0.0
const INVULNERABLE_DURATION: float = 1.0
var is_invulnerable: bool = false

# References
var guns: Array[Node3D]
var gun0: Node3D  # Center gun for stage 1
var main: Node3D
var crosshair_controller: Node3D
var Bullet = load("res://projectiles/bullet.tscn")
var BlueBullet = load("res://projectiles/blue_bullet.tscn")
var LaserImpact = load("res://fx/laser_impact.tscn")
var Explosion = load("res://fx/explosion.tscn")

func _ready():
	# Add player to Player group for enemy targeting
	add_to_group("Player")
	
	# Set collision layers: Player is on layer 2
	collision_layer = 2  # Only on Player layer (bit 2)
	collision_mask = 1 + 16  # Collide with World (bit 1) and EnemyBullet (bit 5)
	
	# Set authority for multiplayer
	if NetworkManager.is_multiplayer_game:
		set_multiplayer_authority(player_id)
	
	
	guns = [$Gun1, $Gun2]
	gun0 = $Gun0  # Center gun
	# Get fresh reference to main scene
	main = get_tree().current_scene
	# Crosshair controller will be set by main.gd for local player only
	
	# Initialize health
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	# Get all mesh instances for hit flash effect
	find_mesh_instances(self)

func _physics_process(delta: float) -> void:
	# Handle hit flash - process on all peers regardless of authority
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0:
			restore_materials()
	
	# Handle invulnerability timer
	if invulnerable_timer > 0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			is_invulnerable = false
			# Restore normal materials when invulnerability ends
			restore_materials()
		else:
			# Flash between red and normal during invulnerability
			var flash_rate = 10.0  # Flashes per second
			var should_flash = fmod(invulnerable_timer * flash_rate, 1.0) > 0.5
			if should_flash:
				flash_hit_without_timer()
			else:
				restore_materials()
	
	# Only process input/physics on the authority peer
	if NetworkManager.is_multiplayer_game and not is_multiplayer_authority():
		return
		
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
	
	# Sync position to other players
	if NetworkManager.is_multiplayer_game and is_multiplayer_authority():
		_sync_position.rpc(global_position, rotation)
	
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
		
	# In multiplayer, calculate shooting parameters and sync
	if NetworkManager.is_multiplayer_game:
		var shoot_data = _calculate_shoot_data()
		if shoot_data:
			_shoot_at_crosshair_synced.rpc(shoot_data.gun_positions, shoot_data.target_pos, shoot_data.damage, shoot_data.bullet_type)
	else:
		_perform_shoot()

func _calculate_shoot_data():
	if not crosshair_controller:
		return null
		
	# Get both crosshair positions
	var crosshair1 = crosshair_controller.get_node_or_null("Crosshair")
	var crosshair2 = crosshair_controller.get_node_or_null("Crosshair2")
	
	if not crosshair1 or not crosshair2:
		return null
	
	var crosshair1_pos = crosshair1.global_position
	var crosshair2_pos = crosshair2.global_position
	
	# Calculate the direction from crosshair1 through crosshair2
	var crosshair_direction = (crosshair2_pos - crosshair1_pos).normalized()
	
	# Find where this direction intersects with z = -100
	var target_z = -100.0
	var distance_to_target_z = (target_z - crosshair1_pos.z) / crosshair_direction.z
	var target_pos = crosshair1_pos + (crosshair_direction * distance_to_target_z)
	
	# Determine which guns to use based on laser_stage
	var guns_to_use: Array[Node3D] = []
	var damage_to_apply: int = 10
	var bullet_type: String = "normal"
	
	# WORKAROUND: Handle fractional laser stages from multiplayer double-pickup
	# 1 or 1.5 = stage 1, 2 or 2.5 = stage 2, 3+ = stage 3
	if laser_stage < 2:  # Stage 1 (includes 1.0 and 1.5)
		guns_to_use = [gun0]
		damage_to_apply = 10
	elif laser_stage < 3:  # Stage 2 (includes 2.0 and 2.5)
		guns_to_use = guns
		damage_to_apply = 20
	else:  # Stage 3 (includes 3.0 and above)
		guns_to_use = guns
		damage_to_apply = 30
		bullet_type = "blue"
	
	var gun_positions = []
	for gun in guns_to_use:
		gun_positions.append(gun.global_position)
	
	return {
		"gun_positions": gun_positions,
		"target_pos": target_pos,
		"damage": damage_to_apply,
		"bullet_type": bullet_type
	}

func _perform_shoot():
	var shoot_data = _calculate_shoot_data()
	if not shoot_data:
		return
	
	var target_pos = shoot_data.target_pos
	var damage_to_apply = shoot_data.damage
	var bullet_scene = BlueBullet if shoot_data.bullet_type == "blue" else Bullet
	
	# Ensure we have a valid main reference
	if not main or not is_instance_valid(main):
		main = get_tree().current_scene
	
	for gun_pos in shoot_data.gun_positions:
		var bullet = bullet_scene.instantiate()
		main.add_child(bullet)
		bullet.global_position = gun_pos
		
		# Store damage value in bullet metadata
		bullet.set_meta("damage", damage_to_apply)
		# Store shooter reference
		bullet.set_meta("shooter", self)
		
		# Calculate direction from gun to the target position
		var direction = (target_pos - gun_pos).normalized()
		
		# Set bullet velocity toward target
		bullet.velocity = direction * abs(BULLET_SPEED)
		
		# Orient bullet to face direction
		if direction.length() > 0:
			bullet.look_at(bullet.global_position + direction, Vector3.UP)
	
@rpc("any_peer", "call_local", "reliable")
func _shoot_at_crosshair_synced(gun_positions: Array, target_pos: Vector3, damage: int, bullet_type: String):
	# Validate that the caller has authority
	if NetworkManager.is_multiplayer_game:
		var sender = multiplayer.get_remote_sender_id()
		if sender != get_multiplayer_authority() and sender != 1:
			return
	
	# Spawn bullets on all peers
	var bullet_scene = BlueBullet if bullet_type == "blue" else Bullet
	
	# Ensure we have a valid main reference
	if not main or not is_instance_valid(main):
		main = get_tree().current_scene
	
	for gun_pos in gun_positions:
		var bullet = bullet_scene.instantiate()
		main.add_child(bullet)
		bullet.global_position = gun_pos
		
		# Store damage value in bullet metadata
		bullet.set_meta("damage", damage)
		# Store shooter reference - find the authoritative player
		var shooter = self
		if NetworkManager.is_multiplayer_game:
			# In multiplayer, find the player that initiated the shot
			for player in get_tree().get_nodes_in_group("Player"):
				if player.get_multiplayer_authority() == get_multiplayer_authority():
					shooter = player
					break
		bullet.set_meta("shooter", shooter)
		
		# Calculate direction from gun to the target position
		var direction = (target_pos - gun_pos).normalized()
		
		# Set bullet velocity toward target
		bullet.velocity = direction * abs(BULLET_SPEED)
		
		# Orient bullet to face direction
		if direction.length() > 0:
			bullet.look_at(bullet.global_position + direction, Vector3.UP)

@rpc("unreliable_ordered")
func _sync_position(new_position: Vector3, new_rotation: Vector3):
	# Only apply position updates from the authoritative player
	if not is_multiplayer_authority():
		global_position = new_position
		rotation = new_rotation

func take_damage(damage: int):
	if NetworkManager.is_multiplayer_game:
		_take_damage_synced.rpc(damage)
	else:
		_apply_damage(damage)

func _apply_damage(damage: int):
	# Check if player is invulnerable
	if is_invulnerable:
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	emit_signal("health_changed", current_health, max_health)
	
	# Start invulnerability period (flashing will be handled in _physics_process)
	is_invulnerable = true
	invulnerable_timer = INVULNERABLE_DURATION
	
	if current_health <= 0:
		die()

@rpc("any_peer", "call_local", "reliable")
func _take_damage_synced(damage: int):
	_apply_damage(damage)

func die():
	if NetworkManager.is_multiplayer_game:
		_die_synced.rpc()
	else:
		_perform_death()

func _perform_death():
	# Create explosion effect
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Hide the player
	visible = false
	set_physics_process(false)
	set_process(false)
	
	# Emit death signal
	emit_signal("player_died")

@rpc("any_peer", "call_local", "reliable")
func _die_synced():
	_perform_death()

func respawn():
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	score = 0
	emit_signal("score_changed", score)
	# Reset position to starting position
	position = Vector3(0, Global.DEFAULT_FLYING_HEIGHT, -11)
	# Make visible and re-enable processing
	visible = true
	set_physics_process(true)
	set_process(true)
	# Reset invulnerability
	is_invulnerable = false
	invulnerable_timer = 0.0

func find_mesh_instances(node: Node):
	if node is MeshInstance3D:
		mesh_instances.append(node)
		# Store original material
		var original_mat = node.get_surface_override_material(0)
		if not original_mat and node.mesh:
			original_mat = node.mesh.surface_get_material(0)
		original_materials.append(original_mat)
	
	for child in node.get_children():
		find_mesh_instances(child)

func flash_hit():
	# Create red flash material
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 0, 0, 1)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 0, 0, 1)
	flash_mat.emission_energy = 2.0
	
	# Apply to all mesh instances
	for i in range(mesh_instances.size()):
		if mesh_instances[i]:
			mesh_instances[i].set_surface_override_material(0, flash_mat)
	
	hit_flash_timer = HIT_FLASH_DURATION

func flash_hit_without_timer():
	# Create red flash material
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 0, 0, 1)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 0, 0, 1)
	flash_mat.emission_energy = 2.0
	
	# Apply to all mesh instances
	for i in range(mesh_instances.size()):
		if mesh_instances[i]:
			mesh_instances[i].set_surface_override_material(0, flash_mat)

func restore_materials():
	# Restore original materials
	for i in range(mesh_instances.size()):
		if i < original_materials.size() and mesh_instances[i]:
			mesh_instances[i].set_surface_override_material(0, original_materials[i])

func collect_pickup(pickup_type: String):
	if NetworkManager.is_multiplayer_game:
		# Apply pickup locally first
		_apply_pickup(pickup_type)
		# Then sync to other clients
		_collect_pickup_synced.rpc(pickup_type)
	else:
		_apply_pickup(pickup_type)

func _apply_pickup(pickup_type: String):
	match pickup_type:
		"health":
			# Heal the player
			var heal_amount = 20
			# WORKAROUND: In multiplayer, pickups are double-applied so we halve the effect
			if NetworkManager.is_multiplayer_game:
				heal_amount = heal_amount / 2
			current_health = min(current_health + heal_amount, max_health)
			emit_signal("health_changed", current_health, max_health)
		"laser":
			# Upgrade laser stage
			if laser_stage < 3:
				# WORKAROUND: In multiplayer, pickups are double-applied so we use 0.5 increments
				if NetworkManager.is_multiplayer_game:
					laser_stage += 0.5
				else:
					laser_stage += 1
				laser_stage = min(laser_stage, 3)  # Ensure we don't go over stage 3
				emit_signal("laser_upgraded", laser_stage)

@rpc("any_peer", "call_remote", "reliable")
func _collect_pickup_synced(pickup_type: String):
	# Only apply pickup for non-calling clients
	_apply_pickup(pickup_type)

func add_score(points: int):
	if NetworkManager.is_multiplayer_game:
		# WORKAROUND: Player 2's kills are double-applied, so player 2 adds half points
		if player_number == 2:
			points = points / 2
		_add_score_synced.rpc(points)
	else:
		_apply_score(points)

func _apply_score(points: int):
	score += points
	emit_signal("score_changed", score)

@rpc("any_peer", "call_local", "reliable")
func _add_score_synced(points: int):
	# Validate that the caller has authority
	if NetworkManager.is_multiplayer_game:
		var sender = multiplayer.get_remote_sender_id()
		if sender != get_multiplayer_authority() and sender != 1:
			return
	_apply_score(points)
