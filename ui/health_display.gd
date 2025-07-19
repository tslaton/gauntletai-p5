extends Control

@onready var health_label = $HealthLabel
var player: Node3D
var tracked_player_id: int = -1

func _ready():
	# Find the player node - in multiplayer, we'll set this later
	if not NetworkManager.is_multiplayer_game:
		player = get_tree().get_first_node_in_group("Player")
		if player:
			setup_player_connection()

func set_tracked_player(player_node: Node3D, player_id: int):
	player = player_node
	tracked_player_id = player_id
	setup_player_connection()

func setup_player_connection():
	if player:
		player.health_changed.connect(_on_health_changed)
		# Get initial health
		if player.has_method("get_health_info"):
			var health_info = player.get_health_info()
			_on_health_changed(health_info.current, health_info.max)
		else:
			_on_health_changed(player.current_health, player.max_health)

func _on_health_changed(current: int, maximum: int):
	# In multiplayer, show player number
	if NetworkManager.is_multiplayer_game and tracked_player_id > 0:
		var player_num = 1 if tracked_player_id == NetworkManager.local_player_id else 2
		health_label.text = "P%d Health: %d/%d" % [player_num, current, maximum]
	else:
		health_label.text = "Health: %d/%d" % [current, maximum]
	
	# Change color based on health percentage
	var health_percentage = float(current) / float(maximum)
	if health_percentage > 0.6:
		health_label.modulate = Color.GREEN
	elif health_percentage > 0.3:
		health_label.modulate = Color.YELLOW
	else:
		health_label.modulate = Color.RED