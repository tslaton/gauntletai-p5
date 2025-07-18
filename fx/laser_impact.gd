extends Node3D

@onready var sparks = $Sparks
@onready var flash_light = $Flash

func _ready():
	setup_particles()
	animate_flash()
	
	# Auto-destroy after animation
	await get_tree().create_timer(0.5).timeout
	queue_free()

func setup_particles():
	var process_mat = ParticleProcessMaterial.new()
	
	# Emission
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.1
	
	# Movement - sparks fly outward
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.initial_velocity_min = 10.0
	process_mat.initial_velocity_max = 20.0
	process_mat.angular_velocity_min = -360.0
	process_mat.angular_velocity_max = 360.0
	process_mat.gravity = Vector3(0, -30, 0)
	process_mat.damping_min = 2.0
	process_mat.damping_max = 5.0
	
	# Scale
	process_mat.scale_min = 0.05
	process_mat.scale_max = 0.15
	
	# Create scale curve
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1))
	scale_curve.add_point(Vector2(1, 0))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	process_mat.scale_curve = scale_curve_tex
	
	# Color
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.3, 1.0]
	gradient.colors = [
		Color(1, 1, 1, 1),
		Color(1, 0.5, 0, 1),
		Color(1, 0, 0, 0)
	]
	
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	sparks.process_material = process_mat

func animate_flash():
	# Animate the flash light
	var tween = create_tween()
	tween.tween_property(flash_light, "light_energy", 0.0, 0.2).from(5.0)
	tween.tween_callback(flash_light.queue_free)
