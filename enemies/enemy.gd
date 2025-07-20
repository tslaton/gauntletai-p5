extends CharacterBody3D

# Movement and combat properties
@export var speed_min: float = 20.0
@export var speed_max: float = 50.0
@export var damage: int = 10  # Damage this enemy's bullets deal
@export var shoot_cooldown: float = 3.0  # Time between bursts
@export var bullet_speed: float = 150.0  # Speed of enemy bullets
@export var max_health: int = 30  # Enemy health
@export var burst_count: int = 3  # Number of bullets per burst
@export var burst_delay: float = 0.15  # Delay between bullets in burst

var speed: float
var current_health: int
var Explosion = preload("res://fx/explosion.tscn")
var EnemyBullet = preload("res://projectiles/enemy_bullet.tscn")
var LaserImpact = preload("res://fx/laser_impact.tscn")
var LaserPickup = preload("res://pickups/laser_pickup.tscn")
var HealthPickup = preload("res://pickups/health_pickup.tscn")
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
const RECYCLE_Z_THRESHOLD: float = 5.0

func _ready():
	# Add to enemies group
	add_to_group("Enemies")
	
	# Set collision layers: Enemy is on layer 3
	collision_layer = 4  # Only on Enemy layer (bit 3)
	collision_mask = 8  # Only collide with PlayerBullet (bit 4)
	
	# Initialize health
	current_health = max_health
	
	# Randomize speed
	speed = randf_range(speed_min, speed_max)
	# Select target player
	select_target_player()
	# Start shoot timer with some randomness
	shoot_timer = randf_range(0.5, shoot_cooldown)
	
	# Get mesh instance for hit flash effect
	mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance and mesh_instance.mesh:
		original_material = mesh_instance.get_surface_override_material(0)
		if not original_material:
			original_material = mesh_instance.mesh.surface_get_material(0)

func _physics_process(delta: float) -> void:
	# Handle recycling when enemy gets too close to camera (runs on all clients)
	if global_position.z >= RECYCLE_Z_THRESHOLD:
		queue_free()
		return
	
	# Immediate destruction if enemy goes too far behind camera
	if transform.origin.z > 10:
		queue_free()
		return
	
	# Only server processes enemy movement in multiplayer
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
		
	self.velocity.z = speed
	move_and_slide()
	
	# Sync position to clients
	if NetworkManager.is_multiplayer_game:
		_sync_enemy_position.rpc(global_position)
	
	# Handle hit flash
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0 and mesh_instance:
			# Restore original material
			mesh_instance.set_surface_override_material(0, original_material)
	
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
		
	# In multiplayer, only host controls enemy shooting
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
	
	# Calculate direction to player
	var player_pos = player_ref.global_position
	var direction = (player_pos - global_position).normalized()
	
	if NetworkManager.is_multiplayer_game:
		_spawn_enemy_bullet_synced.rpc(global_position, direction, bullet_speed, damage)
	else:
		_spawn_enemy_bullet(global_position, direction, bullet_speed, damage)

func _spawn_enemy_bullet(spawn_pos: Vector3, direction: Vector3, speed: float, dmg: int):
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
func _spawn_enemy_bullet_synced(spawn_pos: Vector3, direction: Vector3, speed: float, dmg: int):
	_spawn_enemy_bullet(spawn_pos, direction, speed, dmg)

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
		# Award points to the shooter
		if shooter and shooter.has_method("add_score"):
			shooter.add_score(20)
		die()

@rpc("any_peer", "call_local", "reliable")
func _take_damage_synced(damage: int, impact_point: Vector3, shooter_path: String):
	var shooter = null
	if shooter_path != "":
		shooter = get_node_or_null(shooter_path)
	_apply_damage(damage, impact_point, shooter)

@rpc("unreliable")
func _sync_enemy_position(new_position: Vector3):
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
	# Spawn explosion at enemy position
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Only host decides pickups in multiplayer
	if not NetworkManager.is_multiplayer_game or NetworkManager.is_host:
		# Chance to spawn pickups - only one pickup per enemy
		var rand = randf()
		if rand < 0.15:  # 15% chance for laser pickup
			if NetworkManager.is_multiplayer_game:
				_spawn_pickup_synced.rpc("laser", global_position)
			else:
				spawn_pickup(LaserPickup)
		elif rand < 0.3:  # 15% chance for health pickup (0.15 + 0.15 = 0.3)
			if NetworkManager.is_multiplayer_game:
				_spawn_pickup_synced.rpc("health", global_position)
			else:
				spawn_pickup(HealthPickup)
		# else: 70% chance for no pickup
	
	# Small delay before removing to ensure RPC is sent
	if NetworkManager.is_multiplayer_game:
		await get_tree().create_timer(0.1).timeout
	
	# Remove the enemy
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

func spawn_pickup(pickup_scene: PackedScene):
	var pickup = pickup_scene.instantiate()
	
	# Add to parent (which should be main scene) for visibility in all viewports
	get_parent().add_child(pickup)
		
	pickup.global_position = global_position
	
	# Continue enemy's trajectory toward player
	pickup.velocity = Vector3(0, 0, speed)

@rpc("authority", "call_local", "reliable")
func _spawn_pickup_synced(pickup_type: String, spawn_position: Vector3):
	var pickup_scene = LaserPickup if pickup_type == "laser" else HealthPickup
	var pickup = pickup_scene.instantiate()
	
	# Add to parent (which should be main scene) for visibility in all viewports
	get_parent().add_child(pickup)
		
	pickup.global_position = spawn_position
	pickup.velocity = Vector3(0, 0, speed)
