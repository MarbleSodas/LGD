class_name QuestCondition
extends Resource

enum ConditionType {
	HAS_ITEM,
	QUEST_COMPLETED,
	DIALOGUE_SEEN,
	HAS_FLAG
}

@export var condition_type: ConditionType
@export var target_id: String
@export var required_count: int = 1

func is_met() -> bool:
	match condition_type:
		ConditionType.HAS_ITEM:
			return Inventory.has_item(target_id, required_count)
		ConditionType.QUEST_COMPLETED:
			return QuestManager.is_quest_completed(target_id)
		ConditionType.DIALOGUE_SEEN:
			return DialogueManager.has_shown(target_id)
		ConditionType.HAS_FLAG:
			return GameState.get_flag(target_id)
	return false
