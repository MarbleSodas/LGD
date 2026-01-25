# Rat Planting Removal & Barrel Alignment Fix

## Context

### Original Request
Remove the rat assistant logic for planting entirely, having it focus only on harvesting. Also fix the newly added 3-tile structure making sure barrels are consistent with processors and storage containers for tile alignment.

### Interview Summary
**Key Discussions**:
- Plants always regrow so replanting by rats is unnecessary
- All seed-related logic should be removed (fetching, detection, empty source checking)
- Barrel visual alignment issue: sprite appears offset from tile positions
- Solution: Normalize barrel offsets to match processor pattern (zero offsets)

**Research Findings**:
- Barrel uses compensating offsets: placement_offset = Vector2(0, 16) + sprite offset = Vector2(0, -16)
- Processor uses no offsets and aligns correctly with tiles
- Planting logic spans: rat_plant_state.gd, rat_assistant.gd, rat_assistant.tscn, mushroom_house.gd

---

## Work Objectives

### Core Objective
Remove all planting and seed-related logic from the rat assistant system, and fix barrel visual alignment to match processor tile positioning.

### Concrete Deliverables
- Rat assistant no longer has planting capability
- Mushroom house no longer assigns planting or seed-fetching tasks
- Barrels visually align with their tile positions like processors do

### Definition of Done
- [ ] Rat assistant has no PLANT TaskType
- [ ] No plant state in rat state machine
- [ ] Mushroom house task priority is: Deposit → Harvest → Flush
- [ ] Barrel sprite aligns visually with its 3-tile footprint

### Must Have
- Complete removal of planting code paths
- Barrel alignment matches processor alignment

### Must NOT Have (Guardrails)
- DO NOT modify harvesting logic
- DO NOT modify deposit logic  
- DO NOT change processor or storage building code
- DO NOT add new features

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (Godot game project)
- **User wants tests**: Manual-only
- **Framework**: N/A

### Manual QA Procedures

**Barrel Alignment Verification:**
- Launch Godot editor, run project
- Place a barrel and a processor on adjacent tiles
- Visually confirm both buildings align consistently with the tile grid
- Verify IO indicators (arrows) point to correct adjacent tiles

**Rat Behavior Verification:**
- Assign source tiles to mushroom house (plants)
- Assign output tiles (barrels/processors)
- Observe rat behavior: should only harvest plants and deposit to outputs
- Confirm rat NEVER attempts to plant, even when source tiles are empty
- Confirm rat does NOT fetch seeds from processors

---

## Task Flow

```
Task 1 (Barrel Alignment) → Task 2 (Mushroom House) → Task 3 (Rat State Machine) → Task 4 (Cleanup) → Task 5 (Verification)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | None | Independent visual fix |
| 2 | None | Can run parallel with 1 |
| 3 | 2 | TaskType removal affects state transitions |
| 4 | 2, 3 | Cleanup after main changes |
| 5 | 1, 2, 3, 4 | Final verification |

---

## TODOs

- [ ] 1. Fix Barrel Visual Alignment

  **What to do**:
  - Remove sprite offset from barrel scene
  - Set placement_offset to zero in barrel buildable resource
  - This normalizes barrel positioning to match processor pattern

  **Must NOT do**:
  - Do not change the barrel's StaticBody2D or collision shape
  - Do not modify footprint_size (keep 3,1)

  **Parallelizable**: YES (with 2)

  **References**:

  **Pattern References**:
  - `scenes/processor_building.tscn` - Processor scene with no sprite offset (reference pattern)
  - `resources/buildables/processor.tres:17` - Processor with placement_offset = Vector2(0, 0)

  **Files to Modify**:
  - `scenes/barrel.tscn:11` - offset = Vector2(0, -16) needs to change
  - `resources/buildables/barrel.tres:17` - placement_offset = Vector2(0, 16) needs to change

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run Godot project
  - [ ] Place barrel next to processor on same tile row
  - [ ] Visually confirm barrel sprite aligns with tile grid (no vertical offset)
  - [ ] Confirm barrel's IO indicators point to correct adjacent tiles
  - [ ] Place barrel on flipped orientation, verify alignment still correct

  **Commit**: YES
  - Message: `fix(barrel): normalize visual alignment to match processor tile positioning`
  - Files: `scenes/barrel.tscn`, `resources/buildables/barrel.tres`

---

- [ ] 2. Remove Planting Logic from Mushroom House

  **What to do**:
  - Remove `_planting_rr_index` variable
  - Remove Priority 1 planting block from `_assign_next_task()`
  - Remove fetch seeds fallback from `_assign_next_task()`
  - Delete helper functions: `_rat_has_seeds()`, `_has_empty_sources()`, `_try_assign_planting()`, `_find_planting_target()`, `_try_assign_fetch_seeds()`, `_container_has_seeds()`
  - Update comment block at top of file to reflect new priorities

  **Must NOT do**:
  - Do not modify deposit logic (`_try_assign_deposit()`, `_get_next_valid_output_for_deposit()`, `_can_deposit_to()`)
  - Do not modify harvest logic (`_try_assign_harvest()`, `_find_best_source()`, `_is_ready_harvest()`)
  - Do not modify save/load logic

  **Parallelizable**: YES (with 1)

  **References**:

  **File to Modify**:
  - `scripts/mushroom_house.gd` - Main task assignment logic

  **Code Sections to Remove**:
  - Line 31: `var _planting_rr_index: int = 0`
  - Lines 196-206: Priority 1 planting block in `_assign_next_task()`
  - Lines 226-234: `_rat_has_seeds()` function
  - Lines 237-242: `_has_empty_sources()` function
  - Lines 244-266: `_try_assign_planting()` and `_find_planting_target()` functions
  - Lines 268-302: `_try_assign_fetch_seeds()` and `_container_has_seeds()` functions

  **Comment to Update**:
  - Lines 6-10: Update priority list to remove planting references

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Open mushroom_house.gd in editor
  - [ ] Verify no syntax errors (GDScript validation)
  - [ ] Run project, open mushroom house UI
  - [ ] Assign source tiles (plants) and output tiles (barrels)
  - [ ] Wait for plants to be harvest-ready
  - [ ] Observe rat: should harvest and deposit, never plant
  - [ ] Remove all plants from source tiles (leave empty)
  - [ ] Observe rat: should NOT attempt to plant or fetch seeds

  **Commit**: YES
  - Message: `refactor(rat): remove planting task logic from mushroom house`
  - Files: `scripts/mushroom_house.gd`

---

- [ ] 3. Remove Plant State from Rat State Machine

  **What to do**:
  - Remove PLANT from TaskType enum in rat_assistant.gd
  - Remove Plant state node reference from rat_assistant.tscn
  - Remove PLANT case from move state's `_on_arrived()` function
  - Delete rat_plant_state.gd file entirely

  **Must NOT do**:
  - Do not modify Harvest, Deposit, or Move states
  - Do not change rat movement or visual logic

  **Parallelizable**: NO (depends on 2 - TaskType used by mushroom house)

  **References**:

  **Files to Modify**:
  - `scripts/rat_assistant.gd:15` - TaskType enum
  - `scenes/rat_assistant.tscn:15,82-83` - Plant state node and resource reference
  - `scripts/rat/states/rat_move_to_source_state.gd:41-42` - PLANT case in match statement

  **File to Delete**:
  - `scripts/rat/states/rat_plant_state.gd` - Entire file (51 lines)

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Open rat_assistant.tscn in Godot editor
  - [ ] Verify StateMachine node has no Plant child
  - [ ] Open rat_assistant.gd, verify TaskType enum has only: NONE, HARVEST, DEPOSIT
  - [ ] Run project - no errors on scene load
  - [ ] Rat should function normally (harvest and deposit work)

  **Commit**: YES
  - Message: `refactor(rat): remove plant state and task type`
  - Files: `scripts/rat_assistant.gd`, `scenes/rat_assistant.tscn`, `scripts/rat/states/rat_move_to_source_state.gd`
  - Pre-delete: `scripts/rat/states/rat_plant_state.gd`

---

- [ ] 4. Cleanup: Remove ext_resource for Plant State

  **What to do**:
  - Remove the ext_resource line for rat_plant_state.gd from rat_assistant.tscn
  - This is a cleanup step to ensure no dangling references after file deletion

  **Must NOT do**:
  - Do not modify other ext_resources

  **Parallelizable**: NO (depends on 3)

  **References**:

  **File to Modify**:
  - `scenes/rat_assistant.tscn:15` - ext_resource for plant state script

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Open rat_assistant.tscn in text editor
  - [ ] Verify no reference to rat_plant_state.gd exists
  - [ ] Open scene in Godot editor - no missing resource warnings

  **Commit**: NO (group with Task 3)

---

- [ ] 5. Final Verification

  **What to do**:
  - Run complete integration test of all changes
  - Verify both objectives are achieved

  **Parallelizable**: NO (depends on all previous tasks)

  **References**:
  - All modified files from Tasks 1-4

  **Acceptance Criteria**:

  **Manual Execution Verification:**

  **Barrel Alignment Check:**
  - [ ] Place barrel and processor side by side
  - [ ] Both align consistently with tile grid
  - [ ] IO indicators point to correct tiles for both

  **Rat Behavior Check:**
  - [ ] Setup: mushroom house with source tiles (growable plants) and output tiles (barrel)
  - [ ] Observe rat for 5+ work cycles
  - [ ] Rat harvests ready plants: YES
  - [ ] Rat deposits to barrel: YES
  - [ ] Rat attempts to plant: NO (never)
  - [ ] Rat fetches seeds: NO (never)
  - [ ] When source tiles are empty (before regrow): rat waits or returns home, does NOT plant

  **Edge Cases:**
  - [ ] Empty inventory + empty source tiles = rat idles/returns home
  - [ ] Full inventory + no available outputs = rat waits (existing behavior)
  - [ ] Processor as output: rat deposits correctly

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(barrel): normalize visual alignment to match processor tile positioning` | barrel.tscn, barrel.tres | Visual check in editor |
| 2 | `refactor(rat): remove planting task logic from mushroom house` | mushroom_house.gd | Run project, verify no errors |
| 3 | `refactor(rat): remove plant state and task type` | rat_assistant.gd, rat_assistant.tscn, rat_move_to_source_state.gd, DELETE rat_plant_state.gd | Run project, verify rat functions |

---

## Success Criteria

### Verification Commands
```bash
# Open Godot and run project
godot --path /mnt/c/Users/eugen/Documents/lgd
```

### Final Checklist
- [ ] Barrel visually aligns with tiles (no offset)
- [ ] Processor alignment unchanged (still correct)
- [ ] Rat has no PLANT capability
- [ ] Mushroom house only assigns Harvest/Deposit tasks
- [ ] All planting-related code removed
- [ ] No runtime errors or warnings
- [ ] Save/load still works (unchanged code paths)
