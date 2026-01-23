class_name PlacementManager
extends Node2D

## Manages the placement of new buildings and plants.
## Handles grid snapping, previews, cost calculation, and spawning.

# --- Configuration ---
@export var tile_size: Vector2 = Vector2(32, 32)
@export var plant_offset: Vector2 = Vector2(0, 0)
@export var preview_visual_offset: Vector2 = Vector2(0, 0)

# Colors
@export var preview_color_valid: Color = Color(0.5, 0.7, 1.0, 0.7)
@export var preview_color_invalid: Color = Color(1.0, 0.3, 0.3, 0.7)
@export var grid_outline_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var bulk_start_marker_color: Color = Color(0.2, 1.0, 0.2, 0.9)

# Grid Settings
@export var grid_radius: int = 2
@export var grid_outline_width: float = 1.0

# --- Dependencies ---
var planting_system: PlantingSystem
var tile_map: TileMapLayer
var ysort_root: Node2D
var player: CharacterBody2D
var bulk_cost_panel: Control

# --- State ---
var preview_sprite: Sprite2D
var show_grid: bool = false
var can_place: bool = false
var current_tile_center: Vector2 = Vector2.ZERO

# Bulk Placement State
var bulk_start_tile: Vector2i = Vector2i.ZERO
var bulk_start_set: bool = false

# Constants
const GRASS_CLEAR_SOURCE_ID: int = 1

func _ready() -> void:
	name = "PlacementManager"
	_setup_preview_sprite()

func setup(system: PlantingSystem, _tile_map: TileMapLayer, _ysort_root: Node2D, _player: CharacterBody2D, _bulk_panel: Control) -> void:
	planting_system = system
	tile_map = _tile_map
	ysort_root = _ysort_root
	player = _player
	bulk_cost_panel = _bulk_panel

func _setup_preview_sprite() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "PreviewSprite"
	preview_sprite.visible = false
	preview_sprite.z_index = 100
	preview_sprite.offset = preview_visual_offset
	add_child(preview_sprite)

# --- Public API ---

func activate() -> void:
	show_grid = true
	refresh_preview()

func deactivate() -> void:
	show_grid = false
	preview_sprite.visible = false
	_cancel_bulk_mode()
	queue_redraw()

func update(_delta: float) -> void:
	# Called by parent _process if we prefer manual update, 
	# but since we inherit Node2D, we can use _process if active.
	_update_preview()

func _draw() -> void:
	if not show_grid:
		return
		
	if bulk_start_set:
		_draw_bulk_selection()
	else:
		_draw_normal_grid()

# --- Logic ---

func _update_preview() -> void:
	if not tile_map or not player:
		return
		
	var mouse_world_pos := get_global_mouse_position()
	var tile_coords := tile_map.local_to_map(mouse_world_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	current_tile_center = snapped_pos
	queue_redraw()
	
	if preview_sprite.texture == null:
		refresh_preview()
		
	if bulk_start_set:
		preview_sprite.visible = false
	else:
		preview_sprite.global_position = snapped_pos + plant_offset
		preview_sprite.visible = true
		
		can_place = _check_can_place(tile_coords, snapped_pos)
		preview_sprite.modulate = preview_color_valid if can_place else preview_color_invalid

func _check_can_place(tile_coords: Vector2i, world_pos: Vector2) -> bool:
	# Check 1: Tile occupied?
	if planting_system.is_tile_occupied(tile_coords):
		return false
		
	# Check 2: Overlaps player?
	if _overlaps_player(world_pos):
		return false
		
	# Check 3: Can afford?
	if not bulk_start_set and not _can_afford_placement(1):
		return false
		
	return true

func _overlaps_player(tile_center: Vector2) -> bool:
	if not player: return false
	
	var collision_shape = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape: return false
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape: return false
	
	var player_pos = player.global_position + collision_shape.position
	var player_rect = Rect2(player_pos - shape.size / 2.0, shape.size)
	var tile_rect = Rect2(tile_center - tile_size / 2.0, tile_size)
	
	return player_rect.intersects(tile_rect)

func _can_afford_placement(count: int) -> bool:
	var item = BuildRegistry.active_buildable
	if not item or item.build_costs.is_empty():
		return true
		
	for material_id in item.build_costs:
		var required = item.build_costs[material_id] * count
		if Inventory.count_item(material_id) < required:
			return false
	return true

func _consume_materials(count: int) -> bool:
	var item = BuildRegistry.active_buildable
	if not item or item.build_costs.is_empty():
		return true
		
	for material_id in item.build_costs:
		var required = item.build_costs[material_id] * count
		if not Inventory.consume_item(material_id, required):
			return false
	return true

func refresh_preview() -> void:
	var item = BuildRegistry.active_buildable
	if not item: return
	
	if item.preview_texture:
		preview_sprite.texture = item.preview_texture
		preview_sprite.hframes = item.preview_hframes
		preview_sprite.frame = item.preview_frame
		# Use item offset override if exists, otherwise keep system default
		if item.preview_offset != Vector2.ZERO:
			preview_sprite.offset = item.preview_offset
		else:
			preview_sprite.offset = Vector2.ZERO

# --- Actions ---

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		if bulk_start_set:
			_cancel_bulk_mode()
		else:
			BuildRegistry.clear_active()
		return
		
	if event.is_action_pressed("place"):
		if bulk_start_set:
			_place_bulk()
		elif Input.is_action_pressed("bulk_modifier"):
			_set_bulk_start()
		elif can_place:
			_place_single()

func _place_single() -> void:
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map.local_to_map(mouse_pos)
	var snapped_pos = tile_map.map_to_local(tile_coords)
	
	if not _check_can_place(tile_coords, snapped_pos):
		return
		
	if _consume_materials(1):
		_spawn_object(tile_coords, snapped_pos)

func _spawn_object(tile_coords: Vector2i, world_pos: Vector2) -> void:
	var item = BuildRegistry.active_buildable
	if not item or not item.scene: return
	
	# Visuals
	tile_map.set_cell(tile_coords, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
	
	# Spawn
	var instance = item.scene.instantiate() as Node2D
	
	var final_offset = item.placement_offset
	if not item.ignore_system_offset:
		final_offset += plant_offset
		
	instance.global_position = world_pos + final_offset
	instance.set_meta("buildable_id", item.id)
	
	ysort_root.add_child(instance)
	planting_system.register_object(tile_coords, instance)

# --- Bulk Logic ---

func _set_bulk_start() -> void:
	var mouse_pos = get_global_mouse_position()
	bulk_start_tile = tile_map.local_to_map(mouse_pos)
	bulk_start_set = true
	if bulk_cost_panel: bulk_cost_panel.show()
	queue_redraw()

func _cancel_bulk_mode() -> void:
	bulk_start_set = false
	if bulk_cost_panel: bulk_cost_panel.hide()
	queue_redraw()

func _place_bulk() -> void:
	if not tile_map: return
	var mouse_pos = get_global_mouse_position()
	var end_tile = tile_map.local_to_map(mouse_pos)
	
	var rect = _get_bulk_rect(bulk_start_tile, end_tile)
	var tiles_to_place: Array[Vector2i] = []
	
	# Validate all
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x, y)
			var world_pos = tile_map.map_to_local(coords)
			if not planting_system.is_tile_occupied(coords) and not _overlaps_player(world_pos):
				tiles_to_place.append(coords)
				
	# Cost check
	if tiles_to_place.is_empty(): return
	if not _can_afford_placement(tiles_to_place.size()): return
	if not _consume_materials(tiles_to_place.size()): return
	
	# Place
	for coords in tiles_to_place:
		_spawn_object(coords, tile_map.map_to_local(coords))
		
	_cancel_bulk_mode()

func _get_bulk_rect(start: Vector2i, end: Vector2i) -> Rect2i:
	var min_x = mini(start.x, end.x)
	var min_y = mini(start.y, end.y)
	var max_x = maxi(start.x, end.x)
	var max_y = maxi(start.y, end.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# --- Drawing Helpers ---

func _draw_normal_grid() -> void:
	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			var dist = maxi(absi(x), absi(y))
			var alpha = 1.0 - (float(dist) / float(grid_radius + 1))
			var col = grid_outline_color
			col.a *= alpha
			
			var offset = Vector2(x * tile_size.x, y * tile_size.y)
			_draw_tile_outline(current_tile_center + offset, col)

func _draw_bulk_selection() -> void:
	if not tile_map: return
	var mouse_pos = get_global_mouse_position()
	var end_tile = tile_map.local_to_map(mouse_pos)
	var rect = _get_bulk_rect(bulk_start_tile, end_tile)
	
	# Check validity for color
	var all_valid = true
	var count = 0
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			count += 1
			var coords = Vector2i(x, y)
			var w_pos = tile_map.map_to_local(coords)
			if planting_system.is_tile_occupied(coords) or _overlaps_player(w_pos):
				all_valid = false
				break
				
	if all_valid and not _can_afford_placement(count):
		all_valid = false
		
	# UI Update
	if bulk_cost_panel and bulk_cost_panel.has_method("update_costs"):
		bulk_cost_panel.update_costs(BuildRegistry.active_buildable, count, all_valid)
		
	# Draw
	var preview_tex = preview_sprite.texture
	var frame_w = float(preview_tex.get_width()) / float(preview_sprite.hframes)
	var src_rect = Rect2(frame_w * preview_sprite.frame, 0, frame_w, preview_tex.get_height())
	var col = preview_color_valid if all_valid else preview_color_invalid
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x, y)
			var w_pos = tile_map.map_to_local(coords)
			
			var outline = bulk_start_marker_color if coords == bulk_start_tile else grid_outline_color
			_draw_tile_outline(w_pos, outline)
			
			# Draw Texture
			var draw_pos = to_local(w_pos + plant_offset) + preview_sprite.offset
			var dest_rect = Rect2(draw_pos - Vector2(frame_w/2, preview_tex.get_height()/2.0), Vector2(frame_w, preview_tex.get_height()))
			draw_texture_rect_region(preview_tex, dest_rect, src_rect, col)

func _draw_tile_outline(center: Vector2, color: Color) -> void:
	var half = tile_size / 2.0
	var local_center = to_local(center)
	var top_left = local_center + Vector2(-half.x, -half.y)
	var top_right = local_center + Vector2(half.x, -half.y)
	var bottom_right = local_center + Vector2(half.x, half.y)
	var bottom_left = local_center + Vector2(-half.x, half.y)
	
	draw_line(top_left, top_right, color, grid_outline_width)
	draw_line(top_right, bottom_right, color, grid_outline_width)
	draw_line(bottom_right, bottom_left, color, grid_outline_width)
	draw_line(bottom_left, top_left, color, grid_outline_width)
