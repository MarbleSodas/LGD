# Work Plan: Fix Rat Visuals

## Objective
Restore full functionality to the Rat Assistant's visual feedback system, including movement bobbing, direction flipping, and held item display.

## Root Cause
The `RatVisuals.gd` script is attached to the `Visuals` node in `rat_assistant.tscn`, but its `@export` variables (`body_sprite`, `held_item_sprite`, `count_label`, `inventory`) are **not assigned** in the scene file. This causes all visual update methods to abort immediately due to null checks.

## Implementation Steps

### 1. Fix Scene Wiring (`scenes/rat_assistant.tscn`)
- Assign `body_sprite` -> `BodySprite` (child node)
- Assign `held_item_sprite` -> `HeldItemSprite` (child node)
- Assign `count_label` -> `CountLabel` (child node)
- Assign `inventory` -> `../Inventory` (sibling node)

### 2. Clean Up Duplicate Node (`scenes/rat_assistant.tscn`)
- Identify the duplicate `Plant` node in the `StateMachine` hierarchy.
- Remove the empty `Plant` node (the one without a script).

### 3. Verification
- **Manual Verification**: Run the project using Godot (if available) or rely on static analysis.
- **Success Criteria**:
    - Rat "bobs" up and down while moving.
    - Rat faces the direction of movement.
    - When carrying an item, the item sprite appears above the rat.
    - Item count shows if quantity > 1.
    - No script errors regarding null instances in `RatVisuals.gd`.

## Technical Details
- **File**: `scenes/rat_assistant.tscn`
- **Format**: Godot text scene format (`.tscn`). We will need to locate the `Visuals` node (likely `[node name="Visuals" ...`) and add the properties pointing to the `node_paths`.

## Risks & Constraints
- **Scene File Corruption**: Editing `.tscn` files manually requires precision. We must ensure the `node_paths` syntax is correct.
- **Constraint**: Do not modify the logic in `RatVisuals.gd` unless the scene fix is insufficient (unlikely).
