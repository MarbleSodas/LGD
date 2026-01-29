extends NPCBase

func handle_action(action_id: String) -> void:
	if action_id == "talk":
		# Close menu first
		if DialogueManager.dialogue_box:
			DialogueManager.dialogue_box.close()
			
		# Play generic talk dialogue
		# Ideally we'd have a random chat list, but reusing intro is fine for v1
		if intro_dialogue:
			DialogueManager.start_dialogue(intro_dialogue)
			
		# We don't want to show actions again immediately after talking via menu
		# so we don't connect to dialogue_finished here
	else:
		super.handle_action(action_id)
