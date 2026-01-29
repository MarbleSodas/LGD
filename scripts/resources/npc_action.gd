class_name NPCAction
extends Resource

## Data container for an NPC action button.
## Used in the dialogue box to present options after conversation.

## Unique ID for the action (e.g. "talk", "shop", "research")
@export var action_id: String = ""

## Text displayed on the button
@export var display_name: String = ""

## Optional icon for the button
@export var icon: Texture2D

## If set, this action only appears if the player has this story flag
@export var requires_flag: String = ""

## If set, this action is hidden if the player has this story flag
@export var disabled_if_flag: String = ""
