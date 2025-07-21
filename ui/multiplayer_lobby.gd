extends Control

@onready var ip_label = $VBoxContainer/IPLabel
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartButton
@onready var back_button = $VBoxContainer/BackButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var difficulty_label = $VBoxContainer/DifficultyLabel
@onready var difficulty_container = $VBoxContainer/DifficultyContainer
@onready var easy_button = $VBoxContainer/DifficultyContainer/EasyButton
@onready var medium_button = $VBoxContainer/DifficultyContainer/MediumButton
@onready var hard_button = $VBoxContainer/DifficultyContainer/HardButton

var difficulty_buttons: Array[Button]

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.lobby_ready.connect(_on_lobby_ready)
	
	if NetworkManager.is_host:
		ip_label.text = "Your IP: " + NetworkManager.get_local_ip_address()
		start_button.disabled = true
		status_label.text = "Waiting for another player..."
		
		# Setup difficulty buttons for host
		difficulty_buttons = [easy_button, medium_button, hard_button]
		easy_button.pressed.connect(_on_difficulty_selected.bind(Global.Difficulty.EASY))
		medium_button.pressed.connect(_on_difficulty_selected.bind(Global.Difficulty.MEDIUM))
		hard_button.pressed.connect(_on_difficulty_selected.bind(Global.Difficulty.HARD))
		_update_difficulty_buttons()
	else:
		ip_label.text = "Connected to host"
		start_button.hide()
		status_label.text = "Waiting for host to start..."
		
		# Hide difficulty selection for non-host players
		difficulty_label.hide()
		difficulty_container.hide()
	
	_update_player_list()

func _update_player_list():
	player_list.clear()
	var player_ids = NetworkManager.get_player_ids()
	
	# Sort to ensure consistent order (host first)
	player_ids.sort()
	
	for id in player_ids:
		# Player number is based on peer_id (1 = host = Player 1, others = Player 2)
		var player_number = 1 if id == 1 else 2
		var player_text = "Player " + str(player_number)
		if id == NetworkManager.local_player_id:
			player_text += " (You)"
		if id == 1:
			player_text += " - Host"
		player_list.add_item(player_text)

func _on_player_connected(id: int):
	_update_player_list()
	if NetworkManager.is_host and NetworkManager.get_player_count() == 2:
		start_button.disabled = false
		status_label.text = "Ready to start!"

func _on_player_disconnected(id: int):
	_update_player_list()
	if NetworkManager.is_host:
		start_button.disabled = true
		status_label.text = "Waiting for another player..."

func _on_lobby_ready():
	if NetworkManager.is_host:
		start_button.disabled = false
		status_label.text = "Ready to start!"

func _on_start_pressed():
	if NetworkManager.is_host:
		NetworkManager.start_multiplayer_game()

func _on_back_pressed():
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _on_difficulty_selected(difficulty: Global.Difficulty):
	Global.current_difficulty = difficulty
	_update_difficulty_buttons()

func _update_difficulty_buttons():
	# Update button states based on current difficulty
	easy_button.button_pressed = Global.current_difficulty == Global.Difficulty.EASY
	medium_button.button_pressed = Global.current_difficulty == Global.Difficulty.MEDIUM
	hard_button.button_pressed = Global.current_difficulty == Global.Difficulty.HARD