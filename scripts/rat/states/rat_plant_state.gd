class_name RatPlantState
extends State

@export var plant_duration: float = 0.5

var _timer: float = 0.0

func enter() -> void:
	_timer = 0.0
	var rat: RatAssistant = entity as RatAssistant
	if rat and rat.visuals:
		rat.visuals.reset_bob()

func update(delta: float) -> void:
	_timer += delta
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _timer >= plant_duration:
		_complete_planting(rat)

func _complete_planting(rat: RatAssistant) -> void:
	# 1. Identify what to plant
	var item_id: String = ""
	
	# Assuming RatInventory structure (dictionary based)
	if "items" in rat.inventory:
		if not rat.inventory.items.is_empty():
			# Prioritize the item that matches the buildable if possible, 
			# but simplistic first item check is what we had.
			# Better: Find FIRST item that is plantable.
			for id in rat.inventory.items:
				if _get_plantable_id_for_item(id) != "":
					item_id = id
					break
			
			# Fallback if no plantable item found (shouldn't happen if task was assigned correctly)
			if item_id == "" and not rat.inventory.items.is_empty():
				item_id = rat.inventory.items.keys()[0]
			
	if item_id == "":
		transition_requested.emit(self, "idle")
		return
		
	var buildable_id: String = _get_plantable_id_for_item(item_id)
	
	if buildable_id != "":
		# Determine actual planting coordinates
		var plant_coords: Vector2i = rat.output_coords
		
		# Distance check to verify where we actually are
		var dist_to_target: float = rat.global_position.distance_to(rat.tile_map.map_to_local(rat.target_coords))
		var dist_to_output: float = rat.global_position.distance_to(rat.tile_map.map_to_local(rat.output_coords))
		
		if dist_to_target < dist_to_output:
			plant_coords = rat.target_coords
		
		# Double check if tile is empty
		if rat.planting_system and not rat.planting_system.is_tile_occupied(plant_coords):
			# 3. Plant
			var success: bool = rat.planting_system.plant_item_at(plant_coords, buildable_id)
			if success:
				# Consume seed
				rat.inventory.remove_item(item_id, 1)
				rat.task_completed.emit(plant_coords)
	
	# Transition Logic
	if rat.inventory.is_empty():
		transition_requested.emit(self, "idle")
		if rat.home_building:
			rat.home_building.on_rat_idle(rat)
	else:
		# Has more seeds. Go idle to get next task
		transition_requested.emit(self, "idle")
		if rat.home_building:
			rat.home_building.on_rat_idle(rat)

func _get_plantable_id_for_item(item_id: String) -> String:
	# Fast path for known conversions
	if item_id == "acorn": return "tree"
	
	# Generic Registry lookup
	if BuildRegistry:
		var bid: String = BuildRegistry.get_buildable_id_from_cost(item_id)
		# Enforce plant-only check using our new helper
		if bid != "" and BuildRegistry.has_method("is_buildable_a_plant"):
			if BuildRegistry.is_buildable_a_plant(bid):
				return bid
			else:
				return "" # Reject buildings (processors, barrels, etc)
		
		return bid # Fallback if helper doesn't exist (safety)
				
	return ""
