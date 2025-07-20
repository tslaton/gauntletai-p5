extends Node3D

var MarsDustScene = preload("res://fx/mars_dust.tscn")
var HealthDisplayScene = preload("res://ui/health_display.tscn")
var GameOverScene = preload("res://ui/game_over.tscn")
var PlayerScene = preload("res://player/player.tscn")
var Player2Scene = preload("res://player/player2.tscn")

var game_over_ui: Control
var players = {}  # Dictionary to store player instances by peer ID
var cameras = {}  # Dictionary to store cameras by peer ID
var health_displays = {}  # Dictionary to store health displays by peer ID
var crosshair_controllers = {}  # Dictionary to store crosshair controllers
var alive_players = []  # Track which players are still alive

func _ready():
	# Mars dust is already in the scene, just get reference
	var mars_dust = $MarsDust
	if mars_dust:
		Global.mars_dust_effect = mars_dust
	
	# Create game over UI
	if not game_over_ui:
		game_over_ui = GameOverScene.instantiate()
		game_over_ui.retry_pressed.connect(_on_retry_pressed)
		game_over_ui.quit_pressed.connect(_on_quit_pressed)
	
	# Handle multiplayer vs single player setup
	if NetworkManager.is_multiplayer_game:
		setup_multiplayer()
	else:
		setup_singleplayer()
	
	# Connect to network events for handling disconnections
	if NetworkManager.is_multiplayer_game:
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Add game over UI as overlay
	if not game_over_ui.get_parent():
		add_child(game_over_ui)
	# Ensure it's on top
	game_over_ui.z_index = 100
	game_over_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Ensure it can receive input during pause
	game_over_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func setup_singleplayer():
	# Use existing player in the scene
	var player = get_node_or_null("player")
	if player:
		player.position.y = Global.DEFAULT_FLYING_HEIGHT
		player.player_died.connect(_on_player_died.bind(1))
		players[1] = player
		alive_players.append(1)
	
	# Position camera at flying height
	var camera = get_node_or_null("Camera3D")
	if camera:
		camera.position.y = Global.DEFAULT_FLYING_HEIGHT
		cameras[1] = camera
	
	# Position crosshair controller at flying height
	var crosshair_controller = get_node_or_null("CrosshairController")
	if crosshair_controller:
		crosshair_controller.position.y = Global.DEFAULT_FLYING_HEIGHT
		crosshair_controllers[1] = crosshair_controller
		# Set crosshair controller for the player
		if player:
			player.crosshair_controller = crosshair_controller
	
	# Add health display UI
	var health_display = HealthDisplayScene.instantiate()
	add_child(health_display)
	health_displays[1] = health_display

func setup_multiplayer():
	# Remove the default player from the scene if it exists
	var default_player = get_node_or_null("player")
	if default_player:
		default_player.queue_free()
	
	# Remove default camera if it exists
	var default_camera = get_node_or_null("Camera3D")
	if default_camera:
		default_camera.queue_free()
		
	# Remove default crosshair controller if it exists
	var default_crosshair = get_node_or_null("CrosshairController")
	if default_crosshair:
		default_crosshair.queue_free()
	
	# Spawn players for all connected peers
	var player_ids = NetworkManager.get_player_ids()
	
	# Spawn each player - host is always player 1
	for i in range(player_ids.size()):
		var peer_id = player_ids[i]
		# Determine player number based on whether they're the host
		var player_number = 1 if peer_id == 1 else 2
		spawn_player(peer_id, player_number)
	
	# After all players are spawned, create health displays
	if player_ids.size() > 0:
		# Small delay to ensure players are fully initialized
		await get_tree().process_frame
		create_multiplayer_health_displays()


func spawn_player(peer_id: int, player_number: int):
	# Create player instance - use Player2Scene for second player
	var player_scene_to_use = PlayerScene if player_number == 1 else Player2Scene
	var player = player_scene_to_use.instantiate()
	player.name = "Player" + str(peer_id)
	player.player_id = peer_id
	player.player_number = player_number
	
	# Position player
	player.position.y = Global.DEFAULT_FLYING_HEIGHT
	player.position.z = -11
	
	# Offset player positions in multiplayer (player 1 left, player 2 right)
	if NetworkManager.is_multiplayer_game:
		if player_number == 1:
			player.position.x = -3
		else:
			player.position.x = 3
	
	# Add player to scene BEFORE setting authority
	add_child(player)
	
	# Ensure multiplayer authority is properly set after being in tree
	if NetworkManager.is_multiplayer_game:
		# The player's _ready function already sets authority, but we ensure it here too
		player.set_multiplayer_authority(peer_id)
	
	# Connect death signal
	player.player_died.connect(_on_player_died.bind(peer_id))
	
	# Store player reference
	players[peer_id] = player
	alive_players.append(peer_id)
	
	# Create camera for this player
	var camera = Camera3D.new()
	camera.position = Vector3(0, Global.DEFAULT_FLYING_HEIGHT, 10)
	camera.fov = 50
	
	# Create crosshair controller for this player
	var crosshair_controller = preload("res://player/crosshair_controller.tscn").instantiate()
	crosshair_controller.position.y = Global.DEFAULT_FLYING_HEIGHT
	
	# Add camera and crosshair controller to main scene
	add_child(camera)
	add_child(crosshair_controller)
	
	cameras[peer_id] = camera
	crosshair_controllers[peer_id] = crosshair_controller
	
	# Set the crosshair controller for the player
	# Only set crosshair controller for the local player
	if peer_id == NetworkManager.local_player_id:
		player.crosshair_controller = crosshair_controller
	else:
		# Remote players don't need local crosshair reference
		player.crosshair_controller = null
	
	# Single player health display
	if not NetworkManager.is_multiplayer_game:
		var health_display = HealthDisplayScene.instantiate()
		add_child(health_display)
		health_displays[peer_id] = health_display
		health_display.set_tracked_player(player, peer_id)

func create_multiplayer_health_displays():
	# Create health displays for all players
	var player_ids = NetworkManager.get_player_ids()
	player_ids.sort() # Ensure consistent order (player 1 first)
	
	var y_offset = 10
	for i in range(player_ids.size()):
		var pid = player_ids[i]
		var health_display = HealthDisplayScene.instantiate()
		health_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		health_display.position = Vector2(10, y_offset)
		add_child(health_display)
		health_displays[pid] = health_display
		
		# Find the player to track
		var player_to_track = players.get(pid)
		if player_to_track:
			health_display.set_tracked_player(player_to_track, pid)
		
		# Move y_offset down for next health display
		y_offset += 40

func _input(event):
	# Toggle Mars dust with 'M' key
	if event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		Global.toggle_mars_dust()
	
	# Host-only controls in multiplayer
	if NetworkManager.is_multiplayer_game and NetworkManager.is_host:
		if event.is_action_pressed("ui_cancel"):
			# Only host can pause in multiplayer
			get_tree().paused = !get_tree().paused

func _on_player_died(peer_id: int):
	# Remove from alive players list
	alive_players.erase(peer_id)
	
	# In single player, show game over immediately
	if not NetworkManager.is_multiplayer_game:
		await get_tree().create_timer(1.0).timeout
		game_over_ui.show_game_over()
		return
	
	# In multiplayer, check if all players are dead
	if alive_players.is_empty():
		# All players dead - game over for everyone
		await get_tree().create_timer(1.0).timeout
		if NetworkManager.is_host:
			_show_game_over_all.rpc()
		else:
			game_over_ui.show_game_over()
	else:
		# Switch dead player's camera to spectate the alive player
		var alive_player_id = alive_players[0]
		var dead_camera = cameras.get(peer_id)
		var alive_player = players.get(alive_player_id)
		
		if dead_camera and alive_player:
			# Make the dead player's camera follow the alive player
			dead_camera.position = alive_player.position + Vector3(0, 5, 10)

func _on_player_disconnected(peer_id: int):
	# Remove disconnected player
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	
	if cameras.has(peer_id):
		cameras[peer_id].queue_free()
		cameras.erase(peer_id)
		
	if crosshair_controllers.has(peer_id):
		crosshair_controllers[peer_id].queue_free()
		crosshair_controllers.erase(peer_id)
		
	if health_displays.has(peer_id):
		health_displays[peer_id].queue_free()
		health_displays.erase(peer_id)
	
	alive_players.erase(peer_id)
	
	# If this was a multiplayer game and now only one player remains, transition to single player
	if NetworkManager.is_multiplayer_game and players.size() == 1:
		# Transition to single-player mode
		NetworkManager.is_multiplayer_game = false
		NetworkManager.is_host = false

func _on_retry_pressed():
	# Reload the current scene
	if NetworkManager.is_multiplayer_game:
		if NetworkManager.is_host:
			# Host can restart for everyone
			_restart_game.rpc()
		else:
			# Non-host disconnects and goes to main menu
			get_tree().paused = false
			NetworkManager.disconnect_from_game()
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	else:
		get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func _restart_game():
	# Don't reload the scene - instead reset the game state
	get_tree().paused = false
	
	# Clear existing game objects
	# First, clear all nodes from the Player group
	for player_node in get_tree().get_nodes_in_group("Player"):
		player_node.remove_from_group("Player")
		player_node.queue_free()
	
	# Also remove any existing player nodes by name to ensure cleanup
	for child in get_children():
		if (child.name.begins_with("Player") or child.name == "player") and child.has_method("take_damage"):
			child.queue_free()
	
	for player_id in players:
		if players[player_id] and is_instance_valid(players[player_id]):
			players[player_id].queue_free()
	players.clear()
	
	for cam_id in cameras:
		if cameras[cam_id]:
			cameras[cam_id].queue_free()
	cameras.clear()
	
	for cc_id in crosshair_controllers:
		if crosshair_controllers[cc_id]:
			crosshair_controllers[cc_id].queue_free()
	crosshair_controllers.clear()
	
	# Clear all health displays
	for hd in health_displays.values():
		if hd and is_instance_valid(hd):
			hd.queue_free()
	health_displays.clear()
	
	# Also clear any remaining health displays by name
	for child in get_children():
		if child.name.begins_with("HealthDisplay"):
			child.queue_free()
	
	
	# Clear enemies, pickups, and bullets
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		enemy.queue_free()
	
	for pickup in get_tree().get_nodes_in_group("Pickups"):
		pickup.queue_free()
	
	# Clear all bullets
	for child in get_children():
		if child.name.begins_with("Bullet") or child.name.begins_with("EnemyBullet"):
			child.queue_free()
	
	# Reset alive players list
	alive_players.clear()
	
	# Hide game over UI
	if game_over_ui.has_method("hide_game_over"):
		game_over_ui.hide_game_over()
	else:
		game_over_ui.visible = false
	
	# Wait multiple frames for cleanup to ensure nodes are fully freed
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Double-check that all players are gone
	var remaining_players = get_tree().get_nodes_in_group("Player")
	if remaining_players.size() > 0:
		for p in remaining_players:
			p.queue_free()
		await get_tree().process_frame
	
	# Reinitialize the game
	if NetworkManager.is_multiplayer_game:
		setup_multiplayer()
	else:
		setup_singleplayer()
	
	# Ensure game over UI stays on top after reinit
	if game_over_ui and game_over_ui.get_parent():
		game_over_ui.get_parent().move_child(game_over_ui, -1)
		game_over_ui.z_index = 100
		# Force the game over UI to the top of the render order
		game_over_ui.show()
		game_over_ui.hide()

@rpc("authority", "call_local", "reliable")
func _show_game_over_all():
	game_over_ui.show_game_over()

func _on_quit_pressed():
	if NetworkManager.is_multiplayer_game:
		if NetworkManager.is_host:
			# Host quitting ends the game for everyone
			_notify_game_ending.rpc()
			await get_tree().create_timer(0.1).timeout
			get_tree().quit()
		else:
			# Non-host just disconnects and returns to menu
			get_tree().paused = false
			NetworkManager.disconnect_from_game()
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	else:
		get_tree().quit()

@rpc("authority", "call_local", "reliable")
func _notify_game_ending():
	# Show a message or just quit
	get_tree().paused = false
	if not NetworkManager.is_host:
		# Non-host clients return to main menu when host quits
		NetworkManager.disconnect_from_game()
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
