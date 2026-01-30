class_name NPCBase
extends CharacterBody2D

signal interaction_started
signal interaction_ended

@export var move_speed: float = 60.0
@export var wander_radius: float = 128.0
@export var intro_dialogue: DialogueResource
@export var greeting_dialogue: DialogueResource # Optional short greeting for repeat interactions
@export var actions: Array[Resource] = [] # NPCAction resources
@export var quest: QuestResource
@export var action_menu_prompt: String = "What would you like to do?"

var interact_prompt_scene = preload("res://ui/components/interact_prompt.tscn")
var interact_prompt: Control = null

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var wander_area: Area2D = $WanderArea

var home_position: Vector2
var is_interacting: bool = false
var is_hovered: bool = false
var _is_showing_actions: bool = false
var _is_switching_dialogue: bool = false
var _quest_panel: Control = null

func _ready() -> void:
	home_position = global_position
	
	# Configure nav agent
	nav_agent.path_desired_distance = 10.0
	nav_agent.target_desired_distance = 10.0
	nav_agent.avoidance_enabled = true
	
	# Setup Interact Prompt
	interact_prompt = interact_prompt_scene.instantiate()
	add_child(interact_prompt)
	interact_prompt.position = Vector2(0, 24) # Position below the NPC
	interact_prompt.visible = false
	# Ensure it renders on top
	interact_prompt.z_index = 10

func on_hover_enter() -> void:
	is_hovered = true
	if interact_prompt and not is_interacting:
		interact_prompt.show_prompt()

func on_hover_exit() -> void:
	is_hovered = false
	if interact_prompt:
		interact_prompt.hide_prompt()

func interact() -> void:
	if is_interacting: return
	
	if interact_prompt:
		interact_prompt.hide_prompt()
	
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
		_start_dialogue(intro_dialogue)
	elif greeting_dialogue:
		_start_dialogue(greeting_dialogue)
	else:
		_open_actions_menu()

func _get_quest_action() -> Resource:
	if quest == null:
		return null
	
	var state = QuestManager.get_quest_state(quest.id)
	if state == QuestManager.QuestState.LOCKED or state == QuestManager.QuestState.COMPLETED:
		return null
	
	if state == QuestManager.QuestState.UNLOCKED or state == QuestManager.QuestState.ACTIVE:
		var action = NPCAction.new()
		action.display_name = "Quest"
		action.action_id = "quest_action"
		return action
	
	return null

func _start_dialogue(dialogue: DialogueResource) -> void:
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	_is_showing_actions = false
	
	if DialogueManager.is_active():
		_is_switching_dialogue = true
		DialogueManager.close_dialogue()
		_is_switching_dialogue = false
		
	DialogueManager.start_dialogue(dialogue)

func _face_target(target_pos: Vector2) -> void:
	if target_pos.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _on_dialogue_finished() -> void:
	if not is_interacting or _is_switching_dialogue: return
	
	if _is_showing_actions:
		# If we were showing actions and the dialogue box closed, we are done
		_end_interaction()
		return

	# Dialogue ended, always end interaction unless specific logic dictates otherwise
	# (User requested to exit instead of returning to action menu)
	_end_interaction()

func _show_actions_in_box(display_actions: Array) -> void:
	if DialogueManager.dialogue_box:
		DialogueManager.dialogue_box.show_actions(display_actions, action_menu_prompt)
		
		# We need to listen for selection OR close
		if not DialogueManager.dialogue_box.action_selected.is_connected(_on_action_selected):
			DialogueManager.dialogue_box.action_selected.connect(_on_action_selected, CONNECT_ONE_SHOT)

func _open_actions_menu() -> void:
	_is_showing_actions = true
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
		
	if DialogueManager.dialogue_box:
		var s_name = "???"
		var s_portrait = null
		if intro_dialogue:
			s_name = intro_dialogue.speaker_name
			s_portrait = intro_dialogue.portrait
			
		DialogueManager.start_custom(s_name, s_portrait)
		
		var display_actions = actions.duplicate()
		var quest_action = _get_quest_action()
		if quest_action:
			display_actions.append(quest_action)
			
		_show_actions_in_box(display_actions)

func _on_action_selected(action_id: String) -> void:
	handle_action(action_id)

func handle_action(action_id: String) -> void:
	# Override in child or use for base quest system
	print("Action: ", action_id)
	
	if action_id == "quest_action":
		_close_menu()
		var panel_scene = load("res://ui/components/quest_deposit_panel.tscn")
		_quest_panel = panel_scene.instantiate()
		
		var ui_layer = get_tree().get_first_node_in_group("ui_layer")
		if ui_layer:
			ui_layer.add_child(_quest_panel)
		else:
			get_tree().root.add_child(_quest_panel)
			
		_quest_panel.setup(quest)
		_quest_panel.quest_submitted.connect(_on_quest_submitted)
		_quest_panel.panel_closed.connect(func(): _quest_panel.queue_free())
		return
	
	# Default behavior: Close menu after action
	if action_id == "leave" or action_id == "close":
		_close_menu()
	else:
		# If action triggers more dialogue, the child class handles it
		pass

func _close_menu() -> void:
	if DialogueManager.is_active():
		DialogueManager.close_dialogue()
	else:
		_end_interaction()

func _on_quest_submitted(quest_id: String) -> void:
	QuestManager.complete_quest(quest_id)
	
	if _quest_panel:
		_quest_panel.queue_free()
		_quest_panel = null
	
	if quest and quest.reward_dialogue_id != "":
		var d_path = "res://resources/dialogues/" + quest.reward_dialogue_id + ".tres"
		if FileAccess.file_exists(d_path):
			var res = load(d_path)
			_start_dialogue(res)
		else:
			_end_interaction()
	else:
		_end_interaction()

func _end_interaction() -> void:
	is_interacting = false
	_is_showing_actions = false
	if DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.disconnect(_on_dialogue_finished)
	interaction_ended.emit()
	state_machine._on_transition_requested(state_machine.current_state, "idle")
	
	if is_hovered and interact_prompt:
		interact_prompt.show_prompt()

func get_wander_target() -> Vector2:
	# Random point in circle
	if not wander_area:
		return home_position + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	
	# If Area2D used, pick random point in bounds
	# Simplified: just use radius around home for now as per plan
	var angle = randf() * PI * 2
	var dist = randf() * wander_radius
	return home_position + Vector2(cos(angle), sin(angle)) * dist
