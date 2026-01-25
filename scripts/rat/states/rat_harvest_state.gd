class_name RatHarvestState
extends State

@export var harvest_duration: float = 0.8

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
	
	if _timer >= harvest_duration:
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
	
	# Always go to Idle to get next assignment
	transition_requested.emit(self, "idle")
