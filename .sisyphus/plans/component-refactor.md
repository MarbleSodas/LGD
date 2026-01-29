# Component System Refactoring for LGD

## TL;DR

> **Quick Summary**: Migrate StorageBuilding and ProcessorBuilding from monolithic classes to pure component composition, eliminate 5+ duplicated code patterns, and establish a GameServices autoload for clean service discovery.
> 
> **Deliverables**: 
> - GameServices autoload for service discovery
> - Refactored StorageBuilding using components
> - Refactored ProcessorBuilding using components  
> - Updated .tscn scene files with component nodes
> - Deleted obsolete base classes
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: NO - sequential (Phase 2 validates pattern for Phase 3)
> **Critical Path**: Task 1 -> Task 2 -> Task 3 -> Task 4 -> Task 5 -> Task 6 -> Task 7

---

## Context

### Original Request
User asked to review the project for refactoring opportunities to make code more readable, with emphasis on node-based structure and components displayed properly in editor with defaults for proper editing.

### Interview Summary
**Key Discussions**:
- Goal: Full refactor (deduplication + component adoption + editor basics)
- Approach: Conservative migration (gradual, not big-bang)
- Save compatibility: NOT required (fresh start OK)
- Plant.gd: Leave alone (135 lines works fine)
- MushroomHouse.gd: Exclude (Rat AI domain, separate concern)
- Base classes: Delete both DirectionalBuilding and BuildingBase
- Service discovery: Create GameServices autoload
- Test strategy: Manual verification
- Editor experience: Basic (functional only)

**Research Findings**:
- SafetyCheck: Only 3 files extend DirectionalBuilding (BuildingBase, StorageBuilding, ProcessorBuilding) - safe to delete
- No type checks (`is BuildingBase`, etc.) found in codebase - safe to delete
- Components already exist and are well-designed but unused in scenes
- SaveableComponent uses elegant sibling aggregation pattern

### Metis Review
**Identified Gaps** (addressed):
- Base class deletion safety: Verified via grep - only 3 references, all in-scope
- Component completeness: ContainerComponent supports single inventory, ProcessorBuilding needs 2x
- Behavior verification baseline: Added specific scene + action verification steps
- Type safety after deletion: Using duck typing (has_method) instead of type checks

---

## Work Objectives

### Core Objective
Eliminate code duplication and fully adopt the existing component architecture for building entities, enabling cleaner code organization and proper editor-time configuration.

### Concrete Deliverables
- `scripts/autoloads/game_services.gd` - New service locator
- `scripts/storage_building.gd` - Simplified to ~30 lines (component coordination only)
- `scripts/processor_building.gd` - Simplified to ~50 lines (component coordination only)
- `scenes/barrel.tscn` - Updated with component child nodes
- `scenes/processor_building.tscn` - Updated with component child nodes
- DELETE: `scripts/directional_building.gd`
- DELETE: `scripts/buildings/building_base.gd`

### Definition of Done
- [ ] `godot_run_project` launches without errors
- [ ] StorageBuilding inventory opens when interacted
- [ ] ProcessorBuilding processes recipes correctly
- [ ] Save/load round-trips correctly for both buildings
- [ ] Base classes deleted with no remaining references

### Must Have
- GameServices provides PlantingSystem and UI references
- StorageBuilding uses ContainerComponent + InteractionComponent + SaveableComponent
- ProcessorBuilding uses ProcessingComponent + 2x ContainerComponent + InteractionComponent + SaveableComponent
- Components are scene tree children, properly configured

### Must NOT Have (Guardrails)
- **NO Plant.gd changes** - explicitly out of scope
- **NO MushroomHouse.gd changes** - explicitly out of scope
- **NO UI system changes** - focus is on buildings only
- **NO new features** - behavior parity, not enhancement
- **NO component API changes** - use existing interfaces
- **NO animation system refactoring** - encapsulate existing behavior
- **NO automated tests** - manual verification only
- **NO polished editor experience** - functional only

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (no test framework configured)
- **User wants tests**: Manual verification only
- **Framework**: None

### Automated Verification

Each TODO includes executable verification via Godot tools:

```bash
# After each major change:
godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
# Assert: No errors in godot_get_debug_output
```

### Manual Behavior Verification Checklist

**StorageBuilding (Barrel)**:
- [ ] Load world.tscn, find a barrel in YSortRoot
- [ ] Walk to barrel and interact (E key or click)
- [ ] Verify ContainerPanel UI opens
- [ ] Add items to inventory slots
- [ ] Close UI, reopen - items still present
- [ ] Save game, reload world - items persist

**ProcessorBuilding**:
- [ ] Load world.tscn, find a processor building
- [ ] Interact to open ProcessorMenu
- [ ] Add input items matching a recipe
- [ ] Verify processing animation plays
- [ ] Wait for processing to complete
- [ ] Verify output appears in output slot
- [ ] Save game, reload - processing state preserved

---

## Execution Strategy

### Sequential Execution (No Parallelization)

This refactoring must be sequential because:
- Task 1 (GameServices) is required by all subsequent tasks
- Task 2-4 (StorageBuilding) establishes the pattern used in Task 5-6 (ProcessorBuilding)
- Task 7 (cleanup) requires all refactoring to be complete and verified

```
Task 1: Create GameServices
   |
   v
Task 2: Create StorageBuilding wrapper script
   |
   v
Task 3: Update barrel.tscn with components
   |
   v  
Task 4: Verify StorageBuilding works
   |
   v
Task 5: Create ProcessorBuilding wrapper script
   |
   v
Task 6: Update processor_building.tscn with components
   |
   v
Task 7: Delete obsolete base classes
```

---

## TODOs

- [ ] 1. Create GameServices Autoload

  **What to do**:
  - Create `scripts/autoloads/game_services.gd`
  - Provide cached references to PlantingSystem, UI root
  - Register as autoload in project.godot
  - Replace lookup pattern across codebase

  **Must NOT do**:
  - Move business logic into GameServices (thin wrapper only)
  - Refactor MushroomHouse.gd or other out-of-scope files

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file creation, minimal complexity
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Tasks 2-7
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `scripts/autoloads/build_registry.gd` - Existing autoload pattern (singleton style)
  - `scripts/autoloads/inventory.gd` - Another autoload example

  **API/Type References**:
  - `scripts/planting_system.gd` - PlantingSystem class to expose
  
  **Duplication to Replace** (copy-pasted lookup pattern in 5+ files):
  ```gdscript
  var planting_system = get_tree().get_first_node_in_group(GROUP_PLANTING_SYSTEM)
  if not planting_system:
      var root = get_tree().current_scene
      if root.has_node("PlantingSystem"):
          planting_system = root.get_node("PlantingSystem")
  ```
  - Found in: `scripts/buildings/building_base.gd:51-56`
  - Found in: `scripts/storage_building.gd:69-73`
  - Found in: `scripts/processor_building.gd:86-88`
  - Found in: `scripts/components/InteractionComponent.gd:57-61`
  - Found in: `scripts/mushroom_house.gd:59-67`

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify file exists and project loads
  ls scripts/autoloads/game_services.gd
  # Assert: File exists
  
  # Verify autoload registered
  grep -q "game_services" project.godot
  # Assert: Match found
  
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  # Assert: No errors (GameServices singleton accessible)
  ```

  **Evidence to Capture:**
  - [ ] project.godot autoload entry
  - [ ] GameServices.gd contents

  **Commit**: YES
  - Message: `feat(autoload): add GameServices for centralized service discovery`
  - Files: `scripts/autoloads/game_services.gd`, `project.godot`
  - Pre-commit: `godot --headless --check-only`

---

- [ ] 2. Create StorageBuilding Wrapper Script

  **What to do**:
  - Rewrite `scripts/storage_building.gd` to ~30 lines
  - Remove inline container, interaction, save/load logic
  - Delegate to child components via `$ComponentName`
  - Keep interface compatibility (interact(), get_container(), harvest(), get_save_data(), etc.)

  **Must NOT do**:
  - Delete the file (we're replacing contents)
  - Change the class_name
  - Break compatibility with PlantingSystem or Rat AI

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Moderate refactoring, follows established pattern
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 3, 4
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `scripts/components/SaveableComponent.gd:10-33` - Sibling aggregation pattern (get_save_data iterates siblings)
  - `scripts/components/InteractionComponent.gd:17-25` - Component interaction delegation

  **API/Type References**:
  - `scripts/components/ContainerComponent.gd` - Full API: get_container(), is_full(), is_empty(), add_item(), remove_item(), get_save_data(), load_save_data()
  - `scripts/components/InteractionComponent.gd` - Full API: interact(), close_interaction(), on_ui_closed()
  - `scripts/components/SaveableComponent.gd` - Full API: get_save_data(), load_save_data()
  - `scripts/components/FootprintComponent.gd` - Full API: set_placement_data(), get_center_tile(), get_occupied_tiles(), get_save_data(), load_save_data()

  **Current Implementation** (to be replaced):
  - `scripts/storage_building.gd` - 153 lines of inline everything

  **Expected Component Structure** (scene tree):
  ```
  StorageBuilding (Node2D)
  ├── SaveableComponent
  ├── FootprintComponent  
  ├── InteractionComponent
  ├── ContainerComponent
  └── [existing children: Sprite2D, StaticBody2D]
  ```

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify file compiles
  godot --headless --check-only
  # Assert: Exit code 0
  
  # Verify class structure
  grep "class_name StorageBuilding" scripts/storage_building.gd
  # Assert: Match found
  
  grep "extends Node2D" scripts/storage_building.gd
  # Assert: Match found (no longer extends DirectionalBuilding)
  ```

  **Evidence to Capture:**
  - [ ] New StorageBuilding.gd contents (~30 lines)
  - [ ] Line count: `wc -l scripts/storage_building.gd` shows significant reduction

  **Commit**: NO (groups with Task 3)

---

- [ ] 3. Update barrel.tscn with Component Nodes

  **What to do**:
  - Add component child nodes to barrel.tscn scene
  - Configure ContainerComponent slot_count (30 slots)
  - Configure InteractionComponent menu_group ("ui_layer")
  - Ensure FootprintComponent has correct footprint_size (Vector2i(1,1))
  - Add SaveableComponent for persistence

  **Must NOT do**:
  - Hand-edit .tscn file in text editor (use Godot tools)
  - Change visual structure or collision

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Scene modification using Godot tools
  - **Skills**: []
    - No special skills needed (Godot MCP tools available)

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:

  **Current Scene Structure**:
  - `scenes/barrel.tscn` - Root Sprite2D with script, StaticBody2D child

  **Component Scripts to Add**:
  - `scripts/components/SaveableComponent.gd`
  - `scripts/components/FootprintComponent.gd`
  - `scripts/components/InteractionComponent.gd`
  - `scripts/components/ContainerComponent.gd`

  **Configuration Values**:
  - ContainerComponent.slot_count: 30 (matches current storage_slots export)
  - InteractionComponent.menu_group: "ui_layer"
  - FootprintComponent.footprint_size: Vector2i(1, 1)
  - FootprintComponent.supports_flip: false

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify scene loads without errors
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD", scene="res://scenes/barrel.tscn")
  # Assert: Scene loads, no errors in debug output
  
  # Verify components exist in scene
  grep "SaveableComponent" scenes/barrel.tscn
  grep "ContainerComponent" scenes/barrel.tscn
  grep "InteractionComponent" scenes/barrel.tscn
  # Assert: All matches found
  ```

  **Evidence to Capture:**
  - [ ] Updated barrel.tscn contents
  - [ ] Screenshot of scene tree in Godot editor showing components

  **Commit**: YES
  - Message: `refactor(barrel): migrate to component composition`
  - Files: `scripts/storage_building.gd`, `scenes/barrel.tscn`
  - Pre-commit: Scene loads without errors

---

- [ ] 4. Verify StorageBuilding Functionality

  **What to do**:
  - Load world.tscn and test barrel interaction
  - Verify inventory UI opens correctly
  - Verify items can be added/removed
  - Verify save/load persistence works
  - Document any issues found

  **Must NOT do**:
  - Proceed to ProcessorBuilding if StorageBuilding doesn't work
  - Fix unrelated issues discovered during testing

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Manual verification, no code changes
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 5, 6, 7
  - **Blocked By**: Task 3

  **References**:

  **Test Scene**:
  - `world.tscn` - Main game scene containing buildings

  **Expected Behavior** (baseline from current implementation):
  - Walk to barrel, press interact key
  - ContainerPanel UI opens with 30 slots
  - Items can be dragged into slots
  - Closing and reopening preserves items
  - Saving and reloading game preserves items

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Project runs without errors
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No ERROR messages related to StorageBuilding or components
  ```

  **Manual Verification Checklist**:
  - [ ] Barrel interaction opens ContainerPanel
  - [ ] ContainerPanel shows correct slot count (30)
  - [ ] Items can be placed in slots
  - [ ] Closing/reopening UI preserves items
  - [ ] Save/load preserves container contents

  **Evidence to Capture:**
  - [ ] Debug output showing successful component initialization
  - [ ] Confirmation that all manual checks pass

  **Commit**: NO (verification only, no changes)

---

- [ ] 5. Create ProcessorBuilding Wrapper Script

  **What to do**:
  - Rewrite `scripts/processor_building.gd` to ~50 lines
  - Delegate to ProcessingComponent for recipe logic
  - Use 2x ContainerComponent for input/output inventories
  - Keep animation control inline (ProcessingComponent signals -> animation)
  - Maintain interface compatibility

  **Must NOT do**:
  - Refactor animation system (keep existing AnimationPlayer usage)
  - Change recipe data structures
  - Break Rat AI integration (get_container, harvest, etc.)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Complex refactoring, 396-line file, multiple concerns
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 6, 7
  - **Blocked By**: Task 4

  **References**:

  **Pattern References**:
  - `scripts/storage_building.gd` - Refactored version from Task 2 (follow same pattern)
  - `scripts/components/ProcessingComponent.gd:27-49` - Initialization and container wiring

  **API/Type References**:
  - `scripts/components/ProcessingComponent.gd` - Full API: set_selected_recipe(), get_processing_progress(), get_wanted_item_id(), signals (processing_started, processing_complete)
  - `scripts/components/ContainerComponent.gd` - For input/output inventories
  - `scripts/resources/processor_recipe.gd` - Recipe resource structure

  **Current Implementation** (to be replaced):
  - `scripts/processor_building.gd` - 396 lines

  **Key Interfaces to Preserve** (for Rat AI compatibility):
  - `get_container()` -> input ContainerComponent
  - `harvest(max_amount)` -> extract from output ContainerComponent  
  - `is_harvest_ready()` -> output ContainerComponent not empty
  - `get_wanted_item_id()` -> from ProcessingComponent
  - `get_deposit_tile()`, `get_harvest_tile()` -> from FootprintComponent

  **Expected Component Structure** (scene tree):
  ```
  ProcessorBuilding (Node2D)
  ├── SaveableComponent
  ├── FootprintComponent
  ├── InteractionComponent
  ├── InputContainer (ContainerComponent, slot_count=1)
  ├── OutputContainer (ContainerComponent, slot_count=1)
  ├── ProcessingComponent (references InputContainer, OutputContainer)
  ├── AnimationPlayer
  └── Layers/...
  ```

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify file compiles
  godot --headless --check-only
  # Assert: Exit code 0
  
  # Verify class structure
  grep "class_name ProcessorBuilding" scripts/processor_building.gd
  grep "extends Node2D" scripts/processor_building.gd
  # Assert: Both matches found
  
  # Verify line count reduced
  wc -l scripts/processor_building.gd
  # Assert: ~50 lines (down from 396)
  ```

  **Evidence to Capture:**
  - [ ] New ProcessorBuilding.gd contents (~50 lines)
  - [ ] Line count comparison: 396 -> ~50

  **Commit**: NO (groups with Task 6)

---

- [ ] 6. Update processor_building.tscn with Component Nodes

  **What to do**:
  - Add component child nodes to processor_building.tscn
  - Add 2x ContainerComponent (InputContainer, OutputContainer) with slot_count=1 each
  - Add ProcessingComponent, wire input_container and output_container exports
  - Configure InteractionComponent for processor_menu group
  - Preserve existing AnimationPlayer and Layers structure

  **Must NOT do**:
  - Hand-edit .tscn file in text editor
  - Change animation structure or visual layers
  - Modify recipe resources

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Scene modification using Godot tools
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 7
  - **Blocked By**: Task 5

  **References**:

  **Current Scene Structure**:
  - `scenes/processor_building.tscn` - Node2D with AnimationPlayer, Layers

  **Component Configuration**:
  - InputContainer (ContainerComponent): slot_count=1
  - OutputContainer (ContainerComponent): slot_count=1
  - ProcessingComponent: input_container -> $InputContainer, output_container -> $OutputContainer
  - InteractionComponent: menu_group="processor_menu"
  - FootprintComponent: footprint_size=Vector2i(1,1), supports_flip=false

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify scene loads
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD", scene="res://scenes/processor_building.tscn")
  # Assert: No errors in debug output
  
  # Verify components in scene
  grep "ProcessingComponent" scenes/processor_building.tscn
  grep "InputContainer" scenes/processor_building.tscn
  grep "OutputContainer" scenes/processor_building.tscn
  # Assert: All matches found
  ```

  **Manual Verification Checklist**:
  - [ ] Processor interaction opens ProcessorMenu
  - [ ] Items can be placed in input slot
  - [ ] Processing animation plays when recipe matches
  - [ ] Output appears in output slot after processing
  - [ ] Rat AI can still deposit/harvest (has_method checks pass)

  **Evidence to Capture:**
  - [ ] Updated processor_building.tscn
  - [ ] Screenshot of scene tree showing components

  **Commit**: YES
  - Message: `refactor(processor): migrate to component composition`
  - Files: `scripts/processor_building.gd`, `scenes/processor_building.tscn`
  - Pre-commit: Scene loads, processor functions correctly

---

- [ ] 7. Delete Obsolete Base Classes

  **What to do**:
  - Delete `scripts/directional_building.gd`
  - Delete `scripts/buildings/building_base.gd`
  - Verify no remaining references in codebase
  - Final integration test

  **Must NOT do**:
  - Delete files before verifying all refactoring works
  - Leave orphan references

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file deletion after verification
  - **Skills**: [`git-master`]
    - For clean commit of deletion

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (final task)
  - **Blocks**: None
  - **Blocked By**: Task 6

  **References**:

  **Safety Check Results** (already verified):
  - `extends DirectionalBuilding` found in: BuildingBase, StorageBuilding, ProcessorBuilding (all in-scope)
  - `extends BuildingBase` found in: none
  - Type checks (`is DirectionalBuilding`, etc.): none found

  **Files to Delete**:
  - `scripts/directional_building.gd` (37 lines)
  - `scripts/buildings/building_base.gd` (135 lines)

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Verify files deleted
  ls scripts/directional_building.gd
  # Assert: File not found (deleted)
  
  ls scripts/buildings/building_base.gd
  # Assert: File not found (deleted)
  
  # Verify no references remain
  grep -r "DirectionalBuilding" --include="*.gd" scripts/
  grep -r "BuildingBase" --include="*.gd" scripts/
  # Assert: No matches
  
  # Final integration test
  godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
  godot_get_debug_output()
  # Assert: No errors
  ```

  **Final Manual Verification**:
  - [ ] Project loads without errors
  - [ ] StorageBuilding still works
  - [ ] ProcessorBuilding still works
  - [ ] No orphan class references in console

  **Evidence to Capture:**
  - [ ] Git status showing deleted files
  - [ ] Final debug output clean

  **Commit**: YES
  - Message: `refactor(buildings): delete obsolete base classes`
  - Files: DELETE `scripts/directional_building.gd`, DELETE `scripts/buildings/building_base.gd`
  - Pre-commit: Full project test

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(autoload): add GameServices for centralized service discovery` | game_services.gd, project.godot | Project loads |
| 3 | `refactor(barrel): migrate to component composition` | storage_building.gd, barrel.tscn | Barrel works |
| 6 | `refactor(processor): migrate to component composition` | processor_building.gd, processor_building.tscn | Processor works |
| 7 | `refactor(buildings): delete obsolete base classes` | -directional_building.gd, -building_base.gd | All buildings work |

---

## Success Criteria

### Verification Commands
```bash
# Project compiles and runs
godot_run_project(projectPath="/Users/eugene/Documents/Github Projects/LGD")
godot_get_debug_output()
# Expected: No ERROR messages

# Base classes deleted
ls scripts/directional_building.gd
# Expected: File not found

# No orphan references
grep -r "DirectionalBuilding\|BuildingBase" --include="*.gd" scripts/
# Expected: No matches
```

### Final Checklist
- [ ] GameServices autoload registered and functional
- [ ] StorageBuilding uses components, ~30 lines
- [ ] ProcessorBuilding uses components, ~50 lines
- [ ] Both .tscn files have component children
- [ ] Both buildings function identically to before
- [ ] Base classes deleted (172 lines removed)
- [ ] Total code reduction: ~400+ lines eliminated through deduplication and component reuse
