extends CharacterBody3D

const BULLET_RECYCLE_DISTANCE = 10.0  # Z position where bullets get recycled (behind player)

func _ready():
	# Set collision layers: EnemyBullet is on layer 5
	collision_layer = 16  # Only on EnemyBullet layer (bit 5)
	collision_mask = 2  # Only collide with Player (bit 2)
	
	# Also set collision layers for the Area3D child (used for hit detection)
	var area = $Area3D
	if area:
		area.collision_layer = 16  # Only on EnemyBullet layer (bit 5)
		area.collision_mask = 2  # Only collide with Player (bit 2)

func _physics_process(delta: float) -> void:
	move_and_slide()
	
	# Recycle bullet if it goes beyond the recycle distance (behind player)
	if global_position.z > BULLET_RECYCLE_DISTANCE:
		queue_free()

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Check if hit player
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			# Get damage amount from the enemy who fired this bullet
			var damage = get_meta("damage", 10) # Default 10 damage if not set
			body.take_damage(damage)
		
		# Create impact effect
		create_impact_effect(global_position)
		queue_free()

func create_impact_effect(position: Vector3):
	var LaserImpact = preload("res://fx/laser_impact.tscn")
	var impact = LaserImpact.instantiate()
	get_parent().add_child(impact)
	impact.global_position = position