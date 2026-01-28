extends Node

## Manages the state of tips (hints) in the game.
## Keeps track of which tips have been seen by the player.

signal tip_state_changed(tip_id: String, is_seen: bool)

var _seen_tips: Dictionary = {}

func is_seen(tip_id: String) -> bool:
	return _seen_tips.get(tip_id, false)

func mark_seen(tip_id: String) -> void:
	if not is_seen(tip_id):
		_seen_tips[tip_id] = true
		tip_state_changed.emit(tip_id, true)

func to_save_data() -> Dictionary:
	return _seen_tips.duplicate()

func from_save_data(data: Dictionary) -> void:
	_seen_tips = data.duplicate()
	# Notify listeners (though usually this happens on load where listeners aren't ready yet)
	for tip_id in _seen_tips:
		tip_state_changed.emit(tip_id, true)

func reset() -> void:
	_seen_tips.clear()
