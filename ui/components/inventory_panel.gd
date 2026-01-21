extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 230.0

@onready var panel: NinePatchRect = $Panel
@onready var grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var sort_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/SortButton
@onready var cursor_preview: TextureRect = $HeldItemCursor
@onready var cursor_label: Label = $HeldItemCursor/CountLabel

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var is_open: bool = false
var _tween: Tween

func _ready() -> void:
	add_to_group("inventory_panel")
	# Initial state: Closed (Off-screen right)
	panel.offset_left = 0
	panel.offset_right = PANEL_WIDTH
	
	_populate_slots()
	
	if Inventory:
		Inventory.slots_expanded.connect(_on_slots_expanded)
		Inventory.held_item_changed.connect(_on_held_item_changed)
		
		# specific check in case we reloaded scene while holding something
		var held = Inventory.get_held_item()
		if held.has("item") and held.item != null:
			_on_held_item_changed(held.item, held.count)
	
	sort_button.pressed.connect(_on_sort_pressed)
	
	cursor_preview.visible = false
	cursor_preview.size = Vector2(48, 48) # Match slot size
	cursor_preview.z_index = 100 # Ensure cursor is always on top of other UI panels
	cursor_preview.top_level = true # Render independently from parent hierarchy
	mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if cursor_preview.visible:
		cursor_preview.global_position = get_global_mouse_position() - (cursor_preview.size / 2.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if Inventory and Inventory.is_holding_item():
			Inventory.return_held_item()
		toggle()

func _gui_input(event: InputEvent) -> void:
	# Detect clicks outside the panel when holding an item to return it
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Inventory and Inventory.is_holding_item():
			var global_mouse = get_global_mouse_position()
			if not panel.get_global_rect().has_point(global_mouse):
				Inventory.return_held_item()
				get_viewport().set_input_as_handled()

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
	
	# Force return held item when closing
	if Inventory:
		Inventory.return_held_item()
	
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
	# slot_clicked signal is no longer needed as slots handle their own input

func _on_slots_expanded(new_max: int) -> void:
	# Add new slots when inventory expands
	var current_count = grid.get_child_count()
	for i in range(current_count, new_max):
		_add_slot(i)

func _on_held_item_changed(item: InventoryItem, count: int) -> void:
	if item and count > 0:
		cursor_preview.texture = item.icon
		cursor_label.text = str(count)
		cursor_label.visible = count > 1
		cursor_preview.visible = true
		cursor_preview.global_position = get_global_mouse_position() - (cursor_preview.size / 2.0)
		
		# Block mouse clicks to the world while holding an item
		mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	else:
		cursor_preview.visible = false
		# Let mouse clicks pass through to the world when not holding anything
		mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE

func _on_sort_pressed() -> void:
	if Inventory:
		Inventory.sort_inventory()
