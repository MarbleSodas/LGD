extends Node2D

const AUTO_SAVE_INTERVAL = 60.0

var auto_save_timer: Timer

func _ready() -> void:
	# Load game data if we have a current world
	if GameState.current_world_id != "":
		SaveManager.load_game(GameState.current_world_id)
		print("Loaded world: ", GameState.current_world_name)
	else:
		print("No world context (playtest mode?)")
		
	# Setup auto-save
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(_on_auto_save)
	add_child(auto_save_timer)
	
	# Connect quit notification
	get_tree().set_auto_accept_quit(false) # We'll handle it manually if needed, or just hook notification

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_and_quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()

func _on_auto_save() -> void:
	if GameState.current_world_id != "":
		SaveManager.save_game(GameState.current_world_id)
		print("Auto-saved world")

func _save_and_quit() -> void:
	if GameState.current_world_id != "":
		SaveManager.save_game(GameState.current_world_id)
	get_tree().quit()

func _return_to_menu() -> void:
	if GameState.current_world_id != "":
		SaveManager.save_game(GameState.current_world_id)
	
	GameState.clear_current_world()
	get_tree().change_scene_to_file("res://scenes/start_menu/start_menu.tscn")
