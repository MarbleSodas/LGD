extends Node2D

const AUTO_SAVE_INTERVAL: float = 60.0
const NODE_UI: String = "UI"
const GROUP_UI_LAYER: String = "ui_layer"
const SCENE_START_MENU: String = "res://scenes/start_menu/start_menu.tscn"

# Starter resource positions (tile coordinates)
const STARTER_TREES: Array = [
	Vector2i(2, 2),
	Vector2i(18, 3),
	Vector2i(3, 15),
	Vector2i(16, 14),
	Vector2i(10, 9)
]
const STARTER_MUSHROOMS: Array = [
	Vector2i(12, 10),
	Vector2i(2, 6),
	Vector2i(14, 1)
]

var auto_save_timer: Timer

func _ready() -> void:
	var is_new_world: bool = true
	
	# Load game data if we have a current world
	if GameState.current_world_id != "":
		is_new_world = not SaveManager.load_game(GameState.current_world_id)
		print("Loaded world: ", GameState.current_world_name)
	else:
		print("No world context (playtest mode?)")
	
	# Spawn starter resources for new worlds (deferred to ensure PlantingSystem is ready)
	if is_new_world:
		call_deferred("_spawn_starter_resources")
		
	# Setup auto-save
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(_on_auto_save)
	add_child(auto_save_timer)
	
	# Connect quit notification
	get_tree().set_auto_accept_quit(false) 

func _spawn_starter_resources() -> void:
	var planting_system: PlantingSystem = $PlantingSystem
	if not planting_system:
		push_error("PlantingSystem not found, cannot spawn starter resources")
		return
	
	# Spawn trees
	for tile_coords in STARTER_TREES:
		planting_system.plant_item_at(tile_coords, "tree")
	
	# Spawn mushrooms
	for tile_coords in STARTER_MUSHROOMS:
		planting_system.plant_item_at(tile_coords, "mushroom_plant") 

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_and_quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _close_any_open_ui():
			get_viewport().set_input_as_handled()
			return
			
		# Toggle Pause Menu
		var ui_layer: Node = _get_ui_layer()
		if ui_layer:
			var pause_menu: Control = ui_layer.get_node_or_null("PauseMenu")
			if pause_menu and not pause_menu.visible:
				pause_menu.open()
				get_viewport().set_input_as_handled()

func _close_any_open_ui() -> bool:
	# 1. High Priority: Return held item (Global action)
	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()
		return true

	var ui_layer: Node = _get_ui_layer()
	if ui_layer:
		# 2. Container Panel (Topmost UI)
		var container: Control = ui_layer.get_node_or_null("ContainerPanel")
		if container and container.get("is_open"):
			container.close()
			return true

		# Processor Menu
		var processor_menu: Control = ui_layer.get_node_or_null("ProcessorMenu")
		if processor_menu and processor_menu.get("is_open"):
			processor_menu.close()
			return true
			
		# 3. Rat Manager Panel
		var rat_panel: Control = ui_layer.get_node_or_null("RatManagerPanel")
		if rat_panel and rat_panel.visible:
			rat_panel.close()
			return true
			
	return false

func _get_ui_layer() -> Node:
	# 1. Try direct child
	var ui: Node = get_node_or_null(NODE_UI)
	if ui: return ui
	
	# 2. Try group
	return get_tree().get_first_node_in_group(GROUP_UI_LAYER)

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
	get_tree().change_scene_to_file(SCENE_START_MENU)
