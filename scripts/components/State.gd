class_name State
extends Node

## Base class for all states in the State Machine.
@warning_ignore("unused_signal")
signal transition_requested(from: State, to_state_name: String)

## Reference to the owner of the state machine (e.g., the RatAssistant)
var entity: Node

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
