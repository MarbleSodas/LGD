extends Node

# Merged Registry for InventoryItems and BuildableItems
# Replaces Registries and Registries

# --- Registries Signals ---
# (None existing)

# --- Registries Signals ---
signal buildable_unlocked(item: BuildableItem)
signal hotbar_changed(slot: int, item: BuildableItem)
signal active_buildable_changed(item: BuildableItem)
signal registries_reset

# --- Constants ---
const ITEMS_PATH = "res://resources/items/"
const BUILDABLES_PATH = "res://resources/buildables/"
const HOTBAR_SIZE = 10

# --- Data Storage ---
var _inventory_items: Dictionary = {}
var _buildable_items: Dictionary = {}

# --- Registries State ---
var _unlocked_ids: Array[String] = []
var _unlocked_recipe_ids: Array[String] = []
var _hotbar: Dictionary = {}
var active_buildable: BuildableItem = null : 
	set(val):
		if active_buildable != val:
			active_buildable = val
			active_buildable_changed.emit(active_buildable)

# Unlock rules: Key = Inventory Item ID, Value = List of Buildable IDs to unlock
var _unlock_rules: Dictionary = {
	"shroom": ["mushroom_plant", "mushroom_house"],
	"acorn": ["tree"],
	"wood": ["barrel", "processor"]
}

# Preferred hotbar slots for auto-assignment
var _preferred_hotbar_slots: Dictionary = {
	"dandelion": 0,
	"mushroom_plant": 1,
	"tree": 2,
	"mushroom_house": 3,
	"barrel": 4,
	"processor": 5
}

func _ready() -> void:
	_load_inventory_items()
	_init_hotbar()
	_load_buildables()
	_unlock_default_items()
	
	# Connect to inventory to handle dynamic unlocks
	call_deferred("_connect_inventory_signals")

# ------------------------------------------------------------------------------
# Inventory Item Logic (formerly Registries)
# ------------------------------------------------------------------------------

func _load_inventory_items() -> void:
	var dir = DirAccess.open(ITEMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				var load_path = ITEMS_PATH + file_name.replace(".remap", "")
				var item = load(load_path) as InventoryItem
				if item and item.id != "":
					_inventory_items[item.id] = item
			file_name = dir.get_next()
	else:
		push_error("Registries: Could not open " + ITEMS_PATH)

func get_item(id: String) -> InventoryItem:
	return _inventory_items.get(id)

# ------------------------------------------------------------------------------
# Buildable Item Logic (formerly Registries)
# ------------------------------------------------------------------------------

func get_buildable(id: String) -> BuildableItem:
	return _buildable_items.get(id)

func _load_buildables() -> void:
	var dir: DirAccess = DirAccess.open(BUILDABLES_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				var load_path: String = BUILDABLES_PATH + file_name.replace(".remap", "")
				var item: BuildableItem = load(load_path) as BuildableItem
				if item and item.id != "":
					_buildable_items[item.id] = item
			file_name = dir.get_next()
	else:
		push_error("Registries: Could not open " + BUILDABLES_PATH)

func _init_hotbar() -> void:
	for i in range(HOTBAR_SIZE):
		_hotbar[i] = null

func _unlock_default_items() -> void:
	# Default starting state
	var defaults = ["dandelion"] # ONLY dandelion initially
	for i in range(defaults.size()):
		var id = defaults[i]
		if _buildable_items.has(id):
			unlock_item(id)
			# Dandelion is 0 in preferred slots, but let's ensure it maps correctly
			if _preferred_hotbar_slots.has(id):
				assign_to_hotbar(_preferred_hotbar_slots[id], _buildable_items[id])
			else:
				assign_to_hotbar(i, _buildable_items[id])

func get_unlocked_items() -> Array[BuildableItem]:
	var items: Array[BuildableItem] = []
	for id in _unlocked_ids:
		if _buildable_items.has(id):
			items.append(_buildable_items[id])
	return items

func is_unlocked(id: String) -> bool:
	return id in _unlocked_ids

func unlock_item(id: String) -> void:
	if not _buildable_items.has(id):
		push_warning("Registries: Cannot unlock unknown item " + id)
		return
		
	if not id in _unlocked_ids:
		_unlocked_ids.append(id)
		buildable_unlocked.emit(_buildable_items[id])
		
		# Auto-assign to preferred hotbar slot if available
		if _preferred_hotbar_slots.has(id):
			var slot = _preferred_hotbar_slots[id]
			# Only assign if the slot is empty or we want to force it?
			# Usually we want to force it to the "correct" slot for this game logic
			assign_to_hotbar(slot, _buildable_items[id])

func assign_to_hotbar(slot: int, item: BuildableItem) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
		
	var existing_slot: int = get_slot_for_item(item)
	if existing_slot != -1 and existing_slot != slot:
		unassign_from_hotbar(existing_slot)
	
	_hotbar[slot] = item
	hotbar_changed.emit(slot, item)

func unassign_from_hotbar(slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	
	if _hotbar[slot] != null:
		_hotbar[slot] = null
		hotbar_changed.emit(slot, null)

func get_hotbar_item(slot: int) -> BuildableItem:
	return _hotbar.get(slot)

func get_slot_for_item(item: BuildableItem) -> int:
	for slot in _hotbar:
		if _hotbar[slot] == item:
			return slot
	return -1

func set_active(item: BuildableItem) -> void:
	active_buildable = item

func clear_active() -> void:
	active_buildable = null

func get_buildable_id_from_cost(item_id: String) -> String:
	for id in _unlocked_ids:
		if _buildable_items.has(id):
			var item: BuildableItem = _buildable_items[id]
			if item.build_costs.size() == 1 and item.build_costs.has(item_id):
				return id
	return ""

func is_buildable_a_plant(id: String) -> bool:
	if not _buildable_items.has(id): return false
	var item: BuildableItem = _buildable_items[id]
	return item.buildable_type == BuildableItem.BuildableType.PLANT

func _set_active_buildable(val: BuildableItem) -> void:
	if active_buildable != val:
		active_buildable = val
		active_buildable_changed.emit(active_buildable)

# ------------------------------------------------------------------------------
# Recipe Unlock Logic
# ------------------------------------------------------------------------------

func is_recipe_unlocked(recipe_path: String) -> bool:
	return recipe_path in _unlocked_recipe_ids

func unlock_recipe(recipe_path: String) -> void:
	if not recipe_path in _unlocked_recipe_ids:
		_unlocked_recipe_ids.append(recipe_path)
		# We could emit a signal here if needed, e.g. recipe_unlocked

# ------------------------------------------------------------------------------
# Unlock Logic
# ------------------------------------------------------------------------------

func _connect_inventory_signals() -> void:
	# Inventory autoload should be available now
	# We use get_node("/root/Inventory") or just the global Inventory if valid
	# Since autoloads are children of root, Inventory should be accessible.
	# Note: In GDScript, the global variable 'Inventory' is auto-generated.
	
	if Inventory:
		if not Inventory.item_added.is_connected(_on_inventory_item_added):
			Inventory.item_added.connect(_on_inventory_item_added)
			
		# Check initial state
		_check_all_unlocks()

func _on_inventory_item_added(item: InventoryItem, _slot: int, _count: int) -> void:
	if item:
		_check_unlocks_for_item(item.id)

func _check_unlocks_for_item(item_id: String) -> void:
	if _unlock_rules.has(item_id):
		var to_unlock = _unlock_rules[item_id]
		for buildable_id in to_unlock:
			if not is_unlocked(buildable_id):
				unlock_item(buildable_id)

func _check_all_unlocks() -> void:
	if not Inventory: return
	
	# Check for existing items in inventory that trigger unlocks
	for item_id in _unlock_rules:
		if Inventory.has_item(item_id):
			_check_unlocks_for_item(item_id)

# ------------------------------------------------------------------------------
# Save/Load Support
# ------------------------------------------------------------------------------

func reset() -> void:
	_unlocked_ids.clear()
	_unlocked_recipe_ids.clear()
	_init_hotbar()
	_unlock_default_items()
	
	# Re-check inventory for existing items (if Inventory wasn't reset yet, this might re-unlock things, 
	# so order of reset matters in SaveManager)
	if Inventory:
		_check_all_unlocks()
	
	# Notify listeners that things might have changed (e.g. hotbar)
	for i in range(HOTBAR_SIZE):
		hotbar_changed.emit(i, _hotbar[i])
		
	registries_reset.emit()

func to_save_data() -> Dictionary:
	var hotbar_data: Dictionary = {}
	for slot in _hotbar:
		if _hotbar[slot] != null:
			hotbar_data[str(slot)] = _hotbar[slot].id
			
	return {
		"unlocked_buildables": _unlocked_ids.duplicate(),
		"unlocked_recipes": _unlocked_recipe_ids.duplicate(),
		"hotbar": hotbar_data
	}

func from_save_data(data: Dictionary) -> void:
	# 1. Restore Unlocked Buildables
	if data.has("unlocked_buildables"):
		var saved_ids: Array = data["unlocked_buildables"]
		for id in saved_ids:
			if not is_unlocked(id):
				# We use unlock_item to ensure signals are emitted
				unlock_item(id)

	# 1.5 Restore Unlocked Recipes
	if data.has("unlocked_recipes"):
		_unlocked_recipe_ids.assign(data["unlocked_recipes"])
	else:
		_unlocked_recipe_ids.clear()
	
	# 2. Restore Hotbar
	if data.has("hotbar"):
		var hotbar_data: Dictionary = data["hotbar"]
		# Clear existing hotbar first to avoid "swapping" logic interfering with restore
		for i in range(HOTBAR_SIZE):
			_hotbar[i] = null
			
		for slot_str in hotbar_data:
			var slot: int = int(slot_str)
			var item_id: String = hotbar_data[slot_str]
			if _buildable_items.has(item_id):
				_hotbar[slot] = _buildable_items[item_id]
				hotbar_changed.emit(slot, _buildable_items[item_id])

	# 3. Robustness check: Ensure all items currently in inventory trigger their unlocks
	# This handles cases where save data might be partial or from an older version
	if Inventory:
		_check_all_unlocks()
