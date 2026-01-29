class_name NPCWanderState
extends State

func enter() -> void:
	var npc = entity as NPCBase
	if not npc: return
	
	var target = npc.get_wander_target()
	npc.nav_agent.target_position = target

func physics_update(delta: float) -> void:
	var npc = entity as NPCBase
	if not npc: return
	
	if npc.nav_agent.is_navigation_finished():
		transition_requested.emit(self, "idle")
		return
		
	var next_path_pos = npc.nav_agent.get_next_path_position()
	var direction = npc.global_position.direction_to(next_path_pos)
	
	npc.velocity = direction * npc.move_speed
	npc.move_and_slide()
	
	# Face direction
	if npc.velocity.x < 0:
		npc.sprite.flip_h = true
	elif npc.velocity.x > 0:
		npc.sprite.flip_h = false
