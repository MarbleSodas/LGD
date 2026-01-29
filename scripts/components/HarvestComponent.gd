@tool
class_name HarvestComponent
extends Node

## Handles harvest logic for plants and buildings.
## Can harvest from fixed configuration or from a linked ContainerComponent.

signal harvest_ready
signal harvested(item_id: String, amount: int)

@export_group("Simple Harvest")
@export var harvest_item_id: String = ""
@export var harvest_amount: int = 1
@export var harvest_time: float = 0.5
@export var regrows: bool = false

@export_group("Container Link")
## If assigned, harvest will pull from this container instead of using simple values.
@export var container_component: ContainerComponent

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# If using container, connect to its changes to emit harvest_ready
	if container_component:
		container_component.slot_changed.connect(_on_container_changed)

func _on_container_changed(_index: int, _item: Resource, _count: int) -> void:
	if is_harvest_ready():
		harvest_ready.emit()

func is_harvest_ready() -> bool:
	if container_component:
		return not container_component.is_empty()
	
	# For simple harvest, usually controlled by GrowthComponent or always ready (StoneDeposit)
	# If no growth component involved, we default to true if item is set
	return not harvest_item_id.is_empty()

## Returns a dictionary { "item_id": str, "amount": int, "extra_items": Array }
func harvest(max_amount: int = 10) -> Dictionary:
	if not is_harvest_ready():
		return {}
		
	if container_component:
		return _harvest_from_container(max_amount)
	else:
		return _harvest_simple()

func _harvest_simple() -> Dictionary:
	var result = {
		"item_id": harvest_item_id,
		"amount": harvest_amount
	}
	
	harvested.emit(harvest_item_id, harvest_amount)
	
	# Regrowth/Consumption logic is often handled by caller or GrowthComponent
	# But we emit the signal so listeners know.
	
	return result

func _harvest_from_container(max_amount: int) -> Dictionary:
	var container = container_component.get_container()
	if not container or container.is_empty():
		return {}

	var harvested_items: Array[Dictionary] = []
	var remaining: int = max_amount

	for i in range(container.slot_count):
		if remaining <= 0: break

		var slot = container.get_slot(i)
		if slot == null: continue

		var available = slot.count
		var take_amount = mini(available, remaining)
		var item_id = slot.item.id

		container.remove_item(i, take_amount)

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
		
	# Emit signal for the primary item (simplification)
	harvested.emit(result["item_id"], result["amount"])

	return result
