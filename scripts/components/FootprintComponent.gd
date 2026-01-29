@tool
class_name FootprintComponent
extends Node2D

## Manages multi-tile footprint logic and grid positioning.
## Replaces DirectionalBuilding logic.

@export var footprint_size: Vector2i = Vector2i(1, 1):
	set(value):
		footprint_size = value
		queue_redraw() # For editor visualization

@export var supports_flip: bool = false
@export var color: Color = Color(0.0, 0.0, 1.0, 0.2)

# State
var center_tile: Vector2i = Vector2i.ZERO
var is_flipped: bool = false

func _ready() -> void:
	# Ensure we redraw when properties change in editor
	pass

func set_placement_data(center: Vector2i, flipped: bool) -> void:
	center_tile = center
	is_flipped = flipped
	_update_orientation()

func _update_orientation() -> void:
	# Inform parent if it needs to visually flip
	var parent = get_parent()
	if parent is Node2D and supports_flip:
		# Simple visual flip logic common in LGD
		if is_flipped:
			parent.scale.x = -abs(parent.scale.x)
		else:
			parent.scale.x = abs(parent.scale.x)

func get_center_tile() -> Vector2i:
	return center_tile

func get_input_tile() -> Vector2i:
	return center_tile

func get_output_tile() -> Vector2i:
	return center_tile

func get_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var size = footprint_size
	
	# Logic from PlantingSystem._get_footprint_offsets
	var half_x = size.x / 2
	var half_y = size.y / 2
	
	for x in range(-half_x, -half_x + size.x):
		for y in range(-half_y, -half_y + size.y):
			tiles.append(center_tile + Vector2i(x, y))
			
	return tiles

# --- Save/Load ---

func get_save_data() -> Dictionary:
	return {
		"center_tile_x": center_tile.x,
		"center_tile_y": center_tile.y,
		"is_flipped": is_flipped
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("center_tile_x") and data.has("center_tile_y"):
		center_tile = Vector2i(data["center_tile_x"], data["center_tile_y"])
	if data.has("is_flipped"):
		is_flipped = data["is_flipped"]
		
	_update_orientation()

# --- Editor Visualization ---

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Only draw if parent is selected? 
	# Godot 4 draws @tool _draw of children automatically. 
	# To avoid clutter, we might check selection, but that's hard in a simple script.
	# We'll just draw.
	
	# Assuming 32x32 tiles
	var tile_size = Vector2(32, 32)
	var size_px = Vector2(footprint_size) * tile_size
	var half_size = size_px / 2.0
	
	var rect = Rect2(-half_size, size_px)
	draw_rect(rect, color, true)
	draw_rect(rect, color.lightened(0.2), false, 2.0)
	
	# Draw forward indicator
	draw_line(Vector2.ZERO, Vector2(0, 10), Color.RED, 2.0)
