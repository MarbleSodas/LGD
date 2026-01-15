extends NinePatchRect

signal clicked(item: BuildableItem)
signal hotkey_bind_requested(item: BuildableItem, slot: int)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconBackground/Icon
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var hotkey_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/HotkeyBadge

var buildable_item: BuildableItem
var _is_hovered: bool = false

# Preload slot textures
var _normal_texture = preload("res://ui/resources/atlas/build_menu/slot_normal.tres")
var _hover_texture = preload("res://ui/resources/atlas/build_menu/slot_hover.tres")
var _selected_texture = preload("res://ui/resources/atlas/build_menu/slot_selected.tres")

func _ready() -> void:
	# Set up mouse handling
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to registry to update hotkey badge
	if BuildRegistry:
		BuildRegistry.hotbar_changed.connect(_on_hotbar_changed)
	
	_update_hotkey_badge()

func setup(item: BuildableItem) -> void:
	buildable_item = item
	if icon_rect and item.icon:
		icon_rect.texture = item.icon
	if name_label:
		name_label.text = item.display_name
	_update_hotkey_badge()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual_state()

func _update_visual_state() -> void:
	var icon_bg = get_node_or_null("MarginContainer/HBoxContainer/IconBackground")
	if icon_bg:
		if _is_hovered:
			icon_bg.texture = _hover_texture
		else:
			icon_bg.texture = _normal_texture

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(buildable_item)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _is_hovered:
		return
		
	# Check for hotbar keys while hovered
	if event is InputEventKey and event.pressed:
		for i in range(10):
			var action = "hotbar_0" if i == 9 else "hotbar_" + str(i + 1)
			if event.is_action_pressed(action):
				var slot_index = i
				hotkey_bind_requested.emit(buildable_item, slot_index)
				get_viewport().set_input_as_handled()
				break

func _on_hotbar_changed(_slot: int, _item: BuildableItem) -> void:
	_update_hotkey_badge()

func _update_hotkey_badge() -> void:
	if not buildable_item or not hotkey_badge:
		return
		
	if not BuildRegistry:
		return
		
	var slot = BuildRegistry.get_slot_for_item(buildable_item)
	if slot != -1:
		var display_num = str(slot + 1)
		if slot == 9:
			display_num = "0"
		hotkey_badge.text = "[" + display_num + "]"
		hotkey_badge.visible = true
	else:
		hotkey_badge.visible = false
