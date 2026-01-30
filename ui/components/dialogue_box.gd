extends Control

signal line_displayed
signal line_started(index: int)
signal dialogue_completed
signal action_selected(action_id: String)

@onready var speaker_label = %SpeakerLabel
@onready var dialogue_label = %DialogueLabel
@onready var portrait = %Portrait
@onready var continue_indicator = %ContinueIndicator
@onready var action_buttons_container = %ActionButtons

const ACTION_BUTTON_SCENE = preload("res://ui/components/action_button.tscn")

@onready var overlay = $Overlay
@onready var dialogue_panel = $DialoguePanel
@onready var background = $DialoguePanel/Background
@onready var chat_box = $DialoguePanel/ChatBox
@onready var portrait_container = $DialoguePanel/HBoxContainer/MarginContainer
@onready var content = $DialoguePanel/HBoxContainer/Content

var current_dialogue: DialogueResource
var current_line_index: int = 0
var is_typing: bool = false
var is_open: bool = false

var _type_tween: Tween
var _close_tween: Tween
var default_portrait: Texture2D

func _ready() -> void:
	if DialogueManager:
		DialogueManager.register_dialogue_box(self)
	visible = false
	continue_indicator.visible = false
	
	# Capture the default portrait assigned in the editor scene
	# This ensures editor WYSIWYG matches runtime default
	if portrait.texture:
		default_portrait = portrait.texture
	
	_play_indicator_anim()

func show_actions(actions: Array, prompt_text: String = "") -> void:
	# Clean up previous buttons
	for child in action_buttons_container.get_children():
		child.queue_free()
	
	if actions.is_empty():
		action_buttons_container.visible = false
		return
		
	action_buttons_container.visible = true
	continue_indicator.visible = false # Hide indicator when actions are shown
	
	# Display prompt text if provided
	if prompt_text != "":
		dialogue_label.text = prompt_text
		dialogue_label.visible_characters = -1
	
	# Ensure the whole box is visible and active if showing actions
	visible = true
	is_open = true
	overlay.visible = true
	dialogue_panel.modulate.a = 1.0
	
	for action in actions:
		if action is NPCAction:
			# Check flags if needed
			if action.requires_flag != "" and GameState and GameState.has_method("has_flag"):
				if not GameState.has_flag(action.requires_flag):
					continue
					
			if action.disabled_if_flag != "" and GameState and GameState.has_method("has_flag"):
				if GameState.has_flag(action.disabled_if_flag):
					continue
			
			var btn = ACTION_BUTTON_SCENE.instantiate()
			btn.text = action.display_name
			if action.icon:
				btn.icon = action.icon
			
			btn.pressed.connect(func(): _on_action_pressed(action.action_id))
			action_buttons_container.add_child(btn)
			
	# If no actions ended up being shown (due to flags), maybe close or just show nothing?
	if action_buttons_container.get_child_count() == 0:
		action_buttons_container.visible = false

func _on_action_pressed(action_id: String) -> void:
	emit_signal("action_selected", action_id)
	# Actions usually lead to new dialogue or closing, so we don't auto-close here
	# The controller (NPC) should decide whether to start new dialogue or close

func open(dialogue: DialogueResource) -> void:
	# Kill any pending close tween to prevent it from hiding us
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	
	current_dialogue = dialogue
	current_line_index = 0
	is_open = true
	visible = true
	overlay.visible = true
	
	# Setup UI - set defaults
	speaker_label.text = dialogue.speaker_name
	
	# Hide actions when starting new dialogue
	if action_buttons_container:
		action_buttons_container.visible = false
	
	# Always portrait configuration
	portrait_container.visible = true
	background.visible = true
	chat_box.offset_left = 115
	content.add_theme_constant_override("margin_left", 0)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	if dialogue.portrait:
		portrait.texture = dialogue.portrait
	else:
		portrait.texture = default_portrait
		
	# Animation slide in
	dialogue_panel.modulate.a = 0.0
	dialogue_panel.position.y += 20
	var tween = create_tween()
	tween.parallel().tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(dialogue_panel, "position:y", dialogue_panel.position.y - 20, 0.2)
	
	if current_dialogue.entries.size() > 0:
		_show_current_entry()
	else:
		close()

func close() -> void:
	if not is_open: return  # Prevent double-close
	is_open = false
	
	# Kill any existing close tween to prevent stale callbacks
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	
	_close_tween = create_tween()
	_close_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.2)
	_close_tween.tween_callback(func(): visible = false)

func advance() -> void:
	if not is_open: return
	
	if is_typing:
		_skip_typing()
	elif current_dialogue:
		current_line_index += 1
		if current_line_index < current_dialogue.entries.size():
			_show_current_entry()
		else:
			# DialogueManager handles close via dialogue_completed signal
			emit_signal("dialogue_completed")
	else:
		pass

func _show_current_entry() -> void:
	is_typing = true
	continue_indicator.visible = false
	
	emit_signal("line_started", current_line_index)
	
	var entry: DialogueEntry = current_dialogue.entries[current_line_index]
	var text = entry.text
	
	# Handle overrides
	if entry.speaker_override != "":
		speaker_label.text = entry.speaker_override
	else:
		speaker_label.text = current_dialogue.speaker_name
		
	if entry.portrait_override:
		portrait.texture = entry.portrait_override
	elif current_dialogue.portrait:
		portrait.texture = current_dialogue.portrait
	else:
		portrait.texture = default_portrait
		
	# Handle translation if key exists
	if entry.translation_key != "":
		text = tr(entry.translation_key)
			
	dialogue_label.text = text
	var parsed_len = dialogue_label.get_parsed_text().length()
	dialogue_label.visible_characters = 0
	
	# Kill previous tween if any
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
		
	_type_tween = create_tween()
	var duration = parsed_len / 30.0 # 30 chars per second
	_type_tween.tween_property(dialogue_label, "visible_characters", parsed_len, duration)
	_type_tween.tween_callback(_on_typing_finished)

func open_custom(name_text: String, portrait_texture: Texture2D) -> void:
	# Kill any pending close tween to prevent it from hiding us
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	
	# Clear stale dialogue state so advance() doesn't auto-close action menus
	current_dialogue = null
	current_line_index = 0
	is_open = true
	visible = true
	overlay.visible = true
	
	speaker_label.text = name_text
	if portrait_texture:
		portrait.texture = portrait_texture
	else:
		portrait.texture = default_portrait
		
	# Hide text/typing related stuff
	dialogue_label.text = ""
	continue_indicator.visible = false
	
	# Reset actions
	if action_buttons_container:
		for child in action_buttons_container.get_children():
			child.queue_free()
		action_buttons_container.visible = false
		
	# Animation slide in
	dialogue_panel.modulate.a = 0.0
	dialogue_panel.position.y += 20
	var tween = create_tween()
	tween.parallel().tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(dialogue_panel, "position:y", dialogue_panel.position.y - 20, 0.2)

func _skip_typing() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	dialogue_label.visible_characters = -1 # Show all
	_on_typing_finished()

func _on_typing_finished() -> void:
	is_typing = false
	continue_indicator.visible = true
	emit_signal("line_displayed")

func _play_indicator_anim() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("bounce")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()
