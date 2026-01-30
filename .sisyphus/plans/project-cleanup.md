# LGD Project Cleanup

## TL;DR

> **Quick Summary**: Remove orphaned/duplicate files from the LGD Godot project that were left behind during a folder reorganization, plus delete test files and investigate autoload configuration.
> 
> **Deliverables**:
> - Delete 3 broken orphan scene files
> - Delete 1 orphan root script
> - Delete 2-4 orphan IO indicator scripts
> - Delete tests folder
> - Investigate and document autoload anomaly
> - Verified working game after cleanup
> 
> **Estimated Effort**: Short (< 1 hour)
> **Parallel Execution**: NO - sequential (each step requires verification before proceeding)
> **Critical Path**: Git Safety → Scenes → Script → Tests → Verification

---

## Context

### Original Request
User requested analysis and cleanup of the project to remove duplication and irrelevant code not used in the game.

### Interview Summary
**Key Discussions**:
- Scope: Code only (no asset cleanup)
- Test files: Remove ALL tests
- Verification: Manual game testing after cleanup
- Autoload anomaly: User unsure, include investigation

**Research Findings**:
- Project underwent folder reorganization; old files remain in root and `/scripts/`
- 3 orphan scenes in `/scenes/` reference scripts that don't exist at their expected paths
- Root `world.gd` is a stale duplicate of `/scenes/world/world.gd`
- IO indicator scripts (`io_indicators.gd`, `IOIndicatorComponent.gd`) have no scene references
- 3 autoloads point to same script (DataManager, GameState, TipsManager → data_manager.gd)

### Metis Review
**Identified Gaps** (addressed):
- File list correction: `/scripts/mushroom_house.gd`, `/scripts/tree.gd`, `/scripts/stone_deposit.gd` DON'T EXIST
- Missing guardrail: Create git commit before any deletions
- Missing guardrail: Delete `.gd.uid` files alongside `.gd` files
- Edge case: Editor cache may have stale references after deletion

---

## Work Objectives

### Core Objective
Remove orphaned and duplicate code from the LGD project to reduce complexity and eliminate confusion from stale files.

### Concrete Deliverables
- 3 orphan scenes deleted: `/scenes/mushroom_house.tscn`, `/scenes/stone_deposit.tscn`, `/scenes/tree.tscn`
- 1 orphan root script deleted: `/world.gd` (and `.uid` if exists)
- 2-4 orphan IO scripts deleted: `/scripts/visuals/io_indicators.gd`, `/scripts/components/IOIndicatorComponent.gd`
- Test folder deleted: `/tests/`
- Autoload configuration documented with recommendation
- Game verified working

### Definition of Done
- [ ] `godot --headless --path . --check-only 2>&1 | grep -i error` returns empty (no errors)
- [ ] Game launches and reaches start menu without errors
- [ ] World scene loads and is playable
- [ ] No orphaned files remain in root or `/scripts/` that aren't actively used

### Must Have
- Git safety commit before any deletions
- Verification after each deletion group
- Documentation of autoload investigation findings

### Must NOT Have (Guardrails)
- Do NOT touch `/scenes/entities/` (these are the REAL/active files)
- Do NOT touch `/scenes/world/` (this contains the ACTIVE world.gd)
- Do NOT modify `/resources/` 
- Do NOT modify autoloads without explicit user decision
- Do NOT reorganize or rename files - DELETE ONLY
- Do NOT touch assets (sprites, fonts, images)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (Godot project, no automated test framework)
- **User wants tests**: Manual verification
- **Framework**: None

### Manual Verification Procedure

After each deletion group:

1. **Automated Check** (agent runs):
   ```bash
   godot --headless --path /Users/eugene/Documents/Github\ Projects/LGD --check-only 2>&1 | grep -i error
   ```
   Expected: Empty output (no errors)

2. **Manual Game Test** (agent launches, user verifies):
   - Launch game via `godot_run_project`
   - Start menu appears without errors
   - New game loads world scene
   - Build menu shows items correctly

---

## Execution Strategy

### Sequential Execution (Required)

```
Step 0: Git Safety Checkpoint
    ↓
Step 1: Delete Orphan Scenes (3 files)
    ↓ verify
Step 2: Delete Orphan Root Script (1-2 files)
    ↓ verify
Step 3: Delete Orphan IO Scripts (2-4 files)
    ↓ verify  
Step 4: Delete Tests Folder
    ↓ verify
Step 5: Investigate Autoloads
    ↓
Step 6: Final Verification & Commit
```

**Why Sequential**: Each deletion must be verified before proceeding. If a deletion breaks something, we need to know WHICH deletion caused it.

---

## TODOs

- [ ] 0. Git Safety Checkpoint

  **What to do**:
  - Commit current state with message "chore: pre-cleanup checkpoint"
  - This creates a safe rollback point before any deletions

  **Must NOT do**:
  - Do not push to remote yet
  - Do not include any code changes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single git command, trivial task
  - **Skills**: [`git-master`]
    - `git-master`: Git operations expertise

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Step 0)
  - **Blocks**: All subsequent tasks
  - **Blocked By**: None

  **References**:
  - `project.godot` - Verify current state
  - `.git/` - Git repository

  **Acceptance Criteria**:
  ```bash
  # Verify commit exists
  git log -1 --oneline | grep "pre-cleanup"
  # Assert: Shows the checkpoint commit
  ```

  **Commit**: YES
  - Message: `chore: pre-cleanup checkpoint`
  - Files: All current changes
  - Pre-commit: None

---

- [ ] 1. Delete Orphan Scene Files

  **What to do**:
  - Delete `/scenes/mushroom_house.tscn`
  - Delete `/scenes/stone_deposit.tscn`
  - Delete `/scenes/tree.tscn`
  - These are broken scenes that reference scripts at incorrect paths

  **Must NOT do**:
  - Do NOT touch `/scenes/entities/buildables/` (those are the REAL scenes)
  - Do NOT delete any `.gd` files in this step

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file deletion
  - **Skills**: [`git-master`]
    - `git-master`: For staging deletions properly

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Step 1)
  - **Blocks**: Task 2
  - **Blocked By**: Task 0

  **References**:
  **Files to delete** (verified broken):
  - `/scenes/mushroom_house.tscn` - Orphan scene, references non-existent script path
  - `/scenes/stone_deposit.tscn` - Orphan scene, references non-existent script path
  - `/scenes/tree.tscn` - Orphan scene, references non-existent script path

  **Files to preserve** (active versions):
  - `/scenes/entities/buildables/buildings/mushroom_house.tscn` - ACTIVE
  - `/scenes/entities/buildables/resources/stone_deposit.tscn` - ACTIVE
  - `/scenes/entities/buildables/plants/tree.tscn` - ACTIVE

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Verify files are deleted
  ls scenes/mushroom_house.tscn scenes/stone_deposit.tscn scenes/tree.tscn 2>&1
  # Assert: "No such file or directory" for all three

  # Agent runs: Verify active files still exist
  ls scenes/entities/buildables/buildings/mushroom_house.tscn
  ls scenes/entities/buildables/resources/stone_deposit.tscn
  ls scenes/entities/buildables/plants/tree.tscn
  # Assert: All three exist (exit code 0)

  # Agent runs: Godot project check
  godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
  # Assert: Empty output (no errors)
  ```

  **Commit**: NO (groups with final commit)

---

- [ ] 2. Delete Orphan Root Script

  **What to do**:
  - Delete `/world.gd` (root directory)
  - Delete `/world.gd.uid` if it exists
  - This is a stale duplicate; the active version is at `/scenes/world/world.gd`

  **Must NOT do**:
  - Do NOT touch `/scenes/world/world.gd` (that's the ACTIVE version!)
  - Do NOT modify `world.tscn`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file deletion
  - **Skills**: [`git-master`]
    - `git-master`: For staging deletions properly

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Step 2)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  **File to delete** (verified stale):
  - `/world.gd` - Root-level duplicate with outdated coordinates

  **File to preserve** (active version):
  - `/scenes/world/world.gd` - ACTIVE, used by world.tscn

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Verify root file deleted
  ls world.gd 2>&1
  # Assert: "No such file or directory"

  # Agent runs: Verify active version still exists
  ls scenes/world/world.gd
  # Assert: File exists (exit code 0)

  # Agent runs: Godot project check
  godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
  # Assert: Empty output (no errors)
  ```

  **Commit**: NO (groups with final commit)

---

- [ ] 3. Delete Orphan IO Indicator Scripts

  **What to do**:
  - Search for and delete `/scripts/visuals/io_indicators.gd` (and `.uid` if exists)
  - Search for and delete `/scripts/components/IOIndicatorComponent.gd` (and `.uid` if exists)
  - These scripts have no scene references and are not used

  **Must NOT do**:
  - Do not delete any component scripts that ARE referenced in scenes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file deletion with verification
  - **Skills**: [`git-master`]
    - `git-master`: For staging deletions properly

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Step 3)
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:
  **Files to delete** (verified orphaned):
  - `/scripts/visuals/io_indicators.gd` - No scene references found
  - `/scripts/components/IOIndicatorComponent.gd` - Class defined but never instantiated

  **Pre-deletion verification**:
  - Run: `grep -r "io_indicators" --include="*.tscn" --include="*.gd" .`
  - Run: `grep -r "IOIndicatorComponent" --include="*.tscn" --include="*.gd" .`
  - Both should return empty or only self-references

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Pre-deletion check (should be empty or self-reference only)
  grep -r "io_indicators" --include="*.tscn" . | grep -v "scripts/visuals/io_indicators.gd"
  # Assert: Empty output

  # Agent runs: After deletion - files gone
  ls scripts/visuals/io_indicators.gd scripts/components/IOIndicatorComponent.gd 2>&1
  # Assert: "No such file or directory" for both

  # Agent runs: Godot project check
  godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
  # Assert: Empty output (no errors)
  ```

  **Commit**: NO (groups with final commit)

---

- [ ] 4. Delete Tests Folder

  **What to do**:
  - Delete entire `/tests/` directory
  - User explicitly requested removal of ALL test files

  **Must NOT do**:
  - Do not leave any test files behind

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple directory deletion
  - **Skills**: [`git-master`]
    - `git-master`: For staging deletions properly

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Step 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 3

  **References**:
  **Directory to delete**:
  - `/tests/` - Contains `test_inventory_start.gd` and potentially other test files

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Verify directory deleted
  ls tests/ 2>&1
  # Assert: "No such file or directory"

  # Agent runs: Godot project check
  godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
  # Assert: Empty output (no errors)
  ```

  **Commit**: NO (groups with final commit)

---

- [ ] 5. Investigate Autoload Configuration

  **What to do**:
  - Read `project.godot` autoload section
  - Document that `DataManager`, `GameState`, `TipsManager` all point to `data_manager.gd`
  - Read `data_manager.gd` to understand if it provides multiple singletons or if this is a mistake
  - Create a brief report with recommendation (fix or leave as-is)
  - Do NOT modify anything - investigation only

  **Must NOT do**:
  - Do NOT modify `project.godot`
  - Do NOT modify any autoload scripts
  - Do NOT make changes without explicit user approval

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Investigation task, reading and analysis
  - **Skills**: []
    - No special skills needed, just file reading

  **Parallelization**:
  - **Can Run In Parallel**: YES (could run parallel with Task 4)
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6 (final report)
  - **Blocked By**: Task 3

  **References**:
  **Files to investigate**:
  - `project.godot` - Contains autoload definitions at `[autoload]` section
  - `scripts/autoloads/data_manager.gd` - The script all three autoloads reference

  **Expected investigation output**:
  - Is `data_manager.gd` designed to be accessed via multiple names?
  - Are `GameState` and `TipsManager` used anywhere in the codebase?
  - Recommendation: Keep as-is, consolidate, or split into separate scripts

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Find usages of each autoload name
  grep -r "DataManager\." --include="*.gd" . | wc -l
  grep -r "GameState\." --include="*.gd" . | wc -l  
  grep -r "TipsManager\." --include="*.gd" . | wc -l
  # Document: Usage counts for each

  # Investigation complete when:
  # - All three usage patterns documented
  # - Recommendation documented with rationale
  # - User informed of findings
  ```

  **Commit**: NO (investigation only, no file changes)

---

- [ ] 6. Final Verification & Commit

  **What to do**:
  - Run Godot headless check to verify no errors
  - Launch game and verify:
    - Start menu loads
    - New game works
    - World scene is playable
    - Build menu shows correct items
  - If all passes, commit all deletions with appropriate message

  **Must NOT do**:
  - Do not commit if verification fails
  - Do not push to remote without user approval

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification and git commit
  - **Skills**: [`git-master`]
    - `git-master`: For proper commit creation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Final step)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 4, 5

  **References**:
  - All previously deleted files (for commit message)
  - `project.godot` - Main scene for launch test

  **Acceptance Criteria**:
  ```bash
  # Agent runs: Final Godot check
  godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
  # Assert: Empty output

  # Agent runs: Launch game for verification
  # Use godot_run_project tool, observe for ~10 seconds
  # Manual verification: Start menu appears, no error dialogs

  # Agent runs: Commit the cleanup
  git add -A && git commit -m "chore: remove orphaned and duplicate files

  Deleted:
  - scenes/mushroom_house.tscn (orphan)
  - scenes/stone_deposit.tscn (orphan)
  - scenes/tree.tscn (orphan)
  - world.gd (duplicate of scenes/world/world.gd)
  - scripts/visuals/io_indicators.gd (unused)
  - scripts/components/IOIndicatorComponent.gd (unused)
  - tests/ directory (per user request)
  "
  
  git log -1 --oneline
  # Assert: Shows cleanup commit
  ```

  **Commit**: YES
  - Message: `chore: remove orphaned and duplicate files`
  - Files: All staged deletions
  - Pre-commit: Godot check passes

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0 | `chore: pre-cleanup checkpoint` | Current state | None |
| 6 | `chore: remove orphaned and duplicate files` | All deletions | Godot --check-only |

---

## Success Criteria

### Verification Commands
```bash
# Project has no errors
godot --headless --path "/Users/eugene/Documents/Github Projects/LGD" --check-only 2>&1 | grep -i error
# Expected: Empty output

# Deleted files are gone
ls world.gd scenes/mushroom_house.tscn tests/ 2>&1
# Expected: "No such file or directory" for all

# Active files still exist
ls scenes/world/world.gd scenes/entities/buildables/buildings/mushroom_house.tscn
# Expected: Both exist (exit code 0)

# Git history shows both commits
git log --oneline -3
# Expected: Shows cleanup and checkpoint commits
```

### Final Checklist
- [ ] All orphan scenes deleted (3 files)
- [ ] Root world.gd deleted (1 file)
- [ ] Orphan IO scripts deleted (2-4 files)
- [ ] Tests folder deleted
- [ ] Autoload investigation documented
- [ ] Game launches and runs without errors
- [ ] Git commits in place (checkpoint + cleanup)
