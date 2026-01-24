extends NinePatchRect

signal slot_hovered(index: int)

@export var slot_index: int = 0

## Optional target inventory (for containers). If null, uses player Inventory.
var target_inventory: Object = null

@onready var item_icon: TextureRect = $ItemIcon
@onready var stack_label: Label = $StackCount

# Preload slot textures
var _normal_texture: Texture2D = preload("res://ui/resources/atlas/inventory/slot_normal.tres")
var _selected_texture: Texture2D = preload("res://ui/resources/atlas/inventory/slot_selected.tres")
var _hover_texture: Texture2D = preload("res://ui/resources/atlas/inventory/slot_hover.tres")

var _is_selected: bool = false
var _is_hovered: bool = false

func _ready() -> void:
	texture = _normal_texture
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to inventory changes
	if target_inventory:
		if target_inventory.has_signal("slot_changed"):
			target_inventory.slot_changed.connect(_on_inventory_changed)
	elif Inventory:
		Inventory.inventory_changed.connect(_on_inventory_changed)
	
	# Initial update
	_update_display()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_update_texture()

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

func _update_texture() -> void:
	# Priority: Selected > Hovered > Normal
	if _is_selected:
		texture = _selected_texture
	elif _is_hovered:
		texture = _hover_texture
	else:
		texture = _normal_texture

func _update_display() -> void:
	var slot_data: Variant = null
	
	if target_inventory:
		if target_inventory.has_method("get_slot"):
			slot_data = target_inventory.get_slot(slot_index)
	elif Inventory:
		slot_data = Inventory.get_slot(slot_index)
	
	# Handle both Dictionary and Object based slot data if needed, 
	# but Inventory uses Dictionary {item, count} or null.
	if slot_data != null:
		var item: InventoryItem = slot_data.item if "item" in slot_data else null
		var count: int = slot_data.count if "count" in slot_data else 0
		
		if item:
			set_item(item.icon, count)
			return

	set_item(null, 0)

func _on_inventory_changed(slot: int, _item: InventoryItem, _count: int) -> void:
	if slot == slot_index:
		_update_display()

# ------------------------------------------------------------------------------
# Input Handling
# ------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not Inventory:
			return
			
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_left_click()
				get_viewport().set_input_as_handled()
				
			MOUSE_BUTTON_RIGHT:
				_handle_right_click()
				get_viewport().set_input_as_handled()

func _handle_left_click() -> void:
	var holding: bool = Inventory.is_holding_item()
	var shift: bool = Input.is_key_pressed(KEY_SHIFT)
	
	if target_inventory == null:
		# Player Inventory
		if not holding and shift:
			_handle_player_shift_transfer()
		elif holding:
			Inventory.place_item(slot_index)
		else:
			Inventory.pickup_item(slot_index)
	else:
		# External Inventory
		if not holding and shift:
			_handle_external_shift_transfer()
		elif holding:
			_handle_external_place()
		else:
			_handle_external_pickup()

func _handle_right_click() -> void:
	var holding: bool = Inventory.is_holding_item()
	var shift: bool = Input.is_key_pressed(KEY_SHIFT)
	
	if target_inventory == null:
		# Player Inventory
		if shift and not holding:
			Inventory.pickup_half(slot_index)
		elif holding:
			Inventory.place_one(slot_index)
		else:
			Inventory.pickup_one(slot_index)
	else:
		# External Inventory
		if holding:
			_handle_external_place_one()
		else:
			if shift:
				_handle_external_pickup_half()
			else:
				_handle_external_pickup_one()

# ------------------------------------------------------------------------------
# External Inventory Logic
# ------------------------------------------------------------------------------

func _handle_external_pickup() -> void:
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	if slot_data == null or slot_data.item == null:
		return
		
	Inventory.set_held_item_external(slot_data.item, slot_data.count)
	target_inventory.set_slot(slot_index, null, 0)

func _handle_external_place() -> void:
	var held: Dictionary = Inventory.get_held_item()
	var held_item: InventoryItem = held.item
	var held_count: int = held.count
	
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	
	# Case 1: Empty slot
	if slot_data == null or slot_data.item == null:
		target_inventory.set_slot(slot_index, held_item, held_count)
		Inventory.clear_held_item_external()
		return
		
	# Case 2: Same item -> Merge
	if slot_data.item.id == held_item.id:
		var space: int = slot_data.item.max_stack - slot_data.count
		if space > 0:
			var to_add: int = min(held_count, space)
			target_inventory.set_slot(slot_index, slot_data.item, slot_data.count + to_add)
			
			var remaining: int = held_count - to_add
			Inventory.clear_held_item_external()
			if remaining > 0:
				Inventory.set_held_item_external(held_item, remaining)
		return
		
	# Case 3: Different item -> Swap
	var temp_item: InventoryItem = slot_data.item
	var temp_count: int = slot_data.count
	
	Inventory.clear_held_item_external()
	target_inventory.set_slot(slot_index, held_item, held_count)
	Inventory.set_held_item_external(temp_item, temp_count)

func _handle_external_pickup_one() -> void:
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	if slot_data == null or slot_data.item == null:
		return
		
	Inventory.set_held_item_external(slot_data.item, 1)
	
	if slot_data.count > 1:
		target_inventory.set_slot(slot_index, slot_data.item, slot_data.count - 1)
	else:
		target_inventory.set_slot(slot_index, null, 0)

func _handle_external_pickup_half() -> void:
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	if slot_data == null or slot_data.item == null:
		return
		
	var total: int = slot_data.count
	var take: int = ceili(total / 2.0)
	
	Inventory.set_held_item_external(slot_data.item, take)
	
	if total - take > 0:
		target_inventory.set_slot(slot_index, slot_data.item, total - take)
	else:
		target_inventory.set_slot(slot_index, null, 0)

func _handle_external_place_one() -> void:
	var held: Dictionary = Inventory.get_held_item()
	var held_item: InventoryItem = held.item
	var held_count: int = held.count
	
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	
	# Case 1: Empty slot
	if slot_data == null or slot_data.item == null:
		target_inventory.set_slot(slot_index, held_item, 1)
		Inventory.clear_held_item_external()
		if held_count > 1:
			Inventory.set_held_item_external(held_item, held_count - 1)
		return
		
	# Case 2: Same item -> Add 1
	if slot_data.item.id == held_item.id:
		if slot_data.count < slot_data.item.max_stack:
			target_inventory.set_slot(slot_index, slot_data.item, slot_data.count + 1)
			Inventory.clear_held_item_external()
			if held_count > 1:
				Inventory.set_held_item_external(held_item, held_count - 1)

func _handle_player_shift_transfer() -> void:
	var slot_data: Variant = Inventory.get_slot(slot_index)
	if slot_data == null or slot_data.item == null:
		return
	
	# Priority 1: Check for open processor menu
	var processor_menu: Node = get_tree().get_first_node_in_group("processor_menu")
	if processor_menu and processor_menu.get("is_open") and processor_menu.current_building:
		var building = processor_menu.current_building
		# Only transfer if item matches selected recipe's input
		if building.has_method("get_wanted_item_id"):
			var wanted_id: String = building.get_wanted_item_id()
			if wanted_id != "" and slot_data.item.id == wanted_id:
				var item: InventoryItem = slot_data.item
				var count: int = slot_data.count
				# Transfer to processor input
				var added: int = building.input_inventory.add_item_quantity(item, count)
				if added > 0:
					Inventory.remove_item(slot_index, added)
				return
		
	# Priority 2: Find open container
	var container_panel: Node = get_tree().get_first_node_in_group("container_panel")
	if container_panel and container_panel.get("is_open") and container_panel.current_container:
		var item: InventoryItem = slot_data.item
		var count: int = slot_data.count
		
		# Try to add to container
		var added: int = container_panel.current_container.add_item_quantity(item, count)
		
		if added > 0:
			Inventory.remove_item(slot_index, added)

func _handle_external_shift_transfer() -> void:
	var slot_data: Variant = target_inventory.get_slot(slot_index)
	if slot_data == null or slot_data.item == null:
		return
		
	var item: InventoryItem = slot_data.item
	var count: int = slot_data.count
	
	# Try to add to player inventory
	var added: int = Inventory.add_item_quantity(item, count)
	
	if added > 0:
		target_inventory.remove_item(slot_index, added)

func _on_mouse_entered() -> void:
	_is_hovered = true
	slot_hovered.emit(slot_index)
	_update_texture()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_texture()
