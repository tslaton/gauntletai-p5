extends Control

signal retry_pressed
signal quit_pressed

func _ready():
	visible = false
	$Panel/VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func show_game_over():
	visible = true
	get_tree().paused = true
	# Make sure the UI can process input while paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _on_retry_pressed():
	get_tree().paused = false
	emit_signal("retry_pressed")
	visible = false

func _on_quit_pressed():
	emit_signal("quit_pressed")
	get_tree().quit()