extends Node

## Emitted when a slot's contents change
signal inventory_changed(slot: int, item: InventoryItem, count: int)

## Emitted when an item is added
signal item_added(item: InventoryItem, slot: int, count: int)

## Emitted when an item is removed
signal item_removed(item: InventoryItem, slot: int, count: int)

## Emitted when max slots changes (progression)
signal slots_expanded(new_max: int)

## Emitted when the held item changes (cursor update)
signal held_item_changed(item: InventoryItem, count: int)

const DEFAULT_SLOTS: int = 20
const CATEGORY_ORDER = ["Material", "Tool", "Consumable", "Misc"]

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
	# Add starting items deferred to ensure ItemRegistry is loaded
	call_deferred("_add_starting_items")

func _add_starting_items() -> void:
	if ItemRegistry:
		var tuft = ItemRegistry.get_item("dandelion_tuft")
		if tuft:
			add_item(tuft, 5)

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

# --- Held Item & Drag System ---

func is_holding_item() -> bool:
	return _held_item != null and _held_count > 0

func get_held_item() -> Dictionary:
	if _held_item == null:
		return {}
	return {"item": _held_item, "count": _held_count}

## Pick up entire stack from a slot
func pickup_item(slot: int) -> bool:
	if slot < 0 or slot >= _max_slots or _slots[slot] == null:
		return false
	
	# If already holding something, try to swap or merge first (handled in place_item)
	# But if we strictly want "pickup" to mean "take from slot into empty hand":
	if is_holding_item():
		return false

	var slot_data = _slots[slot]
	_held_item = slot_data.item
	_held_count = slot_data.count
	_held_source_slot = slot
	
	_slots[slot] = null
	inventory_changed.emit(slot, null, 0)
	held_item_changed.emit(_held_item, _held_count)
	return true

## Pick up half the stack (Shift + Right Click)
func pickup_half(slot: int) -> bool:
	if slot < 0 or slot >= _max_slots or _slots[slot] == null:
		return false
	if is_holding_item():
		return false # Cannot split if hand is full
		
	var slot_data = _slots[slot]
	var total = slot_data.count
	var take = ceili(total / 2.0) # Pick up half (rounded up for stack of 1 = 1)
	
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
	if slot < 0 or slot >= _max_slots or _slots[slot] == null:
		return false
		
	# If holding nothing, pick up 1
	if not is_holding_item():
		var slot_data = _slots[slot]
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
		var slot_data = _slots[slot]
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
	if slot < 0 or slot >= _max_slots:
		return false
		
	var slot_data = _slots[slot]
	
	# Case 1: Empty slot
	if slot_data == null:
		_slots[slot] = {"item": _held_item, "count": _held_count}
		inventory_changed.emit(slot, _held_item, _held_count)
		
		_clear_held_item()
		return true
		
	# Case 2: Same item -> Merge
	if slot_data.item.id == _held_item.id:
		var space = slot_data.item.max_stack - slot_data.count
		if space > 0:
			var to_add = min(_held_count, space)
			slot_data.count += to_add
			_held_count -= to_add
			
			inventory_changed.emit(slot, slot_data.item, slot_data.count)
			
			if _held_count <= 0:
				_clear_held_item()
			else:
				held_item_changed.emit(_held_item, _held_count)
			return true
		else:
			# Stack full, do nothing (or could swap if we implemented stack swapping logic, but usually we just hold)
			return false
			
	# Case 3: Different item -> Swap
	else:
		var temp_item = slot_data.item
		var temp_count = slot_data.count
		
		_slots[slot] = {"item": _held_item, "count": _held_count}
		inventory_changed.emit(slot, _held_item, _held_count)
		
		_held_item = temp_item
		_held_count = temp_count
		_held_source_slot = slot # New source is where we swapped from
		held_item_changed.emit(_held_item, _held_count)
		return true

## Place one item into a slot (Right Click)
func place_one(slot: int) -> bool:
	if not is_holding_item():
		return false
	if slot < 0 or slot >= _max_slots:
		return false
		
	var slot_data = _slots[slot]
	
	# Case 1: Empty slot
	if slot_data == null:
		_slots[slot] = {"item": _held_item, "count": 1}
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
		
	# Try original source first
	if _held_source_slot != -1 and _held_source_slot < _max_slots:
		var slot_data = _slots[_held_source_slot]
		# If empty or same item with space
		if slot_data == null:
			_slots[_held_source_slot] = {"item": _held_item, "count": _held_count}
			inventory_changed.emit(_held_source_slot, _held_item, _held_count)
			_clear_held_item()
			return
		elif slot_data.item.id == _held_item.id:
			var space = slot_data.item.max_stack - slot_data.count
			if space >= _held_count:
				slot_data.count += _held_count
				inventory_changed.emit(_held_source_slot, slot_data.item, slot_data.count)
				_clear_held_item()
				return
				
	# If source failed, try adding normally (finds first empty / merges)
	var left_over = add_item(_held_item, _held_count)
	if left_over == -1 or left_over >= 0: # add_item returns slot index or -1 if full (Wait, my add_item returns -1 if full? Checking add_item logic...)
		# The existing add_item emits item_added, which might be slightly wrong context for "returning" but acceptable.
		# Ideally we just manually find a slot to avoid trigger "item_added" events for just moving things around,
		# but for now let's manually find a slot to be safe.
		pass
		
	# Manual placement to ensure we don't lose items
	var remaining = _held_count
	
	# 1. Try to merge
	for i in range(_max_slots):
		if _slots[i] != null and _slots[i].item.id == _held_item.id:
			var space = _slots[i].item.max_stack - _slots[i].count
			if space > 0:
				var to_add = min(remaining, space)
				_slots[i].count += to_add
				remaining -= to_add
				inventory_changed.emit(i, _slots[i].item, _slots[i].count)
				if remaining <= 0: break
	
	# 2. Try empty slots
	if remaining > 0:
		for i in range(_max_slots):
			if _slots[i] == null:
				_slots[i] = {"item": _held_item, "count": remaining}
				inventory_changed.emit(i, _held_item, remaining)
				remaining = 0
				break
	
	# If still remaining, we can't fit it. In a real game, drop to world?
	# For now, we just clear the hand and log a warning (or keep holding? No, user cancelled)
	# User requested "return held item". If full, maybe keep holding?
	# Implementation: clear hand.
	if remaining > 0:
		print("Warning: Inventory full, lost ", remaining, " items on return.")
		
	_clear_held_item()

func _clear_held_item() -> void:
	_held_item = null
	_held_count = 0
	_held_source_slot = -1
	held_item_changed.emit(null, 0)

## Sort inventory by category, then ID, then count
func sort_inventory() -> void:
	if is_holding_item():
		return_held_item()
		
	# 1. Consolidate stacks
	var consolidated: Array = []
	for slot in _slots:
		if slot == null: continue
		
		# Try to merge with existing items in consolidated list
		for existing in consolidated:
			if existing.item.id == slot.item.id:
				var space = existing.item.max_stack - existing.count
				if space > 0:
					var transfer = min(slot.count, space)
					existing.count += transfer
					slot.count -= transfer
					if slot.count <= 0:
						break
		
		# If items remain, add as new stack
		if slot.count > 0:
			consolidated.append(slot)
			
	# 2. Sort the consolidated list
	consolidated.sort_custom(func(a, b):
		var cat_a = CATEGORY_ORDER.find(a.item.category)
		var cat_b = CATEGORY_ORDER.find(b.item.category)
		
		# 1. Category (lower index = higher priority)
		if cat_a != cat_b:
			if cat_a == -1: return false # Unknown category goes last
			if cat_b == -1: return true
			return cat_a < cat_b
			
		# 2. Item ID (Alphabetical)
		if a.item.id != b.item.id:
			return a.item.id < b.item.id
			
		# 3. Count (Descending - larger stacks first)
		return a.count > b.count
	)
	
	# 3. Refill slots
	for i in range(_max_slots):
		if i < consolidated.size():
			_slots[i] = consolidated[i]
		else:
			_slots[i] = null
			
	# Notify UI
	for i in range(_max_slots):
		if _slots[i]:
			inventory_changed.emit(i, _slots[i].item, _slots[i].count)
		else:
			inventory_changed.emit(i, null, 0)

# --- Save/Load Support ---

func to_save_data() -> Dictionary:
	var slots_data = []
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
		_max_slots = data["max_slots"]
	
	# Re-init slots array
	_slots.clear()
	
	if data.has("slots"):
		for slot_data in data["slots"]:
			if slot_data == null:
				_slots.append(null)
			else:
				var item = ItemRegistry.get_item(slot_data["item_id"])
				if item:
					_slots.append({
						"item": item,
						"count": slot_data["count"]
					})
				else:
					# Item ID no longer exists in registry? treat as empty
					_slots.append(null)
	
	# Ensure array matches max_slots size
	while _slots.size() < _max_slots:
		_slots.append(null)
	
	# Notify UI to refresh everything
	# We do this by emitting changes for every slot or just relying on UI to rebuild
	# Ideally we might want a 'full_refresh' signal, but emitting individual changes works
	for i in range(_max_slots):
		var slot = _slots[i]
		if slot:
			inventory_changed.emit(i, slot.item, slot.count)
		else:
			inventory_changed.emit(i, null, 0)

## Count total quantity of a specific item across all slots
func count_item(item_id: String) -> int:
	var total = 0
	for slot_data in _slots:
		if slot_data != null and slot_data.item.id == item_id:
			total += slot_data.count
	return total

## Remove a quantity of an item by ID across all slots. Returns true if successful.
func consume_item(item_id: String, count: int = 1) -> bool:
	if count_item(item_id) < count:
		return false
	
	var remaining = count
	for i in range(_max_slots):
		if remaining <= 0:
			break
			
		var slot_data = _slots[i]
		if slot_data != null and slot_data.item.id == item_id:
			var to_remove = min(remaining, slot_data.count)
			var removed_item = slot_data.item
			
			slot_data.count -= to_remove
			remaining -= to_remove
			
			if slot_data.count <= 0:
				_slots[i] = null
				inventory_changed.emit(i, null, 0)
			else:
				inventory_changed.emit(i, slot_data.item, slot_data.count)
				
			item_removed.emit(removed_item, i, to_remove)
	
	return true
