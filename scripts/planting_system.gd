class_name PlantingSystem
extends Node2D

## Manages plant placement preview and spawning.
## Shows a preview sprite that snaps to the tile grid, with color indicating
## whether placement is valid (blue) or blocked (red).

## Configuration
@export var tile_size: Vector2 = Vector2(32, 32)
@export var plant_offset: Vector2 = Vector2(0, -12)  # Offset from tile center
@export var preview_color_valid: Color = Color(0.5, 0.7, 1.0, 0.7)
@export var preview_color_invalid: Color = Color(1.0, 0.3, 0.3, 0.7)

## Delete mode visual configuration
@export var delete_highlight_color: Color = Color(1.0, 0.4, 0.4, 1.0)  # Red tint for hovered plant
@export var delete_grid_color: Color = Color(1.0, 0.3, 0.3, 0.6)       # Red grid outline
@export var delete_bulk_color: Color = Color(1.0, 0.2, 0.2, 0.7)       # Red bulk selection

## References (set in _ready or via editor)
var tile_map: TileMapLayer
var player: CharacterBody2D
var hotbar: MarginContainer
var delete_overlay: Control

## Preview sprite child
var preview_sprite: Sprite2D

## Track which tiles have plants (tile_coords -> plant_node)
var occupied_tiles: Dictionary = {}

## Current placement validity
var can_place: bool = false

## Grid outline configuration
@export var grid_outline_color: Color = Color(1.0, 1.0, 1.0, 0.5)  # White with 0.5 alpha base
@export var grid_outline_width: float = 1.0
@export var grid_radius: int = 2  # 5x5 grid (2 tiles in each direction)

## Current hovered tile position (for grid drawing)
var current_tile_center: Vector2 = Vector2.ZERO
var show_grid: bool = false

## Bulk placement state
var bulk_start_tile: Vector2i = Vector2i.ZERO  # First clicked tile (Point A)
var bulk_start_set: bool = false               # True after Shift+Click sets Point A

## Delete mode state
var delete_mode: bool = false
var hovered_plant: Node2D = null
var hovered_tile: Vector2i = Vector2i.ZERO
var last_hovered_plant: Node2D = null
var bulk_delete_start_tile: Vector2i = Vector2i.ZERO
var bulk_delete_start_set: bool = false

## Visual configuration for bulk selection
@export var bulk_start_marker_color: Color = Color(0.2, 1.0, 0.2, 0.9)  # Bright green outline for Point A

## Tile source IDs in the TileSet
const GRASS_SOURCE_ID: int = 0
const GRASS_CLEAR_SOURCE_ID: int = 1


func _ready() -> void:
	_setup_preview_sprite()
	_find_references()
	_connect_signals()


func _setup_preview_sprite() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "PreviewSprite"
	preview_sprite.visible = false
	preview_sprite.z_index = 100  # Render above tiles
	add_child(preview_sprite)


func _find_references() -> void:
	# Find TileMapLayer (sibling)
	tile_map = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if not tile_map:
		push_error("PlantingSystem: TileMapLayer not found!")
	
	# Find Player (sibling, named "Hana")
	player = get_parent().get_node_or_null("Hana") as CharacterBody2D
	if not player:
		push_error("PlantingSystem: Player (Hana) not found!")
	
	# Find Hotbar (in UI CanvasLayer)
	var ui := get_parent().get_node_or_null("UI") as CanvasLayer
	if ui:
		hotbar = ui.get_node_or_null("Hotbar") as MarginContainer
		delete_overlay = ui.get_node_or_null("DeleteModeOverlay")
	if not hotbar:
		push_error("PlantingSystem: Hotbar not found!")


func _connect_signals() -> void:
	if BuildRegistry:
		BuildRegistry.active_buildable_changed.connect(_on_active_buildable_changed)


func _on_active_buildable_changed(item: BuildableItem) -> void:
	# Exit delete mode when entering build mode
	if item != null and delete_mode:
		_exit_delete_mode()
	
	# Cancel bulk mode when switching tools
	if bulk_start_set:
		_cancel_bulk_mode()
	
	if item == null:
		preview_sprite.visible = false
		show_grid = false
		queue_redraw()
	else:
		_load_preview_texture()


func _process(_delta: float) -> void:
	# Delete mode processing
	if delete_mode:
		_update_delete_preview()
		return

	if BuildRegistry.active_buildable == null:
		preview_sprite.visible = false
		if show_grid:
			show_grid = false
			queue_redraw()
		return
	
	_update_preview()


func _draw() -> void:
	if not show_grid:
		return
	
	if delete_mode:
		if bulk_delete_start_set:
			_draw_bulk_delete_selection()
		else:
			_draw_delete_grid()
	elif bulk_start_set:
		_draw_bulk_selection()
	else:
		_draw_normal_grid()


func _draw_normal_grid() -> void:
	# Draw grid of tiles with distance-based opacity
	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			var distance := maxi(absi(x), absi(y))  # Chebyshev distance
			var opacity_falloff := 1.0 - (float(distance) / float(grid_radius + 1))
			var tile_color := Color(
				grid_outline_color.r,
				grid_outline_color.g,
				grid_outline_color.b,
				grid_outline_color.a * opacity_falloff
			)
			
			var offset := Vector2(x * tile_size.x, y * tile_size.y)
			var tile_center := current_tile_center + offset
			_draw_tile_outline(tile_center, tile_color)

func _draw_delete_grid() -> void:
	# Draw red-tinted grid with distance fade
	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			var distance := maxi(absi(x), absi(y))
			var opacity_falloff := 1.0 - (float(distance) / float(grid_radius + 1))
			var tile_color := Color(
				delete_grid_color.r,
				delete_grid_color.g,
				delete_grid_color.b,
				delete_grid_color.a * opacity_falloff
			)
			
			var offset := Vector2(x * tile_size.x, y * tile_size.y)
			var tile_center := current_tile_center + offset
			_draw_tile_outline(tile_center, tile_color)

func _draw_bulk_selection() -> void:
	if not tile_map or not preview_sprite.texture:
		return
	
	var mouse_pos := get_global_mouse_position()
	var end_tile := tile_map.local_to_map(mouse_pos)
	
	# Calculate bounding rectangle
	var min_tile := Vector2i(
		mini(bulk_start_tile.x, end_tile.x),
		mini(bulk_start_tile.y, end_tile.y)
	)
	var max_tile := Vector2i(
		maxi(bulk_start_tile.x, end_tile.x),
		maxi(bulk_start_tile.y, end_tile.y)
	)
	
	# First pass: Check if WHOLE area is valid
	var is_whole_area_valid := true
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			if not _check_can_place(tile_coords, world_pos):
				is_whole_area_valid = false
				break
		if not is_whole_area_valid:
			break
	
	# Draw preview on each tile in the selection
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			
			# Draw tile outline
			var outline_color := bulk_start_marker_color if tile_coords == bulk_start_tile else grid_outline_color
			_draw_tile_outline(world_pos, outline_color)
			
			# Draw plant preview texture
			# If entire area is valid, use valid color. Otherwise, use invalid color for ALL tiles.
			var preview_color := preview_color_valid if is_whole_area_valid else preview_color_invalid
			_draw_preview_at(world_pos, preview_color)

func _draw_bulk_delete_selection() -> void:
	if not tile_map:
		return
	
	var mouse_pos := get_global_mouse_position()
	var end_tile := tile_map.local_to_map(mouse_pos)
	
	# Calculate bounding rectangle
	var min_tile := Vector2i(
		mini(bulk_delete_start_tile.x, end_tile.x),
		mini(bulk_delete_start_tile.y, end_tile.y)
	)
	var max_tile := Vector2i(
		maxi(bulk_delete_start_tile.x, end_tile.x),
		maxi(bulk_delete_start_tile.y, end_tile.y)
	)
	
	# Draw selection area with plant indicators
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			
			# Highlight start tile differently
			var is_start := tile_coords == bulk_delete_start_tile
			var has_plant := occupied_tiles.has(tile_coords)
			
			# Choose outline color
			var outline_color: Color
			if is_start:
				outline_color = Color(1.0, 1.0, 0.3, 0.9)  # Yellow for start
			elif has_plant:
				outline_color = delete_bulk_color  # Red for plants to delete
			else:
				outline_color = Color(delete_grid_color.r, delete_grid_color.g, delete_grid_color.b, 0.3)
			
			_draw_tile_outline(world_pos, outline_color)
			
			# Draw X marker on tiles with plants
			if has_plant:
				_draw_delete_marker(world_pos)

func _draw_preview_at(world_pos: Vector2, color: Color) -> void:
	var texture := preview_sprite.texture
	if not texture:
		return
	
	# Calculate the source rect for the current frame
	var frame_width := float(texture.get_width()) / float(preview_sprite.hframes)
	var src_rect := Rect2(frame_width * preview_sprite.frame, 0, frame_width, texture.get_height())
	
	# Calculate destination position (centered, with plant offset)
	var draw_pos := to_local(world_pos + plant_offset)
	var dest_rect := Rect2(
		draw_pos - Vector2(frame_width / 2.0, texture.get_height() / 2.0),
		Vector2(frame_width, texture.get_height())
	)
	
	draw_texture_rect_region(texture, dest_rect, src_rect, color)


func _draw_tile_outline(center: Vector2, color: Color) -> void:
	var half_size := tile_size / 2.0
	var top_left := to_local(center + Vector2(-half_size.x, -half_size.y))
	var top_right := to_local(center + Vector2(half_size.x, -half_size.y))
	var bottom_right := to_local(center + Vector2(half_size.x, half_size.y))
	var bottom_left := to_local(center + Vector2(-half_size.x, half_size.y))
	
	draw_line(top_left, top_right, color, grid_outline_width)
	draw_line(top_right, bottom_right, color, grid_outline_width)
	draw_line(bottom_right, bottom_left, color, grid_outline_width)
	draw_line(bottom_left, top_left, color, grid_outline_width)

func _draw_delete_marker(center: Vector2) -> void:
	# Draw an X to indicate deletion
	var size := tile_size.x * 0.3
	var local_center := to_local(center)
	var color := Color(1.0, 0.2, 0.2, 0.8)
	
	draw_line(
		local_center + Vector2(-size, -size),
		local_center + Vector2(size, size),
		color, 2.0
	)
	draw_line(
		local_center + Vector2(size, -size),
		local_center + Vector2(-size, size),
		color, 2.0
	)

func _update_preview() -> void:
	if not tile_map or not player:
		return
	
	# Get mouse position in world coordinates
	var mouse_world_pos := get_global_mouse_position()
	
	# Snap to tile grid (align to tile center)
	var tile_coords := tile_map.local_to_map(mouse_world_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	# Update grid drawing
	current_tile_center = snapped_pos
	show_grid = true
	queue_redraw()
	
	# Load preview texture if not set
	if preview_sprite.texture == null:
		_load_preview_texture()
	
	if bulk_start_set:
		# In bulk mode: hide single preview, we draw multiple in _draw()
		preview_sprite.visible = false
	else:
		# Normal mode: show single preview
		preview_sprite.global_position = snapped_pos + plant_offset
		preview_sprite.visible = true
		
		# Check placement validity
		can_place = _check_can_place(tile_coords, snapped_pos)
		
		# Set color based on validity
		preview_sprite.modulate = preview_color_valid if can_place else preview_color_invalid

func _update_delete_preview() -> void:
	if not tile_map:
		return
	
	var mouse_pos := get_global_mouse_position()
	var tile_coords := tile_map.local_to_map(mouse_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	# Update grid center for drawing
	current_tile_center = snapped_pos
	hovered_tile = tile_coords
	show_grid = true
	queue_redraw()
	
	# In bulk delete mode, don't highlight individual plants
	if bulk_delete_start_set:
		_clear_plant_highlight()
		hovered_plant = null
		return
	
	# Find plant at this tile for single-delete highlighting
	var plant = occupied_tiles.get(tile_coords)
	
	if plant != hovered_plant:
		_clear_plant_highlight()
		hovered_plant = plant
		_apply_plant_highlight()

func _load_preview_texture() -> void:
	var item = BuildRegistry.active_buildable
	if item == null:
		return
		
	if item.preview_texture:
		preview_sprite.texture = item.preview_texture
		preview_sprite.hframes = item.preview_hframes
		preview_sprite.frame = item.preview_frame


func _check_can_place(tile_coords: Vector2i, world_pos: Vector2) -> bool:
	# Check 1: Tile not already occupied
	if occupied_tiles.has(tile_coords):
		return false
	
	# Check 2: Preview tile doesn't overlap player's collision shape
	if _overlaps_player(world_pos):
		return false
	
	return true


func _overlaps_player(tile_center: Vector2) -> bool:
	if not player:
		return false
	
	# Get player's collision shape
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		return false
	
	var shape := collision_shape.shape as RectangleShape2D
	if not shape:
		return false
	
	# Calculate player's collision rect in world space
	var player_pos := player.global_position + collision_shape.position
	var player_half_size := shape.size / 2.0
	var player_rect := Rect2(
		player_pos - player_half_size,
		shape.size
	)
	
	# Calculate tile rect (32x32 centered on tile_center)
	var tile_half_size := tile_size / 2.0
	var tile_rect := Rect2(
		tile_center - tile_half_size,
		tile_size
	)
	
	return player_rect.intersects(tile_rect)


## Check if bulk mode modifier is pressed (Command on Mac, Ctrl on others)
func _is_bulk_modifier_pressed() -> bool:
	return Input.is_action_pressed("bulk_modifier")


func _input(event: InputEvent) -> void:
	# Toggle delete mode with F key
	if event.is_action_pressed("toggle_delete_mode"):
		if delete_mode:
			_exit_delete_mode()
		else:
			_enter_delete_mode()
		return
	
	# === DELETE MODE INPUT ===
	if delete_mode:
		_handle_delete_input(event)
		return

	if BuildRegistry.active_buildable == null:
		return
	
	# === BUILD MODE INPUT ===
	
	# Right-click exits build mode (or cancels bulk)
	if event.is_action_pressed("cancel"):
		if bulk_start_set:
			_cancel_bulk_mode()
		else:
			BuildRegistry.clear_active()
		return
	
	if event.is_action_pressed("place"):
		if bulk_start_set:
			# Second click: complete bulk placement
			_place_bulk()
		elif _is_bulk_modifier_pressed():
			# Shift + Click: start bulk mode
			_set_bulk_start()
		elif can_place:
			# Normal single placement (no Shift, no bulk mode)
			_place_plant()


func _handle_delete_input(event: InputEvent) -> void:
	# Right-click: cancel bulk delete or exit delete mode
	if event.is_action_pressed("cancel"):
		if bulk_delete_start_set:
			_cancel_bulk_delete()
		else:
			_exit_delete_mode()
		return
	
	# Left-click handling
	if event.is_action_pressed("place"):
		if bulk_delete_start_set:
			# Second click: execute bulk delete
			_execute_bulk_delete()
		elif _is_bulk_modifier_pressed():
			# Shift+Click: start bulk delete selection
			_start_bulk_delete()
		elif hovered_plant:
			# Single plant deletion
			_delete_single_plant()

func _enter_delete_mode() -> void:
	# Exit build mode first if active
	if BuildRegistry.active_buildable != null:
		BuildRegistry.clear_active()
	
	# Cancel any pending bulk placement
	if bulk_start_set:
		_cancel_bulk_mode()
	
	delete_mode = true
	preview_sprite.visible = false
	
	# Show red border overlay
	if delete_overlay:
		delete_overlay.show_overlay()
	
	queue_redraw()

func _exit_delete_mode() -> void:
	delete_mode = false
	bulk_delete_start_set = false
	bulk_delete_start_tile = Vector2i.ZERO
	
	_clear_plant_highlight()
	hovered_plant = null
	
	# Hide red border overlay
	if delete_overlay:
		delete_overlay.hide_overlay()
	
	show_grid = false
	queue_redraw()

func _apply_plant_highlight() -> void:
	if hovered_plant and is_instance_valid(hovered_plant):
		last_hovered_plant = hovered_plant
		# Store original modulate for restoration
		if not hovered_plant.has_meta("original_modulate"):
			hovered_plant.set_meta("original_modulate", hovered_plant.modulate)
		hovered_plant.modulate = delete_highlight_color

func _clear_plant_highlight() -> void:
	if last_hovered_plant and is_instance_valid(last_hovered_plant):
		var original = last_hovered_plant.get_meta("original_modulate", Color.WHITE)
		last_hovered_plant.modulate = original
		last_hovered_plant.remove_meta("original_modulate")
	last_hovered_plant = null

func _place_plant() -> void:
	if not tile_map:
		return
	
	var mouse_world_pos := get_global_mouse_position()
	var tile_coords := tile_map.local_to_map(mouse_world_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	if not _check_can_place(tile_coords, snapped_pos):
		return
	
	_place_plant_at(tile_coords, snapped_pos)


func _place_plant_at(tile_coords: Vector2i, world_pos: Vector2) -> void:
	var item = BuildRegistry.active_buildable
	if item == null or item.scene == null:
		return
	
	# Change the tile to Grass_Clear
	tile_map.set_cell(tile_coords, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
	
	# Instantiate the plant
	var plant_instance := item.scene.instantiate() as Node2D
	plant_instance.global_position = world_pos + plant_offset
	
	# Add to world (as sibling)
	get_parent().add_child(plant_instance)
	
	# Track occupied tile
	occupied_tiles[tile_coords] = plant_instance


func _set_bulk_start() -> void:
	var mouse_pos := get_global_mouse_position()
	bulk_start_tile = tile_map.local_to_map(mouse_pos)
	bulk_start_set = true
	queue_redraw()


func _cancel_bulk_mode() -> void:
	bulk_start_set = false
	bulk_start_tile = Vector2i.ZERO
	queue_redraw()


func _place_bulk() -> void:
	if not tile_map:
		_cancel_bulk_mode()
		return
	
	var mouse_pos := get_global_mouse_position()
	var end_tile := tile_map.local_to_map(mouse_pos)
	
	# Calculate bounding rectangle
	var min_tile := Vector2i(
		mini(bulk_start_tile.x, end_tile.x),
		mini(bulk_start_tile.y, end_tile.y)
	)
	var max_tile := Vector2i(
		maxi(bulk_start_tile.x, end_tile.x),
		maxi(bulk_start_tile.y, end_tile.y)
	)
	
	# Pass 1: Check validity of ALL tiles
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			if not _check_can_place(tile_coords, world_pos):
				# Found an invalid tile, abort the entire placement
				# Do NOT cancel bulk mode, so user can adjust selection
				return
	
	# Pass 2: Place on all tiles (we know they are all valid now)
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			_place_plant_at(tile_coords, world_pos)
	
	_cancel_bulk_mode()

func _delete_single_plant() -> void:
	if not hovered_plant or not is_instance_valid(hovered_plant):
		return
	
	_delete_plant_at(hovered_tile)
	
	hovered_plant = null
	last_hovered_plant = null

func _delete_plant_at(tile_coords: Vector2i) -> void:
	var plant = occupied_tiles.get(tile_coords)
	if not plant or not is_instance_valid(plant):
		return
	
	# Remove from tracking
	occupied_tiles.erase(tile_coords)
	
	# Restore tile to original grass
	tile_map.set_cell(tile_coords, GRASS_SOURCE_ID, Vector2i.ZERO)
	
	# Delete the plant node
	plant.queue_free()

func _start_bulk_delete() -> void:
	if not tile_map:
		return
	
	var mouse_pos := get_global_mouse_position()
	bulk_delete_start_tile = tile_map.local_to_map(mouse_pos)
	bulk_delete_start_set = true
	
	_clear_plant_highlight()
	queue_redraw()

func _cancel_bulk_delete() -> void:
	bulk_delete_start_set = false
	bulk_delete_start_tile = Vector2i.ZERO
	queue_redraw()

func _execute_bulk_delete() -> void:
	if not tile_map:
		_cancel_bulk_delete()
		return
	
	var mouse_pos := get_global_mouse_position()
	var end_tile := tile_map.local_to_map(mouse_pos)
	
	# Calculate bounding rectangle
	var min_tile := Vector2i(
		mini(bulk_delete_start_tile.x, end_tile.x),
		mini(bulk_delete_start_tile.y, end_tile.y)
	)
	var max_tile := Vector2i(
		maxi(bulk_delete_start_tile.x, end_tile.x),
		maxi(bulk_delete_start_tile.y, end_tile.y)
	)
	
	# Collect plants to delete
	var plants_to_delete: Array[Vector2i] = []
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coords := Vector2i(x, y)
			if occupied_tiles.has(tile_coords):
				plants_to_delete.append(tile_coords)
	
	# Delete all plants in selection
	for tile_coords in plants_to_delete:
		_delete_plant_at(tile_coords)
	
	_cancel_bulk_delete()
