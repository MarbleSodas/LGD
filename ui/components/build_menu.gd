extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 220.0

const CATEGORY_ORDER: Array[BuildableItem.BuildableType] = [
	BuildableItem.BuildableType.PLANT,
	BuildableItem.BuildableType.BUILDING
]
const CATEGORY_NAMES: Dictionary = {
	BuildableItem.BuildableType.PLANT: "Plants",
	BuildableItem.BuildableType.BUILDING: "Buildings"
}

@onready var panel: NinePatchRect = $Panel
@onready var item_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ItemList
@onready var search_bar: LineEdit = $Panel/MarginContainer/VBoxContainer/SearchBar

var BuildMenuSlotScene = preload("res://ui/components/build_menu_slot.tscn")
var BuildMenuCategoryScene = preload("res://ui/components/build_menu_category.tscn")
var is_open: bool = false
var _tween: Tween
var _category_nodes: Dictionary = {}
var _category_states: Dictionary = {}

func _ready() -> void:
	# Initial position (off-screen left)
	panel.position.x = -PANEL_WIDTH
	add_to_group("build_menu")
	
	_populate_items()
	
	# Connect signals
	if Registries:
		Registries.buildable_unlocked.connect(_on_buildable_unlocked)
		if Registries.has_signal("registries_reset"):
			Registries.registries_reset.connect(_on_registries_reset)
	
	if search_bar:
		search_bar.text_changed.connect(_on_search_text_changed)

func _input(event: InputEvent) -> void:
	if search_bar and search_bar.has_focus():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside search bar
			if not search_bar.get_global_rect().has_point(search_bar.get_global_mouse_position()):
				search_bar.release_focus()
				return # Allow the click to pass through to whatever was clicked

		return # Don't toggle if typing

	if DialogueManager and DialogueManager.is_active(): return
	
	# Block if Rat Manager is open
	var rat_manager = get_tree().get_first_node_in_group("rat_manager_panel")
	if rat_manager and rat_manager.visible: return
	
	if event.is_action_pressed("toggle_build_menu"):
		toggle()

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
	_category_nodes.clear()
	
	# Group unlocked items by type
	var items_by_type: Dictionary = {}
	if Registries:
		for item in Registries.get_unlocked_items():
			if not items_by_type.has(item.buildable_type):
				items_by_type[item.buildable_type] = []
			items_by_type[item.buildable_type].append(item)
	
	# Iterate through categories in order
	for type in CATEGORY_ORDER:
		if items_by_type.has(type):
			var category = _get_or_create_category(type)
			for item in items_by_type[type]:
				var slot = BuildMenuSlotScene.instantiate()
				slot.setup(item)
				slot.clicked.connect(_on_item_clicked)
				slot.hotkey_bind_requested.connect(_on_hotkey_bind_requested)
				category.add_item_slot(slot)
	
	if search_bar:
		_filter_items(search_bar.text)

func _add_item_slot(item: BuildableItem) -> void:
	var category = _get_or_create_category(item.buildable_type)
	var slot = BuildMenuSlotScene.instantiate()
	slot.setup(item)
	slot.clicked.connect(_on_item_clicked)
	slot.hotkey_bind_requested.connect(_on_hotkey_bind_requested)
	category.add_item_slot(slot)

func _get_or_create_category(type: BuildableItem.BuildableType) -> Node:
	# Return existing category if it exists
	if _category_nodes.has(type):
		return _category_nodes[type]
	
	# Create new category
	var category = BuildMenuCategoryScene.instantiate()
	item_list.add_child(category)
	category.setup(type, CATEGORY_NAMES[type])
	category.toggled.connect(_on_category_toggled.bind(type))
	
	# Apply saved state (default to expanded if no saved state)
	var state_key = str(type)
	var is_expanded = _category_states.get(state_key, true)
	category.set_expanded(is_expanded, false)
	
	_category_nodes[type] = category
	return category

func _on_category_toggled(is_expanded: bool, type: BuildableItem.BuildableType) -> void:
	_category_states[str(type)] = is_expanded

func get_category_states() -> Dictionary:
	return _category_states

func set_category_states(states: Dictionary) -> void:
	_category_states = states
	for type in _category_nodes.keys():
		var state_key = str(type)
		if states.has(state_key):
			_category_nodes[type].set_expanded(states[state_key], false)

func _on_item_clicked(item: BuildableItem) -> void:
	Registries.set_active(item)
	close()

func _on_hotkey_bind_requested(item: BuildableItem, slot: int) -> void:
	var current = Registries.get_hotbar_item(slot)
	if current == item:
		# Already bound - unbind (toggle)
		Registries.unassign_from_hotbar(slot)
	else:
		# Bind to this slot
		Registries.assign_to_hotbar(slot, item)

func _on_buildable_unlocked(item: BuildableItem) -> void:
	_add_item_slot(item)
	if search_bar:
		_filter_items(search_bar.text)

func _on_registries_reset() -> void:
	_populate_items()

func _on_search_text_changed(new_text: String) -> void:
	_filter_items(new_text)

func _filter_items(query: String) -> void:
	var is_searching = not query.is_empty()
	
	for type in _category_nodes:
		var category = _category_nodes[type]
		var visible_count = 0
		
		# Access slots in the category
		for slot in category.items_container.get_children():
			if not slot.get("buildable_item"): continue
			
			var match_result = true
			if is_searching:
				match_result = _fuzzy_match(query, slot.buildable_item.display_name)
			
			slot.visible = match_result
			if match_result:
				visible_count += 1
		
		# Handle category visibility
		if is_searching:
			category.visible = visible_count > 0
			if visible_count > 0:
				category.set_expanded(true, false)
		else:
			category.visible = true
			# Restore saved state
			var state_key = str(type)
			var should_expand = _category_states.get(state_key, true)
			category.set_expanded(should_expand, false)

func _fuzzy_match(query: String, text: String) -> bool:
	if query.is_empty(): return true
	var q_idx = 0
	var t_idx = 0
	var q_len = query.length()
	var t_len = text.length()
	var q_lower = query.to_lower()
	var t_lower = text.to_lower()
	
	while q_idx < q_len and t_idx < t_len:
		if q_lower[q_idx] == t_lower[t_idx]:
			q_idx += 1
		t_idx += 1
	
	return q_idx == q_len
