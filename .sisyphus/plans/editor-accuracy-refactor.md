# Editor Accuracy & Architecture Refactor

## Context

### Original Request
Refactor the project to make the editor as accurate as possible ("what you see is what you get") and simplify the code structure, specifically focusing on proper node-based structures and readable code.

### Interview Summary
**Key Discussions**:
- **Core Philosophy**: Eliminate "hidden defaults" (properties set in code that should be visible in the Inspector).
- **Manager Architecture**: Move `PlacementManager`, `DeletionManager`, `InteractionManager` from code-instantiated (`.new()`) to Scene-based nodes to expose their `@export` variables.
- **Building Architecture**: Create a `BuildingBase` class to reduce duplication between `ProcessorBuilding` and `StorageBuilding`.
- **Testing**: Manual QA only (no automated test infrastructure).

**Research Findings**:
- **Hidden Defaults**: `PlantingSystem` creates managers via code, hiding 12+ exports. Magic numbers exist for interaction ranges, UI offsets, and Z-indices.
- **Scene Issues**: `world.tscn` has `TileMapLayer` sibling to `YSortRoot` (rendering order bug). `player.tscn` has invalid collision mask. `tree.tscn` has disabled collision.
- **Code Duplication**: `PlacementManager` and `PlantingSystem` share footprint logic. Buildings share UI/Harvest logic.
- **Structural Oddities**: `StoneDeposit` extends `Plant` but overrides exported variables in `_ready()`, rendering the Inspector useless.

### Metis Review
**Identified Gaps** (addressed):
- **Phasing**: Broken into 4 distinct phases (Managers, Buildings, Magic Numbers, Cleanup) to isolate risk.
- **StoneDeposit**: Added specific task to fix inheritance/export overrides.
- **Redundancy**: Added task to investigate and remove the legacy `inventory_panel.gd`.

---

## Work Objectives

### Core Objective
Restructure the codebase so that runtime behavior is configured via the Godot Editor (Inspector/Scene Tree) rather than hardcoded scripts, and eliminate code duplication in the Building system.

### Concrete Deliverables
1. **Scene-Based Managers**: `PlantingSystem` scene with child nodes for Managers, all configurable in Inspector.
2. **BuildingBase Class**: Abstract class handling UI, Interaction, and Lifecycle, inherited by specific buildings.
3. **Correct Scene Structure**: `world.tscn` with proper Y-sorting; fixed `player.tscn` and `tree.tscn` collisions.
4. **Exposed Configuration**: Magic numbers converted to `@export` variables across the codebase.

### Definition of Done
- [ ] `PlantingSystem` managers are nodes in the scene, not created via `.new()`.
- [ ] Manager properties (grid radius, colors, etc.) are editable in the Inspector.
- [ ] `ProcessorBuilding` and `StorageBuilding` share common logic via `BuildingBase`.
- [ ] Entities render correctly behind/in-front of map tiles (Y-sorting fixed).
- [ ] Player can interact with objects (collision mask fixed).
- [ ] `StoneDeposit` properties are editable in the Inspector.
- [ ] No regression in gameplay (Place, Delete, Harvest, Process) verified via Manual QA.

### Must Have
- Preserve exact current gameplay values (unless fixing a bug).
- Preserve save/load compatibility.
- Keep existing Rat AI interfaces intact.

### Must NOT Have (Guardrails)
- Do NOT implement new features.
- Do NOT refactor Rat AI logic.
- Do NOT add automated test infrastructure.
- Do NOT change UI visual design or layout.

---

## Verification Strategy

**Test Decision**: Manual QA Only (as requested).

**Verification Protocol**:
Since we are refactoring core systems (Managers, Buildings), manual verification must be exhaustive.

**Standard Test Suite (Run after EACH task):**
1. **Placement**: Select an item, hover over valid/invalid spots, place it. Verify cost deduction.
2. **Interaction**: Walk up to object, verify highlight, click to interact (Open UI).
3. **Processing**: Put items in Processor, wait for output, collect output.
4. **Deletion**: Enter delete mode, remove object, verify refund.
5. **Persistence**: Save game, restart, Load game. Verify world state.

---

## Task Flow

```
Phase 1: Scene Structure & Managers (Core Fixes)
Phase 2: Building Refactor (Code Architecture)
Phase 3: Magic Numbers & Exports (Editor Visibility)
Phase 4: Cleanup & Polish
```

---

## TODOs

### Phase 1: Scene Structure & Managers

- [ ] 1. Fix World Y-Sorting Structure
  - **Goal**: Ensure entities render at correct depth relative to tiles.
  - **Action**: In `world.tscn`, move `TileMapLayer` INTO `YSortRoot` (or restructure so they share a YSort parent).
  - **Verify**: Place player "behind" a high tile (if any) or ensure Z-index is consistent.
  - **Commit**: `fix(scene): correct world y-sort hierarchy`

- [ ] 2. Fix Entity Collision Scenes
  - **Goal**: Fix broken collision settings found during research.
  - **Action**:
    - `player.tscn`: Set `InteractArea` collision mask to 1 (or appropriate interaction layer).
    - `tree.tscn`: Enable `CollisionShape2D`.
    - `rat_assistant.tscn`: Remove hardcoded `z_index = 1` from `HeldItemSprite` (use Y-offset).
  - **Verify**: Player collides with tree; Player interaction zone detects objects.
  - **Commit**: `fix(scene): enable collisions for player and tree`

- [ ] 3. Create Manager Scenes
  - **Goal**: Convert code-only managers to Scenes/Nodes.
  - **Action**:
    - Create `scenes/systems/placement_manager.tscn` (Node2D root, attach script).
    - Create `scenes/systems/deletion_manager.tscn` (Node2D root, attach script).
    - Create `scenes/systems/interaction_manager.tscn` (Node2D root, attach script).
    - **Refactor Scripts**: Remove `_init()` if strictly logic, rely on `_ready()`. Ensure `@export` vars are clean.
  - **Verify**: Scenes can be instantiated.
  - **Commit**: `refactor(systems): create manager scenes`

- [ ] 4. Integrate Managers into PlantingSystem
  - **Goal**: Replace `.new()` instantiation with scene instances.
  - **Action**:
    - In `planting_system.gd`: Remove `.new()` calls in `_ready/_init`.
    - Add `@export var` references or `@onready` lookups for the manager child nodes.
    - In `world.tscn` (or where PlantingSystem is used): Add the Manager instances as children of `PlantingSystem`.
    - Update `setup()` calls to pass dependencies.
  - **Verify**: Run game. Placement, Deletion, Interaction should work EXACTLY as before, but Managers are now visible in Remote Tree.
  - **Commit**: `refactor(systems): move managers to scene tree`

### Phase 2: Building Architecture

- [ ] 5. Create BuildingBase Class
  - **Goal**: Abstract shared logic.
  - **Action**:
    - Create `scripts/buildings/building_base.gd` extending `Node2D` (or `DirectionalBuilding` if that hierarchy stays).
    - Extract common variables: `harvest_ready`, `ui_open`, `custom_ui`.
    - Extract common methods: `open_ui()`, `close_ui()`, `harvest()`, `_input()` (for closing UI).
  - **Verify**: Script compiles.
  - **Commit**: `feat(arch): create BuildingBase class`

- [ ] 6. Refactor ProcessorBuilding
  - **Goal**: Use BuildingBase.
  - **Action**:
    - Update `processor_building.gd` to extend `BuildingBase`.
    - Remove duplicated UI opening/closing logic.
    - Remove duplicated Harvest logic (if identical).
    - Keep Processor-specific logic (timers, recipes).
  - **Verify**: Processor works: opens UI, processes items, closes UI on walk-away.
  - **Commit**: `refactor(building): migrate ProcessorBuilding to BuildingBase`

- [ ] 7. Refactor StorageBuilding
  - **Goal**: Use BuildingBase.
  - **Action**:
    - Update `storage_building.gd` to extend `BuildingBase`.
    - Remove duplicated UI logic.
  - **Verify**: Storage works: opens inventory, transfers items.
  - **Commit**: `refactor(building): migrate StorageBuilding to BuildingBase`

- [ ] 8. Centralize Lifecycle Management
  - **Goal**: Stop Managers from manually hacking `PlantingSystem` arrays.
  - **Action**:
    - In `PlantingSystem`, add `register_object(coords, node)` and `unregister_object(coords)`.
    - In `PlacementManager`, call `planting_system.register_object()`.
    - In `DeletionManager`, call `planting_system.unregister_object()`.
    - In `InteractionManager` (harvest), call `planting_system.unregister_object()` if destroying.
  - **Verify**: Place and Delete objects. Check `occupied_tiles` dictionary in Debugger.
  - **Commit**: `refactor(systems): centralize lifecycle in PlantingSystem`

### Phase 3: Magic Numbers & Exports

- [ ] 9. Expose Interaction Manager Config
  - **Goal**: Remove magic numbers.
  - **Action**:
    - `interaction_manager.gd`: Export `max_dist` (default 64.0).
    - `interaction_manager.gd`: Export `progress_bar_offset` (default Vector2(-12, 16)).
    - `interaction_manager.gd`: Export `popup_offset` (default Vector2(0, -20)).
  - **Verify**: Change values in Inspector, verify runtime behavior changes.
  - **Commit**: `refactor(config): expose InteractionManager settings`

- [ ] 10. Fix StoneDeposit Exports
  - **Goal**: Make StoneDeposit editable in Inspector.
  - **Action**:
    - In `stone_deposit.gd`: Remove the hardcoded `harvest_time = ...` assignments in `_ready()`.
    - In `world.tscn` (or wherever StoneDeposit is used/prefabbed): Set those values in the Inspector for the `stone_deposit.tscn` scene.
  - **Verify**: Change harvest time in Inspector, verify in game.
  - **Commit**: `fix(entity): use exports for StoneDeposit configuration`

- [ ] 11. Clean up "Hidden Defaults" in Managers
  - **Goal**: Review Managers for any other hidden defaults.
  - **Action**:
    - `PlacementManager`: Ensure `grid_radius`, `colors` are exported and respected.
    - `DeletionManager`: Ensure `refund_ratio` is exported.
  - **Verify**: Inspector check.
  - **Commit**: `refactor(config): ensure manager exports are complete`

### Phase 4: Cleanup & Polish

- [ ] 12. Remove Redundant Inventory Panel
  - **Goal**: Clear confusion.
  - **Action**:
    - Confirm `ui/inventory_panel.gd` is unused (legacy).
    - Delete it.
    - Ensure `ui/components/inventory_panel.gd` is the one being used.
  - **Verify**: Game runs, inventory still works.
  - **Commit**: `chore: remove legacy inventory_panel script`

- [ ] 13. Final Regression Check
  - **Action**: Full playthrough.
    - Place Processor.
    - Place Storage.
    - Harvest Stone.
    - Harvest Tree.
    - Rat interaction (if applicable).
    - Save/Load.
  - **Verify**: All systems nominal.

---

## Success Criteria

### Final Checklist
- [ ] `PlantingSystem` has child nodes for Managers in `world.tscn`.
- [ ] `ProcessorBuilding` inherits `BuildingBase`.
- [ ] `StoneDeposit` properties are set in Inspector, not code.
- [ ] Player collides with Trees.
- [ ] No `.new()` calls for system managers in `planting_system.gd`.
