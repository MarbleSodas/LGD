extends Control

@onready var world_list_panel = $WorldListPanel

func _ready() -> void:
	# Connect Play button
	var play_btn = $CenterContainer/VBoxContainer/PlayButton
	play_btn.pressed.connect(_on_play_pressed)

	# Initial state
	world_list_panel.hide()

func _on_play_pressed() -> void:
	# Show the world list panel
	world_list_panel.show()
	world_list_panel.refresh_list()
