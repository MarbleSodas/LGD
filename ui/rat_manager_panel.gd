class_name RatManagerPanel
extends Control

## UI for configuring the Rat Assistant.
## Allows selecting source tiles and output storage directly.

const SLIDE_DURATION: float = 0.2
const OPEN_OFFSET_Y: float = 20.0
const CLOSED_OFFSET_Y: float = -200.0

var current_house: MushroomHouse = null
var is_dragging: bool = false
var drag_action: int = 0 # 0: None, 1: Add, -1: Remove
var _tween: Tween

@onready var panel: NinePatchRect = $Panel
@onready var sources_label: Label = $Panel/MarginContainer/VBoxContainer/SourcesLabel
@onready var output_label: Label = $Panel/MarginContainer/VBoxContainer/OutputLabel
@onready var btn_close: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	add_to_group("rat_manager_panel")
	# Initialize off-screen
	var height = panel.size.y
	panel.offset_top = CLOSED_OFFSET_Y
	panel.offset_bottom = CLOSED_OFFSET_Y + height

	btn_close.pressed.connect(close)

func _process(_delta: float) -> void:
	if not visible or not current_house: return

	# Update hover feedback
	# We need to map screen mouse to world position relative to the house's viewport/camera
	# But get_global_mouse_position() works in CanvasItem coordinates (World space for Node2D)
	var mouse_pos = current_house.get_global_mouse_position()
	if current_house.tile_map:
		var coords = current_house.tile_map.local_to_map(mouse_pos)
		current_house.update_hover(coords)

func open(house: MushroomHouse) -> void:
	# Close build menu if open
	var build_menu = get_tree().get_first_node_in_group("build_menu")
	if build_menu and build_menu.has_method("close"):
		build_menu.close()

	# Close inventory panel if open
	var inventory_panel = get_tree().get_first_node_in_group("inventory_panel")
	if inventory_panel and inventory_panel.has_method("close"):
		inventory_panel.close()

	# Close container panel if open
	var container_panel = get_tree().get_first_node_in_group("container_panel")
	if container_panel and container_panel.has_method("close"):
		container_panel.close()

	# Close processor menu if open
	var processor_menu = get_tree().get_first_node_in_group("processor_menu")
	if processor_menu and processor_menu.has_method("close"):
		processor_menu.close()

	# Disable planting/deletion modes
	if house.planting_system:
		house.planting_system.set_mode(PlantingSystem.Mode.NONE)

	current_house = house
	visible = true
	_update_ui()

	# Slide in
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	var height = panel.size.y
	_tween.tween_property(panel, "offset_top", OPEN_OFFSET_Y, SLIDE_DURATION)
	_tween.parallel().tween_property(panel, "offset_bottom", OPEN_OFFSET_Y + height, SLIDE_DURATION)

func close() -> void:
	# Check visibility to avoid double-closing
	if not visible and not _tween: return
	if _tween and _tween.is_running() and panel.offset_top < 0: return # Already closing

	if current_house:
		current_house.clear_hover()
		current_house.on_ui_closed()
	current_house = null

	# Slide out
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)

	var height = panel.size.y
	_tween.tween_property(panel, "offset_top", CLOSED_OFFSET_Y, SLIDE_DURATION)
	_tween.parallel().tween_property(panel, "offset_bottom", CLOSED_OFFSET_Y + height, SLIDE_DURATION)
	_tween.tween_callback(func(): visible = false)

func _update_ui() -> void:
	if not current_house: return

	sources_label.text = "Sources: %d / %d" % [current_house.get_source_count(), current_house.MAX_SOURCES]
	output_label.text = "Outputs: %s" % current_house.get_output_info()

func _input(event: InputEvent) -> void:
	if not visible or not current_house: return

	# If mouse is over the panel, ignore world interaction
	if event is InputEventMouse:
		if panel.get_global_rect().has_point(get_global_mouse_position()):
			return

	# Handle Right Click (Toggle Output)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(current_house.get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return

	# Handle Left Click (Sources)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			_init_drag_action(current_house.get_global_mouse_position())
			_handle_left_click(current_house.get_global_mouse_position())
			get_viewport().set_input_as_handled()
		else:
			is_dragging = false
			drag_action = 0

	elif event is InputEventMouseMotion and is_dragging:
		# Only allow drag painting if CTRL is held
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
			_handle_left_click(current_house.get_global_mouse_position())
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory") or event.is_action_pressed("harvest"):
		close()
		get_viewport().set_input_as_handled()

func _init_drag_action(global_pos: Vector2) -> void:
	if not current_house or not current_house.tile_map: return
	var coords = current_house.tile_map.local_to_map(global_pos)

	# Check if we should add or remove
	if coords in current_house.assigned_sources:
		drag_action = -1 # Remove
	else:
		drag_action = 1 # Add

func _handle_left_click(global_pos: Vector2) -> void:
	if not current_house or not current_house.tile_map: return

	var coords = current_house.tile_map.local_to_map(global_pos)

	if drag_action == 1:
		current_house.add_source(coords)
	elif drag_action == -1:
		current_house.remove_source(coords)

	_update_ui()

func _handle_right_click(global_pos: Vector2) -> void:
	if not current_house or not current_house.tile_map: return
	var coords = current_house.tile_map.local_to_map(global_pos)
	current_house.toggle_output(coords)
	_update_ui()
