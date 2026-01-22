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
		if _close_any_open_ui():
			get_viewport().set_input_as_handled()
			return
			
		# Toggle Pause Menu
		var ui_layer = get_node_or_null("UI") # Assuming UI is a child named "UI"
		if not ui_layer:
			# Try to find it in the scene tree if not a direct child
			ui_layer = get_tree().get_first_node_in_group("ui_layer")
			
		if ui_layer:
			var pause_menu = ui_layer.get_node_or_null("PauseMenu")
			if pause_menu and not pause_menu.visible:
				pause_menu.open()
				get_viewport().set_input_as_handled()

func _close_any_open_ui() -> bool:
	# 1. High Priority: Return held item (Global action)
	# Check if Inventory singleton exists and has items
	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()
		return true

	var ui_layer = get_node_or_null("UI") # Assuming UI is a child named "UI"
	if not ui_layer:
		# Try to find it in the scene tree if not a direct child
		ui_layer = get_tree().get_first_node_in_group("ui_layer")
	
	if ui_layer:
		# 2. Container Panel (Topmost UI)
		var container = ui_layer.get_node_or_null("ContainerPanel")
		if container and container.get("is_open"):
			container.close()
			return true
			
		# 3. Rat Manager Panel
		var rat_panel = ui_layer.get_node_or_null("RatManagerPanel")
		if rat_panel and rat_panel.visible:
			rat_panel.close()
			return true
			
	return false


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
