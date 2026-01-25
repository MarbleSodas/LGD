class_name RatReturnHomeState
extends State

@export var arrival_threshold: float = 4.0

func enter() -> void:
	var rat: RatAssistant = entity as RatAssistant
	if rat:
		# Drop items? Original code: inventory.clear() + update visual
		# FIX: Don't clear inventory so items persist
		# rat.inventory.clear()
		if rat.visuals: rat.visuals.update_held_item_visual()

func physics_update(delta: float) -> void:
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	if not rat.home_building:
		transition_requested.emit(self, "idle")
		return

	var destination: Vector2 = rat.home_building.global_position
	if rat.home_building.has_method("get_rest_position"):
		destination = rat.home_building.get_rest_position()
		
	var distance: float = rat.global_position.distance_to(destination)
	
	if distance <= arrival_threshold:
		rat.velocity = Vector2.ZERO
		transition_requested.emit(self, "idle")
		return
	
	var direction: Vector2 = (destination - rat.global_position).normalized()
	rat.velocity = direction * rat.move_speed
	rat.move_and_slide()
	
	if rat.visuals:
		rat.visuals.set_facing_direction(direction)
		rat.visuals.update_bob(delta, true)
