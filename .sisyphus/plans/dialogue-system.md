# Dialogue System Implementation

## Context

### Original Request
Create a dialogue system using the Sproutlands UI assets with proper dialog box display, utilizing node-based architecture following best practices.

### Interview Summary
**Key Discussions**:
- **Triggers**: Full system - NPCs, events, items, buildings can all trigger dialogue
- **Flow**: Linear dialogue only (no branching player choices)
- **UI Style**: Hybrid approach - portrait background as node component + NinePatchRect scalable dialog box
- **Data**: DialogueResource custom .tres files for type-safety
- **Polish**: Typewriter effect, continue indicator, entrance animation
- **Verification**: Manual testing via Godot editor

**Research Findings**:
- Sproutlands dialogue assets at `assets/sproutlands/Sprite sheets/Dialouge UI/`
- `dialog box medium.png` (112x42px) suitable for 9-slice
- Existing patterns: State machine, signal-driven, autoloads
- InteractionManager handles player-world interaction
- UI container at `ui/ui.tscn` uses CanvasLayer

### Metis Review
**Identified Gaps** (addressed):
- NPC existence: No NPCs exist → defer NPC creation, provide interface only
- Portrait source: No portrait assets → treat portrait as optional
- Escape priority: Must integrate into `world.gd:_close_any_open_ui()` → dialogue FIRST
- Typewriter skip: Standard click-to-complete behavior
- Rich text: Use RichTextLabel for future extensibility

---

## Work Objectives

### Core Objective
Build a reusable dialogue system with Sproutlands-styled UI that displays speaker portraits and typewriter text, triggered via a simple API from any game object.

### Concrete Deliverables
1. `scripts/resources/dialogue_resource.gd` - Custom Resource for dialogue data
2. `ui/components/dialogue_box.tscn` - UI scene with portrait + 9-slice dialog box
3. `ui/components/dialogue_box.gd` - UI controller with typewriter effect
4. `scripts/autoloads/dialogue_manager.gd` - Singleton for dialogue control
5. Modified `world.gd` - Escape key priority integration
6. Test `.tres` file demonstrating the system

### Definition of Done
- [ ] Running game can trigger dialogue via `DialogueManager.start_dialogue(resource)`
- [ ] Dialogue box appears with typewriter effect and continue indicator
- [ ] Player input is blocked during active dialogue
- [ ] Escape key closes dialogue (highest priority)
- [ ] "E" or "Space" advances dialogue lines
- [ ] System emits `dialogue_finished` signal when complete

### Must Have
- DialogueManager autoload with `start_dialogue()` API
- DialogueBox UI with portrait frame + scalable text area
- Typewriter effect with skip-on-click
- Continue indicator animation
- Input blocking during dialogue
- Escape key closes dialogue (first priority)
- Dialogue state tracking (what has been shown)
- Translation key support for localization

### Must NOT Have (Guardrails)
- No NPC class creation (provide interface documentation only)
- No branching choices or conditions
- No audio integration (out of scope)
- No modification to GameState.gd (use dedicated DialogueManager)
- No tree pausing (`get_tree().paused = true` breaks auto-save)
- No vertical stretching of dialog box asset (pointer distorts)
- No over-engineering - keep linear flow simple

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: Manual-only
- **Framework**: None

### Manual QA Approach

Each TODO includes verification procedures using the Godot editor.

**Evidence Required:**
- Screenshot of dialogue box displaying correctly
- Verification of typewriter effect timing
- Confirmation of input blocking behavior
- Test of escape key priority

---

## Task Flow

```
Task 1 (DialogueResource) → Task 2 (DialogueBox UI) → Task 3 (DialogueBox Script)
                                                              ↓
                                                      Task 4 (DialogueManager)
                                                              ↓
                                                      Task 5 (World.gd Integration)
                                                              ↓
                                                      Task 6 (Test & Documentation)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | None | Foundation - data structure |
| 2 | None | Can build UI scene independently |
| 3 | 1, 2 | Needs resource structure and scene |
| 4 | 1, 3 | Needs resource and UI controller |
| 5 | 4 | Needs DialogueManager to exist |
| 6 | 5 | Integration testing after all pieces |

---

## TODOs

- [ ] 1. Create DialogueResource Class

  **What to do**:
  - Create `scripts/resources/dialogue_resource.gd`
  - Define custom Resource class extending `Resource`
  - Properties:
    - `speaker_name: String` - Name displayed above dialogue
    - `portrait: Texture2D` - Optional speaker portrait
    - `lines: Array[String]` - Sequential dialogue text
    - `translation_keys: Array[String]` - Optional keys for localization
    - `dialogue_id: String` - Unique ID for state tracking
  - Add `@export` annotations for editor integration
  - Register class_name for global access

  **Must NOT do**:
  - No branching logic or conditions
  - No audio references (out of scope)
  - No complex nested structures

  **Parallelizable**: YES (with 2)

  **References**:

  **Pattern References**:
  - `scripts/resources/inventory_item.gd` - Example of custom Resource pattern in this project
  - `scripts/resources/processor_recipe.gd` - Another Resource example showing export annotations

  **External References**:
  - Godot docs: Custom Resources - https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html

  **Acceptance Criteria**:
  - [ ] File exists at `scripts/resources/dialogue_resource.gd`
  - [ ] Class is registered as `class_name DialogueResource`
  - [ ] Creating a `.tres` file with type DialogueResource works in editor
  - [ ] All properties visible and editable in Inspector
  - [ ] Verify: Create test resource, save as `resources/test_dialogue.tres`, confirm loads without errors

  **Commit**: YES
  - Message: `feat(dialogue): add DialogueResource class for dialogue data`
  - Files: `scripts/resources/dialogue_resource.gd`

---

- [ ] 2. Create DialogueBox UI Scene

  **What to do**:
  - Create `ui/components/dialogue_box.tscn`
  - Scene structure:
    ```
    DialogueBox (Control) [anchored bottom-center]
    ├── Background (NinePatchRect) [9-slice dialog box]
    ├── PortraitFrame (TextureRect) [left side, optional]
    │   └── Portrait (TextureRect) [actual speaker image]
    ├── Content (MarginContainer)
    │   └── VBox (VBoxContainer)
    │       ├── SpeakerLabel (Label) [speaker name]
    │       └── DialogueLabel (RichTextLabel) [dialogue text]
    └── ContinueIndicator (TextureRect) [animated arrow]
    ```
  - Use `dialog box medium.png` as 9-slice texture
  - 9-slice margins: top=12, bottom=12, left=16, right=10
  - Apply `themes/sproutlands_ui_theme.tres` for font styling
  - Set initial visibility to `false`
  - Use Scene Unique Names (`%`) for key nodes: `%DialogueLabel`, `%SpeakerLabel`, `%Portrait`, `%ContinueIndicator`

  **Must NOT do**:
  - No vertical stretching of dialog box (use fixed height or horizontal-only stretch)
  - No script attachment yet (Task 3)
  - No complex animations in scene (handled in script)

  **Parallelizable**: YES (with 1)

  **References**:

  **Pattern References**:
  - `ui/components/container_panel.tscn` - Example UI panel structure
  - `ui/components/hotbar_slot.tscn` - Example of modular UI component

  **Asset References**:
  - `assets/sproutlands/Sprite sheets/Dialouge UI/dialog box medium.png` - 9-slice texture
  - `assets/sproutlands/Sprite sheets/Dialouge UI/dialog box character finished talking click to continue indicator - spritesheet .png` - Continue indicator frames
  - `themes/sproutlands_ui_theme.tres` - Font and styling theme

  **Acceptance Criteria**:
  - [ ] Scene file exists at `ui/components/dialogue_box.tscn`
  - [ ] Opens in Godot editor without errors
  - [ ] Dialog box displays correctly with 9-slice scaling
  - [ ] Text area visible with proper margins
  - [ ] Portrait area visible on left side
  - [ ] Verify: Open scene in editor, manually instance and position at screen bottom

  **Commit**: YES
  - Message: `feat(dialogue): create DialogueBox UI scene with Sproutlands assets`
  - Files: `ui/components/dialogue_box.tscn`

---

- [ ] 3. Create DialogueBox Script with Typewriter Effect

  **What to do**:
  - Create `ui/components/dialogue_box.gd`
  - Attach to DialogueBox scene root
  - State management:
    ```gdscript
    var is_open: bool = false
    var current_dialogue: DialogueResource
    var current_line_index: int = 0
    var is_typing: bool = false
    ```
  - Signals:
    ```gdscript
    signal line_displayed
    signal dialogue_completed
    ```
  - Functions:
    - `open(dialogue: DialogueResource) -> void` - Start showing dialogue
    - `close() -> void` - Hide and cleanup
    - `advance() -> void` - Move to next line or close if done
    - `_type_text(text: String) -> void` - Typewriter effect using Tween
    - `_skip_typing() -> void` - Complete current line immediately
  - Typewriter implementation:
    - Use `Tween` to animate `visible_characters` property
    - Speed: ~30 characters per second (adjustable)
    - Click during typing → skip to full text
    - Click after complete → advance to next line
  - Continue indicator:
    - Show after typing completes
    - Simple bob animation using Tween
  - Entrance animation:
    - Slide up from bottom or fade in

  **Must NOT do**:
  - No input handling (DialogueManager handles input)
  - No dialogue state tracking (DialogueManager handles)
  - No direct autoload references for triggering

  **Parallelizable**: NO (depends on 1, 2)

  **References**:

  **Pattern References**:
  - `ui/components/container_panel.gd:15-80` - `is_open` state pattern, `open()/close()` API
  - `ui/components/floating_text.gd` - Tween-based animation example

  **API References**:
  - `RichTextLabel.visible_characters` - Property for typewriter effect
  - `Tween.tween_property()` - Animation method

  **External References**:
  - Godot docs: Tween - https://docs.godotengine.org/en/stable/classes/class_tween.html

  **Acceptance Criteria**:
  - [ ] Script attached to DialogueBox scene
  - [ ] `open(dialogue)` displays first line with typewriter effect
  - [ ] `close()` hides dialogue and resets state
  - [ ] `advance()` shows next line or emits `dialogue_completed`
  - [ ] Typewriter effect visible (characters appear one by one)
  - [ ] Continue indicator bobs after typing completes
  - [ ] Verify in editor: Run scene standalone, call `open()` with test resource from debugger

  **Commit**: YES
  - Message: `feat(dialogue): add DialogueBox script with typewriter effect`
  - Files: `ui/components/dialogue_box.gd`

---

- [ ] 4. Create DialogueManager Autoload

  **What to do**:
  - Create `scripts/autoloads/dialogue_manager.gd`
  - Register in `project.godot` as autoload singleton
  - State:
    ```gdscript
    var is_dialogue_active: bool = false
    var dialogue_box: Control  # Reference to UI
    var shown_dialogues: Dictionary = {}  # {dialogue_id: true}
    ```
  - Signals:
    ```gdscript
    signal dialogue_started
    signal dialogue_finished
    ```
  - Public API:
    ```gdscript
    func start_dialogue(resource: DialogueResource) -> void
    func close_dialogue() -> void
    func is_active() -> bool
    func has_shown(dialogue_id: String) -> bool
    func mark_shown(dialogue_id: String) -> void
    ```
  - Input handling:
    - Listen for "ui_accept" (Space/Enter) and "harvest" (E) to advance
    - Listen for "ui_cancel" (Escape) to close
    - Block input propagation when active
  - Integration:
    - Find DialogueBox in UI layer on ready
    - Connect to DialogueBox signals
  - Dialogue rejection:
    - If `is_dialogue_active`, reject new `start_dialogue()` calls

  **Must NOT do**:
  - No dialogue queuing (reject while active)
  - No save/load of shown_dialogues (per-session only)
  - No modification to other autoloads

  **Parallelizable**: NO (depends on 1, 3)

  **References**:

  **Pattern References**:
  - `scripts/autoloads/inventory.gd` - Autoload singleton pattern
  - `scripts/autoloads/game_state.gd` - State management autoload
  - `scripts/systems/interaction_manager.gd:77-98` - Input handling pattern with `set_input_as_handled()`

  **Configuration Reference**:
  - `project.godot` - Where to add autoload entry

  **Acceptance Criteria**:
  - [ ] File exists at `scripts/autoloads/dialogue_manager.gd`
  - [ ] Registered in project.godot under `[autoload]`
  - [ ] `DialogueManager.start_dialogue(resource)` works from any script
  - [ ] Pressing E/Space advances dialogue
  - [ ] Pressing Escape closes dialogue
  - [ ] `dialogue_started` and `dialogue_finished` signals emit correctly
  - [ ] Second `start_dialogue()` call while active is rejected
  - [ ] Verify: From world.gd `_ready()`, call `DialogueManager.start_dialogue(test_resource)` 

  **Commit**: YES
  - Message: `feat(dialogue): add DialogueManager autoload with input handling`
  - Files: `scripts/autoloads/dialogue_manager.gd`, `project.godot`

---

- [ ] 5. Integrate with World.gd Escape Chain

  **What to do**:
  - Modify `world.gd` (project root)
  - Add dialogue check as FIRST priority in `_close_any_open_ui()`:
    ```gdscript
    func _close_any_open_ui() -> bool:
        # Priority 0: Active dialogue (HIGHEST)
        if DialogueManager and DialogueManager.is_active():
            DialogueManager.close_dialogue()
            return true
        
        # Priority 1: Return held item (existing)
        # ... rest of existing code
    ```
  - Ensure DialogueManager input handling uses `set_input_as_handled()`
  - Player movement blocking:
    - Check `DialogueManager.is_active()` before processing movement
    - Option A: In player script, early return if dialogue active
    - Option B: DialogueManager emits signal that player listens to

  **Must NOT do**:
  - No restructuring of existing priority chain (only prepend)
  - No tree pausing
  - No modification to other systems beyond integration point

  **Parallelizable**: NO (depends on 4)

  **References**:

  **Pattern References**:
  - `world.gd:80-106` - Existing `_close_any_open_ui()` function (project root)
  - `world.gd` - Overall world script structure (project root)

  **API Reference**:
  - `DialogueManager.is_active()` - Check if dialogue is active
  - `DialogueManager.close_dialogue()` - Close active dialogue

  **Acceptance Criteria**:
  - [ ] `_close_any_open_ui()` checks dialogue FIRST
  - [ ] Pressing Escape during dialogue closes dialogue (not other UI)
  - [ ] Pressing Escape when no dialogue falls through to existing behavior
  - [ ] Player cannot move during active dialogue
  - [ ] Verify: Start game, trigger dialogue, press Escape → dialogue closes, nothing else opens
  - [ ] Verify: Start game, trigger dialogue, try to move → player stays still

  **Commit**: YES
  - Message: `feat(dialogue): integrate DialogueManager with world escape chain`
  - Files: `world.gd`

---

- [ ] 6. Add DialogueBox to UI Layer and Create Test Dialogue

  **What to do**:
  - Modify `ui/ui.tscn`:
    - Instance `dialogue_box.tscn` as child
    - Position at bottom-center of screen
    - Ensure visibility is `false` by default
  - Create test dialogue resource:
    - `resources/dialogues/test_dialogue.tres`
    - Speaker: "Narrator"
    - Lines: ["Welcome to the farm!", "Use tools to plant and harvest crops.", "Good luck!"]
    - dialogue_id: "tutorial_welcome"
  - Add debug trigger:
    - Temporary: In world.gd `_ready()` or via F1 key
    - Call `DialogueManager.start_dialogue(preload("res://resources/dialogues/test_dialogue.tres"))`

  **Must NOT do**:
  - No permanent debug triggers in final code (remove after testing)
  - No complex dialogue content

  **Parallelizable**: NO (depends on 5)

  **References**:

  **Pattern References**:
  - `ui/ui.tscn` - Existing UI structure with other panels

  **Acceptance Criteria**:
  - [ ] DialogueBox instanced in `ui/ui.tscn`
  - [ ] Test resource exists at `resources/dialogues/test_dialogue.tres`
  - [ ] Run game → Press F1 (or trigger) → Dialogue appears
  - [ ] Dialogue displays "Welcome to the farm!" with typewriter effect
  - [ ] Continue indicator appears after typing
  - [ ] Press E → Next line "Use tools..."
  - [ ] Press E → Next line "Good luck!"
  - [ ] Press E → Dialogue closes, `dialogue_finished` emits
  - [ ] Player movement blocked during entire sequence
  - [ ] Press Escape at any point → Dialogue closes immediately
  - [ ] Screenshots captured as evidence

  **Commit**: YES
  - Message: `feat(dialogue): add DialogueBox to UI and create test dialogue`
  - Files: `ui/ui.tscn`, `resources/dialogues/test_dialogue.tres`

---

- [ ] 7. Document Trigger Interface for NPCs/Buildings

  **What to do**:
  - Create `docs/dialogue-system.md` documentation
  - Content:
    - How to create DialogueResource files
    - How to trigger dialogue from any node
    - Example: NPC interaction pattern
    - Example: Building interaction pattern
    - Example: Event/cutscene trigger pattern
    - API reference for DialogueManager
    - Localization key usage
  - Include code snippets for:
    ```gdscript
    # From any interactive object:
    @export var dialogue: DialogueResource
    
    func interact() -> void:
        if dialogue and not DialogueManager.has_shown(dialogue.dialogue_id):
            DialogueManager.start_dialogue(dialogue)
    ```

  **Must NOT do**:
  - No actual NPC implementation
  - No over-documentation

  **Parallelizable**: NO (depends on 6)

  **References**:

  **Pattern References**:
  - `scripts/systems/interaction_manager.gd:138-145` - interact() interface pattern

  **Acceptance Criteria**:
  - [ ] Documentation file exists at `docs/dialogue-system.md`
  - [ ] Contains clear usage examples
  - [ ] Contains API reference
  - [ ] A developer reading the doc can integrate dialogue into a new NPC

  **Commit**: YES
  - Message: `docs(dialogue): add dialogue system usage documentation`
  - Files: `docs/dialogue-system.md`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(dialogue): add DialogueResource class` | `scripts/resources/dialogue_resource.gd` | Create .tres in editor |
| 2 | `feat(dialogue): create DialogueBox UI scene` | `ui/components/dialogue_box.tscn` | Open scene in editor |
| 3 | `feat(dialogue): add DialogueBox script with typewriter` | `ui/components/dialogue_box.gd` | Run scene standalone |
| 4 | `feat(dialogue): add DialogueManager autoload` | `scripts/autoloads/dialogue_manager.gd`, `project.godot` | Call from debug |
| 5 | `feat(dialogue): integrate with world escape chain` | `world.gd` | Test Escape priority |
| 6 | `feat(dialogue): add to UI and create test` | `ui/ui.tscn`, `resources/dialogues/test_dialogue.tres` | Full integration test |
| 7 | `docs(dialogue): add usage documentation` | `docs/dialogue-system.md` | Review doc |

---

## Success Criteria

### Verification Commands
```bash
# Run Godot project
godot --path . --editor  # Open editor
# OR
godot --path .  # Run game directly
```

### Final Checklist
- [ ] DialogueManager autoload registered and accessible globally
- [ ] DialogueBox displays with Sproutlands styling
- [ ] Typewriter effect works at readable speed
- [ ] Continue indicator animates after typing completes
- [ ] E/Space advances dialogue
- [ ] Escape closes dialogue (highest priority)
- [ ] Player movement blocked during dialogue
- [ ] Dialogue state tracking works (shown_dialogues)
- [ ] Test dialogue demonstrates full flow
- [ ] Documentation enables future NPC integration
- [ ] All "Must NOT Have" guardrails respected
