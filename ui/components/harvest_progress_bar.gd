extends ProgressBar

func update_progress(current_time: float, max_time: float) -> void:
	max_value = max_time
	value = current_time
