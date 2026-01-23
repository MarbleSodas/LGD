class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	# Wait for parent to be ready so we can get the entity reference if needed
	# This ensures parent's @onready vars are initialized
	await owner.ready
	
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.entity = owner
			child.transition_requested.connect(_on_transition_requested)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _on_transition_requested(from: State, to_state_name: String) -> void:
	if from != current_state:
		return
	
	var new_state = states.get(to_state_name.to_lower())
	if not new_state:
		push_warning("State Machine: State not found - " + to_state_name)
		return
		
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
