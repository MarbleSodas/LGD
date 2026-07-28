extends Node

## Tracks tutorial-tip acknowledgement independently from world progression.

signal tip_state_changed(tip_id: String, is_seen: bool)

var _seen_tips: Dictionary = {}


func is_seen(tip_id: String) -> bool:
	return _seen_tips.get(tip_id, false)


func mark_seen(tip_id: String) -> void:
	if is_seen(tip_id):
		return

	_seen_tips[tip_id] = true
	tip_state_changed.emit(tip_id, true)


func reset_tips() -> void:
	_seen_tips.clear()


func to_save_data() -> Dictionary:
	return _seen_tips.duplicate(true)


func from_save_data(data: Dictionary) -> void:
	_seen_tips = data.duplicate(true)
	for tip_id: String in _seen_tips:
		tip_state_changed.emit(tip_id, true)
