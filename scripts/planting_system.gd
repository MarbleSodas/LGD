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

## The plant scene to spawn (set per-item, dandelion for slot 0)
@export var plant_scene: PackedScene

## References (set in _ready or via editor)
var tile_map: TileMapLayer
var player: CharacterBody2D
var hotbar: MarginContainer

## Preview sprite child
var preview_sprite: Sprite2D

## Track which tiles have plants (tile_coords -> plant_node)
var occupied_tiles: Dictionary = {}

## Current placement validity
var can_place: bool = false

## Which hotbar slot enables this planting tool (slot 0 = dandelion)
var active_slot: int = 0

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
	if not hotbar:
		push_error("PlantingSystem: Hotbar not found!")


func _connect_signals() -> void:
	if hotbar and hotbar.has_signal("slot_changed"):
		hotbar.slot_changed.connect(_on_hotbar_slot_changed)


func _on_hotbar_slot_changed(slot_index: int) -> void:
	active_slot = slot_index
	# Hide preview if not on plant tool slot
	if slot_index != 0:
		preview_sprite.visible = false


func _process(_delta: float) -> void:
	if active_slot != 0:
		preview_sprite.visible = false
		return
	
	_update_preview()


func _update_preview() -> void:
	if not tile_map or not player:
		return
	
	# Get mouse position in world coordinates
	var mouse_world_pos := get_global_mouse_position()
	
	# Snap to tile grid (align to tile center)
	var tile_coords := tile_map.local_to_map(mouse_world_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	# Position the preview (with offset)
	preview_sprite.global_position = snapped_pos + plant_offset
	preview_sprite.visible = true
	
	# Load preview texture if not set
	if preview_sprite.texture == null:
		_load_preview_texture()
	
	# Check placement validity
	can_place = _check_can_place(tile_coords, snapped_pos)
	
	# Set color based on validity
	preview_sprite.modulate = preview_color_valid if can_place else preview_color_invalid


func _load_preview_texture() -> void:
	# Load the dandelion texture for preview (showing flowering stage - frame 2)
	var texture := load("res://assets/objects/Dandelion.png") as Texture2D
	if texture:
		preview_sprite.texture = texture
		preview_sprite.hframes = 3
		preview_sprite.frame = 2  # Flowering stage for preview


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place") and active_slot == 0 and can_place:
		_place_plant()


func _place_plant() -> void:
	if not tile_map or not plant_scene:
		return
	
	var mouse_world_pos := get_global_mouse_position()
	var tile_coords := tile_map.local_to_map(mouse_world_pos)
	var snapped_pos := tile_map.map_to_local(tile_coords)
	
	# Double-check we can still place (in case of race condition)
	if not _check_can_place(tile_coords, snapped_pos):
		return
	
	# Change the tile to Grass_Clear
	tile_map.set_cell(tile_coords, GRASS_CLEAR_SOURCE_ID, Vector2i.ZERO)
	
	# Instantiate the plant
	var plant_instance := plant_scene.instantiate() as Node2D
	plant_instance.global_position = snapped_pos + plant_offset
	
	# Add to world (as sibling)
	get_parent().add_child(plant_instance)
	
	# Track occupied tile
	occupied_tiles[tile_coords] = plant_instance
