class_name DirectionalBuilding
extends Node2D

## Base class for buildings with directional Input/Output tiles.
## Supports flipping (swapping input/output) and multi-tile footprint.

@export var is_flipped: bool = false
var center_tile: Vector2i = Vector2i.ZERO

var _io_indicators: Node2D

func _ready() -> void:
	# Add IO visual indicators
	var script = load("res://scripts/visuals/io_indicators.gd")
	if script:
		_io_indicators = Node2D.new()
		_io_indicators.name = "IOIndicators"
		_io_indicators.set_script(script)
		_io_indicators.z_index = 20 # Ensure visibility
		add_child(_io_indicators)

## Called by PlacementManager (and PlantingSystem load) to set state
func set_placement_data(center: Vector2i, flipped: bool) -> void:
	center_tile = center
	is_flipped = flipped
	_update_orientation()

func _update_orientation() -> void:
	if _io_indicators:
		_io_indicators.queue_redraw()

func get_center_tile() -> Vector2i:
	return center_tile

func get_input_tile() -> Vector2i:
	# Default: Input Left (-1, 0), Output Right (1, 0)
	# Flipped: Input Right (1, 0), Output Left (-1, 0)
	var offset_x = 1 if is_flipped else -1
	return center_tile + Vector2i(offset_x, 0)

func get_output_tile() -> Vector2i:
	var offset_x = -1 if is_flipped else 1
	return center_tile + Vector2i(offset_x, 0)

func get_occupied_tiles() -> Array[Vector2i]:
	# Assumes 3-tile horizontal footprint centered on center_tile
	return [
		center_tile + Vector2i(-1, 0),
		center_tile,
		center_tile + Vector2i(1, 0)
	]

func get_all_tiles() -> Array[Vector2i]:
	return get_occupied_tiles()
