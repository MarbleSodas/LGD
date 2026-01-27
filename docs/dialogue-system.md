# Dialogue System

## Overview
A linear dialogue system using Sproutlands UI assets. It supports portraits, typewriter effects, and input blocking.

## Creating Dialogue Content
1. In FileSystem dock, right-click -> **Create New** -> **Resource**.
2. Search for `DialogueResource`.
3. Save as a `.tres` file (e.g. `res://resources/dialogues/npc_intro.tres`).
4. Edit properties in the Inspector:
   - `dialogue_id`: Unique ID for state tracking (e.g. "npc_intro").
   - `speaker_name`: Name displayed above the text (e.g. "Old Man").
   - `portrait`: Optional texture for the speaker.
   - `lines`: Array of strings to display sequentially.
   - `translation_keys`: Optional array of translation keys matching the lines.

## Triggering Dialogue
To start a dialogue from any script (NPC, Building, Event), export a `DialogueResource` variable and call the manager:

```gdscript
extends Node2D

@export var dialogue_resource: DialogueResource

func interact():
    # Optional: Check if already shown
    if dialogue_resource and not DialogueManager.has_shown(dialogue_resource.dialogue_id):
        DialogueManager.start_dialogue(dialogue_resource)
```

## API Reference (DialogueManager)

`scripts/autoloads/dialogue_manager.gd`

- `start_dialogue(resource: DialogueResource) -> void`: Opens the dialogue UI with the given resource.
- `close_dialogue() -> void`: Force closes the dialogue.
- `is_active() -> bool`: Returns `true` if a dialogue is currently open.
- `has_shown(dialogue_id: String) -> bool`: Returns `true` if the dialogue ID has been shown in the current session.
- `mark_shown(dialogue_id: String) -> void`: Manually marks a dialogue ID as shown.

## Localization
The system supports Godot's built-in localization.
- Provide `translation_keys` in the `DialogueResource`.
- If a key exists for the current line index, `tr(key)` is called.
- If the key is empty or missing, the raw text from `lines` is used.

## Inputs
- **Advance/Skip**: `ui_accept` (Space/Enter) or `harvest` (E).
- **Cancel**: `ui_cancel` (Escape) - Closes dialogue immediately.
- **Note**: Player movement is blocked while dialogue is active.
