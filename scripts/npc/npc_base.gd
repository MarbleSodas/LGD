class_name NPCBase
extends CharacterBody2D

signal interaction_started
signal interaction_ended

@export var move_speed: float = 60.0
@export var wander_radius: float = 128.0
@export var intro_dialogue: DialogueResource
@export var greeting_dialogue: DialogueResource # Optional short greeting for repeat interactions
@export var actions: Array[Resource] = [] # NPCAction resources

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var wander_area: Area2D = $WanderArea

var home_position: Vector2
var is_interacting: bool = false

func _ready() -> void:
	home_position = global_position
	
	# Configure nav agent
	nav_agent.path_desired_distance = 10.0
	nav_agent.target_desired_distance = 10.0
	nav_agent.avoidance_enabled = true
	
	# Connect to DialogueBox signals globally via Manager if possible, 
	# but usually we connect dynamically when interaction starts.

func interact() -> void:
	if is_interacting: return
	
	is_interacting = true
	state_machine._on_transition_requested(state_machine.current_state, "talk")
	interaction_started.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_face_target(player.global_position)
	
	# Determine interaction mode
	var use_intro = true
	if intro_dialogue and DialogueManager.has_shown(intro_dialogue.dialogue_id):
		use_intro = false
	
	if use_intro and intro_dialogue:
		DialogueManager.start_dialogue(intro_dialogue)
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	elif greeting_dialogue:
		DialogueManager.start_dialogue(greeting_dialogue)
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		# Direct menu
		_open_actions_menu()

func _face_target(target_pos: Vector2) -> void:
	if target_pos.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _on_dialogue_finished() -> void:
	# Dialogue ended, now show actions if any
	if actions.is_empty():
		_end_interaction()
	else:
		_show_actions_in_box()

func _show_actions_in_box() -> void:
	if DialogueManager.dialogue_box:
		DialogueManager.dialogue_box.show_actions(actions)
		
		# We need to listen for selection OR close
		if not DialogueManager.dialogue_box.action_selected.is_connected(_on_action_selected):
			DialogueManager.dialogue_box.action_selected.connect(_on_action_selected, CONNECT_ONE_SHOT)
			
		# Also watch for box closing without selection (e.g. ESC)
		# But DialogueBox typically closes on ESC. We need to catch that to end interaction.
		# For now, let's assume action selection handles it or DialogueManager.dialogue_finished handles closure.
		# Wait, dialogue_finished only emits when box closes completely.
		# If show_actions keeps box open, we are fine.
		pass

func _open_actions_menu() -> void:
	if DialogueManager.dialogue_box:
		# We need a way to open box without text, or with static text.
		# For now, let's assume we pass a dummy resource or method.
		# Let's add open_for_actions to DialogueBox later.
		# Calling generic open_custom or similar.
		
		# Reusing intro resource for portrait/name but suppressing lines?
		# Let's try to just open the box visually.
		if intro_dialogue:
			DialogueManager.dialogue_box.open_custom(intro_dialogue.speaker_name, intro_dialogue.portrait)
			_show_actions_in_box()

func _on_action_selected(action_id: String) -> void:
	handle_action(action_id)

func handle_action(action_id: String) -> void:
	# Override in child
	print("Action: ", action_id)
	
	# Default behavior: Close menu after action
	if action_id == "leave" or action_id == "close":
		_close_menu()
	else:
		# If action triggers more dialogue, the child class handles it
		pass

func _close_menu() -> void:
	if DialogueManager.dialogue_box:
		DialogueManager.dialogue_box.close()
	_end_interaction()

func _end_interaction() -> void:
	is_interacting = false
	interaction_ended.emit()
	state_machine._on_transition_requested(state_machine.current_state, "idle")

func get_wander_target() -> Vector2:
	# Random point in circle
	if not wander_area:
		return home_position + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	
	# If Area2D used, pick random point in bounds
	# Simplified: just use radius around home for now as per plan
	var angle = randf() * PI * 2
	var dist = randf() * wander_radius
	return home_position + Vector2(cos(angle), sin(angle)) * dist
