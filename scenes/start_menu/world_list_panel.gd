extends CanvasLayer

# Preloads
const WORLD_ITEM_SCENE = preload("res://scenes/start_menu/world_list_item.tscn")
const WORLD_SCENE_PATH = "res://world.tscn"

# Nodes
@onready var world_container = $Control/Panel/MarginContainer/VBoxContainer/ScrollContainer/WorldList
@onready var new_world_dialog = $Control/NewWorldDialog
@onready var delete_confirm_dialog = $Control/DeleteConfirmDialog

# State
var world_to_delete_id: String = ""

func _ready() -> void:
	new_world_dialog.hide()
	# DeleteConfirmDialog hides itself on ready
	
	# Connect top-level buttons
	$Control/Panel/MarginContainer/VBoxContainer/Header/CloseButton.pressed.connect(hide)
	$Control/Panel/MarginContainer/VBoxContainer/Footer/NewWorldButton.pressed.connect(_on_new_world_pressed)
	
	# Connect dialog signals
	new_world_dialog.confirmed.connect(_on_create_confirmed)
	
	# Connect Delete Dialog signals
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	delete_confirm_dialog.cancelled.connect(func(): world_to_delete_id = "")

func refresh_list() -> void:
	# Clear existing - Use remove_child to instantly detach from tree before freeing
	for child in world_container.get_children():
		world_container.remove_child(child)
		child.queue_free()
		
	# Fetch worlds
	var worlds = SaveManager.get_all_worlds()
	
	# Create items
	for data in worlds:
		var item = WORLD_ITEM_SCENE.instantiate()
		world_container.add_child(item)
		item.setup(data)
		item.load_requested.connect(_on_load_world)
		item.delete_requested.connect(_on_delete_request)
		
	# Check limit for New World button
	var new_btn = $Control/Panel/MarginContainer/VBoxContainer/Footer/NewWorldButton
	new_btn.disabled = (worlds.size() >= 10)
	if new_btn.disabled:
		new_btn.modulate = Color(0.5, 0.5, 0.5) # Dim it
	else:
		new_btn.modulate = Color(1, 1, 1)

func _on_new_world_pressed() -> void:
	new_world_dialog.show_dialog()

func _on_create_confirmed(world_name: String) -> void:
	if world_name.length() > 20:
		world_name = world_name.substr(0, 20)
		
	var id = SaveManager.create_world(world_name)
	if id != "":
		_on_load_world(id)
	else:
		pass

func _on_load_world(world_id: String) -> void:
	# Load world
	GameState.set_current_world(world_id, "Loading...")
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_delete_request(world_id: String, world_name: String) -> void:
	world_to_delete_id = world_id
	delete_confirm_dialog.show_confirm("Delete '%s'?\nThis cannot be undone." % world_name)

func _on_delete_confirmed() -> void:
	if world_to_delete_id != "":
		SaveManager.delete_world(world_to_delete_id)
		world_to_delete_id = ""
		refresh_list()
