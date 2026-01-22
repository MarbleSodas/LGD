class_name RatAssistant
extends CharacterBody2D

## Autonomous harvesting assistant that collects from source nodes
## and deposits to an output storage building.

signal task_completed(source_coords: Vector2i)
signal item_deposited(item_id: String, amount: int)
signal state_changed(new_state: State)

enum State {
	IDLE,
	MOVING_TO_SOURCE,
	HARVESTING,
	MOVING_TO_OUTPUT,
	DEPOSITING,
	RETURNING_HOME
}

## Movement speed in pixels/second
@export var move_speed: float = 80.0
## Time to harvest a plant (seconds)
@export var harvest_duration: float = 0.8
## Time to deposit items (seconds)
@export var deposit_duration: float = 0.4
## Maximum number of items the rat can carry
@export var max_capacity: int = 10

## Reference to the home building (MushroomHouse)
var home_building: Node2D = null
## Reference to PlantingSystem for object lookups
var planting_system: PlantingSystem = null
## Reference to TileMapLayer for coordinate conversions
var tile_map: TileMapLayer = null

## Current state
var current_state: State = State.IDLE : set = _set_state

## Current task data
var target_coords: Vector2i = Vector2i.ZERO
var target_position: Vector2 = Vector2.ZERO
var output_coords: Vector2i = Vector2i.ZERO
var output_position: Vector2 = Vector2.ZERO

## Temporary inventory (what the rat is carrying)
## Format: { item_id (String): amount (int) }
var inventory: Dictionary = {}

## Internal timers
var _action_timer: float = 0.0
var _arrival_threshold: float = 4.0  # Distance to consider "arrived"
var _return_home_delay: float = 2.0 # Increased to 30s
var _idle_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var held_item_sprite: Sprite2D
var _bob_timer: float = 0.0

func _ready() -> void:
	current_state = State.IDLE
	
	# Create sprite for held item
	held_item_sprite = Sprite2D.new()
	held_item_sprite.name = "HeldItemSprite"
	held_item_sprite.scale = Vector2(0.6, 0.6)
	held_item_sprite.position = Vector2(0, -18)
	held_item_sprite.z_index = 1 # In front of rat
	add_child(held_item_sprite)
	
	# Create label for count
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.position = Vector2(-20, -40) # Centered above item
	count_label.size = Vector2(40, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 3)
	add_child(count_label)
	
	# Restore visual if loaded
	_update_held_item_visual()


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
			_reset_bob(delta)
		State.MOVING_TO_SOURCE:
			_process_moving(delta, target_position, _on_arrived_at_source)
		State.HARVESTING:
			_process_harvesting(delta)
			_reset_bob(delta)
		State.MOVING_TO_OUTPUT:
			_process_moving(delta, output_position, _on_arrived_at_output)
		State.DEPOSITING:
			_process_depositing(delta)
			_reset_bob(delta)
		State.RETURNING_HOME:
			if home_building:
				var target_pos = home_building.global_position
				if home_building.has_method("get_rest_position"):
					target_pos = home_building.get_rest_position()
				_process_moving(delta, target_pos, _on_arrived_home)
			else:
				current_state = State.IDLE

func _reset_bob(delta: float) -> void:
	# Smoothly return to base offset
	if sprite:
		sprite.offset.y = lerpf(sprite.offset.y, -8.0, delta * 10.0)

func _process_idle(delta: float) -> void:
	_idle_timer += delta
	
	if _idle_timer >= _return_home_delay:
		_idle_timer = 0.0
		if home_building and global_position.distance_to(home_building.global_position) > _arrival_threshold:
			current_state = State.RETURNING_HOME


func _process_moving(delta: float, destination: Vector2, on_arrive: Callable) -> void:
	var direction = (destination - global_position).normalized()
	var distance = global_position.distance_to(destination)
	
	if distance <= _arrival_threshold:
		velocity = Vector2.ZERO
		on_arrive.call()
		return
	
	velocity = direction * move_speed
	
	# Flip sprite based on movement direction (Faces Right by default)
	if direction.x != 0 and sprite:
		sprite.flip_h = direction.x < 0
		
	# Add walking bob
	_bob_timer += delta * 15.0
	if sprite:
		sprite.offset.y = -8 + sin(_bob_timer) * 2.0
	
	move_and_slide()


func _process_harvesting(delta: float) -> void:
	_action_timer += delta
	
	if _action_timer >= harvest_duration:
		_complete_harvest()


func _process_depositing(delta: float) -> void:
	_action_timer += delta
	
	if _action_timer >= deposit_duration:
		_complete_deposit()


# --- Task Assignment ---

## Assign a harvest task to the rat
func assign_task(source: Vector2i, output: Vector2i) -> void:
	if current_state != State.IDLE:
		return  # Already busy
	
	target_coords = source
	output_coords = output
	
	# Convert tile coords to world positions
	if tile_map:
		target_position = tile_map.map_to_local(source)
		output_position = tile_map.map_to_local(output)
	
	current_state = State.MOVING_TO_SOURCE


## Check if the rat is available for a new task
func is_available() -> bool:
	return current_state == State.IDLE


## Force the rat to return home (cancel current task)
func return_home() -> void:
	# Drop any carried items (or keep them for next trip)
	inventory.clear()
	_update_held_item_visual()
	current_state = State.RETURNING_HOME


# --- State Callbacks ---

func _on_arrived_at_source() -> void:
	# Check if the plant is still there and ready
	var plant = planting_system.get_object_at(target_coords) if planting_system else null
	
	if not plant or not plant.has_method("harvest"):
		# Plant is gone or not harvestable
		_decide_next_step_after_failure()
		return
	
	if plant.has_method("is_harvest_ready") and not plant.is_harvest_ready():
		# Not ready yet
		_decide_next_step_after_failure()
		return
	
	# Start harvesting
	_action_timer = 0.0
	current_state = State.HARVESTING

func _decide_next_step_after_failure() -> void:
	# If we failed to harvest (plant gone/not ready), decide what to do
	if has_items():
		current_state = State.MOVING_TO_OUTPUT
	else:
		# Set to IDLE first so assign_task can accept new work
		current_state = State.IDLE
		
		# Try to get another task nearby
		if home_building and home_building.has_method("assign_next_task_nearby"):
			home_building.assign_next_task_nearby(self)
			
		# If still IDLE (no task assigned), go home
		if current_state == State.IDLE:
			current_state = State.RETURNING_HOME

func _complete_harvest() -> void:
	var source_obj = planting_system.get_object_at(target_coords) if planting_system else null
	
	if source_obj and source_obj.has_method("harvest"):
		var drops: Dictionary = {}
		
		# Check if it's a storage building (pass capacity)
		if source_obj.has_method("get_container"):
			var space_left = max_capacity - get_total_count()
			drops = source_obj.harvest(space_left)
		else:
			drops = source_obj.harvest()
			
		if not drops.is_empty():
			var item_id = drops.get("item_id", "")
			var amount = drops.get("amount", 1)
			_add_to_inventory(item_id, amount)
			
			# Add any extra items (from barrel multi-type harvest)
			if drops.has("extra_items"):
				for extra in drops["extra_items"]:
					_add_to_inventory(extra["item_id"], extra["amount"])
					
			_update_held_item_visual()
		
		# Check if plant was consumed (non-regrowing)
		# Only applies to Plants, not buildings
		if source_obj is Plant and not source_obj.get("regrows"):
			if planting_system:
				planting_system.remove_object(target_coords)
			if tile_map:
				tile_map.set_cell(target_coords, 0, Vector2i.ZERO)
	
	task_completed.emit(target_coords)
	
	# Decide next move
	if is_full():
		if output_coords != Vector2i.ZERO:
			current_state = State.MOVING_TO_OUTPUT
		else:
			current_state = State.IDLE # Stuck full
	else:
		# Set to IDLE first so assign_task can accept new work
		current_state = State.IDLE
		
		# Try to get another task nearby
		if home_building and home_building.has_method("assign_next_task_nearby"):
			home_building.assign_next_task_nearby(self)
			
		# If still IDLE (no task was assigned), decide fallback
		if current_state == State.IDLE:
			if has_items():
				current_state = State.MOVING_TO_OUTPUT
			else:
				current_state = State.RETURNING_HOME


func _on_arrived_at_output() -> void:
	# Check if output building exists
	var building = planting_system.get_object_at(output_coords) if planting_system else null
	
	if not building or not building.has_method("get_container"):
		# Output is invalid, return home (items lost or kept)
		current_state = State.RETURNING_HOME
		return
	
	_action_timer = 0.0
	current_state = State.DEPOSITING


func _complete_deposit() -> void:
	var building = planting_system.get_object_at(output_coords) if planting_system else null
	
	if building and building.has_method("get_container"):
		var container = building.get_container()
		if container and container.has_method("add_item"):
			# Deposit all items
			for item_id in inventory:
				var amount = inventory[item_id]
				var item = ItemRegistry.get_item(item_id) if ItemRegistry else null
				if item:
					container.add_item(item, amount)
					item_deposited.emit(item_id, amount)
	
	# Clear carried items
	inventory.clear()
	_update_held_item_visual()
	
	# Do NOT automatically return home. Be available for next task immediately.
	current_state = State.IDLE
	
	# Trigger immediate check from house
	if home_building and home_building.has_method("on_rat_idle"):
		home_building.on_rat_idle(self)


func _on_arrived_home() -> void:
	current_state = State.IDLE


# --- Inventory Helpers ---

func _add_to_inventory(item_id: String, amount: int) -> void:
	if item_id == "": return
	
	if inventory.has(item_id):
		inventory[item_id] += amount
	else:
		inventory[item_id] = amount

func has_items() -> bool:
	return not inventory.is_empty()

func get_total_count() -> int:
	var total = 0
	for count in inventory.values():
		total += count
	return total

func is_full() -> bool:
	return get_total_count() >= max_capacity


# --- State Setter ---

func _set_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state
		_idle_timer = 0.0
		state_changed.emit(new_state)


# --- Save/Load ---

func get_save_data() -> Dictionary:
	return {
		"state": current_state,
		"target_coords": {"x": target_coords.x, "y": target_coords.y},
		"output_coords": {"x": output_coords.x, "y": output_coords.y},
		"inventory": inventory
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("state"):
		current_state = data["state"]
	if data.has("target_coords"):
		target_coords = Vector2i(data["target_coords"]["x"], data["target_coords"]["y"])
	if data.has("output_coords"):
		output_coords = Vector2i(data["output_coords"]["x"], data["output_coords"]["y"])
	if data.has("inventory"):
		inventory = data["inventory"]
	# Legacy support
	if data.has("carried_item_id") and data["carried_item_id"] != "":
		_add_to_inventory(data["carried_item_id"], data.get("carried_amount", 1))
		
	_update_held_item_visual()

func _update_held_item_visual() -> void:
	var label = get_node_or_null("CountLabel")
	
	if not held_item_sprite: return
	
	if inventory.is_empty():
		held_item_sprite.texture = null
		if label: label.text = ""
		return
		
	# Just show the first item found for now, or a generic "bag" if we had one
	# Ideally we'd check if we have multiple types
	var first_id = inventory.keys()[0]
	var item = ItemRegistry.get_item(first_id) if ItemRegistry else null
	if item:
		held_item_sprite.texture = item.icon
	else:
		held_item_sprite.texture = null
		
	if label:
		var total = get_total_count()
		label.text = str(total) if total > 1 else ""
