extends Node

## Handles all save/load operations and world management.
##
## Manages persistent data for worlds, inventory, and scene objects.
## Saves data to JSON files in the user directory.

# Constants
const SAVE_DIR: String = "user://saves/"
const METADATA_FILE: String = "world.json"
const SAVE_FILE: String = "save.json"
const MAX_WORLDS: int = 10

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# ------------------------------------------------------------------------------
# World Management
# ------------------------------------------------------------------------------

## Returns list of all worlds with their metadata
func get_all_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				var metadata: Dictionary = _load_world_metadata(file_name)
				if not metadata.is_empty():
					worlds.append(metadata)
			
			file_name = dir.get_next()
	
	# Sort by last played (newest first)
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: 
		return Time.get_unix_time_from_datetime_string(a.last_played) > Time.get_unix_time_from_datetime_string(b.last_played)
	)
	
	return worlds

## Creates a new world folder and metadata.
## Returns the new world ID if successful, empty string if failed.
func create_world(world_name: String) -> String:
	# Check limits
	if get_all_worlds().size() >= MAX_WORLDS:
		push_error("Maximum number of worlds reached")
		return ""
		
	# Generate ID (using timestamp + random suffix)
	var timestamp: int = int(Time.get_unix_time_from_system())
	var random_suffix: int = randi() % 1000
	var world_id: String = "world_%d_%d" % [timestamp, random_suffix]
	
	var world_dir: String = SAVE_DIR + world_id
	
	# Create directory
	var err: Error = DirAccess.make_dir_absolute(world_dir)
	if err != OK:
		push_error("Failed to create world directory: %s" % error_string(err))
		return ""
		
	# Create initial metadata
	var current_time: String = Time.get_datetime_string_from_system()
	var metadata: Dictionary = {
		"id": world_id,
		"name": world_name,
		"created_at": current_time,
		"last_played": current_time,
		"version": 1
	}
	
	if not _save_json(world_dir + "/" + METADATA_FILE, metadata):
		return ""
		
	return world_id

## Deletes a world and all its files
func delete_world(world_id: String) -> bool:
	var world_dir: String = SAVE_DIR + world_id
	if not DirAccess.dir_exists_absolute(world_dir):
		return false
		
	# Delete all files in the directory first
	var dir: DirAccess = DirAccess.open(world_dir)
	if dir:
		# Ensure we see hidden files (like .DS_Store) so we can empty the dir
		dir.include_hidden = true
		dir.include_navigational = false
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
			
	# Remove the directory itself
	var err: Error = DirAccess.remove_absolute(world_dir)
	return err == OK

# ------------------------------------------------------------------------------
# Save/Load Logic
# ------------------------------------------------------------------------------

## Saves the current game state to the current world's folder
func save_game(world_id: String) -> bool:
	if world_id.is_empty():
		return false
		
	var world_dir: String = SAVE_DIR + world_id
	if not DirAccess.dir_exists_absolute(world_dir):
		return false
	
	# 1. Update Metadata (Last Played)
	var metadata: Dictionary = _load_world_metadata(world_id)
	metadata["last_played"] = Time.get_datetime_string_from_system()
	_save_json(world_dir + "/" + METADATA_FILE, metadata)
	
	# 2. Collect Game State
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"inventory": Inventory.to_save_data(),
		"planting": {}, # Will be filled if PlantingSystem is found
		"tips": TipsManager.to_save_data(),
		"story_flags": GameState.story_flags,
		"dialogue": DialogueManager.to_save_data(),
		"registries": Registries.to_save_data(),
		"quests": QuestManager.to_save_data(),
		"player": {},
		"ui_state": {}
	}
	
	# Get data from active scene nodes
	var tree: SceneTree = get_tree()
	if tree.current_scene:
		# Find Player
		var player: Node = tree.current_scene.find_child("Hana", true, false) 
		if player:
			save_data["player"] = {
				"position": {
					"x": player.global_position.x,
					"y": player.global_position.y
				}
			}
			
		# Find PlantingSystem
		var planting_system: Node = tree.current_scene.find_child("PlantingSystem", true, false)
		if planting_system and planting_system.has_method("to_save_data"):
			save_data["planting"] = planting_system.to_save_data()
			
		# Find BuildMenu and save UI state
		var build_menu: Control = tree.current_scene.find_child("BuildMenu", true, false)
		if build_menu and build_menu.has_method("get_category_states"):
			save_data["ui_state"]["build_menu_collapsed"] = build_menu.get_category_states()
			
	# 3. Write Save File
	return _save_json(world_dir + "/" + SAVE_FILE, save_data)

## Loads the game state from the specified world
## Returns true if save was loaded, false if it's a new world (no save file)
func load_game(world_id: String) -> bool:
	var world_dir: String = SAVE_DIR + world_id
	var file_path: String = world_dir + "/" + SAVE_FILE
	
	if not FileAccess.file_exists(file_path):
		# If save file doesn't exist (new world), that's fine, just init default state
		print("No save file found for %s, starting fresh." % world_id)
		return false
		
	var save_data: Variant = _load_json(file_path)
	if save_data is Dictionary and save_data.is_empty():
		return false
	
	if not save_data is Dictionary:
		return false
		
	# Apply data
	_apply_save_data(save_data)
	return true

## Resets all game systems to their default state.
## Should be called before starting a new game or loading a save.
func reset_game_state() -> void:
	# 1. Reset Inventory first (as Registries depends on it)
	Inventory.reset()
	
	# 2. Reset Registries (Unlocks, Hotbar)
	Registries.reset()
	
	# 3. Reset Dialogue
	DialogueManager.reset()
	
	# 4. Reset Tips
	TipsManager.reset_tips()
	
	# 5. Reset GameState (Story flags, etc)
	# GameState.clear_current_world() # This also clears flags
	GameState.story_flags.clear() 
	
	# 6. Reset Quests
	QuestManager.reset()

func _apply_save_data(data: Dictionary) -> void:
	# Reset everything first to ensure clean state
	reset_game_state()

	# 1. Inventory
	if data.has("inventory"):
		Inventory.from_save_data(data["inventory"])
		
	# 2. Scene Objects (Player, Plants)
	var tree: SceneTree = get_tree()
	if tree.current_scene:
		# Apply Player Position
		if data.has("player") and data["player"].has("position"):
			var player: Node2D = tree.current_scene.find_child("Hana", true, false)
			if player:
				var pos_data: Dictionary = data["player"]["position"]
				player.global_position = Vector2(pos_data["x"], pos_data["y"])
				
		# Apply Planting System
		if data.has("planting"):
			var planting_system: Node = tree.current_scene.find_child("PlantingSystem", true, false)
			if planting_system and planting_system.has_method("from_save_data"):
				planting_system.from_save_data(data["planting"])

	# Apply Tips
	if data.has("tips"):
		TipsManager.from_save_data(data["tips"])

	# Apply Story Flags
	if data.has("story_flags"):
		GameState.story_flags = data["story_flags"]
	else:
		GameState.story_flags = {}

	# Apply Dialogue
	if data.has("dialogue"):
		DialogueManager.from_save_data(data["dialogue"])
		
	# Apply Registries (Unlock progression)
	if data.has("registries"):
		Registries.from_save_data(data["registries"])
		
	# Apply Quests
	if data.has("quests"):
		QuestManager.from_save_data(data["quests"])

	# Apply UI state
	if data.has("ui_state") and data["ui_state"].has("build_menu_collapsed"):
		var build_menu: Control = tree.current_scene.find_child("BuildMenu", true, false)
		if build_menu and build_menu.has_method("set_category_states"):
			build_menu.set_category_states(data["ui_state"]["build_menu_collapsed"])

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

func _load_world_metadata(world_id: String) -> Dictionary:
	var path: String = SAVE_DIR + world_id + "/" + METADATA_FILE
	var data: Variant = _load_json(path)
	if data is Dictionary:
		return data
	return {}

func _save_json(path: String, data: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s" % path)
		return false
	
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file for reading: %s" % path)
		return {}
		
	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: Error = json.parse(content)
	
	if err != OK:
		push_error("JSON Parse Error: %s in %s at line %s" % [json.get_error_message(), path, json.get_error_line()])
		return {}
		
	return json.data
