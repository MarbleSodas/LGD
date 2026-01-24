class_name RatMoveToOutputState
extends State

@export var arrival_threshold: float = 4.0

func physics_update(delta: float) -> void:
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	var destination: Vector2 = rat.output_position
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
	var building: Node2D = rat.planting_system.get_object_at(rat.output_coords) if rat.planting_system else null
	
	if not building:
		# Empty tile! Assume planting.
		transition_requested.emit(self, "plant")
		return
	
	if not building.has_method("get_container"):
		transition_requested.emit(self, "returnhome")
		return
		
	transition_requested.emit(self, "deposit")
