# Plant Regrow, Rat State Cleanup, Plant/Building Differentiation

## Context

### Original Request
User requested:
1. Ensure all plants regrow after harvest
2. Clean up rat state machine by removing unnecessary states  
3. Make plants and buildings differentiable

### Interview Summary
**Key Discussions**:
- Tree is the only plant currently set to NOT regrow (default false)
- User wants trees to regrow normally (not stump-first behavior)
- RatMoveToOutputState is completely unused dead code
- User prefers enum on BuildableItem over Godot groups for differentiation

**Research Findings**:
- Plant regrow controlled by `@export var regrows: bool = false` in `/scripts/plant.gd:26`
- Tree scene (`scenes/tree.tscn`) doesn't set regrows, uses default (false)
- Mushroom and Dandelion already have `regrows = true`
- `RatMoveToOutputState` and MoveToOutput node never used - no code transitions to "movetooutput"
- `is_buildable_a_plant()` in build_registry.gd instantiates scenes at runtime (expensive)
- BuildableItem has no type field - needs enum added

### Self-Review Gap Analysis
**Gaps Addressed**:
- Verified all 6 buildable resources exist: dandelion, mushroom_plant, tree (plants) + barrel, processor, mushroom_house (buildings)
- Confirmed exact lines in tree.tscn where regrows property would go
- Confirmed MoveToOutput node location in rat_assistant.tscn (lines 73-74)
- Verified no other code references the MoveToOutput state

---

## Work Objectives

### Core Objective
Clean up plant regrow behavior, remove rat dead code, and add proper plant/building differentiation via BuildableItem enum.

### Concrete Deliverables
- `scenes/tree.tscn` with `regrows = true`
- Deleted `scripts/rat/states/rat_move_to_output_state.gd`
- `scenes/rat_assistant.tscn` without MoveToOutput node
- `scripts/resources/buildable_item.gd` with `BuildableType` enum
- All 6 `.tres` files updated with `buildable_type` field
- `scripts/autoloads/build_registry.gd` using enum instead of instantiation

### Definition of Done
- [ ] All plants (Tree, Dandelion, Mushroom) have regrows=true
- [ ] No unused rat states remain
- [ ] `BuildRegistry.is_buildable_a_plant()` uses enum lookup (no instantiation)
- [ ] Game runs without errors after changes

### Must Have
- Tree regrows after harvest
- Dead MoveToOutput state completely removed
- BuildableType enum on BuildableItem resource
- All buildables tagged with correct type

### Must NOT Have (Guardrails)
- Do NOT add Godot groups (user chose enum approach)
- Do NOT change stump/tree growth stages (normal regrow only)
- Do NOT modify other rat states (only remove MoveToOutput)
- Do NOT change MushroomHouse class hierarchy
- Do NOT add complex interfaces or base class refactoring

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (Godot project without test framework)
- **User wants tests**: Manual-only
- **Framework**: none

### Manual QA Approach
Each TODO includes verification via Godot editor run or file inspection.

---

## Task Flow

```
Task 1 (Tree regrow) ──┐
Task 2 (Rat cleanup) ──┼──> Task 4 (Verification)
Task 3 (Enum + update)─┘
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1, 2, 3 | Fully independent - different files/systems |

| Task | Depends On | Reason |
|------|------------|--------|
| 4 | 1, 2, 3 | Verification after all changes |

---

## TODOs

- [ ] 1. Enable Tree Regrow

  **What to do**:
  - Add `regrows = true` property to `scenes/tree.tscn` on the Tree node
  - The property should be added after line 26 (after `harvest_time = 3.0`)

  **Must NOT do**:
  - Do NOT change growth_stages or tree sprite frames
  - Do NOT modify tree.gd script

  **Parallelizable**: YES (with 2, 3)

  **References**:
  
  **Pattern References**:
  - `scenes/mushroom_plant.tscn:24` - Shows `regrows = true` property format in scene file
  - `scenes/dandelion.tscn:25` - Another example of regrows property in scene

  **Implementation References**:
  - `scripts/plant.gd:26` - Defines `@export var regrows: bool = false` (the property we're setting)
  - `scripts/tree.gd:17-18` - Shows TreePlant.harvest() checks regrows before queue_free()

  **File to Modify**:
  - `scenes/tree.tscn:26` - Add `regrows = true` after `harvest_time = 3.0`

  **Acceptance Criteria**:

  **Manual Verification**:
  - [ ] Open `scenes/tree.tscn` in text editor
  - [ ] Verify line after `harvest_time = 3.0` contains `regrows = true`
  - [ ] Using Godot editor or `godot-mcp_run_project`:
    - Place a tree
    - Wait for tree to grow to harvest stage
    - Harvest the tree
    - Verify tree resets to stage 0 (smallest sprite) instead of disappearing
    - Verify tree begins growing again

  **Commit**: YES
  - Message: `fix(plant): enable tree regrow after harvest`
  - Files: `scenes/tree.tscn`

---

- [ ] 2. Remove Unused RatMoveToOutputState

  **What to do**:
  - Delete file `scripts/rat/states/rat_move_to_output_state.gd`
  - Remove MoveToOutput node from `scenes/rat_assistant.tscn` (lines 12, 73-74)
  - This removes the ext_resource reference and the node definition

  **Must NOT do**:
  - Do NOT modify any other rat states
  - Do NOT change state machine logic in other files

  **Parallelizable**: YES (with 1, 3)

  **References**:
  
  **Evidence of Dead Code**:
  - `scripts/rat/states/rat_move_to_output_state.gd` - File to delete (class RatMoveToOutputState)
  - `scenes/rat_assistant.tscn:12` - ext_resource for move_to_output_state.gd (to remove)
  - `scenes/rat_assistant.tscn:73-74` - MoveToOutput node definition (to remove)
  
  **Verification that no code uses this state**:
  - Searched entire codebase: No transitions to "movetooutput" found
  - State contains reference to non-existent "plant" state (line 31) - further proof of dead code

  **Files to Modify**:
  - DELETE: `scripts/rat/states/rat_move_to_output_state.gd`
  - EDIT: `scenes/rat_assistant.tscn` - Remove lines 12 (ext_resource) and 73-74 (node)

  **Acceptance Criteria**:

  **Manual Verification**:
  - [ ] File `scripts/rat/states/rat_move_to_output_state.gd` no longer exists
  - [ ] `scenes/rat_assistant.tscn` has no reference to `rat_move_to_output_state.gd`
  - [ ] `scenes/rat_assistant.tscn` has no `MoveToOutput` node
  - [ ] Using Godot editor or `godot-mcp_run_project`:
    - Load the game
    - Assign a rat to harvest task in MushroomHouse
    - Verify rat correctly cycles through: Idle -> Move -> Harvest -> Idle
    - No errors in console about missing states

  **Commit**: YES
  - Message: `refactor(rat): remove unused MoveToOutput state`
  - Files: `scripts/rat/states/rat_move_to_output_state.gd` (deleted), `scenes/rat_assistant.tscn`

---

- [ ] 3. Add BuildableType Enum and Update Resources

  **What to do**:
  
  **Step 3a: Add enum to BuildableItem resource**
  - Edit `scripts/resources/buildable_item.gd`
  - Add enum definition after line 2:
    ```gdscript
    enum BuildableType { PLANT, BUILDING }
    ```
  - Add export property after line 5 (after `id`):
    ```gdscript
    @export var buildable_type: BuildableType = BuildableType.PLANT
    ```
  
  **Step 3b: Update all buildable .tres files**
  - `resources/buildables/dandelion.tres` - Add `buildable_type = 0` (PLANT)
  - `resources/buildables/mushroom_plant.tres` - Add `buildable_type = 0` (PLANT)
  - `resources/buildables/tree.tres` - Add `buildable_type = 0` (PLANT)
  - `resources/buildables/barrel.tres` - Add `buildable_type = 1` (BUILDING)
  - `resources/buildables/processor.tres` - Add `buildable_type = 1` (BUILDING)
  - `resources/buildables/mushroom_house.tres` - Add `buildable_type = 1` (BUILDING)
  
  **Step 3c: Update build_registry.gd to use enum**
  - Replace `is_buildable_a_plant()` (lines 176-190) with:
    ```gdscript
    func is_buildable_a_plant(id: String) -> bool:
        if not _all_items.has(id): return false
        var item: BuildableItem = _all_items[id]
        return item.buildable_type == BuildableItem.BuildableType.PLANT
    ```

  **Must NOT do**:
  - Do NOT add Godot group assignments
  - Do NOT change other BuildableItem properties
  - Do NOT modify the scene loading logic

  **Parallelizable**: YES (with 1, 2)

  **References**:
  
  **Resource Class**:
  - `scripts/resources/buildable_item.gd:1-43` - Full BuildableItem class (add enum here)
  
  **Files to Update**:
  - `resources/buildables/dandelion.tres` - Plant type
  - `resources/buildables/mushroom_plant.tres` - Plant type
  - `resources/buildables/tree.tres` - Plant type
  - `resources/buildables/barrel.tres` - Building type
  - `resources/buildables/processor.tres` - Building type
  - `resources/buildables/mushroom_house.tres` - Building type

  **Current Implementation to Replace**:
  - `scripts/autoloads/build_registry.gd:174-190` - Old is_buildable_a_plant() that instantiates scenes

  **Acceptance Criteria**:

  **Manual Verification**:
  - [ ] `scripts/resources/buildable_item.gd` contains `enum BuildableType { PLANT, BUILDING }`
  - [ ] `scripts/resources/buildable_item.gd` contains `@export var buildable_type: BuildableType`
  - [ ] All 6 .tres files have `buildable_type` property set
  - [ ] `scripts/autoloads/build_registry.gd` `is_buildable_a_plant()` no longer instantiates scenes
  - [ ] Using Godot editor:
    - Open a buildable resource in inspector
    - Verify "Buildable Type" dropdown appears with PLANT/BUILDING options
  - [ ] Using `godot-mcp_run_project`:
    - Game loads without errors
    - Hotbar shows correct items
    - Can place plants and buildings

  **Commit**: YES
  - Message: `feat(build): add BuildableType enum for plant/building differentiation`
  - Files: `scripts/resources/buildable_item.gd`, `scripts/autoloads/build_registry.gd`, `resources/buildables/*.tres`

---

- [ ] 4. Final Verification

  **What to do**:
  - Run the game and verify all systems work together
  - Test the specific scenarios that exercise all changes

  **Parallelizable**: NO (depends on 1, 2, 3)

  **References**:
  
  **Test Scenarios**:
  - Tree regrow (Task 1)
  - Rat state machine (Task 2)  
  - Build system (Task 3)

  **Acceptance Criteria**:

  **Manual Verification**:
  - [ ] Using `godot-mcp_run_project`:
    
    **Test Tree Regrow**:
    - Place a tree from hotbar
    - Wait for full growth (or use debug to skip)
    - Harvest tree (player or rat)
    - Verify tree resets to stage 0, not removed
    
    **Test Rat State Machine**:
    - Open MushroomHouse
    - Assign rat to harvest task
    - Watch rat perform: Idle -> Move -> Harvest -> Idle cycle
    - No console errors about missing states
    
    **Test Build Differentiation**:
    - Check console: No errors about BuildableType
    - Place both plants (dandelion) and buildings (barrel)
    - Both should place correctly with appropriate behavior

  - [ ] Using `godot-mcp_get_debug_output`:
    - No errors related to: "State not found", "plant state", "movetooutput"
    - No errors related to BuildableType or buildable_type

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(plant): enable tree regrow after harvest` | scenes/tree.tscn | Visual test in game |
| 2 | `refactor(rat): remove unused MoveToOutput state` | rat_move_to_output_state.gd (del), rat_assistant.tscn | Rat harvesting works |
| 3 | `feat(build): add BuildableType enum for plant/building differentiation` | buildable_item.gd, build_registry.gd, *.tres | Build system works |

---

## Success Criteria

### Verification Commands
```bash
# Verify tree scene has regrows
grep -n "regrows" scenes/tree.tscn  # Expected: regrows = true

# Verify MoveToOutput removed
ls scripts/rat/states/  # Expected: no rat_move_to_output_state.gd
grep -n "MoveToOutput" scenes/rat_assistant.tscn  # Expected: no matches

# Verify enum added
grep -n "BuildableType" scripts/resources/buildable_item.gd  # Expected: enum definition
grep -n "buildable_type" resources/buildables/*.tres  # Expected: matches in all 6 files
```

### Final Checklist
- [ ] All plants regrow: Tree, Dandelion, Mushroom all have regrows=true
- [ ] Dead code removed: No MoveToOutput state or file
- [ ] Differentiation works: BuildableType enum in place, all resources tagged
- [ ] No regression: Game runs, rats work, building placement works
