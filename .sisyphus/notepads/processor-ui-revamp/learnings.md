# Learnings - Processor UI Revamp

## 2026-01-23 Implementation Complete

### Patterns Discovered

1. **Group-based UI detection**: Use `add_to_group("processor_menu")` in `_ready()` and detect with `get_tree().get_first_node_in_group()` for shift+click integration

2. **Recipe selection pattern**: 
   - `selected_recipe: ProcessorRecipe` on building (persisted)
   - `current_recipe: ProcessorRecipe` for transient processing state (separate)
   - Signal `selected_recipe_changed` for UI sync

3. **Visual feedback for selection**:
   - Use `PanelContainer` with `StyleBoxFlat` for clickable rows
   - Constants: `SELECTED_COLOR = Color(0.639, 0.463, 0.337, 0.6)`, `HOVER_COLOR = Color(0.639, 0.463, 0.337, 0.3)`
   - Dim processing area with `DIMMED_MODULATE = Color(1.0, 1.0, 1.0, 0.4)`

4. **Save/Load persistence**:
   - Save recipe by `resource_path`: `_get_recipe_id(selected_recipe)`
   - Load recipe by path: `_get_recipe_by_id(selected_id)`
   - Handle missing key gracefully for backwards compatibility

5. **Shift+click priority chain**:
   - Check `processor_menu` group first
   - Then check `container_panel` group
   - Use `processor_menu.get("is_open")` for safe property access

### Successful Approaches

1. **Rat integration via `get_wanted_item_id()`**: Simple method returning input item ID from selected recipe, or "" if none

2. **Theme application**: Apply theme to root Control node, remove `theme_override_font_sizes` from labels to inherit

3. **Recipe row creation**: Use `_recipe_rows: Dictionary` mapping recipe to PanelContainer for easy style updates on selection change

### Technical Notes

- Godot 4.5.1 with friendlyscribbles font in `themes/sproutlands_ui_theme.tres`
- ProcessorBuilding emits `selected_recipe_changed` signal on selection
- Inventory slot checks for processor menu before container panel for shift+click
