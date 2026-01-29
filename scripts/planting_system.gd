class_name PlantingSystem
extends Node2D

## Main controller for the planting and building system.
##
## Delegates specific logic to child managers (Placement, Deletion, Interaction).
## Maintains the state of the world (occupied tiles).

# --- Dependencies (Injected via Editor) ---
@export var tile_map: TileMapLayer
@export var ysort_root: Node2D
@export var player: CharacterBody2D
@export var ui_root: CanvasLayer

# --- Configuration ---
@export var tile_size: Vector2 = Vector2(32, 32)

# --- State ---
## Dictionary { Vector2i: Node2D } - Maps coordinates to objects (Plants, Buildings)
var occupied_tiles: Dictionary = {}

enum Mode { NONE, PLACE, DELETE }
var current_mode: Mode = Mode.NONE

# --- Managers ---
var placement_manager: PlacementManager
var deletion_manager: DeletionManager
var interaction_manager: InteractionManager

# --- Constants ---
const GRASS_CLEAR_SOURCE_ID: int = 1

func _ready() -> void:
	_resolve_dependencies()
	_setup_managers()
	_connect_signals()
	_scan_existing_objects()

func _resolve_dependencies() -> void:
	# Fallback search if not assigned in Editor
	if not tile_map: 
		tile_map = get_parent().get_node_or_null("TileMapLayer")
	if not ysort_root: 
		ysort_root = get_parent().get_node_or_null("YSortRoot")
	if not player and ysort_root: 
		player = ysort_root.get_node_or_null("Hana")
	if not ui_root: 
		ui_root = get_parent().get_node_or_null("UI")
	
	if not tile_map or not player:
		push_error("PlantingSystem: Missing essential dependencies.")

func _setup_managers() -> void:
	# create managers
	placement_manager = PlacementManager.new()
	deletion_manager = DeletionManager.new()
	interaction_manager = InteractionManager.new()
	
	add_child(placement_manager)
	add_child(deletion_manager)
	add_child(interaction_manager)
	
	# inject dependencies
	var bulk_panel: Control = ui_root.get_node_or_null("BulkCostPanel") if ui_root else null
	placement_manager.setup(self, tile_map, ysort_root, player, bulk_panel)
	
	var delete_overlay: Control = ui_root.get_node_or_null("DeleteModeOverlay") if ui_root else null
	var refund_panel: Control = ui_root.get_node_or_null("RefundPanel") if ui_root else null
	deletion_manager.setup(self, tile_map, delete_overlay, refund_panel)
	
	var interact_area: Area2D = player.get_node_or_null("InteractArea") if player else null
	if not interact_area and player and player.has_method("get_interact_area"):
		interact_area = player.get_interact_area()
		
	interaction_manager.setup(self, tile_map, player, interact_area)
	
	# Start in default state (Interaction active)
	set_mode(Mode.NONE)

func _connect_signals() -> void:
	if BuildRegistry:
		BuildRegistry.active_buildable_changed.connect(_on_buildable_changed)

func _scan_existing_objects() -> void:
	if not ysort_root or not tile_map: return
	
	for child in ysort_root.get_children():
		if child.has_meta("buildable_id") or child is Plant or child is StorageBuilding:
			var coords: Vector2i = tile_map.local_to_map(child.global_position)
			occupied_tiles[coords] = child

# --- Mode Management ---

func set_mode(new_mode: Mode) -> void:
	if current_mode == new_mode: return
	
	# Exit previous
	match current_mode:
		Mode.PLACE: placement_manager.deactivate()
		Mode.DELETE: deletion_manager.deactivate()
		Mode.NONE: interaction_manager.deactivate()
		
	current_mode = new_mode
	
	# Enter new
	match current_mode:
		Mode.PLACE: placement_manager.activate()
		Mode.DELETE: deletion_manager.activate()
		Mode.NONE: interaction_manager.activate()

func _on_buildable_changed(item: BuildableItem) -> void:
	if item:
		set_mode(Mode.PLACE)
		placement_manager.refresh_preview()
	else:
		if current_mode == Mode.PLACE:
			set_mode(Mode.NONE)

func _process(delta: float) -> void:
	match current_mode:
		Mode.PLACE: placement_manager.update(delta)
		Mode.DELETE: deletion_manager.update(delta)
		Mode.NONE: interaction_manager.update(delta)

func _input(event: InputEvent) -> void:
	if DialogueManager and DialogueManager.is_active():
		return

	# Block if Rat Manager is open
	var rat_manager = get_tree().get_first_node_in_group("rat_manager_panel")
	if rat_manager and rat_manager.visible: return

	# Global Toggle: Delete Mode (F)
	if event.is_action_pressed("toggle_delete_mode"):
		if current_mode == Mode.DELETE:
			set_mode(Mode.NONE)
		else:
			# If building, clear active item first
			if BuildRegistry.active_buildable:
				BuildRegistry.clear_active()
			set_mode(Mode.DELETE)
		return
		
	# Route input to active manager
	match current_mode:
		Mode.PLACE: placement_manager.handle_input(event)
		Mode.DELETE: deletion_manager.handle_input(event)
		Mode.NONE: interaction_manager.handle_input(event)

# --- Public API for Managers ---

## Check if a tile is occupied by an object
func is_tile_occupied(coords: Vector2i) -> bool:
	return occupied_tiles.has(coords) and is_instance_valid(occupied_tiles[coords])

## Get the object at a specific tile coordinate
func get_object_at(coords: Vector2i) -> Node2D:
	if is_tile_occupied(coords):
		return occupied_tiles[coords]
	return null

## Register an object at a coordinate (Internal use)
func register_object(coords: Vector2i, object: Node2D) -> void:
	if object.has_method("get_occupied_tiles"):
		var tiles = object.get_occupied_tiles()
		# Fallback if method returns empty (shouldn't happen for valid objects)
		if tiles.is_empty():
			occupied_tiles[coords] = object
		else:
			for tile in tiles:
				occupied_tiles[tile] = object
	else:
		occupied_tiles[coords] = object

## Remove an object from a coordinate
func remove_object(coords: Vector2i) -> bool:
	if not is_tile_occupied(coords): return false
	
	var obj: Node2D = occupied_tiles[coords]
	
	# Clear ALL occupied tiles for this object
	if obj.has_method("get_occupied_tiles"):
		var tiles = obj.get_occupied_tiles()
		for tile in tiles:
			occupied_tiles.erase(tile)
	else:
		# Fallback cleanup (scan just in case, or assume single tile)
		# For safety, erase the target coords
		occupied_tiles.erase(coords)
		# If it was a multi-tile object without the method (legacy?), we might leave ghosts. 
		# But we assume all multi-tile objects implement the interface.
	
	if is_instance_valid(obj):
		obj.queue_free()
		
	return true

## Get the building/object at a tile (Alias)
func get_building_at_tile(coords: Vector2i) -> Node2D:
	return get_object_at(coords)

## Plant an item at a specific coordinate programmatically
func plant_item_at(coords: Vector2i, buildable_id: String) -> bool:
	if is_tile_occupied(coords):
		return false
		
	var item: BuildableItem = BuildRegistry.get_buildable(buildable_id)
	if not item or not item.scene:
		return false
		
	var instance: Node2D = item.scene.instantiate() as Node2D
	var pos: Vector2 = tile_map.map_to_local(coords)
	
	var final_offset: Vector2 = item.placement_offset
	if not item.ignore_system_offset and placement_manager:
		final_offset += placement_manager.plant_offset
		
	instance.global_position = pos + final_offset
	instance.set_meta("buildable_id", buildable_id)
	
	if instance.has_method("set_placement_data"):
		instance.set_placement_data(coords, false)
	
	# Clear ground tiles based on footprint
	var offsets = _get_footprint_offsets(item)
	for offset in offsets:
		tile_map.set_cell(coords + offset, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
	
	ysort_root.add_child(instance)
	register_object(coords, instance)
	
	return true

func _get_footprint_offsets(item: BuildableItem) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if not item: return [Vector2i.ZERO]
	
	var size = item.footprint_size
	var half_x = size.x / 2
	var half_y = size.y / 2
	
	for x in range(-half_x, -half_x + size.x):
		for y in range(-half_y, -half_y + size.y):
			offsets.append(Vector2i(x, y))
			
	return offsets

# --- Save / Load ---

func to_save_data() -> Dictionary:
	var plants_data: Array = []
	var processed_objects: Dictionary = {}
	
	for tile_coords in occupied_tiles:
		var plant: Node2D = occupied_tiles[tile_coords]
		if not is_instance_valid(plant): continue
		
		# Deduplicate multi-tile objects
		if processed_objects.has(plant): continue
		processed_objects[plant] = true
		
		# Only save objects with a buildable_id
		if not plant.has_meta("buildable_id"): continue
		
		var save_coords = tile_coords
		# Ensure we save the center coordinate for multi-tile objects
		if plant.has_method("get_center_tile"):
			save_coords = plant.get_center_tile()
		
		var data: Dictionary = {
			"x": save_coords.x,
			"y": save_coords.y,
			"buildable_id": plant.get_meta("buildable_id")
		}
		
		# Delegate detailed saving to object itself
		if plant.has_method("get_save_data"):
			var extra: Dictionary = plant.get_save_data()
			data.merge(extra)
			
		plants_data.append(data)
		
	return { "plants": plants_data }

func from_save_data(data: Dictionary) -> void:
	if not data.has("plants"): return
	
	# Usually loading happens on scene start, so let's assume empty or overwrite.
	
	for entry in data["plants"]:
		var coords: Vector2i = Vector2i(entry["x"], entry["y"])
		var id: String = entry.get("buildable_id", "")
		
		var item: BuildableItem = BuildRegistry.get_buildable(id)
		if not item or not item.scene: continue
		
		# Spawn
		var instance: Node2D = item.scene.instantiate() as Node2D
		var pos: Vector2 = tile_map.map_to_local(coords)
		
		var offset: Vector2 = item.placement_offset
		if not item.ignore_system_offset:
			offset += placement_manager.plant_offset
			
		instance.global_position = pos + offset
		instance.set_meta("buildable_id", id)
		
		# Set placement data (Crucial for multi-tile objects like StoneDeposit)
		if instance.has_method("set_placement_data"):
			instance.set_placement_data(coords, false)
		
		# Visuals - clear full footprint
		var offsets = _get_footprint_offsets(item)
		for off in offsets:
			tile_map.set_cell(coords + off, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
		
		ysort_root.add_child(instance)
		
		# Restore State BEFORE registering (so orientation/footprint is known)
		if instance.has_method("load_save_data"):
			instance.load_save_data(entry)
			
		register_object(coords, instance)
