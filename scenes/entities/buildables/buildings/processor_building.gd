class_name ProcessorBuilding
extends DirectionalBuilding

## Processor Building with Input/Output inventory and Recipe logic.
##
## Expects:
## - AnimationPlayer (with "Processing_Animation" and "idle")
## - Layers/BaseLayer, Layers/MiddleLayer, Layers/TopLayer etc.

signal selected_recipe_changed(recipe: ProcessorRecipe)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var layers: Node2D = $Layers

# --- State ---
enum State { IDLE, PROCESSING, WAITING_OUTPUT }
var current_state: int = State.IDLE

# --- Inventory ---
var input_inventory: ContainerInventory
var output_inventory: ContainerInventory

# --- Recipes ---
@export var recipes: Array[ProcessorRecipe] = []

# --- Recipe Selection ---
## The recipe the player has selected for this processor. Processing only occurs
## when input matches this recipe. Null means no recipe selected.
var selected_recipe: ProcessorRecipe = null

# --- Processing ---
var current_recipe: ProcessorRecipe = null
var process_duration: float = 0.0
var process_timer: Timer

func _ready() -> void:
	super._ready()
	# Initialize inventories (Size 1 each)
	input_inventory = ContainerInventory.new(1)
	output_inventory = ContainerInventory.new(1)
	
	# Setup Timer
	_setup_timer()
	
	# Connect signals
	input_inventory.slot_changed.connect(_on_input_changed)
	output_inventory.slot_changed.connect(_on_output_changed)
	
	# Load recipes
	_load_recipes()
	
	# Initial check
	_check_recipe()

func _setup_timer() -> void:
	process_timer = Timer.new()
	process_timer.name = "ProcessTimer"
	process_timer.one_shot = true
	process_timer.timeout.connect(_on_process_timer_timeout)
	add_child(process_timer)

func _process(_delta: float) -> void:
	# Keep animation looping during processing states
	if current_state in [State.PROCESSING, State.WAITING_OUTPUT]:
		if not animation_player.is_playing() or animation_player.current_animation != "Processing_Animation":
			play_process_animation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_return_items_to_player()

# --- Public API ---

func interact() -> void:
	var menu = get_tree().get_first_node_in_group("processor_menu")
	if menu:
		menu.open(input_inventory, output_inventory, self)

func close_interaction() -> void:
	var menu = get_tree().get_first_node_in_group("processor_menu")
	if menu and menu.is_open and menu.current_building == self:
		menu.close()

func on_ui_closed() -> void:
	# Notify InteractionManager that we closed
	var planting_system = get_tree().get_first_node_in_group("planting_system")
	if planting_system and planting_system.interaction_manager:
		planting_system.interaction_manager.on_building_closed(self)

func get_processing_progress() -> float:
	if current_state == State.IDLE:
		return 0.0
	if current_state == State.WAITING_OUTPUT:
		return 1.0  # Complete but waiting
	if process_duration <= 0.0:
		return 0.0
	return 1.0 - (process_timer.time_left / process_duration)

## Set the selected recipe for this processor. Only this recipe will be processed.
func set_selected_recipe(recipe: ProcessorRecipe) -> void:
	if selected_recipe == recipe:
		return
	selected_recipe = recipe
	selected_recipe_changed.emit(recipe)
	# Re-check if we can start processing with the new selection
	if current_state == State.IDLE:
		_check_recipe()

## Get the item ID that this processor wants (based on selected recipe).
## Returns empty string if no recipe is selected.
func get_wanted_item_id() -> String:
	if selected_recipe == null or selected_recipe.input_item == null:
		return ""
	return selected_recipe.input_item.id

# --- Recipe Logic ---

func _load_recipes() -> void:
	# TODO: Dynamic loading. For now, we expect them to be exported or hardcoded.
	if recipes.is_empty():
		# Fallback: Try to load wood_to_acorn if not set
		if ResourceLoader.exists("res://resources/recipes/wood_to_acorn.tres"):
			recipes.append(load("res://resources/recipes/wood_to_acorn.tres"))

func _check_recipe() -> void:
	if current_state != State.IDLE:
		return
	
	# Must have a selected recipe to process
	if selected_recipe == null:
		return
		
	# 1. Check Input
	var input_slot = input_inventory.get_slot(0)
	if input_slot == null:
		return
		
	var item = input_slot.item
	var count = input_slot.count
	
	# 2. Check if input matches selected recipe
	if item == selected_recipe.input_item and count >= selected_recipe.input_count:
		_start_processing(selected_recipe)

func _find_recipe_for(item: InventoryItem, count: int) -> ProcessorRecipe:
	for r in recipes:
		if r.input_item == item and count >= r.input_count:
			return r
	return null

func _can_output(recipe: ProcessorRecipe) -> bool:
	var slot = output_inventory.get_slot(0)
	if slot == null:
		return true # Empty slot
	
	if slot.item != recipe.output_item:
		return false # Wrong item
		
	if slot.count + recipe.output_count > slot.item.max_stack:
		return false # Full
		
	return true

func _start_processing(recipe: ProcessorRecipe) -> void:
	current_recipe = recipe
	process_duration = recipe.processing_time
	current_state = State.PROCESSING
	
	# Start timer (input stays in slot - we consume on completion)
	process_timer.start(process_duration)
	
	play_process_animation()

func _on_process_timer_timeout() -> void:
	_try_complete_processing()

func _try_complete_processing() -> void:
	if current_recipe == null:
		_reset_to_idle()
		return
	
	# 1. Verify input still exists (player might have removed it)
	var input_slot = input_inventory.get_slot(0)
	if input_slot == null or input_slot.item != current_recipe.input_item or input_slot.count < current_recipe.input_count:
		# Input was removed - cancel gracefully
		_reset_to_idle()
		return
	
	# 2. Check output space
	if not _can_output(current_recipe):
		current_state = State.WAITING_OUTPUT
		# Keep animation running
		if not animation_player.is_playing() or animation_player.current_animation != "Processing_Animation":
			play_process_animation()
		return
	
	# 3. Success! Consume input and produce output
	var recipe = current_recipe
	input_inventory.remove_item(0, recipe.input_count)
	output_inventory.add_item(recipe.output_item, recipe.output_count)
	
	_reset_to_idle()
	
	# 4. Check for next recipe
	_check_recipe()

func _reset_to_idle() -> void:
	current_state = State.IDLE
	current_recipe = null
	process_timer.stop()
	animation_player.play("RESET")

func _return_items_to_player() -> void:
	if not Inventory: return
	
	# Return input inventory contents
	var input_slot = input_inventory.get_slot(0)
	if input_slot != null and input_slot.item != null:
		Inventory.add_item(input_slot.item, input_slot.count)
	
	# Return output inventory contents
	var output_slot = output_inventory.get_slot(0)
	if output_slot != null and output_slot.item != null:
		Inventory.add_item(output_slot.item, output_slot.count)

# --- Signals ---

func _on_input_changed(_slot_index: int, _item: InventoryItem, _count: int) -> void:
	match current_state:
		State.IDLE:
			_check_recipe()
		State.PROCESSING, State.WAITING_OUTPUT:
			# Input changed during processing/waiting - verify it's still valid
			if not _is_current_recipe_valid():
				_reset_to_idle()

func _on_output_changed(_slot_index: int, _item: InventoryItem, _count: int) -> void:
	match current_state:
		State.IDLE:
			_check_recipe()
		State.WAITING_OUTPUT:
			# Output changed - try completing again
			_try_complete_processing()

func _is_current_recipe_valid() -> bool:
	if current_recipe == null:
		return false
	var input_slot = input_inventory.get_slot(0)
	if input_slot == null:
		return false
	return input_slot.item == current_recipe.input_item and input_slot.count >= current_recipe.input_count

# --- Visuals ---

func play_process_animation() -> void:
	if animation_player.has_animation("Processing_Animation"):
		animation_player.play("Processing_Animation")

func get_save_data() -> Dictionary:
	return {
		"input_inventory": input_inventory.to_save_data(),
		"output_inventory": output_inventory.to_save_data(),
		"current_state": current_state,
		"process_time_left": process_timer.time_left if process_timer else 0.0,
		"current_recipe_id": _get_recipe_id(current_recipe),
		"selected_recipe_id": _get_recipe_id(selected_recipe),
		"is_flipped": is_flipped,
		"center_tile_x": center_tile.x,
		"center_tile_y": center_tile.y,
		"version": 2
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("input_inventory"):
		input_inventory.from_save_data(data["input_inventory"])
	if data.has("output_inventory"):
		output_inventory.from_save_data(data["output_inventory"])
	
	if data.has("is_flipped"):
		is_flipped = data["is_flipped"]
		
	if data.has("center_tile_x") and data.has("center_tile_y"):
		center_tile = Vector2i(data["center_tile_x"], data["center_tile_y"])
		
	_update_orientation()
	
	current_state = data.get("current_state", State.IDLE)
	
	# Restore selected recipe (user's choice)
	var selected_id = data.get("selected_recipe_id", "")
	if selected_id != "":
		selected_recipe = _get_recipe_by_id(selected_id)
	
	# Restore current recipe (in-progress processing)
	var recipe_id = data.get("current_recipe_id", "")
	if recipe_id != "":
		current_recipe = _get_recipe_by_id(recipe_id)
		if current_recipe:
			process_duration = current_recipe.processing_time

	# Resume processing if we were mid-process
	if current_state == State.PROCESSING and current_recipe:
		var time_left = data.get("process_time_left", process_duration)
		# Ensure positive time
		if time_left <= 0: time_left = 0.1
		process_timer.start(time_left)
		play_process_animation()
	elif current_state == State.WAITING_OUTPUT:
		play_process_animation()
		# Try completing in case output is now available
		call_deferred("_try_complete_processing")

func _get_recipe_id(recipe: ProcessorRecipe) -> String:
	if recipe == null: return ""
	return recipe.resource_path

func _get_recipe_by_id(id: String) -> ProcessorRecipe:
	if id == "": return null
	if ResourceLoader.exists(id):
		return load(id) as ProcessorRecipe
	return null

# --- Dual-Role Interface (Rat Integration) ---

## Returns the tile coordinates where rats should deposit items
func get_deposit_tile() -> Vector2i:
	return get_input_tile()

## Returns the tile coordinates where rats should harvest items
func get_harvest_tile() -> Vector2i:
	return get_output_tile()

func get_input_inventory() -> ContainerInventory:
	return input_inventory

func get_output_inventory() -> ContainerInventory:
	return output_inventory

## Smart inventory access for automated agents
func get_preferred_inventory(action_type: String) -> ContainerInventory:
	if action_type == "insert":
		return input_inventory
	elif action_type == "extract":
		return output_inventory
	return output_inventory 

## Compatibility for Rat "Deposit" Logic (Target: Input)
func get_container() -> ContainerInventory:
	return input_inventory

## Compatibility for Rat "Harvest" Logic (Target: Output)
func is_harvest_ready() -> bool:
	if not output_inventory: return false
	return not output_inventory.is_empty()

func harvest(max_amount: int = 10) -> Dictionary:
	if not output_inventory or output_inventory.is_empty():
		return {}
	
	var harvested_items: Array = []
	var remaining = max_amount
	
	for i in range(output_inventory.slot_count):
		if remaining <= 0: break
			
		var slot = output_inventory.get_slot(i)
		if slot == null: continue
		
		var available = slot.count
		var take_amount = mini(available, remaining)
		var item_id = slot.item.id # Assuming item has id property
		
		# We assume the item object itself is needed for return, 
		# but the harvest signature returns a Dict with IDs.
		# RatHarvestState._complete_harvest reconstructs the item from ID via ItemDatabase usually?
		# Let's check RatHarvestState logic.
		# Assuming standard harvest protocol.
		
		output_inventory.remove_item(i, take_amount)
		
		harvested_items.append({"item_id": item_id, "amount": take_amount})
		remaining -= take_amount
	
	if harvested_items.is_empty():
		return {}
	
	var result = {
		"item_id": harvested_items[0]["item_id"],
		"amount": harvested_items[0]["amount"]
	}
	
	if harvested_items.size() > 1:
		result["extra_items"] = harvested_items.slice(1)
		
	return result
