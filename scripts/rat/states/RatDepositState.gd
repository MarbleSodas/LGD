class_name RatDepositState
extends State

@export var deposit_duration: float = 0.4

var _timer: float = 0.0

func enter() -> void:
	_timer = 0.0
	var rat = entity as RatAssistant
	if rat and rat.visuals:
		rat.visuals.reset_bob()

func update(delta: float) -> void:
	_timer += delta
	var rat = entity as RatAssistant
	if not rat: return
	
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _timer >= deposit_duration:
		_complete_deposit(rat)

func _complete_deposit(rat: RatAssistant) -> void:
	var building = rat.planting_system.get_object_at(rat.output_coords) if rat.planting_system else null
	
	if building and building.has_method("get_container"):
		var container = building.get_container()
		if container and container.has_method("add_item"):
			# Deposit all items
			for item_id in rat.inventory.items:
				var amount = rat.inventory.items[item_id]
				var item = ItemRegistry.get_item(item_id) if ItemRegistry else null
				if item:
					container.add_item(item, amount)
					rat.item_deposited.emit(item_id, amount)
	
	rat.inventory.clear()
	
	transition_requested.emit(self, "idle")
	
	# Trigger immediate check from house
	if rat.home_building and rat.home_building.has_method("on_rat_idle"):
		rat.home_building.on_rat_idle(rat)
