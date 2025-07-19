extends Control

signal retry_pressed
signal quit_pressed

func _ready():
	visible = false
	$Panel/VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func show_game_over():
	print("Game Over UI - show_game_over() called")
	visible = true
	get_tree().paused = true
	# Make sure the UI can process input while paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Hide retry button for non-host players in multiplayer
	if NetworkManager.is_multiplayer_game and not NetworkManager.is_host:
		$Panel/VBoxContainer/RetryButton.visible = false
		# Change quit button text to be clearer
		$Panel/VBoxContainer/QuitButton.text = "Leave Game"
	else:
		$Panel/VBoxContainer/RetryButton.visible = true
		$Panel/VBoxContainer/QuitButton.text = "Quit"
	
	print("Game Over UI visible: ", visible, " paused: ", get_tree().paused)

func _on_retry_pressed():
	get_tree().paused = false
	emit_signal("retry_pressed")
	visible = false
	
func hide_game_over():
	visible = false
	get_tree().paused = false

func _on_quit_pressed():
	emit_signal("quit_pressed")
	# Don't quit directly - let main.gd handle it based on multiplayer state
