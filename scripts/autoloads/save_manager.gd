extends Node

## Handles all save/load operations and world management

# Constants
const SAVE_DIR = "user://saves/"
const METADATA_FILE = "world.json"
const SAVE_FILE = "save.json"
const MAX_WORLDS = 10

# Dependencies (will be looked up dynamically to avoid cyclic deps if possible, or just standard access)
# Inventory is an Autoload, so we can access it directly: Inventory
# GameState is an Autoload: GameState

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# --- World Management ---

## Returns list of all worlds with their metadata
func get_all_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				var metadata = _load_world_metadata(file_name)
				if not metadata.is_empty():
					worlds.append(metadata)
			
			file_name = dir.get_next()
	
	# Sort by last played (newest first)
	worlds.sort_custom(func(a, b): 
		return Time.get_unix_time_from_datetime_string(a.last_played) > Time.get_unix_time_from_datetime_string(b.last_played)
	)
	
	return worlds

## Creates a new world folder and metadata
## Returns the new world ID if successful, empty string if failed
func create_world(world_name: String) -> String:
	# Check limits
	if get_all_worlds().size() >= MAX_WORLDS:
		push_error("Maximum number of worlds reached")
		return ""
		
	# Generate ID (using timestamp + random suffix)
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 1000
	var world_id = "world_%d_%d" % [timestamp, random_suffix]
	
	var world_dir = SAVE_DIR + world_id
	
	# Create directory
	var err = DirAccess.make_dir_absolute(world_dir)
	if err != OK:
		push_error("Failed to create world directory: %s" % error_string(err))
		return ""
		
	# Create initial metadata
	var current_time = Time.get_datetime_string_from_system()
	var metadata = {
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
	var world_dir = SAVE_DIR + world_id
	if not DirAccess.dir_exists_absolute(world_dir):
		return false
		
	# Delete all files in the directory first
	var dir = DirAccess.open(world_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
			
	# Remove the directory itself
	var err = DirAccess.remove_absolute(world_dir)
	return err == OK

# --- Save/Load Logic ---

## Saves the current game state to the current world's folder
func save_game(world_id: String) -> bool:
	if world_id.is_empty():
		return false
		
	var world_dir = SAVE_DIR + world_id
	if not DirAccess.dir_exists_absolute(world_dir):
		return false
	
	# 1. Update Metadata (Last Played)
	var metadata = _load_world_metadata(world_id)
	metadata["last_played"] = Time.get_datetime_string_from_system()
	_save_json(world_dir + "/" + METADATA_FILE, metadata)
	
	# 2. Collect Game State
	var save_data = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"inventory": Inventory.to_save_data(),
		"planting": {}, # Will be filled if PlantingSystem is found
		"player": {}
	}
	
	# Get data from active scene nodes
	var tree = get_tree()
	if tree.current_scene:
		# Find Player
		var player = tree.current_scene.find_child("Hana", true, false) # Adjust name if needed
		if player:
			save_data["player"] = {
				"position": {
					"x": player.global_position.x,
					"y": player.global_position.y
				}
			}
			
		# Find PlantingSystem
		var planting_system = tree.current_scene.find_child("PlantingSystem", true, false)
		if planting_system and planting_system.has_method("to_save_data"):
			save_data["planting"] = planting_system.to_save_data()
			
	# 3. Write Save File
	return _save_json(world_dir + "/" + SAVE_FILE, save_data)

## Loads the game state from the specified world
func load_game(world_id: String) -> bool:
	var world_dir = SAVE_DIR + world_id
	var file_path = world_dir + "/" + SAVE_FILE
	
	if not FileAccess.file_exists(file_path):
		# If save file doesn't exist (new world), that's fine, just init default state
		print("No save file found for %s, starting fresh." % world_id)
		return true
		
	var save_data = _load_json(file_path)
	if save_data.is_empty():
		return false
		
	# Apply data
	_apply_save_data(save_data)
	return true

func _apply_save_data(data: Dictionary) -> void:
	# 1. Inventory
	if data.has("inventory"):
		Inventory.from_save_data(data["inventory"])
		
	# 2. Scene Objects (Player, Plants)
	# These need the scene to be ready.
	# We'll use call_deferred or expect this to be called after scene load.
	var tree = get_tree()
	if tree.current_scene:
		# Apply Player Position
		if data.has("player") and data["player"].has("position"):
			var player = tree.current_scene.find_child("Hana", true, false)
			if player:
				var pos_data = data["player"]["position"]
				player.global_position = Vector2(pos_data["x"], pos_data["y"])
				
		# Apply Planting System
		if data.has("planting"):
			var planting_system = tree.current_scene.find_child("PlantingSystem", true, false)
			if planting_system and planting_system.has_method("from_save_data"):
				planting_system.from_save_data(data["planting"])

# --- Helpers ---

func _load_world_metadata(world_id: String) -> Dictionary:
	# world_id might be the folder name directly
	var path = SAVE_DIR + world_id + "/" + METADATA_FILE
	return _load_json(path)

func _save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s" % path)
		return false
	
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file for reading: %s" % path)
		return {}
		
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	
	if err != OK:
		push_error("JSON Parse Error: %s in %s at line %s" % [json.get_error_message(), path, json.get_error_line()])
		return {}
		
	return json.data
