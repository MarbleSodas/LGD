class_name MushroomHouse
extends Node2D

## Hub for the Rat Assistant.
##
## Manages task assignment with strict priorities:
## 1. Deposit (if inventory full).
## 2. Harvest (standard work).
## 3. Flush Inventory (if items held).


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
# Removed _planting_rr_index

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
			var _result: bool = assign_next_task()

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
# Task Management (REWRITTEN)
# ------------------------------------------------------------------------------

func assign_next_task(force: bool = false) -> bool:
	if not is_instance_valid(rat_instance):
		return false

	if not force and not rat_instance.is_available():
		return false

	# PRIORITY 1: DEPOSITING
	# If full, must deposit.
	if rat_instance.inventory.is_full():
		if try_assign_deposit(force):
			return true

	# PRIORITY 2: HARVESTING (Standard)
	# Harvest from sources.
	if not rat_instance.inventory.is_full():
		if _try_assign_harvest(force):
			return true

	# PRIORITY 3: FLUSH INVENTORY (Optional)
	# If we have stuff and nothing else to do, try to deposit it.
	if rat_instance.inventory.has_items():
		if try_assign_deposit(force):
			return true

	return false




func try_assign_deposit(force: bool = false) -> bool:
	# Find a valid output that accepts our items
	var target: Vector2i = _get_next_valid_output_for_deposit()
	if target != Vector2i.MAX:
		rat_instance.assign_task(RatAssistant.TaskType.DEPOSIT, target, force)
		return true
	return false

func _get_next_valid_output_for_deposit() -> Vector2i:
	if assigned_outputs.is_empty(): return Vector2i.MAX

	for i in range(assigned_outputs.size()):
		var idx: int = (_output_rr_index + i) % assigned_outputs.size()
		var coords: Vector2i = assigned_outputs[idx]

		if _can_deposit_to(coords):
			_output_rr_index = (idx + 1) % assigned_outputs.size()
			return coords

	return Vector2i.MAX

func _can_deposit_to(coords: Vector2i) -> bool:
	if not planting_system: return false
	var obj = planting_system.get_object_at(coords)
	if not obj or not obj.has_method("get_container"): return false

	# Check if processor/container wants our items
	if obj.has_method("get_wanted_item_id"):
		var wanted = obj.get_wanted_item_id()
		if wanted == "": return false # Wants nothing
		if not rat_instance.inventory.has_item(wanted): return false # We don't have it

	# Check if full
	var container = obj.get_container()
	if container and container.has_method("is_full") and container.is_full():
		return false

	return true

func _try_assign_harvest(force: bool = false) -> bool:
	var required_item: String = ""
	# If holding items, restrict harvest to same item type
	if rat_instance.inventory.has_items():
		required_item = rat_instance.inventory.get_first_item_id()

	# Find best source
	var best_source: Vector2i = _find_best_source(rat_instance.global_position, required_item)
	if best_source != Vector2i.MAX:
		rat_instance.assign_task(RatAssistant.TaskType.HARVEST, best_source, force)
		return true
	return false

## Called by Rat when it finishes a task and wants more work nearby
func on_rat_idle(_rat: RatAssistant) -> void:
	# Simply re-run the main assignment logic
	var _result: bool = assign_next_task()

# Compatibility / Deprecated but kept for safety if needed
func assign_next_task_nearby(_rat: RatAssistant) -> bool:
	return assign_next_task()

func _find_best_source(from_pos: Vector2, required_item: String = "") -> Vector2i:
	if not planting_system: return Vector2i.MAX

	var valid_sources: Array[Vector2i] = []

	for source in assigned_sources:
		if _is_ready_harvest(source):
			# Filter by item type if required
			if required_item != "":
				var source_item = _get_source_item_id(source)
				if source_item != required_item:
					continue
					
			valid_sources.append(source)

	if valid_sources.is_empty():
		return Vector2i.MAX

	valid_sources.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = tile_map.map_to_local(a)
		var pos_b: Vector2 = tile_map.map_to_local(b)
		return from_pos.distance_squared_to(pos_a) < from_pos.distance_squared_to(pos_b)
	)

	return valid_sources[0]

func _get_source_item_id(coords: Vector2i) -> String:
	if not planting_system: return ""
	var obj: Node2D = planting_system.get_object_at(coords)
	if not obj: return ""
	
	# Plant
	if "harvest_item_id" in obj:
		return obj.harvest_item_id
		
	# Storage / Container
	if obj.has_method("get_container"):
		var container = obj.get_container()
		if container:
			# Check first occupied slot
			for i in range(container.slot_count):
				var slot = container.get_slot(i)
				if slot != null:
					return slot.item.id
	
	return ""

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

	# Allow empty tiles? NO, strictly containers for output now,
	# since planting target is determined by empty Sources.
	if not obj: return false

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

func _resolve_source_tile(coords: Vector2i) -> Vector2i:
	if not planting_system: return coords
	var obj = planting_system.get_object_at(coords)
	if obj and obj.has_method("get_harvest_tile"):
		return obj.get_harvest_tile()
	return coords

func _resolve_output_tile(coords: Vector2i) -> Vector2i:
	if not planting_system: return coords
	var obj = planting_system.get_object_at(coords)
	if obj and obj.has_method("get_deposit_tile"):
		return obj.get_deposit_tile()
	return coords

func add_source(coords: Vector2i) -> bool:
	var target = _resolve_source_tile(coords)

	if assigned_sources.size() >= MAX_SOURCES:
		return false
	if target in assigned_sources:
		return false

	# Mutual Exclusivity Check
	if target in assigned_outputs:
		return false

	# Check valid object
	if not can_add_source(coords):
		return false
	# Check overlap
	if is_tile_assigned_to_others(target):
		return false

	assigned_sources.append(target)
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()
	return true

func remove_source(coords: Vector2i) -> void:
	var target = _resolve_source_tile(coords)
	assigned_sources.erase(target)
	if _visuals_overlay:
		_visuals_overlay.queue_redraw()

func toggle_output(coords: Vector2i) -> bool:
	var target = _resolve_output_tile(coords)

	if target in assigned_outputs:
		assigned_outputs.erase(target)
		if _visuals_overlay:
			_visuals_overlay.queue_redraw()
		return true

	if assigned_outputs.size() < MAX_OUTPUTS:
		if can_set_output(coords):
			# Mutual Exclusivity Check
			if target in assigned_sources:
				return false

			assigned_outputs.append(target)
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
