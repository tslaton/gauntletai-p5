extends CharacterBody3D

# Movement and combat properties
@export var speed_min: float = 20.0
@export var speed_max: float = 50.0
@export var damage: int = 10  # Damage this enemy's bullets deal
@export var shoot_cooldown: float = 2.0  # Time between shots
@export var bullet_speed: float = 400.0  # Speed of enemy bullets
@export var max_health: int = 30  # Enemy health

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

func _ready():
	# Add to enemies group
	add_to_group("Enemies")
	
	# Initialize health
	current_health = max_health
	
	# Randomize speed
	speed = randf_range(speed_min, speed_max)
	# Find player reference
	player_ref = get_tree().get_first_node_in_group("Player")
	# Start shoot timer with some randomness
	shoot_timer = randf_range(0.5, shoot_cooldown)
	
	# Get mesh instance for hit flash effect
	mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance and mesh_instance.mesh:
		original_material = mesh_instance.get_surface_override_material(0)
		if not original_material:
			original_material = mesh_instance.mesh.surface_get_material(0)

func _physics_process(delta: float) -> void:
	self.velocity.z = speed
	move_and_slide()
	
	# Handle hit flash
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0 and mesh_instance:
			# Restore original material
			mesh_instance.set_surface_override_material(0, original_material)
	
	# Shooting logic
	if player_ref and is_instance_valid(player_ref):
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			shoot_at_player()
			shoot_timer = shoot_cooldown
	
	# destroy enemies when they go behind the camera
	if transform.origin.z > 10:
		queue_free()

func shoot_at_player():
	if not player_ref:
		return
		
	# Create bullet
	var bullet = EnemyBullet.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	
	# Calculate direction to player with some prediction
	var player_pos = player_ref.global_position
	var direction = (player_pos - global_position).normalized()
	
	# Set bullet velocity toward player
	bullet.velocity = direction * bullet_speed
	
	# Store damage value in bullet metadata
	bullet.set_meta("damage", damage)
	
	# Orient bullet to face direction
	if direction.length() > 0:
		bullet.look_at(bullet.global_position + direction, Vector3.UP)

func take_damage(damage: int, impact_point: Vector3 = Vector3.ZERO):
	current_health -= damage
	
	# Flash effect
	flash_hit()
	
	# Create impact effect at hit location
	create_impact_effect(impact_point if impact_point != Vector3.ZERO else global_position)
	
	if current_health <= 0:
		die()

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
	# Spawn explosion at enemy position
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Chance to spawn pickups
	var rand = randf()
	if rand < 0.2:  # 20% chance for laser pickup
		spawn_pickup(LaserPickup)
	elif rand < 0.4:  # 20% chance for health pickup (0.2 + 0.2 = 0.4)
		spawn_pickup(HealthPickup)
	
	# Remove the enemy
	queue_free()

func spawn_pickup(pickup_scene: PackedScene):
	var pickup = pickup_scene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	
	# Continue enemy's trajectory toward player
	pickup.velocity = Vector3(0, 0, speed)
