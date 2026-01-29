class_name StoneDeposit
extends Plant

## Stone Deposit resource node.
## Permanent, always harvestable, blocks movement.

# Flag for DeletionManager to prevent deletion
var is_permanent: bool = true

# Store placement data for multi-tile logic
var tile_coords: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# Configure properties before super._ready() to ensure they are used
	harvest_time = 10.0
	harvest_item_id = "stone"
	harvest_amount = 1
	regrows = true
	
	# Prevent warning in _start_growth
	if growth_stages.is_empty():
		growth_stages = [{"frame": 0, "duration": 0}]
	
	super._ready()

## Always ready to harvest
func is_harvest_ready() -> bool:
	return true

## Harvest without removing the object
func harvest() -> Dictionary:
	var result: Dictionary = {
		"item_id": harvest_item_id,
		"amount": harvest_amount
	}
	
	harvested.emit(harvest_item_id, harvest_amount)
	
	# Do NOT call queue_free()
	# Do NOT reset growth stages (since we are always ready)
	
	return result

func set_placement_data(coords: Vector2i, _flip: bool) -> void:
	tile_coords = coords

func get_center_tile() -> Vector2i:
	return tile_coords

func get_occupied_tiles() -> Array[Vector2i]:
	# Footprint size (3, 1) means centered at tile_coords with +/- 1 tile horizontally
	# Logic matches PlacementManager/PlantingSystem centering:
	# half_x = 3/2 = 1. Range [-1, 0, 1].
	return [
		tile_coords + Vector2i(-1, 0),
		tile_coords,
		tile_coords + Vector2i(1, 0)
	]
