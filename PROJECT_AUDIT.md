# LGD Project Audit

Date: 2026-07-28
Scope: project structure, stashed work, Godot configuration, resource integrity,
runtime startup, global state, inventory behavior, and development tooling.

## Current status

LGD now imports from a clean checkout and starts both configured entry points
under Godot 4.7.1 without resource, parse, script, or assertion errors. The
useful behavior from the local stashes has been integrated into the maintained
project structure; the stashes remain available as an untouched recovery point.

This was a stabilization pass, not a wholesale architecture rewrite. It fixes
the concrete blockers and removes invalid duplicates while preserving the
existing data-driven resource model, pixel-art configuration, and save shape.

## Integrated and resolved

### Missing Glider dialogue

`resources/dialogues/simple_greeting.tres` has been restored with the historical
UID and migrated to the current typed `DialogueResource`/`DialogueEntry` schema.
The Glider scene and world now load without a missing-resource error.

The separate `H` debug shortcut was removed because it referenced a deleted
dialogue using an obsolete schema.

### Container interaction work from the stash

The maintained player and UI scenes now include the useful behavior from the
older stash:

- the player has a stable `player` group and a narrow movement lock API;
- opening a container locks movement and displays a non-interactive dimming
  layer behind the UI;
- closing the container restores movement and fades the layer out;
- the maintained container panel uses the intended title font and scene UID.

The legacy player/UI paths from the stash were not restored.

### Inventory integrity

Returning a cursor-held item no longer adds it twice or silently loses overflow.
Items return to their source stack first, use remaining inventory capacity once,
and stay on the cursor with a warning when no capacity remains.

External callers can no longer overwrite a held overflow stack. Container
sorting also uses the actual `InventoryItem` categories.

### Resource and scene cleanup

The obsolete root-level tree and stone-deposit scenes were removed after
confirming the maintained scenes live under
`scenes/entities/buildables/...` and no active `res://` reference uses the old
paths. The duplicate untracked barrel scene was also removed.

The Rat Manager scene had a malformed UID. It now has a valid generated UID,
and its consumer reference has been updated.

### Project configuration and development tooling

The project feature version is aligned with Godot 4.7. The unused `DataManager`
autoload registration was removed; the established `GameState` and
`TipsManager` compatibility names remain.

The custom cursor remains a project-wide display setting, so it is active in
the start menu as well as gameplay.

The repository's raw GodotCLI bridge is now:

- disabled in the committed project configuration and enabled only when a
  developer deliberately activates the editor plugin;
- editor-plugin managed instead of a persistent project autoload;
- disabled in release builds;
- disabled unless the process receives `--enable-godot-cli`;
- bound to `127.0.0.1`;
- restricted to `res://` and `user://` for file commands;
- absent from normal main-scene and world runs.

The bridge still exposes powerful mutation, file, and evaluation commands when
explicitly enabled and should remain trusted-local development tooling.

### Focused progression services

The temporary merged `data_manager.gd` compatibility script has been retired.
`GameState` now owns only active-world identity and story flags, while
`TipsManager` owns only tutorial-tip acknowledgement. Their established
autoload names and the existing `story_flags` and `tips` save keys are
unchanged.

`SaveManager` now uses each service's serialization API instead of reaching
into `GameState`'s mutable dictionary. Loading preserves the prior signal
behavior so quest restoration is not triggered prematurely.

### UI responsibility cleanup

The UI scene now has a focused `GameUI` controller. It owns top-level cancel
routing, panel close priority, pause-menu opening, and modal
dimming/player locks. `world.gd` delegates UI requests instead of knowing each
panel's node path, and `ContainerPanel` no longer searches the world tree for
presentation dependencies.

The unused `GameServices` locator and uninstantiated `InteractionComponent`
were removed. In addition to being dead code, the locator's UI contract
required a `Control` even though the maintained UI root is a `CanvasLayer`.

## Architecture assessment

### Strengths

- Typed custom resources keep items, buildables, dialogue, quests, and recipes
  data-driven.
- Maintained scenes are organized by entity/system responsibility.
- Reusable components and narrow manager APIs provide good extension points.
- Save data is versioned and defaults many missing sections.
- The 1024×512 pixel-art viewport and rendering choices remain explicit.

### Remaining improvement work

1. **Automated validation:** there is no test framework or CI pipeline. Add
   log-aware import and entry-scene smoke checks; Godot may exit with status
   `0` even after logging a resource error.
2. **Characterization tests:** inventory transfer/overflow, save round trips,
   registry unlocks, quests, placement footprints, and processor recipes are
   the highest-value initial targets.
3. **Large systems:** inventory, placement, mushroom-house, and processor logic
   remain broad. Extract stable responsibilities only after characterization
   tests exist.
4. **Resource metadata:** older scenes/resources without declared UIDs can be
   migrated gradually when they are edited; avoid a noisy bulk editor rewrite.
5. **Release configuration:** add and validate export presets before calling
   the project release-ready.

These are maintainability investments rather than current startup blockers.

## Verification

The following checks passed on the working tree and on a temporary copy that
excluded both `.git` and `.godot`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --import --no-header

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --quit-after 120 --no-header

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --scene res://scenes/world/world.tscn \
  --quit-after 120 --no-header
```

Focused scene startup also passed for:

- `res://scenes/entities/npcs/glider.tscn`
- `res://scenes/entities/buildables/plants/tree.tscn`
- `res://scenes/entities/buildables/resources/stone_deposit.tscn`

All statically discoverable `res://` references resolve, and no duplicate
declared scene/resource UIDs were found. `godot-cli 0.20.0` still reports its
separate Godot-MCP server as unavailable; that is expected because LGD contains
the raw GDScript bridge, not the C# Godot-MCP addon.
