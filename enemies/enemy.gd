extends CharacterBody3D

# Movement and combat properties
@export var speed_min: float = 20.0
@export var speed_max: float = 50.0
@export var damage: int = 10  # Damage this enemy's bullets deal
@export var shoot_cooldown: float = 2.0  # Time between shots
@export var bullet_speed: float = 400.0  # Speed of enemy bullets

var speed: float
var Explosion = preload("res://fx/explosion.tscn")
var EnemyBullet = preload("res://projectiles/enemy_bullet.tscn")
var shoot_timer: float = 0.0
var player_ref: Node3D

func _ready():
	# Randomize speed
	speed = randf_range(speed_min, speed_max)
	# Find player reference
	player_ref = get_tree().get_first_node_in_group("Player")
	# Start shoot timer with some randomness
	shoot_timer = randf_range(0.5, shoot_cooldown)

func _physics_process(delta: float) -> void:
	self.velocity.z = speed
	move_and_slide()
	
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

func die():
	# Spawn explosion at enemy position
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	# Remove the enemy
	queue_free()
