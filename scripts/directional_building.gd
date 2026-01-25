class_name DirectionalBuilding
extends Node2D

## Base class for buildings with directional Input/Output tiles.
## Refactored to single-tile behavior (input/output/center are all the same).
## Supports flipping property for save compatibility, but it has no effect on logic.

@export var is_flipped: bool = false
var center_tile: Vector2i = Vector2i.ZERO

func _ready() -> void:
	pass

## Called by PlacementManager (and PlantingSystem load) to set state
func set_placement_data(center: Vector2i, flipped: bool) -> void:
	center_tile = center
	is_flipped = flipped
	_update_orientation()

func _update_orientation() -> void:
	pass

func get_center_tile() -> Vector2i:
	return center_tile

func get_input_tile() -> Vector2i:
	return center_tile

func get_output_tile() -> Vector2i:
	return center_tile

func get_occupied_tiles() -> Array[Vector2i]:
	return [center_tile]

func get_all_tiles() -> Array[Vector2i]:
	return get_occupied_tiles()
