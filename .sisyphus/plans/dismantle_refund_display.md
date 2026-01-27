# Dismantle Refund Display Implementation Plan

## Context

### Original Request
Display the refunded material under a building/plant when you dismantle it.

### Interview Summary
**Key Discussions**:
- **Visual Style**: Icon + Text (e.g., [Wood Icon] +5).
- **Layout**: Stacked vertically if multiple materials are refunded.
- **Trigger**: Dismantling via `DeletionManager`.

**Research Findings**:
- `FloatingText` currently exists as a simple `Label`. Needs refactoring to support icons.
- `DeletionManager` handles the refund logic in `_refund_object`.
- `InteractionManager` currently instantiates `FloatingText`. We should align with this or genericize it.

---

## Work Objectives

### Core Objective
Visually communicate returned resources to the player when they dismantle structures.

### Concrete Deliverables
- **Refactored `FloatingText.tscn`**: Converted to support Icon + Text.
- **Updated `FloatingText.gd`**: API to set text and icon.
- **Updated `DeletionManager.gd`**: Spawns floating text during refund loop.

### Definition of Done
- [x] Dismantling a building with costs (e.g., Mushroom House) shows "[Icon] +[Amount]" popping up.
- [x] Dismantling a building with multiple costs shows multiple popups stacked vertically.
- [x] Existing floating text (e.g., harvesting) still works (backward compatibility).

### Must Have
- Icon support in floating text.
- Vertical stacking for readability.
- `mouse_filter = IGNORE` to prevent blocking clicks.

### Must NOT Have
- Complex physics for the text (simple float-up animation only).
- Blocking UI interactions.

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (Godot project)
- **User wants tests**: Manual QA Only (Standard for this project size/type)

### Manual QA Procedure

**1. Floating Text Refactor Verification**
- [x] Trigger: Harvest a plant (uses existing `InteractionManager`).
- [x] Verify: Text still appears (e.g., "+1 Wood"), even if icon is null.

**2. Dismantle Refund Verification**
- [x] Setup: Place a building with known costs (e.g., `Mushroom House` -> 50 Shrooms).
- [x] Action: Select Delete Mode -> Click building.
- [x] Verify:
    - [x] Popup appears at building location.
    - [x] Shows "50" (or "+50") and the Shroom icon.
    - [x] Text floats up and fades out.

**3. Multi-Material Stack Verification**
- [x] Setup: Place a building with >1 cost (might need to temporarily edit a resource to test this if none exist).
- [x] Action: Dismantle.
- [x] Verify: Two popups appear, one slightly below the other, both readable.

---

## Task Flow

```
Refactor FloatingText → Update DeletionManager
```

---

## TODOs

- [x] 1. Refactor `FloatingText` Scene
  **What to do**:
  - Change root node of `ui/components/floating_text.tscn` from `Label` to `HBoxContainer` (or `Control` with HBox).
  - Add children:
    - `TextureRect` (Name: "Icon", Expand: true, Stretch Mode: Keep Aspect Centered).
    - `Label` (Name: "Label", Text: "+1", layout settings to expand).
  - Set `mouse_filter` to `IGNORE` on root and children.
  - Ensure alignment is Center.

  **References**:
  - `ui/components/floating_text.tscn`
  - `ui/components/inventory_slot.tscn` (for icon sizing reference)

  **Acceptance Criteria**:
  - [x] Scene structure is HBoxContainer -> [TextureRect, Label].
  - [x] `mouse_filter` is Ignore.

- [x] 2. Update `FloatingText` Script
  **What to do**:
  - Update `ui/components/floating_text.gd`.
  - Add `@onready var label` and `@onready var icon`.
  - Update `set_text_content(content)` to set `label.text`.
  - Add `set_content(text: String, icon_texture: Texture2D = null)`.
  - If `icon_texture` is null, hide the icon node.
  - Update animation (tween) to operate on the Root node (self) properties (modulate, position).

  **References**:
  - `ui/components/floating_text.gd`

  **Acceptance Criteria**:
  - [x] `set_content("Test", null)` hides icon.
  - [x] `set_content("Test", texture)` shows icon.
  - [x] Animation still works on the container.

- [x] 3. Implement Refund Display in `DeletionManager`
  **What to do**:
  - In `scripts/systems/deletion_manager.gd`:
  - Preload `res://ui/components/floating_text.tscn`.
  - In `_refund_object(obj)`:
    - Initialize `y_offset = 0`.
    - Inside the loop `for material_id in buildable.build_costs`:
      - Get item via `ItemRegistry.get_item(material_id)`.
      - Instantiate floating text.
      - Call `popup.set_content("+" + str(amount), item.icon)`.
      - Position: `obj.global_position + Vector2(0, -20 + y_offset)`.
      - Add child to `get_tree().current_scene` (or `obj.get_parent()`).
      - Increment `y_offset` (e.g., `-15`) so next item stacks *above* (or below, user choice: "Stacked Vertically").

  **References**:
  - `scripts/systems/deletion_manager.gd`: `_refund_object`
  - `scripts/autoloads/item_registry.gd`: `get_item`
  - `scripts/resources/inventory_item.gd`: properties (icon, display_name)

  **Acceptance Criteria**:
  - [x] Dismantling spawns the text.
  - [x] Correct icon and amount shown.
  - [x] Multiple items stack without overlapping perfectly.

---

## Success Criteria

### Final Checklist
- [x] Dismantling shows refunds.
- [x] Harvesting (old system) still works.
- [x] No errors in debugger when dismantling.
