class_name StorageBuilding
extends Sprite2D

## Base class for buildable storage structures (barrels, chests, etc.)
## Handles interaction and container management.

@export var storage_slots: int = 30

var container: ContainerInventory
var is_interacting: bool = false
var _current_panel: Control = null

func _ready() -> void:
	# Initialize the container
	container = ContainerInventory.new(storage_slots)

## Called by PlantingSystem when player interacts
func interact() -> void:
	print("StorageBuilding: interact() called")
	is_interacting = true
	
	# Find the ContainerPanel in the UI and open it
	# We assume the UI structure is known or we can find it via group/singleton
	# For now, let's look for it in the scene tree
	
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		var container_panel = ui_layer.get_node_or_null("ContainerPanel")
		if container_panel:
			print("StorageBuilding: Found ContainerPanel via group")
			_current_panel = container_panel
			container_panel.open(container, "Storage Barrel", self) # TODO: Make title configurable
			return
			
	# Fallback search if group not set
	var ui = get_tree().current_scene.get_node_or_null("UI")
	if ui:
		var panel = ui.get_node_or_null("ContainerPanel")
		if panel:
			print("StorageBuilding: Found ContainerPanel via current_scene")
			_current_panel = panel
			panel.open(container, "Storage Barrel", self)
		else:
			print("StorageBuilding: ContainerPanel not found in UI")
	else:
		print("StorageBuilding: UI node not found in current_scene")

func close_interaction() -> void:
	if _current_panel and _current_panel.get("is_open"):
		_current_panel.close()

func on_ui_closed() -> void:
	is_interacting = false
	_current_panel = null
	_notify_interaction_manager_closed()

func _notify_interaction_manager_closed() -> void:
	var planting_system = get_tree().get_first_node_in_group("planting_system")
	if not planting_system:
		var root = get_tree().current_scene
		if root.has_node("PlantingSystem"):
			planting_system = root.get_node("PlantingSystem")
	if planting_system and planting_system.interaction_manager:
		planting_system.interaction_manager.on_building_closed(self)

func get_container() -> ContainerInventory:
	return container

## Returns true if the container has any items to harvest
func is_harvest_ready() -> bool:
	if not container: return false
	return not container.is_empty()

## Harvest items from the container (up to max_amount)
## Returns dictionary with harvested items: { "item_id": id, "amount": amt, "extra_items": [...] }
func harvest(max_amount: int = 10) -> Dictionary:
	if not container or container.is_empty():
		return {}
	
	var harvested_items: Array = []
	var remaining = max_amount
	
	# Take items from container until we hit capacity
	# Iterate backwards or iterate a copy to avoid index issues? 
	# The container logic shifts things or just clears slots? 
	# Looking at ContainerInventory.remove_item, it just clears or reduces count.
	# We iterate slot indices.
	
	for i in range(container.slot_count):
		if remaining <= 0:
			break
			
		var slot = container.get_slot(i)
		if slot == null: # ContainerInventory uses null for empty slots
			continue
		
		var available = slot.count
		var take_amount = mini(available, remaining)
		var item_id = slot.item.id
		
		container.remove_item(i, take_amount) # Using public API
		
		# Consolidate with existing harvested items or just append?
		# Simple append is fine, RatAssistant will handle.
		harvested_items.append({"item_id": item_id, "amount": take_amount})
		remaining -= take_amount
	
	if harvested_items.is_empty():
		return {}
	
	# Format result
	var result = {
		"item_id": harvested_items[0]["item_id"],
		"amount": harvested_items[0]["amount"]
	}
	
	if harvested_items.size() > 1:
		result["extra_items"] = harvested_items.slice(1)
		
	return result

# --- Save/Load Support ---

# These are called by PlantingSystem during save/load

func get_save_data() -> Dictionary:
	return {
		"container": container.to_save_data()
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("container"):
		container.from_save_data(data["container"])
