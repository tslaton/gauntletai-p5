extends CharacterBody3D

const BULLET_RECYCLE_DISTANCE = 10.0  # Z position where bullets get recycled (behind player)

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
		queue_free()