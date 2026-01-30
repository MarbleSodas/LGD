class_name DialogueEntry
extends Resource

## A single beat of dialogue.
## Defines what is said and who says it.

## The line of text to display.
@export_multiline var text: String = ""

## Optional: Override the displayed speaker name for this specific line.
## Useful for "???" reveals or multiple speakers.
## If empty, uses the DialogueResource's default speaker.
@export var speaker_override: String = ""

## Optional: Override the portrait for this specific line.
## If null, uses the DialogueResource's default portrait.
@export var portrait_override: Texture2D

## Optional: Expression/Mood string (e.g., "happy", "angry") that could trigger animations
@export var expression: String = ""

## Optional: Translation key for the text.
## If set, 'text' is ignored in favor of tr(translation_key).
@export var translation_key: String = ""

@export_group("Quest Events")
## Optional: Quest ID to start when this line is shown.
@export var quest_to_start: String = ""

## Optional: Quest ID to complete when this line is shown.
@export var quest_to_complete: String = ""
