extends Node

## Tracks the current game session state

signal world_loaded(world_id: String)
signal world_unloaded()

# Current world metadata
var current_world_id: String = ""
var current_world_name: String = ""
var is_world_loaded: bool = false

func set_current_world(id: String, world_name: String) -> void:
	current_world_id = id
	current_world_name = world_name
	is_world_loaded = true
	world_loaded.emit(id)

func clear_current_world() -> void:
	current_world_id = ""
	current_world_name = ""
	is_world_loaded = false
	world_unloaded.emit()
