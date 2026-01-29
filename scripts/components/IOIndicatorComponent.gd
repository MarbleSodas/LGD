@tool
class_name IOIndicatorComponent
extends Node2D

## Visualizes Input/Output tiles for the parent building in the editor.

@export var show_input: bool = true:
	set(value):
		show_input = value
		queue_redraw()

@export var show_output: bool = true:
	set(value):
		show_output = value
		queue_redraw()

@export var tile_size: Vector2 = Vector2(32, 32):
	set(value):
		tile_size = value
		queue_redraw()

@export var input_color: Color = Color(0.0, 0.8, 0.0, 0.5):
	set(value):
		input_color = value
		queue_redraw()

@export var output_color: Color = Color(0.8, 0.0, 0.0, 0.5):
	set(value):
		output_color = value
		queue_redraw()

# Dependency
var footprint_component: FootprintComponent

func _ready() -> void:
	# Find sibling
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is FootprintComponent:
				footprint_component = child
				break

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Try to find component if not cached (e.g. just added in editor)
	if not footprint_component:
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is FootprintComponent:
					footprint_component = child
					break
	
	if not footprint_component:
		return
		
	if show_input:
		# var input_tile = footprint_component.get_input_tile() # Relative to center usually 0,0
		# But FootprintComponent stores center_tile which is global grid coords usually.
		# We need local offset.
		# Wait, DirectionalBuilding.get_input_tile returned `center_tile`.
		# And FootprintComponent uses `center_tile` (global map coords).
		# BUT for visualization, we are drawing relative to the node.
		# If the node is at (100, 100) and that maps to tile (3, 3), 
		# we want to draw at (0, 0) local if the tile is (3, 3).
		
		# In LGD, buildings are typically placed centered on their tile.
		# So (0, 0) local corresponds to the center_tile.
		# So input/output tiles are just offsets from (0,0) based on footprint logic.
		# However, `get_input_tile()` returns `center_tile` in the current implementation (DirectionalBuilding).
		# This means input/output is ALWAYS the center tile for single-tile buildings.
		
		# If we had multi-tile logic where input was (x-1, y), we'd need that offset.
		# Since `FootprintComponent.get_input_tile()` returns `center_tile`, and we assume `center_tile` matches node position...
		# We draw at (0,0).
		
		var offset = Vector2.ZERO
		# If we improve FootprintComponent later to support offsets, we'd calculate `input_tile - center_tile`.
		
		var rect = Rect2(offset - tile_size/2, tile_size)
		draw_rect(rect, input_color, true)
		draw_rect(rect, input_color.lightened(0.2), false, 2.0)
		draw_string(ThemeDB.get_fallback_font(), offset, "IN", HORIZONTAL_ALIGNMENT_CENTER)

	if show_output:
		# Same logic for output
		var offset = Vector2.ZERO
		# Shift slightly if they overlap?
		if show_input and offset == Vector2.ZERO:
			# If input and output are same tile, maybe draw output as a border or smaller rect?
			# Or just let alpha blending show both (yellowish?)
			pass
			
		var rect = Rect2(offset - tile_size/2, tile_size)
		# Draw output slightly smaller if overlapping?
		if show_input:
			rect = rect.grow(-4)
			
		draw_rect(rect, output_color, true)
		draw_rect(rect, output_color.lightened(0.2), false, 2.0)
