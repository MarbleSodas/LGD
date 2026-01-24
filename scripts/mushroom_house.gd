class_name MushroomHouse
extends Node2D

## Hub for the Rat Assistant.
##
## Manages task assignment (harvest, plant, store) and configuration.
## Handles interaction to open the Rat Manager UI.

const MAX_SOURCES: int = 10
const MAX_OUTPUTS: int = 10
const CHECK_INTERVAL: float = 1.0 # Check for work every second
const FRONT_DOOR_OFFSET: Vector2 = Vector2(0, 20)

const GROUP_MUSHROOM_HOUSES: String = "mushroom_houses"
const GROUP_UI_LAYER: String = "ui_layer"
const GROUP_PLANTING_SYSTEM: String = "planting_system"

@export var rat_scene: PackedScene = preload("res://scenes/rat_assistant.tscn")

# -- Dependencies --
var planting_system: PlantingSystem
var tile_map: TileMapLayer

# -- State --
var assigned_sources: Array[Vector2i] = []
var assigned_outputs: Array[Vector2i] = []
var _output_rr_index: int = 0
var _planting_rr_index: int = 0
var show_debug_visuals: bool = false
var is_interacting: bool = false
var hover_coords: Vector2i = Vector2i.MAX
var hover_valid: bool = false

var rat_instance: RatAssistant = null
var _work_timer: float = 0.0

# -- Visuals --
var _visuals_overlay: Node2D

func _ready() -> void:
	add_to_group(GROUP_MUSHROOM_HOUSES)
	
	# Setup Overlay Node for drawing highlights on top of world
	_visuals_overlay = Node2D.new()
	_visuals_overlay.name = "VisualsOverlay"
	_visuals_overlay.z_index = 100 # Ensure it draws above YSorted objects
	add_child(_visuals_overlay)
	# Inject a script to handle the draw callback
	var script = GDScript.new()
	script.source_code = "extends Node2D\nfunc _draw(): get_parent()._draw_overlay()"
	script.reload()
	_visuals_overlay.set_script(script)
	
	# Find dependencies
	var root: Node = get_tree().current_scene
	if root.has_node("PlantingSystem"):
		planting_system = root.get_node("PlantingSystem")
	elif root.name == "PlantingSystem":
		planting_system = root
	
	# Fallback
	if not planting_system:
		planting_system = get_tree().get_first_node_in_group(GROUP_PLANTING_SYSTEM)
		
	if planting_system:
		tile_map = planting_system.tile_map

	# Spawn rat if not exists
	_spawn_rat()

func _process(delta: float) -> void:
	if not is_instance_valid(rat_instance): return
	
	# Periodically check for work if rat is idle
	if rat_instance.is_available():
		_work_timer += delta
		if _work_timer >= CHECK_INTERVAL:
			_work_timer = 0.0
			_assign_next_task()

func _spawn_rat() -> void:
	if rat_instance: return
	if not rat_scene: return
	
	rat_instance = rat_scene.instantiate()
	# Place rat near the door (offset)
	rat_instance.position = position + FRONT_DOOR_OFFSET
	
	# Inject dependencies into rat
	rat_instance.home_building = self
	rat_instance.planting_system = planting_system
	rat_instance.tile_map = tile_map
	
	# Add to same parent (YSortRoot) so it y-sorts correctly
	get_parent().add_child.call_deferred(rat_instance)

# ------------------------------------------------------------------------------
# Interaction & UI
# ------------------------------------------------------------------------------

func interact() -> void:
	is_interacting = true
	var panel: Control = _get_rat_manager_panel()
	
	if panel:
		panel.open(self)
		set_show_visuals(true)
	else:
		print("RatManagerPanel not found!")

func on_ui_closed() -> void:
	is_interacting = false
	set_show_visuals(false)
	_notify_interaction_manager_closed()

func close_interaction() -> void:
	var panel: Control = _get_rat_manager_panel()
	if panel and panel.visible:
		panel.close()

func _notify_interaction_manager_closed() -> void:
	if planting_system and planting_system.interaction_manager:
		planting_system.interaction_manager.on_building_closed(self)

func _get_rat_manager_panel() -> Control:
	# Try 1: UI Layer group
	var ui_layer: Node = get_tree().get_first_node_in_group(GROUP_UI_LAYER)
	if ui_layer:
		return ui_layer.get_node_or_null("RatManagerPanel")
		
	# Try 2: PlantingSystem reference
	if planting_system and planting_system.ui_root:
		return planting_system.ui_root.get_node_or_null("RatManagerPanel")
		
	return null

func on_hover_enter() -> void:
	set_show_visuals(true)

func on_hover_exit() -> void:
	if not is_interacting:
		set_show_visuals(false)

func set_show_visuals(enabled: bool) -> void:
	show_debug_visuals = enabled
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()

func _draw_overlay() -> void:
	if not show_debug_visuals: return
	if not tile_map: return
	
	# Drawing context is _visuals_overlay (child of House)
	# It shares the same position as House, so to_local works relative to House position.
	
	var ts: Vector2 = Vector2(32, 32)
	if planting_system:
		ts = planting_system.tile_size
	var half_ts: Vector2 = ts / 2.0
	
	# Draw hover indicator (if hovering)
	if hover_coords != Vector2i.MAX:
		var pos: Vector2 = to_local(tile_map.map_to_local(hover_coords))
		var color: Color = Color(0.0, 0.8, 0.0, 0.3) if hover_valid else Color(0.8, 0.0, 0.0, 0.3)
		var border: Color = Color(0.0, 1.0, 0.0, 0.6) if hover_valid else Color(1.0, 0.0, 0.0, 0.6)
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), color, true)
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), border, false, 2.0)
	
	# Draw sources (Purple for Managed)
	for source in assigned_sources:
		var pos: Vector2 = to_local(tile_map.map_to_local(source))
		# Main fill
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), Color(0.5, 0.0, 1.0, 0.4), true)
		# Border
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), Color(0.8, 0.4, 1.0, 0.8), false, 2.0)
		
	# Draw outputs (Gold/Orange)
	for out in assigned_outputs:
		var pos: Vector2 = to_local(tile_map.map_to_local(out))
		# Main fill
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), Color(1.0, 0.6, 0.0, 0.4), true)
		# Border
		_visuals_overlay.draw_rect(Rect2(pos - half_ts, ts), Color(1.0, 0.8, 0.2, 0.8), false, 2.0)

# ------------------------------------------------------------------------------
# Task Management
# ------------------------------------------------------------------------------

func _assign_next_task() -> void:
	if assigned_outputs.is_empty() or not is_instance_valid(rat_instance): return 
	if not rat_instance.is_available(): return
	
	# Priority 1: Planting (If we have seeds)
	if _try_assign_planting():
		return

	# Priority 2: Delivering Existing Items
	if _try_assign_delivery():
		return
		
	# Priority 3: Standard Harvest
	_try_assign_harvest()

func _try_assign_planting() -> bool:
	# Check if we have ANY plantable items in inventory
	if not rat_instance.inventory.has_items():
		return false
		
	if not BuildRegistry:
		return false
		
	# Dictionary based iteration {item_id: count}
	if "items" in rat_instance.inventory:
		for item_id in rat_instance.inventory.items:
			var buildable_id: String = BuildRegistry.get_buildable_id_from_cost(item_id)
			if buildable_id != "":
				# Is it actually a plant?
				if BuildRegistry.is_buildable_a_plant(buildable_id):
					# Found a valid seed! Try to plant it.
					var plant_target: Vector2i = _find_planting_target()
					if plant_target != Vector2i.MAX:
						var current_grid: Vector2i = tile_map.local_to_map(rat_instance.global_position)
						rat_instance.assign_task(current_grid, plant_target)
						return true
					
	return false

func _try_assign_delivery() -> bool:
	if rat_instance.inventory.has_items():
		var target_output: Vector2i = _get_next_valid_output()
		if target_output != Vector2i.MAX:
			var current_grid: Vector2i = tile_map.local_to_map(rat_instance.global_position)
			rat_instance.assign_task(current_grid, target_output)
			return true
	return false

func _try_assign_harvest() -> bool:
	# Only harvest if we have capacity
	if rat_instance.inventory.is_full():
		return false

	var target_output: Vector2i = _get_next_valid_output()
	if target_output == Vector2i.MAX:
		return false
		
	# Find best source relative to rat's current position
	var best_source: Vector2i = _find_best_source(rat_instance.global_position)
	
	# Anti-Loop Logic: Prevent taking from X and putting into X
	if best_source != Vector2i.MAX and best_source == target_output:
		return false

	if best_source != Vector2i.MAX:
		rat_instance.assign_task(best_source, target_output)
		return true
	return false

## Called by Rat when it finishes a harvest and wants more work nearby
func assign_next_task_nearby(rat: RatAssistant) -> bool:
	if assigned_outputs.is_empty(): return false
	
	# Priority 1: Plant if holding seeds (Round robin planting)
	if _try_assign_planting():
		return true
	
	# Priority 2: Deliver if full or holding items
	if rat.inventory.is_full():
		var target_output: Vector2i = _get_next_valid_output()
		if target_output != Vector2i.MAX:
			var current_grid: Vector2i = tile_map.local_to_map(rat.global_position)
			rat.assign_task(current_grid, target_output)
			return true
	
	# Priority 3: More harvest if space remains
	if not rat.inventory.is_full():
		var target_output: Vector2i = _get_next_valid_output()
		if target_output == Vector2i.MAX: return false
		
		var best_source: Vector2i = _find_best_source(rat.global_position)
		if best_source != Vector2i.MAX and best_source != target_output:
			rat.assign_task(best_source, target_output)
			return true
		
	return false

## Helper to get next output in Round-Robin fashion.
## NOTE: This now strictly looks for CONTAINERS (for delivery/storage).
## Empty tiles (for planting) are handled by _find_planting_target().
## Now supports smart filtering for Processors.
func _get_next_valid_output() -> Vector2i:
	if assigned_outputs.is_empty(): return Vector2i.MAX
	
	# Try each output starting from current index
	for i in range(assigned_outputs.size()):
		var idx: int = (_output_rr_index + i) % assigned_outputs.size()
		var coords: Vector2i = assigned_outputs[idx]
		
		# Strictly check for CONTAINER
		var is_container: bool = false
		var processor_wants_items: bool = true # Assume true for generics
		
		if planting_system:
			var obj: Node2D = planting_system.get_object_at(coords)
			if obj and obj.has_method("get_container"):
				is_container = true
				
				# Smart Check: If it's a processor, does it want what we have?
				if obj.has_method("get_wanted_item_id"):
					var wanted: String = obj.get_wanted_item_id()
					# If processor wants specific item, do we have it?
					# If wanted is empty (no recipe), treat as rejecting everything
					if wanted == "":
						processor_wants_items = false
					elif rat_instance and not rat_instance.inventory.has_item(wanted):
						processor_wants_items = false
		
		if is_container and processor_wants_items and not _is_output_full(coords):
			# Found a valid container
			_output_rr_index = (idx + 1) % assigned_outputs.size()
			return coords
			
	return Vector2i.MAX

func _find_planting_target() -> Vector2i:
	if not planting_system: return Vector2i.MAX
	if assigned_outputs.is_empty(): return Vector2i.MAX
	
	# Round Robin for Planting
	for i in range(assigned_outputs.size()):
		var idx: int = (_planting_rr_index + i) % assigned_outputs.size()
		var coords: Vector2i = assigned_outputs[idx]
		
		if not planting_system.is_tile_occupied(coords):
			_planting_rr_index = (idx + 1) % assigned_outputs.size()
			return coords
			
	return Vector2i.MAX

## Check if output container is full
func _is_output_full(coords: Vector2i) -> bool:
	if not planting_system: return true
	var obj: Node2D = planting_system.get_object_at(coords)
	
	if not obj:
		# Empty tile is available (not full)
		return false
		
	if not obj.has_method("get_container"): return true # Blocked by non-container
	
	var container: Object = obj.get_container()
	if not container: return true
	
	if container.has_method("is_full"):
		return container.is_full()
		
	return false

## Called by Rat when it becomes idle (e.g. after depositing)
func on_rat_idle(_rat: RatAssistant) -> void:
	_assign_next_task()

func _find_best_source(from_pos: Vector2) -> Vector2i:
	if not planting_system: return Vector2i.MAX
	
	var valid_sources: Array[Vector2i] = []
	
	# 1. Filter ready sources
	for source in assigned_sources:
		if _is_ready_harvest(source):
			valid_sources.append(source)
			
	if valid_sources.is_empty():
		return Vector2i.MAX
		
	# 2. Sort by distance to from_pos
	# We need to convert map coords to world pos for distance
	valid_sources.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = tile_map.map_to_local(a)
		var pos_b: Vector2 = tile_map.map_to_local(b)
		return from_pos.distance_squared_to(pos_a) < from_pos.distance_squared_to(pos_b)
	)
	
	return valid_sources[0]

func _is_valid_output(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj: Node2D = planting_system.get_object_at(coords)
	
	# Allow empty tiles (for planting)
	if not obj: return true
	
	# Otherwise requires container
	return obj.has_method("get_container")

func _is_ready_harvest(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj: Node2D = planting_system.get_object_at(coords)
	if not obj: return false
	if not obj.has_method("is_harvest_ready"): return false
	return obj.is_harvest_ready()

# ------------------------------------------------------------------------------
# Configuration API (for UI)
# ------------------------------------------------------------------------------

func can_add_source(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj: Node2D = planting_system.get_object_at(coords)
	
	# Allow empty tiles (for Managed Planting)
	if not obj: return true
	
	# Valid if it has harvest capability (Plant) OR container (Barrel/Storage)
	return obj.has_method("is_harvest_ready") or obj.has_method("get_container")

func can_set_output(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj: Node2D = planting_system.get_object_at(coords)
	
	# Allow empty tiles
	if not obj: return true
	
	# Valid only if it has a container (storage buildings)
	return obj.has_method("get_container")

func update_hover(coords: Vector2i) -> void:
	hover_coords = coords
	# Valid if can be source OR can be output
	hover_valid = can_add_source(coords) or can_set_output(coords)
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()

func clear_hover() -> void:
	hover_coords = Vector2i.MAX
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()

func is_tile_assigned_to_others(coords: Vector2i) -> bool:
	var houses: Array[Node] = get_tree().get_nodes_in_group(GROUP_MUSHROOM_HOUSES)
	for house in houses:
		if house == self: continue
		if coords in house.assigned_sources:
			return true
	return false

func add_source(coords: Vector2i) -> bool:
	if assigned_sources.size() >= MAX_SOURCES:
		return false
	if coords in assigned_sources:
		return false
	# Check valid object
	if not can_add_source(coords):
		return false
	# Check overlap
	if is_tile_assigned_to_others(coords):
		return false
		
	assigned_sources.append(coords)
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()
	return true

func remove_source(coords: Vector2i) -> void:
	assigned_sources.erase(coords)
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()

func toggle_output(coords: Vector2i) -> bool:
	if coords in assigned_outputs:
		assigned_outputs.erase(coords)
		if _visuals_overlay:
			_visuals_overlay.queue_redraw()
		return true
		
	if assigned_outputs.size() < MAX_OUTPUTS:
		if can_set_output(coords):
			assigned_outputs.append(coords)
			if _visuals_overlay:
				_visuals_overlay.queue_redraw()
			return true
			
	return false

func get_source_count() -> int:
	return assigned_sources.size()

func get_output_info() -> String:
	if assigned_outputs.is_empty(): return "None"
	if assigned_outputs.size() == 1:
		var out: Vector2i = assigned_outputs[0]
		return "Tile (%d, %d)" % [out.x, out.y]
	return "%d defined" % assigned_outputs.size()

func get_rest_position() -> Vector2:
	return global_position + FRONT_DOOR_OFFSET

# ------------------------------------------------------------------------------
# Save/Load
# ------------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var output_data: Array = []
	for out in assigned_outputs:
		output_data.append({"x": out.x, "y": out.y})

	var data: Dictionary = {
		"sources": [],
		"outputs": output_data
	}
	
	for s in assigned_sources:
		data["sources"].append({"x": s.x, "y": s.y})
		
	if rat_instance:
		data["rat"] = rat_instance.get_save_data()
		
	return data

func load_save_data(data: Dictionary) -> void:
	if data.has("sources"):
		assigned_sources.clear()
		for s in data["sources"]:
			assigned_sources.append(Vector2i(s["x"], s["y"]))
			
	assigned_outputs.clear()
	if data.has("outputs"):
		for out in data["outputs"]:
			assigned_outputs.append(Vector2i(out["x"], out["y"]))
			
	if data.has("rat") and rat_instance:
		rat_instance.load_save_data(data["rat"])

func _exit_tree() -> void:
	if rat_instance and is_instance_valid(rat_instance):
		rat_instance.queue_free()
