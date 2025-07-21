extends Control

signal replay_pressed
signal quit_pressed

func _ready():
	visible = false
	$Panel/VBoxContainer/ReplayButton.pressed.connect(_on_replay_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func show_victory():
	visible = true
	get_tree().paused = true
	# Make sure the UI can process input while paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Hide replay button for non-host players in multiplayer
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		$Panel/VBoxContainer/ReplayButton.visible = false
		# Change quit button text to be clearer
		$Panel/VBoxContainer/QuitButton.text = "Leave Game"
	else:
		$Panel/VBoxContainer/ReplayButton.visible = true
		$Panel/VBoxContainer/QuitButton.text = "Quit"

func _on_replay_pressed():
	get_tree().paused = false
	emit_signal("replay_pressed")
	visible = false
	
func hide_victory():
	visible = false
	get_tree().paused = false

func _on_quit_pressed():
	emit_signal("quit_pressed")
	# Don't quit directly - let main.gd handle it based on multiplayer state