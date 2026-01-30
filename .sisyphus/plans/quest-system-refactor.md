# Quest System Refactor: Dialogue Integration & Persistent Unlock Conditions

## TL;DR

> **Quick Summary**: Refactor the quest system to support item deposits with partial progress persistence, unlock conditions (item/quest/dialogue/flag-based), and seamless NPC dialogue integration via action menus.
> 
> **Deliverables**:
> - `QuestCondition` resource for unlock prerequisites
> - Enhanced `QuestResource` with conditions, NPC association, and state tracking
> - Refactored `QuestManager` with LOCKED/UNLOCKED/ACTIVE/COMPLETED states
> - New `QuestDepositPanel` UI (replaces QuestTurnInPanel)
> - NPC integration showing/hiding quest actions based on state
> - Full persistence of deposit progress and unlock states
> 
> **Estimated Effort**: Large (8-12 tasks, multi-day)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 5 → Task 7 → Task 9

---

## Context

### Original Request
Refactor the quest system to work seamlessly with the dialogue system with slots for quests so that if a quest requires items, it can be submitted by the user properly and also allow quests to properly become unlocked when certain conditions have been met that persist across sessions like collecting a certain item, completing other quests, etc.

### Interview Summary
**Key Discussions**:
- **Panel behavior**: Separate deposit panel (not blocking dialogue), can be exited anytime
- **Partial deposits**: YES - deposit 50 shrooms now, 50 more tomorrow, persists across sessions
- **Item retrieval**: NO - once deposited, items are committed (immediate removal)
- **Panel trigger**: NPC action menu (e.g., "Help" or "Quest" option)
- **Multi-quest NPCs**: One quest per NPC at a time
- **Quest completion flow**: Panel closes → NPC auto-triggers reward dialogue
- **Post-completion**: Quest action hides from NPC menu
- **Condition logic**: Flat list with single AND/OR operator
- **Quest-NPC association**: Quest knows NPC (QuestResource.npc_id)
- **Condition evaluation**: Reactive (signal-based - fires on item added, dialogue finished, flag set)

**Research Findings**:
- Current `QuestManager` is missing core methods (`start_quest`, `complete_quest`, etc.) - must restore
- `DialogueManager.has_shown()` already tracks seen dialogues
- `DataManager` (GameState) already handles story flags with `get_flag()`/`set_flag()`
- `Registries` uses reactive unlock pattern - reference for condition architecture
- `NPCAction` has `requires_flag` and `disabled_if_flag` - pattern for visibility
- Existing `QuestTurnInPanel` uses `QuestInputInventory` bridge for slot management

### Metis Review
**Identified Gaps** (addressed):
- Must restore missing QuestManager methods before refactoring
- Use reactive architecture like Registries (signal-based condition evaluation)
- Follow NPCAction.requires_flag pattern for action visibility
- AND/OR operator applies to entire condition list (single operator mode)
- Edge case: inventory full during reward → log warning, prevent completion
- Edge case: invalid condition ID → log warning, return false

---

## Work Objectives

### Core Objective
Create a robust quest system with data-driven unlock conditions, partial deposit persistence, and seamless NPC dialogue integration.

### Concrete Deliverables
1. `scripts/resources/quest_condition.gd` - New resource for unlock conditions
2. `scripts/resources/quest_resource.gd` - Enhanced with conditions, npc_id, state
3. `scripts/autoloads/quest_manager.gd` - Refactored with state machine
4. `ui/components/quest_deposit_panel.gd` - New deposit panel
5. `ui/components/quest_deposit_panel.tscn` - Scene file
6. `scripts/npc/npc_base.gd` - Quest action integration
7. `resources/quests/test_quest.tres` - Example quest for testing

### Definition of Done
- [ ] Quest can be locked until conditions met (item in inventory, quest completed, dialogue seen, story flag)
- [ ] Quest unlocks reactively when conditions are satisfied
- [ ] Player can deposit items partially across multiple sessions
- [ ] Deposited items cannot be retrieved
- [ ] Quest completes when all required items deposited
- [ ] Completion auto-triggers reward dialogue
- [ ] Quest action hidden from NPC menu after completion
- [ ] All states persist through save/load

### Must Have
- Quest states: LOCKED → UNLOCKED → ACTIVE → COMPLETED
- Condition types: has_item, quest_completed, dialogue_seen, has_flag
- Flat condition list with single AND/OR operator per quest
- Reactive condition evaluation (signal-based)
- Partial deposit persistence
- Immediate item removal on deposit

### Must NOT Have (Guardrails)
- Quest log/journal UI
- Quest chains (use story flags if needed)
- Quest timers or expiration
- Quest abandonment/cancellation
- Item retrieval after deposit
- Nested condition logic (only flat AND/OR)
- Quest markers/waypoints
- Multiple active quests from same NPC
- Complex condition operators (>=, <, !=, etc.)
- Progress bars or animations beyond slot fill states
- Migration of existing "build_base" quest

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: NO (manual in-game)
- **Framework**: None
- **QA approach**: Manual verification via Godot execution

### Manual Verification Protocol

Each TODO includes verification steps the agent can execute:
1. Launch game via Godot CLI or editor
2. Use debug console commands to set game state
3. Interact with NPCs and verify UI behavior
4. Save/load and verify persistence
5. Check debug output for expected signals/logs

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Restore QuestManager missing methods
└── Task 2: Create QuestCondition resource

Wave 2 (After Wave 1):
├── Task 3: Enhance QuestResource with conditions/state
├── Task 4: Refactor QuestManager state machine
└── Task 5: Create QuestDepositPanel UI

Wave 3 (After Wave 2):
├── Task 6: Integrate NPC action visibility
├── Task 7: Implement persistence
└── Task 8: Create test quest and verify end-to-end

Wave 4 (Final):
└── Task 9: Cleanup deprecated code
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4 | 2 |
| 2 | None | 3, 4 | 1 |
| 3 | 1, 2 | 4, 5, 6 | None |
| 4 | 1, 2, 3 | 5, 6, 7 | None |
| 5 | 3 | 6, 8 | 4 |
| 6 | 4, 5 | 8 | 7 |
| 7 | 4 | 8 | 6 |
| 8 | 5, 6, 7 | 9 | None |
| 9 | 8 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Approach |
|------|-------|---------------------|
| 1 | 1, 2 | Run in parallel - independent foundational work |
| 2 | 3, 4, 5 | Task 3 first, then 4 and 5 can parallelize |
| 3 | 6, 7, 8 | Task 6, 7 parallel, then 8 |
| 4 | 9 | Final cleanup |

---

## TODOs

- [ ] 1. Restore QuestManager Missing Methods

  **What to do**:
  - Check git history for `quest_manager.gd` to find missing methods
  - Restore: `start_quest()`, `complete_quest()`, `is_quest_active()`, `is_quest_completed()`
  - Restore: `to_save_data()`, `from_save_data()`, `check_quest_progress()`
  - Verify all current callers still work after restoration
  - Run game to ensure no regressions

  **Must NOT do**:
  - Modify method signatures that would break existing callers
  - Add new functionality yet - just restore what was lost

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Git history recovery is a focused, low-complexity task
  - **Skills**: [`git-master`]
    - `git-master`: Need git log/blame/checkout to recover lost code

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4
  - **Blocked By**: None

  **References**:
  - `scripts/autoloads/quest_manager.gd` - Current file to restore
  - `scripts/npcs/glider.gd` - Calls quest methods, verify compatibility
  - `scripts/autoloads/save_manager.gd:133` - Calls `QuestManager.to_save_data()`

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -n "func start_quest" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (method exists)
  
  grep -n "func complete_quest" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (method exists)
  
  grep -n "func to_save_data" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (method exists)
  ```

  **Commit**: YES
  - Message: `fix(quests): restore missing QuestManager methods from git history`
  - Files: `scripts/autoloads/quest_manager.gd`

---

- [ ] 2. Create QuestCondition Resource

  **What to do**:
  - Create new resource `scripts/resources/quest_condition.gd`
  - Define condition types enum: `HAS_ITEM`, `QUEST_COMPLETED`, `DIALOGUE_SEEN`, `HAS_FLAG`
  - Export properties:
    - `condition_type: ConditionType`
    - `target_id: String` (item ID, quest ID, dialogue ID, or flag name)
    - `required_count: int = 1` (for HAS_ITEM, how many needed)
  - Implement `is_met() -> bool` method that checks current game state
  - Use existing systems: `Inventory.has_item()`, `QuestManager.is_quest_completed()`, `DialogueManager.has_shown()`, `GameState.get_flag()`

  **Must NOT do**:
  - Add complex operators (>=, <, !=)
  - Add nested condition groups
  - Add caching (evaluate fresh each time)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single resource file creation with clear requirements
  - **Skills**: []
    - No special skills needed - straightforward GDScript

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 3, 4
  - **Blocked By**: None

  **References**:
  - `scripts/resources/quest_resource.gd` - Existing resource pattern to follow
  - `scripts/autoloads/inventory.gd:has_item()` - Method for HAS_ITEM check
  - `scripts/autoloads/dialogue_manager.gd:has_shown()` - Method for DIALOGUE_SEEN check
  - `scripts/autoloads/data_manager.gd:get_flag()` - Method for HAS_FLAG check (note: aliased as GameState)
  - `scripts/autoloads/registries.gd:188-210` - `_check_complex_unlocks()` pattern for condition logic

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  test -f scripts/resources/quest_condition.gd && echo "EXISTS"
  # Assert: Output is "EXISTS"
  
  grep -n "enum ConditionType" scripts/resources/quest_condition.gd
  # Assert: Returns line number (enum exists)
  
  grep -n "func is_met" scripts/resources/quest_condition.gd
  # Assert: Returns line number (method exists)
  ```

  **Commit**: YES
  - Message: `feat(quests): add QuestCondition resource for unlock prerequisites`
  - Files: `scripts/resources/quest_condition.gd`

---

- [ ] 3. Enhance QuestResource with Conditions and State

  **What to do**:
  - Add to `scripts/resources/quest_resource.gd`:
    - `@export var npc_id: String` - Which NPC offers this quest
    - `@export var unlock_conditions: Array[QuestCondition] = []`
    - `@export var condition_operator: String = "AND"` - "AND" or "OR"
    - `@export var reward_dialogue_id: String` - Dialogue to play on completion
  - Add method `are_conditions_met() -> bool`:
    - If operator is "AND": all conditions must be met
    - If operator is "OR": at least one condition must be met
    - Empty conditions array = always met (no prerequisites)
  - Keep existing `required_items` and `rewards` properties

  **Must NOT do**:
  - Remove or rename existing properties
  - Add state tracking to resource (state lives in QuestManager)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Extending existing resource with new exports
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (needs Task 1, 2 complete)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `scripts/resources/quest_resource.gd` - File to modify
  - `scripts/resources/quest_condition.gd` - Condition resource created in Task 2
  - `scripts/resources/dialogue_resource.gd:12-18` - Pattern for exported arrays

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -n "@export var npc_id" scripts/resources/quest_resource.gd
  # Assert: Returns line number
  
  grep -n "@export var unlock_conditions" scripts/resources/quest_resource.gd
  # Assert: Returns line number
  
  grep -n "func are_conditions_met" scripts/resources/quest_resource.gd
  # Assert: Returns line number
  ```

  **Commit**: YES
  - Message: `feat(quests): add unlock conditions and NPC association to QuestResource`
  - Files: `scripts/resources/quest_resource.gd`

---

- [ ] 4. Refactor QuestManager State Machine

  **What to do**:
  - Add quest state enum: `LOCKED`, `UNLOCKED`, `ACTIVE`, `COMPLETED`
  - Refactor internal tracking:
    - `_quest_states: Dictionary = {}` - {quest_id: state}
    - `_quest_deposits: Dictionary = {}` - {quest_id: {item_id: count}}
  - Implement reactive condition evaluation:
    - Connect to signals: `Inventory.item_added`, `DialogueManager.dialogue_finished`, `GameState.flag_changed`, `quest_completed`
    - On signal: re-evaluate conditions for all LOCKED quests
    - If conditions met: transition to UNLOCKED
  - Add methods:
    - `get_quest_state(quest_id) -> int`
    - `unlock_quest(quest_id)` - LOCKED → UNLOCKED
    - `activate_quest(quest_id)` - UNLOCKED → ACTIVE (called when player opens deposit panel)
    - `deposit_item(quest_id, item_id, count)` - Add to deposits
    - `get_deposits(quest_id) -> Dictionary`
    - `check_quest_completion(quest_id) -> bool`
  - Emit signals: `quest_unlocked`, `quest_activated`, `quest_completed`

  **Must NOT do**:
  - Remove existing methods (keep backward compatibility where possible)
  - Add polling/timer-based condition checks
  - Handle rewards here (NPC dialogue handles rewards)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core system refactor with state machine, signals, and persistence
  - **Skills**: []
    - No special skills needed - core GDScript architecture work

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (critical path)
  - **Blocks**: Tasks 5, 6, 7
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - `scripts/autoloads/quest_manager.gd` - File to refactor
  - `scripts/autoloads/registries.gd:45-60` - Signal connection pattern for reactive unlocks
  - `scripts/autoloads/registries.gd:240-246` - `_check_complex_unlocks()` condition evaluation pattern
  - `scripts/autoloads/inventory.gd` - Has `item_added` signal to connect
  - `scripts/autoloads/dialogue_manager.gd` - Has `dialogue_finished` signal
  - `scripts/autoloads/data_manager.gd` - May need to add `flag_changed` signal

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -n "enum.*LOCKED" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (state enum exists)
  
  grep -n "signal quest_unlocked" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number
  
  grep -n "func deposit_item" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number
  
  grep -n "func get_quest_state" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number
  ```

  **Commit**: YES
  - Message: `refactor(quests): implement state machine and reactive condition evaluation`
  - Files: `scripts/autoloads/quest_manager.gd`, `scripts/autoloads/data_manager.gd` (if flag_changed signal added)

---

- [ ] 5. Create QuestDepositPanel UI

  **What to do**:
  - Create `ui/components/quest_deposit_panel.tscn`:
    - Panel container that slides in from side (similar to existing QuestTurnInPanel)
    - Header showing quest name
    - Grid of deposit slots (one per required item type)
    - Each slot shows: item icon, deposited count, required count (e.g., "50/100")
    - Close button (X)
    - "Complete Quest" button (disabled until all requirements met)
  - Create `ui/components/quest_deposit_panel.gd`:
    - `setup(quest: QuestResource)` - Initialize slots from `quest.required_items`
    - Handle item drag-drop from inventory to slots
    - On drop: call `Inventory.consume_item()` then `QuestManager.deposit_item()`
    - Update slot display from `QuestManager.get_deposits()`
    - Emit `quest_submitted` signal when Complete button pressed
    - Emit `panel_closed` signal when closed
  - Reference existing `QuestTurnInPanel` for visual style but fresh implementation

  **Must NOT do**:
  - Add progress bars or animations
  - Allow item retrieval from slots
  - Handle quest completion logic (just emit signal, let caller handle)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI component with drag-drop interaction and visual feedback
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: UI/UX design for the deposit panel layout and interaction

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Task 3)
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Tasks 6, 8
  - **Blocked By**: Task 3

  **References**:
  - `ui/components/quest_turn_in_panel.gd` - Existing panel to reference for patterns
  - `ui/components/quest_turn_in_panel.tscn` - Existing scene for visual reference
  - `scripts/resources/quest_input_inventory.gd` - Existing slot logic pattern
  - `ui/components/inventory_panel.gd` - Drag-drop patterns
  - `ui/components/inventory_slot.gd` - Slot interaction patterns

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  test -f ui/components/quest_deposit_panel.tscn && echo "EXISTS"
  # Assert: Output is "EXISTS"
  
  test -f ui/components/quest_deposit_panel.gd && echo "EXISTS"
  # Assert: Output is "EXISTS"
  
  grep -n "func setup" ui/components/quest_deposit_panel.gd
  # Assert: Returns line number
  
  grep -n "signal quest_submitted" ui/components/quest_deposit_panel.gd
  # Assert: Returns line number
  ```

  **Commit**: YES
  - Message: `feat(quests): add QuestDepositPanel UI for item deposits`
  - Files: `ui/components/quest_deposit_panel.gd`, `ui/components/quest_deposit_panel.tscn`

---

- [ ] 6. Integrate NPC Action Visibility

  **What to do**:
  - Modify `scripts/npc/npc_base.gd` or create mixin:
    - Add `@export var quest: QuestResource` (optional - NPC may have no quest)
    - Add method `_get_quest_action() -> NPCAction or null`:
      - If no quest assigned: return null
      - Check `QuestManager.get_quest_state(quest.id)`:
        - LOCKED: return null (invisible)
        - UNLOCKED or ACTIVE: return quest action
        - COMPLETED: return null (hide after completion)
    - Inject quest action into `actions` array dynamically
  - Quest action should:
    - Label: "Quest" or quest-specific text
    - On select: open QuestDepositPanel with quest data
    - Connect to panel's `quest_submitted` signal
    - On submission: call `QuestManager.complete_quest()`, close panel, trigger reward dialogue

  **Must NOT do**:
  - Modify unrelated NPC behavior
  - Add quest markers or indicators
  - Support multiple quests per NPC

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: NPC integration is localized modification following existing patterns
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 8
  - **Blocked By**: Tasks 4, 5

  **References**:
  - `scripts/npc/npc_base.gd` - File to modify
  - `scripts/npcs/glider.gd:45-80` - Existing quest integration pattern
  - `scripts/resources/npc_action.gd` - Action resource structure
  - `scripts/npc/npc_base.gd:_handle_action()` - How actions are processed

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -n "@export var quest" scripts/npc/npc_base.gd
  # Assert: Returns line number
  
  grep -n "_get_quest_action" scripts/npc/npc_base.gd
  # Assert: Returns line number
  
  grep -n "QuestDepositPanel" scripts/npc/npc_base.gd
  # Assert: Returns line number (panel is opened)
  ```

  **Commit**: YES
  - Message: `feat(quests): integrate quest actions into NPC menu system`
  - Files: `scripts/npc/npc_base.gd`

---

- [ ] 7. Implement Persistence for Quest State and Deposits

  **What to do**:
  - Update `QuestManager.to_save_data()`:
    - Include `_quest_states` dictionary
    - Include `_quest_deposits` dictionary
    - Format: `{"states": {}, "deposits": {}, "completed": []}`
  - Update `QuestManager.from_save_data()`:
    - Restore states and deposits
    - Re-connect to signals for reactive evaluation
    - For LOCKED quests: re-evaluate conditions (they may now be met)
  - Verify `SaveManager` correctly calls these methods

  **Must NOT do**:
  - Change SaveManager's save file format
  - Add separate quest save file

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Following established save/load patterns
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 6)
  - **Blocks**: Task 8
  - **Blocked By**: Task 4

  **References**:
  - `scripts/autoloads/quest_manager.gd` - File to modify (from Task 4)
  - `scripts/autoloads/save_manager.gd:60-120` - Save aggregation pattern
  - `scripts/autoloads/inventory.gd:to_save_data()` - Reference implementation

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -n '"states"' scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (in to_save_data)
  
  grep -n '"deposits"' scripts/autoloads/quest_manager.gd
  # Assert: Returns line number (in to_save_data)
  
  grep -n "from_save_data" scripts/autoloads/quest_manager.gd
  # Assert: Returns line number
  ```

  **Manual Verification**:
  1. Start game, deposit partial items to a quest
  2. Save game via menu
  3. Quit and reload save
  4. Verify deposited items are still tracked
  5. Complete deposit, save, reload, verify quest shows as completed

  **Commit**: YES
  - Message: `feat(quests): persist quest states and deposits across sessions`
  - Files: `scripts/autoloads/quest_manager.gd`

---

- [ ] 8. Create Test Quest and End-to-End Verification

  **What to do**:
  - Create `resources/quests/test_quest.tres`:
    - `id: "test_collect_shrooms"`
    - `npc_id: "glider"` (or test NPC)
    - `required_items: {"shroom": 10}`
    - `unlock_conditions`: has_flag("test_quest_enabled")
    - `reward_dialogue_id: "test_quest_complete"`
  - Create matching dialogue resource for reward
  - Test the full flow:
    1. Quest invisible when flag not set
    2. Set flag via debug → Quest appears in NPC menu
    3. Open deposit panel → deposit 5 shrooms → close
    4. Reopen → shows 5/10 deposited
    5. Save/load → still 5/10
    6. Deposit 5 more → quest completes → reward dialogue plays
    7. NPC no longer shows quest action

  **Must NOT do**:
  - Create production quests (this is for testing only)
  - Modify Glider's existing quest setup

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Resource creation and manual testing
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (depends on all prior work)
  - **Blocks**: Task 9
  - **Blocked By**: Tasks 5, 6, 7

  **References**:
  - `resources/quests/build_base_quest.tres` - Existing quest resource example
  - `resources/dialogues/` - Dialogue resource location

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  test -f resources/quests/test_quest.tres && echo "EXISTS"
  # Assert: Output is "EXISTS"
  ```

  **Manual Verification**:
  Full end-to-end test as described in "What to do" section.

  **Commit**: YES
  - Message: `test(quests): add test quest for end-to-end verification`
  - Files: `resources/quests/test_quest.tres`, `resources/dialogues/test_quest_complete.tres`

---

- [ ] 9. Cleanup Deprecated Code

  **What to do**:
  - Remove or deprecate `ui/components/quest_turn_in_panel.gd` and `.tscn`
  - Remove or deprecate `scripts/resources/quest_input_inventory.gd`
  - Update any remaining references to use new system
  - Remove `check_triggers()` from QuestManager if it exists (replaced by reactive system)
  - Clean up any TODO comments added during refactor

  **Must NOT do**:
  - Remove files that are still referenced elsewhere
  - Break existing Glider NPC functionality (ensure it uses new system)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File removal and reference cleanup
  - **Skills**: [`git-master`]
    - `git-master`: Clean commit history for deprecation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final (after all verification)
  - **Blocks**: None
  - **Blocked By**: Task 8

  **References**:
  - `ui/components/quest_turn_in_panel.gd` - To deprecate/remove
  - `scripts/resources/quest_input_inventory.gd` - To deprecate/remove
  - Use `lsp_find_references` to find all usages before removal

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -r "quest_turn_in_panel" scripts/ ui/ --include="*.gd" | grep -v "# deprecated" | wc -l
  # Assert: Output is 0 (no active references)
  
  grep -r "QuestInputInventory" scripts/ ui/ --include="*.gd" | grep -v "# deprecated" | wc -l
  # Assert: Output is 0 (no active references)
  ```

  **Commit**: YES
  - Message: `chore(quests): remove deprecated QuestTurnInPanel and QuestInputInventory`
  - Files: Removed files, updated references

---

## Commit Strategy

| After Task | Message | Files |
|------------|---------|-------|
| 1 | `fix(quests): restore missing QuestManager methods from git history` | quest_manager.gd |
| 2 | `feat(quests): add QuestCondition resource for unlock prerequisites` | quest_condition.gd |
| 3 | `feat(quests): add unlock conditions and NPC association to QuestResource` | quest_resource.gd |
| 4 | `refactor(quests): implement state machine and reactive condition evaluation` | quest_manager.gd |
| 5 | `feat(quests): add QuestDepositPanel UI for item deposits` | quest_deposit_panel.* |
| 6 | `feat(quests): integrate quest actions into NPC menu system` | npc_base.gd |
| 7 | `feat(quests): persist quest states and deposits across sessions` | quest_manager.gd |
| 8 | `test(quests): add test quest for end-to-end verification` | test_quest.tres |
| 9 | `chore(quests): remove deprecated QuestTurnInPanel and QuestInputInventory` | (removed files) |

---

## Success Criteria

### Verification Commands
```bash
# All new files exist:
ls -la scripts/resources/quest_condition.gd ui/components/quest_deposit_panel.* resources/quests/test_quest.tres

# No deprecated references remain:
grep -r "QuestTurnInPanel\|QuestInputInventory" scripts/ ui/ --include="*.gd" | grep -v deprecated
```

### Final Checklist
- [ ] Quest states transition correctly: LOCKED → UNLOCKED → ACTIVE → COMPLETED
- [ ] All 4 condition types work: has_item, quest_completed, dialogue_seen, has_flag
- [ ] AND/OR operator evaluates correctly for condition lists
- [ ] Reactive evaluation triggers on relevant signals
- [ ] Partial deposits persist across save/load
- [ ] Items cannot be retrieved after deposit
- [ ] Quest action visible only when UNLOCKED or ACTIVE
- [ ] Quest action hidden after COMPLETED
- [ ] Reward dialogue triggers on completion
- [ ] No deprecated code references remain
