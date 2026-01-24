class_name RatMoveToSourceState
extends State

@export var arrival_threshold: float = 4.0

func enter() -> void:
	# Recalculate position in case it moved? (Maybe not needed if set once)
	pass

func physics_update(delta: float) -> void:
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	var destination: Vector2 = rat.target_position
	var distance: float = rat.global_position.distance_to(destination)
	
	if distance <= arrival_threshold:
		rat.velocity = Vector2.ZERO
		_on_arrived(rat)
		return
	
	var direction: Vector2 = (destination - rat.global_position).normalized()
	rat.velocity = direction * rat.move_speed
	rat.move_and_slide()
	
	if rat.visuals:
		rat.visuals.set_facing_direction(direction)
		rat.visuals.update_bob(delta, true)

func _on_arrived(rat: RatAssistant) -> void:
	# Check availability
	var plant: Node2D = rat.planting_system.get_object_at(rat.target_coords) if rat.planting_system else null
	
	# If empty tile AND we have items (presumably seeds), we might be here to plant
	if not plant:
		if rat.inventory.has_items():
			transition_requested.emit(self, "plant")
		else:
			_handle_failure(rat)
		return
	
	if not plant.has_method("harvest"):
		_handle_failure(rat)
		return
		
	if plant.has_method("is_harvest_ready") and not plant.is_harvest_ready():
		_handle_failure(rat)
		return
		
	transition_requested.emit(self, "harvest")

func _handle_failure(rat: RatAssistant) -> void:
	if rat.inventory.has_items():
		transition_requested.emit(self, "movetooutput")
	else:
		transition_requested.emit(self, "idle")
		# Logic to try getting another task should be triggered here or in Idle
		# The original code called assign_next_task_nearby from the house.
		if rat.home_building and rat.home_building.has_method("assign_next_task_nearby"):
			rat.home_building.assign_next_task_nearby(rat)
