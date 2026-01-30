extends Node

# Merged Data Manager for GameState and TipsManager
# Replaces GameState and TipsManager

# --- GameState Signals ---
signal world_loaded(world_id: String)
signal world_unloaded()
signal flag_changed(flag_name: String, value: bool)

# --- TipsManager Signals ---
signal tip_state_changed(tip_id: String, is_seen: bool)

# --- GameState Data ---
var current_world_id: String = ""
var current_world_name: String = ""
var is_world_loaded: bool = false
var story_flags: Dictionary = {}

# --- TipsManager Data ---
var _seen_tips: Dictionary = {}

# ------------------------------------------------------------------------------
# GameState Logic
# ------------------------------------------------------------------------------

func set_current_world(id: String, world_name: String) -> void:
	current_world_id = id
	current_world_name = world_name
	is_world_loaded = true
	world_loaded.emit(id)

func clear_current_world() -> void:
	current_world_id = ""
	current_world_name = ""
	is_world_loaded = false
	story_flags.clear()
	# Note: Tips are global, so we usually don't clear them on world unload, 
	# but SaveManager handles loading/saving tips per save file anyway.
	world_unloaded.emit()

func set_flag(flag_name: String, value: bool = true) -> void:
	if story_flags.get(flag_name) != value:
		story_flags[flag_name] = value
		flag_changed.emit(flag_name, value)

func get_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)

func has_flag(flag_name: String) -> bool:
	return get_flag(flag_name)

# ------------------------------------------------------------------------------
# TipsManager Logic
# ------------------------------------------------------------------------------

func is_seen(tip_id: String) -> bool:
	return _seen_tips.get(tip_id, false)

func mark_seen(tip_id: String) -> void:
	if not is_seen(tip_id):
		_seen_tips[tip_id] = true
		tip_state_changed.emit(tip_id, true)

func reset_tips() -> void:
	_seen_tips.clear()

# ------------------------------------------------------------------------------
# Serialization (Tips only, as GameState is handled manually by SaveManager)
# ------------------------------------------------------------------------------

# Used by SaveManager via TipsManager alias
func to_save_data() -> Dictionary:
	return _seen_tips.duplicate()

# Used by SaveManager via TipsManager alias
func from_save_data(data: Dictionary) -> void:
	_seen_tips = data.duplicate()
	for tip_id in _seen_tips:
		tip_state_changed.emit(tip_id, true)
