@tool
extends Node2D

const TREE_RES = preload("res://resources/buildables/tree.tres")
const MUSHROOM_RES = preload("res://resources/buildables/mushroom_plant.tres")
const STONE_RES = preload("res://resources/buildables/stone_deposit.tres")
const INTRO_DIALOGUE_RES = preload("res://resources/dialogues/intro_awakening.tres")

const AUTO_SAVE_INTERVAL: float = 60.0
const NODE_UI: String = "UI"
const GROUP_UI_LAYER: String = "ui_layer"
const SCENE_START_MENU: String = "res://scenes/start_menu/start_menu.tscn"

# Starter resource positions (tile coordinates)
@export var starter_trees: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(18, 3),
	Vector2i(3, 15),
	Vector2i(16, 14),
	Vector2i(10, 9)
]:
	set(value):
		starter_trees = value
		queue_redraw()

@export var starter_mushrooms: Array[Vector2i] = [
	Vector2i(12, 10),
	Vector2i(2, 6),
	Vector2i(14, 1)
]:
	set(value):
		starter_mushrooms = value
		queue_redraw()

@export var starter_stone_deposits: Array[Vector2i] = [
	Vector2i(8, 5),
	Vector2i(15, 12),
	Vector2i(4, 10)
]:
	set(value):
		starter_stone_deposits = value
		queue_redraw()

var auto_save_timer: Timer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
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
		call_deferred("_play_intro")
		
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
	for tile_coords in starter_trees:
		planting_system.plant_item_at(tile_coords, "tree")
	
	# Spawn mushrooms
	for tile_coords in starter_mushrooms:
		planting_system.plant_item_at(tile_coords, "mushroom_plant") 
		
	# Spawn stone deposits
	for tile_coords in starter_stone_deposits:
		planting_system.plant_item_at(tile_coords, "stone_deposit") 

func _play_intro() -> void:
	var ui_layer: Node = _get_ui_layer()
	if not ui_layer:
		push_error("UI layer not found, cannot play intro")
		return
	
	var overlay: Control = ui_layer.get_node_or_null("IntroFadeOverlay")
	if not overlay:
		push_error("IntroFadeOverlay not found in UI layer")
		return
	
	# Start with full opacity
	overlay.visible = true
	overlay.modulate.a = 1.0
	
	# Fade out over 1.5 seconds
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 1.5)
	
	# Start dialogue when fade completes
	tween.finished.connect(func():
		DialogueManager.start_dialogue(INTRO_DIALOGUE_RES)
	)
	
	# Hide overlay when dialogue finishes
	DialogueManager.dialogue_finished.connect(func():
		overlay.visible = false
	, CONNECT_ONE_SHOT) 

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_and_quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		var res = load("res://resources/dialogues/test_dialogue.tres")
		if res and DialogueManager:
			DialogueManager.start_dialogue(res)

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
	# 0. Highest Priority: Dialogue
	if DialogueManager and DialogueManager.is_active():
		DialogueManager.close_dialogue()
		return true

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

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Default tile size (32x32) as in PlantingSystem
	var tile_size = Vector2(32, 32)
	
	_draw_resources(starter_trees, TREE_RES, tile_size)
	_draw_resources(starter_mushrooms, MUSHROOM_RES, tile_size)
	_draw_resources(starter_stone_deposits, STONE_RES, tile_size)

func _draw_resources(coords_list: Array[Vector2i], item: Resource, tile_size: Vector2) -> void:
	if not item or not item.preview_texture:
		return
		
	var tex = item.preview_texture
	var hframes = item.preview_hframes if "preview_hframes" in item else 1
	var frame = item.preview_frame if "preview_frame" in item else 0
	var offset = item.placement_offset if "placement_offset" in item else Vector2.ZERO
	var preview_offset = item.preview_offset if "preview_offset" in item else Vector2.ZERO
	
	var frame_w = float(tex.get_width()) / float(hframes)
	var frame_h = float(tex.get_height())
	
	var src_rect = Rect2(frame * frame_w, 0, frame_w, frame_h)
	
	for coords in coords_list:
		# Map center
		var pos = Vector2(coords) * tile_size + (tile_size / 2.0)
		
		# Center texture on pos, apply offsets
		var dest_pos = pos + offset + preview_offset - Vector2(frame_w / 2.0, frame_h / 2.0)
		
		draw_texture_rect_region(tex, Rect2(dest_pos, Vector2(frame_w, frame_h)), src_rect, Color(1, 1, 1, 0.8))
