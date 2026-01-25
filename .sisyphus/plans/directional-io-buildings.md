# Directional Input/Output Buildings (Barrel & Processor)

## Context

### Original Request
Modify barrels and processors to have directional input/output tiles:
- Left tile = INPUT (rats deposit items here)
- Right tile = OUTPUT (rats take items from here)
- Center tile = building itself
- 3-tile footprint total
- "R" key during placement flips IO sides
- Enable workflow: Rat 1 takes from barrel OUTPUT → processor INPUT, Rat 2 takes from processor OUTPUT → plants trees

### Interview Summary
**Key Discussions**:
- **Tile Layout**: INPUT (left) - BUILDING (center) - OUTPUT (right)
- **Barrel Model**: Keep single container - input deposits, output withdraws from same storage
- **Processor Model**: Leverage existing input_inventory/output_inventory, spatially separate them
- **Flip Behavior**: "R" swaps IO sides only, visual sprite unchanged
- **Collision**: Only center tile solid; IO tiles walkable
- **Rat Position**: Rats stand ON IO tile to interact
- **Player Interaction**: Center tile only responds to click/interact
- **Visual Indicators**: Show arrows/icons for IO directions
- **Migration**: Auto-migrate existing buildings to 3-tile layout on save load
- **Costs**: Keep current build costs unchanged
- **Preview**: Full 3-tile preview with IO indicators during placement

**Research Findings**:
- `storage_building.gd`: Single container, methods `get_container()`, `harvest()`, `is_harvest_ready()`
- `processor_building.gd`: Already has `input_inventory`/`output_inventory`, `get_wanted_item_id()`
- `placement_manager.gd`: No rotation support, no multi-tile footprint currently
- `planting_system.gd`: Per-tile occupancy tracking via `occupied_tiles`
- `mushroom_house.gd`: Assigns rats via `assigned_outputs`, uses `_can_deposit_to()`

### Gap Analysis (Self-Conducted)
**Identified Gaps** (addressed in plan):
- Auto-migration overlap handling: If IO tiles would overlap existing structures, migration skips that building
- Orientation: Horizontal only (left-right), no vertical orientation
- Placement validation: Must have 3 free horizontal tiles to place

---

## Work Objectives

### Core Objective
Add directional input/output tile support to barrels and processors, enabling rats to deposit at specific INPUT tiles and harvest from OUTPUT tiles, with rotation support during placement.

### Concrete Deliverables
- Modified `BuildableItem` resource with footprint size and flip state
- Modified `PlacementManager` with multi-tile placement and R-key rotation
- Modified `PlantingSystem` with multi-tile occupancy tracking
- Modified `StorageBuilding` (barrel) with IO tile position tracking
- Modified `ProcessorBuilding` with IO tile position tracking
- Modified `MushroomHouse` to assign rats to specific IO tiles
- Modified rat states to navigate to IO tiles
- Visual IO indicators on barrel and processor sprites
- Save/load migration for existing buildings

### Definition of Done
- [ ] Barrels and processors take up 3 tiles when placed
- [ ] Pressing "R" during placement flips IO sides
- [ ] Rats deposit items by standing on INPUT tile
- [ ] Rats harvest items by standing on OUTPUT tile
- [ ] Existing single-tile buildings auto-migrate on load
- [ ] Player can only interact with center tile
- [ ] Visual indicators show IO directions

### Must Have
- 3-tile horizontal footprint (INPUT-CENTER-OUTPUT)
- R-key to flip IO during placement
- Walkable IO tiles, solid center tile
- Separate rat assignment for input vs output operations
- Save/load compatibility with auto-migration

### Must NOT Have (Guardrails)
- No vertical orientation support (horizontal only)
- No variable footprint sizes (always 3 tiles)
- No explicit supply chain linking UI
- No changes to other building types (only barrel and processor)
- No automated tests (manual QA only per user request)
- No build cost changes

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: Unknown (not assessed)
- **User wants tests**: Manual-only
- **Framework**: N/A

### Manual QA Only

Each TODO includes detailed verification procedures using Godot editor and in-game testing.

**By Deliverable Type:**

| Type | Verification Tool | Procedure |
|------|------------------|-----------|
| **Godot Game** | Run game via Godot | Test placement, rotation, rat behavior |
| **Visual Changes** | Godot editor | Inspect scenes and sprites |
| **Save/Load** | Game save/load cycle | Verify migration works |

**Evidence Required:**
- Visual confirmation of 3-tile placement
- Rat pathfinding to correct IO tiles
- Successful item deposit/withdrawal at IO tiles

---

## Task Flow

```
Task 1 (BuildableItem footprint) 
    ↓
Task 2 (PlacementManager multi-tile) 
    ↓
Task 3 (PlacementManager rotation) ← depends on 2
    ↓
Task 4 (PlantingSystem multi-tile occupancy) 
    ↓
Task 5 (DirectionalBuilding base class)
    ↓
Task 6 (StorageBuilding IO support) ← depends on 5
    ↓
Task 7 (ProcessorBuilding IO support) ← depends on 5
    ↓
Task 8 (MushroomHouse IO assignment) ← depends on 6, 7
    ↓
Task 9 (Rat states IO navigation) ← depends on 8
    ↓
Task 10 (Visual IO indicators)
    ↓
Task 11 (Save/Load migration)
    ↓
Task 12 (Integration testing)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 6, 7 | StorageBuilding and ProcessorBuilding can be modified in parallel once base class exists |
| B | 10, 11 | Visual indicators and save/load migration are independent |

| Task | Depends On | Reason |
|------|------------|--------|
| 3 | 2 | Rotation requires multi-tile to be implemented first |
| 6, 7 | 5 | IO buildings need the base DirectionalBuilding class |
| 8 | 6, 7 | MushroomHouse needs buildings to expose IO tiles |
| 9 | 8 | Rat states need MushroomHouse to assign IO targets |
| 12 | All | Integration testing requires all components |

---

## TODOs

- [ ] 1. Add footprint support to BuildableItem resource

  **What to do**:
  - Add `footprint_size: Vector2i = Vector2i(1, 1)` property to BuildableItem
  - Add `supports_flip: bool = false` property for buildings that can be rotated
  - Update `barrel.tres` to set `footprint_size = Vector2i(3, 1)` and `supports_flip = true`
  - Update `processor.tres` to set `footprint_size = Vector2i(3, 1)` and `supports_flip = true`

  **Must NOT do**:
  - Do not change footprint for any other buildable items
  - Do not add vertical footprint support

  **Parallelizable**: NO (foundational - all other tasks depend on this)

  **References**:
  - `scripts/resources/buildable_item.gd:1-50` - BuildableItem resource class definition, add new properties here
  - `resources/buildables/barrel.tres` - Barrel resource to update with new properties
  - `resources/buildables/processor.tres` - Processor resource to update with new properties

  **Acceptance Criteria**:
  - [ ] `buildable_item.gd` has `footprint_size` and `supports_flip` exported properties
  - [ ] `barrel.tres` has `footprint_size = Vector2i(3, 1)` and `supports_flip = true`
  - [ ] `processor.tres` has `footprint_size = Vector2i(3, 1)` and `supports_flip = true`
  - [ ] Godot editor: Open barrel.tres in inspector, verify footprint_size shows (3, 1)

  **Commit**: YES
  - Message: `feat(buildable): add footprint_size and supports_flip properties`
  - Files: `scripts/resources/buildable_item.gd`, `resources/buildables/barrel.tres`, `resources/buildables/processor.tres`

---

- [ ] 2. Implement multi-tile placement validation in PlacementManager

  **What to do**:
  - Modify `_check_can_place()` to validate ALL tiles in the footprint, not just one
  - Get footprint from `BuildRegistry.active_buildable.footprint_size`
  - For each tile in footprint (0 to footprint_size.x - 1), check occupancy
  - Update `_update_preview()` to show preview across all footprint tiles
  - Calculate footprint tiles relative to placement origin (center tile)

  **Must NOT do**:
  - Do not implement rotation yet (Task 3)
  - Do not change single-tile buildable behavior (footprint 1x1 should work as before)

  **Parallelizable**: NO (depends on Task 1)

  **References**:
  - `scripts/systems/placement_manager.gd:100-130` - `_check_can_place()` and `_update_preview()` functions
  - `scripts/planting_system.gd:145-151` - `is_tile_occupied()` for checking tile availability
  - `scripts/autoloads/build_registry.gd` - `active_buildable` property to get current item

  **Acceptance Criteria**:
  - [ ] Using Godot: Select barrel in build menu
  - [ ] Move mouse over empty 3-tile horizontal area: preview shows green across all 3 tiles
  - [ ] Move mouse where only 2 tiles are free: preview shows red (cannot place)
  - [ ] Existing single-tile items (like other plants) still place correctly with 1-tile validation

  **Commit**: YES
  - Message: `feat(placement): add multi-tile footprint validation`
  - Files: `scripts/systems/placement_manager.gd`

---

- [ ] 3. Add R-key rotation support to PlacementManager

  **What to do**:
  - Add `current_flip_state: bool = false` variable to track flip state
  - Add input handling for "rotate_build" action (map to R key) in `handle_input()`
  - When R is pressed, toggle `current_flip_state`
  - Modify footprint calculation: if flipped, INPUT is on right, OUTPUT is on left
  - Reset `current_flip_state = false` when switching buildable items
  - Only allow flip if `active_buildable.supports_flip == true`

  **Must NOT do**:
  - Do not rotate the visual sprite (flip only affects IO tile positions)
  - Do not add rotation to single-tile items

  **Parallelizable**: NO (depends on Task 2)

  **References**:
  - `scripts/systems/placement_manager.gd:180-200` - `handle_input()` function for input handling
  - `scripts/resources/buildable_item.gd` - `supports_flip` property
  - Project input map - May need to add "rotate_build" action mapped to R key

  **Acceptance Criteria**:
  - [ ] Using Godot: Select barrel in build menu
  - [ ] Press R key: Preview should update (flip indicator changes)
  - [ ] Place flipped barrel: IO tiles are swapped (verify via later testing with rats)
  - [ ] Select a non-flippable item: R key does nothing
  - [ ] Switch buildable: flip state resets to default

  **Commit**: YES
  - Message: `feat(placement): add R-key rotation for directional buildings`
  - Files: `scripts/systems/placement_manager.gd`, `project.godot` (if input map changes needed)

---

- [ ] 4. Update PlantingSystem for multi-tile occupancy tracking

  **What to do**:
  - Modify `register_object()` to register ALL tiles in footprint as occupied
  - Store reference to building in all occupied tiles
  - Add `get_building_at_tile(coords)` to return the building that occupies a tile
  - Modify `unregister_object()` to clear all footprint tiles
  - Handle IO tiles differently: mark as "occupied_io" (walkable but assigned to building)

  **Must NOT do**:
  - Do not break existing single-tile occupancy behavior
  - Do not mark IO tiles as blocked for pathfinding

  **Parallelizable**: YES (with Task 3, independent logic)

  **References**:
  - `scripts/planting_system.gd:100-160` - `register_object()`, `unregister_object()`, `occupied_tiles` dictionary
  - `scripts/planting_system.gd:145-151` - `is_tile_occupied()` function

  **Acceptance Criteria**:
  - [ ] Using Godot: Place a barrel
  - [ ] All 3 tiles show as occupied in debug view or via code inspection
  - [ ] Cannot place another building overlapping any of the 3 tiles
  - [ ] Removing the barrel frees all 3 tiles
  - [ ] Player and rats can walk on IO tiles (only center is blocked)

  **Commit**: YES
  - Message: `feat(planting): add multi-tile occupancy tracking`
  - Files: `scripts/planting_system.gd`

---

- [ ] 5. Create DirectionalBuilding base class

  **What to do**:
  - Create new script `scripts/directional_building.gd`
  - Base class that StorageBuilding and ProcessorBuilding will inherit common IO logic from
  - Properties:
    - `is_flipped: bool = false` - stored from placement
    - `center_tile: Vector2i` - the building's center tile position
  - Methods:
    - `get_input_tile() -> Vector2i` - returns left tile (or right if flipped)
    - `get_output_tile() -> Vector2i` - returns right tile (or left if flipped)
    - `get_all_tiles() -> Array[Vector2i]` - returns all 3 tiles
    - `set_placement_data(center: Vector2i, flipped: bool)` - called during spawn

  **Must NOT do**:
  - Do not modify existing building behavior yet
  - Do not implement inventory logic (that's in subclasses)

  **Parallelizable**: NO (depends on Task 4, foundational for Tasks 6-7)

  **References**:
  - `scripts/storage_building.gd` - StorageBuilding to understand current structure
  - `scripts/processor_building.gd` - ProcessorBuilding to understand current structure
  - Godot GDScript class inheritance patterns

  **Acceptance Criteria**:
  - [ ] New file `scripts/directional_building.gd` exists
  - [ ] Class has documented properties and methods listed above
  - [ ] No syntax errors when opening in Godot editor
  - [ ] Class extends appropriate base (Sprite2D or Node2D matching storage_building.gd)

  **Commit**: YES
  - Message: `feat(buildings): add DirectionalBuilding base class for IO support`
  - Files: `scripts/directional_building.gd`

---

- [ ] 6. Update StorageBuilding (barrel) with IO tile support

  **What to do**:
  - Make StorageBuilding extend DirectionalBuilding (or incorporate its methods)
  - Override/use `get_input_tile()` and `get_output_tile()` methods
  - Add `get_deposit_tile() -> Vector2i` - returns input tile for rat deposits
  - Add `get_harvest_tile() -> Vector2i` - returns output tile for rat harvesting
  - Update `_ready()` to initialize IO tile positions based on placement
  - Ensure `get_container()` still works for player UI interaction

  **Must NOT do**:
  - Do not split barrel into two containers (keep single container per design)
  - Do not change player interaction behavior (center tile only)

  **Parallelizable**: YES (with Task 7)

  **References**:
  - `scripts/storage_building.gd:1-80` - Current StorageBuilding implementation
  - `scripts/directional_building.gd` - New base class from Task 5
  - `scenes/barrel.tscn` - Barrel scene file

  **Acceptance Criteria**:
  - [ ] Using Godot: Place a barrel
  - [ ] Call `barrel.get_input_tile()` in debugger - returns correct left tile coords
  - [ ] Call `barrel.get_output_tile()` in debugger - returns correct right tile coords
  - [ ] Place a flipped barrel - IO tiles are swapped correctly
  - [ ] Player can still open barrel UI by clicking center tile

  **Commit**: YES
  - Message: `feat(barrel): add directional IO tile support`
  - Files: `scripts/storage_building.gd`, `scenes/barrel.tscn`

---

- [ ] 7. Update ProcessorBuilding with IO tile support

  **What to do**:
  - Make ProcessorBuilding extend DirectionalBuilding (or incorporate its methods)
  - Override/use `get_input_tile()` and `get_output_tile()` methods
  - `get_deposit_tile()` returns input tile (for depositing raw materials)
  - `get_harvest_tile()` returns output tile (for collecting processed items)
  - Input tile accesses `input_inventory`, output tile accesses `output_inventory`
  - Update `_ready()` to initialize IO tile positions based on placement

  **Must NOT do**:
  - Do not change processor recipe logic
  - Do not change player interaction (center tile opens processor UI)

  **Parallelizable**: YES (with Task 6)

  **References**:
  - `scripts/processor_building.gd:1-100` - Current ProcessorBuilding with input_inventory/output_inventory
  - `scripts/directional_building.gd` - New base class from Task 5
  - `scenes/processor_building.tscn` - Processor scene file

  **Acceptance Criteria**:
  - [ ] Using Godot: Place a processor
  - [ ] Call `processor.get_input_tile()` in debugger - returns correct left tile coords
  - [ ] Call `processor.get_output_tile()` in debugger - returns correct right tile coords
  - [ ] Place a flipped processor - IO tiles are swapped correctly
  - [ ] Processor still processes items correctly (recipe logic unchanged)

  **Commit**: YES
  - Message: `feat(processor): add directional IO tile support`
  - Files: `scripts/processor_building.gd`, `scenes/processor_building.tscn`

---

- [ ] 8. Update MushroomHouse for IO tile-based rat assignment

  **What to do**:
  - Modify `assigned_outputs` to store IO tile references (input tiles for deposit targets)
  - Modify `assigned_sources` to include output tiles for harvest targets
  - Update `_can_deposit_to(coords)` to check if coords is a valid INPUT tile
  - Update `_get_next_valid_output_for_deposit()` to return INPUT tiles of directional buildings
  - Update `_find_best_source()` to return OUTPUT tiles of directional buildings
  - Add method to get building from IO tile coordinate

  **Must NOT do**:
  - Do not break assignment for non-directional buildings
  - Do not change rat priority logic (plant, deposit, harvest order)

  **Parallelizable**: NO (depends on Tasks 6, 7)

  **References**:
  - `scripts/mushroom_house.gd:200-300` - Assignment logic, `_can_deposit_to()`, `_get_next_valid_output_for_deposit()`
  - `scripts/mushroom_house.gd:150-200` - `assigned_outputs`, `assigned_sources` arrays
  - `scripts/planting_system.gd` - `get_building_at_tile()` from Task 4

  **Acceptance Criteria**:
  - [ ] Using Godot: Assign barrel OUTPUT as a harvest source
  - [ ] Assign processor INPUT as a deposit target
  - [ ] Rat receives correct tile coordinates for navigation
  - [ ] Multiple rats can be assigned to different IO tiles of same building

  **Commit**: YES
  - Message: `feat(mushroom-house): update rat assignment for IO tiles`
  - Files: `scripts/mushroom_house.gd`

---

- [ ] 9. Update rat states to navigate to IO tiles

  **What to do**:
  - Modify `RatMoveToSourceState` to navigate to OUTPUT tile of source building
  - Modify `RatMoveToOutputState` to navigate to INPUT tile of deposit target
  - Modify `RatHarvestState` to verify rat is standing on correct OUTPUT tile
  - Modify `RatDepositState` to verify rat is standing on correct INPUT tile
  - Handle arrival detection: rat arrives when standing ON the IO tile

  **Must NOT do**:
  - Do not change rat inventory logic
  - Do not change item transfer amounts
  - Do not break behavior for non-directional targets

  **Parallelizable**: NO (depends on Task 8)

  **References**:
  - `scripts/rat/states/rat_move_to_source_state.gd` - Navigation to source
  - `scripts/rat/states/rat_move_to_output_state.gd` - Navigation to deposit target
  - `scripts/rat/states/rat_harvest_state.gd` - Harvest action
  - `scripts/rat/states/rat_deposit_state.gd` - Deposit action

  **Acceptance Criteria**:
  - [ ] Using Godot: Assign rat to harvest from barrel OUTPUT tile
  - [ ] Rat walks to OUTPUT tile (not center), stands ON it
  - [ ] Rat successfully harvests items
  - [ ] Assign rat to deposit to processor INPUT tile
  - [ ] Rat walks to INPUT tile, stands ON it, deposits items

  **Commit**: YES
  - Message: `feat(rat-states): update navigation for IO tiles`
  - Files: `scripts/rat/states/rat_move_to_source_state.gd`, `scripts/rat/states/rat_move_to_output_state.gd`, `scripts/rat/states/rat_harvest_state.gd`, `scripts/rat/states/rat_deposit_state.gd`

---

- [ ] 10. Add visual IO indicators to barrel and processor sprites

  **What to do**:
  - Add arrow sprites or icons to barrel scene showing INPUT (left arrow) and OUTPUT (right arrow)
  - Add same indicators to processor scene
  - Indicators should flip when building is flipped
  - Use consistent visual language (e.g., green arrow for input, red for output)
  - Position indicators at IO tile locations

  **Must NOT do**:
  - Do not change the main building sprite
  - Do not add complex animations (keep it simple)

  **Parallelizable**: YES (with Task 11)

  **References**:
  - `scenes/barrel.tscn` - Barrel scene to add indicator sprites
  - `scenes/processor_building.tscn` - Processor scene to add indicator sprites
  - Existing sprite assets in project (or create simple arrow sprites)

  **Acceptance Criteria**:
  - [ ] Using Godot: Place a barrel - left side shows INPUT indicator, right shows OUTPUT
  - [ ] Place a flipped barrel - indicators are swapped
  - [ ] Same for processor
  - [ ] Indicators are clearly visible and don't obscure the building

  **Commit**: YES
  - Message: `feat(visuals): add IO direction indicators to barrels and processors`
  - Files: `scenes/barrel.tscn`, `scenes/processor_building.tscn`, any new sprite assets

---

- [ ] 11. Implement save/load migration for existing buildings

  **What to do**:
  - Update `get_save_data()` in StorageBuilding to include:
    - `is_flipped` state
    - `center_tile` position
    - `version` field (e.g., "2" for new format)
  - Update `load_save_data()` to handle migration:
    - If loading old format (no version or version 1): 
      - Check if 3-tile footprint would fit
      - If fits: migrate to 3-tile with default orientation
      - If overlap: log warning, skip migration (keep as single tile temporarily)
  - Same changes for ProcessorBuilding

  **Must NOT do**:
  - Do not corrupt existing save files
  - Do not delete buildings that can't migrate (handle gracefully)

  **Parallelizable**: YES (with Task 10)

  **References**:
  - `scripts/storage_building.gd:get_save_data()` and `load_save_data()` methods
  - `scripts/processor_building.gd:get_save_data()` and `load_save_data()` methods
  - `world.gd` - World save/load system

  **Acceptance Criteria**:
  - [ ] Create a save with old single-tile barrels and processors
  - [ ] Load the save after code changes
  - [ ] Buildings auto-migrate to 3-tile footprint
  - [ ] IO tiles function correctly after migration
  - [ ] Re-save and re-load maintains new format

  **Commit**: YES
  - Message: `feat(save-load): add migration for directional buildings`
  - Files: `scripts/storage_building.gd`, `scripts/processor_building.gd`

---

- [ ] 12. Integration testing and QA verification

  **What to do**:
  - Complete end-to-end workflow test:
    1. Place a barrel (3 tiles) with wood inside
    2. Place a processor (3 tiles) with a recipe selected
    3. Assign Rat 1 to harvest from barrel OUTPUT, deposit to processor INPUT
    4. Verify processor receives wood and starts processing
    5. Assign Rat 2 to harvest from processor OUTPUT
    6. Verify Rat 2 receives processed items
  - Test flip functionality:
    1. Place flipped barrel next to normal processor
    2. Verify IO tiles are adjacent correctly
  - Test edge cases:
    1. Try to place where only 2 tiles available - should fail
    2. Try to delete building - all 3 tiles freed
    3. Test save/load cycle

  **Must NOT do**:
  - Do not skip any test scenario
  - Do not mark as complete if any core workflow fails

  **Parallelizable**: NO (final integration, depends on all previous tasks)

  **References**:
  - All previous task implementations
  - Game run via Godot editor

  **Acceptance Criteria**:
  - [ ] End-to-end workflow: Wood from barrel → processor → processed output works with 2 rats
  - [ ] Flip placement works correctly
  - [ ] Cannot place in insufficient space
  - [ ] Delete frees all tiles
  - [ ] Save/load preserves building state
  - [ ] No console errors during testing

  **Commit**: NO (testing only, no code changes)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(buildable): add footprint_size and supports_flip properties` | buildable_item.gd, barrel.tres, processor.tres | Inspect in editor |
| 2 | `feat(placement): add multi-tile footprint validation` | placement_manager.gd | Place barrel, verify 3 tiles |
| 3 | `feat(placement): add R-key rotation for directional buildings` | placement_manager.gd | Press R during placement |
| 4 | `feat(planting): add multi-tile occupancy tracking` | planting_system.gd | Verify all 3 tiles occupied |
| 5 | `feat(buildings): add DirectionalBuilding base class for IO support` | directional_building.gd | Open in editor, no errors |
| 6 | `feat(barrel): add directional IO tile support` | storage_building.gd, barrel.tscn | Test get_input_tile() |
| 7 | `feat(processor): add directional IO tile support` | processor_building.gd, processor_building.tscn | Test get_input_tile() |
| 8 | `feat(mushroom-house): update rat assignment for IO tiles` | mushroom_house.gd | Assign rats to IO tiles |
| 9 | `feat(rat-states): update navigation for IO tiles` | rat states/*.gd | Rats navigate to IO tiles |
| 10 | `feat(visuals): add IO direction indicators to barrels and processors` | barrel.tscn, processor_building.tscn | Visual inspection |
| 11 | `feat(save-load): add migration for directional buildings` | storage_building.gd, processor_building.gd | Old save loads correctly |

---

## Success Criteria

### Verification Commands
```bash
# Run game from Godot editor
# No specific terminal commands - all verification is in-game
```

### Final Checklist
- [ ] Barrels take up 3 tiles (INPUT-CENTER-OUTPUT)
- [ ] Processors take up 3 tiles (INPUT-CENTER-OUTPUT)
- [ ] R key flips IO sides during placement
- [ ] Rats navigate to and stand on IO tiles
- [ ] Rats deposit at INPUT, harvest at OUTPUT
- [ ] Visual indicators show IO directions
- [ ] Only center tile blocks movement
- [ ] Only center tile responds to player interaction
- [ ] Existing saves migrate correctly
- [ ] 2-rat workflow (barrel→processor→planting) functions correctly
