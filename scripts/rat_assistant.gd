class_name RatAssistant
extends CharacterBody2D

## Autonomous harvesting assistant.
##
## Rewritten Logic:
## - One task at a time (Harvest or Deposit).
## - Returns to Idle after every task to get new assignment from MushroomHouse.

@warning_ignore("unused_signal")
signal task_completed(source_coords: Vector2i)
@warning_ignore("unused_signal")
signal item_deposited(item_id: String, amount: int)

enum TaskType { NONE, HARVEST, DEPOSIT }

## Movement speed in pixels/second
@export var move_speed: float = 80.0

## Components
@onready var state_machine: StateMachine = $StateMachine
@onready var inventory: RatInventory = $Inventory
@onready var visuals: RatVisuals = $Visuals

## Context References
var home_building: Node2D = null
var planting_system: PlantingSystem = null
var tile_map: TileMapLayer = null

## Task Data
var current_task: TaskType = TaskType.NONE
var target_coords: Vector2i = Vector2i.ZERO
var target_position: Vector2 = Vector2.ZERO
var target_container: Node2D = null # Cached reference to target object

func _ready() -> void:
	pass

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

## Assign a specific task to the rat
func assign_task(type: TaskType, target: Vector2i, force: bool = false) -> void:
	# Ensure we are ready before accepting tasks
	if not is_node_ready():
		await ready

	# Always show rat when given work
	if visuals:
		visuals.set_visible_in_world(true)

	if not force and not is_available():
		return

	current_task = type
	target_coords = target

	# Cache position and object
	if tile_map:
		target_position = tile_map.map_to_local(target)

	if planting_system:
		target_container = planting_system.get_object_at(target)
	else:
		target_container = null

	# Start moving
	if state_machine.current_state:
		state_machine._on_transition_requested(state_machine.current_state, "move")

## Check if the rat is available for a new task
func is_available() -> bool:
	if not state_machine or not state_machine.current_state:
		return false
	return state_machine.current_state.name.to_lower() == "idle"

## Force the rat to return home (cancel current task)
func return_home() -> void:
	if state_machine.current_state:
		state_machine._on_transition_requested(state_machine.current_state, "returnhome")

# ------------------------------------------------------------------------------
# Save/Load
# ------------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var state_name: String = "idle"
	if state_machine.current_state:
		state_name = state_machine.current_state.name.to_lower()

	return {
		"state_name": state_name,
		"current_task": current_task,
		"target_coords": {"x": target_coords.x, "y": target_coords.y},
		"inventory": inventory.items
	}

func load_save_data(data: Dictionary) -> void:
	if not is_node_ready():
		await ready

	# Wait for StateMachine to initialize
	if state_machine and not state_machine.current_state:
		await get_tree().process_frame

	if data.has("target_coords"):
		target_coords = Vector2i(data["target_coords"]["x"], data["target_coords"]["y"])
		if tile_map:
			target_position = tile_map.map_to_local(target_coords)

	if data.has("current_task"):
		current_task = int(data["current_task"]) as TaskType

	if data.has("inventory"):
		inventory.items = data["inventory"]
		inventory.inventory_changed.emit()

	# Restore state
	if data.has("state_name"):
		if state_machine.current_state:
			state_machine._on_transition_requested(state_machine.current_state, data["state_name"])
