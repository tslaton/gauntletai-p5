extends Control

@onready var ip_label = $VBoxContainer/IPLabel
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartButton
@onready var back_button = $VBoxContainer/BackButton
@onready var status_label = $VBoxContainer/StatusLabel

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
	else:
		ip_label.text = "Connected to host"
		start_button.hide()
		status_label.text = "Waiting for host to start..."
	
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