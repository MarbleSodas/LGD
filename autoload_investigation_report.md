# Autoload Investigation Report

## Resolution

The duplicated-autoload issue has been resolved:

- the unused `DataManager` registration was removed;
- `GameState` now uses `res://scripts/autoloads/game_state.gd`;
- `TipsManager` now uses `res://scripts/autoloads/tips_manager.gd`;
- each service exposes only its own state and behavior;
- the existing autoload names and save-file keys remain compatible.

`SaveManager` serializes story flags through `GameState.to_save_data()` and
restores them through `GameState.from_save_data()`. Tips continue to use the
same focused serialization API. No consumer needs access to the services'
internal dictionaries.
