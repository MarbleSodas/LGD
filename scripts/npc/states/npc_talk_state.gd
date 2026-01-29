class_name NPCTalkState
extends State

func enter() -> void:
	var npc = entity as NPCBase
	if npc:
		npc.velocity = Vector2.ZERO
