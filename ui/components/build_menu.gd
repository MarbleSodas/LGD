extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 200.0

@onready var panel: NinePatchRect = $Panel
@onready var item_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ItemList

var BuildMenuSlotScene = preload("res://ui/components/build_menu_slot.tscn")
var is_open: bool = false
var _tween: Tween

func _ready() -> void:
	# Initial position (off-screen left)
	panel.position.x = -PANEL_WIDTH
	
	_populate_items()
	
	# Connect signals
	if BuildRegistry:
		BuildRegistry.buildable_unlocked.connect(_on_buildable_unlocked)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_menu"):
		toggle()
	elif event.is_action_pressed("ui_cancel") and is_open:
		close()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open: return
	is_open = true
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(panel, "position:x", 0.0, SLIDE_DURATION)

func close() -> void:
	if not is_open: return
	is_open = false
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(panel, "position:x", -PANEL_WIDTH, SLIDE_DURATION)

func _populate_items() -> void:
	# Clear existing items
	for child in item_list.get_children():
		child.queue_free()
	
	# Add unlocked items
	if BuildRegistry:
		for item in BuildRegistry.get_unlocked_items():
			_add_item_slot(item)

func _add_item_slot(item: BuildableItem) -> void:
	var slot = BuildMenuSlotScene.instantiate()
	item_list.add_child(slot)
	# Wait for ready to ensure nodes are available
	slot.setup(item)
	slot.clicked.connect(_on_item_clicked)
	slot.hotkey_bind_requested.connect(_on_hotkey_bind_requested)

func _on_item_clicked(item: BuildableItem) -> void:
	BuildRegistry.set_active(item)
	close()

func _on_hotkey_bind_requested(item: BuildableItem, slot: int) -> void:
	var current = BuildRegistry.get_hotbar_item(slot)
	if current == item:
		# Already bound - unbind (toggle)
		BuildRegistry.unassign_from_hotbar(slot)
	else:
		# Bind to this slot
		BuildRegistry.assign_to_hotbar(slot, item)

func _on_buildable_unlocked(item: BuildableItem) -> void:
	_add_item_slot(item)
