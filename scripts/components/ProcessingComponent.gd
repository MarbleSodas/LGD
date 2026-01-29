@tool
class_name ProcessingComponent
extends Node

## Manages recipe processing logic.
## Takes items from InputContainer, processes them, puts in OutputContainer.

signal selected_recipe_changed(recipe: ProcessorRecipe)
signal processing_started
signal processing_complete(recipe: ProcessorRecipe)

@export var recipes: Array[ProcessorRecipe] = []

@export_group("Containers")
@export var input_container: ContainerComponent
@export var output_container: ContainerComponent

# State
enum State { IDLE, PROCESSING, WAITING_OUTPUT }
var current_state: int = State.IDLE
var selected_recipe: ProcessorRecipe = null
var current_recipe: ProcessorRecipe = null
var process_duration: float = 0.0

var process_timer: Timer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	process_timer = Timer.new()
	process_timer.one_shot = true
	process_timer.timeout.connect(_on_process_timer_timeout)
	add_child(process_timer)
	
	# Hook up container signals
	if input_container:
		input_container.slot_changed.connect(_on_input_changed)
	if output_container:
		output_container.slot_changed.connect(_on_output_changed)
		
	# Fallback recipe load (legacy support)
	if recipes.is_empty():
		# This path might need to be verified or removed if we rely purely on export
		if ResourceLoader.exists("res://resources/recipes/wood_to_acorn.tres"):
			recipes.append(load("res://resources/recipes/wood_to_acorn.tres"))

	# Initial check
	_check_recipe()

func _on_input_changed(_idx: int, _item: Resource, _count: int) -> void:
	match current_state:
		State.IDLE:
			_check_recipe()
		State.PROCESSING, State.WAITING_OUTPUT:
			if not _is_current_recipe_valid():
				_reset_to_idle()

func _on_output_changed(_idx: int, _item: Resource, _count: int) -> void:
	match current_state:
		State.IDLE:
			_check_recipe()
		State.WAITING_OUTPUT:
			_try_complete_processing()

func set_selected_recipe(recipe: ProcessorRecipe) -> void:
	if selected_recipe == recipe: return
	selected_recipe = recipe
	selected_recipe_changed.emit(recipe)
	if current_state == State.IDLE:
		_check_recipe()

func get_processing_progress() -> float:
	if current_state == State.IDLE: return 0.0
	if current_state == State.WAITING_OUTPUT: return 1.0
	if process_duration <= 0.0: return 0.0
	return 1.0 - (process_timer.time_left / process_duration)

func get_wanted_item_id() -> String:
	if selected_recipe and selected_recipe.input_item:
		return selected_recipe.input_item.id
	return ""

# --- Logic ---

func _check_recipe() -> void:
	if current_state != State.IDLE: return
	if not selected_recipe: return
	if not input_container: return
	
	var input_slot = input_container.get_slot(0)
	if not input_slot: return
	
	if input_slot.item == selected_recipe.input_item and input_slot.count >= selected_recipe.input_count:
		_start_processing(selected_recipe)

func _start_processing(recipe: ProcessorRecipe) -> void:
	current_recipe = recipe
	process_duration = recipe.processing_time
	current_state = State.PROCESSING
	
	process_timer.start(process_duration)
	processing_started.emit()

func _on_process_timer_timeout() -> void:
	_try_complete_processing()

func _try_complete_processing() -> void:
	if not current_recipe:
		_reset_to_idle()
		return
		
	# Verify input exists
	if not input_container:
		_reset_to_idle()
		return
		
	var input_slot = input_container.get_slot(0)
	if not input_slot or input_slot.item != current_recipe.input_item or input_slot.count < current_recipe.input_count:
		_reset_to_idle()
		return
		
	# Check output
	if not _can_output(current_recipe):
		current_state = State.WAITING_OUTPUT
		return
		
	# Consume and produce
	var recipe_to_process = current_recipe
	input_container.remove_item(0, recipe_to_process.input_count)
	output_container.add_item(recipe_to_process.output_item, recipe_to_process.output_count)
	
	var completed_recipe = recipe_to_process
	_reset_to_idle()
	processing_complete.emit(completed_recipe)
	
	# Check next
	_check_recipe()

func _can_output(recipe: ProcessorRecipe) -> bool:
	if not output_container: return false
	var slot = output_container.get_slot(0)
	if not slot: return true
	if slot.item != recipe.output_item: return false
	if slot.count + recipe.output_count > slot.item.max_stack: return false
	return true

func _reset_to_idle() -> void:
	current_state = State.IDLE
	current_recipe = null
	process_timer.stop()

func _is_current_recipe_valid() -> bool:
	if not current_recipe: return false
	if not input_container: return false
	var slot = input_container.get_slot(0)
	if not slot: return false
	return slot.item == current_recipe.input_item and slot.count >= current_recipe.input_count

# --- Save/Load ---

func get_save_data() -> Dictionary:
	return {
		"current_state": current_state,
		"process_time_left": process_timer.time_left if not process_timer.is_stopped() else 0.0,
		"current_recipe_id": _get_recipe_id(current_recipe),
		"selected_recipe_id": _get_recipe_id(selected_recipe)
	}

func load_save_data(data: Dictionary) -> void:
	current_state = data.get("current_state", State.IDLE)
	
	var sel_id = data.get("selected_recipe_id", "")
	if sel_id != "": selected_recipe = _load_recipe(sel_id)
	
	var cur_id = data.get("current_recipe_id", "")
	if cur_id != "": current_recipe = _load_recipe(cur_id)
	
	if current_recipe:
		process_duration = current_recipe.processing_time
	
	if current_state == State.PROCESSING and current_recipe:
		var time = data.get("process_time_left", process_duration)
		if time <= 0: time = 0.1
		process_timer.start(time)
		processing_started.emit()
	elif current_state == State.WAITING_OUTPUT:
		processing_started.emit() # Resume animation
		call_deferred("_try_complete_processing")

func _get_recipe_id(recipe: Resource) -> String:
	return recipe.resource_path if recipe else ""

func _load_recipe(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null
