@tool
extends NinePatchRect

signal clicked(item: BuildableItem)
signal hotkey_bind_requested(item: BuildableItem, slot: int)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconBackground/Icon
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var cost_container: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/CostContainer

var buildable_item: BuildableItem
var _is_hovered: bool = false

# Preload slot textures
var _normal_texture = preload("res://ui/resources/atlas/build_menu/slot_normal.tres")
var _hover_texture = preload("res://ui/resources/atlas/build_menu/slot_hover.tres")
# var _selected_texture = preload("res://ui/resources/atlas/build_menu/slot_selected.tres")

func _ready() -> void:
	# Initialize visual state immediately
	_update_visual_state()
	
	# Update content if item was set before ready
	if buildable_item:
		_update_content()
	
	# Set up mouse handling
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	# Autoloads (Inventory) are not available in the editor
	if not Engine.is_editor_hint() and Inventory:
		if not Inventory.inventory_changed.is_connected(_on_inventory_changed):
			Inventory.inventory_changed.connect(_on_inventory_changed)
	
func setup(item: BuildableItem) -> void:
	buildable_item = item
	if is_node_ready():
		_update_content()

func _update_content() -> void:
	if not buildable_item: return
	
	if icon_rect and buildable_item.icon:
		icon_rect.texture = buildable_item.icon
	if name_label:
		name_label.text = buildable_item.display_name
	_update_cost_display()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual_state()

func _update_visual_state() -> void:
	var icon_bg = get_node_or_null("MarginContainer/HBoxContainer/IconBackground")
	if icon_bg:
		if _is_hovered:
			icon_bg.texture = _hover_texture
		else:
			icon_bg.texture = _normal_texture

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(buildable_item)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _is_hovered:
		return
		
	# Check for hotbar keys while hovered
	if event is InputEventKey and event.pressed:
		for i in range(10):
			var action = "hotbar_0" if i == 9 else "hotbar_" + str(i + 1)
			if event.is_action_pressed(action):
				var slot_index = i
				hotkey_bind_requested.emit(buildable_item, slot_index)
				get_viewport().set_input_as_handled()
				break

func _on_inventory_changed(_slot: int, _item: InventoryItem, _count: int) -> void:
	_update_cost_display()

func _update_cost_display() -> void:
	if not cost_container or not buildable_item:
		return
	
	# Clear existing cost items
	for child in cost_container.get_children():
		child.queue_free()
	
	if buildable_item.build_costs.is_empty():
		return
	
	for material_id in buildable_item.build_costs:
		var required = buildable_item.build_costs[material_id]
		var available = Inventory.count_item(material_id) if Inventory else 0
		var item_data = ItemRegistry.get_item(material_id) if ItemRegistry else null
		
		# Create a container for this cost item
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 2)
		
		# Set tooltip to item name
		if item_data:
			item_hbox.tooltip_text = item_data.display_name
		
		# Icon
		if item_data and item_data.icon:
			var icon = TextureRect.new()
			icon.texture = item_data.icon
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			item_hbox.add_child(icon)
		
		# Count
		var label = Label.new()
		label.text = str(required)
		label.add_theme_font_size_override("font_size", 14)
		
		# Color based on affordability
		if available >= required:
			label.add_theme_color_override("font_color", Color(0.4, 0.298, 0.22, 1)) # Normal brown text
		else:
			label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 1)) # Red warning
			
		item_hbox.add_child(label)
		cost_container.add_child(item_hbox)
