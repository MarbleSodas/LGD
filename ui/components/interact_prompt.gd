extends Control

@onready var label: Label = $PanelContainer/MarginContainer/HBoxContainer/Label
@onready var icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Icon

func _ready() -> void:
	visible = false

func set_text(text: String) -> void:
	if label:
		label.text = text

func show_prompt() -> void:
	visible = true

func hide_prompt() -> void:
	visible = false
