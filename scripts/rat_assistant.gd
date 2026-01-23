class_name RatAssistant
extends CharacterBody2D

## Autonomous harvesting assistant that collects from source nodes
## and deposits to an output storage building.

@warning_ignore("unused_signal")
signal task_completed(source_coords: Vector2i)
@warning_ignore("unused_signal")
signal item_deposited(item_id: String, amount: int)

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
var target_coords: Vector2i = Vector2i.ZERO
var target_position: Vector2 = Vector2.ZERO
var output_coords: Vector2i = Vector2i.ZERO
var output_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Initialize references if they weren't injected
	# Note: In the original code, these seemed to be injected by the spawner.
	pass

# --- Public API ---

## Assign a harvest task to the rat
func assign_task(source: Vector2i, output: Vector2i) -> void:
	# Ensure we are ready before accepting tasks
	if not is_node_ready():
		await ready

	# Only accept if Idle? The State Machine handles logic, but we can check state name
	if not is_available():
		return
	
	target_coords = source
	output_coords = output
	
	if tile_map:
		target_position = tile_map.map_to_local(source)
		output_position = tile_map.map_to_local(output)
	
	if not state_machine.current_state:
		return

	# Ideally, we tell the current state (Idle) to handle the task assignment.
	if state_machine.current_state.has_method("handle_task_assignment"):
		state_machine.current_state.handle_task_assignment()
	else:
		# Fallback force
		state_machine._on_transition_requested(state_machine.current_state, "move")

## Check if the rat is available for a new task
func is_available() -> bool:
	if not state_machine or not state_machine.current_state: return false
	return state_machine.current_state.name.to_lower() == "idle"

## Force the rat to return home (cancel current task)
func return_home() -> void:
	state_machine._on_transition_requested(state_machine.current_state, "returnhome")


# --- Save/Load ---

func get_save_data() -> Dictionary:
	return {
		"state_name": state_machine.current_state.name.to_lower() if state_machine.current_state else "idle",
		"target_coords": {"x": target_coords.x, "y": target_coords.y},
		"output_coords": {"x": output_coords.x, "y": output_coords.y},
		"inventory": inventory.items
	}

func load_save_data(data: Dictionary) -> void:
	if not is_node_ready():
		await ready
		
	if data.has("target_coords"):
		target_coords = Vector2i(data["target_coords"]["x"], data["target_coords"]["y"])
	if data.has("output_coords"):
		output_coords = Vector2i(data["output_coords"]["x"], data["output_coords"]["y"])
	if data.has("inventory"):
		inventory.items = data["inventory"]
		inventory.inventory_changed.emit()
	
	# Legacy support
	if data.has("carried_item_id") and data["carried_item_id"] != "":
		inventory.add_item(data["carried_item_id"], data.get("carried_amount", 1))

	# Restore state
	if data.has("state_name"):
		if state_machine.current_state:
			state_machine._on_transition_requested(state_machine.current_state, data["state_name"])
	elif data.has("state"): # Legacy enum support
		# Map integer to string? 
		# IDLE=0, MOVING_TO_SOURCE=1, HARVESTING=2, MOVING_TO_OUTPUT=3, DEPOSITING=4, RETURNING_HOME=5
		var legacy_map = {
			0: "idle", 1: "move", 2: "harvest", 3: "movetooutput", 4: "deposit", 5: "returnhome"
		}
		var state_name = legacy_map.get(int(data["state"]), "idle")
			
		if state_machine.current_state:
			state_machine._on_transition_requested(state_machine.current_state, state_name)
