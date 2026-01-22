class_name DeletionManager
extends Node2D

## Manages deletion of placed objects.
## Handles highlighting, bulk selection, and removal validation.

# --- Configuration ---
@export var tile_size: Vector2 = Vector2(32, 32)
@export var delete_highlight_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var delete_grid_color: Color = Color(1.0, 0.3, 0.3, 0.6)
@export var delete_bulk_color: Color = Color(1.0, 0.2, 0.2, 0.7)
@export var grid_radius: int = 2

# --- Dependencies ---
var planting_system: PlantingSystem
var tile_map: TileMapLayer
var delete_overlay: Control

# --- State ---
var show_grid: bool = false
var current_tile_center: Vector2 = Vector2.ZERO
var hovered_tile: Vector2i = Vector2i.ZERO
var hovered_plant: Node2D = null
var last_hovered_plant: Node2D = null

# Bulk Delete State
var bulk_start_tile: Vector2i = Vector2i.ZERO
var bulk_start_set: bool = false

const GRASS_SOURCE_ID: int = 0

func _ready() -> void:
	name = "DeletionManager"

func setup(system: PlantingSystem, _tile_map: TileMapLayer, _overlay: Control) -> void:
	planting_system = system
	tile_map = _tile_map
	delete_overlay = _overlay

# --- Public API ---

func activate() -> void:
	show_grid = true
	if delete_overlay: delete_overlay.show_overlay()
	queue_redraw()

func deactivate() -> void:
	show_grid = false
	_cancel_bulk_delete()
	_clear_plant_highlight()
	if delete_overlay: delete_overlay.hide_overlay()
	queue_redraw()

func update(delta: float) -> void:
	_update_preview()

func _draw() -> void:
	if not show_grid: return
	
	if bulk_start_set:
		_draw_bulk_delete_selection()
	else:
		_draw_delete_grid()

# --- Logic ---

func handle_input(event: InputEvent) -> void:
	# Right Click: Cancel
	if event.is_action_pressed("cancel"):
		if bulk_start_set:
			_cancel_bulk_delete()
		else:
			planting_system.set_mode(PlantingSystem.Mode.NONE)
		return

	# Left Click: Action
	if event.is_action_pressed("place"):
		if bulk_start_set:
			_execute_bulk_delete()
		elif Input.is_action_pressed("bulk_modifier"):
			_start_bulk_delete()
		elif hovered_plant:
			_delete_single(hovered_tile)

func _update_preview() -> void:
	if not tile_map: return
	
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map.local_to_map(mouse_pos)
	current_tile_center = tile_map.map_to_local(tile_coords)
	hovered_tile = tile_coords
	queue_redraw()
	
	if bulk_start_set:
		_clear_plant_highlight()
		return
		
	var plant = planting_system.get_object_at(tile_coords)
	
	if plant != hovered_plant:
		_clear_plant_highlight()
		hovered_plant = plant
		if hovered_plant:
			_highlight_plant(hovered_plant)

func _delete_single(coords: Vector2i) -> void:
	if planting_system.remove_object(coords):
		# Restore tile visual
		tile_map.set_cell(coords, GRASS_SOURCE_ID, Vector2i.ZERO)
		_clear_plant_highlight()

# --- Bulk Logic ---

func _start_bulk_delete() -> void:
	var mouse_pos = get_global_mouse_position()
	bulk_start_tile = tile_map.local_to_map(mouse_pos)
	bulk_start_set = true
	_clear_plant_highlight()
	queue_redraw()

func _cancel_bulk_delete() -> void:
	bulk_start_set = false
	queue_redraw()

func _execute_bulk_delete() -> void:
	if not tile_map: return
	
	var mouse_pos = get_global_mouse_position()
	var end_tile = tile_map.local_to_map(mouse_pos)
	var rect = _get_rect(bulk_start_tile, end_tile)
	
	var to_delete: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x, y)
			if planting_system.is_tile_occupied(coords):
				to_delete.append(coords)
	
	for coords in to_delete:
		if planting_system.remove_object(coords):
			tile_map.set_cell(coords, GRASS_SOURCE_ID, Vector2i.ZERO)
			
	_cancel_bulk_delete()

func _get_rect(start: Vector2i, end: Vector2i) -> Rect2i:
	var min_x = mini(start.x, end.x)
	var min_y = mini(start.y, end.y)
	var max_x = maxi(start.x, end.x)
	var max_y = maxi(start.y, end.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# --- Visuals ---

func _highlight_plant(plant: Node2D) -> void:
	if not is_instance_valid(plant): return
	last_hovered_plant = plant
	
	if not plant.has_meta("original_modulate"):
		plant.set_meta("original_modulate", plant.modulate)
	plant.modulate = delete_highlight_color

func _clear_plant_highlight() -> void:
	if is_instance_valid(last_hovered_plant):
		var orig = last_hovered_plant.get_meta("original_modulate", Color.WHITE)
		last_hovered_plant.modulate = orig
		last_hovered_plant.remove_meta("original_modulate")
	last_hovered_plant = null
	hovered_plant = null

func _draw_delete_grid() -> void:
	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			var dist = maxi(absi(x), absi(y))
			var alpha = 1.0 - (float(dist) / float(grid_radius + 1))
			var col = delete_grid_color
			col.a *= alpha
			
			var offset = Vector2(x * tile_size.x, y * tile_size.y)
			_draw_tile_outline(current_tile_center + offset, col)
			
			if x == 0 and y == 0 and hovered_plant:
				_draw_x_marker(current_tile_center)

func _draw_bulk_delete_selection() -> void:
	if not tile_map: return
	var mouse_pos = get_global_mouse_position()
	var end_tile = tile_map.local_to_map(mouse_pos)
	var rect = _get_rect(bulk_start_tile, end_tile)
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x, y)
			var w_pos = tile_map.map_to_local(coords)
			var occupied = planting_system.is_tile_occupied(coords)
			
			var col = delete_bulk_color if occupied else delete_grid_color
			if not occupied: col.a = 0.3
			
			_draw_tile_outline(w_pos, col)
			if occupied:
				_draw_x_marker(w_pos)

func _draw_tile_outline(center: Vector2, color: Color) -> void:
	var half = tile_size / 2.0
	var local = to_local(center)
	draw_rect(Rect2(local - half, tile_size), color, false, 1.0)

func _draw_x_marker(center: Vector2) -> void:
	var size = tile_size.x * 0.3
	var local = to_local(center)
	var col = Color(1.0, 0.2, 0.2, 0.8)
	
	draw_line(local + Vector2(-size, -size), local + Vector2(size, size), col, 2.0)
	draw_line(local + Vector2(size, -size), local + Vector2(-size, size), col, 2.0)
