extends CharacterBody3D

const BULLET_RECYCLE_DISTANCE = -100.0  # Z position where bullets get recycled

func _ready():
	# Set collision layers: PlayerBullet is on layer 4
	collision_layer = 8  # Only on PlayerBullet layer (bit 4)
	collision_mask = 4  # Only collide with Enemy (bit 3)
	
	# Also set collision layers for the Area3D child (used for hit detection)
	var area = $Area3D
	if area:
		area.collision_layer = 8  # Only on PlayerBullet layer (bit 4)
		area.collision_mask = 4  # Only collide with Enemy (bit 3)

func _physics_process(delta: float) -> void:
	move_and_slide()
	
	# Recycle bullet if it goes beyond the recycle distance
	if global_position.z < BULLET_RECYCLE_DISTANCE:
		queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	# check for a hit, then recylce the bullet and enemy
	if body.is_in_group("Enemies"):
		if body.has_method("take_damage"):
			# Get damage amount from bullet metadata
			var damage = get_meta("damage", 10) # Default 10 if not set
			body.take_damage(damage, global_position)
		elif body.has_method("die"):
			body.die()
		else:
			body.queue_free()
		
		# Create impact effect
		create_impact_effect(global_position)
		queue_free()

func create_impact_effect(position: Vector3):
	var LaserImpact = preload("res://fx/laser_impact.tscn")
	var impact = LaserImpact.instantiate()
	get_parent().add_child(impact)
	impact.global_position = position
