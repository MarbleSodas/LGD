# Project Structure Refactor: Simplify Following Godot Best Practices

## TL;DR

> **Quick Summary**: Refactor LGD project structure by first reducing coupling (consolidate 8 autoloads to 5), then reorganizing directory structure following Godot's node-based best practices with hybrid script organization.
> 
> **Deliverables**:
> - Consolidated autoloads: Registries (ItemRegistry+BuildRegistry), DataManager (GameState+TipsManager)
> - Consistent directory structure with scenes and co-located scripts
> - Organized buildables by type under scenes/entities/
> - Unified UI folder structure
> 
> **Estimated Effort**: Large (3-5 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Phase 0 → Phase 1.1 → Phase 1.2 → Phase 2.1 → Phase 2.2 → Phase 2.3

---

## Context

### Original Request
Create a refactor plan to simplify the project structure focusing on best practices and the node-based structure of Godot.

### Interview Summary
**Key Discussions**:
- **Pain Points**: All (finding files confusing, adding features messy, coupling causes bugs)
- **Script Organization**: Hybrid (scene-specific co-located, shared logic in scripts/)
- **Risk Tolerance**: Moderate (reorganize, update references, some breaking changes OK)
- **Autoload Strategy**: Consolidate related autoloads
- **Buildable Organization**: By type (scenes/entities/buildables/ with subfolders)
- **Priority**: Coupling/dependencies first, then directory structure
- **Test Strategy**: Manual QA (no test infrastructure exists)

### Research Findings
- **75 GDScript files, 38+ scenes** analyzed
- **8 autoloads** currently: BuildRegistry, Inventory, ItemRegistry, GameState, SaveManager, DialogueManager, TipsManager, GameServices
- **21 instances** of `get_first_node_in_group()` across 15 files
- **Positive patterns to preserve**: StateMachine, signal-based communication, resource-driven data, component-based approach

### Metis Review
**Identified Gaps (addressed)**:
- Player node hardcoded as "Hana" in SaveManager → Guardrail: Keep name stable
- Groups used as public API → Document stable groups
- SaveManager's fragile find_child() → OUT OF SCOPE for this refactor
- Missing validation phase → Added Phase 0

---

## Work Objectives

### Core Objective
Simplify project structure by reducing autoload coupling and organizing files consistently following Godot best practices, enabling easier feature development and reduced coupling bugs.

### Concrete Deliverables
- `scripts/autoloads/registries.gd` - Consolidated ItemRegistry + BuildRegistry
- `scripts/autoloads/data_manager.gd` - Consolidated GameState + TipsManager (optional)
- `scenes/player/player.tscn` + `player.gd` - Relocated and co-located
- `scenes/world/world.tscn` + `world.gd` - Relocated and co-located
- `scenes/entities/buildables/{plants,buildings,resources}/` - Organized buildables
- `ui/` - Unified UI folder (merged scenes/ui/ into ui/)

### Definition of Done
- [ ] Zero Godot console errors on launch
- [ ] Full gameplay loop: Start → Build → Save → Quit → Load → Verify
- [ ] All autoloads registered in project.godot
- [ ] No "Orphan resource" or "missing dependency" warnings
- [ ] All existing save files still loadable (or documented as breaking)

### Must Have
- Backwards-compatible autoload APIs (old method calls still work)
- All group names preserved (planting_system, ui_layer, player, etc.)
- Signal signatures unchanged
- Node names "Hana" and "PlantingSystem" unchanged (SaveManager dependency)
- Git commit after each phase for rollback capability

### Must NOT Have (Guardrails)
- NO changes to SaveManager internals (find_child logic)
- NO changes to DialogueManager's registration pattern
- NO changes to scripts/components/ (StateMachine, State, etc.)
- NO new architectural patterns (DI containers, typed signals, etc.)
- NO method signature changes on autoloads
- NO renaming of player node "Hana" or "PlantingSystem"
- NO changes to resource paths in resources/items/, resources/buildables/

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: Manual-only
- **Framework**: None

### Manual QA Protocol

Each TODO includes specific verification steps. After each phase completion:

1. **Launch Verification**: Start Godot editor, open project, check console for errors
2. **Gameplay Loop Test**: Start Menu → New World → Build something → Save → Quit → Load → Verify state
3. **Build Menu Test**: Press Q, verify all 6 default buildables appear with correct icons
4. **Save/Load Test**: Create save, quit game, reload, verify player position and inventory

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Validation - Start Immediately):
└── Task 0: Validate assumptions and create baseline

Wave 1 (Coupling Reduction):
├── Task 1.1: Create Registries autoload (ItemRegistry + BuildRegistry)
└── Task 1.2: Create DataManager autoload (GameState + TipsManager) [OPTIONAL]

Wave 2 (Directory Structure - Sequential):
├── Task 2.1: Move player.tscn to scenes/player/
├── Task 2.2: Move world.tscn/world.gd to scenes/world/
└── Task 2.3: Organize buildables under scenes/entities/

Wave 3 (UI Consolidation):
└── Task 3.1: Merge UI folders
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 0 | None | 1.1, 1.2, 2.x | None (validation first) |
| 1.1 | 0 | 2.x | 1.2 |
| 1.2 | 0 | 2.x | 1.1 |
| 2.1 | 1.1, 1.2 | 2.2 | None |
| 2.2 | 2.1 | 2.3 | None |
| 2.3 | 2.2 | 3.1 | None |
| 3.1 | 2.3 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 0 | 0 | delegate_task(category="quick", load_skills=[], run_in_background=false) |
| 1 | 1.1, 1.2 | delegate_task(category="unspecified-low", load_skills=[], run_in_background=true) - parallel |
| 2 | 2.1, 2.2, 2.3 | delegate_task(category="quick", load_skills=[], run_in_background=false) - sequential |
| 3 | 3.1 | delegate_task(category="quick", load_skills=[], run_in_background=false) |

---

## TODOs

### Phase 0: Validation

- [ ] 0. Validate Assumptions and Create Baseline

  **What to do**:
  - Search for all references to `player.tscn` and `world.tscn` in codebase
  - Document current group names in use as "stable API"
  - Create a known-good save file for regression testing
  - Verify no external tools/mods reference file paths
  - Commit current state as "pre-refactor baseline"

  **Must NOT do**:
  - Modify any files
  - Change any code

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
    - No specialized skills needed for validation
  - **Skills Evaluated but Omitted**:
    - `git-master`: Simple commit, not needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 0 (standalone)
  - **Blocks**: All Phase 1 and 2 tasks
  - **Blocked By**: None

  **References**:
  
  **Pattern References**:
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/save_manager.gd:95-110` - Shows `find_child("Hana")` and `find_child("PlantingSystem")` usage
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/game_services.gd:15-25` - Shows group-based lookups

  **Validation Commands**:
  ```bash
  # Find all player.tscn references
  grep -r "player.tscn" --include="*.gd" --include="*.tscn" .
  
  # Find all world.tscn references  
  grep -r "world.tscn" --include="*.gd" --include="*.tscn" .
  
  # Find all group names in use
  grep -r "add_to_group\|get_first_node_in_group\|get_nodes_in_group" --include="*.gd" .
  ```

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify grep commands run without error
  grep -r "player.tscn" --include="*.gd" --include="*.tscn" . | head -20
  # Assert: Command completes (exit 0 or 1, not error)
  
  # Verify git status is clean or committed
  git status --porcelain
  # Assert: Either empty or shows committed state
  ```

  **Manual Verification**:
  1. Launch Godot editor with the project
  2. Create a new world, place 2-3 buildings, save
  3. Export save file path for future regression testing
  4. Verify console shows no errors

  **Evidence to Capture**:
  - [ ] List of all player.tscn references found
  - [ ] List of all world.tscn references found
  - [ ] List of group names (stable API documentation)
  - [ ] Save file created for regression testing

  **Commit**: YES
  - Message: `chore: document pre-refactor state for baseline`
  - Files: `.sisyphus/baseline/groups-api.md`, `.sisyphus/baseline/file-references.md`
  - Pre-commit: N/A (documentation only)

---

### Phase 1: Coupling Reduction

- [ ] 1.1. Create Consolidated Registries Autoload

  **What to do**:
  - Create `scripts/autoloads/registries.gd` that combines ItemRegistry and BuildRegistry functionality
  - Expose both APIs: `Registries.get_item(id)` for items, `Registries.get_buildable(id)` for buildables
  - Keep backward-compatible aliases: `ItemRegistry` and `BuildRegistry` still work via autoload aliases
  - Update `project.godot` to register Registries, keep ItemRegistry/BuildRegistry as aliases pointing to same script
  - Test that existing code still works without changes

  **Must NOT do**:
  - Change any caller code (63 Inventory references, 32 BuildRegistry references)
  - Change method signatures
  - Change resource loading paths

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: []
    - No specialized skills needed for GDScript refactoring
  - **Skills Evaluated but Omitted**:
    - `git-master`: Will use for commit but not specialized refactoring

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1.2)
  - **Blocks**: Phase 2 tasks
  - **Blocked By**: Task 0

  **References**:

  **Pattern References**:
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/item_registry.gd` - Current ItemRegistry implementation (load pattern, get_item method)
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/build_registry.gd` - Current BuildRegistry implementation (similar pattern)

  **API References**:
  - `/Users/eugene/Documents/Github Projects/LGD/project.godot` - Autoload registration format

  **Usage References** (to verify compatibility):
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/inventory.gd` - Uses ItemRegistry.get_item()
  - `/Users/eugene/Documents/Github Projects/LGD/ui/components/build_menu.gd` - Uses BuildRegistry

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify Registries.gd exists and has expected methods
  grep -q "func get_item" scripts/autoloads/registries.gd && echo "get_item exists"
  grep -q "func get_buildable" scripts/autoloads/registries.gd && echo "get_buildable exists"
  # Assert: Both outputs appear
  
  # Verify project.godot has Registries autoload
  grep -q "Registries" project.godot && echo "Registries registered"
  # Assert: Output appears
  ```

  **Manual Verification**:
  1. Launch game from Godot editor
  2. Verify console shows no errors on startup
  3. Open build menu (Q key), verify all 6 buildables appear with icons
  4. Place a tree, verify it spawns correctly
  5. Check inventory panel, verify items display correctly
  6. Save game, quit, reload - verify no errors

  **Evidence to Capture**:
  - [ ] Console output on launch (no errors)
  - [ ] Build menu screenshot showing all items
  - [ ] Save/load cycle completed successfully

  **Commit**: YES
  - Message: `refactor(autoloads): consolidate ItemRegistry and BuildRegistry into Registries`
  - Files: `scripts/autoloads/registries.gd`, `project.godot`
  - Pre-commit: Manual QA verification

---

- [ ] 1.2. Create Consolidated DataManager Autoload (OPTIONAL)

  **What to do**:
  - Create `scripts/autoloads/data_manager.gd` that combines GameState and TipsManager
  - Expose both APIs with clear namespacing: `DataManager.game_state.*`, `DataManager.tips.*`
  - OR keep as separate autoloads if key collision risk is high
  - Evaluate first: Check if GameState.story_flags and TipsManager keys could collide

  **Must NOT do**:
  - Proceed if key collision found (skip this task)
  - Change SaveManager's serialization logic
  - Change signal signatures

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1.1)
  - **Blocks**: Phase 2 tasks
  - **Blocked By**: Task 0

  **References**:

  **Pattern References**:
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/game_state.gd` - GameState implementation (story_flags, world signals)
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/tips_manager.gd` - TipsManager implementation

  **Usage References**:
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/autoloads/save_manager.gd` - Uses both for serialization

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # If consolidated, verify DataManager exists
  test -f scripts/autoloads/data_manager.gd && echo "DataManager created"
  
  # Verify project.godot updated
  grep -q "DataManager\|GameState" project.godot
  # Assert: At least one exists
  ```

  **Manual Verification**:
  1. Launch game, start new world
  2. Trigger a tip to appear (if tip system active)
  3. Progress story to set a flag
  4. Save game, quit, reload
  5. Verify tip state and story flags restored

  **Evidence to Capture**:
  - [ ] Decision: Consolidated or kept separate (document reason)
  - [ ] If consolidated: save/load verification passed

  **Commit**: YES (if changes made)
  - Message: `refactor(autoloads): consolidate GameState and TipsManager into DataManager`
  - Files: `scripts/autoloads/data_manager.gd`, `project.godot`
  - Pre-commit: Manual QA verification

---

### Phase 2: Directory Structure Reorganization

- [ ] 2.1. Move Player Scene to scenes/player/

  **What to do**:
  - Create `scenes/player/` directory
  - Use Godot editor's FileSystem dock to MOVE (not copy) `player.tscn` to `scenes/player/player.tscn`
  - Move any player-specific scripts with it (co-locate)
  - Godot will auto-update UIDs and most references
  - Manually verify and fix any broken preload() calls

  **Must NOT do**:
  - Rename the player node inside the scene (keep "Hana")
  - Change any player script logic
  - Use filesystem (mv command) - must use Godot editor

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None - simple file move operation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential)
  - **Blocks**: Task 2.2
  - **Blocked By**: Tasks 1.1, 1.2

  **References**:

  **Current Location**:
  - `/Users/eugene/Documents/Github Projects/LGD/player.tscn` - Current player scene (root level)
  - `/Users/eugene/Documents/Github Projects/LGD/scripts/player.gd` - Player script (in scripts/)

  **References to Update** (from validation phase):
  - Check validation output for list of files referencing player.tscn

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify player.tscn moved
  test -f scenes/player/player.tscn && echo "player.tscn moved"
  test ! -f player.tscn && echo "old location cleared"
  # Assert: Both outputs appear
  
  # Check for broken references
  grep -r "res://player.tscn" --include="*.gd" --include="*.tscn" .
  # Assert: No matches (or all updated to new path)
  ```

  **Manual Verification**:
  1. Open Godot editor, check FileSystem dock shows `scenes/player/player.tscn`
  2. Open world.tscn, verify player instance reference is valid (no red X)
  3. Launch game, verify player spawns correctly
  4. Move player around, verify movement works
  5. Save game, verify no errors in console

  **Evidence to Capture**:
  - [ ] FileSystem dock screenshot showing new location
  - [ ] Console output on launch (no errors)
  - [ ] Player movement verification

  **Commit**: YES
  - Message: `refactor(structure): move player.tscn to scenes/player/`
  - Files: `scenes/player/player.tscn`, `scenes/player/player.gd` (if moved)
  - Pre-commit: Manual QA verification

---

- [ ] 2.2. Move World Scene to scenes/world/

  **What to do**:
  - Create `scenes/world/` directory
  - Use Godot editor to MOVE `scenes/world.tscn` to `scenes/world/world.tscn`
  - Move `world.gd` from root to `scenes/world/world.gd`
  - Update script reference in world.tscn if needed
  - Update `project.godot` if world.tscn is referenced there

  **Must NOT do**:
  - Rename "PlantingSystem" node
  - Change world.gd logic
  - Break SaveManager's scene lookups

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential)
  - **Blocks**: Task 2.3
  - **Blocked By**: Task 2.1

  **References**:

  **Current Locations**:
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/world.tscn`
  - `/Users/eugene/Documents/Github Projects/LGD/world.gd` - In root!

  **References to Update**:
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/start_menu/world_list_panel.gd` - Uses `change_scene_to_file("res://scenes/world.tscn")`
  - Check validation output for complete list

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify world files moved
  test -f scenes/world/world.tscn && echo "world.tscn moved"
  test -f scenes/world/world.gd && echo "world.gd moved"
  test ! -f world.gd && echo "root world.gd cleared"
  # Assert: All three outputs appear
  ```

  **Manual Verification**:
  1. Open Godot editor, verify FileSystem shows `scenes/world/` with both files
  2. Open world.tscn, verify script attachment is valid
  3. From start menu, click Play → select world → verify world loads
  4. Verify PlantingSystem node exists and functions
  5. Place a building, verify placement works
  6. Save and load game

  **Evidence to Capture**:
  - [ ] FileSystem dock screenshot
  - [ ] World load from start menu successful
  - [ ] Building placement working
  - [ ] Save/load cycle passed

  **Commit**: YES
  - Message: `refactor(structure): move world scene to scenes/world/`
  - Files: `scenes/world/world.tscn`, `scenes/world/world.gd`
  - Pre-commit: Manual QA verification

---

- [ ] 2.3. Organize Buildables Under scenes/entities/

  **What to do**:
  - Create directory structure:
    ```
    scenes/entities/
    ├── buildables/
    │   ├── plants/        # mushroom_plant, dandelion, tree
    │   ├── buildings/     # mushroom_house, processor_building
    │   └── resources/     # stone_deposit, barrel
    └── npcs/              # Move existing scenes/npcs/ here
    ```
  - Move buildable scenes to appropriate subdirectories
  - Update all preload() and load() references
  - Update BuildRegistry resource paths if hardcoded

  **Must NOT do**:
  - Change buildable scene internal structure
  - Change .tres resource file locations (keep in resources/buildables/)
  - Rename any scene files

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential)
  - **Blocks**: Task 3.1
  - **Blocked By**: Task 2.2

  **References**:

  **Files to Move**:
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/tree.tscn` → `scenes/entities/buildables/plants/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/mushroom_plant.tscn` → `scenes/entities/buildables/plants/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/dandelion.tscn` → `scenes/entities/buildables/plants/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/mushroom_house.tscn` → `scenes/entities/buildables/buildings/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/processor_building.tscn` → `scenes/entities/buildables/buildings/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/stone_deposit.tscn` → `scenes/entities/buildables/resources/`
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/barrel.tscn` → `scenes/entities/buildables/resources/`

  **Resource Files** (scene_path property to update):
  - `/Users/eugene/Documents/Github Projects/LGD/resources/buildables/*.tres` - Each has a scene_path property

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify directory structure created
  test -d scenes/entities/buildables/plants && echo "plants dir exists"
  test -d scenes/entities/buildables/buildings && echo "buildings dir exists"
  test -d scenes/entities/buildables/resources && echo "resources dir exists"
  # Assert: All three outputs appear
  
  # Verify key files moved
  test -f scenes/entities/buildables/plants/tree.tscn && echo "tree moved"
  test -f scenes/entities/buildables/buildings/mushroom_house.tscn && echo "mushroom_house moved"
  # Assert: Both outputs appear
  ```

  **Manual Verification**:
  1. Open Godot editor, verify new directory structure
  2. Open build menu (Q), verify all 6 buildables show
  3. Place each type of buildable (plant, building, resource)
  4. Verify each spawns correctly with proper visuals
  5. Interact with mushroom_house, verify rat spawning works
  6. Save and load game

  **Evidence to Capture**:
  - [ ] FileSystem dock screenshot of new structure
  - [ ] Build menu showing all items
  - [ ] Each buildable type placed and verified

  **Commit**: YES
  - Message: `refactor(structure): organize buildables under scenes/entities/`
  - Files: All moved scenes, updated .tres files
  - Pre-commit: Manual QA verification

---

### Phase 3: UI Consolidation

- [ ] 3.1. Merge UI Folders

  **What to do**:
  - Move contents of `scenes/ui/` into `ui/` (if any exist)
  - Decide on start_menu location: keep in `scenes/start_menu/` (it's a full scene, not a component)
  - Ensure UI components are in `ui/components/`
  - Update any references to moved files

  **Must NOT do**:
  - Move start_menu to ui/ (it's a scene, not a component)
  - Change any UI logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final)
  - **Blocks**: None
  - **Blocked By**: Task 2.3

  **References**:

  **Current Structure**:
  - `/Users/eugene/Documents/Github Projects/LGD/ui/` - Main UI folder (13 components)
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/ui/` - Secondary UI (ui.tscn main HUD)
  - `/Users/eugene/Documents/Github Projects/LGD/scenes/start_menu/` - Start menu scenes

  **Target Structure**:
  ```
  ui/
  ├── components/          # Reusable widgets
  ├── hud/                 # Main game HUD (from scenes/ui/)
  ├── pause_menu.tscn
  ├── processor_menu.tscn
  └── ...
  scenes/
  └── start_menu/          # Keep separate (full scene, not component)
  ```

  **Acceptance Criteria**:

  **Automated Verification (via Bash)**:
  ```bash
  # Verify scenes/ui/ is empty or removed
  test ! -d scenes/ui || test -z "$(ls -A scenes/ui 2>/dev/null)" && echo "scenes/ui cleared"
  
  # Verify ui/ has expected content
  test -f ui/components/dialogue_box.tscn && echo "dialogue_box in place"
  # Assert: Both outputs appear
  ```

  **Manual Verification**:
  1. Launch game from start menu
  2. Start new world, verify HUD appears (hotbar, portrait)
  3. Open inventory (I key), verify inventory panel
  4. Open build menu (Q key), verify build menu
  5. Press ESC, verify pause menu
  6. Open dialogue (interact with NPC if available)
  7. Full save/load cycle

  **Evidence to Capture**:
  - [ ] All UI elements functioning
  - [ ] No console errors
  - [ ] FileSystem dock showing clean structure

  **Commit**: YES
  - Message: `refactor(structure): consolidate UI folders`
  - Files: All moved UI files
  - Pre-commit: Manual QA verification

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0 | `chore: document pre-refactor state for baseline` | `.sisyphus/baseline/*` | N/A |
| 1.1 | `refactor(autoloads): consolidate ItemRegistry and BuildRegistry into Registries` | `scripts/autoloads/registries.gd`, `project.godot` | Build menu test |
| 1.2 | `refactor(autoloads): consolidate GameState and TipsManager into DataManager` | `scripts/autoloads/data_manager.gd`, `project.godot` | Save/load test |
| 2.1 | `refactor(structure): move player.tscn to scenes/player/` | `scenes/player/*` | Player movement |
| 2.2 | `refactor(structure): move world scene to scenes/world/` | `scenes/world/*` | World load test |
| 2.3 | `refactor(structure): organize buildables under scenes/entities/` | `scenes/entities/**` | Build menu + placement |
| 3.1 | `refactor(structure): consolidate UI folders` | `ui/**` | Full UI test |

---

## Success Criteria

### Verification Commands
```bash
# Check for any remaining root-level scenes (should only have project.godot, .gitignore, etc.)
ls -la *.tscn 2>/dev/null || echo "No root scenes - PASS"

# Check new structure exists
ls scenes/player/ scenes/world/ scenes/entities/buildables/ ui/components/

# Verify no broken references (run in Godot console or check editor)
# Editor should show no red X icons on any scene nodes
```

### Final Checklist
- [ ] All "Must Have" requirements present
- [ ] All "Must NOT Have" guardrails respected
- [ ] Zero Godot console errors
- [ ] Full gameplay loop verified: Start → Build → Save → Load → Verify
- [ ] All 5 (or 6) autoloads registered and functional
- [ ] Git history shows clean, atomic commits for each phase
- [ ] No orphaned files or broken references
