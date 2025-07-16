extends Node3D

var main
var Enemy: PackedScene = load("res://enemy.tscn") as PackedScene

func _ready():
	main = get_tree().current_scene

func spawn():
	var enemy = Enemy.instantiate()
	main.add_child(enemy)
	var offset = Vector3(randf_range(-15,15), randf_range(-10,10), 0)
	enemy.transform.origin = transform.origin + offset
	# enemy asset is facing the wrong way
	enemy.rotation_degrees.y = 180

func _on_timer_timeout() -> void:
	spawn()
