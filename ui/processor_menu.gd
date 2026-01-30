extends Control

const SLIDE_DURATION: float = 0.2
const PANEL_WIDTH: float = 230.0
const SELECTED_COLOR: Color = Color(0.639, 0.463, 0.337, 0.6)
const HOVER_COLOR: Color = Color(0.639, 0.463, 0.337, 0.3)
const DIMMED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.4)

@onready var panel: NinePatchRect = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/CloseButton
@onready var input_slot_container: Control = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/InputSlotContainer
@onready var output_slot_container: Control = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/OutputSlotContainer
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/ProcessingContainer/ProgressBar
@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/RecipeListScroll/RecipeList
@onready var processing_container: Control = $Panel/MarginContainer/VBoxContainer/ProcessingContainer

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var input_inventory: ContainerInventory
var output_inventory: ContainerInventory
var current_building: Node2D = null
var is_open: bool = false
var _tween: Tween

# Recipe selection state
var selected_recipe: ProcessorRecipe = null
var _recipe_rows: Dictionary = {}  # ProcessorRecipe -> PanelContainer

func _ready() -> void:
	add_to_group("processor_menu")
	
	# Initial state: Hidden behind inventory
	panel.offset_left = -PANEL_WIDTH
	panel.offset_right = 0.0
	visible = false
	
	close_button.pressed.connect(close)

func _process(_delta: float) -> void:
	if is_open and is_instance_valid(current_building):
		if current_building.has_method("get_processing_progress"):
			progress_bar.value = current_building.get_processing_progress() * 100.0

func open(p_input_inventory: ContainerInventory, p_output_inventory: ContainerInventory, building: Node2D) -> void:
	input_inventory = p_input_inventory
	output_inventory = p_output_inventory
	current_building = building
	
	# Sync selected recipe from building
	if current_building and "selected_recipe" in current_building:
		selected_recipe = current_building.selected_recipe
	else:
		selected_recipe = null
	
	_setup_slots()
	_refresh_recipe_list()
	_update_processing_area_state()
	
	visible = true
	is_open = true
	
	# Animate slide out
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	
	# Slide to the left of inventory
	var overlap_offset = 4.0
	var target_right = -PANEL_WIDTH + overlap_offset
	var target_left = target_right - PANEL_WIDTH
	
	_tween.tween_property(panel, "offset_left", target_left, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", target_right, SLIDE_DURATION)
	
	# Ensure Inventory Panel is open
	var inventory_panel = get_tree().get_first_node_in_group("inventory_panel")
	if not inventory_panel:
		inventory_panel = get_parent().get_node_or_null("InventoryPanel")
		
	if inventory_panel and inventory_panel.has_method("open"):
		if not inventory_panel.is_open:
			inventory_panel.open()

func close() -> void:
	if not is_open: return
	is_open = false
	current_building = null
	
	# Return held item if any
	if Inventory and Inventory.is_holding_item():
		Inventory.return_held_item()
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	
	_tween.tween_property(panel, "offset_left", -PANEL_WIDTH, SLIDE_DURATION)
	_tween.tween_property(panel, "offset_right", 0.0, SLIDE_DURATION)
	_tween.tween_callback(func(): visible = false)

func _setup_slots() -> void:
	# clear existing
	for child in input_slot_container.get_children():
		child.queue_free()
	for child in output_slot_container.get_children():
		child.queue_free()
	
	if input_inventory:
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = 0
		slot.target_inventory = input_inventory
		input_slot_container.add_child(slot)
		
	if output_inventory:
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = 0
		slot.target_inventory = output_inventory
		slot.enable_insertion = false
		output_slot_container.add_child(slot)

func _refresh_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	_recipe_rows.clear()
	
	if not is_instance_valid(current_building) or not "recipes" in current_building:
		return
		
	# Filter and Sort recipes
	# 1. Available (Player has ingredients) -> Top
	# 2. Unavailable -> Bottom
	# 3. Locked -> Hidden
	
	var visible_recipes = []
	for r in current_building.recipes:
		if not r.is_locked or Registries.is_recipe_unlocked(r.resource_path):
			visible_recipes.append(r)
			
	visible_recipes.sort_custom(func(a, b):
		var a_avail = false
		if a.input_item:
			a_avail = Inventory.count_item(a.input_item.id) >= a.input_count
			
		var b_avail = false
		if b.input_item:
			b_avail = Inventory.count_item(b.input_item.id) >= b.input_count
			
		if a_avail and not b_avail: return true
		if not a_avail and b_avail: return false
		return false
	)
	
	for recipe in visible_recipes:
		var row_panel = _create_recipe_row(recipe)
		recipe_list.add_child(row_panel)
		_recipe_rows[recipe] = row_panel

func _create_recipe_row(recipe: ProcessorRecipe) -> PanelContainer:
	var row_panel = PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create a stylebox for the background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent by default
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	row_panel.add_theme_stylebox_override("panel", style)
	
	# Highlight if selected
	if recipe == selected_recipe:
		style.bg_color = SELECTED_COLOR
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	
	# Input icon
	var input_tex = TextureRect.new()
	if recipe.input_item and recipe.input_item.icon:
		input_tex.texture = recipe.input_item.icon
	input_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	input_tex.custom_minimum_size = Vector2(24, 24)
	input_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Check availability
	var avail = false
	if recipe.input_item:
		avail = Inventory.count_item(recipe.input_item.id) >= recipe.input_count
	if not avail:
		input_tex.modulate = Color(1, 1, 1, 0.5)
		
	row.add_child(input_tex)
	
	# Arrow label
	var arrow = Label.new()
	arrow.text = str(recipe.input_count) + " -> "
	if not avail:
		arrow.modulate = Color(1, 1, 1, 0.5)
	row.add_child(arrow)
	
	# Output icon
	var output_tex = TextureRect.new()
	if recipe.output_item and recipe.output_item.icon:
		output_tex.texture = recipe.output_item.icon
	output_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output_tex.custom_minimum_size = Vector2(24, 24)
	output_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not avail:
		output_tex.modulate = Color(1, 1, 1, 0.5)
	row.add_child(output_tex)
	
	# Output count (if > 1)
	if recipe.output_count > 1:
		var out_count = Label.new()
		out_count.text = " x" + str(recipe.output_count)
		if not avail:
			out_count.modulate = Color(1, 1, 1, 0.5)
		row.add_child(out_count)
	
	row_panel.add_child(row)
	
	# Connect click handler
	row_panel.gui_input.connect(_on_recipe_row_input.bind(recipe, row_panel))
	row_panel.mouse_entered.connect(_on_recipe_row_hover.bind(recipe, row_panel, true))
	row_panel.mouse_exited.connect(_on_recipe_row_hover.bind(recipe, row_panel, false))
	
	return row_panel

func _on_recipe_row_input(event: InputEvent, recipe: ProcessorRecipe, _row_panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_recipe(recipe)

func _on_recipe_row_hover(recipe: ProcessorRecipe, row_panel: PanelContainer, entered: bool) -> void:
	if recipe == selected_recipe:
		return  # Don't change hover for selected
	var style: StyleBoxFlat = row_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = HOVER_COLOR if entered else Color(0, 0, 0, 0)

func _select_recipe(recipe: ProcessorRecipe) -> void:
	if selected_recipe == recipe:
		return
	
	# Update old row style
	if selected_recipe in _recipe_rows:
		var old_panel: PanelContainer = _recipe_rows[selected_recipe]
		var old_style: StyleBoxFlat = old_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if old_style:
			old_style.bg_color = Color(0, 0, 0, 0)
	
	selected_recipe = recipe
	
	# Update new row style
	if recipe in _recipe_rows:
		var new_panel: PanelContainer = _recipe_rows[recipe]
		var new_style: StyleBoxFlat = new_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if new_style:
			new_style.bg_color = SELECTED_COLOR
	
	# Sync to building
	if current_building and current_building.has_method("set_selected_recipe"):
		current_building.set_selected_recipe(recipe)
	
	_update_processing_area_state()

func _update_processing_area_state() -> void:
	# Dim or undim the processing area based on recipe selection
	if processing_container:
		processing_container.modulate = Color.WHITE if selected_recipe else DIMMED_MODULATE

func _input(event: InputEvent) -> void:
	if not is_open:
		return
		
	if event.is_action_pressed("toggle_inventory"):
		close()
