extends MarginContainer

## Emitted when the selected hotbar slot changes
signal slot_changed(index: int)

var current_slot: int = -1
var slots: Array = []

func _ready() -> void:
	_cache_slots()
	# Start with nothing selected
	deselect_slot()
	
	# Connect to registry
	if BuildRegistry:
		BuildRegistry.hotbar_changed.connect(_on_hotbar_changed)
		BuildRegistry.active_buildable_changed.connect(_on_active_buildable_changed)
		_sync_from_registry()

func _cache_slots() -> void:
	var hbox := $HBoxContainer
	for i in range(hbox.get_child_count()):
		var slot = hbox.get_child(i)
		# Assign index and connect signal if it's a HotbarSlot
		if slot.has_method("set_selected"):
			slot.slot_index = i
			if not slot.slot_clicked.is_connected(_on_slot_clicked):
				slot.slot_clicked.connect(_on_slot_clicked)
			slots.append(slot)
		# Allow fallback to Panels if scene not fully updated yet
		elif slot is Panel:
			slots.append(slot)

func _sync_from_registry() -> void:
	# Load initial hotbar state from registry
	for i in range(slots.size()):
		var item = BuildRegistry.get_hotbar_item(i)
		_update_slot_icon(i, item)

func _on_hotbar_changed(slot: int, item: BuildableItem) -> void:
	_update_slot_icon(slot, item)
	
	# If the currently selected slot changed, update selection state
	if slot == current_slot:
		if item == null:
			# If current slot was cleared, deselect it
			deselect_slot()
			BuildRegistry.clear_active()
		else:
			# If current slot changed item, activate the new item
			BuildRegistry.set_active(item)

func _on_active_buildable_changed(item: BuildableItem) -> void:
	if item == null:
		deselect_slot()
	else:
		# If the item is in the hotbar, select that slot
		var slot = BuildRegistry.get_slot_for_item(item)
		if slot != -1:
			select_slot(slot)
		else:
			# If activated from menu but not in hotbar, deselect hotbar
			deselect_slot()

func _update_slot_icon(slot: int, item: BuildableItem) -> void:
	if slot >= 0 and slot < slots.size():
		if item:
			slots[slot].set_item(item.icon, 0)
		else:
			slots[slot].set_item(null, 0)  # Clear icon

func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager and DialogueManager.is_active(): return
	if event.is_action_pressed("hotbar_1"): _toggle_slot(0)
	elif event.is_action_pressed("hotbar_2"): _toggle_slot(1)
	elif event.is_action_pressed("hotbar_3"): _toggle_slot(2)
	elif event.is_action_pressed("hotbar_4"): _toggle_slot(3)
	elif event.is_action_pressed("hotbar_5"): _toggle_slot(4)
	elif event.is_action_pressed("hotbar_6"): _toggle_slot(5)
	elif event.is_action_pressed("hotbar_7"): _toggle_slot(6)
	elif event.is_action_pressed("hotbar_8"): _toggle_slot(7)
	elif event.is_action_pressed("hotbar_9"): _toggle_slot(8)
	elif event.is_action_pressed("hotbar_0"): _toggle_slot(9)

func _on_slot_clicked(index: int) -> void:
	_toggle_slot(index)

func _toggle_slot(index: int) -> void:
	var item = BuildRegistry.get_hotbar_item(index)
	
	if item == null:
		# Empty slot - do nothing
		return
	
	if current_slot == index:
		# Pressing the same slot deselects it
		deselect_slot()
		BuildRegistry.clear_active()
	else:
		# Pressing a different slot selects it
		select_slot(index)
		BuildRegistry.set_active(item)

func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	
	# Deselect previous slot
	if current_slot >= 0 and current_slot < slots.size():
		if slots[current_slot].has_method("set_selected"):
			slots[current_slot].set_selected(false)
	
	# Select new slot
	current_slot = index
	if slots[current_slot].has_method("set_selected"):
		slots[current_slot].set_selected(true)
	
	# Notify other systems
	slot_changed.emit(current_slot)

func deselect_slot() -> void:
	# Deselect current slot
	if current_slot >= 0 and current_slot < slots.size():
		if slots[current_slot].has_method("set_selected"):
			slots[current_slot].set_selected(false)
	
	current_slot = -1
	slot_changed.emit(current_slot)

# Helper to update item display (to be called by inventory system)
func set_slot_item(index: int, texture: Texture2D, count: int = 0) -> void:
	if index >= 0 and index < slots.size():
		if slots[index].has_method("set_item"):
			slots[index].set_item(texture, count)
