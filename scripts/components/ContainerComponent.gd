@tool
class_name ContainerComponent
extends Node

## Wrapper around ContainerInventory resource.
## Manages storage slots and item persistence.

signal slot_changed(slot_index: int, item: InventoryItem, count: int)

@export var slot_count: int = 1:
	set(value):
		slot_count = value
		if container and container.slot_count != value:
			# If we wanted to resize at runtime, we'd do it here.
			# But for now, mainly for init.
			pass

var container: ContainerInventory

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	container = ContainerInventory.new(slot_count)
	container.slot_changed.connect(_on_slot_changed)

func _on_slot_changed(index: int, item: InventoryItem, count: int) -> void:
	slot_changed.emit(index, item, count)

func get_container() -> ContainerInventory:
	return container

func is_full() -> bool:
	if not container: return true
	return container.is_full()

func is_empty() -> bool:
	if not container: return true
	return container.is_empty()

func get_slot(index: int) -> Variant:
	if not container: return null
	return container.get_slot(index)

func add_item(item: InventoryItem, count: int) -> bool:
	if not container: return false
	return container.add_item(item, count)

func remove_item(index: int, count: int) -> void:
	if container:
		container.remove_item(index, count)

# --- Save/Load ---

func get_save_data() -> Dictionary:
	if not container:
		return {}
	return { "container": container.to_save_data() }

func load_save_data(data: Dictionary) -> void:
	if data.has("container") and container:
		container.from_save_data(data["container"])
