extends CharacterBody3D

# speed at which the enemy will come toward the player
var speed = randf_range(20, 50)

func _physics_process(delta: float) -> void:
	self.velocity.z = speed
	move_and_slide()
	# destroy enemies when they go behind the camera
	if transform.origin.z > 10:
		queue_free()
	
