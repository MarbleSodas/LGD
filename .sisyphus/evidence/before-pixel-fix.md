# Settings Snapshot - Before Pixel Rendering Fix

**Date:** Wed Jan 28 2026  
**Purpose:** Rollback reference for viewport and camera changes

## project.godot - Display Settings

```ini
[display]

window/size/window_width_override=1152
window/size/window_height_override=648
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

**Current Resolution:** 1152 x 648

## player.tscn - Camera2D Settings

```gdscript
[node name="Camera2D" type="Camera2D" parent="."]
physics_interpolation_mode = 2
zoom = Vector2(1.25, 1.25)
position_smoothing_enabled = true
position_smoothing_speed = 8.0
```

**Current Camera Zoom:** 1.25

---

## Planned Changes
- Resolution: 1152x648 → 1024x512
- Camera Zoom: 1.25 → 2.0

## Rollback Command
If changes cause issues, revert using this snapshot.
