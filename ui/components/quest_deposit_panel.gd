extends PanelContainer

## Panel for depositing items required for a quest.
## Supports drag-and-drop from the inventory.

signal quest_submitted(quest_id: String)
signal panel_closed

@onready var title_label: Label = %TitleLabel
@onready var grid_container: GridContainer = %GridContainer
@onready var complete_button: Button = %CompleteButton
@onready var close_button: Button = %CloseButton

var InventorySlotScene = preload("res://ui/components/inventory_slot.tscn")
var current_quest: QuestResource = null

func _ready() -> void:
	complete_button.pressed.connect(_on_complete_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Initial state
	complete_button.disabled = true

## Initializes the panel with a quest.
func setup(quest: QuestResource) -> void:
	current_quest = quest
	_refresh_ui()

## Updates the UI elements based on current quest state.
func _refresh_ui() -> void:
	if not current_quest:
		return
		
	title_label.text = current_quest.title
	
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	# Populate slots based on quest requirements
	var active_quests = QuestManager.get_active_quests()
	var quest_data = active_quests.get(current_quest.id, {})
	var deposited_items = quest_data.get("current_items", {})
	
	var all_met = true
	for item_id in current_quest.required_items:
		var required_count = current_quest.required_items[item_id]
		var current_count = deposited_items.get(item_id, 0)
		
		var slot = InventorySlotScene.instantiate()
		grid_container.add_child(slot)
		
		# Configure slot
		var item_res = Registries.get_item(item_id)
		if item_res:
			slot.set_ghost_item(item_res.icon)
			if current_count > 0:
				slot.set_item(item_res.icon, current_count)
			
		# Show "5/10" count on slots
		var stack_label = slot.get_node("StackCount")
		stack_label.text = str(current_count) + "/" + str(required_count)
		stack_label.visible = true
		
		if current_count < required_count:
			all_met = false
	
	complete_button.disabled = not all_met

# ------------------------------------------------------------------------------
# Drag and Drop Handling
# ------------------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Expects data to be a dictionary with an "item" key (InventoryItem)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("item"):
		return false
		
	var dropped_item = data["item"]
	if not current_quest:
		return false
		
	# Check if this item is actually required for the quest
	return current_quest.required_items.has(dropped_item.id)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dropped_item = data["item"]
	var item_id = dropped_item.id
	
	# Check how many we still need to deposit
	var active_quests = QuestManager.get_active_quests()
	var quest_data = active_quests.get(current_quest.id, {})
	var deposited_items = quest_data.get("current_items", {})
	
	var required_total = current_quest.required_items[item_id]
	var currently_deposited = deposited_items.get(item_id, 0)
	var needed = required_total - currently_deposited
	
	if needed <= 0:
		return
		
	# Check how many the player actually has in their inventory
	var player_has = Inventory.count_item(item_id)
	var to_deposit = min(needed, player_has)
	
	if to_deposit > 0:
		# Consume from player inventory and add to quest deposits
		if Inventory.consume_item(item_id, to_deposit):
			QuestManager.deposit_item(current_quest.id, item_id, to_deposit)
			_refresh_ui()

# ------------------------------------------------------------------------------
# Signal Handlers
# ------------------------------------------------------------------------------

func _on_complete_pressed() -> void:
	complete_button.disabled = true
	quest_submitted.emit(current_quest.id)
	# Typically QuestManager would handle the actual completion logic
	# following this signal or a direct call.

func _on_close_pressed() -> void:
	panel_closed.emit()
	hide()
