extends GPUParticles3D

@onready var explosion_sound = $ExplosionSound

func _ready():
	emitting = true
	$Timer.start()
	
	# Play explosion sound if available
	if explosion_sound:
		explosion_sound.play()

func _on_timer_timeout():
	queue_free()
