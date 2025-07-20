extends CharacterBody3D

# Boss constants
const BOSS_Z_POSITION: float = -80.0
const BOSS_MAX_HEALTH: int = 1000
const STRAFE_SPEED: float = 15.0
const STRAFE_RANGE: float = 30.0  # How far left/right boss can move

# Movement and combat properties
@export var damage: int = 10  # Damage this boss's bullets deal
@export var shoot_cooldown: float = 3.0  # Time between bursts
@export var bullet_speed: float = 150.0  # Speed of boss bullets
@export var burst_count: int = 3  # Number of bullets per burst
@export var burst_delay: float = 0.15  # Delay between bullets in burst

# Boss specific properties
var current_health: int = BOSS_MAX_HEALTH
var max_health: int = BOSS_MAX_HEALTH
var strafe_direction: float = 1.0  # 1.0 for right, -1.0 for left
var initial_x_position: float = 0.0

# Combat variables
var Explosion = preload("res://fx/explosion.tscn")
var EnemyBullet = preload("res://projectiles/enemy_bullet.tscn")
var LaserImpact = preload("res://fx/laser_impact.tscn")
var shoot_timer: float = 0.0
var player_ref: Node3D
var mesh_instance: MeshInstance3D
var original_material: Material
var hit_flash_timer: float = 0.0
const HIT_FLASH_DURATION: float = 0.1
var is_dying: bool = false
var is_bursting: bool = false
var burst_shots_fired: int = 0
var burst_timer: float = 0.0

signal boss_died()

func _ready():
	# Add to enemies group and boss group
	add_to_group("Enemies")
	add_to_group("Boss")
	
	# Set collision layers: Enemy is on layer 3
	collision_layer = 4  # Only on Enemy layer (bit 3)
	collision_mask = 8  # Only collide with PlayerBullet (bit 4)
	
	# Initialize health
	current_health = max_health
	
	# Set boss at fixed Z position
	global_position.z = BOSS_Z_POSITION
	initial_x_position = global_position.x
	
	# Select target player
	select_target_player()
	# Start shoot timer with some randomness
	shoot_timer = randf_range(0.5, shoot_cooldown)
	
	# Get mesh instance for hit flash effect
	var boss_mesh_parent = get_node_or_null("BossMesh")
	if boss_mesh_parent:
		for child in boss_mesh_parent.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	
	if mesh_instance and mesh_instance.mesh:
		original_material = mesh_instance.get_surface_override_material(0)
		if not original_material:
			original_material = mesh_instance.mesh.surface_get_material(0)

func _physics_process(delta: float) -> void:
	# Handle hit flash - process on all peers regardless of authority
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0 and mesh_instance:
			# Restore original material
			mesh_instance.set_surface_override_material(0, original_material)
	
	# Only server processes boss movement in multiplayer
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
	
	# Boss strafes left and right instead of moving forward
	global_position.x += strafe_direction * STRAFE_SPEED * delta
	
	# Check strafe boundaries and reverse direction
	if abs(global_position.x - initial_x_position) > STRAFE_RANGE:
		strafe_direction *= -1.0
		# Clamp position to ensure it doesn't go beyond range
		if global_position.x > initial_x_position + STRAFE_RANGE:
			global_position.x = initial_x_position + STRAFE_RANGE
		elif global_position.x < initial_x_position - STRAFE_RANGE:
			global_position.x = initial_x_position - STRAFE_RANGE
	
	# Keep Z position fixed
	global_position.z = BOSS_Z_POSITION
	
	# Apply velocity for physics (mainly for Y movement if needed)
	velocity.x = strafe_direction * STRAFE_SPEED
	velocity.z = 0  # Boss doesn't move forward/backward
	move_and_slide()
	
	# Sync position to clients
	if NetworkManager.is_multiplayer_game:
		_sync_boss_position.rpc(global_position)
	
	# Shooting logic
	if not player_ref or not is_instance_valid(player_ref) or not player_ref.visible:
		select_target_player()
	
	if player_ref and is_instance_valid(player_ref):
		# Handle burst firing
		if is_bursting:
			burst_timer -= delta
			if burst_timer <= 0.0:
				fire_single_bullet()
				burst_shots_fired += 1
				
				if burst_shots_fired >= burst_count:
					# Burst complete
					is_bursting = false
					burst_shots_fired = 0
					shoot_timer = shoot_cooldown
				else:
					# Set timer for next bullet in burst
					burst_timer = burst_delay
		else:
			# Normal cooldown between bursts
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				# Start new burst
				is_bursting = true
				burst_shots_fired = 0
				burst_timer = 0.0

func fire_single_bullet():
	if not player_ref:
		return
		
	# In multiplayer, only host controls boss shooting
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
	
	# Calculate direction to player
	var player_pos = player_ref.global_position
	var direction = (player_pos - global_position).normalized()
	
	if NetworkManager.is_multiplayer_game:
		_spawn_boss_bullet_synced.rpc(global_position, direction, bullet_speed, damage)
	else:
		_spawn_boss_bullet(global_position, direction, bullet_speed, damage)

func _spawn_boss_bullet(spawn_pos: Vector3, direction: Vector3, speed: float, dmg: int):
	# Create bullet
	var bullet = EnemyBullet.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = spawn_pos
	
	# Set bullet velocity toward player
	bullet.velocity = direction * speed
	
	# Store damage value in bullet metadata
	bullet.set_meta("damage", dmg)
	
	# Orient bullet to face direction
	if direction.length() > 0:
		bullet.look_at(bullet.global_position + direction, Vector3.UP)

@rpc("authority", "call_local", "reliable")
func _spawn_boss_bullet_synced(spawn_pos: Vector3, direction: Vector3, speed: float, dmg: int):
	_spawn_boss_bullet(spawn_pos, direction, speed, dmg)

func take_damage(damage: int, impact_point: Vector3 = Vector3.ZERO, shooter: Node3D = null):
	if NetworkManager.is_multiplayer_game:
		var shooter_path = shooter.get_path() if shooter else ""
		_take_damage_synced.rpc(damage, impact_point, shooter_path)
	else:
		_apply_damage(damage, impact_point, shooter)

func _apply_damage(damage: int, impact_point: Vector3, shooter: Node3D = null):
	var was_alive = current_health > 0
	current_health -= damage
	
	# Flash effect
	flash_hit()
	
	# Create impact effect at hit location
	create_impact_effect(impact_point if impact_point != Vector3.ZERO else global_position)
	
	if current_health <= 0 and was_alive:
		# Award points to the shooter - boss awards 100 points
		if shooter and shooter.has_method("add_score"):
			shooter.add_score(100)
		die()

@rpc("any_peer", "call_local", "reliable")
func _take_damage_synced(damage: int, impact_point: Vector3, shooter_path: String):
	var shooter = null
	if shooter_path != "":
		shooter = get_node_or_null(shooter_path)
	_apply_damage(damage, impact_point, shooter)

@rpc("unreliable")
func _sync_boss_position(new_position: Vector3):
	if not NetworkManager.is_host:
		global_position = new_position

func flash_hit():
	if mesh_instance:
		# Create a red flash material
		var flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1, 0, 0, 1)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1, 0, 0, 1)
		flash_mat.emission_energy = 2.0
		
		mesh_instance.set_surface_override_material(0, flash_mat)
		hit_flash_timer = HIT_FLASH_DURATION

func create_impact_effect(position: Vector3):
	var impact = LaserImpact.instantiate()
	get_parent().add_child(impact)
	impact.global_position = position

func die():
	if is_dying:
		return
	
	if NetworkManager.is_multiplayer_game:
		_die_synced.rpc()
	else:
		is_dying = true
		_perform_death()

func _perform_death():
	# Emit boss died signal
	emit_signal("boss_died")
	
	# Spawn multiple explosions for dramatic effect
	for i in range(5):
		var explosion = Explosion.instantiate()
		get_parent().add_child(explosion)
		var offset = Vector3(
			randf_range(-2, 2),
			randf_range(-2, 2),
			randf_range(-2, 2)
		)
		explosion.global_position = global_position + offset
		await get_tree().create_timer(0.2).timeout
	
	# Remove the boss
	queue_free()

@rpc("any_peer", "call_local", "reliable")
func _die_synced():
	if is_dying:
		return
	is_dying = true
	_perform_death()

func get_health() -> int:
	return current_health

func select_target_player():
	var players = get_tree().get_nodes_in_group("Player")
	var valid_players = []
	var distances = []
	
	# Get all valid players and their distances
	for player in players:
		if player.visible and is_instance_valid(player):
			var distance = global_position.distance_to(player.global_position)
			valid_players.append(player)
			distances.append(distance)
	
	if valid_players.is_empty():
		player_ref = null
		return
	
	# If only one player, target them
	if valid_players.size() == 1:
		player_ref = valid_players[0]
		return
	
	# Calculate weights based on inverse distance (closer = higher weight)
	var weights = []
	var total_weight = 0.0
	
	for i in range(distances.size()):
		# Use inverse distance for weight (add 1 to avoid division by zero)
		var weight = 1.0 / (distances[i] + 1.0)
		weights.append(weight)
		total_weight += weight
	
	# Normalize weights and select random player
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for i in range(valid_players.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			player_ref = valid_players[i]
			return
	
	# Fallback (shouldn't reach here)
	player_ref = valid_players[0]