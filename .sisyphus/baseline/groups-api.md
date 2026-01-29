# Stable Group Names API

The following group names are used for runtime lookups and must be preserved during refactoring.

## UI Components
- `rat_manager_panel`
- `build_menu`
- `processor_menu`
- `inventory_panel`
- `container_panel`
- `ui_layer` (often via constant `GROUP_UI_LAYER`)

## Gameplay Systems
- `planting_system` (often via constant `GROUP_PLANTING_SYSTEM`)
- `mushroom_houses` (often via constant `GROUP_MUSHROOM_HOUSES`)
- `player`

## Usage Analysis
- **PlantingSystem**: Heavily accessed via group lookup in buildings and mushroom houses.
- **UI Panels**: Cross-reference each other (e.g., build menu needs rat manager, hotbar needs rat manager).
- **Player**: Accessed by NPCs.
