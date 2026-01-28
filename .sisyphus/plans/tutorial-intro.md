# Tutorial Intro Scene - "Opening Eyes" Cinematic

## Context

### Original Request
Create a tutorial scene where the player "opens their eyes" in the world with dialogue and player portrait. Player should be completely locked (can't build/interact/move) during the intro.

### Interview Summary
**Key Discussions**:
- Visual effect: Fade from black (classic cinematic)
- Player freeze: Yes, but need COMPLETE input lock (not just movement)
- Player portrait: Extract from Player_Idle.png sprite sheet
- Dialogue: Placeholder text for now (user will edit .tres file later)
- Scope: Just the intro, NO gameplay guidance after

**Research Findings**:
- Player sprite is 128x32px with 4 frames (32x32 each) - first frame suitable for portrait
- Dialogue system already supports portraits via DialogueResource
- Player movement already blocked (player.gd:15-18) but 4+ other systems accept input during dialogue
- world.gd already detects new worlds at lines 49-60

### Metis Review
**Identified Gaps** (addressed):
- Missed `inventory_panel.gd:106` input handler - added to blocklist
- Need to define fade duration (defaulting to 1.5s)
- Need to sequence: fade first, dialogue after fade completes
- Portrait may need size verification in DialogueBox

---

## Work Objectives

### Core Objective
Add a cinematic "opening eyes" intro sequence for new worlds: screen fades from black while all player input is blocked, then shows dialogue with player portrait.

### Concrete Deliverables
- `resources/ui/player_portrait.tres` - AtlasTexture of player face (32x32)
- `resources/dialogues/intro_awakening.tres` - DialogueResource with placeholder text
- Fade overlay system integrated into world.gd
- Input guards in 4 files to block all gameplay during dialogue

### Definition of Done
- [ ] New world: Screen starts black, fades to visible over ~1.5 seconds
- [ ] After fade: Dialogue appears with player portrait
- [ ] During dialogue: Player cannot move, build, interact, open menus, or use hotbar
- [ ] After dialogue: All controls restored
- [ ] Loaded games: No intro shown

### Must Have
- Fade from black effect on new world load
- Player portrait visible in dialogue box (bottom-left position)
- Complete input lock during intro (movement, building, menus, hotbar)
- Placeholder dialogue text that user can edit later

### Must NOT Have (Guardrails)
- Audio/sound effects
- Fancy animations (eyelid shape, blur, vignette)
- Tutorial guidance or gameplay hints after intro
- Modifications to DialogueManager autoload behavior
- Save file changes to persist "intro seen" state
- Modifications to pause_menu.gd (pause should still work)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (this is a Godot game, no unit tests)
- **User wants tests**: Manual-only
- **Framework**: N/A

### Manual QA Procedures
Each task includes detailed manual verification using Godot editor run.

---

## Task Flow

```
Task 0 (Input Guards - Phase 1)
      ↓
Task 1 (Verify guards with H-key test dialogue)
      ↓
Task 2 (Player portrait AtlasTexture) ──┬─→ Task 3 (DialogueResource)
                                         │
Task 4 (Fade overlay + integration) ←────┘
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 2, 3 | Independent asset creation (portrait + dialogue) |

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | 0 | Need guards in place before testing |
| 3 | 2 | Dialogue needs portrait texture reference |
| 4 | 0, 3 | Needs guards working + dialogue resource |

---

## TODOs

- [x] 0. Add input guards to block all gameplay during dialogue

  **What to do**:
  - Add early-return guard at the TOP of `_input()` or `_unhandled_input()` in each file:
    ```gdscript
    if DialogueManager and DialogueManager.is_active():
        return
    ```
  - Files to modify:
    1. `scripts/planting_system.gd` - line 125 (`_input` function)
    2. `ui/components/build_menu.gd` - line 23 (`_input` function)
    3. `ui/hotbar.gd` - line 72 (`_unhandled_input` function)
    4. `ui/components/inventory_panel.gd` - line 106 (`_input` function)

  **Must NOT do**:
  - Do NOT modify `scripts/autoloads/dialogue_manager.gd`
  - Do NOT add guards to `pause_menu.gd` (pause should work during dialogue)
  - Do NOT touch `world.gd` input yet (will handle in task 4)

  **Parallelizable**: NO (foundational task)

  **References**:
  - `scripts/player.gd:15-18` - Existing guard pattern to follow:
    ```gdscript
    if DialogueManager and DialogueManager.is_active():
        velocity = Vector2.ZERO
        move_and_slide()
        return
    ```
  - `scripts/planting_system.gd:125` - Target: add guard at start of `_input()`
  - `ui/components/build_menu.gd:23` - Target: add guard at start of `_input()`
  - `ui/hotbar.gd:72` - Target: add guard at start of `_unhandled_input()`
  - `ui/components/inventory_panel.gd:106` - Target: add guard at start of `_input()`

  **Acceptance Criteria**:
  - [ ] Guard added to `planting_system.gd:_input()` as first statement
  - [ ] Guard added to `build_menu.gd:_input()` as first statement
  - [ ] Guard added to `hotbar.gd:_unhandled_input()` as first statement
  - [ ] Guard added to `inventory_panel.gd:_input()` as first statement
  - [ ] No syntax errors when opening project in Godot

  **Commit**: YES
  - Message: `feat(dialogue): block all input during active dialogue`
  - Files: `scripts/planting_system.gd`, `ui/components/build_menu.gd`, `ui/hotbar.gd`, `ui/components/inventory_panel.gd`
  - Pre-commit: Open Godot project, verify no errors in Output panel

---

- [x] 1. Verify input guards work with existing test dialogue

  **What to do**:
  - Run the game from Godot editor
  - Press H key to trigger existing test dialogue
  - While dialogue is visible, attempt ALL blocked inputs
  - Verify each is blocked

  **Must NOT do**:
  - Do NOT modify any code in this task (verification only)

  **Parallelizable**: NO (depends on task 0)

  **References**:
  - `world.gd:95-98` - H key triggers test dialogue:
    ```gdscript
    if event is InputEventKey and event.pressed and event.keycode == KEY_H:
        var res = load("res://resources/dialogues/test_dialogue.tres")
        if res and DialogueManager:
            DialogueManager.start_dialogue(res)
    ```
  - `resources/dialogues/test_dialogue.tres` - Existing test dialogue resource

  **Acceptance Criteria**:
  - [ ] Run game, press H → dialogue appears
  - [ ] While dialogue visible: Press WASD → player does NOT move
  - [ ] While dialogue visible: Press B → build menu does NOT open
  - [ ] While dialogue visible: Press 1-5 → hotbar does NOT change selection
  - [ ] While dialogue visible: Press I → inventory does NOT open
  - [ ] While dialogue visible: Press F → delete mode does NOT activate
  - [ ] Click or press Enter/Space → dialogue advances
  - [ ] After dialogue ends → all controls work normally

  **Commit**: NO (verification only)

---

- [x] 2. Create player portrait AtlasTexture
- [x] 3. Create intro dialogue resource
  - Create a new AtlasTexture resource file at `resources/ui/player_portrait.tres`
  - Set atlas to `res://assets/player/Player_Idle.png`
  - Set region to first frame: `Rect2(0, 0, 32, 32)`
  - Verify it looks good in Godot inspector

  **Must NOT do**:
  - Do NOT create a new image file (use AtlasTexture)
  - Do NOT modify the Player_Idle.png source

  **Parallelizable**: YES (with task 3 prep)

  **References**:
  - `assets/player/Player_Idle.png` - Source sprite sheet (128x32px, 4 frames)
  - `ui/components/dialogue_box.tscn:14-16` - Existing portrait AtlasTexture pattern:
    ```
    [sub_resource type="AtlasTexture" id="AtlasTexture_portrait"]
    atlas = ExtResource("6_teemo")
    region = Rect2(5, 258, 23, 30)
    ```

  **Acceptance Criteria**:
  - [ ] File exists: `resources/ui/player_portrait.tres`
  - [ ] In Godot Inspector: Shows player face cropped correctly (32x32)
  - [ ] No black borders or cut-off pixels

  **Commit**: YES (groups with task 3)
  - Message: `feat(tutorial): add player portrait and intro dialogue resources`
  - Files: `resources/ui/player_portrait.tres`, `resources/dialogues/intro_awakening.tres`

---

- [ ] 3. Create intro dialogue resource

  **What to do**:
  - Create new DialogueResource at `resources/dialogues/intro_awakening.tres`
  - Set properties:
    - `dialogue_id`: `"intro_awakening"`
    - `speaker_name`: `"???"` (mysterious, player doesn't know their name yet)
    - `portrait`: Load the portrait from task 2
    - `lines`: Placeholder array with 2-3 lines, e.g.:
      ```
      "..."
      "Where... am I?"
      "I should look around."
      ```

  **Must NOT do**:
  - Do NOT add translation_keys (user will handle later)
  - Do NOT use more than 3 placeholder lines

  **Parallelizable**: YES (with task 2, but depends on portrait file existing)

  **References**:
  - `scripts/resources/dialogue_resource.gd` - Resource class definition
  - `resources/dialogues/test_dialogue.tres` - Example format:
    ```
    [gd_resource type="Resource" script_class="DialogueResource" load_steps=2 format=3]
    [ext_resource type="Script" path="res://scripts/resources/dialogue_resource.gd" id="1_script"]
    [resource]
    script = ExtResource("1_script")
    dialogue_id = "tutorial_welcome"
    speaker_name = "Narrator"
    lines = Array[String](["Welcome to the farm!", ...])
    ```
  - `resources/ui/player_portrait.tres` - Portrait from task 2

  **Acceptance Criteria**:
  - [ ] File exists: `resources/dialogues/intro_awakening.tres`
  - [ ] In Godot Inspector: Shows correct properties
  - [ ] `dialogue_id` is "intro_awakening"
  - [ ] `speaker_name` is "???"
  - [ ] `portrait` references player_portrait.tres
  - [ ] `lines` has 2-3 placeholder strings

  **Commit**: YES (groups with task 2)
  - Message: `feat(tutorial): add player portrait and intro dialogue resources`
  - Files: `resources/ui/player_portrait.tres`, `resources/dialogues/intro_awakening.tres`

---

- [x] 4. Add fade overlay and trigger intro on new world

  **What to do**:
  - Add a ColorRect node to `ui/ui.tscn` for the fade overlay:
    - Name: `IntroFadeOverlay`
    - Anchors: Full rect (cover entire screen)
    - Color: Black (0, 0, 0, 1)
    - Mouse filter: Ignore
    - Visible: false (will be enabled by code)
    - Z-index or node order: Should be ABOVE other UI but BELOW DialogueBox
  
  - Modify `world.gd` to trigger intro sequence:
    - Add a constant for intro dialogue path
    - In `_ready()`, after `call_deferred("_spawn_starter_resources")`, add `call_deferred("_play_intro")` for new worlds
    - Create `_play_intro()` function that:
      1. Gets the fade overlay from UI
      2. Sets overlay visible and modulate.a = 1.0 (fully black)
      3. Creates tween to fade overlay alpha from 1.0 to 0.0 over 1.5 seconds
      4. On tween complete, starts the intro dialogue
      5. Hides overlay after dialogue completes (connect to dialogue_finished signal)

  **Must NOT do**:
  - Do NOT add audio
  - Do NOT modify DialogueBox or DialogueManager
  - Do NOT make fade duration configurable (hardcode 1.5s)
  - Do NOT add any gameplay hints in dialogue

  **Parallelizable**: NO (final integration task)

  **References**:
  - `ui/ui.tscn` - UI scene to add overlay to
  - `world.gd:45-60` - Current `_ready()` function with new world detection
  - `world.gd:59-60` - Where to add intro trigger:
    ```gdscript
    if is_new_world:
        call_deferred("_spawn_starter_resources")
        # ADD: call_deferred("_play_intro")
    ```
  - `scripts/autoloads/dialogue_manager.gd:4-5` - Signals to use:
    ```gdscript
    signal dialogue_started
    signal dialogue_finished
    ```
  - `ui/components/dialogue_box.gd:64-66` - Existing tween animation pattern:
    ```gdscript
    var tween = create_tween()
    tween.parallel().tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
    ```

  **Acceptance Criteria**:
  - [ ] IntroFadeOverlay node exists in ui/ui.tscn
  - [ ] Run game → Create new world → Screen starts BLACK
  - [ ] Screen fades to visible over ~1.5 seconds
  - [ ] After fade completes → Dialogue appears with player portrait
  - [ ] Player portrait visible in bottom-left of dialogue box
  - [ ] Speaker name shows "???"
  - [ ] During entire sequence: Player cannot move/build/interact
  - [ ] After advancing through all dialogue lines → Controls restored
  - [ ] Load existing saved world → NO intro (game loads normally)

  **Commit**: YES
  - Message: `feat(tutorial): add opening eyes intro sequence for new worlds`
  - Files: `ui/ui.tscn`, `world.gd`
  - Pre-commit: Full manual test of new world intro

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0 | `feat(dialogue): block all input during active dialogue` | planting_system.gd, build_menu.gd, hotbar.gd, inventory_panel.gd | H-key test |
| 2+3 | `feat(tutorial): add player portrait and intro dialogue resources` | player_portrait.tres, intro_awakening.tres | Inspector check |
| 4 | `feat(tutorial): add opening eyes intro sequence for new worlds` | ui.tscn, world.gd | Full new world test |

---

## Success Criteria

### Verification Commands
```bash
# Open Godot project
godot --path /Users/eugene/Documents/Github\ Projects/LGD --editor
```

### Final Checklist
- [ ] New world: Fade from black works (1.5s duration)
- [ ] Dialogue appears after fade with player portrait
- [ ] Speaker name is "???"
- [ ] Placeholder dialogue has 2-3 lines
- [ ] ALL input blocked during intro (movement, B, I, F, 1-5, click on world)
- [ ] Controls fully restored after dialogue ends
- [ ] Loading saved game: No intro shown
- [ ] No audio added
- [ ] No gameplay hints added
- [ ] Existing H-key test dialogue still works
