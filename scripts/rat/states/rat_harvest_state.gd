class_name RatHarvestState
extends State

@export var harvest_duration: float = 0.8

var _timer: float = 0.0

func enter() -> void:
	_timer = 0.0
	var rat: RatAssistant = entity as RatAssistant
	if rat:
		# Safety check: if full, go deposit immediately
		if rat.inventory.is_full():
			if rat.output_coords != Vector2i.ZERO:
				transition_requested.emit(self, "movetooutput")
			else:
				transition_requested.emit(self, "idle")
			return

	if rat and rat.visuals:
		rat.visuals.reset_bob()

func update(delta: float) -> void:
	_timer += delta
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _timer >= harvest_duration:
		_complete_harvest(rat)

func _complete_harvest(rat: RatAssistant) -> void:
	var source_obj: Node2D = rat.planting_system.get_object_at(rat.target_coords) if rat.planting_system else null
	
	if source_obj and source_obj.has_method("harvest"):
		var drops: Dictionary = {}
		
		# Always pass capacity limit, even for plants
		var space_left: int = 0
		if rat.inventory.has_method("get_remaining_capacity"):
			space_left = rat.inventory.get_remaining_capacity()
		else:
			space_left = rat.inventory.max_capacity - rat.inventory.get_total_count()

		# Check if it's a storage building (pass capacity)
		if source_obj.has_method("get_container"):
			drops = source_obj.harvest(space_left)
		else:
			# For plants (or anything else), check if harvest accepts argument
			# Note: Standard Plant.harvest() doesn't take arguments, so we can't force partial harvest there.
			# But we CAN check if we have space before calling it.
			if space_left > 0:
				drops = source_obj.harvest()
			else:
				# No space! Abort harvest logic, treat as completed but nothing gained
				pass
			
		if not drops.is_empty():
			var item_id: String = drops.get("item_id", "")
			var amount: int = drops.get("amount", 1)
			rat.inventory.add_item(item_id, amount)
			
			if drops.has("extra_items"):
				for extra in drops["extra_items"]:
					rat.inventory.add_item(extra["item_id"], extra["amount"])
		
		# Check if plant was consumed (non-regrowing)
		if source_obj is Plant and not source_obj.get("regrows"):
			if rat.planting_system:
				rat.planting_system.remove_object(rat.target_coords)
			if rat.tile_map:
				rat.tile_map.set_cell(rat.target_coords, 0, Vector2i.ZERO)

	rat.task_completed.emit(rat.target_coords)
	
	if rat.inventory.is_full():
		if rat.output_coords != Vector2i.ZERO:
			transition_requested.emit(self, "movetooutput")
		else:
			transition_requested.emit(self, "idle")
	else:
		# Try to get more work
		transition_requested.emit(self, "idle")
		if rat.home_building and rat.home_building.has_method("assign_next_task_nearby"):
			rat.home_building.assign_next_task_nearby(rat)
		
		# If state changed during that call, great. If not, and we have items, check if we should dump them.
		if rat.state_machine.current_state.name.to_lower() == "idle":
			if rat.inventory.has_items():
				transition_requested.emit(self, "movetooutput")
