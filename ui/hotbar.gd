extends MarginContainer

## Emitted when the selected hotbar slot changes
signal slot_changed(index: int)

var current_slot: int = 0
var slots: Array[Panel] = []

# StyleBoxFlat for active slot (red border only, transparent bg)
var active_style: StyleBoxFlat


func _ready() -> void:
	_setup_styles()
	_cache_slots()
	select_slot(0)


func _setup_styles() -> void:
	# Active: red border only, transparent background to show default Panel style
	active_style = StyleBoxFlat.new()
	active_style.border_color = Color(1.0, 0.0, 0.0)  # Red
	active_style.border_width_left = 2
	active_style.border_width_right = 2
	active_style.border_width_top = 2
	active_style.border_width_bottom = 2


func _cache_slots() -> void:
	var hbox := $HBoxContainer
	for i in range(10):
		var slot := hbox.get_node("Slot" + str(i)) as Panel
		slots.append(slot)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hotbar_1"):
		select_slot(0)
	elif event.is_action_pressed("hotbar_2"):
		select_slot(1)
	elif event.is_action_pressed("hotbar_3"):
		select_slot(2)
	elif event.is_action_pressed("hotbar_4"):
		select_slot(3)
	elif event.is_action_pressed("hotbar_5"):
		select_slot(4)
	elif event.is_action_pressed("hotbar_6"):
		select_slot(5)
	elif event.is_action_pressed("hotbar_7"):
		select_slot(6)
	elif event.is_action_pressed("hotbar_8"):
		select_slot(7)
	elif event.is_action_pressed("hotbar_9"):
		select_slot(8)
	elif event.is_action_pressed("hotbar_0"):
		select_slot(9)


func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	
	# Remove highlight from old slot (restore default style)
	if current_slot >= 0 and current_slot < slots.size():
		slots[current_slot].remove_theme_stylebox_override("panel")
	
	# Set new slot with red border
	current_slot = index
	slots[current_slot].add_theme_stylebox_override("panel", active_style)
	
	# Notify other systems of the slot change
	slot_changed.emit(current_slot)
