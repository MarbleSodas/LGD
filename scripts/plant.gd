class_name Plant
extends Sprite2D

## Reusable plant script with configurable growth stages.
##
## Each stage has a frame index and duration. The plant cycles through stages
## and emits signals when growth completes or harvest is ready.

## Emitted when the plant reaches its final growth stage (harvest ready)
signal harvest_ready
## Emitted when the plant transitions to a new growth stage
signal stage_changed(stage_index: int)
## Emitted when the plant is harvested
signal harvested(item_id: String, amount: int)

## Growth stage configuration
## Each entry is a dictionary with:
##   - "frame": int - The sprite frame index to display
##   - "duration": float - Time in seconds before advancing to next stage (0 = final stage)
@export var growth_stages: Array[Dictionary] = []

## Harvest Configuration
@export var harvest_item_id: String = ""
@export var harvest_amount: int = 1
@export var harvest_time: float = 0.5
@export var regrows: bool = false

## Current growth stage index
var current_stage: int = 0

## Timer for growth transitions
var growth_timer: Timer

func _ready() -> void:
	_setup_timer()
	_start_growth()

func _setup_timer() -> void:
	growth_timer = Timer.new()
	growth_timer.one_shot = true
	growth_timer.timeout.connect(_on_growth_timer_timeout)
	add_child(growth_timer)

func _start_growth() -> void:
	if growth_stages.is_empty():
		push_warning("Plant has no growth stages configured!")
		return
	
	_apply_stage(0)

func _apply_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= growth_stages.size():
		return
	
	current_stage = stage_index
	var stage: Dictionary = growth_stages[stage_index]
	
	# Set the sprite frame
	frame = stage.get("frame", 0)
	
	# Emit stage change signal
	stage_changed.emit(current_stage)
	
	# Check if this is the final stage (duration == 0 or not set)
	var duration: float = stage.get("duration", 0.0)
	if duration > 0.0 and stage_index < growth_stages.size() - 1:
		# Start timer for next stage
		growth_timer.start(duration)
	else:
		# Final stage reached
		harvest_ready.emit()

func _on_growth_timer_timeout() -> void:
	# Advance to next stage
	var next_stage: int = current_stage + 1
	if next_stage < growth_stages.size():
		_apply_stage(next_stage)

## Returns true if the plant is at its final growth stage
func is_harvest_ready() -> bool:
	return current_stage == growth_stages.size() - 1

## Returns the current growth stage index
func get_current_stage() -> int:
	return current_stage

## Force the plant to a specific growth stage (useful for loading saves)
func set_growth_stage(stage_index: int) -> void:
	growth_timer.stop()
	_apply_stage(clampi(stage_index, 0, growth_stages.size() - 1))

## Harvest the plant
## Returns a dictionary { "item_id": str, "amount": int } or empty if not ready
func harvest() -> Dictionary:
	if not is_harvest_ready() and not harvest_item_id.is_empty():
		return {}
		
	var result: Dictionary = {
		"item_id": harvest_item_id,
		"amount": harvest_amount
	}
	
	harvested.emit(harvest_item_id, harvest_amount)
	
	if regrows:
		_apply_stage(0)
	else:
		# Consumed logic handled by caller (PlantingSystem)
		pass
		
	return result

# ------------------------------------------------------------------------------
# Save/Load Support
# ------------------------------------------------------------------------------

## Returns data to be saved by the PlantingSystem
func get_save_data() -> Dictionary:
	return {
		"current_stage": current_stage,
		"time_left": growth_timer.time_left if not growth_timer.is_stopped() else 0.0
	}

## Loads data from a save file
func load_save_data(data: Dictionary) -> void:
	if data.has("current_stage"):
		var stage = int(data["current_stage"])
		set_growth_stage(stage)
		
		# Override timer if provided and valid
		if data.has("time_left"):
			var time = float(data["time_left"])
			if time > 0 and not is_harvest_ready():
				growth_timer.start(time)
