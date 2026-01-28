# Learnings: Tutorial Intro

## Implementation Details
- Used `DialogueManager.is_active()` as a global guard for input blocking.
- Added guards to:
  - `planting_system.gd` (General gameplay/building)
  - `build_menu.gd` (Building UI)
  - `hotbar.gd` (Item selection)
  - `inventory_panel.gd` (Inventory UI)
- Created `IntroFadeOverlay` in `ui/ui.tscn` (ColorRect) to handle the fade-in effect.
- Triggered via `world.gd`'s `_ready()` using `is_new_world` flag.

## Resources Created
- `resources/ui/player_portrait.tres`: AtlasTexture from Player_Idle.png
- `resources/dialogues/intro_awakening.tres`: Intro dialogue data

## Notes
- Input blocking relies on manual guards. If new input handling systems are added (e.g. a new menu), they must also include the `DialogueManager.is_active()` check.
- The fade duration is hardcoded to 1.5s in `world.gd`.
