class_name RatDepositState
extends State

@export var deposit_duration: float = 0.4

var _timer: float = 0.0

func enter() -> void:
	_timer = 0.0
	var rat: RatAssistant = entity as RatAssistant
	if rat and rat.visuals:
		rat.visuals.reset_bob()

func update(delta: float) -> void:
	_timer += delta
	var rat: RatAssistant = entity as RatAssistant
	if not rat: return
	
	if rat.visuals:
		rat.visuals.update_bob(delta, false)
	
	if _timer >= deposit_duration:
		_complete_deposit(rat)

func _complete_deposit(rat: RatAssistant) -> void:
	var obj = rat.target_container
	if not obj and rat.planting_system:
		obj = rat.planting_system.get_object_at(rat.target_coords)
	
	if obj and obj.has_method("get_container"):
		var wanted_id: String = ""
		if obj.has_method("get_wanted_item_id"):
			wanted_id = obj.get_wanted_item_id()
			
		var container: Object = obj.get_container()
		if container and container.has_method("add_item"):
			var deposited_items: Array = []
			
			for item_id in rat.inventory.items:
				# Filter Logic: Only deposit wanted items if specified
				if wanted_id != "" and item_id != wanted_id:
					continue
					
				var amount: int = rat.inventory.items[item_id]
				var item: InventoryItem = ItemRegistry.get_item(item_id) if ItemRegistry else null
				
				if item:
					container.add_item(item, amount)
					rat.item_deposited.emit(item_id, amount)
					deposited_items.append(item_id)
			
			# Remove deposited items from rat
			if wanted_id == "":
				rat.inventory.clear()
			else:
				for id in deposited_items:
					rat.inventory.remove_item(id, rat.inventory.items[id])

	transition_requested.emit(self, "idle")
