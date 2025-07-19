extends Node3D

var MarsDustScene = preload("res://fx/mars_dust.tscn")
var HealthDisplayScene = preload("res://ui/health_display.tscn")
var GameOverScene = preload("res://ui/game_over.tscn")
var PlayerScene = preload("res://player/player.tscn")

var game_over_ui: Control
var players = {}  # Dictionary to store player instances by peer ID
var cameras = {}  # Dictionary to store cameras by peer ID
var viewports = {}  # Dictionary to store viewports for split screen
var health_displays = {}  # Dictionary to store health displays by peer ID
var crosshair_controllers = {}  # Dictionary to store crosshair controllers
var alive_players = []  # Track which players are still alive

func _ready():
	# Mars dust is already in the scene, just get reference
	var mars_dust = $MarsDust
	if mars_dust:
		Global.mars_dust_effect = mars_dust
	
	# Add game over UI
	game_over_ui = GameOverScene.instantiate()
	add_child(game_over_ui)
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

func setup_singleplayer():
	# Use existing player in the scene
	var player = $player
	if player:
		player.position.y = Global.DEFAULT_FLYING_HEIGHT
		player.player_died.connect(_on_player_died.bind(1))
		players[1] = player
		alive_players.append(1)
	
	# Position camera at flying height
	var camera = $Camera3D
	if camera:
		camera.position.y = Global.DEFAULT_FLYING_HEIGHT
		cameras[1] = camera
	
	# Position crosshair controller at flying height
	var crosshair_controller = $CrosshairController
	if crosshair_controller:
		crosshair_controller.position.y = Global.DEFAULT_FLYING_HEIGHT
		crosshair_controllers[1] = crosshair_controller
	
	# Add health display UI
	var health_display = HealthDisplayScene.instantiate()
	add_child(health_display)
	health_displays[1] = health_display

func setup_multiplayer():
	# Remove the default player from the scene
	var default_player = $player
	if default_player:
		default_player.queue_free()
	
	# Remove default camera
	var default_camera = $Camera3D
	if default_camera:
		default_camera.queue_free()
		
	# Remove default crosshair controller
	var default_crosshair = $CrosshairController
	if default_crosshair:
		default_crosshair.queue_free()
	
	# Spawn players for all connected peers
	var player_ids = NetworkManager.get_player_ids()
	
	# Setup viewports for split screen if there are 2 players
	if player_ids.size() == 2:
		setup_split_screen()
	
	# Spawn each player
	for i in range(player_ids.size()):
		var peer_id = player_ids[i]
		spawn_player(peer_id, i + 1)

func setup_split_screen():
	# Create two viewport containers for split screen
	var screen_size = get_viewport().get_visible_rect().size
	
	# Create container for both viewports
	var split_container = HSplitContainer.new()
	split_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split_container.split_offset = int(screen_size.x / 2)
	add_child(split_container)
	
	# Left viewport for player 1
	var left_viewport_container = SubViewportContainer.new()
	left_viewport_container.stretch = true
	left_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_container.add_child(left_viewport_container)
	
	var left_viewport = SubViewport.new()
	left_viewport.size = Vector2(screen_size.x / 2, screen_size.y)
	left_viewport_container.add_child(left_viewport)
	viewports[1] = left_viewport
	
	# Right viewport for player 2  
	var right_viewport_container = SubViewportContainer.new()
	right_viewport_container.stretch = true
	right_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_container.add_child(right_viewport_container)
	
	var right_viewport = SubViewport.new()
	right_viewport.size = Vector2(screen_size.x / 2, screen_size.y)
	right_viewport_container.add_child(right_viewport)
	viewports[2] = right_viewport

func spawn_player(peer_id: int, player_number: int):
	# Create player instance
	var player = PlayerScene.instantiate()
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
	
	# Add player to scene
	add_child(player)
	
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
	
	# Add to appropriate viewport or main scene
	if NetworkManager.is_multiplayer_game and viewports.has(player_number):
		viewports[player_number].add_child(camera)
		viewports[player_number].add_child(crosshair_controller)
	else:
		add_child(camera)
		add_child(crosshair_controller)
	
	cameras[peer_id] = camera
	crosshair_controllers[peer_id] = crosshair_controller
	
	# Set the crosshair controller for the player
	player.crosshair_controller = crosshair_controller
	
	# Create health display for this player
	var health_display = HealthDisplayScene.instantiate()
	if NetworkManager.is_multiplayer_game and viewports.has(player_number):
		viewports[player_number].add_child(health_display)
	else:
		add_child(health_display)
	health_displays[peer_id] = health_display
	
	# Set the player to track for health display
	health_display.set_tracked_player(player, peer_id)
	
	# Make player 2 use the second ship model
	if player_number == 2:
		# This would need to be implemented in the player scene
		# by swapping the mesh or loading a different model
		pass

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
		# All players dead - game over
		await get_tree().create_timer(1.0).timeout
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
	
	# If this was a multiplayer game and now only one player remains, continue as single player
	if NetworkManager.is_multiplayer_game and players.size() == 1:
		# Could transition to single-player mode here if desired
		pass

func _on_retry_pressed():
	# Reload the current scene
	if NetworkManager.is_multiplayer_game:
		# In multiplayer, only host can restart
		if NetworkManager.is_host:
			_restart_game.rpc()
	else:
		get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func _restart_game():
	get_tree().reload_current_scene()

func _on_quit_pressed():
	if NetworkManager.is_multiplayer_game:
		NetworkManager.disconnect_from_game()
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	else:
		get_tree().quit()