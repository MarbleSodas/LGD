class_name RatMoveState
extends State

@export var arrival_threshold: float = 4.0

func enter() -> void:
	var rat: RatAssistant = entity as RatAssistant
	if rat:
		# Recalculate target position from coords to ensure it's up to date
		if rat.tile_map:
			rat.target_position = rat.tile_map.map_to_local(rat.target_coords)

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
	match rat.current_task:
		RatAssistant.TaskType.HARVEST:
			transition_requested.emit(self, "harvest")
			
		RatAssistant.TaskType.DEPOSIT:
			transition_requested.emit(self, "deposit")
			
		_:
			# Unknown task? Go idle.
			transition_requested.emit(self, "idle")
