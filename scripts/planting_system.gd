class_name PlantingSystem
extends Node2D

## Manages plant placement preview and spawning.
## Shows a preview sprite that snaps to the tile grid, with color indicating
## whether placement is valid (blue) or blocked (red).

## Configuration
@export var tile_size: Vector2 = Vector2(32, 32)
@export var plant_offset: Vector2 = Vector2(0, 0)  # Offset from tile center (visual offset now handled by sprite)
@export var preview_visual_offset: Vector2 = Vector2(0, -12) # Visual shift for preview to match plant sprite offset
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
var bulk_cost_panel: Control
var ysort_root: Node2D

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

## Interaction Configuration
@export var interact_highlight_color: Color = Color(1.0, 1.0, 0.0, 1.0) # Yellow for out of range or not ready
@export var interact_ready_color: Color = Color(0.0, 1.0, 0.0, 1.0)    # Green for ready
@export var interact_building_color: Color = Color(0.3, 0.5, 1.0, 1.0) # Blue for buildings

## Interaction resources
var floating_text_scene = preload("res://ui/components/floating_text.tscn")
var progress_bar_scene = preload("res://ui/components/harvest_progress_bar.tscn")

## Interaction state
var interact_area: Area2D
var is_harvesting: bool = false
var harvest_timer: float = 0.0
var harvest_target: Node2D = null
var current_progress_bar: Control = null

## Tile source IDs in the TileSet
const GRASS_SOURCE_ID: int = 0
const GRASS_CLEAR_SOURCE_ID: int = 1


func _ready() -> void:
	_setup_preview_sprite()
	_find_references()
	_connect_signals()
	_scan_existing_objects()

func _scan_existing_objects() -> void:
	if not ysort_root or not tile_map:
		return
		
	for child in ysort_root.get_children():
		if child is Plant or child is StorageBuilding:
			var tile_coords = tile_map.local_to_map(child.global_position)
			occupied_tiles[tile_coords] = child



func _setup_preview_sprite() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "PreviewSprite"
	preview_sprite.visible = false
	preview_sprite.z_index = 100  # Render above tiles
	preview_sprite.offset = preview_visual_offset
	add_child(preview_sprite)


func _find_references() -> void:
	# Find TileMapLayer (sibling)
	tile_map = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if not tile_map:
		push_error("PlantingSystem: TileMapLayer not found!")
	
	# Find YSortRoot (sibling, contains player and plants)
	ysort_root = get_parent().get_node_or_null("YSortRoot") as Node2D
	if not ysort_root:
		push_error("PlantingSystem: YSortRoot not found!")
	
	# Find Player (now inside YSortRoot)
	if ysort_root:
		player = ysort_root.get_node_or_null("Hana") as CharacterBody2D
	if not player:
		push_error("PlantingSystem: Player (Hana) not found!")
	else:
		if player.has_method("get_interact_area"):
			interact_area = player.get_interact_area()
		else:
			interact_area = player.get_node_or_null("InteractArea")
	
	# Find Hotbar (in UI CanvasLayer)
	var ui := get_parent().get_node_or_null("UI") as CanvasLayer
	if ui:
		hotbar = ui.get_node_or_null("Hotbar") as MarginContainer
		delete_overlay = ui.get_node_or_null("DeleteModeOverlay")
		bulk_cost_panel = ui.get_node_or_null("BulkCostPanel")
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


func _process(delta: float) -> void:
	# Handle harvest progress
	if is_harvesting:
		_process_harvest(delta)

	# Delete mode processing
	if delete_mode:
		_update_delete_preview()
		return

	if BuildRegistry.active_buildable == null:
		preview_sprite.visible = false
		_update_interaction_preview()
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
	elif BuildRegistry.active_buildable != null:
		_draw_normal_grid()
	elif hovered_plant and not delete_mode:
		_draw_interaction_highlight()

func _draw_interaction_highlight() -> void:
	if not hovered_plant or not is_instance_valid(hovered_plant):
		return
		
	var tile_pos = tile_map.map_to_local(hovered_tile)
	var in_range = _is_plant_in_range(hovered_plant)
	var color: Color

	# Check if this is a harvestable plant or an interactable building
	if hovered_plant.has_method("is_harvest_ready"):
		# It's a plant - check harvest readiness and range
		var is_harvestable = hovered_plant.is_harvest_ready()
		if is_harvestable and in_range:
			color = interact_ready_color      # Green - ready to harvest!
		else:
			color = interact_highlight_color  # Yellow - not ready or out of range
	elif hovered_plant is StorageBuilding:
		# It's a storage building (barrel)
		if in_range:
			color = interact_building_color   # Blue - ready to open
		else:
			color = interact_highlight_color  # Yellow - out of range
	else:
		# It's a generic building/interactable - use blue
		color = interact_building_color
	
	_draw_tile_outline(tile_pos, color)


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
	var tile_count := 0
	var is_whole_area_valid := true
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			tile_count += 1
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			if occupied_tiles.has(tile_coords) or _overlaps_player(world_pos):
				is_whole_area_valid = false
				break
		if not is_whole_area_valid:
			break
	
	# Check affordability for entire bulk placement
	var can_afford := _can_afford_placement(tile_count)
	if not can_afford:
		is_whole_area_valid = false
	
	# Update bulk cost panel
	if bulk_cost_panel and bulk_cost_panel.has_method("update_costs"):
		var item = BuildRegistry.active_buildable
		bulk_cost_panel.update_costs(item, tile_count, can_afford)
	
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
	var draw_pos := to_local(world_pos + plant_offset) + preview_sprite.offset
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
		
		# Use item-specific offset if defined (non-zero), otherwise fallback to system default (or just use item's if we migrate everything)
		# For backward compatibility with existing system config, we could add system default to item offset
		# But better to just use item offset if we configure resources correctly.
		# Let's use the item's offset directly + global adjustment if needed.
		# System has `preview_visual_offset` default (0, -12).
		# To support both without massive migration: use item offset + system offset? 
		# No, that's confusing.
		# Let's override the system offset if the item specifies one? 
		# OR just set the preview_sprite.offset to item.preview_offset
		
		# Current system default was: preview_visual_offset = Vector2(0, -12)
		# If we change code to use item.preview_offset, default is (0,0).
		
		# Logic: If item.preview_offset is different from ZERO (or maybe just use it), use it.
		# But wait, Dandelion needs (0, -12). If I don't update Dandelion resource, it will be (0,0) and break.
		
		# I will update the resources.
		preview_sprite.offset = item.preview_offset


func _check_can_place(tile_coords: Vector2i, world_pos: Vector2) -> bool:
	# Check 1: Tile not already occupied
	if occupied_tiles.has(tile_coords):
		return false
	
	# Check 2: Preview tile doesn't overlap player's collision shape
	if _overlaps_player(world_pos):
		return false
	
	# Check 3: Player can afford (for single placement)
	if not bulk_start_set and not _can_afford_placement(1):
		return false
	
	return true


func _can_afford_placement(count: int = 1) -> bool:
	var item = BuildRegistry.active_buildable
	if item == null or item.build_costs.is_empty():
		return true
	
	for material_id in item.build_costs:
		var required = item.build_costs[material_id] * count
		if Inventory.count_item(material_id) < required:
			return false
	return true


func _consume_materials(count: int = 1) -> bool:
	var item = BuildRegistry.active_buildable
	if item == null or item.build_costs.is_empty():
		return true
	
	for material_id in item.build_costs:
		var required = item.build_costs[material_id] * count
		if not Inventory.consume_item(material_id, required):
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
	# Block harvesting in build mode or delete mode
	var can_harvest = BuildRegistry.active_buildable == null and not delete_mode

	if event.is_action_pressed("harvest"):
		if can_harvest and hovered_plant and _is_plant_in_range(hovered_plant):
			_interact_with_target(hovered_plant)
	elif event.is_action_released("harvest"):
		if is_harvesting:
			_cancel_harvest()

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
	
	# Consume materials before placing
	if not _consume_materials(1):
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
	plant_instance.global_position = world_pos + plant_offset + item.placement_offset
	
	# Store the ID so we can save it later!
	plant_instance.set_meta("buildable_id", item.id)
	
	# Add to YSortRoot for proper Y-sorting with player
	ysort_root.add_child(plant_instance)
	
	# Track occupied tile
	occupied_tiles[tile_coords] = plant_instance


func _set_bulk_start() -> void:
	var mouse_pos := get_global_mouse_position()
	bulk_start_tile = tile_map.local_to_map(mouse_pos)
	bulk_start_set = true
	if bulk_cost_panel:
		bulk_cost_panel.show()
	queue_redraw()


func _cancel_bulk_mode() -> void:
	bulk_start_set = false
	bulk_start_tile = Vector2i.ZERO
	if bulk_cost_panel:
		bulk_cost_panel.hide()
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
	
	var tile_count := 0
	
	# Pass 1: Check validity of ALL tiles
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			tile_count += 1
			var tile_coords := Vector2i(x, y)
			var world_pos := tile_map.map_to_local(tile_coords)
			if occupied_tiles.has(tile_coords) or _overlaps_player(world_pos):
				# Found an invalid tile, abort the entire placement
				# Do NOT cancel bulk mode, so user can adjust selection
				return
	
	# Check affordability
	if not _can_afford_placement(tile_count):
		return
	
	# Consume materials for all tiles at once
	if not _consume_materials(tile_count):
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

# === INTERACTION LOGIC ===

func _update_interaction_preview() -> void:
	if not tile_map:
		return
		
	var mouse_pos := get_global_mouse_position()
	var tile_coords := tile_map.local_to_map(mouse_pos)
	
	# Only update if changed tile to avoid unnecessary redraws
	if tile_coords != hovered_tile:
		hovered_tile = tile_coords
		var plant = occupied_tiles.get(tile_coords)
		
		# Reset highlight if moved to new tile
		if plant != hovered_plant:
			_clear_plant_highlight()
			hovered_plant = plant
		
		# Show grid only if hovering a plant
		show_grid = (hovered_plant != null)
		queue_redraw()
	
	# Update grid center for drawing
	current_tile_center = tile_map.map_to_local(tile_coords)

	# Always redraw if hovering a plant/object so player movement updates range status immediately
	if hovered_plant:
		queue_redraw()
	
	# If currently harvesting, check if we moved away or out of range
	if is_harvesting:
		if harvest_target != hovered_plant or not _is_plant_in_range(harvest_target):
			_cancel_harvest()

	# Auto-harvest if holding the key and hovering a valid plant
	if Input.is_action_pressed("harvest") and hovered_plant and not is_harvesting:
		if _is_plant_in_range(hovered_plant):
			# Only auto-harvest plants, not buildings
			if hovered_plant.has_method("harvest"):
				_interact_with_target(hovered_plant)

func _is_plant_in_range(plant: Node2D) -> bool:
	if not plant or not is_instance_valid(plant) or not interact_area:
		return false
	
	# Check if plant's position is within the InteractArea
	# Since InteractArea is an Area2D on the player, we can check overlap
	# But checking point inside Area2D manually is tricky with shapes.
	# Easier: Check distance to player
	# InteractArea radius is ~36. Tile is 32. 
	# Let's use distance check for simplicity as we have the player reference
	
	# Or better, use the Area2D.overlaps_body / overlaps_area if the plant had a collision shape.
	# But plants don't have collision shapes usually (they are sprites).
	# So manual distance check against InteractArea's collision shape radius is best.
	
	var interact_shape = interact_area.get_child(0) as CollisionShape2D
	if interact_shape and interact_shape.shape is CircleShape2D:
		var radius = interact_shape.shape.radius
		var distance = plant.global_position.distance_to(interact_area.global_position)
		# Add a bit of buffer (tile size/2) since we measure from center
		return distance <= (radius + 16.0)
		
	return false

func _interact_with_target(target: Node2D) -> void:
	if is_harvesting: 
		return
		
	# Check for direct interaction (Buildings/Containers)
	if target.has_method("interact"):
		print("PlantingSystem: Calling interact() on target")
		target.interact()
		return
		
	# Fallback to harvest logic (Plants)
	_start_harvest(target)

func _start_harvest(plant: Node2D) -> void:
	if not plant.has_method("harvest"):
		return
		
	# Check if harvestable (ready)
	if plant.has_method("is_harvest_ready") and not plant.is_harvest_ready():
		return
		
	is_harvesting = true
	harvest_target = plant
	harvest_timer = 0.0
	
	# Create progress bar
	_create_progress_bar(plant)

func _create_progress_bar(plant: Node2D) -> void:
	if current_progress_bar:
		current_progress_bar.queue_free()
		
	current_progress_bar = progress_bar_scene.instantiate()
	add_child(current_progress_bar)
	current_progress_bar.global_position = plant.global_position + Vector2(-12, 16) # Below plant
	current_progress_bar.visible = true

func _cancel_harvest() -> void:
	is_harvesting = false
	harvest_target = null
	harvest_timer = 0.0
	if current_progress_bar:
		current_progress_bar.queue_free()
		current_progress_bar = null

func _process_harvest(delta: float) -> void:
	if not harvest_target or not is_instance_valid(harvest_target):
		_cancel_harvest()
		return
		
	var required_time = harvest_target.get("harvest_time") if "harvest_time" in harvest_target else 0.5
	harvest_timer += delta
	
	if current_progress_bar:
		if current_progress_bar.has_method("update_progress"):
			current_progress_bar.update_progress(harvest_timer, required_time)
		else:
			current_progress_bar.max_value = required_time
			current_progress_bar.value = harvest_timer
			
	if harvest_timer >= required_time:
		_complete_harvest()

func _complete_harvest() -> void:
	var plant = harvest_target
	_cancel_harvest() # Reset state first
	
	if not plant or not is_instance_valid(plant):
		return
		
	# Perform harvest
	var dropped_items = plant.harvest()
	
	if dropped_items.is_empty():
		return
		
	var item_id = dropped_items.get("item_id", "")
	var amount = dropped_items.get("amount", 1)
	
	# Add to inventory
	if Inventory and ItemRegistry:
		var item = ItemRegistry.get_item(item_id)
		if item:
			Inventory.add_item(item, amount)
			_spawn_floating_text(plant.global_position, "+%d %s" % [amount, item.display_name])
	
	# Plant regrowth handled in plant.gd logic (it resets itself)
	# If plant does NOT regrow (queue_free called), we need to update occupied_tiles
	if not is_instance_valid(plant) or plant.is_queued_for_deletion():
		# Find the tile this plant was on (we know hovered_tile, but better be safe)
		var tile_loc = occupied_tiles.find_key(plant)
		if tile_loc:
			occupied_tiles.erase(tile_loc)
			tile_map.set_cell(tile_loc, GRASS_SOURCE_ID, Vector2i.ZERO)

func _spawn_floating_text(pos: Vector2, text: String) -> void:
	var popup = floating_text_scene.instantiate()
	get_parent().add_child(popup)
	popup.global_position = pos + Vector2(0, -20)
	if popup.has_method("set_text_content"):
		popup.set_text_content(text)
	else:
		popup.text = text

# --- Save/Load Support ---

func to_save_data() -> Dictionary:
	var plants_data = []
	
	for tile_coords in occupied_tiles:
		var plant = occupied_tiles[tile_coords]
		if not is_instance_valid(plant):
			continue
			
		var plant_data = {
			"x": tile_coords.x,
			"y": tile_coords.y,
		}
		
		# If the plant instance has a 'buildable_id' property, use that.
		if plant.has_meta("buildable_id"):
			plant_data["buildable_id"] = plant.get_meta("buildable_id")
		else:
			# Fallback or skip if we can't identify it
			continue
			
		# Save growth state if applicable
		if plant.get("current_stage") != null:
			plant_data["stage"] = plant.current_stage
			
		# Check timer
		var timer = plant.get("growth_timer")
		if timer and timer is Timer and not timer.is_stopped():
			plant_data["timer_left"] = timer.time_left
			
		# Save container data if applicable
		if plant.has_method("get_container"):
			plant_data["container"] = plant.get_container().to_save_data()
			
		plants_data.append(plant_data)
		
	return {
		"plants": plants_data
	}

func from_save_data(data: Dictionary) -> void:
	if not data.has("plants"):
		return
		
	for plant_data in data["plants"]:
		var tile_coords = Vector2i(plant_data["x"], plant_data["y"])
		var buildable_id = plant_data.get("buildable_id", "")
		
		if buildable_id == "":
			continue
			
		var item = BuildRegistry.get_item(buildable_id)
		if not item:
			continue
			
		# Place the plant
		var world_pos = tile_map.map_to_local(tile_coords)
		
		# Set tile to Clear
		tile_map.set_cell(tile_coords, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
		
		# Spawn
		var plant_instance = item.scene.instantiate() as Node2D
		plant_instance.global_position = world_pos + plant_offset + item.placement_offset
		
		# Store ID for future saving
		plant_instance.set_meta("buildable_id", buildable_id)
		
		ysort_root.add_child(plant_instance)
		occupied_tiles[tile_coords] = plant_instance
		
		# Restore state
		if plant_data.has("stage") and plant_instance.has_method("set_growth_stage"):
			plant_instance.set_growth_stage(int(plant_data["stage"]))
			
		# Restore timer if valid
		if plant_data.has("timer_left") and plant_data["timer_left"] > 0:
			var timer = plant_instance.get("growth_timer")
			if timer and timer is Timer:
				timer.start(plant_data["timer_left"])
		
		# Restore container data
		if plant_data.has("container") and plant_instance.has_method("get_container"):
			plant_instance.get_container().from_save_data(plant_data["container"])
