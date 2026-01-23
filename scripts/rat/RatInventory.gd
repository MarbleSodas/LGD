class_name RatInventory
extends Node

signal inventory_changed
signal full_capacity_reached

@export var max_capacity: int = 10

## Format: { item_id (String): amount (int) }
var items: Dictionary = {}

func add_item(item_id: String, amount: int) -> void:
	if item_id == "": return
	
	if items.has(item_id):
		items[item_id] += amount
	else:
		items[item_id] = amount
	
	inventory_changed.emit()
	
	if is_full():
		full_capacity_reached.emit()

func clear() -> void:
	items.clear()
	inventory_changed.emit()

func has_items() -> bool:
	return not items.is_empty()

func get_total_count() -> int:
	var total = 0
	for count in items.values():
		total += count
	return total

func is_full() -> bool:
	return get_total_count() >= max_capacity

func get_first_item_id() -> String:
	if items.is_empty():
		return ""
	return items.keys()[0]
