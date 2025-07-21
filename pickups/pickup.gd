extends Area3D

@export var pickup_type: String = "laser"  # "laser" or "health"
@export var move_speed: float = 30.0
@export var rotation_speed: float = 2.0

var velocity: Vector3 = Vector3.ZERO
const RECYCLE_Z_THRESHOLD: float = 5.0

func _ready():
	add_to_group("Pickups")
	body_entered.connect(_on_body_entered)
	
	# Set collision layers: Pickups are on layer 5 (same as enemy bullets)
	collision_layer = 16  # Only on layer 5 (bit 5)
	collision_mask = 2  # Only detect Player (bit 2)

func _physics_process(delta: float) -> void:
	# Move forward
	global_position += velocity * delta
	
	# Rotate around Y axis
	rotate_y(rotation_speed * delta)
	
	# Handle recycling when pickup gets too close to camera
	if global_position.z >= RECYCLE_Z_THRESHOLD:
		queue_free()
	
	# Immediate destruction if pickup goes too far behind camera
	if transform.origin.z > 10:
		queue_free()

var is_collected: bool = false

func _on_body_entered(body: Node3D):
	# Prevent multiple collections
	if is_collected:
		return
		
	if body.is_in_group("Player"):
		is_collected = true
		# Let player handle the pickup effect
		if body.has_method("collect_pickup"):
			body.collect_pickup(pickup_type)
		queue_free()