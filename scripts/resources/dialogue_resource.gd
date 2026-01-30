class_name DialogueResource
extends Resource

## Data container for a linear dialogue sequence.
## Used by DialogueManager to display conversations.

## Unique ID for state tracking (e.g. "tutorial_intro", "npc_rat_greet")
@export var dialogue_id: String = ""

## Default name displayed above the dialogue box.
## Used if a DialogueEntry doesn't specify a speaker_override.
@export var speaker_name: String = ""

## Default portrait of the speaker.
## Used if a DialogueEntry doesn't specify a portrait_override.
@export var portrait: Texture2D

## Sequential entries of dialogue to display.
## Each entry defines text, speaker override, portrait override, etc.
@export var entries: Array[DialogueEntry] = []
