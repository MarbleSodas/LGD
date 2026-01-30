extends Node

signal quest_started(quest_id)
signal quest_completed(quest_id)

# Format: { quest_id: { "current_items": { "wood": 2 } } }
var active_quests: Dictionary = {}
# Format: { quest_id: true }
var completed_quests: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_quest(quest_id: String) -> void:
	if quest_id == "": return
	
	if is_quest_active(quest_id):
		print("Quest already active: ", quest_id)
		return
		
	if is_quest_completed(quest_id):
		print("Quest already completed: ", quest_id)
		return
		
	# Initialize quest state
	active_quests[quest_id] = {
		"current_items": {}
	}
	
	emit_signal("quest_started", quest_id)
	print("Quest Started: ", quest_id)

func complete_quest(quest_id: String) -> void:
	if quest_id == "": return
	
	if not is_quest_active(quest_id):
		print("Cannot complete inactive quest: ", quest_id)
		return
		
	active_quests.erase(quest_id)
	completed_quests[quest_id] = true
	
	emit_signal("quest_completed", quest_id)
	print("Quest Completed: ", quest_id)

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)

func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func get_active_quests() -> Dictionary:
	return active_quests

func get_completed_quests() -> Dictionary:
	return completed_quests

# Save/Load Support
func to_save_data() -> Dictionary:
	return {
		"active": active_quests.duplicate(true),
		"completed": completed_quests.duplicate(true)
	}

func from_save_data(data: Dictionary) -> void:
	if data.has("active"):
		active_quests = data["active"].duplicate(true)
	if data.has("completed"):
		completed_quests = data["completed"].duplicate(true)

func reset() -> void:
	active_quests.clear()
	completed_quests.clear()
