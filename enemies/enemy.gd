extends CharacterBody3D

# speed at which the enemy will come toward the player
var speed = randf_range(20, 50)
var Explosion = preload("res://fx/explosion.tscn")

func _physics_process(delta: float) -> void:
	self.velocity.z = speed
	move_and_slide()
	# destroy enemies when they go behind the camera
	if transform.origin.z > 10:
		queue_free()

func die():
	# Spawn explosion at enemy position
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	# Remove the enemy
	queue_free()
	
