class_name RatIdleState
extends State

@export var return_home_delay: float = 2.0
@export var arrival_threshold: float = 4.0

var _idle_timer: float = 0.0

func enter() -> void:
	_idle_timer = 0.0
	var rat: RatAssistant = entity as RatAssistant
	if rat:
		if rat.visuals:
			rat.visuals.update_bob(0, false) # Reset bob
			
		# Ask for work immediately upon becoming idle
		if rat.home_building and rat.home_building.has_method("on_rat_idle"):
			rat.home_building.on_rat_idle(rat)

func update(delta: float) -> void:
	_idle_timer += delta
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	# Bob reset effect
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _idle_timer >= return_home_delay:
		_idle_timer = 0.0
		
		# If we have a home, and we are far from it, return home
		if rat.home_building and rat.global_position.distance_to(rat.home_building.global_position) > arrival_threshold:
			transition_requested.emit(self, "returnhome")
			
# Note: Task assignment is handled by RatAssistant forcing transition to "move"
