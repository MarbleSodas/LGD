class_name RatHarvestState
extends State

@export var harvest_duration: float = 0.8

var _timer: float = 0.0
var _current_duration: float = 0.0

func enter() -> void:
	_timer = 0.0
	_current_duration = harvest_duration
	
	var rat: RatAssistant = entity as RatAssistant
	if rat:
		# Determine dynamic duration from target
		var obj = rat.target_container
		if not obj and rat.planting_system:
			obj = rat.planting_system.get_object_at(rat.target_coords)
			
		if obj and "harvest_time" in obj:
			_current_duration = obj.harvest_time
		
		if rat.visuals:
			rat.visuals.reset_bob()

func update(delta: float) -> void:
	_timer += delta
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _timer >= _current_duration:
		_complete_harvest(rat)

func _complete_harvest(rat: RatAssistant) -> void:
	var obj = rat.target_container
	if not obj and rat.planting_system:
		obj = rat.planting_system.get_object_at(rat.target_coords)
	
	if obj and obj.has_method("harvest"):
		var drops: Dictionary = {}
		
		# Calculate capacity
		var space_left: int = 0
		if rat.inventory.has_method("get_remaining_capacity"):
			space_left = rat.inventory.get_remaining_capacity()
		else:
			space_left = rat.inventory.max_capacity - rat.inventory.get_total_count()

		# Check if it's a storage building (container) or plant
		if obj.has_method("get_container"):
			# Storage/Processor: Pass limit
			drops = obj.harvest(space_left)
		else:
			# Plant: Standard harvest
			# Check if we have enough space for the harvest
			var estimated_amount: int = 1
			if "harvest_amount" in obj:
				estimated_amount = obj.harvest_amount
			
			# If harvesting would exceed capacity (strict check)
			if space_left < estimated_amount:
				# Try to deposit immediately
				var deposit_assigned: bool = false
				if rat.home_building and rat.home_building.has_method("try_assign_deposit"):
					deposit_assigned = rat.home_building.try_assign_deposit(true) # Force assign
				
				if deposit_assigned:
					# Deposit task assigned successfully.
					# The assign_task call triggers transition to 'move', so we just return.
					return
				
				# If we couldn't assign deposit (e.g. outputs full), go to Idle.
				rat.task_completed.emit(rat.target_coords) # Optional: signal we are done here (failed/skipped)
				transition_requested.emit(self, "idle")
				return

			if space_left > 0:
				drops = obj.harvest()
			
		if not drops.is_empty():
			var item_id: String = drops.get("item_id", "")
			var amount: int = drops.get("amount", 1)
			rat.inventory.add_item(item_id, amount)
			
			if drops.has("extra_items"):
				for extra in drops["extra_items"]:
					rat.inventory.add_item(extra["item_id"], extra["amount"])
		
		# Check if plant was consumed (non-regrowing)
		# Note: StorageBuildings don't get removed on harvest
		if obj is Plant and not obj.get("regrows"):
			if rat.planting_system:
				rat.planting_system.remove_object(rat.target_coords)
			if rat.tile_map:
				rat.tile_map.set_cell(rat.target_coords, 0, Vector2i.ZERO)

	rat.task_completed.emit(rat.target_coords)
	
	# Try to get next task immediately without going to idle
	if rat.home_building and rat.home_building.has_method("assign_next_task"):
		if rat.home_building.assign_next_task(true):
			# Task assigned successfully, transitioned to 'move'
			return

	# If no task found, go to Idle to wait
	transition_requested.emit(self, "idle")
