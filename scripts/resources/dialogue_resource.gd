class_name DialogueResource
extends Resource

## Data container for a linear dialogue sequence.
## Used by DialogueManager to display conversations.

## Unique ID for state tracking (e.g. "tutorial_intro", "npc_rat_greet")
@export var dialogue_id: String = ""

## Name displayed above the dialogue box
@export var speaker_name: String = ""

## Optional portrait of the speaker
@export var portrait: Texture2D

## Sequential lines of text to display
@export_multiline var lines: Array[String] = []

## Optional translation keys corresponding to lines (for localization)
## If empty, raw text from 'lines' is used.
@export var translation_keys: Array[String] = []
