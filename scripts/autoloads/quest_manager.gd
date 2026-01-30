extends Node

## Manages quest progression, states, and condition-based unlocks.

signal quest_unlocked(quest_id)
signal quest_activated(quest_id)
signal quest_started(quest_id) # For backward compatibility
signal quest_completed(quest_id)
signal quest_updated(quest_id)

enum QuestState {
	LOCKED,
	UNLOCKED,
	ACTIVE,
	COMPLETED
}

const QUESTS_PATH = "res://resources/quests/"

## Cache of all QuestResources found in QUESTS_PATH
var _all_quests: Dictionary = {} # { quest_id: QuestResource }

## Current states of all quests
var _quest_states: Dictionary = {} # { quest_id: QuestState }

## Items deposited into quests
var _quest_deposits: Dictionary = {} # { quest_id: { item_id: count } }

# For backward compatibility with scripts accessing active_quests directly
var active_quests: Dictionary :
	get:
		var active = {}
		for q_id in _quest_states:
			if _quest_states[q_id] == QuestState.ACTIVE:
				active[q_id] = {
					"current_items": _quest_deposits.get(q_id, {})
				}
		return active

# For backward compatibility with scripts accessing completed_quests directly
var completed_quests: Dictionary :
	get:
		var completed = {}
		for q_id in _quest_states:
			if _quest_states[q_id] == QuestState.COMPLETED:
				completed[q_id] = true
		return completed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan_quests()
	
	# Connect to reactive signals
	if Inventory:
		Inventory.item_added.connect(_on_inventory_changed)
	if DialogueManager:
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	if GameState:
		GameState.flag_changed.connect(_on_flag_changed)
	
	# Re-check triggers on completion of any quest for potential chain unlocks
	quest_completed.connect(func(_id): _check_conditions_for_unlocks())
	
	# Initial check
	_check_conditions_for_unlocks()

func _scan_quests() -> void:
	var dir = DirAccess.open(QUESTS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				var path = QUESTS_PATH + file_name.replace(".remap", "")
				var quest = load(path) as QuestResource
				if quest and quest.id != "":
					_all_quests[quest.id] = quest
			file_name = dir.get_next()
	else:
		push_error("QuestManager: Could not open quests directory: " + QUESTS_PATH)

func get_quest_state(quest_id: String) -> int:
	return _quest_states.get(quest_id, QuestState.LOCKED)

func unlock_quest(quest_id: String) -> void:
	if get_quest_state(quest_id) == QuestState.LOCKED:
		_quest_states[quest_id] = QuestState.UNLOCKED
		quest_unlocked.emit(quest_id)
		print("Quest Unlocked: ", quest_id)

func activate_quest(quest_id: String) -> void:
	var state = get_quest_state(quest_id)
	if state == QuestState.UNLOCKED or state == QuestState.LOCKED:
		_quest_states[quest_id] = QuestState.ACTIVE
		if not _quest_deposits.has(quest_id):
			_quest_deposits[quest_id] = {}
		
		quest_activated.emit(quest_id)
		quest_started.emit(quest_id) # Compatibility
		quest_updated.emit(quest_id)
		print("Quest Activated: ", quest_id)

func deposit_item(quest_id: String, item_id: String, count: int) -> void:
	if get_quest_state(quest_id) != QuestState.ACTIVE:
		return
		
	if not _quest_deposits.has(quest_id):
		_quest_deposits[quest_id] = {}
		
	var current = _quest_deposits[quest_id].get(item_id, 0)
	_quest_deposits[quest_id][item_id] = current + count
	
	quest_updated.emit(quest_id)
	print("Quest Deposit: ", quest_id, " | ", item_id, " +", count)
	
	if check_quest_completion(quest_id):
		# We don't auto-complete, we just notify. 
		# NPC dialogue or explicit call should trigger complete_quest.
		pass

func check_quest_completion(quest_id: String) -> bool:
	if not _all_quests.has(quest_id): return false
	var quest = _all_quests[quest_id]
	var deposits = _quest_deposits.get(quest_id, {})
	
	for req_id in quest.required_items:
		if deposits.get(req_id, 0) < quest.required_items[req_id]:
			return false
	return true

func complete_quest(quest_id: String) -> void:
	if get_quest_state(quest_id) != QuestState.ACTIVE:
		return
		
	_quest_states[quest_id] = QuestState.COMPLETED
	quest_completed.emit(quest_id)
	quest_updated.emit(quest_id)
	print("Quest Completed: ", quest_id)

func is_quest_active(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestState.ACTIVE

func is_quest_completed(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestState.COMPLETED

func start_quest(quest_id: String) -> void:
	# Backward compatibility: ensures quest is active
	activate_quest(quest_id)

func check_quest_progress(quest_id: String) -> void:
	quest_updated.emit(quest_id)

func _on_inventory_changed(_item, _slot, _count) -> void:
	_check_conditions_for_unlocks()

func _on_dialogue_finished() -> void:
	_check_conditions_for_unlocks()

func _on_flag_changed(_flag, _val) -> void:
	_check_conditions_for_unlocks()

func _check_conditions_for_unlocks() -> void:
	for quest_id in _all_quests:
		if get_quest_state(quest_id) == QuestState.LOCKED:
			var quest = _all_quests[quest_id]
			if quest.are_conditions_met():
				unlock_quest(quest_id)

func get_active_quests() -> Dictionary:
	return active_quests

func get_completed_quests() -> Dictionary:
	return completed_quests

# Save/Load Support
func to_save_data() -> Dictionary:
	return {
		"states": _quest_states.duplicate(),
		"deposits": _quest_deposits.duplicate(true)
	}

func from_save_data(data: Dictionary) -> void:
	if data.has("states"):
		var saved_states = data["states"]
		_quest_states.clear()
		for key in saved_states:
			_quest_states[key] = int(saved_states[key])
			
	if data.has("deposits"):
		_quest_deposits = data["deposits"].duplicate(true)
	
	# Migration/Legacy Support
	if data.has("active") and _quest_states.is_empty():
		for q_id in data["active"]:
			_quest_states[q_id] = QuestState.ACTIVE
			_quest_deposits[q_id] = data["active"][q_id].get("current_items", {})
	
	if data.has("completed") and _quest_states.values().count(QuestState.COMPLETED) == 0:
		for q_id in data["completed"]:
			_quest_states[q_id] = QuestState.COMPLETED

	_check_conditions_for_unlocks()

func reset() -> void:
	_quest_states.clear()
	_quest_deposits.clear()
	_check_conditions_for_unlocks()
