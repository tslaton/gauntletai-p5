extends Node3D

var main
var Enemy: PackedScene = load("res://enemies/enemy.tscn") as PackedScene
var enemy_counter: int = 0

func _ready():
	main = get_tree().current_scene

func spawn():
	# In multiplayer, only the host spawns enemies
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
		
	# Generate spawn parameters
	var spawn_seed = randi()
	var offset_x = randf_range(-15, 15)
	var offset_y = randf_range(-10, 10)
	enemy_counter += 1
	var enemy_id = enemy_counter
	
	# Spawn locally and sync to clients
	if NetworkManager.is_multiplayer_game:
		_spawn_enemy_synced.rpc(spawn_seed, offset_x, offset_y, enemy_id)
	else:
		_perform_spawn(spawn_seed, offset_x, offset_y, enemy_id)

func _perform_spawn(spawn_seed: int, offset_x: float, offset_y: float, enemy_id: int):
	var enemy = Enemy.instantiate()
	enemy.name = "Enemy_" + str(enemy_id)
	main.add_child(enemy)
	var offset = Vector3(offset_x, offset_y, 0)
	enemy.transform.origin = transform.origin + offset
	enemy.transform.origin.y = Global.DEFAULT_FLYING_HEIGHT
	
	# Set the enemy ID for tracking
	enemy.set_meta("enemy_id", enemy_id)

@rpc("authority", "call_local", "reliable")
func _spawn_enemy_synced(spawn_seed: int, offset_x: float, offset_y: float, enemy_id: int):
	_perform_spawn(spawn_seed, offset_x, offset_y, enemy_id)

func _on_timer_timeout() -> void:
	spawn()
