class_name GameUI
extends CanvasLayer

## Coordinates top-level UI behavior shared by the world and modal panels.

@onready var container_panel: Control = $ContainerPanel
@onready var processor_menu: Control = $ProcessorMenu
@onready var rat_manager_panel: RatManagerPanel = $RatManagerPanel
@onready var pause_menu: Control = $PauseMenu
@onready var dimming_layer: ColorRect = $DimmingLayer

var _dimming_tween: Tween
var _player: CharacterBody2D


func handle_cancel_request() -> bool:
	if close_topmost():
		return true

	if pause_menu and not pause_menu.visible and pause_menu.has_method("open"):
		pause_menu.call("open")
		return true

	return false


func close_topmost() -> bool:
	if DialogueManager and DialogueManager.is_active():
		DialogueManager.close_dialogue()
		return true

	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()
		return true

	if _is_open(container_panel):
		container_panel.call("close")
		return true

	if _is_open(processor_menu):
		processor_menu.call("close")
		return true

	if rat_manager_panel and rat_manager_panel.visible:
		rat_manager_panel.close()
		return true

	return false


func set_modal_presentation(active: bool, transition_duration: float = 0.1) -> void:
	_set_player_movement_enabled(not active)

	if not dimming_layer:
		return

	if _dimming_tween:
		_dimming_tween.kill()

	if active:
		if not dimming_layer.visible:
			dimming_layer.modulate.a = 0.0
		dimming_layer.visible = true

	_dimming_tween = create_tween()
	_dimming_tween.set_ease(Tween.EASE_OUT if active else Tween.EASE_IN)
	_dimming_tween.tween_property(
		dimming_layer,
		"modulate:a",
		1.0 if active else 0.0,
		transition_duration
	)

	if not active:
		_dimming_tween.tween_callback(dimming_layer.hide)


func _is_open(panel: Control) -> bool:
	return panel != null and panel.get("is_open") == true and panel.has_method("close")


func _set_player_movement_enabled(enabled: bool) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not _player:
		push_warning("GameUI: Cannot change movement because the player was not found.")
		return

	var method_name: StringName = &"unlock_movement" if enabled else &"lock_movement"
	if _player.has_method(method_name):
		_player.call(method_name)
	else:
		push_warning("GameUI: Player does not implement %s()." % method_name)
