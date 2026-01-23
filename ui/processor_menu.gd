extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 230.0

@onready var panel: NinePatchRect = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/CloseButton
@onready var input_slot_container: Control = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/InputSlotContainer
@onready var output_slot_container: Control = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/OutputSlotContainer
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/ProgressBar

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var input_inventory: ContainerInventory
var output_inventory: ContainerInventory
var current_building: Node2D = null
var is_open: bool = false
var _tween: Tween

func _ready() -> void:
	add_to_group("processor_menu")
	
	# Initial state: Hidden behind inventory
	panel.offset_left = -PANEL_WIDTH
	panel.offset_right = 0.0
	visible = false
	
	close_button.pressed.connect(close)

func _process(_delta: float) -> void:
	if is_open and is_instance_valid(current_building):
		if current_building.has_method("get_processing_progress"):
			progress_bar.value = current_building.get_processing_progress() * 100.0

func open(p_input_inventory: ContainerInventory, p_output_inventory: ContainerInventory, building: Node2D) -> void:
	input_inventory = p_input_inventory
	output_inventory = p_output_inventory
	current_building = building
	
	_setup_slots()
	
	visible = true
	is_open = true
	
	# Animate slide out
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	
	# Slide to the left of inventory
	var overlap_offset = 4.0
	var target_right = -PANEL_WIDTH + overlap_offset
	var target_left = target_right - PANEL_WIDTH
	
	_tween.tween_property(panel, "offset_left", target_left, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", target_right, SLIDE_DURATION)
	
	# Ensure Inventory Panel is open
	var inventory_panel = get_tree().get_first_node_in_group("inventory_panel")
	if not inventory_panel:
		inventory_panel = get_parent().get_node_or_null("InventoryPanel")
		
	if inventory_panel and inventory_panel.has_method("open"):
		if not inventory_panel.is_open:
			inventory_panel.open()

func close() -> void:
	if not is_open: return
	is_open = false
	current_building = null
	
	# Return held item if any
	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	
	_tween.tween_property(panel, "offset_left", -PANEL_WIDTH, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", 0.0, SLIDE_DURATION)
	_tween.tween_callback(func(): visible = false)

func _setup_slots() -> void:
	# clear existing
	for child in input_slot_container.get_children():
		child.queue_free()
	for child in output_slot_container.get_children():
		child.queue_free()
	
	if input_inventory:
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = 0
		slot.target_inventory = input_inventory
		input_slot_container.add_child(slot)
		
	if output_inventory:
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = 0
		slot.target_inventory = output_inventory
		output_slot_container.add_child(slot)

func _input(event: InputEvent) -> void:
	if not is_open:
		return
		
	if event.is_action_pressed("toggle_inventory"):
		close()
