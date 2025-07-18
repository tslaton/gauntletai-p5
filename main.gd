extends Node3D

var MarsDustScene = preload("res://fx/mars_dust.tscn")
var HealthDisplayScene = preload("res://ui/health_display.tscn")
var GameOverScene = preload("res://ui/game_over.tscn")

var game_over_ui: Control
var player: Node3D

func _ready():
	# Position player at default flying height
	player = $player
	if player:
		player.position.y = Global.DEFAULT_FLYING_HEIGHT
		player.player_died.connect(_on_player_died)
	
	# Position camera at flying height
	var camera = $Camera3D
	if camera:
		camera.position.y = Global.DEFAULT_FLYING_HEIGHT
	
	# Position crosshair controller at flying height
	var crosshair_controller = $CrosshairController
	if crosshair_controller:
		crosshair_controller.position.y = Global.DEFAULT_FLYING_HEIGHT
	
	# Mars dust is already in the scene, just get reference
	var mars_dust = $MarsDust
	if mars_dust:
		Global.mars_dust_effect = mars_dust
	
	# Add health display UI
	var health_display = HealthDisplayScene.instantiate()
	add_child(health_display)
	
	# Add game over UI
	game_over_ui = GameOverScene.instantiate()
	add_child(game_over_ui)
	game_over_ui.retry_pressed.connect(_on_retry_pressed)
	game_over_ui.quit_pressed.connect(_on_quit_pressed)

func _input(event):
	# Toggle Mars dust with 'M' key
	if event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		Global.toggle_mars_dust()

func _on_player_died():
	# Show game over screen after a short delay
	await get_tree().create_timer(1.0).timeout
	game_over_ui.show_game_over()

func _on_retry_pressed():
	# Reload the current scene
	get_tree().reload_current_scene()

func _on_quit_pressed():
	# Quit is handled by the game_over UI
	pass