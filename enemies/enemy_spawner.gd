extends Node3D

var main
var Enemy: PackedScene = load("res://enemies/enemy.tscn") as PackedScene
var Enemy2: PackedScene = load("res://enemies/enemy2.tscn") as PackedScene
var Boss: PackedScene = load("res://enemies/boss.tscn") as PackedScene
var enemy_counter: int = 0
var boss_spawned: bool = false

func _ready():
	main = get_tree().current_scene

func spawn():
	# In multiplayer, only the host spawns enemies
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		return
		
	# Check total player score
	var total_score = 0
	var players = get_tree().get_nodes_in_group("Player")
	for player in players:
		if player.has_method("get") and player.get("score") != null:
			total_score += player.score
	
	# Stop spawning enemies if score >= 800
	if total_score >= 800:
		# Check if all enemies are dead and boss hasn't spawned
		var enemies = get_tree().get_nodes_in_group("Enemies")
		var living_enemies = []
		for enemy in enemies:
			if not enemy.is_in_group("Boss") and is_instance_valid(enemy):
				living_enemies.append(enemy)
		
		if living_enemies.is_empty() and not boss_spawned:
			spawn_boss()
		return
	
	# Generate spawn parameters
	var spawn_seed = randi()
	var offset_x = randf_range(-15, 15)
	var offset_y = randf_range(-10, 10)
	enemy_counter += 1
	var enemy_id = enemy_counter
	
	# Only spawn enemy2 if total score >= 500, then 50/50 chance
	var is_enemy2 = false
	if total_score >= 500:
		is_enemy2 = randf() < 0.5
	
	# Spawn locally and sync to clients
	if NetworkManager.is_multiplayer_game:
		_spawn_enemy_synced.rpc(spawn_seed, offset_x, offset_y, enemy_id, is_enemy2)
	else:
		_perform_spawn(spawn_seed, offset_x, offset_y, enemy_id, is_enemy2)

func _perform_spawn(spawn_seed: int, offset_x: float, offset_y: float, enemy_id: int, is_enemy2: bool = false):
	if is_enemy2:
		# Spawn enemy2 in V formation
		var center_x = offset_x
		var center_y = offset_y
		
		# Spawn center enemy2
		var enemy_center = Enemy2.instantiate()
		enemy_center.name = "Enemy2_" + str(enemy_id) + "_center"
		main.add_child(enemy_center)
		enemy_center.transform.origin = transform.origin + Vector3(center_x, center_y, 0)
		enemy_center.transform.origin.y = Global.DEFAULT_FLYING_HEIGHT * 1.5
		enemy_center.set_meta("enemy_id", enemy_id)
		
		# Spawn left enemy2 (slightly up and to the left)
		var enemy_left = Enemy2.instantiate()
		enemy_left.name = "Enemy2_" + str(enemy_id) + "_left"
		main.add_child(enemy_left)
		enemy_left.transform.origin = transform.origin + Vector3(center_x - 4, center_y + 2, 0)
		enemy_left.transform.origin.y = Global.DEFAULT_FLYING_HEIGHT * 1.5
		enemy_left.set_meta("enemy_id", enemy_id)
		
		# Spawn right enemy2 (slightly up and to the right)
		var enemy_right = Enemy2.instantiate()
		enemy_right.name = "Enemy2_" + str(enemy_id) + "_right"
		main.add_child(enemy_right)
		enemy_right.transform.origin = transform.origin + Vector3(center_x + 4, center_y + 2, 0)
		enemy_right.transform.origin.y = Global.DEFAULT_FLYING_HEIGHT * 1.5
		enemy_right.set_meta("enemy_id", enemy_id)
	else:
		# Spawn regular enemy
		var enemy = Enemy.instantiate()
		enemy.name = "Enemy_" + str(enemy_id)
		main.add_child(enemy)
		var offset = Vector3(offset_x, offset_y, 0)
		enemy.transform.origin = transform.origin + offset
		enemy.transform.origin.y = Global.DEFAULT_FLYING_HEIGHT
		enemy.set_meta("enemy_id", enemy_id)

@rpc("authority", "call_local", "reliable")
func _spawn_enemy_synced(spawn_seed: int, offset_x: float, offset_y: float, enemy_id: int, is_enemy2: bool = false):
	_perform_spawn(spawn_seed, offset_x, offset_y, enemy_id, is_enemy2)

func spawn_boss():
	boss_spawned = true
	
	if NetworkManager.is_multiplayer_game:
		_spawn_boss_synced.rpc()
	else:
		_perform_boss_spawn()

func _perform_boss_spawn():
	var boss = Boss.instantiate()
	boss.name = "Boss"
	main.add_child(boss)
	boss.global_position = Vector3(0, Global.DEFAULT_FLYING_HEIGHT, boss.BOSS_Z_POSITION)
	
	# Connect boss death signal to main
	if main.has_method("_on_boss_died"):
		boss.boss_died.connect(main._on_boss_died)

@rpc("authority", "call_local", "reliable")
func _spawn_boss_synced():
	_perform_boss_spawn()

func _on_timer_timeout() -> void:
	spawn()
