extends TextureRect

signal slot_clicked(index: int)
signal slot_hovered(index: int)

@export var slot_index: int = 0

@onready var item_icon: TextureRect = $ItemIcon
@onready var stack_label: Label = $StackCount

# Preload resources - make sure these paths match your created resources
var _normal_texture = preload("res://ui/resources/atlas/slot_normal.tres")
var _selected_texture = preload("res://ui/resources/atlas/slot_selected.tres")
var _hover_texture = preload("res://ui/resources/atlas/slot_hover.tres")

var _is_selected: bool = false
var _is_hovered: bool = false

func _ready() -> void:
	texture = _normal_texture
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_update_texture()

func _update_texture() -> void:
	# Priority: Selected > Hovered > Normal
	# User Request: "if a slot is hovered and selected just display the selected texture"
	if _is_selected:
		texture = _selected_texture
	elif _is_hovered:
		texture = _hover_texture
	else:
		texture = _normal_texture

func set_item(item_texture: Texture2D, count: int = 0) -> void:
	if item_texture:
		item_icon.texture = item_texture
		item_icon.visible = true
	else:
		item_icon.texture = null
		item_icon.visible = false
		
	if count > 1:
		stack_label.text = str(count)
		stack_label.visible = true
	else:
		stack_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)
		# Right click ignored as requested

func _on_mouse_entered() -> void:
	_is_hovered = true
	slot_hovered.emit(slot_index)
	_update_texture()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_texture()
