extends NPCBase

func handle_action(action_id: String) -> void:
	if action_id == "talk":
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
	
	super.interact()
	
	# If this was the first interaction, the base class started the dialogue.
	# We hook into the finished signal to give the item.
	if is_first_interaction:
		if not DialogueManager.dialogue_finished.is_connected(_on_intro_finished):
			DialogueManager.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)

func _on_intro_finished() -> void:
	# Give 1 Dandelion Tuft
	if Inventory and ItemRegistry:
		var tuft = ItemRegistry.get_item("dandelion_tuft")
		if tuft:
			Inventory.add_item(tuft, 1)
			print("Glider gave 1 Dandelion Tuft")
