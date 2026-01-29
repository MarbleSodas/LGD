class_name TreePlant
extends Plant

## Extended Plant script for Trees that enables collision at later growth stages.

func _ready() -> void:
	super._ready()
	# Ensure collision is set correctly when spawned/loaded
	_update_collision()

func _apply_stage(stage_index: int) -> void:
	super._apply_stage(stage_index)
	_update_collision()

func harvest() -> Dictionary:
	var result = super.harvest()
	if not result.is_empty() and not regrows:
		queue_free()
	return result

func _update_collision() -> void:
	var collider = get_node_or_null("StaticBody2D/CollisionShape2D")
	if collider:
		# Collision enabled for stage 1 (Young) and 2 (Mature)
		# Stage 0 is Small Sapling (no collision)
		collider.disabled = (current_stage < 1)
