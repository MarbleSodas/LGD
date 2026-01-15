extends CanvasLayer

# Preloads
const WORLD_ITEM_SCENE = preload("res://scenes/start_menu/world_list_item.tscn")
const WORLD_SCENE_PATH = "res://world.tscn"

# Nodes
@onready var world_container = $Control/Panel/MarginContainer/VBoxContainer/ScrollContainer/WorldList
@onready var new_world_dialog = $Control/NewWorldDialog
@onready var name_input = $Control/NewWorldDialog/VBoxContainer/NameInput
@onready var delete_confirm_dialog = $Control/DeleteConfirmDialog
@onready var confirm_label = $Control/DeleteConfirmDialog/VBoxContainer/Label

# State
var world_to_delete_id: String = ""

func _ready() -> void:
	$Control/NewWorldDialog.hide()
	$Control/DeleteConfirmDialog.hide()
	
	# Connect top-level buttons
	$Control/Panel/MarginContainer/VBoxContainer/Header/CloseButton.pressed.connect(hide)
	$Control/Panel/MarginContainer/VBoxContainer/Footer/NewWorldButton.pressed.connect(_on_new_world_pressed)
	
	# Connect dialog buttons
	$Control/NewWorldDialog/VBoxContainer/HBoxContainer/CancelButton.pressed.connect(func(): new_world_dialog.hide())
	$Control/NewWorldDialog/VBoxContainer/HBoxContainer/CreateButton.pressed.connect(_on_create_confirmed)
	
	$Control/DeleteConfirmDialog/VBoxContainer/HBoxContainer/CancelButton.pressed.connect(func(): delete_confirm_dialog.hide())
	$Control/DeleteConfirmDialog/VBoxContainer/HBoxContainer/DeleteButton.pressed.connect(_on_delete_confirmed)

func refresh_list() -> void:
	# Clear existing
	for child in world_container.get_children():
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
	name_input.text = ""
	new_world_dialog.show()
	name_input.grab_focus()

func _on_create_confirmed() -> void:
	var name = name_input.text.strip_edges()
	if name.is_empty():
		return
		
	if name.length() > 20:
		name = name.substr(0, 20)
		
	var id = SaveManager.create_world(name)
	if id != "":
		new_world_dialog.hide()
		_on_load_world(id)
	else:
		# Show error?
		pass

func _on_load_world(world_id: String) -> void:
	# Load world
	GameState.set_current_world(world_id, "Loading...") # We could fetch name
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_delete_request(world_id: String, world_name: String) -> void:
	world_to_delete_id = world_id
	confirm_label.text = "Delete '%s'?\nThis cannot be undone." % world_name
	delete_confirm_dialog.show()

func _on_delete_confirmed() -> void:
	if world_to_delete_id != "":
		SaveManager.delete_world(world_to_delete_id)
		world_to_delete_id = ""
		delete_confirm_dialog.hide()
		refresh_list()
