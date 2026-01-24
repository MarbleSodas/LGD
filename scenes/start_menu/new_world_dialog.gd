extends Control

signal confirmed(world_name: String)
signal cancelled

@onready var name_input = $VBoxContainer/NameInput
@onready var create_button = $VBoxContainer/HBoxContainer/CreateButton
@onready var cancel_button = $VBoxContainer/HBoxContainer/CancelButton

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Close on background click (optional, but good UX)
	# $Bg.gui_input.connect(_on_bg_input)

func show_dialog() -> void:
	name_input.text = ""
	show()
	name_input.grab_focus()

func _on_create_pressed() -> void:
	var world_name = name_input.text.strip_edges()
	if world_name.is_empty():
		return
		
	confirmed.emit(world_name)
	hide()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_accept"):
		if name_input.has_focus():
			accept_event()
			_on_create_pressed()
	elif event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_cancel_pressed()
