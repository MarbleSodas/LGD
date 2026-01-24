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
	var building: Node2D = rat.planting_system.get_object_at(rat.output_coords) if rat.planting_system else null
	
	if building and building.has_method("get_container"):
		# Smart Processor Logic
		var wanted_id: String = ""
		if building.has_method("get_wanted_item_id"):
			wanted_id = building.get_wanted_item_id()
			
		var container: Object = building.get_container()
		if container and container.has_method("add_item"):
			# If it's a generic container (wanted_id == ""), we can dump everything.
			# If it's a specific processor (wanted_id != ""), only dump that item.
			
			# Collect items to remove (can't modify dict while iterating)
			var deposited_items: Array = []
			
			for item_id in rat.inventory.items:
				# Filter Logic
				if wanted_id != "" and item_id != wanted_id:
					continue
					
				var amount: int = rat.inventory.items[item_id]
				var item: InventoryItem = ItemRegistry.get_item(item_id) if ItemRegistry else null
				if item:
					# Try adding to container (it might be full)
					# ContainerInventory.add_item doesn't return leftover amount in this codebase usually
					# Assuming it accepts everything for now or logic handles full earlier.
					# Note: Processor input inventory is size 1 stack.
					container.add_item(item, amount)
					rat.item_deposited.emit(item_id, amount)
					deposited_items.append(item_id)
			
			# Clear deposited items from rat inventory
			if wanted_id == "":
				# Generic dump - clear all
				rat.inventory.clear()
			else:
				# Specific deposit - only remove what we deposited
				for id in deposited_items:
					# We put ALL of it in. 
					# (If container logic is robust it handles partials, but here we assume success)
					rat.inventory.remove_item(id, rat.inventory.items[id])

	transition_requested.emit(self, "idle")
	
	# Trigger immediate check from house
	if rat.home_building and rat.home_building.has_method("on_rat_idle"):
		rat.home_building.on_rat_idle(rat)
