class_name BuildingBase
extends DirectionalBuilding

## Abstract base class for interactive buildings.
## Handles common UI interaction, harvesting, and Rat AI interfaces.

const GROUP_PLANTING_SYSTEM: String = "planting_system"
const GROUP_UI_LAYER: String = "ui_layer"

# State
var is_interacting: bool = false

# ------------------------------------------------------------------------------
# Virtual Methods (Subclasses MUST override)
# ------------------------------------------------------------------------------

## Returns the menu node responsible for this building's UI
func get_menu_node() -> Control:
	return null

## Called when interact() triggers. Subclass handles specific menu.open() call.
func _open_menu(_menu: Control) -> void:
	pass

## Returns the inventory to be harvested (Output for Processor, Container for Storage)
func get_harvest_inventory() -> ContainerInventory:
	return null

# ------------------------------------------------------------------------------
# Interaction API
# ------------------------------------------------------------------------------

func interact() -> void:
	var menu = get_menu_node()
	if menu:
		is_interacting = true
		_open_menu(menu)
	else:
		push_warning("BuildingBase: No menu node found for %s" % name)

func close_interaction() -> void:
	var menu = get_menu_node()
	if menu and menu.has_method("close") and menu.get("is_open"):
		menu.close()

func on_ui_closed() -> void:
	is_interacting = false
	_notify_interaction_manager_closed()

func _notify_interaction_manager_closed() -> void:
	var planting_system = get_tree().get_first_node_in_group(GROUP_PLANTING_SYSTEM)
	if not planting_system:
		# Fallback search
		var root = get_tree().current_scene
		if root and root.has_node("PlantingSystem"):
			planting_system = root.get_node("PlantingSystem")
	
	if planting_system and planting_system.interaction_manager:
		planting_system.interaction_manager.on_building_closed(self)

# ------------------------------------------------------------------------------
# Harvest Logic (Shared)
# ------------------------------------------------------------------------------

func is_harvest_ready() -> bool:
	var inv = get_harvest_inventory()
	return inv and not inv.is_empty()

func harvest(max_amount: int = 10) -> Dictionary:
	var inventory = get_harvest_inventory()
	if not inventory or inventory.is_empty():
		return {}

	var harvested_items: Array[Dictionary] = []
	var remaining: int = max_amount

	for i in range(inventory.slot_count):
		if remaining <= 0: break

		var slot = inventory.get_slot(i)
		if slot == null: continue

		var available = slot.count
		var take_amount = mini(available, remaining)
		var item_id = slot.item.id

		inventory.remove_item(i, take_amount)

		harvested_items.append({"item_id": item_id, "amount": take_amount})
		remaining -= take_amount

	if harvested_items.is_empty():
		return {}

	var result = {
		"item_id": harvested_items[0]["item_id"],
		"amount": harvested_items[0]["amount"]
	}

	if harvested_items.size() > 1:
		result["extra_items"] = harvested_items.slice(1)

	return result

# ------------------------------------------------------------------------------
# Rat AI Interface (Shared)
# ------------------------------------------------------------------------------

func get_deposit_tile() -> Vector2i:
	return get_input_tile()

func get_harvest_tile() -> Vector2i:
	return get_output_tile()

# ------------------------------------------------------------------------------
# Save/Load Helpers
# ------------------------------------------------------------------------------

func get_base_save_data() -> Dictionary:
	return {
		"is_flipped": is_flipped,
		"center_tile_x": center_tile.x,
		"center_tile_y": center_tile.y,
		"version": 2
	}

func load_base_save_data(data: Dictionary) -> void:
	if data.has("is_flipped"):
		is_flipped = data["is_flipped"]
	
	if data.has("center_tile_x") and data.has("center_tile_y"):
		center_tile = Vector2i(data["center_tile_x"], data["center_tile_y"])
	
	_update_orientation()
