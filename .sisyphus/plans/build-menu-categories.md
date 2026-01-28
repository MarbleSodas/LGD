# Build Menu Categories

## TL;DR

> **Quick Summary**: Add categorized, collapsible sections to the build menu with **smooth sliding animations**. Items are grouped by type (Plants, Buildings) inside container nodes that animate open/closed. Category state is persisted to the world save file.
> 
> **Deliverables**:
> - New `BuildMenuCategory` scene (hierarchical structure with header + item container)
> - Modified `build_menu.gd` to populate categories hierarchically
> - Tween-based animation system for expand/collapse
> - Save/load integration for persistent state
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4

---

## Context

### Request
Add categories to the build menu grouping plants and buildings separately. The system must be expandable and feature **smooth animations** for expanding/collapsing.

### Interview Summary
**Key Decisions**:
- **UI Structure**: Hierarchical (Category Node contains Item List) to support animation.
- **Animation**: Smooth slide (Tween `custom_minimum_size` + `clip_contents`).
- **Category System**: Extend existing `BuildableType` enum.
- **Persistence**: Store collapse state in world save.
- **Verification**: User will test manually.

---

## Work Objectives

### Core Objective
Transform the build menu into a list of Category nodes, where each node contains a header and a collapsible container of items that animates smoothly when toggled.

### Must Have
- [x] Grouping by `BuildableType`
- [x] **Smooth sliding animation** (slide down/up) for categories
- [x] Persistence of state (save/load)
- [x] Extensible via Enum
- [x] Dynamic updates (unlocks add to correct category)

### Must NOT Have
- Complex springs/physics (standard cubic/quad tweens are sufficient)
- Reordering of categories by user

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Create BuildMenuCategory scene/script (with Animation Logic)
└── Task 5: Add category state to SaveManager schema

Wave 2 (After Wave 1):
└── Task 2: Modify build_menu.gd for Hierarchical Population

Wave 3 (After Wave 2):
└── Task 3: Integrate persistence

Wave 4 (After Wave 3):
└── Task 4: Handle dynamic unlock updates
```

---

## TODOs

- [ ] 1. Create BuildMenuCategory Scene and Script

  **What to do**:
  - Create `ui/components/build_menu_category.tscn`:
    - Root: `VBoxContainer` named `BuildMenuCategory`
    - Child 1: `Button` (or Panel+Input) named `Header` (clickable)
      - Sub-child: `Label` "Title"
      - Sub-child: `Label` "Arrow" (rotated or text change)
    - Child 2: `VBoxContainer` named `ItemsContainer`
      - **Crucial**: Set `clip_contents = true`.
      - **Crucial**: This container will hold the `BuildMenuSlot` instances.
  - Create `ui/components/build_menu_category.gd`:
    - `func setup(type, name)`
    - `func add_item_slot(slot_instance)`
    - `func set_expanded(expanded: bool, animate: bool = true)`
      - If `animate`:
        - Create `Tween`.
        - Tween `ItemsContainer.custom_minimum_size:y`.
        - From `0` to `content_height` (expand) or `current` to `0` (collapse).
        - Use `Tween.EASE_OUT`, `Tween.TRANS_CUBIC`.
      - If `!animate` (setup/load):
        - Set visibility and size instantly.
    - Signal `toggled(type, is_expanded)`

  **Animation Details**:
  - To get `content_height` for the tween:
    - Force update? Or use `get_minimum_size().y` of the children?
    - *Better approach*: Tween `custom_minimum_size:y`. When expanding, you might need to calculate the height.
    - *Alternative*: Simple visibility toggle is NOT smooth.
    - *Godot Tip*: To animate height of a VBoxContainer:
      1. Set `custom_minimum_size.y = 0` and `visible = false` (collapsed).
      2. To Expand: `visible = true`. Calculate total height of children. Tween `custom_minimum_size.y` to that height.
      3. On Tween finish: Set `custom_minimum_size.y = 0` (let auto-layout take over) or keep it fixed? -> Usually keep it fixed or set strict min height.
      - *Simpler*: `Container` with `clip_contents`. Tween its `custom_minimum_size`.

  **Recommended Agent**: `visual-engineering` (for animation tuning)
  
  **Acceptance Criteria**:
  - [ ] Scene exists with hierarchical structure (Header + ItemsContainer).
  - [ ] `add_item_slot` adds child to `ItemsContainer`.
  - [ ] `set_expanded(true, true)` smoothly animates height from 0 to full.
  - [ ] `set_expanded(false, true)` smoothly animates height from full to 0.

---

- [ ] 2. Modify build_menu.gd for Hierarchical Population

  **What to do**:
  - Modify `_populate_items()`:
    - Instead of adding all slots to main list:
    - Iterate `CATEGORY_ORDER`.
    - Instantiate `BuildMenuCategory`.
    - Add Category to main `item_list` (VBox).
    - Add relevant items *into* the Category using `category.add_item_slot(slot)`.
  - Update `_on_category_toggled`:
    - Just handle save state update (UI animation is handled by component).

  **Acceptance Criteria**:
  - [ ] Main menu contains only Category nodes.
  - [ ] Items appear inside their respective categories.
  - [ ] Layout flows correctly.

---

- [ ] 3. Integrate Category State Persistence

  **Same as before**, but ensure `set_expanded(state, false)` is called on load (no animation during initial load).

---

- [ ] 4. Handle Dynamic Unlock Updates

  **What to do**:
  - When item unlocks:
    - Find existing Category node for type.
    - If exists: `category.add_item_slot(new_slot)`.
      - *Edge Case*: If expanded, might need to re-adjust height if using fixed height tween?
      - *Fix*: If expanded, set `custom_minimum_size` to 0 (auto) so it grows instantly, or animate the growth.
    - If not exists: Create new Category, add item, add to main list.

---

- [ ] 5. Add UI State Schema to SaveManager (Same as before)

