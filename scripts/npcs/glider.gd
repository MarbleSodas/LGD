extends NPCBase

@export var busy_dialogue: DialogueResource = preload("res://resources/dialogues/glider_busy.tres")

@export var quest_shroom_start: DialogueResource = preload("res://resources/dialogues/glider_quest_shroom_start.tres")
@export var quest_shroom_wait: DialogueResource = preload("res://resources/dialogues/glider_quest_shroom_wait.tres")
@export var quest_shroom_complete: DialogueResource = preload("res://resources/dialogues/glider_quest_shroom_complete.tres")
@export var mushroom_house_scene: PackedScene = preload("res://scenes/entities/buildables/buildings/mushroom_house.tscn")

@export var quest_resource: QuestResource = preload("res://resources/quests/build_base_quest.tres")

func _ready():
	super._ready()
	QuestManager.quest_completed.connect(_on_quest_completed_signal)

func handle_action(action_id: String) -> void:
	if action_id == "talk":
		# Check for specific quest dialogues first
		if _handle_quest_dialogue():
			return

		# If no quests active, show busy dialogue
		if QuestManager.active_quests.is_empty() and busy_dialogue:
			_start_dialogue(busy_dialogue)
			return

		# For repeat interactions, prefer greeting if available, otherwise fallback to intro
		if greeting_dialogue:
			_start_dialogue(greeting_dialogue)
		elif intro_dialogue:
			_start_dialogue(intro_dialogue)

	else:
		super.handle_action(action_id)

func interact() -> void:
	# Check if this is the first interaction (intro hasn't been shown yet)
	var is_first_interaction = false
	if intro_dialogue and not DialogueManager.has_shown(intro_dialogue.dialogue_id):
		is_first_interaction = true
	
	if is_first_interaction:
		super.interact()
		# Hook into the finished signal to give the item
		if not DialogueManager.dialogue_finished.is_connected(_on_intro_finished):
			DialogueManager.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
		return

	# If intro is done, check for quests
	if is_interacting: return
	
	if interact_prompt:
		interact_prompt.hide_prompt()
	
	is_interacting = true
	state_machine._on_transition_requested(state_machine.current_state, "talk")
	interaction_started.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_face_target(player.global_position)
	
	if QuestManager.active_quests.is_empty():
		# No active quests -> Busy dialogue
		if busy_dialogue:
			_start_dialogue(busy_dialogue)
		elif greeting_dialogue:
			_start_dialogue(greeting_dialogue)
		else:
			_open_actions_menu()
	else:
		# Active quests -> Standard greeting (or quest specific logic)
		if _handle_quest_dialogue():
			return
			
		if greeting_dialogue:
			_start_dialogue(greeting_dialogue)
		else:
			_open_actions_menu()

func _on_intro_finished() -> void:
	# Give 1 Dandelion Tuft
	if Inventory and Registries:
		var tuft = Registries.get_item("dandelion_tuft")
		if tuft:
			Inventory.add_item(tuft, 1)
			print("Glider gave 1 Dandelion Tuft")

func _handle_quest_dialogue() -> bool:
	if QuestManager.is_quest_active("build_base"):
		if quest_shroom_start and not DialogueManager.has_shown(quest_shroom_start.dialogue_id):
			_start_dialogue(quest_shroom_start)
			return true
			
	return false

func _on_quest_completed_signal(quest_id: String) -> void:
	if quest_id == "build_base":
		print("Completed Shroom Quest")
		
		# Ensure Glider stays put
		state_machine._on_transition_requested(state_machine.current_state, "talk")
		is_interacting = true
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_face_target(player.global_position)
		
		# Show completion dialogue
		if quest_shroom_complete:
			_start_dialogue(quest_shroom_complete)
		
		# Build base
		if mushroom_house_scene:
			var house = mushroom_house_scene.instantiate()
			# Place near Glider's home position for consistency
			house.global_position = home_position + Vector2(48, 0)
			
			# Find World node or YSort to add to
			var world = get_tree().get_first_node_in_group("world_ysort")
			if not world:
				world = get_parent()
				
			world.add_child(house)

# Removed old _on_shroom_quest_complete logic as it is now handled by signal
