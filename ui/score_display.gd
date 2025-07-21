extends Control

@onready var score_label = $ScoreLabel
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
		player.score_changed.connect(_on_score_changed)
		# Get initial score
		_on_score_changed(player.score)

func _on_score_changed(new_score: int):
	# In multiplayer, show player number based on who is host
	if NetworkManager.is_multiplayer_game and tracked_player_id > 0:
		var player_num = 1 if tracked_player_id == 1 else 2
		score_label.text = "P%d Score: %d" % [player_num, new_score]
	else:
		score_label.text = "Score: %d" % [new_score]