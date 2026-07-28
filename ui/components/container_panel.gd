extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 230.0

@onready var panel: NinePatchRect = $Panel
@onready var container_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/TitleLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/CloseButton
@onready var sort_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/SortButton

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var current_container: ContainerInventory = null
var source_building: Node2D = null
var is_open: bool = false
var _tween: Tween
var _game_ui: GameUI

func _ready() -> void:
	add_to_group("container_panel")
	# Initial state: Hidden behind inventory (or offscreen)
	# We want it to slide out to the left of the inventory panel.
	# Inventory panel is at [-230, 0] when open.
	# So we want to end up at [-460, -230].
	# Start position: [-230, 0] (Hidden behind inventory)
	panel.offset_left = -PANEL_WIDTH
	panel.offset_right = 0.0

	visible = false # Hide initially
	close_button.pressed.connect(close)
	sort_button.pressed.connect(_on_sort_pressed)
	_game_ui = get_parent() as GameUI

func _on_sort_pressed() -> void:
	if current_container:
		current_container.sort_inventory()

func open(container: ContainerInventory, title: String = "Container", building: Node2D = null) -> void:
	if container == null:
		return

	current_container = container
	source_building = building
	title_label.text = title.to_upper()

	_populate_container_slots()

	visible = true
	is_open = true

	if _game_ui:
		_game_ui.set_modal_presentation(true, SLIDE_DURATION * 0.5)
	else:
		push_warning("ContainerPanel: GameUI parent was not found.")

	# Animate slide out to the left
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)

	# Slide to [-456, -226] (Overlap by 4px with inventory at -230)
	# Panel Width is 230.
	# Inventory Left is -230.
	# We want Container Right to be -226.
	# So Container Left = -226 - 230 = -456.
	var overlap_offset = 4.0
	var target_right = -PANEL_WIDTH + overlap_offset
	var target_left = target_right - PANEL_WIDTH

	_tween.tween_property(panel, "offset_left", target_left, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", target_right, SLIDE_DURATION)

	# Also ensure Inventory Panel is open
	var inventory_panel = get_tree().get_first_node_in_group("inventory_panel")
	if not inventory_panel:
		# Fallback: try to find it in parent (UI)
		inventory_panel = get_parent().get_node_or_null("InventoryPanel")

	if inventory_panel and inventory_panel.has_method("open"):
		if not inventory_panel.is_open:
			inventory_panel.open()

func close() -> void:
	if not is_open: return
	is_open = false
	current_container = null

	if source_building and source_building.has_method("on_ui_closed"):
		source_building.on_ui_closed()
	source_building = null

	# Return any held item to player inventory
	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()

	if _game_ui:
		_game_ui.set_modal_presentation(false, SLIDE_DURATION * 0.5)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)

	# Slide back to [-230, 0]
	_tween.tween_property(panel, "offset_left", -PANEL_WIDTH, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", 0.0, SLIDE_DURATION)
	_tween.tween_callback(func(): visible = false)

func _populate_container_slots() -> void:
	# Clear existing
	for child in container_grid.get_children():
		child.queue_free()

	if current_container == null:
		return

	for i in range(current_container.slot_count):
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = i
		slot.target_inventory = current_container # Bind to container
		container_grid.add_child(slot)

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("toggle_inventory"):
		close()
		# Note: We don't consume the event here so InventoryPanel can also close if it wants to
