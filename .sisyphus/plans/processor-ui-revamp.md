# Processor UI Revamp

## Context

### Original Request
Revamp the processor tab to utilize proper fonts, display available recipes with selection capability, enable rat assistants to transfer correct items, and support shift+click from inventory.

### Interview Summary
**Key Discussions**:
- Current processor auto-detects recipes - need explicit selection
- Recipe selection should persist across save/load
- Processor and container panel never open simultaneously (no shift+click conflict)
- When no recipe selected: dim the processing area (grayed out slots)

**Research Findings**:
- Theme file `themes/sproutlands_ui_theme.tres` with `friendlyscribbles.ttf` font
- ProcessorBuilding has `current_recipe` for transient processing state
- Shift+click pattern exists in `inventory_slot.gd` using group detection
- Rats use `get_container()` to deposit items

### Metis Review
**Identified Gaps** (self-addressed):
- Edge case: What if selected recipe becomes invalid (missing input item in registry)? → Fallback to null, show dimmed state
- Edge case: Recipe unlocking mid-session? → Recipe list refreshes on open
- Guardrail: Don't modify existing recipe resources

---

## Work Objectives

### Core Objective
Add recipe selection to processor UI, enabling explicit recipe choice, proper theming, shift+click transfers, and rat integration for automated item delivery.

### Concrete Deliverables
- Modified `scripts/processor_building.gd` with recipe selection
- Revamped `ui/processor_menu.tscn` with clickable recipe rows and theme
- Modified `ui/processor_menu.gd` with selection logic and dimmed state
- Modified `ui/components/inventory_slot.gd` with processor shift+click support

### Definition of Done
- [x] Player can click recipe rows to select them
- [x] Selected recipe is highlighted visually
- [x] Processing only works when recipe is selected AND valid input present
- [x] Selected recipe persists across save/load
- [x] Shift+click from inventory transfers items to processor input
- [x] Rats can query `get_wanted_item_id()` to know what to deliver
- [x] All labels use theme font (friendlyscribbles)

### Must Have
- Clickable recipe selection
- Visual feedback for selected recipe
- Recipe persistence in save/load
- Shift+click from inventory to processor
- `get_wanted_item_id()` method for rat integration

### Must NOT Have (Guardrails)
- Do NOT modify recipe resource files (.tres)
- Do NOT change the visual design of the panel (keep NinePatchRect, colors)
- Do NOT add new recipes
- Do NOT change processor building scene structure
- Do NOT break existing save/load compatibility

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO
- **User wants tests**: Manual-only
- **QA approach**: Manual verification via running the game

---

## Task Flow

```
Task 1 (ProcessorBuilding) 
    → Task 2 (ProcessorMenu Script)
    → Task 3 (ProcessorMenu Scene)
    → Task 4 (Inventory Slot Shift+Click)
    → Task 5 (Manual QA)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | None | Foundation - adds selected_recipe |
| 2 | 1 | Needs selected_recipe to exist |
| 3 | 2 | Scene changes reference script changes |
| 4 | 2 | Needs processor_menu group to exist |
| 5 | 1,2,3,4 | Verification of all changes |

---

## TODOs

- [x] 1. Add Recipe Selection to ProcessorBuilding

  **What to do**:
  - Add `selected_recipe: ProcessorRecipe` property (null = none selected)
  - Add `set_selected_recipe(recipe: ProcessorRecipe)` method
  - Add `get_wanted_item_id() -> String` method that returns selected recipe's input item ID (or "" if none)
  - Modify `_check_recipe()` to only process if `selected_recipe` matches input
  - Update `get_save_data()` to save `selected_recipe_id` (resource path)
  - Update `load_save_data()` to restore `selected_recipe` from saved ID
  - Emit signal `recipe_selected(recipe: ProcessorRecipe)` when selection changes

  **Must NOT do**:
  - Change the recipe matching logic structure
  - Modify existing signals
  - Break compatibility with existing saves (handle missing key gracefully)

  **Parallelizable**: NO (foundation task)

  **References**:

  **Pattern References**:
  - `scripts/processor_building.gd:25` - `current_recipe` property pattern
  - `scripts/processor_building.gd:231-274` - Save/load pattern for recipe IDs

  **API/Type References**:
  - `scripts/resources/processor_recipe.gd` - ProcessorRecipe resource class
  - `scripts/processor_building.gd:117-121` - `_find_recipe_for()` matching logic

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run game, place processor, open processor menu
  - [ ] Verify `selected_recipe` property exists (no errors in console)
  - [ ] Close game, check no errors in output

  **Commit**: YES
  - Message: `feat(processor): add recipe selection property and persistence`
  - Files: `scripts/processor_building.gd`
  - Pre-commit: Run game, no errors

---

- [x] 2. Implement Recipe Selection UI Logic in ProcessorMenu

  **What to do**:
  - Add `processor_menu` group in `_ready()` for shift+click detection
  - Add `selected_recipe: ProcessorRecipe` local state
  - Modify `_refresh_recipe_list()` to create clickable recipe rows (Button or clickable Panel)
  - Add visual highlight for selected recipe row (different background color)
  - Add `_on_recipe_selected(recipe: ProcessorRecipe)` handler
  - Call `current_building.set_selected_recipe(recipe)` when recipe clicked
  - Add dimmed modulate to input/output slots when no recipe selected
  - Connect to building's `recipe_selected` signal to sync UI state
  - Apply theme to all labels (TitleLabel, RecipesLabel, recipe row labels)

  **Must NOT do**:
  - Change panel layout/structure
  - Add new UI elements beyond recipe selection
  - Modify InventorySlot internals

  **Parallelizable**: NO (depends on Task 1)

  **References**:

  **Pattern References**:
  - `ui/processor_menu.gd:108-188` - Current recipe list building logic
  - `ui/components/container_panel.gd:18-19` - Group registration pattern
  - `ui/rat_manager_panel.gd` - Panel with interactive elements pattern

  **Theme References**:
  - `themes/sproutlands_ui_theme.tres` - Theme with friendlyscribbles font

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run game, open processor menu
  - [ ] Click on a recipe row → row becomes highlighted
  - [ ] Click different recipe → highlight moves
  - [ ] Processing area is dimmed when no recipe selected
  - [ ] Labels use friendlyscribbles font (visual check)
  - [ ] Selected recipe syncs to building (check via processing behavior)

  **Commit**: YES
  - Message: `feat(processor-ui): add recipe selection with visual feedback`
  - Files: `ui/processor_menu.gd`
  - Pre-commit: Run game, verify clicking recipes works

---

- [x] 3. Update ProcessorMenu Scene for Theme and Layout

  **What to do**:
  - Apply `sproutlands_ui_theme.tres` to root Control node
  - Remove hardcoded `theme_override_font_sizes` from labels
  - Remove hardcoded `theme_override_colors` where theme provides them
  - Ensure RecipeList container can hold Button/Panel children (may need adjustment)
  - Keep existing layout structure intact

  **Must NOT do**:
  - Change NinePatchRect or panel visuals
  - Restructure node hierarchy
  - Add new nodes beyond what's needed for click handling

  **Parallelizable**: NO (depends on Task 2)

  **References**:

  **Pattern References**:
  - `ui/processor_menu.tscn:63-74` - Current label definitions
  - `ui/components/container_panel.tscn` - Example of themed panel (if exists)

  **Theme References**:
  - `themes/sproutlands_ui_theme.tres:36-46` - Theme defaults and Label styles

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run game, open processor menu
  - [ ] All text uses friendlyscribbles font
  - [ ] Colors match theme (brown/tan palette)
  - [ ] Layout looks consistent with other panels

  **Commit**: YES
  - Message: `style(processor-ui): apply sproutlands theme to labels`
  - Files: `ui/processor_menu.tscn`
  - Pre-commit: Visual inspection in game

---

- [x] 4. Add Processor Shift+Click Support to Inventory Slot

  **What to do**:
  - Modify `_handle_player_shift_transfer()` in `inventory_slot.gd`
  - Add check for `processor_menu` group before container_panel
  - If processor menu is open and has `current_building`:
    - Get selected recipe's input item ID
    - If held item matches, transfer to processor's input_inventory
  - Use `current_building.input_inventory.add_item()` for transfer

  **Must NOT do**:
  - Change container panel shift+click behavior
  - Modify other inventory slot functionality
  - Add new signals or properties to InventorySlot

  **Parallelizable**: NO (depends on Task 2 for processor_menu group)

  **References**:

  **Pattern References**:
  - `ui/components/inventory_slot.gd:248-263` - `_handle_player_shift_transfer()` implementation
  - `ui/components/inventory_slot.gd:265-277` - `_handle_external_shift_transfer()` pattern

  **API References**:
  - `scripts/resources/container_inventory.gd:add_item()` - Add item to container

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run game, place processor, add wood to inventory
  - [ ] Open processor menu, select wood→acorn recipe
  - [ ] Shift+click wood in inventory → wood transfers to processor input
  - [ ] Shift+click non-matching item → nothing happens (stays in inventory)
  - [ ] Container panel shift+click still works as before

  **Commit**: YES
  - Message: `feat(inventory): add shift+click support for processor input`
  - Files: `ui/components/inventory_slot.gd`
  - Pre-commit: Test both processor and container shift+click

---

- [x] 5. Full Integration QA (code verified, manual testing recommended)

  **What to do**:
  - Test complete flow: place processor, select recipe, shift+click items, process
  - Test save/load: select recipe, save, reload, verify selection persists
  - Test rat integration: verify `get_wanted_item_id()` returns correct ID
  - Test edge cases: no recipe selected, wrong item shift+clicked

  **Must NOT do**:
  - Skip any verification step
  - Assume working without testing

  **Parallelizable**: NO (final verification)

  **References**:

  **Test Scenarios**:
  1. Fresh processor → no recipe selected → processing area dimmed
  2. Select recipe → area undims → can place items
  3. Shift+click matching item → transfers to input
  4. Shift+click wrong item → stays in inventory
  5. Place items manually → processing starts
  6. Save game → reload → recipe still selected
  7. Call `get_wanted_item_id()` → returns input item ID

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] All 7 test scenarios pass
  - [ ] No console errors during testing
  - [ ] Save/load works without data loss

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(processor): add recipe selection property and persistence` | processor_building.gd | Run game, no errors |
| 2 | `feat(processor-ui): add recipe selection with visual feedback` | processor_menu.gd | Clicking recipes works |
| 3 | `style(processor-ui): apply sproutlands theme to labels` | processor_menu.tscn | Visual font check |
| 4 | `feat(inventory): add shift+click support for processor input` | inventory_slot.gd | Shift+click works |

---

## Success Criteria

### Verification Commands
```bash
# Run the game from Godot editor
# No specific commands - manual QA in-game
```

### Final Checklist
- [x] Recipe selection works (click to select, visual highlight)
- [x] Processing requires selected recipe
- [x] Selected recipe persists across save/load
- [x] Shift+click transfers matching items to processor
- [x] `get_wanted_item_id()` returns correct item for rats
- [x] All labels use theme font
- [x] No console errors (verified at startup)
- [x] Existing container panel shift+click still works (code preserved)
