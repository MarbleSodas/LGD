class_name MushroomHouse
extends Node2D

## Hub for the Rat Assistant. Manages task assignment and configuration.
## Handles interaction to open the Rat Manager UI.

const MAX_SOURCES = 10
const CHECK_INTERVAL = 1.0 # Check for work every second
const FRONT_DOOR_OFFSET = Vector2(0, 20)

@export var rat_scene: PackedScene = preload("res://scenes/rat_assistant.tscn")

# -- Dependencies --
var planting_system: PlantingSystem
var tile_map: TileMapLayer

# -- State --
var assigned_sources: Array[Vector2i] = []
var assigned_output: Vector2i = Vector2i.ZERO 
var has_output: bool = false
var show_debug_visuals: bool = false
var is_interacting: bool = false
var hover_coords: Vector2i = Vector2i.MAX
var hover_valid: bool = false

var rat_instance: RatAssistant = null
var _work_timer: float = 0.0

func _ready() -> void:
	add_to_group("mushroom_houses")
	
	# Find dependencies
	var root = get_tree().current_scene
	if root.has_node("PlantingSystem"):
		planting_system = root.get_node("PlantingSystem")
	elif root.name == "PlantingSystem":
		planting_system = root
	
	# Fallback
	if not planting_system:
		planting_system = get_tree().get_first_node_in_group("planting_system")
		
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

func interact() -> void:
	is_interacting = true
	# Open Rat Manager UI
	var panel = null
	
	# Try 1: UI Layer group
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		panel = ui_layer.get_node_or_null("RatManagerPanel")
		
	# Try 2: PlantingSystem reference
	if not panel and planting_system and planting_system.ui_root:
		panel = planting_system.ui_root.get_node_or_null("RatManagerPanel")
		
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
	var panel = _get_rat_manager_panel()
	if panel and panel.visible:
		panel.close()

func _notify_interaction_manager_closed() -> void:
	if planting_system and planting_system.interaction_manager:
		planting_system.interaction_manager.on_building_closed(self)

func _get_rat_manager_panel() -> Control:
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		return ui_layer.get_node_or_null("RatManagerPanel")
	return null

func on_hover_enter() -> void:
	set_show_visuals(true)

func on_hover_exit() -> void:
	if not is_interacting:
		set_show_visuals(false)

func set_show_visuals(show: bool) -> void:
	show_debug_visuals = show
	queue_redraw()

func _draw() -> void:
	if not show_debug_visuals: return
	if not tile_map: return
	
	var ts = Vector2(32, 32)
	if planting_system:
		ts = planting_system.tile_size
	var half_ts = ts / 2.0
	
	# Draw hover indicator (if hovering)
	if hover_coords != Vector2i.MAX:
		var pos = to_local(tile_map.map_to_local(hover_coords))
		var color = Color(0.0, 0.8, 0.0, 0.3) if hover_valid else Color(0.8, 0.0, 0.0, 0.3)
		var border = Color(0.0, 1.0, 0.0, 0.6) if hover_valid else Color(1.0, 0.0, 0.0, 0.6)
		draw_rect(Rect2(pos - half_ts, ts), color, true)
		draw_rect(Rect2(pos - half_ts, ts), border, false, 2.0)
	
	# Draw sources (Purple for Managed)
	for source in assigned_sources:
		var pos = to_local(tile_map.map_to_local(source))
		# Main fill
		draw_rect(Rect2(pos - half_ts, ts), Color(0.5, 0.0, 1.0, 0.4), true)
		# Border
		draw_rect(Rect2(pos - half_ts, ts), Color(0.8, 0.4, 1.0, 0.8), false, 2.0)
		
	# Draw output (Gold/Orange for Output)
	if has_output:
		var pos = to_local(tile_map.map_to_local(assigned_output))
		# Main fill
		draw_rect(Rect2(pos - half_ts, ts), Color(1.0, 0.6, 0.0, 0.4), true)
		# Border
		draw_rect(Rect2(pos - half_ts, ts), Color(1.0, 0.8, 0.2, 0.8), false, 2.0)

# --- Task Management ---

func _assign_next_task() -> void:
	if not has_output or not is_instance_valid(rat_instance): return 
	
	# If rat is busy, don't interrupt unless we want to queue (not implemented yet)
	if not rat_instance.is_available():
		return
		
	# Validate output exists
	if not _is_valid_output(assigned_output):
		return
		
	# Find best source relative to rat's current position
	var best_source = _find_best_source(rat_instance.global_position)
	if best_source != Vector2i.MAX:
		rat_instance.assign_task(best_source, assigned_output)
	# Else: no work found, rat stays idle

## Called by Rat when it finishes a harvest and wants more work nearby
func assign_next_task_nearby(rat: RatAssistant) -> bool:
	if not has_output: return false
	if not _is_valid_output(assigned_output): return false
	
	var best_source = _find_best_source(rat.global_position)
	if best_source != Vector2i.MAX:
		rat.assign_task(best_source, assigned_output)
		return true
		
	return false

## Called by Rat when it becomes idle (e.g. after depositing)
func on_rat_idle(rat: RatAssistant) -> void:
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
	valid_sources.sort_custom(func(a, b):
		var pos_a = tile_map.map_to_local(a)
		var pos_b = tile_map.map_to_local(b)
		return from_pos.distance_squared_to(pos_a) < from_pos.distance_squared_to(pos_b)
	)
	
	return valid_sources[0]

func _is_valid_output(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj = planting_system.get_object_at(coords)
	return obj != null and obj.has_method("get_container")

func _is_ready_harvest(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj = planting_system.get_object_at(coords)
	if not obj: return false
	if not obj.has_method("is_harvest_ready"): return false
	return obj.is_harvest_ready()

# --- Configuration API (for UI) ---

func can_add_source(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj = planting_system.get_object_at(coords)
	if not obj: return false
	# Valid if it has harvest capability (Plant) OR container (Barrel/Storage)
	return obj.has_method("is_harvest_ready") or obj.has_method("get_container")

func can_set_output(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj = planting_system.get_object_at(coords)
	if not obj: return false
	# Valid only if it has a container (storage buildings)
	return obj.has_method("get_container")

func update_hover(coords: Vector2i) -> void:
	hover_coords = coords
	# Valid if can be source OR can be output
	hover_valid = can_add_source(coords) or can_set_output(coords)
	queue_redraw()

func clear_hover() -> void:
	hover_coords = Vector2i.MAX
	queue_redraw()

func is_tile_assigned_to_others(coords: Vector2i) -> bool:
	var houses = get_tree().get_nodes_in_group("mushroom_houses")
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
	queue_redraw()
	return true

func remove_source(coords: Vector2i) -> void:
	assigned_sources.erase(coords)
	queue_redraw()

func set_output(coords: Vector2i) -> bool:
	if not can_set_output(coords):
		return false
		
	assigned_output = coords
	has_output = true
	queue_redraw()
	return true

func clear_output() -> void:
	assigned_output = Vector2i.ZERO
	has_output = false
	queue_redraw()

func get_source_count() -> int:
	return assigned_sources.size()

func get_output_info() -> String:
	if not has_output: return "None"
	return "Tile (%d, %d)" % [assigned_output.x, assigned_output.y]

func get_rest_position() -> Vector2:
	return global_position + FRONT_DOOR_OFFSET

# --- Save/Load ---

func get_save_data() -> Dictionary:
	var data = {
		"sources": [],
		"output_x": assigned_output.x,
		"output_y": assigned_output.y,
		"has_output": has_output
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
			
	if data.has("has_output"):
		has_output = data["has_output"]
		if has_output:
			assigned_output = Vector2i(data.get("output_x", 0), data.get("output_y", 0))
			
	if data.has("rat") and rat_instance:
		rat_instance.load_save_data(data["rat"])

func _exit_tree() -> void:
	if rat_instance and is_instance_valid(rat_instance):
		rat_instance.queue_free()
