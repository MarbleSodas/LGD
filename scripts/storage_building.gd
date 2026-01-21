class_name StorageBuilding
extends Sprite2D

## Base class for buildable storage structures (barrels, chests, etc.)
## Handles interaction and container management.

@export var storage_slots: int = 30

var container: ContainerInventory

func _ready() -> void:
	# Initialize the container
	container = ContainerInventory.new(storage_slots)

## Called by PlantingSystem when player interacts
func interact() -> void:
	print("StorageBuilding: interact() called")
	# Find the ContainerPanel in the UI and open it
	# We assume the UI structure is known or we can find it via group/singleton
	# For now, let's look for it in the scene tree
	
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		var container_panel = ui_layer.get_node_or_null("ContainerPanel")
		if container_panel:
			print("StorageBuilding: Found ContainerPanel via group")
			container_panel.open(container, "Storage Barrel") # TODO: Make title configurable
			return
			
	# Fallback search if group not set
	var ui = get_tree().current_scene.get_node_or_null("UI")
	if ui:
		var panel = ui.get_node_or_null("ContainerPanel")
		if panel:
			print("StorageBuilding: Found ContainerPanel via current_scene")
			panel.open(container, "Storage Barrel")
		else:
			print("StorageBuilding: ContainerPanel not found in UI")
	else:
		print("StorageBuilding: UI node not found in current_scene")

func get_container() -> ContainerInventory:
	return container

# --- Save/Load Support ---

# These are called by PlantingSystem during save/load

func get_save_data() -> Dictionary:
	return {
		"container": container.to_save_data()
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("container"):
		container.from_save_data(data["container"])
