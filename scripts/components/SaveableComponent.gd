@tool
class_name SaveableComponent
extends Node

## Aggregates save data from sibling components.
## Parent object uses this to implement save/load persistence.

@export var save_version: int = 2

func get_save_data() -> Dictionary:
	var data = {
		"version": save_version
	}
	
	var parent = get_parent()
	if not parent: return data
	
	# Iterate all children of parent (siblings)
	for child in parent.get_children():
		if child == self: continue
		
		# If sibling has get_save_data, merge it
		if child.has_method("get_save_data"):
			var child_data = child.get_save_data()
			if child_data is Dictionary:
				data.merge(child_data)
				
	# Also grab parent's basic data if needed (position is usually handled by SaveManager, 
	# but legacy buildings saved center_tile/flipped status)
	# The legacy BuildingBase.get_base_save_data handled center_tile/is_flipped.
	# FootprintComponent now handles that, so it should be picked up above.
	
	return data

func load_save_data(data: Dictionary) -> void:
	var parent = get_parent()
	if not parent: return
	
	for child in parent.get_children():
		if child == self: continue
		
		if child.has_method("load_save_data"):
			child.load_save_data(data)
