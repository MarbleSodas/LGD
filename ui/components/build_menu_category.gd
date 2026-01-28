extends VBoxContainer
class_name BuildMenuCategory

signal toggled(is_expanded: bool)

var _type: int
var _is_expanded: bool = true

@onready var header_button: BaseButton = $HeaderPanel/HeaderButton
@onready var arrow_label: Label = $HeaderPanel/HBoxContainer/ArrowLabel
@onready var title_label: Label = $HeaderPanel/HBoxContainer/TitleLabel
@onready var items_container: VBoxContainer = $AnimationWrapper/ItemsContainer
@onready var animation_wrapper: Control = $AnimationWrapper

func _ready() -> void:
	# Ensure the signal is connected
	if not header_button.pressed.is_connected(_on_header_pressed):
		header_button.pressed.connect(_on_header_pressed)
	
	# Initial state
	if _is_expanded:
		animation_wrapper.visible = true
	else:
		animation_wrapper.visible = false
		animation_wrapper.custom_minimum_size.y = 0

func setup(type: int, category_name: String) -> void:
	_type = type
	if title_label:
		title_label.text = category_name
	
	# Initialize state without animation
	set_expanded(_is_expanded, false)

func add_item_slot(slot_node: Node) -> void:
	items_container.add_child(slot_node)
	# Recalculate size if expanded
	if _is_expanded and is_inside_tree():
		# Defer to allow child to layout
		get_tree().create_timer(0.05).timeout.connect(_update_height)

func set_expanded(expanded: bool, animate: bool = true) -> void:
	_is_expanded = expanded
	
	if not is_inside_tree():
		return
		
	# Update arrow
	if arrow_label:
		arrow_label.text = "▼" if _is_expanded else "►"
	
	_update_height(animate)

func _update_height(animate: bool = true) -> void:
	if not animation_wrapper or not items_container:
		return
		
	# Calculate target height based on content
	var target_height: float = 0.0
	
	if _is_expanded:
		# Force update of children sizes
		items_container.queue_sort() # Force layout update
		
		# Get the height of the content
		target_height = items_container.get_minimum_size().y
		
		# Ensure visible before animating
		animation_wrapper.visible = true
	
	if animate:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		
		tween.tween_property(animation_wrapper, "custom_minimum_size:y", target_height, 0.3)
		
		if not _is_expanded:
			tween.finished.connect(func(): animation_wrapper.visible = false)
	else:
		animation_wrapper.custom_minimum_size.y = target_height
		animation_wrapper.visible = _is_expanded

func _on_header_pressed() -> void:
	set_expanded(not _is_expanded, true)
	toggled.emit(_is_expanded)
