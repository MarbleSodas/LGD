@tool
class_name InteractionComponent
extends Node

## Handles interaction logic (opening UI menus) for the parent object.

signal interaction_started
signal interaction_ended

@export var menu_group: String = "ui_layer"
@export var menu_node_path: NodePath

func _ready() -> void:
	if Engine.is_editor_hint():
		return

func interact() -> void:
	var menu = _get_menu_node()
	if menu:
		if menu.has_method("open"):
			# Pass the parent node as the context
			menu.open(get_parent())
		interaction_started.emit()
	else:
		push_warning("InteractionComponent: No menu node found for %s" % get_parent().name)

func close_interaction() -> void:
	var menu = _get_menu_node()
	if menu and menu.has_method("close") and menu.get("is_open"):
		menu.close()

func on_ui_closed() -> void:
	interaction_ended.emit()
	_notify_interaction_manager_closed()

func _get_menu_node() -> Control:
	if not menu_node_path.is_empty():
		return get_node_or_null(menu_node_path) as Control
	
	if not menu_group.is_empty():
		var menu = get_tree().get_first_node_in_group(menu_group)
		if menu is Control:
			return menu
			
	# Fallback search commonly used in project
	var game_services = get_node_or_null("/root/GameServices")
	if game_services:
		var ui_layer = game_services.ui_root
		if ui_layer:
			# Try to guess based on group name if it matches a node name? 
			# Or just return null if specific path/group failed.
			# Existing code (storage_building) looks for "ContainerPanel".
			# We should rely on configuration, but maybe provide one fallback?
			pass
		
	return null

func _notify_interaction_manager_closed() -> void:
	var game_services = get_node_or_null("/root/GameServices")
	if game_services and game_services.planting_system and game_services.planting_system.interaction_manager:
		# PlantingSystem expects the building (parent), not the component
		game_services.planting_system.interaction_manager.on_building_closed(get_parent())
