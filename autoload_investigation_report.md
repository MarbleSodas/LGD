# Autoload Investigation Report

## Findings
- **3 Autoloads, 1 Script**: `DataManager`, `GameState`, and `TipsManager` all point to `res://scripts/autoloads/data_manager.gd`.
- **Logic Merged**: `data_manager.gd` contains logic for both GameState (flags, world) and TipsManager (seen tips).
- **Instance Separation**: Since they are separate autoloads, Godot creates 3 separate nodes (`DataManager`, `GameState`, `TipsManager`).
- **Usage Analysis**:
  - `GameState`: Used for `set_current_world` and `story_flags`.
  - `TipsManager`: Used for `is_seen`, `mark_seen`, and save/load of tips.
  - `DataManager`: **UNUSED**. No references found in the codebase.

## Potential Issues
- **State Split**: Logic is shared, but state is INSTANCE-local.
  - Calling `GameState.set_flag()` only affects the `GameState` node.
  - Calling `TipsManager.mark_seen()` only affects the `TipsManager` node.
  - This works ONLY because the code rigorously uses `GameState` for flags and `TipsManager` for tips.
  - If someone called `GameState.mark_seen()`, the tip would be saved in the `GameState` node but `TipsManager.is_seen()` would return false.

## Recommendation
1. **Remove `DataManager` Autoload**: It is unused and misleading.
2. **Short Term**: Keep `GameState` and `TipsManager` as is, but add comments in `data_manager.gd` warning about the split instance behavior.
3. **Long Term**: Refactor to a single `GameState` autoload that handles both, and replace `TipsManager` references with `GameState.Tips` or similar.

## Action Item
- Safe to delete `DataManager` line from `project.godot` in a future cleanup.
