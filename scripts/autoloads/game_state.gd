extends Node

## Owns the active world identity and story progression state.
##
## SaveManager persists only the story flags. World identity comes from the
## selected world metadata and remains active while a save is reset or loaded.

signal world_loaded(world_id: String)
signal world_unloaded
signal flag_changed(flag_name: String, value: bool)

var current_world_id: String = ""
var current_world_name: String = ""
var is_world_loaded: bool = false

var _story_flags: Dictionary = {}


func set_current_world(world_id: String, world_name: String) -> void:
	current_world_id = world_id
	current_world_name = world_name
	is_world_loaded = true
	world_loaded.emit(world_id)


func clear_current_world() -> void:
	current_world_id = ""
	current_world_name = ""
	is_world_loaded = false
	reset_progress()
	world_unloaded.emit()


func set_flag(flag_name: String, value: bool = true) -> void:
	if _story_flags.get(flag_name) == value:
		return

	_story_flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func get_flag(flag_name: String) -> bool:
	return _story_flags.get(flag_name, false)


func has_flag(flag_name: String) -> bool:
	return get_flag(flag_name)


func reset_progress() -> void:
	_story_flags.clear()


func to_save_data() -> Dictionary:
	return _story_flags.duplicate(true)


func from_save_data(data: Dictionary) -> void:
	# Loading intentionally does not emit flag_changed. Quest state is restored
	# separately after flags, matching the previous direct-assignment behavior.
	_story_flags = data.duplicate(true)
