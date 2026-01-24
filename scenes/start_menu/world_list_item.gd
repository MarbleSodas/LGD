extends Control

signal load_requested(world_id: String)
signal delete_requested(world_id: String, world_name: String)

var world_id: String = ""
var world_name: String = ""

@onready var name_label = $MarginContainer/HBoxContainer/VBoxContainer/WorldName
@onready var date_label = $MarginContainer/HBoxContainer/VBoxContainer/LastPlayed
@onready var delete_btn = $MarginContainer/HBoxContainer/DeleteButton

func setup(data: Dictionary) -> void:
	world_id = data["id"]
	world_name = data["name"]
	
	name_label.text = world_name
	
	# Format date
	var date_str = data["last_played"]
	if "T" in date_str:
		date_label.text = "Last played: " + date_str.split("T")[0]
	else:
		date_label.text = "Last played: " + date_str

func _ready() -> void:
	# Connect signals
	gui_input.connect(_on_gui_input)
	delete_btn.pressed.connect(_on_delete_pressed)
	
	# Enforce mouse filter to ensure button consumes events
	delete_btn.mouse_filter = MouseFilter.MOUSE_FILTER_STOP

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Safety check: if the click happened over the delete button, ignore it here
		# (This handles edge cases where the event might propagate or if user clicks passing through)
		if delete_btn.is_visible_in_tree() and delete_btn.get_global_rect().has_point(get_global_mouse_position()):
			return
			
		load_requested.emit(world_id)

func _on_delete_pressed() -> void:
	delete_requested.emit(world_id, world_name)
