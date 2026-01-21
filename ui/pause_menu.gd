extends Control

func _ready() -> void:
	# Hide initially
	visible = false
	
	# Connect buttons
	$CenterContainer/Panel/MarginContainer/VBoxContainer/ResumeButton.pressed.connect(resume)
	$CenterContainer/Panel/MarginContainer/VBoxContainer/MainMenuButton.pressed.connect(quit_to_menu)
	$CenterContainer/Panel/MarginContainer/VBoxContainer/QuitButton.pressed.connect(quit_game)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true

func resume() -> void:
	visible = false
	get_tree().paused = false

func quit_to_menu() -> void:
	resume() # Unpause first
	# Save game before quitting (optional but good practice, usually handled by world)
	var world = get_tree().current_scene
	if world.has_method("_save_and_quit"):
		# We don't want to quit the app, just save.
		# world.gd has _save_and_quit which quits tree.
		# world.gd has _return_to_menu which saves and changes scene.
		world._return_to_menu()
	else:
		# Fallback
		get_tree().change_scene_to_file("res://scenes/start_menu/start_menu.tscn")

func quit_game() -> void:
	resume() # Unpause first
	var world = get_tree().current_scene
	if world.has_method("_save_and_quit"):
		world._save_and_quit()
	else:
		get_tree().quit()
