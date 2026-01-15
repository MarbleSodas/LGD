class_name DeleteModeOverlay
extends Control

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks

func show_overlay() -> void:
	visible = true

func hide_overlay() -> void:
	visible = false
