extends HBoxContainer

@export var float_speed: float = 30.0
@export var fade_duration: float = 1.0

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

func _ready() -> void:
	# Ensure mouse input doesn't block interactions
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Tween the container's position and modulation
	tween.tween_property(self, "position:y", -float_speed, fade_duration).as_relative()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.chain().tween_callback(queue_free)

func set_content(text_content: String, icon_texture: Texture2D = null) -> void:
	if label:
		label.text = text_content
	
	if icon_rect:
		if icon_texture:
			icon_rect.texture = icon_texture
			icon_rect.visible = true
		else:
			icon_rect.visible = false

# Backward compatibility
func set_text_content(content: String) -> void:
	set_content(content, null)
