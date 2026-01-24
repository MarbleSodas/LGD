extends Control

signal confirmed
signal cancelled

@onready var label = $DialogPanel/VBoxContainer/Label

func _ready() -> void:
	$DialogPanel/VBoxContainer/HBoxContainer/CancelButton.pressed.connect(_on_cancel)
	$DialogPanel/VBoxContainer/HBoxContainer/DeleteButton.pressed.connect(_on_delete)
	hide()

func show_confirm(text: String) -> void:
	label.text = text
	show()

func close() -> void:
	hide()

func _on_cancel() -> void:
	cancelled.emit()
	hide()

func _on_delete() -> void:
	confirmed.emit()
	hide()
