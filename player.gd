extends CharacterBody3D

# constants
const MAXSPEED = 30
const ACCELERATION = 0.75
const BULLET_SPEED = -600 # negative: toward player
const BULLET_COOLDOWN = 8 # frames
# inputs
var inputVector = Vector3()
var v = Vector3() # velocity
var bullet_cooldown = 0
# resources
var guns: Array[Node3D]
var main: Node3D
var Bullet = load("res://bullet.tscn")

func _ready():
	guns = [$Gun1, $Gun2]
	main = get_tree().current_scene

func _physics_process(delta: float) -> void:
	# read inputs
	inputVector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	inputVector.y = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	inputVector = inputVector.normalized()
	# set new velocity
	v.x = move_toward(v.x, inputVector.x * MAXSPEED, ACCELERATION)
	v.y = move_toward(v.y, inputVector.y * MAXSPEED, ACCELERATION)
	# rotate the ship, in response to velocity
	rotation_degrees.z = v.x * -2
	rotation_degrees.x = v.y / 2
	rotation_degrees.y = -v.x / 2
	# apply the updates
	self.velocity = v
	move_and_slide()	
	# restrict the player to the screen
	transform.origin.x = clamp(transform.origin.x, -15, 15)
	transform.origin.y = clamp(transform.origin.y, -10, 10)
	# shoot
	if Input.is_action_pressed("ui_accept") and bullet_cooldown <= 0:
		bullet_cooldown = BULLET_COOLDOWN
		for i in guns:
			var bullet = Bullet.instantiate()
			main.add_child(bullet)
			bullet.global_position = i.global_position
			bullet.global_rotation = i.global_rotation
			bullet.velocity = bullet.global_transform.basis.z * BULLET_SPEED
	# bullet cooldown
	if bullet_cooldown > 0:
		bullet_cooldown -= 1
		
