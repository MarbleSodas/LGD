extends Control

## Emitted when inventory visibility changes
signal inventory_toggled(is_open: bool)
## Emitted when a slot is selected
signal slot_selected(index: int)

## Number of inventory slots (can be increased at runtime)
@export var slot_count: int = 20
## Number of columns in the grid
@export var columns: int = 4
## Size of each slot in pixels
@export var slot_size: int = 32
## Gap between slots
@export var slot_gap: int = 4
## Animation duration in seconds
@export var animation_duration: float = 0.2

var is_open: bool = false
var slots: Array[Panel] = []
var current_tween: Tween

@onready var slide_container: HBoxContainer = $Anchor/SlideContainer
@onready var toggle_button: Button = $Anchor/SlideContainer/ToggleButton
@onready var panel_container: PanelContainer = $Anchor/SlideContainer/PanelContainer
@onready var slot_grid: GridContainer = $Anchor/SlideContainer/PanelContainer/MarginContainer/VBoxContainer/SlotGrid

# StyleBoxFlat for selected slot
var selected_style: StyleBoxFlat


func _ready() -> void:
	_setup_styles()
	_setup_panel()
	_generate_slots()
	_update_toggle_button()
	
	toggle_button.pressed.connect(_on_toggle_button_pressed)


func _setup_styles() -> void:
	selected_style = StyleBoxFlat.new()
	selected_style.border_color = Color(1.0, 0.8, 0.0)  # Gold/yellow
	selected_style.border_width_left = 2
	selected_style.border_width_right = 2
	selected_style.border_width_top = 2
	selected_style.border_width_bottom = 2


func _setup_panel() -> void:
	# Configure grid
	slot_grid.columns = columns
	slot_grid.add_theme_constant_override("h_separation", slot_gap)
	slot_grid.add_theme_constant_override("v_separation", slot_gap)
	
	# Initial positioning
	# Force update of container size to get correct widths
	slide_container.reset_size()
	
	# Position closed by default: 
	# offset_left = -ButtonWidth (so only button sticks out left from anchor)
	# offset_right = PanelWidth (so panel is pushed right off screen)
	# Actually, simply setting position.x is easier if anchors are simple
	
	# Let's use position relative to the Anchor node (which is at screen right)
	# -container_width = Fully Open (Left edge is container_width away from right anchor)
	# -button_width    = Closed (Left edge is button_width away from right anchor)
	
	var closed_x := -toggle_button.custom_minimum_size.x
	slide_container.position.x = closed_x


func _generate_slots() -> void:
	# Clear existing slots
	for child in slot_grid.get_children():
		child.queue_free()
	slots.clear()
	
	# Generate new slots
	for i in range(slot_count):
		var slot := _create_slot(i)
		slot_grid.add_child(slot)
		slots.append(slot)


func _create_slot(index: int) -> Panel:
	var slot := Panel.new()
	slot.name = "Slot" + str(index)
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	
	# Add ItemIcon TextureRect inside slot
	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	
	return slot


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_panel()


func toggle_panel() -> void:
	is_open = not is_open
	_animate_panel()
	_update_toggle_button()
	inventory_toggled.emit(is_open)


func open_panel() -> void:
	if not is_open:
		is_open = true
		_animate_panel()
		_update_toggle_button()
		inventory_toggled.emit(is_open)


func close_panel() -> void:
	if is_open:
		is_open = false
		_animate_panel()
		_update_toggle_button()
		inventory_toggled.emit(is_open)


func _animate_panel() -> void:
	# Kill any existing tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Calculate target positions
	# Use size.x from container (ensure it's updated)
	var container_width := slide_container.size.x
	if container_width == 0: 
		# Fallback/Estimate if size not ready
		container_width = toggle_button.custom_minimum_size.x + panel_container.custom_minimum_size.x
		
	var button_width := toggle_button.custom_minimum_size.x
	
	# Open: Left edge is shifted left by full width
	# Closed: Left edge is shifted left by only button width
	var open_x := -container_width
	var closed_x := -button_width
	
	var target_x := open_x if is_open else closed_x
	current_tween.tween_property(slide_container, "position:x", target_x, animation_duration)


func _update_toggle_button() -> void:
	toggle_button.text = "▶" if is_open else "◀"


func _on_toggle_button_pressed() -> void:
	toggle_panel()


## Add more slots to the inventory
func expand_slots(additional_slots: int) -> void:
	var start_index := slot_count
	slot_count += additional_slots
	
	for i in range(additional_slots):
		var slot := _create_slot(start_index + i)
		slot_grid.add_child(slot)
		slots.append(slot)


## Set the texture for a specific slot
func set_slot_texture(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= slots.size():
		return
	var icon := slots[index].get_node("ItemIcon") as TextureRect
	if icon:
		icon.texture = texture


## Clear a slot's texture
func clear_slot(index: int) -> void:
	set_slot_texture(index, null)


## Clear all slots
func clear_all_slots() -> void:
	for i in range(slots.size()):
		clear_slot(i)
