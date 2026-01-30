extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var cost_container: HBoxContainer = $MarginContainer/VBoxContainer/CostContainer

## Update the panel with current bulk placement costs
func update_costs(buildable: BuildableItem, tile_count: int, can_afford: bool) -> void:
	if buildable == null:
		hide()
		return
	
	title_label.text = "Placing %d %s" % [tile_count, buildable.display_name]
	
	# Clear existing cost items
	for child in cost_container.get_children():
		child.queue_free()
	
	# Add cost items
	if buildable.build_costs.is_empty():
		hide()
		return
	
	for material_id in buildable.build_costs:
		var required = buildable.build_costs[material_id] * tile_count
		var available = Inventory.count_item(material_id) if Inventory else 0
		var item_data = Registries.get_item(material_id) if Registries else null
		
		_add_cost_item(item_data, required, available, can_afford)
	
	show()

## Update the panel with refund information
func update_refunds(buildable: BuildableItem) -> void:
	if buildable == null:
		hide()
		return
	
	title_label.text = "Refund: %s" % [buildable.display_name]
	
	# Clear existing items
	for child in cost_container.get_children():
		child.queue_free()
	
	# Add refund items
	if buildable.build_costs.is_empty():
		hide()
		return
		
	for material_id in buildable.build_costs:
		var amount = buildable.build_costs[material_id]
		var item_data = Registries.get_item(material_id) if Registries else null
		
		_add_refund_item(item_data, amount)
	
	show()

func _add_refund_item(item: InventoryItem, amount: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	# Icon
	if item and item.icon:
		var icon = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hbox.add_child(icon)
	
	# Amount label: "+amount"
	var label = Label.new()
	label.text = "+%d" % [amount]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))  # Green for gain
	
	hbox.add_child(label)
	cost_container.add_child(hbox)

func _add_cost_item(item: InventoryItem, required: int, available: int, _can_afford: bool) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	# Icon
	if item and item.icon:
		var icon = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hbox.add_child(icon)
	
	# Amount label: "required/available"
	var label = Label.new()
	label.text = "%d/%d" % [required, available]
	label.add_theme_font_size_override("font_size", 12)
	
	# Color based on affordability
	if available >= required:
		label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))  # Green
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Red
	
	hbox.add_child(label)
	cost_container.add_child(hbox)
