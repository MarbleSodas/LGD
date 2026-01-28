# Pixel Rendering Fix - Integer Scaling with 1024×512 Base

## TL;DR

> **Quick Summary**: Fix pixel rendering by establishing 1024×512 as the base viewport resolution with factor-of-2 scaling breakpoints. Change camera zoom from 1.25 (fractional) to 2.0 (integer) for clean pixel rendering.
> 
> **Deliverables**:
> - Updated `project.godot` with correct viewport and stretch settings
> - Camera zoom changed to integer 2.0
> - Clean pixel rendering at 1080p (2x scale), 4K (4x scale), and smaller displays (expand mode)
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - sequential (each task depends on previous)
> **Critical Path**: Snapshot → Settings → Camera → Verify

---

## Context

### Original Request
Fix the pixel rendering with a base of 1920x1080 as the 1 to 1 pixel rendering and have the pixel scaling scale in factors of 2 with breakpoints for clean pixel rendering and pixel consistency.

### Interview Summary
**Key Discussions**:
- **Internal resolution**: Originally requested 1920×1080, refined to 960×540, then corrected to 1024×512 after discovering tile alignment issue (540÷32=16.875 fractional)
- **Camera zoom**: User confirmed changing from 1.25 to 2.0 (integer)
- **Smaller displays**: Expand mode (show more game world, no letterboxing)
- **UI scaling**: Pixel-perfect UI (integer scaling)

**Research Findings**:
- Only ONE Camera2D exists in `player.tscn` at line 70
- No custom shaders (.gdshader files) to worry about
- Tile size is 32×32 throughout
- 1024×512 = 32×16 tiles = perfect grid alignment
- Current camera zoom 1.25 causes pixel shimmering

### Metis Review
**Identified Gaps** (addressed):
- **Math error**: 540÷32=16.875 fractional → Resolved by changing to 512 height
- **Camera count unknown**: Verified only ONE Camera2D in `player.tscn`
- **Shader risk**: Verified no custom shaders exist
- **Acceptance criteria**: Changed from "visual verification" to automated assertions

---

## Work Objectives

### Core Objective
Establish clean pixel-perfect rendering by setting 1024×512 as the internal resolution with integer-only scaling factors, eliminating the current pixel shimmering caused by the 1.25 camera zoom.

### Concrete Deliverables
1. `project.godot` updated with:
   - `viewport_width=1024`
   - `viewport_height=512`
   - `stretch/mode="viewport"`
   - `stretch/aspect="expand"`
   - `stretch/scale_mode="integer"` (if supported in Godot 4.5)
2. `player.tscn` Camera2D zoom changed from `Vector2(1.25, 1.25)` to `Vector2(2, 2)`

### Definition of Done
- [ ] Game renders at 1024×512 internal resolution
- [ ] At 1080p: Renders at clean 2x scale (2048×1024)
- [ ] At 4K: Renders at clean 4x scale (4096×2048)
- [ ] At smaller displays: Expands to show more game world
- [ ] No pixel shimmering on tile edges
- [ ] Camera shows 16×8 tiles visible area (32÷2 × 16÷2)

### Must Have
- Integer-only scaling (1x, 2x, 4x)
- 1024×512 base resolution (32×16 tile grid)
- Camera zoom exactly 2.0 (not 1.25)
- Expand aspect mode for smaller displays

### Must NOT Have (Guardrails)
- **DO NOT** change tile sizes or tilemap configuration
- **DO NOT** modify any game logic (player movement, collision, etc.)
- **DO NOT** alter sprite assets (no re-exporting, no filter changes)
- **DO NOT** add resolution presets or settings UI
- **DO NOT** touch any scripts except for configuration reading (if needed)
- **DO NOT** modify multiple cameras (there's only one, but don't add more)
- **DO NOT** change particle systems or effects

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (no GUT/gdUnit tests)
- **User wants tests**: Manual verification + automated config assertions
- **Framework**: N/A

### Automated Verification (Agent-Executable)

Each TODO includes grep assertions and runtime checks that agents can execute directly.

**Verification Tools Used:**
| Type | Tool | Purpose |
|------|------|---------|
| Config assertion | `grep` | Verify exact values in project.godot |
| Scene assertion | `grep` | Verify camera zoom in player.tscn |
| Runtime check | `godot_run_project` | Verify game launches without errors |
| Debug output | `godot_get_debug_output` | Capture any runtime warnings |

**Visual Verification (Manual)**:
After automated checks pass, visually confirm:
- 1080p fullscreen: Tiles render with clean edges
- 4K display: Pixels scale at exact 4x
- Windowed at 800×400: Game expands to show more tiles

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential - dependencies exist):
Task 1: Snapshot current settings
    ↓
Task 2: Update project.godot display settings
    ↓
Task 3: Update Camera2D zoom
    ↓
Task 4: Verify changes

Critical Path: Task 1 → Task 2 → Task 3 → Task 4
Parallel Speedup: N/A (sequential due to dependencies)
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2 | None |
| 2 | 1 | 3 | None |
| 3 | 2 | 4 | None |
| 4 | 3 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1,2,3,4 | Sequential execution (category="quick") |

---

## TODOs

- [x] 1. Snapshot Current Settings

  **What to do**:
  - Read and document current `project.godot` display settings
  - Read and document current `player.tscn` Camera2D settings
  - Save snapshot to `.sisyphus/evidence/before-pixel-fix.md`

  **Must NOT do**:
  - Do NOT modify any files in this task
  - Do NOT run the game (read-only task)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file read and documentation task
  - **Skills**: `[]`
    - No specialized skills needed for file reading

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (start)
  - **Blocks**: Task 2
  - **Blocked By**: None

  **References**:
  - `project.godot:27-32` - Current display settings ([display] section)
  - `player.tscn:70-74` - Current Camera2D configuration

  **Acceptance Criteria**:

  ```bash
  # AC1: Evidence file exists with settings snapshot
  cat .sisyphus/evidence/before-pixel-fix.md | grep "viewport" && \
  cat .sisyphus/evidence/before-pixel-fix.md | grep "zoom"
  # Assert: Both settings documented
  ```

  **Commit**: NO (groups with Task 4)

---

- [x] 2. Update project.godot Display Settings

  **What to do**:
  - Set `display/window/size/viewport_width = 1024`
  - Set `display/window/size/viewport_height = 512`
  - Change `display/window/stretch/mode` from `"canvas_items"` to `"viewport"`
  - Keep `display/window/stretch/aspect = "expand"` (already correct)
  - Remove or update `window_width_override` and `window_height_override` to match new base

  **Must NOT do**:
  - Do NOT change rendering settings (texture filter, pixel snapping already correct)
  - Do NOT change input mappings
  - Do NOT change autoloads
  - Do NOT add new settings not specified above

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small configuration file edit
  - **Skills**: `[]`
    - No specialized skills needed for config editing

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (sequential)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - `project.godot:27-32` - Current [display] section to modify
  - Godot docs: `display/window/stretch/mode` accepts "disabled", "canvas_items", "viewport"
  - Godot docs: `display/window/stretch/aspect` accepts "ignore", "keep", "keep_width", "keep_height", "expand"

  **Acceptance Criteria**:

  ```bash
  # AC1: Viewport dimensions set correctly
  grep "viewport_width=1024" project.godot && grep "viewport_height=512" project.godot
  # Assert: Both lines present

  # AC2: Stretch mode changed to viewport
  grep 'stretch/mode="viewport"' project.godot
  # Assert: Line present

  # AC3: Aspect mode is expand
  grep 'stretch/aspect="expand"' project.godot
  # Assert: Line present

  # AC4: Window overrides removed or updated
  ! grep "window_width_override=1152" project.godot
  # Assert: Old override NOT present
  ```

  **Commit**: NO (groups with Task 4)

---

- [x] 3. Update Camera2D Zoom to Integer

  **What to do**:
  - In `player.tscn`, find the Camera2D node (line 70-74)
  - Change `zoom = Vector2(1.25, 1.25)` to `zoom = Vector2(2, 2)`

  **Must NOT do**:
  - Do NOT change `position_smoothing_enabled` or `position_smoothing_speed`
  - Do NOT change `physics_interpolation_mode`
  - Do NOT add any new properties to the camera
  - Do NOT modify any other nodes in player.tscn

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single line change in scene file
  - **Skills**: `[]`
    - No specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (sequential)
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:
  - `player.tscn:70-74` - Camera2D node definition
    ```
    [node name="Camera2D" type="Camera2D" parent="."]
    physics_interpolation_mode = 2
    zoom = Vector2(1.25, 1.25)  ← CHANGE THIS LINE
    position_smoothing_enabled = true
    position_smoothing_speed = 8.0
    ```

  **Acceptance Criteria**:

  ```bash
  # AC1: Camera zoom is exactly Vector2(2, 2)
  grep 'zoom = Vector2(2, 2)' player.tscn
  # Assert: Line present

  # AC2: Old zoom value NOT present
  ! grep 'zoom = Vector2(1.25, 1.25)' player.tscn
  # Assert: Old value NOT present

  # AC3: Other camera properties unchanged
  grep 'position_smoothing_speed = 8.0' player.tscn
  # Assert: Other properties still present
  ```

  **Commit**: NO (groups with Task 4)

---

- [x] 4. Verify Changes and Commit

  **What to do**:
  - Run all acceptance criteria from Tasks 2 and 3
  - Launch game with `godot_run_project` to verify no runtime errors
  - Capture debug output to check for warnings
  - Create git commit with all changes

  **Must NOT do**:
  - Do NOT make additional changes if tests fail (report failure instead)
  - Do NOT push to remote (commit only)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification and commit task
  - **Skills**: `["git-master"]`
    - git-master: Required for proper commit workflow

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (final)
  - **Blocks**: None
  - **Blocked By**: Task 3

  **References**:
  - `project.godot` - Verify all display settings
  - `player.tscn` - Verify camera zoom
  - `.sisyphus/evidence/before-pixel-fix.md` - Compare against snapshot

  **Acceptance Criteria**:

  ```bash
  # AC1: All project.godot settings correct
  grep "viewport_width=1024" project.godot && \
  grep "viewport_height=512" project.godot && \
  grep 'stretch/mode="viewport"' project.godot && \
  grep 'stretch/aspect="expand"' project.godot
  # Assert: All four lines present

  # AC2: Camera zoom correct
  grep 'zoom = Vector2(2, 2)' player.tscn
  # Assert: Line present
  ```

  **Runtime Verification** (using godot_run_project):
  ```
  1. Launch game with godot_run_project
  2. Wait 5 seconds for initialization
  3. Check godot_get_debug_output for errors
  4. Stop project with godot_stop_project
  5. Assert: No critical errors in output
  ```

  **Evidence to Capture:**
  - [ ] Terminal output from grep assertions
  - [ ] Debug output from godot_run_project

  **Commit**: YES
  - Message: `fix(display): implement integer pixel scaling with 1024×512 base`
  - Files: `project.godot`, `player.tscn`
  - Pre-commit: Run acceptance criteria greps

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 4 | `fix(display): implement integer pixel scaling with 1024×512 base` | project.godot, player.tscn | grep assertions |

---

## Success Criteria

### Verification Commands
```bash
# Viewport settings
grep "viewport_width=1024" project.godot  # Expected: line present
grep "viewport_height=512" project.godot  # Expected: line present

# Stretch settings
grep 'stretch/mode="viewport"' project.godot  # Expected: line present
grep 'stretch/aspect="expand"' project.godot  # Expected: line present

# Camera zoom
grep 'zoom = Vector2(2, 2)' player.tscn  # Expected: line present
```

### Final Checklist
- [ ] Viewport is 1024×512 (32×16 tile grid)
- [ ] Stretch mode is "viewport" (not "canvas_items")
- [ ] Aspect mode is "expand" (show more on smaller screens)
- [ ] Camera zoom is 2.0 (integer, not 1.25)
- [ ] Game launches without errors
- [ ] Old 1152×648 override removed/updated
- [ ] No game logic or assets modified

---

## Rollback Plan

If changes cause issues:
```bash
git checkout HEAD~1 -- project.godot player.tscn
```

Or restore from snapshot in `.sisyphus/evidence/before-pixel-fix.md`
