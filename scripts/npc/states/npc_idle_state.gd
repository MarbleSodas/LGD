class_name NPCIdleState
extends State

@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0

var _timer: float = 0.0
var _current_wait: float = 0.0

func enter() -> void:
	_timer = 0.0
	_current_wait = randf_range(min_idle_time, max_idle_time)
	
	var npc = entity as NPCBase
	if npc:
		npc.velocity = Vector2.ZERO

func update(delta: float) -> void:
	_timer += delta
	if _timer >= _current_wait:
		transition_requested.emit(self, "wander")
