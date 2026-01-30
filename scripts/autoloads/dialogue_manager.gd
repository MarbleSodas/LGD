extends Node

signal dialogue_started
signal dialogue_finished
signal line_started(index: int)

var is_dialogue_active: bool = false
var dialogue_box: Control
var shown_dialogues: Dictionary = {}
var current_resource: DialogueResource

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_dialogue_box(box: Control) -> void:
	dialogue_box = box
	# Check if signal is already connected to avoid errors on reload
	if not dialogue_box.dialogue_completed.is_connected(_on_dialogue_box_completed):
		dialogue_box.dialogue_completed.connect(_on_dialogue_box_completed)
	
	if not dialogue_box.line_started.is_connected(_on_line_started):
		dialogue_box.line_started.connect(_on_line_started)

func start_dialogue(resource: DialogueResource) -> void:
	if is_dialogue_active: return
	if not dialogue_box:
		push_error("DialogueManager: No dialogue box registered!")
		return
		
	is_dialogue_active = true
	current_resource = resource
	if resource.dialogue_id != "":
		shown_dialogues[resource.dialogue_id] = true
	emit_signal("dialogue_started")
	
	dialogue_box.open(resource)

func start_custom(speaker: String, portrait: Texture2D) -> void:
	if is_dialogue_active: return
	if not dialogue_box: return
	
	is_dialogue_active = true
	emit_signal("dialogue_started")
	dialogue_box.open_custom(speaker, portrait)

func close_dialogue() -> void:
	if not is_dialogue_active: return
	
	is_dialogue_active = false
	current_resource = null
	dialogue_box.close()
	emit_signal("dialogue_finished")

func is_active() -> bool:
	return is_dialogue_active

func has_shown(dialogue_id: String) -> bool:
	return shown_dialogues.has(dialogue_id)

func mark_shown(dialogue_id: String) -> void:
	shown_dialogues[dialogue_id] = true

func _on_dialogue_box_completed() -> void:
	close_dialogue()

func _on_line_started(index: int) -> void:
	emit_signal("line_started", index)
	
	if current_resource and index >= 0 and index < current_resource.entries.size():
		var entry = current_resource.entries[index]
		if entry.quest_to_start != "":
			if QuestManager:
				QuestManager.start_quest(entry.quest_to_start)
		if entry.quest_to_complete != "":
			if QuestManager:
				QuestManager.complete_quest(entry.quest_to_complete)

func _unhandled_input(event: InputEvent) -> void:
	if not is_dialogue_active: return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("harvest"):
		if dialogue_box:
			dialogue_box.advance()
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# Save/Load Support
# ------------------------------------------------------------------------------

func reset() -> void:
	shown_dialogues.clear()
	close_dialogue()

func to_save_data() -> Dictionary:
	return shown_dialogues.duplicate()

func from_save_data(data: Dictionary) -> void:
	shown_dialogues = data.duplicate()
