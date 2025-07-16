extends GPUParticles3D

func _ready():
	emitting = true
	$Timer.start()

func _on_timer_timeout():
	queue_free()
