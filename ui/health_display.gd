extends Control

@onready var health_label = $HealthLabel
var player: Node3D

func _ready():
	# Find the player node
	player = get_tree().get_first_node_in_group("Player")
	if player:
		player.health_changed.connect(_on_health_changed)
		# Get initial health
		if player.has_method("get_health_info"):
			var health_info = player.get_health_info()
			_on_health_changed(health_info.current, health_info.max)
		else:
			_on_health_changed(player.current_health, player.max_health)

func _on_health_changed(current: int, maximum: int):
	health_label.text = "Health: %d/%d" % [current, maximum]
	
	# Change color based on health percentage
	var health_percentage = float(current) / float(maximum)
	if health_percentage > 0.6:
		health_label.modulate = Color.GREEN
	elif health_percentage > 0.3:
		health_label.modulate = Color.YELLOW
	else:
		health_label.modulate = Color.RED