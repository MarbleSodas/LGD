extends Label

@export var float_speed: float = 30.0
@export var fade_duration: float = 1.0

func _ready() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", -float_speed, fade_duration).as_relative()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.chain().tween_callback(queue_free)

func set_text_content(content: String) -> void:
	text = content
