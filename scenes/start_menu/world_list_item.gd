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
	
	# Format date nicely if possible, or just show raw string
	var date_str = data["last_played"]
	# Try to parse and reformat? For now, raw is okay-ish, or we can just say "Last played: ..."
	date_label.text = "Last played: " + date_str.split("T")[0] # Just the date part
	
	delete_btn.hide() # Hidden by default, show on hover

func _ready() -> void:
	# Connect signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	delete_btn.pressed.connect(_on_delete_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		load_requested.emit(world_id)

func _on_mouse_entered() -> void:
	delete_btn.show()

func _on_mouse_exited() -> void:
	# Keep shown if hovering the button itself? 
	# Actually, the button is inside the panel, so mouse_exited won't fire if we move to the button (child).
	# Wait, mouse_exited fires when leaving the control's rect. Moving to a child *inside* doesn't trigger exit.
	# So this is fine.
	delete_btn.hide()

func _on_delete_pressed() -> void:
	delete_requested.emit(world_id, world_name)
