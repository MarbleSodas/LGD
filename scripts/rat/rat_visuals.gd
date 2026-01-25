class_name RatVisuals
extends Node2D

@export var body_sprite: Sprite2D
@export var held_item_sprite: Sprite2D
@export var count_label: Label
@export var inventory: RatInventory

var _base_body_offset_y: float = -8.0
var _base_item_pos_y: float = -18.0
var _base_label_pos_y: float = -40.0

var _bob_timer: float = 0.0

func _ready() -> void:
	if inventory:
		inventory.inventory_changed.connect(update_held_item_visual)

	# Initialize base positions from current inspector values
	if body_sprite: _base_body_offset_y = body_sprite.offset.y
	if held_item_sprite: _base_item_pos_y = held_item_sprite.position.y
	if count_label: _base_label_pos_y = count_label.position.y

	update_held_item_visual()

func update_held_item_visual() -> void:
	if not held_item_sprite or not inventory:
		return

	if not inventory.has_items():
		held_item_sprite.texture = null
		if count_label: count_label.text = ""
		return

	# Show first item
	var first_id: String = inventory.get_first_item_id()
	var item: InventoryItem = ItemRegistry.get_item(first_id) if ItemRegistry else null

	if item:
		held_item_sprite.texture = item.icon
	else:
		held_item_sprite.texture = null

	if count_label:
		var total: int = inventory.get_total_count()
		count_label.text = str(total) if total > 1 else ""

func set_facing_direction(direction: Vector2) -> void:
	if direction.x != 0 and body_sprite:
		body_sprite.flip_h = direction.x < 0

		# Optional: Flip held item position if we wanted side-holding
		# For now, assuming it's centered above/front, so no position flip needed.

func update_bob(delta: float, is_moving: bool) -> void:
	if not body_sprite: return

	var bob_offset: float = 0.0

	if is_moving:
		_bob_timer += delta * 15.0
		bob_offset = sin(_bob_timer) * 2.0
	else:
		# Smoothly return to 0 bob
		# We use the current offset difference to calculate the current bob, then lerp it
		var current_bob = body_sprite.offset.y - _base_body_offset_y
		bob_offset = lerpf(current_bob, 0.0, delta * 10.0)
		_bob_timer = 0.0

	# Apply bob to all visual components
	body_sprite.offset.y = _base_body_offset_y + bob_offset

	if held_item_sprite:
		held_item_sprite.position.y = _base_item_pos_y + bob_offset

	if count_label:
		count_label.position.y = _base_label_pos_y + bob_offset

func reset_bob() -> void:
	_bob_timer = 0.0
	update_bob(0.0, false)

func set_visible_in_world(visible_state: bool) -> void:
	if body_sprite: body_sprite.visible = visible_state
	if held_item_sprite: held_item_sprite.visible = visible_state
	if count_label: count_label.visible = visible_state
