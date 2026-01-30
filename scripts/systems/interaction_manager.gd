class_name InteractionManager
extends Node2D

## Manages player interaction with the world (Harvesting, Opening containers).
## Handles hovering highlights, range checks, and progress bars.

# --- Configuration ---
@export var tile_size: Vector2 = Vector2(32, 32)
@export var interact_highlight_color: Color = Color(1.0, 1.0, 0.0, 1.0) # Yellow (Out of range)
@export var interact_ready_color: Color = Color(0.0, 1.0, 0.0, 1.0)    # Green (Ready)
@export var interact_building_color: Color = Color(0.3, 0.5, 1.0, 1.0) # Blue (Building)

# --- Dependencies ---
var planting_system: PlantingSystem
var tile_map: TileMapLayer
var player: CharacterBody2D
var interact_area: Area2D

# --- Resources ---
var floating_text_scene = preload("res://ui/components/floating_text.tscn")
var progress_bar_scene = preload("res://ui/components/harvest_progress_bar.tscn")

# --- State ---
var hovered_tile: Vector2i = Vector2i.ZERO
var hovered_object: Node2D = null
var current_tile_center: Vector2 = Vector2.ZERO

# Harvesting State
var is_harvesting: bool = false
var harvest_target: Node2D = null
var harvest_timer: float = 0.0
var current_progress_bar: Control = null

# Building Interaction State
var current_interacting_building: Node2D = null

func _ready() -> void:
	name = "InteractionManager"

func setup(system: PlantingSystem, _tile_map: TileMapLayer, _player: CharacterBody2D, _interact_area: Area2D) -> void:
	planting_system = system
	tile_map = _tile_map
	player = _player
	interact_area = _interact_area

# --- Public API ---

func activate() -> void:
	queue_redraw()

func deactivate() -> void:
	if hovered_object and hovered_object.has_method("on_hover_exit"):
		hovered_object.on_hover_exit()
	_cancel_harvest()
	hovered_object = null
	queue_redraw()

func update(delta: float) -> void:
	# 1. Update Hover
	_update_hover()
	
	# 2. Process Harvest
	if is_harvesting:
		_process_harvest(delta)
	
	# 3. Auto-Harvest (Hold Key)
	if Input.is_action_pressed("harvest") and not is_harvesting:
		if hovered_object and _is_in_range(hovered_object):
			# Only auto-harvest plants (not chests)
			if hovered_object.has_method("harvest"):
				_interact_with(hovered_object)

func _draw() -> void:
	if hovered_object:
		_draw_interaction_highlight()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("harvest"):
		# Case 1: Toggle logic for building interactions
		if current_interacting_building:
			# If interaction is open, ANY interact press should close it
			_close_current_interaction()
			get_viewport().set_input_as_handled()
			return
		
		# Case 2: Standard Interaction
		if hovered_object and _is_in_range(hovered_object):
			_interact_with(hovered_object)
			get_viewport().set_input_as_handled()
			
	elif event.is_action_released("harvest"):
		if is_harvesting:
			_cancel_harvest()

# --- Logic ---

func _update_hover() -> void:
	if not tile_map: return
	
	var mouse_pos = get_global_mouse_position()
	
	# Priority 1: Check for interactable entities (NPCs)
	var entity = _get_entity_under_mouse(mouse_pos)
	if entity:
		if entity != hovered_object:
			if hovered_object and hovered_object.has_method("on_hover_exit"):
				hovered_object.on_hover_exit()
			hovered_object = entity
			hovered_tile = Vector2i(-999, -999) # Invalid tile
			if hovered_object.has_method("on_hover_enter"):
				hovered_object.on_hover_enter()
			queue_redraw()
		
		# Update center for drawing highlight
		current_tile_center = entity.global_position
		
		# Redraw if needed (e.g. range changes)
		if hovered_object:
			queue_redraw()
		return
		
	# Priority 2: Check Tiles
	var tile_coords = tile_map.local_to_map(mouse_pos)
	current_tile_center = tile_map.map_to_local(tile_coords)
	
	if tile_coords != hovered_tile or (hovered_object and not hovered_object is Node2D): # Force update if switching from entity
		if hovered_object and hovered_object.has_method("on_hover_exit"):
			hovered_object.on_hover_exit()
			
		hovered_tile = tile_coords
		hovered_object = planting_system.get_object_at(tile_coords)
		
		if hovered_object and hovered_object.has_method("on_hover_enter"):
			hovered_object.on_hover_enter()
			
		queue_redraw()
	
	# If moving while harvesting, check range break
	if is_harvesting and harvest_target:
		if not _is_in_range(harvest_target):
			_cancel_harvest()
			
	# Always redraw if hovering to update dynamic range color
	if hovered_object:
		queue_redraw()

func _get_entity_under_mouse(pos: Vector2) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true # Check areas (NPCs might be Area2D or have one)
	query.collide_with_bodies = true
	query.collision_mask = 1 | 2 | 4 # Check standard layers (adjust if needed)
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("interact") and not collider.has_method("harvest"): # Distinguish from plants if needed
			return collider
	return null

func _is_in_range(target: Node2D) -> bool:
	if not is_instance_valid(target) or not interact_area: return false
	
	# Simple distance check based on InteractArea radius (approx 36 + buffer)
	var max_dist = 64.0 # Increased from 52 to allow slightly more leniency for large objects
	
	# Check distance to ANY occupied tile for multi-tile objects
	if target.has_method("get_occupied_tiles"):
		var tiles = target.get_occupied_tiles()
		if not tiles.is_empty():
			var min_dist = 9999.0
			var interact_pos = interact_area.global_position
			
			for tile_coords in tiles:
				# Get center of the tile
				var tile_center = tile_map.map_to_local(tile_coords)
				var dist = interact_pos.distance_to(tile_center)
				if dist < min_dist:
					min_dist = dist
					
			return min_dist <= max_dist

	# Fallback: Distance to object origin
	return target.global_position.distance_to(interact_area.global_position) <= max_dist

func _interact_with(target: Node2D) -> void:
	if is_harvesting: return
	
	# Case 1: Building (Immediate Interaction)
	if target.has_method("interact"):
		current_interacting_building = target
		target.interact()
		return
		
	# Case 2: Plant (Harvesting with Timer)
	_start_harvest(target)

func _start_harvest(target: Node2D) -> void:
	if not target.has_method("harvest"): return
	if target.has_method("is_harvest_ready") and not target.is_harvest_ready(): return
	
	is_harvesting = true
	harvest_target = target
	harvest_timer = 0.0
	
	_create_progress_bar(target)

func _create_progress_bar(target: Node2D) -> void:
	if current_progress_bar: current_progress_bar.queue_free()
	
	current_progress_bar = progress_bar_scene.instantiate()
	add_child(current_progress_bar)
	current_progress_bar.global_position = target.global_position + Vector2(-12, 16)
	current_progress_bar.visible = true

func _process_harvest(delta: float) -> void:
	if not is_instance_valid(harvest_target):
		_cancel_harvest()
		return
		
	var duration = harvest_target.get("harvest_time") if "harvest_time" in harvest_target else 0.5
	harvest_timer += delta
	
	if current_progress_bar:
		if current_progress_bar.has_method("update_progress"):
			current_progress_bar.update_progress(harvest_timer, duration)
		else:
			current_progress_bar.value = (harvest_timer / duration) * 100
			
	if harvest_timer >= duration:
		_complete_harvest()

func _complete_harvest() -> void:
	var target = harvest_target
	_cancel_harvest()
	
	if not is_instance_valid(target): return
	
	var drops = target.harvest()
	if drops.is_empty(): return
	
	# Give Item
	if Inventory and ItemRegistry:
		var item = ItemRegistry.get_item(drops.get("item_id", ""))
		var amount = drops.get("amount", 1)
		if item:
			Inventory.add_item(item, amount)
			_spawn_text(target.global_position, "+%d" % amount, item.icon)

	# Check if destroyed
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		# Need to remove from system
		var tile = planting_system.occupied_tiles.find_key(target)
		if tile:
			planting_system.remove_object(tile)
			tile_map.set_cell(tile, 0, Vector2i.ZERO) # Reset to grass

func _cancel_harvest() -> void:
	is_harvesting = false
	harvest_target = null
	harvest_timer = 0.0
	if current_progress_bar:
		current_progress_bar.queue_free()
		current_progress_bar = null

func _spawn_text(pos: Vector2, text: String, icon: Texture2D = null) -> void:
	var popup = floating_text_scene.instantiate()
	get_parent().get_parent().add_child(popup) # Add to World or UI
	popup.global_position = pos + Vector2(0, -20)
	if popup.has_method("set_content"):
		popup.set_content(text, icon)
	elif popup.has_method("set_text_content"):
		popup.set_text_content(text)
	else:
		popup.text = text

# --- Interaction State Management ---

func _close_current_interaction() -> void:
	if not is_instance_valid(current_interacting_building):
		current_interacting_building = null
		return
		
	# Close via the building's API if available
	if current_interacting_building.has_method("close_interaction"):
		current_interacting_building.close_interaction()
	
	# Clear reference
	current_interacting_building = null

func on_building_closed(building: Node2D) -> void:
	# Callback from building when closed by other means (Escape, Close Button)
	if current_interacting_building == building:
		current_interacting_building = null

# --- Visuals ---

func _draw_interaction_highlight() -> void:
	if not hovered_object: return
	
	var in_range = _is_in_range(hovered_object)
	var col = interact_highlight_color
	
	if hovered_object.has_method("is_harvest_ready"):
		# Plant
		if in_range and hovered_object.is_harvest_ready():
			col = interact_ready_color
	else:
		# Building / Entity
		if in_range:
			col = interact_building_color
			
	if hovered_object.is_in_group("interactable"):
		# Skip highlight for NPCs that have their own interact prompt
		if hovered_object is NPCBase:
			return

		draw_circle(to_local(current_tile_center), 20.0, col)
		draw_circle(to_local(current_tile_center), 22.0, col, false, 2.0)
	else:
		_draw_tile_outline(current_tile_center, col)

func _draw_tile_outline(center: Vector2, color: Color) -> void:
	var half = tile_size / 2.0
	var local = to_local(center)
	draw_rect(Rect2(local - half, tile_size), color, false, 1.0)
