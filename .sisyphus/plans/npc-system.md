# NPC System with Dialogue & Functional Options

## TL;DR

> **Quick Summary**: Create a reusable NPC system with wandering behavior, dialogue for story progression, and action menus. Includes Glider as the first NPC example.
> 
> **Deliverables**:
> - NPC base scene with StateMachine (Idle, Wander, Talk states)
> - NavigationRegion2D setup for pathfinding
> - Extended dialogue box with action buttons
> - Story flag system for progression
> - Glider NPC example with Talk action
> 
> **Estimated Effort**: Medium (6-8 hours)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (Navigation) → Task 2 (NPC Base) → Task 5 (Glider) → Task 7 (Integration)

---

## Context

### Original Request
Create an NPC system with dialogue to progress the story and NPCs with functional options like researching technologies. System should be reusable with Glider as an example.

### Interview Summary
**Key Discussions**:
- **Interaction flow**: Context-dependent (first meeting = dialogue, subsequent = menu)
- **Research system**: Deferred to Phase 2 - this plan focuses on core NPC system
- **NPC movement**: Random wander within Area2D boundary using NavigationAgent2D
- **Menu UI**: Extend existing dialogue box with action buttons
- **Story progression**: Manual flags (not quest-based)
- **Verification**: Manual QA (no test infrastructure)

**Research Findings**:
- Existing StateMachine + State pattern from RatAssistant is clean and reusable
- DialogueManager tracks shown dialogues via `shown_dialogues` dict - can use for first-meeting detection
- InteractionComponent pattern opens menus on interaction - NPCs can use similar approach
- No NavigationRegion2D exists - needs to be added to world.tscn

### Self-Gap-Analysis
**Identified Gaps** (addressed in plan):
- NavigationRegion2D missing from world - added as Task 1
- Need clear NPC-player interaction trigger - using InteractionComponent pattern
- Story flags need storage - using existing GameState autoload
- Wander boundary needs Area2D setup - included in NPC scene structure

---

## Work Objectives

### Core Objective
Build a reusable NPC system where NPCs can wander, be interacted with for dialogue/actions, and track story progression via flags.

### Concrete Deliverables
- `scripts/npc/npc_base.gd` - Base NPC controller (CharacterBody2D)
- `scripts/npc/states/npc_idle_state.gd` - Standing still state
- `scripts/npc/states/npc_wander_state.gd` - Random movement state
- `scripts/npc/states/npc_talk_state.gd` - Facing player during dialogue
- `scenes/npc_base.tscn` - Reusable NPC scene with StateMachine
- `scripts/resources/npc_action.gd` - Resource for NPC action buttons
- Updated `ui/components/dialogue_box.gd` - Action button support
- `scenes/npcs/glider.tscn` - Glider NPC instance
- NavigationRegion2D added to world.tscn

### Definition of Done
- [ ] Glider NPC wanders within defined Area2D boundary
- [ ] Player can interact with Glider (harvest key)
- [ ] First interaction shows dialogue, subsequent shows action menu
- [ ] Story flags persist across sessions
- [ ] NPC pathfinds around obstacles

### Must Have
- StateMachine architecture matching RatAssistant pattern
- NavigationAgent2D for obstacle avoidance
- First-meeting detection using DialogueManager.has_shown()
- Action buttons in dialogue box after dialogue ends
- Save/load support for story flags

### Must NOT Have (Guardrails)
- NO research/technology system (Phase 2)
- NO quest system
- NO NPC schedules or needs
- NO animated sprites beyond idle (single frame OK)
- NO complex branching dialogue (linear only)
- NO new autoloads (use existing GameState for flags)
- NO modification to RatAssistant code

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: Manual-only
- **Framework**: none

### Manual QA Procedures

Each TODO includes verification steps the agent executes via Godot tools:

**For Scene/Script changes:**
```bash
# Agent runs project and captures output
godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
# Observe debug output for errors
godot_get_debug_output()
```

**For UI changes** (using playwright skill if available, otherwise manual):
```
# Agent runs game, navigates to NPC, interacts
1. Run project
2. Move player to Glider NPC location
3. Press harvest key near NPC
4. Verify dialogue appears
5. Advance through dialogue
6. Verify action buttons appear
7. Screenshot evidence
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Add NavigationRegion2D to world [no dependencies]
├── Task 3: Create NPC action resource [no dependencies]
└── Task 4: Extend dialogue box with actions [no dependencies]

Wave 2 (After Wave 1):
├── Task 2: Create NPC base scene + states [depends: 1]
└── Task 6: Add story flags to GameState [no dependencies - can parallel]

Wave 3 (After Wave 2):
├── Task 5: Create Glider NPC [depends: 2, 3, 4]
└── Task 7: Integration & testing [depends: 5, 6]

Critical Path: Task 1 → Task 2 → Task 5 → Task 7
Parallel Speedup: ~40% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2 | 3, 4 |
| 2 | 1 | 5 | 6 |
| 3 | None | 5 | 1, 4 |
| 4 | None | 5 | 1, 3 |
| 5 | 2, 3, 4 | 7 | 6 |
| 6 | None | 7 | 1, 2, 3, 4, 5 |
| 7 | 5, 6 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 3, 4 | 3x delegate_task(category="quick", run_in_background=true) |
| 2 | 2, 6 | 2x delegate_task(category="unspecified-low", run_in_background=true) |
| 3 | 5, 7 | sequential - 5 then 7 |

---

## TODOs

- [ ] 1. Add NavigationRegion2D to World Scene

  **What to do**:
  - Add NavigationRegion2D as child of World node in world.tscn
  - Create NavigationPolygon covering the playable area (use TileMap bounds)
  - Configure navigation layers if needed
  - Ensure polygon excludes building footprints (or rely on dynamic obstacles)

  **Must NOT do**:
  - Don't add navigation to individual tiles (use single region)
  - Don't modify PlantingSystem or TileMap scripts

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single scene modification, straightforward Godot task
  - **Skills**: [`git-master`]
    - `git-master`: May need to commit navigation changes separately
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not a UI task
    - `playwright`: Not browser-related

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 3, 4)
  - **Blocks**: Task 2
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `world.tscn` - World scene structure, PlantingSystem child location

  **API/Type References**:
  - Godot NavigationRegion2D docs - How to create navigation mesh

  **Documentation References**:
  - Godot 4 Navigation Overview - NavigationPolygon setup

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  # Wait 5s for world to load
  godot_get_debug_output()
  # Assert: No navigation-related errors in output
  ```

  **Evidence to Capture:**
  - [ ] Terminal output showing no navigation errors
  - [ ] Screenshot of world.tscn scene tree showing NavigationRegion2D

  **Commit**: YES
  - Message: `feat(world): add NavigationRegion2D for NPC pathfinding`
  - Files: `world.tscn`
  - Pre-commit: Run project, verify no errors

---

- [ ] 2. Create NPC Base Scene with StateMachine

  **What to do**:
  - Create `scripts/npc/npc_base.gd` extending CharacterBody2D
    - Properties: move_speed, wander_radius, home_position
    - NavigationAgent2D reference
    - Interaction detection (use harvest key like buildings)
    - first_meeting detection using DialogueManager.has_shown()
    - API: interact() to trigger dialogue or menu
  - Create `scripts/npc/states/npc_idle_state.gd`
    - Timer to transition to wander
    - Face player if nearby
  - Create `scripts/npc/states/npc_wander_state.gd`
    - Pick random point within wander Area2D
    - Navigate using NavigationAgent2D
    - Return to idle when reached
  - Create `scripts/npc/states/npc_talk_state.gd`
    - Entered during dialogue
    - Face player
    - Listen for dialogue_finished to exit
  - Create `scenes/npc_base.tscn`
    - CharacterBody2D root with CollisionShape2D
    - Sprite2D for visuals
    - NavigationAgent2D
    - StateMachine with Idle, Wander, Talk states
    - Area2D for wander boundary (configurable per instance)
    - InteractionComponent for menu opening

  **Must NOT do**:
  - Don't copy RatAssistant code directly (reference pattern only)
  - Don't add animated sprite logic (simple Sprite2D)
  - Don't add research/action-specific code (that's for NPC instances)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Multiple files but follows clear existing pattern
  - **Skills**: []
    - No special skills needed - follows existing StateMachine pattern
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not UI work

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 6)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `scripts/rat_assistant.gd:1-77` - CharacterBody2D structure, StateMachine integration, task assignment pattern
  - `scripts/components/StateMachine.gd:1-46` - State machine implementation
  - `scripts/rat/states/rat_idle_state.gd:1-47` - Idle state pattern with timer
  - `scripts/rat/states/rat_move_to_source_state.gd` - Movement state pattern (if exists)
  - `scripts/components/InteractionComponent.gd:1-63` - How buildings handle interaction

  **API/Type References**:
  - `scripts/components/State.gd` - Base State class interface
  - `scripts/autoloads/dialogue_manager.gd:45-46` - has_shown() API

  **External References**:
  - Godot NavigationAgent2D docs - target_position, velocity_computed signal

  **WHY Each Reference Matters**:
  - RatAssistant shows how to structure CharacterBody2D with StateMachine child
  - StateMachine.gd is the exact component to reuse
  - rat_idle_state shows timer-based transitions
  - InteractionComponent shows how to open menus on interact

  **Acceptance Criteria**:

  ```bash
  # Agent verifies files created:
  ls scripts/npc/npc_base.gd scripts/npc/states/*.gd scenes/npc_base.tscn
  # Assert: All files exist
  
  # Agent runs project to check for parse errors:
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No GDScript parse errors
  ```

  **Evidence to Capture:**
  - [ ] File listing showing all NPC scripts created
  - [ ] Debug output with no parse errors

  **Commit**: YES
  - Message: `feat(npc): add NPC base scene with StateMachine, Idle/Wander/Talk states`
  - Files: `scripts/npc/*.gd`, `scripts/npc/states/*.gd`, `scenes/npc_base.tscn`
  - Pre-commit: Run project, verify no errors

---

- [ ] 3. Create NPC Action Resource

  **What to do**:
  - Create `scripts/resources/npc_action.gd` extending Resource
    - `action_id: String` - unique ID (e.g., "talk", "research")
    - `display_name: String` - button label (e.g., "Talk", "Research Lab")
    - `icon: Texture2D` - optional icon for button
    - `requires_flag: String` - story flag required to show action (empty = always show)
    - `disabled_if_flag: String` - story flag that disables/hides action
  - This resource will be used by NPCs to define their available actions

  **Must NOT do**:
  - Don't implement action execution logic (that's in dialogue box/NPC)
  - Don't create research-specific actions yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single resource file, very simple
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All skills - too simple

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 4)
  - **Blocks**: Task 5
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `scripts/resources/dialogue_resource.gd:1-22` - Resource class pattern with @export
  - `scripts/resources/buildable_item.gd` - Another resource example
  - `scripts/resources/inventory_item.gd` - Resource with icon

  **WHY Each Reference Matters**:
  - dialogue_resource shows how to create simple data resources
  - Other resources show @export patterns used in project

  **Acceptance Criteria**:

  ```bash
  # Agent verifies:
  ls scripts/resources/npc_action.gd
  # Assert: File exists
  
  # Check resource is valid by loading in project
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No errors about npc_action.gd
  ```

  **Evidence to Capture:**
  - [ ] File exists confirmation
  - [ ] No parse errors in debug output

  **Commit**: YES (group with Task 4)
  - Message: `feat(npc): add NPCAction resource and dialogue box action buttons`
  - Files: `scripts/resources/npc_action.gd`

---

- [ ] 4. Extend Dialogue Box with Action Buttons

  **What to do**:
  - Modify `ui/components/dialogue_box.gd`:
    - Add `signal action_selected(action_id: String)`
    - Add `var available_actions: Array[Resource] = []` (NPCAction resources)
    - Add action button container (HBoxContainer below dialogue text)
    - Add `func show_actions(actions: Array)` - displays action buttons
    - After dialogue completes (or if no dialogue), show action buttons
    - Each button emits action_selected with action_id
    - Action buttons should be styled consistently with game UI
  - Modify `ui/components/dialogue_box.tscn`:
    - Add ActionButtonContainer (HBoxContainer) below DialogueLabel
    - Initially hidden, shown when actions available

  **Must NOT do**:
  - Don't break existing dialogue functionality
  - Don't implement action handling (NPC handles that via signal)
  - Don't add complex styling (simple buttons are fine)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Extending existing UI with straightforward changes
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: UI modification, button layout
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not browser testing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 5
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `ui/components/dialogue_box.gd:1-136` - Full file, understand current structure
  - `ui/components/dialogue_box.tscn` - Scene structure to modify
  - `ui/components/build_menu_slot.gd` - Button click handling pattern
  - `ui/processor_menu.gd` - Another menu with buttons pattern

  **API/Type References**:
  - `scripts/resources/npc_action.gd` - Resource being used (from Task 3)

  **WHY Each Reference Matters**:
  - dialogue_box.gd is the file being modified - need full context
  - build_menu_slot shows how other UI buttons handle clicks
  - processor_menu shows menu patterns in the codebase

  **Acceptance Criteria**:

  ```bash
  # Agent runs project:
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  # Press H to trigger test dialogue
  godot_get_debug_output()
  # Assert: No errors, dialogue still works
  ```

  ```
  # Manual verification in game:
  1. Run project
  2. Press H (test dialogue hotkey from world.gd:137-140)
  3. Advance through dialogue
  4. Verify no visual regressions
  ```

  **Evidence to Capture:**
  - [ ] Debug output showing no errors after modification
  - [ ] Dialogue still opens and advances correctly

  **Commit**: YES (group with Task 3)
  - Message: `feat(npc): add NPCAction resource and dialogue box action buttons`
  - Files: `ui/components/dialogue_box.gd`, `ui/components/dialogue_box.tscn`

---

- [ ] 5. Create Glider NPC

  **What to do**:
  - Create `scenes/npcs/glider.tscn` inheriting from `scenes/npc_base.tscn`
    - Set Sprite2D texture to `res://assets/characters/Glider.png`
    - Create DialogueResource at `resources/dialogues/glider_intro.tres`
      - dialogue_id: "glider_intro"
      - speaker_name: "Glider"
      - portrait: Glider.png (or cropped version)
      - lines: ["Hello there!", "I'm Glider. Nice to meet you!", "Let me know if you need anything."]
    - Create NPCAction resource at `resources/npc_actions/glider_talk.tres`
      - action_id: "talk"
      - display_name: "Talk"
    - Configure Glider with:
      - intro_dialogue: glider_intro.tres
      - actions: [glider_talk.tres]
    - Add wander Area2D sized appropriately (e.g., 128x128)
  - Create `scripts/npcs/glider.gd` extending npc_base.gd
    - Override action handling for "talk" action
    - Different dialogues based on story flags (if needed later)

  **Must NOT do**:
  - Don't add research action (Phase 2)
  - Don't add complex dialogue branching
  - Don't animate sprite

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Multiple resources and scene configuration
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not UI-focused

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential with Task 7)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 2, 3, 4

  **References**:

  **Pattern References**:
  - `scenes/npc_base.tscn` - Base scene to inherit from (from Task 2)
  - `scripts/npc/npc_base.gd` - Base class to extend (from Task 2)
  - `resources/dialogues/intro_awakening.tres` - Example dialogue resource

  **API/Type References**:
  - `scripts/resources/dialogue_resource.gd` - DialogueResource structure
  - `scripts/resources/npc_action.gd` - NPCAction structure (from Task 3)

  **External References**:
  - `assets/characters/Glider.png` - Confirmed exists via grep earlier

  **WHY Each Reference Matters**:
  - npc_base.tscn is the scene to inherit from
  - intro_awakening.tres shows how dialogue resources are structured in this project
  - Glider.png is the required sprite asset

  **Acceptance Criteria**:

  ```bash
  # Verify files created:
  ls scenes/npcs/glider.tscn scripts/npcs/glider.gd resources/dialogues/glider_intro.tres resources/npc_actions/glider_talk.tres
  # Assert: All files exist
  
  # Run project and check for errors:
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No parse errors or missing resource errors
  ```

  **Evidence to Capture:**
  - [ ] All Glider-related files exist
  - [ ] No errors when loading Glider scene

  **Commit**: YES
  - Message: `feat(npc): create Glider NPC with intro dialogue and Talk action`
  - Files: `scenes/npcs/glider.tscn`, `scripts/npcs/glider.gd`, `resources/dialogues/glider_intro.tres`, `resources/npc_actions/glider_talk.tres`

---

- [ ] 6. Add Story Flags to GameState

  **What to do**:
  - Modify `scripts/autoloads/game_state.gd`:
    - Add `var story_flags: Dictionary = {}` to store progression flags
    - Add `func set_flag(flag_name: String, value: bool = true) -> void`
    - Add `func get_flag(flag_name: String) -> bool`
    - Add `func has_flag(flag_name: String) -> bool`
    - Include story_flags in save/load data
  - Ensure flags persist when saving world

  **Must NOT do**:
  - Don't modify SaveManager structure
  - Don't add quest-related logic
  - Don't add UI for flags

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple dictionary addition to existing autoload
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All - too simple

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 2) or even Wave 1
  - **Blocks**: Task 7
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `scripts/autoloads/game_state.gd` - File being modified
  - `scripts/autoloads/save_manager.gd` - How save/load works
  - `scripts/autoloads/dialogue_manager.gd:9,45-49` - shown_dialogues pattern (similar to flags)

  **WHY Each Reference Matters**:
  - game_state.gd is where flags will live
  - save_manager shows how to integrate with persistence
  - dialogue_manager.shown_dialogues is exact same pattern we're implementing

  **Acceptance Criteria**:

  ```bash
  # Verify API exists by checking file content:
  grep -c "story_flags" scripts/autoloads/game_state.gd
  # Assert: Returns > 0
  
  grep -c "set_flag\|get_flag\|has_flag" scripts/autoloads/game_state.gd
  # Assert: Returns >= 3 (all three functions)
  
  # Run project to verify no errors:
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No parse errors
  ```

  **Evidence to Capture:**
  - [ ] grep output showing story_flags and flag functions exist
  - [ ] No runtime errors

  **Commit**: YES
  - Message: `feat(game-state): add story flags for progression tracking`
  - Files: `scripts/autoloads/game_state.gd`

---

- [ ] 7. Integration: Place Glider in World and Test

  **What to do**:
  - Add Glider instance to world.tscn
    - Position near player start (visible but not blocking)
    - Configure wander Area2D boundary
  - Test complete flow:
    - Player approaches Glider
    - Player presses harvest key
    - First time: Dialogue plays, then action buttons appear
    - Player selects "Talk"
    - Dialogue plays again
    - Second interaction: Action menu appears directly
  - Verify pathfinding works (Glider navigates around obstacles)
  - Verify flags persist after save/load

  **Must NOT do**:
  - Don't add multiple NPCs (just Glider for now)
  - Don't add spawn/despawn logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Integration testing, scene modification
  - **Skills**: [`playwright`]
    - `playwright`: Could help with visual verification if browser-based testing available
  - **Skills Evaluated but Omitted**:
    - `git-master`: Will commit as final task

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final task)
  - **Blocks**: None (final)
  - **Blocked By**: Tasks 5, 6

  **References**:

  **Pattern References**:
  - `world.tscn` - World scene to modify
  - `world.gd:60-62` - How starter resources are spawned (reference pattern)
  - `scenes/npcs/glider.tscn` - Glider scene to instantiate (from Task 5)

  **WHY Each Reference Matters**:
  - world.tscn is where Glider will be placed
  - world.gd shows spawn patterns if dynamic spawn is preferred

  **Acceptance Criteria**:

  ```
  # Manual QA Flow (Agent runs game and tests):
  1. godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  2. Locate Glider NPC in world
  3. Verify Glider is wandering (moving randomly)
  4. Approach Glider (within interaction range)
  5. Press harvest key
  6. Verify: Dialogue appears with Glider portrait
  7. Advance through all dialogue lines
  8. Verify: Action buttons appear ("Talk")
  9. Click "Talk" button
  10. Verify: Dialogue plays again
  11. Close dialogue
  12. Interact with Glider again
  13. Verify: Action menu appears directly (no dialogue first)
  14. Save game (ESC → Save or auto-save)
  15. Reload game
  16. Verify: Glider still knows player has met them (flag persisted)
  ```

  **Evidence to Capture:**
  - [ ] Screenshot of Glider in world
  - [ ] Screenshot of dialogue with Glider
  - [ ] Screenshot of action buttons
  - [ ] Debug output showing flag persistence

  **Commit**: YES (final commit)
  - Message: `feat(world): integrate Glider NPC, complete NPC system v1`
  - Files: `world.tscn`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(world): add NavigationRegion2D for NPC pathfinding` | world.tscn | Run project |
| 2 | `feat(npc): add NPC base scene with StateMachine, Idle/Wander/Talk states` | scripts/npc/*, scenes/npc_base.tscn | Run project |
| 3+4 | `feat(npc): add NPCAction resource and dialogue box action buttons` | scripts/resources/npc_action.gd, ui/components/dialogue_box.* | Run project, test H key |
| 5 | `feat(npc): create Glider NPC with intro dialogue and Talk action` | scenes/npcs/glider.tscn, scripts/npcs/glider.gd, resources/* | Run project |
| 6 | `feat(game-state): add story flags for progression tracking` | scripts/autoloads/game_state.gd | Run project |
| 7 | `feat(world): integrate Glider NPC, complete NPC system v1` | world.tscn | Full QA flow |

---

## Success Criteria

### Verification Commands
```bash
# All NPC system files exist:
ls scripts/npc/npc_base.gd scripts/npc/states/*.gd scenes/npc_base.tscn scenes/npcs/glider.tscn

# Project runs without errors:
godot_run_project # No console errors
```

### Final Checklist
- [ ] Glider NPC visible and wandering in world
- [ ] First interaction triggers dialogue
- [ ] Subsequent interactions show action menu directly
- [ ] "Talk" action works
- [ ] Story flags persist across save/load
- [ ] No modifications to RatAssistant code
- [ ] No research system implemented (saved for Phase 2)
