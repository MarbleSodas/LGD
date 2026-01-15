extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 230.0

@onready var panel: NinePatchRect = $Panel
@onready var grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var is_open: bool = false
var _tween: Tween

func _ready() -> void:
	# Initial state: Closed (Off-screen right)
	# Since anchors are set to right (1.0), offsets 0 to 230 places it just outside the right edge
	panel.offset_left = 0
	panel.offset_right = PANEL_WIDTH
	
	_populate_slots()
	
	# Connect to inventory expansion
	if Inventory:
		Inventory.slots_expanded.connect(_on_slots_expanded)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
	elif event.is_action_pressed("ui_cancel") and is_open:
		close()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open: return
	is_open = true
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	# Slide in: Left edge becomes -230 (width), Right edge becomes 0 (screen edge)
	_tween.tween_property(panel, "offset_left", -PANEL_WIDTH, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", 0.0, SLIDE_DURATION)

func close() -> void:
	if not is_open: return
	is_open = false
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	# Slide out: Left edge becomes 0 (screen edge), Right edge becomes 230 (width)
	_tween.tween_property(panel, "offset_left", 0.0, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", PANEL_WIDTH, SLIDE_DURATION)

func _populate_slots() -> void:
	# Clear existing slots
	for child in grid.get_children():
		child.queue_free()
	
	# Create slots based on inventory capacity
	var slot_count = Inventory.get_slot_count() if Inventory else 20
	for i in range(slot_count):
		_add_slot(i)

func _add_slot(index: int) -> void:
	var slot = InventorySlotScene.instantiate()
	grid.add_child(slot)
	slot.slot_index = index
	slot.slot_clicked.connect(_on_slot_clicked)

func _on_slot_clicked(index: int) -> void:
	# For now, just print the slot clicked
	# Future: implement item selection, drag-drop, etc.
	print("Inventory slot clicked: ", index)

func _on_slots_expanded(new_max: int) -> void:
	# Add new slots when inventory expands
	var current_count = grid.get_child_count()
	for i in range(current_count, new_max):
		_add_slot(i)
