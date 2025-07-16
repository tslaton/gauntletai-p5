extends CharacterBody3D

func _physics_process(delta: float) -> void:
	move_and_slide()


func _on_area_3d_body_entered(body: Node3D) -> void:
	# check for a hit, then recylce the bullet and enemy
	if body.is_in_group("Enemies"):
		body.queue_free()
		queue_free()
