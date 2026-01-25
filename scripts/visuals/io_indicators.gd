extends Node2D

@export var input_color: Color = Color(0.2, 1.0, 0.2, 0.6)
@export var output_color: Color = Color(1.0, 0.4, 0.2, 0.6)
@export var tile_size: Vector2 = Vector2(32, 32)

var planting_system: Node = null
var rat_manager_panel: Control = null

func _ready() -> void:
	# Default to hidden
	visible = false
	
	# Redraw when parent changes orientation
	var parent = get_parent()
	if parent and parent.has_signal("orientation_changed"):
		parent.connect("orientation_changed", queue_redraw)
		
	# Find dependencies
	planting_system = get_tree().get_first_node_in_group("planting_system")
	
	var ui = get_tree().get_first_node_in_group("ui_layer")
	if ui:
		rat_manager_panel = ui.get_node_or_null("RatManagerPanel")

func _process(_delta: float) -> void:
	var should_show: bool = false
	
	# 1. Building Mode
	if planting_system and "current_mode" in planting_system:
		# Mode.PLACE is 1
		if planting_system.current_mode == 1:
			should_show = true
			
	# 2. Rat Management Mode
	if not should_show and rat_manager_panel:
		if rat_manager_panel.visible:
			should_show = true
			
	if visible != should_show:
		visible = should_show

func _draw() -> void:
	var parent = get_parent()
	if not parent or not parent.has_method("get_input_tile"): return
	
	# Determine offsets based on flip state
	# Parent is DirectionalBuilding
	var flipped = parent.get("is_flipped")
	
	# Default: Input Left (-1, 0), Output Right (1, 0)
	var in_dir = Vector2(-1, 0)
	var out_dir = Vector2(1, 0)
	
	if flipped:
		in_dir = Vector2(1, 0)
		out_dir = Vector2(-1, 0)
		
	var in_pos = in_dir * tile_size
	var out_pos = out_dir * tile_size
	
	_draw_indicator(in_pos, input_color, "IN")
	_draw_indicator(out_pos, output_color, "OUT")

func _draw_indicator(pos: Vector2, color: Color, text: String) -> void:
	var size = tile_size.x / 3.0
	draw_circle(pos, size, color)
	draw_circle(pos, size, Color.WHITE, false, 2.0)
	
	# Draw arrow or simple line
	# For IN: Pointing towards 0,0?
	# For OUT: Pointing away?
	# Just the text is fine for debug/MVP
