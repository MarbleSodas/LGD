class_name RatVisuals
extends Node2D

@export var body_sprite: Sprite2D
@export var held_item_sprite: Sprite2D
@export var count_label: Label
@export var inventory: RatInventory

var _bob_timer: float = 0.0

func _ready() -> void:
	if inventory:
		inventory.inventory_changed.connect(update_held_item_visual)
	update_held_item_visual()

func update_held_item_visual() -> void:
	if not held_item_sprite or not inventory:
		return
	
	if not inventory.has_items():
		held_item_sprite.texture = null
		if count_label: count_label.text = ""
		return
		
	# Show first item
	var first_id = inventory.get_first_item_id()
	# Assuming ItemRegistry is a global singleton as in the original code
	var item = ItemRegistry.get_item(first_id) if ItemRegistry else null
	
	if item:
		held_item_sprite.texture = item.icon
	else:
		held_item_sprite.texture = null
		
	if count_label:
		var total = inventory.get_total_count()
		count_label.text = str(total) if total > 1 else ""

func set_facing_direction(direction: Vector2) -> void:
	if direction.x != 0 and body_sprite:
		body_sprite.flip_h = direction.x < 0

func update_bob(delta: float, is_moving: bool) -> void:
	if not body_sprite: return
	
	if is_moving:
		_bob_timer += delta * 15.0
		body_sprite.offset.y = -8 + sin(_bob_timer) * 2.0
	else:
		# Return to base
		body_sprite.offset.y = lerpf(body_sprite.offset.y, -8.0, delta * 10.0)

func reset_bob() -> void:
	if body_sprite:
		body_sprite.offset.y = -8.0
	_bob_timer = 0.0
