extends CharacterBody3D

# Constants
const BOMB_SPEED: float = 10.0
const BOMB_HEALTH: int = 30
const BOMB_TIMER: float = 2.5
const FIRE_WAVE_DAMAGE: int = 30
const FIRE_WAVE_HEIGHT: float = 5.0

# Variables
var target_position: Vector3
var current_health: int = BOMB_HEALTH
var timer: float = BOMB_TIMER
var is_dying: bool = false
var mesh_instance: MeshInstance3D
var original_material: Material
var hit_flash_timer: float = 0.0
const HIT_FLASH_DURATION: float = 0.1

# Preloads
var Explosion = preload("res://fx/explosion.tscn")
var LaserImpact = preload("res://fx/laser_impact.tscn")

signal bomb_exploded(position: Vector3, is_vertical: bool)

func _ready():
	# Add to enemies group so it can be targeted
	add_to_group("Enemies")
	add_to_group("Bombs")
	
	# Set collision layers: Enemy is on layer 3
	collision_layer = 4  # Only on Enemy layer (bit 3)
	collision_mask = 8  # Only collide with PlayerBullet (bit 4)
	
	# Get mesh instance for hit flash effect
	var mesh_parent = get_node_or_null("HorizontalBombMesh")
	if mesh_parent:
		for child in mesh_parent.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	
	if mesh_instance and mesh_instance.mesh:
		original_material = mesh_instance.get_surface_override_material(0)
		if not original_material:
			original_material = mesh_instance.mesh.surface_get_material(0)

func initialize(target_pos: Vector3):
	target_position = target_pos
	target_position.z = 0  # Ensure z is 0
	
	# Calculate direction to target
	var direction = (target_position - global_position).normalized()
	velocity = direction * BOMB_SPEED
	
	# Orient bomb to face direction
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	# Handle hit flash
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0 and mesh_instance:
			mesh_instance.set_surface_override_material(0, original_material)
	
	if is_dying:
		return
	
	# Only server processes bomb movement in multiplayer
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
	
	# Update timer
	timer -= delta
	if timer <= 0:
		detonate()
		return
	
	# Check if reached target
	var distance_to_target = global_position.distance_to(target_position)
	if distance_to_target < 2.0:
		# Stop moving when at target
		velocity = Vector3.ZERO
	
	# Move
	move_and_slide()
	
	# Sync position to clients
	if NetworkManager.is_multiplayer_game:
		_sync_bomb_position.rpc(global_position)

@rpc("unreliable")
func _sync_bomb_position(new_position: Vector3):
	if not NetworkManager.is_host:
		global_position = new_position

func take_damage(damage: int, impact_point: Vector3 = Vector3.ZERO, shooter: Node3D = null):
	if NetworkManager.is_multiplayer_game:
		var shooter_path = shooter.get_path() if shooter else ""
		_take_damage_synced.rpc(damage, impact_point, shooter_path)
	else:
		_apply_damage(damage, impact_point, shooter)

func _apply_damage(damage: int, impact_point: Vector3, shooter: Node3D = null):
	if is_dying:
		return
		
	var was_alive = current_health > 0
	current_health -= damage
	
	# Flash effect
	flash_hit()
	
	# Create impact effect at hit location
	create_impact_effect(impact_point if impact_point != Vector3.ZERO else global_position)
	
	if current_health <= 0 and was_alive:
		# Award points to the shooter - bomb awards 10 points
		if shooter and shooter.has_method("add_score"):
			shooter.add_score(10)
		die()

@rpc("any_peer", "call_local", "reliable")
func _take_damage_synced(damage: int, impact_point: Vector3, shooter_path: String):
	var shooter = null
	if shooter_path != "":
		shooter = get_node_or_null(shooter_path)
	_apply_damage(damage, impact_point, shooter)

func flash_hit():
	if mesh_instance:
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
	# Spawn regular explosion
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Remove the bomb
	queue_free()

@rpc("any_peer", "call_local", "reliable")
func _die_synced():
	if is_dying:
		return
	is_dying = true
	_perform_death()

func detonate():
	if is_dying:
		return
	
	if NetworkManager.is_multiplayer_game:
		_detonate_synced.rpc()
	else:
		is_dying = true
		_perform_detonation()

func _perform_detonation():
	# Emit signal for fire wave effect
	emit_signal("bomb_exploded", global_position, false)
	
	# Create horizontal fire wave effect
	create_horizontal_fire_wave()
	
	# Spawn explosion at bomb location
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Deal damage to all players in the fire wave area
	var players = get_tree().get_nodes_in_group("Player")
	for player in players:
		if is_instance_valid(player) and player.has_method("take_damage"):
			var player_pos = player.global_position
			# Check if player is in the horizontal fire wave area
			# Fire wave hits all x and all z > bomb position for y +/- height
			if abs(player_pos.y - global_position.y) <= FIRE_WAVE_HEIGHT and player_pos.z >= global_position.z:
				player.take_damage(FIRE_WAVE_DAMAGE)
	
	# Remove the bomb
	queue_free()

@rpc("any_peer", "call_local", "reliable")
func _detonate_synced():
	if is_dying:
		return
	is_dying = true
	_perform_detonation()

func create_horizontal_fire_wave():
	# Create a visual effect for the horizontal fire wave
	# This creates a wide rectangular wave effect
	var fire_wave = GPUParticles3D.new()
	get_parent().add_child(fire_wave)
	fire_wave.global_position = global_position
	
	# Configure the particle system
	fire_wave.amount = 200
	fire_wave.lifetime = 1.0
	fire_wave.one_shot = true
	fire_wave.emitting = true
	
	# Create process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(50.0, FIRE_WAVE_HEIGHT, 1.0)  # Wide horizontal box
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.0
	process_mat.angular_velocity_min = -180.0
	process_mat.angular_velocity_max = 180.0
	process_mat.scale_min = 2.0
	process_mat.scale_max = 4.0
	process_mat.color = Color(1.0, 0.3, 0.0, 1.0)  # Orange fire color
	
	fire_wave.process_material = process_mat
	
	# Create draw pass material
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 4
	fire_wave.draw_pass_1 = sphere_mesh
	
	var fire_mat = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.3, 0.0, 1.0)
	fire_mat.emission_energy = 3.0
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	sphere_mesh.surface_set_material(0, fire_mat)
	
	# Clean up after effect
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(fire_wave):
		fire_wave.queue_free()

func get_health() -> int:
	return current_health