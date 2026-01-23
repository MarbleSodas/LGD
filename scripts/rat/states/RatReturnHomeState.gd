class_name RatReturnHomeState
extends State

@export var arrival_threshold: float = 4.0

func enter() -> void:
	var rat = entity as RatAssistant
	if rat:
		# Drop items? Original code: inventory.clear() + update visual
		rat.inventory.clear()
		if rat.visuals: rat.visuals.update_held_item_visual()

func physics_update(delta: float) -> void:
	var rat = entity as RatAssistant
	if not rat: return
	
	if not rat.home_building:
		transition_requested.emit(self, "idle")
		return

	var destination = rat.home_building.global_position
	if rat.home_building.has_method("get_rest_position"):
		destination = rat.home_building.get_rest_position()
		
	var distance = rat.global_position.distance_to(destination)
	
	if distance <= arrival_threshold:
		rat.velocity = Vector2.ZERO
		
		# Only drop items if we actually arrived home? 
		# Original logic: return_home() dropped items immediately.
		# _on_arrived_at_output failure -> RETURNING_HOME. 
		# If we arrive home, we are Idle.
		transition_requested.emit(self, "idle")
		return
	
	var direction = (destination - rat.global_position).normalized()
	rat.velocity = direction * rat.move_speed
	rat.move_and_slide()
	
	if rat.visuals:
		rat.visuals.set_facing_direction(direction)
		rat.visuals.update_bob(delta, true)
