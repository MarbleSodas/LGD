class_name PlantingSystem
extends Node2D

## Main controller for the planting and building system.
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
	if not tile_map: tile_map = get_parent().get_node_or_null("TileMapLayer")
	if not ysort_root: ysort_root = get_parent().get_node_or_null("YSortRoot")
	if not player: player = ysort_root.get_node_or_null("Hana") if ysort_root else null
	if not ui_root: ui_root = get_parent().get_node_or_null("UI")
	
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
	var bulk_panel = ui_root.get_node_or_null("BulkCostPanel") if ui_root else null
	placement_manager.setup(self, tile_map, ysort_root, player, bulk_panel)
	
	var delete_overlay = ui_root.get_node_or_null("DeleteModeOverlay") if ui_root else null
	deletion_manager.setup(self, tile_map, delete_overlay)
	
	var interact_area = player.get_node_or_null("InteractArea") if player else null
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
			var coords = tile_map.local_to_map(child.global_position)
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
	else:
		if current_mode == Mode.PLACE:
			set_mode(Mode.NONE)

func _process(delta: float) -> void:
	match current_mode:
		Mode.PLACE: placement_manager.update(delta)
		Mode.DELETE: deletion_manager.update(delta)
		Mode.NONE: interaction_manager.update(delta)

func _input(event: InputEvent) -> void:
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

func is_tile_occupied(coords: Vector2i) -> bool:
	return occupied_tiles.has(coords) and is_instance_valid(occupied_tiles[coords])

func get_object_at(coords: Vector2i) -> Node2D:
	if is_tile_occupied(coords):
		return occupied_tiles[coords]
	return null

func register_object(coords: Vector2i, object: Node2D) -> void:
	occupied_tiles[coords] = object

func remove_object(coords: Vector2i) -> bool:
	if not is_tile_occupied(coords): return false
	
	var obj = occupied_tiles[coords]
	occupied_tiles.erase(coords)
	
	if is_instance_valid(obj):
		obj.queue_free()
		
	return true

# --- Save / Load ---

func to_save_data() -> Dictionary:
	var plants_data = []
	
	for tile_coords in occupied_tiles:
		var plant = occupied_tiles[tile_coords]
		if not is_instance_valid(plant): continue
		
		# Only save objects with a buildable_id
		if not plant.has_meta("buildable_id"): continue
		
		var data = {
			"x": tile_coords.x,
			"y": tile_coords.y,
			"buildable_id": plant.get_meta("buildable_id")
		}
		
		# Delegate detailed saving to object itself
		if plant.has_method("get_save_data"):
			var extra = plant.get_save_data()
			data.merge(extra)
		# Legacy support for Plant properties
		elif plant.get("current_stage") != null:
			data["stage"] = plant.current_stage
			
		plants_data.append(data)
		
	return { "plants": plants_data }

func from_save_data(data: Dictionary) -> void:
	if not data.has("plants"): return
	
	# Clear existing first? Or just append? 
	# Usually loading happens on scene start, so let's assume empty or overwrite.
	
	for entry in data["plants"]:
		var coords = Vector2i(entry["x"], entry["y"])
		var id = entry.get("buildable_id", "")
		
		var item = BuildRegistry.get_item(id)
		if not item or not item.scene: continue
		
		# Visuals
		tile_map.set_cell(coords, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
		
		# Spawn
		var instance = item.scene.instantiate() as Node2D
		var pos = tile_map.map_to_local(coords)
		
		var offset = item.placement_offset
		if not item.ignore_system_offset:
			offset += placement_manager.plant_offset
			
		instance.global_position = pos + offset
		instance.set_meta("buildable_id", id)
		
		ysort_root.add_child(instance)
		register_object(coords, instance)
		
		# Restore State
		if instance.has_method("load_save_data"):
			instance.load_save_data(entry)
		# Legacy Plant Support
		elif instance.has_method("set_growth_stage") and entry.has("stage"):
			instance.set_growth_stage(int(entry["stage"]))
