extends Node3D

var MarsDustScene = preload("res://fx/mars_dust.tscn")

func _ready():
	# Position player at default flying height
	var player = $player
	if player:
		player.position.y = Global.DEFAULT_FLYING_HEIGHT
	
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

func _input(event):
	# Toggle Mars dust with 'M' key
	if event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		Global.toggle_mars_dust()