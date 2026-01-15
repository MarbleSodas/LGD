extends Node

## Emitted when a slot's contents change
signal inventory_changed(slot: int, item: InventoryItem, count: int)

## Emitted when an item is added
signal item_added(item: InventoryItem, slot: int, count: int)

## Emitted when an item is removed
signal item_removed(item: InventoryItem, slot: int, count: int)

## Emitted when max slots changes (progression)
signal slots_expanded(new_max: int)

const DEFAULT_SLOTS: int = 20

## Array of slot data: each element is {item: InventoryItem, count: int} or null
var _slots: Array = []

## Current maximum number of slots
var _max_slots: int = DEFAULT_SLOTS

func _ready() -> void:
	_init_slots()

## Initialize all slots as empty
func _init_slots() -> void:
	_slots.clear()
	for i in range(_max_slots):
		_slots.append(null)

# --- Public API ---

## Add an item to the inventory. Returns the slot it was added to, or -1 if full.
## If the item is stackable, it will try to stack with existing items first.
func add_item(item: InventoryItem, count: int = 1) -> int:
	if item == null or count <= 0:
		return -1
	
	var remaining = count
	
	# First, try to stack with existing items of the same type
	if item.max_stack > 1:
		for i in range(_max_slots):
			if _slots[i] != null and _slots[i].item.id == item.id:
				var space = item.max_stack - _slots[i].count
				if space > 0:
					var to_add = min(remaining, space)
					_slots[i].count += to_add
					remaining -= to_add
					inventory_changed.emit(i, _slots[i].item, _slots[i].count)
					
					if remaining <= 0:
						item_added.emit(item, i, count)
						return i
	
	# Then, find empty slots for remaining items
	while remaining > 0:
		var empty_slot = get_first_empty_slot()
		if empty_slot == -1:
			# Inventory full, return -1 but keep what we added
			if remaining < count:
				item_added.emit(item, -1, count - remaining)
			return -1
		
		var to_add = min(remaining, item.max_stack)
		_slots[empty_slot] = {item = item, count = to_add}
		remaining -= to_add
		inventory_changed.emit(empty_slot, item, to_add)
		
		if remaining <= 0:
			item_added.emit(item, empty_slot, count)
			return empty_slot
	
	return -1

## Remove items from a specific slot. Returns {item, count} of what was removed.
func remove_item(slot: int, count: int = 1) -> Dictionary:
	if slot < 0 or slot >= _max_slots or _slots[slot] == null:
		return {}
	
	var slot_data = _slots[slot]
	var to_remove = min(count, slot_data.count)
	var removed_item = slot_data.item
	
	slot_data.count -= to_remove
	
	if slot_data.count <= 0:
		_slots[slot] = null
		inventory_changed.emit(slot, null, 0)
	else:
		inventory_changed.emit(slot, slot_data.item, slot_data.count)
	
	item_removed.emit(removed_item, slot, to_remove)
	return {item = removed_item, count = to_remove}

## Remove all items from a slot. Returns {item, count} of what was removed.
func clear_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= _max_slots or _slots[slot] == null:
		return {}
	
	var slot_data = _slots[slot]
	var removed = {item = slot_data.item, count = slot_data.count}
	
	_slots[slot] = null
	inventory_changed.emit(slot, null, 0)
	item_removed.emit(removed.item, slot, removed.count)
	
	return removed

## Get the contents of a slot. Returns {item, count} or null if empty.
func get_slot(slot: int) -> Variant:
	if slot < 0 or slot >= _max_slots:
		return null
	return _slots[slot]

## Get the current number of slots
func get_slot_count() -> int:
	return _max_slots

## Get the first empty slot index, or -1 if full
func get_first_empty_slot() -> int:
	for i in range(_max_slots):
		if _slots[i] == null:
			return i
	return -1

## Check if the inventory is completely full
func is_full() -> bool:
	return get_first_empty_slot() == -1

## Expand the inventory by a number of slots (for progression)
func expand_slots(additional: int) -> void:
	if additional <= 0:
		return
	
	var _old_max = _max_slots
	_max_slots += additional
	
	for i in range(additional):
		_slots.append(null)
	
	slots_expanded.emit(_max_slots)

## Swap the contents of two slots
func swap_slots(from_slot: int, to_slot: int) -> void:
	if from_slot < 0 or from_slot >= _max_slots:
		return
	if to_slot < 0 or to_slot >= _max_slots:
		return
	if from_slot == to_slot:
		return
	
	var temp = _slots[from_slot]
	_slots[from_slot] = _slots[to_slot]
	_slots[to_slot] = temp
	
	# Emit changes for both slots
	var from_item = _slots[from_slot].item if _slots[from_slot] else null
	var from_count = _slots[from_slot].count if _slots[from_slot] else 0
	var to_item = _slots[to_slot].item if _slots[to_slot] else null
	var to_count = _slots[to_slot].count if _slots[to_slot] else 0
	
	inventory_changed.emit(from_slot, from_item, from_count)
	inventory_changed.emit(to_slot, to_item, to_count)

## Check if the inventory has a specific item (by ID)
func has_item(item_id: String) -> bool:
	for slot_data in _slots:
		if slot_data != null and slot_data.item.id == item_id:
			return true
	return false

## Count total quantity of a specific item across all slots
func count_item(item_id: String) -> int:
	var total = 0
	for slot_data in _slots:
		if slot_data != null and slot_data.item.id == item_id:
			total += slot_data.count
	return total
