extends Node

## Emitted when a new item is unlocked
signal buildable_unlocked(item: BuildableItem)

## Emitted when a hotbar slot assignment changes
## item is null if the slot is cleared
signal hotbar_changed(slot: int, item: BuildableItem)

## Emitted when the active buildable item changes
## item is null if deactivated (empty hand/non-build tool)
signal active_buildable_changed(item: BuildableItem)

## Dictionary of all loaded items: {id: BuildableItem}
var _all_items: Dictionary = {}

## Array of unlocked item IDs
var _unlocked_ids: Array[String] = []

## Dictionary mapping hotbar slot index (0-9) to BuildableItem (or null)
var _hotbar: Dictionary = {}

## The currently active item for placement
var active_buildable: BuildableItem = null : set = _set_active_buildable

func _ready() -> void:
	_init_hotbar()
	_load_buildables()
	
	# Default starting state: Unlock Dandelion and bind to slot 0 (key '1')
	_unlock_default_items()

## Initialize empty hotbar
func _init_hotbar() -> void:
	for i in range(10):
		_hotbar[i] = null

## Load all buildable resources from the resources/buildables folder
func _load_buildables() -> void:
	var path = "res://resources/buildables/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				# Strip .remap extension for exported projects
				var load_path = path + file_name.replace(".remap", "")
				var item = load(load_path) as BuildableItem
				if item and item.id != "":
					_all_items[item.id] = item
			file_name = dir.get_next()
	else:
		push_error("BuildRegistry: Could not open " + path)

## Unlock initial items
func _unlock_default_items() -> void:
	if _all_items.has("dandelion"):
		unlock_item("dandelion")
		# Assign to first slot by default for better UX
		assign_to_hotbar(0, _all_items["dandelion"])
		
	if _all_items.has("barrel"):
		unlock_item("barrel")
		assign_to_hotbar(1, _all_items["barrel"])

# --- Public API ---

## Get an item by ID
func get_item(id: String) -> BuildableItem:
	return _all_items.get(id)

## Get all unlocked items (sorted by ID or load order)
func get_unlocked_items() -> Array[BuildableItem]:
	var items: Array[BuildableItem] = []
	for id in _unlocked_ids:
		if _all_items.has(id):
			items.append(_all_items[id])
	return items

## Check if an item is unlocked
func is_unlocked(id: String) -> bool:
	return id in _unlocked_ids

## Unlock an item by ID
func unlock_item(id: String) -> void:
	if not _all_items.has(id):
		push_warning("BuildRegistry: Cannot unlock unknown item " + id)
		return
		
	if not id in _unlocked_ids:
		_unlocked_ids.append(id)
		buildable_unlocked.emit(_all_items[id])

## Assign an item to a hotbar slot
func assign_to_hotbar(slot: int, item: BuildableItem) -> void:
	if slot < 0 or slot >= 10:
		return
		
	# If this item is already bound to another slot, clear that slot first
	# (Optional: depends on if we want to allow duplicates. Let's assume unique binding for now)
	var existing_slot = get_slot_for_item(item)
	if existing_slot != -1 and existing_slot != slot:
		unassign_from_hotbar(existing_slot)
	
	_hotbar[slot] = item
	hotbar_changed.emit(slot, item)

## Unassign whatever is in the slot
func unassign_from_hotbar(slot: int) -> void:
	if slot < 0 or slot >= 10:
		return
	
	if _hotbar[slot] != null:
		_hotbar[slot] = null
		hotbar_changed.emit(slot, null)

## Get the item assigned to a slot
func get_hotbar_item(slot: int) -> BuildableItem:
	return _hotbar.get(slot)

## Find which slot contains the item (returns -1 if not found)
func get_slot_for_item(item: BuildableItem) -> int:
	for slot in _hotbar:
		if _hotbar[slot] == item:
			return slot
	return -1

## Set the active buildable item
func set_active(item: BuildableItem) -> void:
	active_buildable = item

## Clear the active buildable
func clear_active() -> void:
	active_buildable = null

# --- Internal ---

func _set_active_buildable(val: BuildableItem) -> void:
	if active_buildable != val:
		active_buildable = val
		active_buildable_changed.emit(active_buildable)
