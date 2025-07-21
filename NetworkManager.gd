extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connected_to_server()
signal lobby_ready()

const PORT = 8910
const MAX_PLAYERS = 2

var is_multiplayer_game = false
var is_host = false
var connected_players = {}
var local_player_id = 1

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Failed to create server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	local_player_id = multiplayer.get_unique_id()
	is_multiplayer_game = true
	is_host = true
	connected_players[local_player_id] = {"ready": true, "is_host": true}
	print("Server started on port ", PORT)
	return true

func join_game(ip_address: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	if error != OK:
		print("Failed to create client: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_multiplayer_game = true
	is_host = false
	print("Attempting to connect to ", ip_address, ":", PORT)
	return true

func start_singleplayer():
	is_multiplayer_game = false
	is_host = false
	connected_players.clear()
	get_tree().change_scene_to_file("res://main.tscn")

func start_multiplayer_game():
	if not is_host:
		print("Only host can start the game")
		return
	
	# Send difficulty setting to all clients before starting
	_sync_difficulty.rpc(Global.current_difficulty)
	_notify_game_start.rpc()
	get_tree().change_scene_to_file("res://main.tscn")

@rpc("authority", "call_local", "reliable")
func _notify_game_start():
	get_tree().change_scene_to_file("res://main.tscn")

@rpc("authority", "call_local", "reliable")
func _sync_difficulty(difficulty: int):
	Global.current_difficulty = difficulty

func disconnect_from_game():
	multiplayer.multiplayer_peer = null
	is_multiplayer_game = false
	connected_players.clear()

func get_player_count():
	return connected_players.size()

func is_all_players_ready():
	if connected_players.size() < 2:
		return false
	
	for player in connected_players.values():
		if not player.get("ready", false):
			return false
	return true

func get_local_ip_address():
	var addresses = IP.get_local_addresses()
	for address in addresses:
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "Unable to determine IP"

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	connected_players[id] = {"ready": false, "is_host": false}
	player_connected.emit(id)
	
	if is_host:
		_sync_player_list.rpc()
		if connected_players.size() == MAX_PLAYERS:
			lobby_ready.emit()

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	connected_players.erase(id)
	player_disconnected.emit(id)
	
	if is_host:
		_sync_player_list.rpc()

func _on_connected_to_server():
	print("Connected to server successfully")
	local_player_id = multiplayer.get_unique_id()
	connected_players[local_player_id] = {"ready": true, "is_host": false}
	connected_to_server.emit()

func _on_connection_failed():
	print("Failed to connect to server")
	connection_failed.emit()
	disconnect_from_game()

func _on_server_disconnected():
	print("Server disconnected")
	server_disconnected.emit()
	disconnect_from_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

@rpc("authority", "call_local", "reliable")
func _sync_player_list():
	pass

func get_player_ids():
	return connected_players.keys()

func get_other_player_id():
	for id in connected_players.keys():
		if id != local_player_id:
			return id
	return -1