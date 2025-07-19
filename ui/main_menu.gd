extends Control

@onready var single_player_button = $VBoxContainer/SinglePlayerButton
@onready var host_multiplayer_button = $VBoxContainer/HostMultiplayerButton
@onready var join_multiplayer_button = $VBoxContainer/JoinMultiplayerButton
@onready var join_container = $VBoxContainer/JoinContainer
@onready var ip_input = $VBoxContainer/JoinContainer/IPInput
@onready var connect_button = $VBoxContainer/JoinContainer/ConnectButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	single_player_button.pressed.connect(_on_single_player_pressed)
	host_multiplayer_button.pressed.connect(_on_host_multiplayer_pressed)
	join_multiplayer_button.pressed.connect(_on_join_multiplayer_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	
	join_container.hide()
	status_label.text = ""

func _on_single_player_pressed():
	NetworkManager.start_singleplayer()

func _on_host_multiplayer_pressed():
	if NetworkManager.host_game():
		get_tree().change_scene_to_file("res://ui/multiplayer_lobby.tscn")
	else:
		status_label.text = "Failed to create server"

func _on_join_multiplayer_pressed():
	join_container.show()
	ip_input.grab_focus()

func _on_connect_pressed():
	var ip = ip_input.text.strip_edges()
	if ip == "":
		status_label.text = "Please enter an IP address"
		return
	
	status_label.text = "Connecting..."
	if not NetworkManager.join_game(ip):
		status_label.text = "Failed to connect"

func _on_connection_failed():
	status_label.text = "Connection failed"

func _on_connected_to_server():
	get_tree().change_scene_to_file("res://ui/multiplayer_lobby.tscn")

func _on_quit_pressed():
	get_tree().quit()