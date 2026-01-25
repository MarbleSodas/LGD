# Mushroom House & Rat Fixes

## Context

### Original Request
> Could you make sure that items that the rats are holding don't disappear and modify the styling of the mushroom house so that there is no offset with the mushroom house when placed and the rat only appears when working and hides behind the mushroom house and is not visible when the rat is idle and returned to the house?

### Interview Summary
**Key Discussions**:
- Items disappear because `rat_return_home_state.gd` calls `inventory.clear()` on enter
- User confirmed: Keep items in inventory, do not clear on return home
- Mushroom house offset: Scene sprite has -16 Y offset but preview doesn't match
- User confirmed: Remove the sprite offset from scene (not adjust preview)
- Rat visibility: Should be hidden when idle at home, visible when working
- User confirmed: Instant hide/show transition (no fade)

**Research Findings**:
- Root cause of item loss: `rat_return_home_state.gd` line 10 calls `rat.inventory.clear()`
- Current scene structure: Sprite2D offset=(0,-16), CollisionShape2D position=(0,-4)
- Rat visuals controlled by `RatVisuals` class with `body_sprite`, `held_item_sprite`, `count_label`
- Idle state detection available in `rat_idle_state.gd`, knows `home_building` reference

### Self-Review Gap Analysis
**Addressed**:
- Edge case: What if rat becomes visible mid-movement? Handled by showing on task assignment.
- Edge case: Save/load with hidden rat? Visibility is runtime-only, not persisted - safe.
- Guardrail: Don't touch deposit logic, only return home state

---

## Work Objectives

### Core Objective
Fix three bugs related to mushroom house placement and rat assistant behavior so that items persist, the house places without visual offset, and the rat hides when idle at home.

### Concrete Deliverables
- `scripts/rat/states/rat_return_home_state.gd` - Inventory no longer cleared
- `scenes/mushroom_house.tscn` - Sprite offset removed, collision adjusted
- `scripts/rat/rat_visuals.gd` - Visibility toggle method added
- `scripts/rat/states/rat_idle_state.gd` - Hides rat when at home
- `scripts/rat_assistant.gd` - Shows rat when task assigned

### Definition of Done
- [ ] Items held by rat persist when returning home (not cleared)
- [ ] Mushroom house preview matches placed position (no offset jump)
- [ ] Rat is invisible when idle at home position
- [ ] Rat becomes visible immediately when assigned a task
- [ ] Rat becomes visible when leaving idle state for any reason

### Must Have
- Inventory persists across return-home cycles
- No visual offset on mushroom house placement
- Rat visibility toggle based on working/idle-at-home state

### Must NOT Have (Guardrails)
- DO NOT modify deposit behavior or deposit state logic
- DO NOT modify harvest behavior
- DO NOT add fade/animation to visibility (user chose instant)
- DO NOT modify item pickup/drop logic
- DO NOT touch save/load logic for visibility (runtime only)
- DO NOT change the FRONT_DOOR_OFFSET or rest_position logic

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: N/A (no infrastructure)
- **Framework**: None
- **QA approach**: Manual verification using Godot editor and game runtime

---

## Task Flow

```
Task 1 (Item Fix) → Independent
Task 2 (Offset Fix) → Independent  
Task 3 (Visibility) → Depends on understanding Task 2 rest position
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1, 2 | Independent fixes, different files |

| Task | Depends On | Reason |
|------|------------|--------|
| 3 | None | Can be done after 1 and 2, but not dependent |

---

## TODOs

- [ ] 1. Fix item preservation in return home state

  **What to do**:
  - Open `scripts/rat/states/rat_return_home_state.gd`
  - In the `enter()` function (lines 6-11), remove or comment out:
    - Line 10: `rat.inventory.clear()`
    - Line 11: `if rat.visuals: rat.visuals.update_held_item_visual()`
  - The rat should keep its items when returning home

  **Must NOT do**:
  - Do NOT modify the physics_update or movement logic
  - Do NOT add any deposit logic here

  **Parallelizable**: YES (with task 2)

  **References**:

  **Pattern References**:
  - `scripts/rat/states/rat_idle_state.gd` - Shows state structure pattern (enter, update methods)
  - `scripts/rat/rat_inventory.gd` - Inventory API reference (clear, has_items methods)

  **Code to Modify**:
  - `scripts/rat/states/rat_return_home_state.gd:6-11` - The enter() function containing the bug

  **Acceptance Criteria**:

  **Manual Execution Verification**:
  - [ ] Run the game with `godot-mcp_run_project`
  - [ ] Place a mushroom house and assign harvest sources
  - [ ] Wait for rat to collect items and return home
  - [ ] Verify: Rat still shows held item sprite after returning home
  - [ ] Verify: Rat uses held items on next harvest/deposit cycle
  - [ ] Evidence: Screenshot of rat at home with visible held item

  **Commit**: YES
  - Message: `fix(rat): preserve inventory when returning home`
  - Files: `scripts/rat/states/rat_return_home_state.gd`

---

- [ ] 2. Remove mushroom house sprite offset and adjust collision

  **What to do**:
  - Open `scenes/mushroom_house.tscn`
  - Modify `Sprite2D` node: Change `offset` from `Vector2(0, -16)` to `Vector2(0, 0)`
  - Modify `StaticBody2D/CollisionShape2D` node: Change `position` from `Vector2(0, -4)` to `Vector2(0, 12)` 
    - Rationale: Original sprite center was at Y=0, offset moved visual up 16px
    - Collision was at Y=-4 relative to origin (so 12px below visual center)
    - After removing sprite offset, collision should move DOWN by 16px to maintain same relative position: -4 + 16 = 12

  **Must NOT do**:
  - Do NOT modify the script attachment or node structure
  - Do NOT change the collision shape SIZE (keep 30x20)
  - Do NOT modify FRONT_DOOR_OFFSET in mushroom_house.gd (it's separate)

  **Parallelizable**: YES (with task 1)

  **References**:

  **Current Scene Structure**:
  - `scenes/mushroom_house.tscn:12-14` - Sprite2D node with offset property
  - `scenes/mushroom_house.tscn:18-20` - CollisionShape2D with position property

  **Build System Reference**:
  - `resources/buildables/mushroom_house.tres` - Build placement settings (preview_offset, placement_offset)
  - Note: These are already at (0,0) with ignore_system_offset=true, so no changes needed there

  **Acceptance Criteria**:

  **Manual Execution Verification**:
  - [ ] Open Godot editor and load the project
  - [ ] Open build mode and hover mushroom house preview over terrain
  - [ ] Place mushroom house on the terrain
  - [ ] Verify: Preview position matches final placed position exactly (no jump/offset)
  - [ ] Verify: Collision still works (player can't walk through house base)
  - [ ] Evidence: Screenshot comparing preview position with placed position

  **Commit**: YES
  - Message: `fix(mushroom-house): remove sprite offset for accurate placement`
  - Files: `scenes/mushroom_house.tscn`

---

- [ ] 3. Implement rat visibility toggle based on work state

  **What to do**:
  
  **Step 3a: Add visibility control to RatVisuals**
  - Open `scripts/rat/rat_visuals.gd`
  - Add a new method at the end of the file:
  ```gdscript
  func set_visible_in_world(visible: bool) -> void:
      if body_sprite: body_sprite.visible = visible
      if held_item_sprite: held_item_sprite.visible = visible
      if count_label: count_label.visible = visible
  ```

  **Step 3b: Hide rat when entering idle state at home**
  - Open `scripts/rat/states/rat_idle_state.gd`
  - In `enter()` function, after line 18 (`rat.home_building.on_rat_idle(rat)`), add check:
  ```gdscript
  # Hide rat if at home
  if rat.home_building:
      var home_pos: Vector2 = rat.home_building.get_rest_position()
      if rat.global_position.distance_to(home_pos) <= arrival_threshold:
          if rat.visuals:
              rat.visuals.set_visible_in_world(false)
  ```

  **Step 3c: Show rat when task assigned**
  - Open `scripts/rat_assistant.gd`
  - Find the `assign_task()` function
  - At the beginning of that function, add:
  ```gdscript
  # Always show rat when given work
  if visuals:
      visuals.set_visible_in_world(true)
  ```

  **Must NOT do**:
  - Do NOT persist visibility state to save data
  - Do NOT add fade animations (user chose instant)
  - Do NOT modify the state machine transitions
  - Do NOT change when the rat MOVES, only when it's VISIBLE

  **Parallelizable**: NO (logically should be done after understanding task 2, but no code dependency)

  **References**:

  **Pattern References**:
  - `scripts/rat/rat_visuals.gd:48-50` - set_facing_direction shows how to control sprite properties
  - `scripts/rat/rat_visuals.gd:26-46` - update_held_item_visual shows held_item_sprite access pattern

  **State Machine References**:
  - `scripts/rat/states/rat_idle_state.gd:9-18` - enter() function where hide logic goes
  - `scripts/rat_assistant.gd` - assign_task() function where show logic goes

  **Position Logic Reference**:
  - `scripts/mushroom_house.gd:422-423` - get_rest_position() returns home position
  - `scripts/rat/states/rat_idle_state.gd:5` - arrival_threshold export var (4.0 pixels)

  **Acceptance Criteria**:

  **Manual Execution Verification**:
  - [ ] Run the game with `godot-mcp_run_project`
  - [ ] Place mushroom house, assign sources and outputs
  - [ ] Watch rat complete a task and return home
  - [ ] Verify: Rat is INVISIBLE when idle at home position
  - [ ] Wait for rat to be assigned new task
  - [ ] Verify: Rat becomes VISIBLE immediately when leaving to work
  - [ ] Verify: Rat stays visible during entire work cycle (move, harvest, deposit)
  - [ ] Verify: Rat becomes invisible again only when idle at home
  - [ ] Edge case: Verify rat is visible if idle but NOT at home position
  - [ ] Evidence: Screenshots of rat visible while working, invisible at home

  **Commit**: YES
  - Message: `feat(rat): hide rat when idle at mushroom house`
  - Files: `scripts/rat/rat_visuals.gd`, `scripts/rat/states/rat_idle_state.gd`, `scripts/rat_assistant.gd`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(rat): preserve inventory when returning home` | `scripts/rat/states/rat_return_home_state.gd` | Run game, verify items persist |
| 2 | `fix(mushroom-house): remove sprite offset for accurate placement` | `scenes/mushroom_house.tscn` | Build and place house, verify no offset |
| 3 | `feat(rat): hide rat when idle at mushroom house` | 3 files (visuals, idle state, assistant) | Run game, verify visibility toggling |

---

## Success Criteria

### Verification Commands
```bash
# Run Godot project
godot-mcp_run_project with projectPath="/Users/eugene/Documents/Github/LGD"

# Check for script errors on load
godot-mcp_get_debug_output
```

### Final Checklist
- [ ] Items persist when rat returns home (not cleared)
- [ ] Mushroom house placement matches preview exactly
- [ ] Rat invisible when idle at home
- [ ] Rat visible when working (moving, harvesting, depositing)
- [ ] No console errors during gameplay
- [ ] Save/load still works (visibility is runtime-only, not persisted)
