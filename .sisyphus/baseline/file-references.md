# File References Baseline

References to files that will be moved in Phase 2.

## player.tscn
**Current Location**: `res://player.tscn`
**Target Location**: `res://scenes/player/player.tscn`

### Inbound References
- `res://world.tscn`: `[ext_resource type="PackedScene" path="res://player.tscn" id="3_player"]`

## world.tscn
**Current Location**: `res://scenes/world.tscn` (Wait, the grep output showed `res://world.tscn` in `world_list_panel.gd`, but the plan says `scenes/world.tscn`. Let me check `world_list_panel.gd` to be precise.)

### Inbound References
- `res://scenes/start_menu/world_list_panel.gd`: `const WORLD_SCENE_PATH = "res://world.tscn"`
