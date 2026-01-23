class_name ContainerInventory
extends Resource

## Instance-based inventory for storage containers (chests, barrels, etc.)
## Mirrors the API of the Inventory autoload for compatibility

signal slot_changed(slot_index: int, item: InventoryItem, count: int)
signal item_added(item: InventoryItem, slot: int, count: int)
signal item_removed(item: InventoryItem, slot: int, count: int)

@export var slot_count: int = 30
var _slots: Array = []

func _init(p_slot_count: int = 30) -> void:
	slot_count = p_slot_count
	_init_slots()

func _init_slots() -> void:
	_slots.clear()
	for i in range(slot_count):
		_slots.append(null)

# --- Public API ---

func add_item(item: InventoryItem, count: int = 1) -> int:
	if item == null or count <= 0:
		return -1
	
	var remaining = count
	
	# 1. Stack with existing
	if item.max_stack > 1:
		for i in range(slot_count):
			if _slots[i] != null and _slots[i].item.id == item.id:
				var space = item.max_stack - _slots[i].count
				if space > 0:
					var to_add = min(remaining, space)
					_slots[i].count += to_add
					remaining -= to_add
					slot_changed.emit(i, _slots[i].item, _slots[i].count)
					
					if remaining <= 0:
						item_added.emit(item, i, count)
						return i
	
	# 2. Find empty slots
	while remaining > 0:
		var empty_slot = get_first_empty_slot()
		if empty_slot == -1:
			if remaining < count:
				item_added.emit(item, -1, count - remaining)
			return -1
		
		var to_add = min(remaining, item.max_stack)
		_slots[empty_slot] = {item = item, count = to_add}
		remaining -= to_add
		slot_changed.emit(empty_slot, item, to_add)
		
		if remaining <= 0:
			item_added.emit(item, empty_slot, count)
			return empty_slot
	
	return -1

func add_item_quantity(item: InventoryItem, count: int) -> int:
	if item == null or count <= 0:
		return 0
	
	var remaining = count
	var total_added = 0
	
	# 1. Stack with existing
	if item.max_stack > 1:
		for i in range(slot_count):
			if _slots[i] != null and _slots[i].item.id == item.id:
				var space = item.max_stack - _slots[i].count
				if space > 0:
					var to_add = min(remaining, space)
					_slots[i].count += to_add
					remaining -= to_add
					total_added += to_add
					slot_changed.emit(i, _slots[i].item, _slots[i].count)
					
					if remaining <= 0:
						item_added.emit(item, i, count)
						return total_added
	
	# 2. Empty slots
	while remaining > 0:
		var empty_slot = get_first_empty_slot()
		if empty_slot == -1:
			break
		
		var to_add = min(remaining, item.max_stack)
		_slots[empty_slot] = {item = item, count = to_add}
		remaining -= to_add
		total_added += to_add
		slot_changed.emit(empty_slot, item, to_add)
	
	if total_added > 0:
		item_added.emit(item, -1, total_added)
		
	return total_added

func remove_item(slot: int, count: int = 1) -> Dictionary:
	if slot < 0 or slot >= slot_count or _slots[slot] == null:
		return {}
	
	var slot_data = _slots[slot]
	var to_remove = min(count, slot_data.count)
	var removed_item = slot_data.item
	
	slot_data.count -= to_remove
	
	if slot_data.count <= 0:
		_slots[slot] = null
		slot_changed.emit(slot, null, 0)
	else:
		slot_changed.emit(slot, slot_data.item, slot_data.count)
	
	item_removed.emit(removed_item, slot, to_remove)
	return {item = removed_item, count = to_remove}

func get_slot(slot: int) -> Variant:
	if slot < 0 or slot >= slot_count:
		return null
	return _slots[slot]

func set_slot(slot: int, item: InventoryItem, count: int) -> void:
	if slot < 0 or slot >= slot_count:
		return
	
	if item == null or count <= 0:
		_slots[slot] = null
		slot_changed.emit(slot, null, 0)
	else:
		_slots[slot] = {item = item, count = count}
		slot_changed.emit(slot, item, count)

func get_first_empty_slot() -> int:
	for i in range(slot_count):
		if _slots[i] == null:
			return i
	return -1

func is_full() -> bool:
	return get_first_empty_slot() == -1

func is_empty() -> bool:
	for slot in _slots:
		if slot != null:
			return false
	return true

func count_item(item_id: String) -> int:
	var total = 0
	for slot_data in _slots:
		if slot_data != null and slot_data.item.id == item_id:
			total += slot_data.count
	return total

# Category order for sorting (mirrors Inventory autoload)
const CATEGORY_ORDER = ["seed", "crop", "material", "tool", "decoration"]

func sort_inventory() -> void:
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
			consolidated.append({item = slot.item, count = slot.count})
			
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
	for i in range(slot_count):
		if i < consolidated.size():
			_slots[i] = consolidated[i]
			slot_changed.emit(i, _slots[i].item, _slots[i].count)
		else:
			_slots[i] = null
			slot_changed.emit(i, null, 0)

# --- Save/Load ---

func to_save_data() -> Array:
	var slots_data = []
	for slot in _slots:
		if slot == null:
			slots_data.append(null)
		else:
			slots_data.append({
				"item_id": slot.item.id,
				"count": slot.count
			})
	return slots_data

func from_save_data(data: Array) -> void:
	_slots.clear()
	for slot_data in data:
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
				_slots.append(null)
	
	# Ensure size matches
	while _slots.size() < slot_count:
		_slots.append(null)
	
	# Notify listeners
	for i in range(slot_count):
		if _slots[i]:
			slot_changed.emit(i, _slots[i].item, _slots[i].count)
		else:
			slot_changed.emit(i, null, 0)
