class_name QuestResource
extends Resource

## Data container for a quest.
## Defines the quest details, objectives, and rewards.

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""

## Dictionary of required items and their counts.
## Format: { "item_id": quantity }
## Example: { "wood": 5, "stone": 2 }
@export var required_items: Dictionary = {} 

## Dictionary of rewards.
## Format: { "item_id": quantity }
@export var rewards: Dictionary = {}

@export var npc_id: String = ""
@export var unlock_conditions: Array[QuestCondition] = []
@export_enum("AND", "OR") var condition_operator: String = "AND"
@export var reward_dialogue_id: String = ""

func are_conditions_met() -> bool:
	if unlock_conditions.is_empty():
		return true
		
	if condition_operator == "AND":
		for condition in unlock_conditions:
			if not condition.is_met():
				return false
		return true
	else: # OR
		for condition in unlock_conditions:
			if condition.is_met():
				return true
		return false
