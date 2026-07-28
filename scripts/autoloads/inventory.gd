extends Node

## Global inventory system handling player items, stacking, and persistence.
##
## Manages a fixed number of slots containing [InventoryItem]s.
## Supports drag-and-drop, stacking, sorting, and save/load operations.

## Emitted when a slot's contents change (added, removed, or count updated)
signal inventory_changed(slot: int, item: InventoryItem, count: int)

## Emitted when an item is added to the inventory
signal item_added(item: InventoryItem, slot: int, count: int)

## Emitted when an item is removed from the inventory
signal item_removed(item: InventoryItem, slot: int, count: int)

## Emitted when max slots changes (progression)
signal slots_expanded(new_max: int)

## Emitted when the held item changes (cursor update)
signal held_item_changed(item: InventoryItem, count: int)

const DEFAULT_SLOTS: int = 20
const CATEGORY_ORDER: Array[String] = ["Material", "Tool", "Consumable", "Misc"]

## Array of slot data: each element is {item: InventoryItem, count: int} or null
var _slots: Array = []

## Current maximum number of slots
var _max_slots: int = DEFAULT_SLOTS

## Held item state
var _held_item: InventoryItem = null
var _held_count: int = 0
var _held_source_slot: int = -1

func _ready() -> void:
	_init_slots()
	# Add starting items deferred to ensure Registries is loaded
	call_deferred("_add_starting_items")

func _add_starting_items() -> void:
	# Only add starting items if inventory is completely empty
	# This prevents duplicates if _ready is called multiple times or after load
	if not is_empty(): return
	
	# Only add starting items if specifically requested or for debugging
	# For the main game loop, we want the player to start empty-handed
	# and receive their first item from Glider
	pass

	# if Registries:
	# 	var tuft: InventoryItem = Registries.get_item("dandelion_tuft")
	# 	if tuft:
	# 		add_item(tuft, 5)

## Reset inventory to default state
func reset() -> void:
	_max_slots = DEFAULT_SLOTS
	_init_slots()
	
	# Clear held item
	_held_item = null
	_held_count = 0
	_held_source_slot = -1
	held_item_changed.emit(null, 0)
	
	slots_expanded.emit(_max_slots)
	
	# Notify UI of full reset
	for i in range(_max_slots):
		_emit_slot_change(i)

## Initialize all slots as empty
func _init_slots() -> void:
	_slots.clear()
	for i in range(_max_slots):
		_slots.append(null)

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

## Add an item to the inventory.
## Returns the slot it was added to, or -1 if full.
## If the item is stackable, it will try to stack with existing items first.
func add_item(item: InventoryItem, count: int = 1) -> int:
	if item == null or count <= 0:
		return -1
	
	var remaining: int = count
	
	# 1. Try to stack with existing items
	if item.max_stack > 1:
		var stack_result: Dictionary = _try_stack_item(item, remaining)
		remaining = stack_result.remaining
		if remaining <= 0:
			item_added.emit(item, stack_result.last_slot, count)
			return stack_result.last_slot
	
	# 2. Find empty slots for remaining items
	while remaining > 0:
		var empty_slot: int = get_first_empty_slot()
		if empty_slot == -1:
			# Inventory full, return -1 but keep what we added
			if remaining < count:
				item_added.emit(item, -1, count - remaining)
			return -1
		
		var to_add: int = min(remaining, item.max_stack)
		_slots[empty_slot] = { "item": item, "count": to_add }
		remaining -= to_add
		inventory_changed.emit(empty_slot, item, to_add)
		
		if remaining <= 0:
			item_added.emit(item, empty_slot, count)
			return empty_slot
	
	return -1

## Add items and return the number of items successfully added
func add_item_quantity(item: InventoryItem, count: int) -> int:
	if item == null or count <= 0:
		return 0
	
	var remaining: int = count
	var total_added: int = 0
	
	# 1. Stack with existing
	if item.max_stack > 1:
		var stack_result: Dictionary = _try_stack_item(item, remaining)
		remaining = stack_result.remaining
		total_added += (count - remaining)
	
	# 2. Empty slots
	while remaining > 0:
		var empty_slot: int = get_first_empty_slot()
		if empty_slot == -1:
			break
		
		var to_add: int = min(remaining, item.max_stack)
		_slots[empty_slot] = { "item": item, "count": to_add }
		remaining -= to_add
		total_added += to_add
		inventory_changed.emit(empty_slot, item, to_add)
	
	if total_added > 0:
		item_added.emit(item, -1, total_added)
		
	return total_added

## Remove items from a specific slot.
## Returns {item: InventoryItem, count: int} of what was removed.
func remove_item(slot: int, count: int = 1) -> Dictionary:
	if !_is_valid_slot(slot) or _slots[slot] == null:
		return {}
	
	var slot_data: Dictionary = _slots[slot]
	var to_remove: int = min(count, slot_data.count)
	var removed_item: InventoryItem = slot_data.item
	
	slot_data.count -= to_remove
	
	if slot_data.count <= 0:
		_slots[slot] = null
		inventory_changed.emit(slot, null, 0)
	else:
		inventory_changed.emit(slot, slot_data.item, slot_data.count)
	
	item_removed.emit(removed_item, slot, to_remove)
	return { "item": removed_item, "count": to_remove }

## Remove all items from a slot.
## Returns {item: InventoryItem, count: int} of what was removed.
func clear_slot(slot: int) -> Dictionary:
	if !_is_valid_slot(slot) or _slots[slot] == null:
		return {}
	
	var slot_data: Dictionary = _slots[slot]
	var removed: Dictionary = { "item": slot_data.item, "count": slot_data.count }
	
	_slots[slot] = null
	inventory_changed.emit(slot, null, 0)
	item_removed.emit(removed.item, slot, removed.count)
	
	return removed

## Get the contents of a slot.
## Returns {item: InventoryItem, count: int} or null if empty.
func get_slot(slot: int) -> Variant:
	if !_is_valid_slot(slot):
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

## Check if the inventory is empty
func is_empty() -> bool:
	for slot in _slots:
		if slot != null:
			return false
	return true

## Expand the inventory by a number of slots (for progression)
func expand_slots(additional: int) -> void:
	if additional <= 0:
		return
	
	_max_slots += additional
	
	for i in range(additional):
		_slots.append(null)
	
	slots_expanded.emit(_max_slots)

## Swap the contents of two slots
func swap_slots(from_slot: int, to_slot: int) -> void:
	if !_is_valid_slot(from_slot) or !_is_valid_slot(to_slot):
		return
	if from_slot == to_slot:
		return
	
	var temp: Variant = _slots[from_slot]
	_slots[from_slot] = _slots[to_slot]
	_slots[to_slot] = temp
	
	# Emit changes for both slots
	_emit_slot_change(from_slot)
	_emit_slot_change(to_slot)

## Check if the inventory has a specific item (by ID) and optional count
func has_item(item_id: String, count: int = 1) -> bool:
	return count_item(item_id) >= count

# ------------------------------------------------------------------------------
# Held Item & Drag System
# ------------------------------------------------------------------------------

func is_holding_item() -> bool:
	return _held_item != null and _held_count > 0

func get_held_item() -> Dictionary:
	if _held_item == null:
		return {}
	return { "item": _held_item, "count": _held_count }

## Pick up entire stack from a slot
func pickup_item(slot: int) -> bool:
	if !_is_valid_slot(slot) or _slots[slot] == null:
		return false
	
	if is_holding_item():
		return false
	
	var slot_data: Dictionary = _slots[slot]
	_held_item = slot_data.item
	_held_count = slot_data.count
	_held_source_slot = slot
	
	_slots[slot] = null
	inventory_changed.emit(slot, null, 0)
	held_item_changed.emit(_held_item, _held_count)
	return true

## Pick up half the stack (Shift + Right Click)
func pickup_half(slot: int) -> bool:
	if !_is_valid_slot(slot) or _slots[slot] == null:
		return false
	if is_holding_item():
		return false
		
	var slot_data: Dictionary = _slots[slot]
	var total: int = slot_data.count
	var take: int = ceili(total / 2.0)
	
	_held_item = slot_data.item
	_held_count = take
	_held_source_slot = slot
	
	slot_data.count -= take
	if slot_data.count <= 0:
		_slots[slot] = null
		inventory_changed.emit(slot, null, 0)
	else:
		inventory_changed.emit(slot, slot_data.item, slot_data.count)
		
	held_item_changed.emit(_held_item, _held_count)
	return true

## Pick up one item (Right Click)
func pickup_one(slot: int) -> bool:
	if !_is_valid_slot(slot) or _slots[slot] == null:
		return false
		
	# If holding nothing, pick up 1
	if not is_holding_item():
		var slot_data: Dictionary = _slots[slot]
		_held_item = slot_data.item
		_held_count = 1
		_held_source_slot = slot
		
		slot_data.count -= 1
		if slot_data.count <= 0:
			_slots[slot] = null
			inventory_changed.emit(slot, null, 0)
		else:
			inventory_changed.emit(slot, slot_data.item, slot_data.count)
			
		held_item_changed.emit(_held_item, _held_count)
		return true
		
	# If holding same item, add 1 to hand
	else:
		var slot_data: Dictionary = _slots[slot]
		if slot_data.item.id == _held_item.id:
			if _held_count < _held_item.max_stack:
				_held_count += 1
				slot_data.count -= 1
				
				if slot_data.count <= 0:
					_slots[slot] = null
					inventory_changed.emit(slot, null, 0)
				else:
					inventory_changed.emit(slot, slot_data.item, slot_data.count)
					
				held_item_changed.emit(_held_item, _held_count)
				return true
	
	return false

## Place all held items into a slot (Left Click)
func place_item(slot: int) -> bool:
	if not is_holding_item():
		return false
	if !_is_valid_slot(slot):
		return false
		
	var slot_data: Variant = _slots[slot]
	
	# Case 1: Empty slot
	if slot_data == null:
		_slots[slot] = { "item": _held_item, "count": _held_count }
		inventory_changed.emit(slot, _held_item, _held_count)
		_clear_held_item()
		return true
		
	# Case 2: Same item -> Merge
	if slot_data.item.id == _held_item.id:
		var space: int = slot_data.item.max_stack - slot_data.count
		if space > 0:
			var to_add: int = min(_held_count, space)
			slot_data.count += to_add
			_held_count -= to_add
			
			inventory_changed.emit(slot, slot_data.item, slot_data.count)
			
			if _held_count <= 0:
				_clear_held_item()
			else:
				held_item_changed.emit(_held_item, _held_count)
			return true
		else:
			return false
			
	# Case 3: Different item -> Swap
	else:
		var temp_item: InventoryItem = slot_data.item
		var temp_count: int = slot_data.count
		
		_slots[slot] = { "item": _held_item, "count": _held_count }
		inventory_changed.emit(slot, _held_item, _held_count)
		
		_held_item = temp_item
		_held_count = temp_count
		_held_source_slot = slot
		held_item_changed.emit(_held_item, _held_count)
		return true

## Place one item into a slot (Right Click)
func place_one(slot: int) -> bool:
	if not is_holding_item():
		return false
	if !_is_valid_slot(slot):
		return false
		
	var slot_data: Variant = _slots[slot]
	
	# Case 1: Empty slot
	if slot_data == null:
		_slots[slot] = { "item": _held_item, "count": 1 }
		_held_count -= 1
		
		inventory_changed.emit(slot, _held_item, 1)
		
		if _held_count <= 0:
			_clear_held_item()
		else:
			held_item_changed.emit(_held_item, _held_count)
		return true
		
	# Case 2: Same item -> Add 1
	if slot_data.item.id == _held_item.id:
		if slot_data.count < slot_data.item.max_stack:
			slot_data.count += 1
			_held_count -= 1
			
			inventory_changed.emit(slot, slot_data.item, slot_data.count)
			
			if _held_count <= 0:
				_clear_held_item()
			else:
				held_item_changed.emit(_held_item, _held_count)
			return true
	
	return false

## Return held item to source or first empty slot
func return_held_item() -> void:
	if not is_holding_item():
		return

	var returning_item: InventoryItem = _held_item
	var remaining: int = _held_count

	# Try original source first
	if _held_source_slot != -1 and _held_source_slot < _max_slots:
		var slot_data: Variant = _slots[_held_source_slot]
		if slot_data == null:
			_slots[_held_source_slot] = { "item": returning_item, "count": remaining }
			inventory_changed.emit(_held_source_slot, returning_item, remaining)
			_clear_held_item()
			return
		elif slot_data.item.id == returning_item.id:
			var available_space: int = slot_data.item.max_stack - slot_data.count
			var source_return_count: int = min(remaining, available_space)
			if source_return_count > 0:
				slot_data.count += source_return_count
				remaining -= source_return_count
				inventory_changed.emit(_held_source_slot, slot_data.item, slot_data.count)

	if remaining > 0:
		remaining -= add_item_quantity(returning_item, remaining)

	if remaining <= 0:
		_clear_held_item()
		return

	_held_item = returning_item
	_held_count = remaining
	_held_source_slot = -1
	held_item_changed.emit(_held_item, _held_count)
	push_warning("Inventory: Could not return %d held item(s); keeping them on the cursor." % remaining)

## Clear held item without returning to inventory
func clear_held_item_external() -> void:
	_clear_held_item()

## Set the held item from an external source
func set_held_item_external(item: InventoryItem, count: int) -> bool:
	if item == null or count <= 0:
		return false

	if is_holding_item():
		return_held_item()
		if is_holding_item():
			return false

	_held_item = item
	_held_count = count
	_held_source_slot = -1 # External source

	held_item_changed.emit(_held_item, _held_count)
	return true

## Sort inventory by category, then ID, then count
func sort_inventory() -> void:
	if is_holding_item():
		return_held_item()
		
	# 1. Consolidate stacks
	var consolidated: Array[Dictionary] = []
	for slot in _slots:
		if slot == null: continue
		
		# Try to merge with existing items in consolidated list
		var merged: bool = false
		for existing in consolidated:
			if existing.item.id == slot.item.id:
				var space: int = existing.item.max_stack - existing.count
				if space > 0:
					var transfer: int = min(slot.count, space)
					existing.count += transfer
					slot.count -= transfer
					if slot.count <= 0:
						merged = true
						break
		
		if !merged and slot.count > 0:
			consolidated.append(slot)
			
	# 2. Sort the consolidated list
	consolidated.sort_custom(_sort_items)
	
	# 3. Refill slots
	for i in range(_max_slots):
		if i < consolidated.size():
			_slots[i] = consolidated[i]
		else:
			_slots[i] = null
			
	# Notify UI
	for i in range(_max_slots):
		_emit_slot_change(i)

# ------------------------------------------------------------------------------
# Save/Load Support
# ------------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	var slots_data: Array = []
	for slot in _slots:
		if slot == null:
			slots_data.append(null)
		else:
			slots_data.append({
				"item_id": slot.item.id,
				"count": slot.count
			})
			
	return {
		"max_slots": _max_slots,
		"slots": slots_data
	}

func from_save_data(data: Dictionary) -> void:
	if data.has("max_slots"):
		_max_slots = int(data["max_slots"])
	
	_slots.clear()
	
	if data.has("slots"):
		for slot_data in data["slots"]:
			if slot_data == null:
				_slots.append(null)
			else:
				var item: InventoryItem = Registries.get_item(slot_data["item_id"])
				if item:
					_slots.append({
						"item": item,
						"count": int(slot_data["count"])
					})
				else:
					_slots.append(null)
	
	# Ensure array matches max_slots size
	while _slots.size() < _max_slots:
		_slots.append(null)
	
	# Notify UI
	for i in range(_max_slots):
		_emit_slot_change(i)

# ------------------------------------------------------------------------------
# Query Helpers
# ------------------------------------------------------------------------------

## Count total quantity of a specific item across all slots
func count_item(item_id: String) -> int:
	var total: int = 0
	for slot_data in _slots:
		if slot_data != null and slot_data.item.id == item_id:
			total += slot_data.count
	return total

## Remove a quantity of an item by ID across all slots.
## Returns true if successful.
func consume_item(item_id: String, count: int = 1) -> bool:
	if count_item(item_id) < count:
		return false
	
	var remaining: int = count
	for i in range(_max_slots):
		if remaining <= 0:
			break
			
		var slot_data: Variant = _slots[i]
		if slot_data != null and slot_data.item.id == item_id:
			var to_remove: int = min(remaining, slot_data.count)
			var removed_item: InventoryItem = slot_data.item
			
			slot_data.count -= to_remove
			remaining -= to_remove
			
			if slot_data.count <= 0:
				_slots[i] = null
				inventory_changed.emit(i, null, 0)
			else:
				inventory_changed.emit(i, slot_data.item, slot_data.count)
				
			item_removed.emit(removed_item, i, to_remove)
	
	return true

# ------------------------------------------------------------------------------
# Internal Helpers
# ------------------------------------------------------------------------------

func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < _max_slots

func _clear_held_item() -> void:
	_held_item = null
	_held_count = 0
	_held_source_slot = -1
	held_item_changed.emit(null, 0)

func _emit_slot_change(slot: int) -> void:
	if _slots[slot]:
		inventory_changed.emit(slot, _slots[slot].item, _slots[slot].count)
	else:
		inventory_changed.emit(slot, null, 0)

## Helper to stack items into existing slots.
## Returns { "remaining": int, "last_slot": int }
func _try_stack_item(item: InventoryItem, count: int) -> Dictionary:
	var remaining: int = count
	var last_slot: int = -1
	
	for i in range(_max_slots):
		if _slots[i] != null and _slots[i].item.id == item.id:
			var space: int = item.max_stack - _slots[i].count
			if space > 0:
				var to_add: int = min(remaining, space)
				_slots[i].count += to_add
				remaining -= to_add
				last_slot = i
				inventory_changed.emit(i, _slots[i].item, _slots[i].count)
				
				if remaining <= 0:
					break
					
	return { "remaining": remaining, "last_slot": last_slot }

func _sort_items(a: Dictionary, b: Dictionary) -> bool:
	var cat_a: int = CATEGORY_ORDER.find(a.item.category)
	var cat_b: int = CATEGORY_ORDER.find(b.item.category)
	
	# 1. Category (lower index = higher priority)
	if cat_a != cat_b:
		if cat_a == -1: return false 
		if cat_b == -1: return true
		return cat_a < cat_b
		
	# 2. Item ID (Alphabetical)
	if a.item.id != b.item.id:
		return a.item.id < b.item.id
		
	# 3. Count (Descending)
	return a.count > b.count
