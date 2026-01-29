extends Node

# Merged Registry for InventoryItems and BuildableItems
# Replaces ItemRegistry and BuildRegistry

# --- ItemRegistry Signals ---
# (None existing)

# --- BuildRegistry Signals ---
signal buildable_unlocked(item: BuildableItem)
signal hotbar_changed(slot: int, item: BuildableItem)
signal active_buildable_changed(item: BuildableItem)

# --- Constants ---
const ITEMS_PATH = "res://resources/items/"
const BUILDABLES_PATH = "res://resources/buildables/"
const HOTBAR_SIZE = 10

# --- Data Storage ---
var _inventory_items: Dictionary = {}
var _buildable_items: Dictionary = {}

# --- BuildRegistry State ---
var _unlocked_ids: Array[String] = []
var _hotbar: Dictionary = {}
var active_buildable: BuildableItem = null : set = _set_active_buildable

func _ready() -> void:
	_load_inventory_items()
	_init_hotbar()
	_load_buildables()
	_unlock_default_items()

# ------------------------------------------------------------------------------
# Inventory Item Logic (formerly ItemRegistry)
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
# Buildable Item Logic (formerly BuildRegistry)
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
	var defaults = ["dandelion", "barrel", "mushroom_house", "tree", "mushroom_plant", "processor"]
	for i in range(defaults.size()):
		var id = defaults[i]
		if _buildable_items.has(id):
			unlock_item(id)
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
