@tool
extends TextureButton

@export var tip_id: String = ""
@export_multiline var tip_text: String = "":
	set(value):
		tip_text = value
		if is_node_ready() and tip_label:
			tip_label.text = value

@export var normal_texture: Texture2D:
	set(value):
		normal_texture = value
		_update_texture()

@export var new_texture: Texture2D:
	set(value):
		new_texture = value
		_update_texture()

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var tip_label: Label = $CanvasLayer/Overlay/PanelContainer/MarginContainer/VBoxContainer/TipLabel
@onready var close_button: Button = $CanvasLayer/Overlay/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var background: ColorRect = $CanvasLayer/Overlay/Background

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_texture()
		return

	if tip_id.is_empty():
		push_warning("TipIcon has no tip_id assigned.")
	
	_update_state()
	
	# Listen for state changes
	if TipsManager:
		TipsManager.tip_state_changed.connect(_on_tip_state_changed)
	
	pressed.connect(_on_pressed)
	close_button.pressed.connect(_close_overlay)
	
	# Close on background click
	background.gui_input.connect(_on_background_input)
	
	if tip_label:
		tip_label.text = tip_text

func _update_texture() -> void:
	if not is_inside_tree(): return
	
	if Engine.is_editor_hint():
		# In editor, just show one of them (prefer new_texture to see it)
		texture_normal = new_texture if new_texture else normal_texture
		return

	if TipsManager and TipsManager.is_seen(tip_id):
		texture_normal = normal_texture
		modulate = Color(1, 1, 1, 0.7)
	else:
		texture_normal = new_texture
		modulate = Color(1, 1, 1, 1)

func _update_state() -> void:
	if Engine.is_editor_hint(): return
	_update_texture()

func _on_pressed() -> void:
	if canvas_layer:
		canvas_layer.visible = true
		
		# Mark as seen when opened
		if TipsManager and not TipsManager.is_seen(tip_id):
			TipsManager.mark_seen(tip_id)

func _close_overlay() -> void:
	if canvas_layer:
		canvas_layer.visible = false

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_overlay()

func _on_tip_state_changed(id: String, _seen: bool) -> void:
	if id == tip_id:
		_update_state()
