extends Node

## Global registry for buildable items (buildings, plants, etc.).
##
## Manages unlocking items and the hotbar system.
## Loads items from resources/buildables directory.

## Emitted when a new item is unlocked
signal buildable_unlocked(item: BuildableItem)

## Emitted when a hotbar slot assignment changes
## item is null if the slot is cleared
signal hotbar_changed(slot: int, item: BuildableItem)

## Emitted when the active buildable item changes
## item is null if deactivated (empty hand/non-build tool)
signal active_buildable_changed(item: BuildableItem)

const BUILDABLES_PATH: String = "res://resources/buildables/"
const HOTBAR_SIZE: int = 10

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
	for i in range(HOTBAR_SIZE):
		_hotbar[i] = null

## Load all buildable resources from the resources/buildables folder
func _load_buildables() -> void:
	var dir: DirAccess = DirAccess.open(BUILDABLES_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				# Strip .remap extension for exported projects
				var load_path: String = BUILDABLES_PATH + file_name.replace(".remap", "")
				var item: BuildableItem = load(load_path) as BuildableItem
				if item and item.id != "":
					_all_items[item.id] = item
			file_name = dir.get_next()
	else:
		push_error("BuildRegistry: Could not open " + BUILDABLES_PATH)

## Unlock initial items
func _unlock_default_items() -> void:
	if _all_items.has("dandelion"):
		unlock_item("dandelion")
		# Assign to first slot by default for better UX
		assign_to_hotbar(0, _all_items["dandelion"])
		
	if _all_items.has("barrel"):
		unlock_item("barrel")
		assign_to_hotbar(1, _all_items["barrel"])

	if _all_items.has("mushroom_house"):
		unlock_item("mushroom_house")
		assign_to_hotbar(2, _all_items["mushroom_house"])

	if _all_items.has("tree"):
		unlock_item("tree")
		assign_to_hotbar(3, _all_items["tree"])

	if _all_items.has("mushroom_plant"):
		unlock_item("mushroom_plant")
		assign_to_hotbar(4, _all_items["mushroom_plant"])

	if _all_items.has("processor"):
		unlock_item("processor")
		assign_to_hotbar(5, _all_items["processor"])

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

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
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
		
	# If this item is already bound to another slot, clear that slot first
	# (Unique binding rule)
	var existing_slot: int = get_slot_for_item(item)
	if existing_slot != -1 and existing_slot != slot:
		unassign_from_hotbar(existing_slot)
	
	_hotbar[slot] = item
	hotbar_changed.emit(slot, item)

## Unassign whatever is in the slot
func unassign_from_hotbar(slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
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

## Find a buildable ID that can be built using the specified item as a primary cost.
## Useful for rats to determine what to plant based on seeds they are holding.
func get_buildable_id_from_cost(item_id: String) -> String:
	for id in _unlocked_ids:
		if _all_items.has(id):
			var item: BuildableItem = _all_items[id]
			# Heuristic: If it costs this item, it's likely what we want to plant.
			# We prioritize single-ingredient costs to avoid complex recipes.
			if item.build_costs.size() == 1 and item.build_costs.has(item_id):
				return id
	return ""

## Check if the buildable item is actually a Plant (vs a Building).
## Instantiates the scene temporarily to check its type.
func is_buildable_a_plant(id: String) -> bool:
	if not _all_items.has(id): return false
	
	var item: BuildableItem = _all_items[id]
	if not item.scene: return false
	
	var instance = item.scene.instantiate()
	var is_plant: bool = false
	
	# Check if it inherits from Plant class (by class_name or script)
	if instance.has_method("is_harvest_ready"): # Duck typing for Plant
		is_plant = true
	
	instance.free()
	return is_plant

# ------------------------------------------------------------------------------
# Internal
# ------------------------------------------------------------------------------

func _set_active_buildable(val: BuildableItem) -> void:
	if active_buildable != val:
		active_buildable = val
		active_buildable_changed.emit(active_buildable)
