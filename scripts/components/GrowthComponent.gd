@tool
class_name GrowthComponent
extends Node

## Manages plant growth stages and timing.

signal stage_changed(stage_index: int)
signal growth_complete

## Configuration: [{ "frame": int, "duration": float }]
@export var growth_stages: Array[Dictionary] = []

# State
var current_stage: int = 0
var growth_timer: Timer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	growth_timer = Timer.new()
	growth_timer.one_shot = true
	growth_timer.timeout.connect(_on_growth_timer_timeout)
	add_child(growth_timer)
	
	# Auto-start if configured
	if not growth_stages.is_empty():
		_apply_stage(0)

func _start_growth() -> void:
	if growth_stages.is_empty():
		return
	_apply_stage(0)

func _apply_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= growth_stages.size():
		return
		
	current_stage = stage_index
	var stage = growth_stages[stage_index]
	
	# Emit signal so parent (Plant) can update sprite frame
	stage_changed.emit(current_stage)
	
	# Check duration
	var duration: float = stage.get("duration", 0.0)
	if duration > 0.0 and stage_index < growth_stages.size() - 1:
		growth_timer.start(duration)
	elif stage_index == growth_stages.size() - 1:
		growth_complete.emit()

func _on_growth_timer_timeout() -> void:
	var next_stage = current_stage + 1
	if next_stage < growth_stages.size():
		_apply_stage(next_stage)

func get_current_stage() -> int:
	return current_stage

func set_growth_stage(stage_index: int) -> void:
	growth_timer.stop()
	_apply_stage(clampi(stage_index, 0, growth_stages.size() - 1))

func is_fully_grown() -> bool:
	if growth_stages.is_empty(): return true
	return current_stage >= growth_stages.size() - 1

# --- Save/Load ---

func get_save_data() -> Dictionary:
	return {
		"current_stage": current_stage,
		"time_left": growth_timer.time_left if not growth_timer.is_stopped() else 0.0
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("current_stage"):
		var stage = int(data["current_stage"])
		set_growth_stage(stage)
		
		if data.has("time_left"):
			var time = float(data["time_left"])
			if time > 0 and not is_fully_grown():
				growth_timer.start(time)
