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
