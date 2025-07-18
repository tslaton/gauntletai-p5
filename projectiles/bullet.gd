extends CharacterBody3D

const BULLET_RECYCLE_DISTANCE = -100.0  # Z position where bullets get recycled

func _physics_process(delta: float) -> void:
	move_and_slide()
	
	# Recycle bullet if it goes beyond the recycle distance
	if global_position.z < BULLET_RECYCLE_DISTANCE:
		queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	# check for a hit, then recylce the bullet and enemy
	if body.is_in_group("Enemies"):
		if body.has_method("die"):
			body.die()
		else:
			body.queue_free()
		queue_free()
