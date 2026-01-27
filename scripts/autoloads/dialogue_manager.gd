extends Node

signal dialogue_started
signal dialogue_finished

var is_dialogue_active: bool = false
var dialogue_box: Control
var shown_dialogues: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_dialogue_box(box: Control) -> void:
	dialogue_box = box
	# Check if signal is already connected to avoid errors on reload
	if not dialogue_box.dialogue_completed.is_connected(_on_dialogue_box_completed):
		dialogue_box.dialogue_completed.connect(_on_dialogue_box_completed)

func start_dialogue(resource: DialogueResource) -> void:
	if is_dialogue_active: return
	if not dialogue_box:
		push_error("DialogueManager: No dialogue box registered!")
		return
		
	is_dialogue_active = true
	shown_dialogues[resource.dialogue_id] = true
	emit_signal("dialogue_started")
	
	dialogue_box.open(resource)

func close_dialogue() -> void:
	if not is_dialogue_active: return
	
	is_dialogue_active = false
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_dialogue_active: return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("harvest"):
		if dialogue_box:
			dialogue_box.advance()
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
