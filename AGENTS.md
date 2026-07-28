# LGD Project Guidelines

## Project identity

LGD is a Godot 4.7 pixel-art game written in GDScript. The configured entry
scene is `res://scenes/start_menu/start_menu.tscn`; gameplay lives in
`res://scenes/world/world.tscn`.

Preserve the pixel-art rendering settings, the 1024×512 reference viewport, and
the existing data-driven resource model unless a task explicitly changes them.

## Read before editing

1. Inspect `git status --short` and preserve unrelated user changes.
2. Read `project.godot` for autoloads, input actions, plugins, and the engine
   feature version.
3. Trace a feature through its `.tres` data, `.tscn` composition, GDScript, and
   autoload dependencies before changing it.
4. Search for all `res://` references before moving or renaming a scene,
   resource, or script.

Do not edit `.godot/`; it is generated local cache. Commit Godot-generated
`.gd.uid` files with their scripts. Perform scene/resource moves in Godot when
practical so UIDs and references remain coherent.

## Source layout

- `assets/`: source art, fonts, licenses, and Godot import metadata.
- `resources/`: data assets for items, buildables, recipes, dialogue, quests,
  NPC actions, and UI.
- `scenes/`: gameplay, entities, systems, player, world, and start-menu scenes.
- `scripts/autoloads/`: global state and services registered in `project.godot`.
- `scripts/components/`: reusable behavior/state components.
- `scripts/systems/`: placement, deletion, and interaction controllers.
- `ui/`: UI scenes, scripts, themes, and atlas resources.
- `addons/`: development/editor integrations; keep runtime-only tooling out of
  production exports.

Prefer the organized subdirectories over adding new legacy root-level scenes or
scripts.

## GDScript conventions

- Use tabs for GDScript indentation and LF line endings.
- Use `snake_case` for new files, variables, signals, and functions.
- Use `PascalCase` for `class_name` types and typed resource classes.
- Add explicit return types and parameter types for public and nontrivial
  methods.
- Prefer signals or a narrow service API over repeated scene-tree searches.
- Use `@export` for scene-authored configuration and `@onready` for required
  child-node references.
- Guard optional nodes/resources and report actionable failures with
  `push_warning` or `push_error`.
- Keep `_process` and `_input` allocation-light; cache stable lookups.
- Avoid adding hard-coded `res://` debug resources or magic node paths.
- Add comments for intent, invariants, or Godot-specific traps, not line-by-line
  narration.

Do not mass-rename existing PascalCase component files as part of unrelated
work. Improve naming when a task already requires touching the relevant API and
all references can be validated.

## Scenes and resources

- Compose behavior in scenes and reusable components; keep item/buildable/quest
  values in typed `.tres` resources.
- Keep scene node names stable when scripts, saves, or UI lookups depend on
  them.
- Give each maintained scene/resource a unique UID. Remove obsolete duplicate
  scenes after verifying that no path or UID references remain.
- Treat a missing external resource as a release-blocking defect even if Godot
  logs it and exits with status `0`.
- After changing a `.tscn` or `.tres`, load the owning scene and at least one
  consumer scene.
- Inspect diffs after editor saves; Godot may rewrite ordering, UIDs, or
  whitespace outside the intended change.

## Global state and saves

The current autoloads include inventory, registries, save, dialogue, quest,
game-state/tips aliases, game services, and development tooling. Before adding
an autoload, prefer extending an existing focused service or passing a
dependency explicitly.

Never register the same stateful script under multiple names without a clear
instance-separation contract. Remember that each autoload name creates a
separate node and separate state.

Save changes must remain backward-compatible or include an explicit migration:

- Preserve existing keys where possible.
- Default missing keys when loading older saves.
- Increment the save version when the stored shape changes materially.
- Test new-world creation, save, load, return-to-menu, and deletion behavior.

Do not inspect, modify, or delete real `user://saves` during routine automated
checks. Use an isolated user-data directory or a temporary project copy.

## Godot CLI and runtime tooling

The `godot-cli` executable installed on this workstation is the Godot-MCP CLI.
It expects the separate `addons/godot_mcp` C# addon. The repository's
`addons/godot_cli` GDScript TCP bridge is not that addon and cannot be driven
with `godot-cli run-tool`.

Use `$lgd-godot-cli` when available. Always run:

```bash
godot-cli --version
godot-cli status --path .
```

Only use `godot-cli wait-for-ready` or `godot-cli run-tool` after status confirms
that the MCP server itself responds. Do not install/configure an addon, add C#,
log in, or enable broad tool families without an explicit request.

The raw `addons/godot_cli` bridge exposes code execution and file mutation.
Restrict it to trusted local development, never ship it in an export, inspect
before mutating, and do not use `eval` or delete operations without explicit
authorization.

## Validation

On this macOS workstation the Godot binary is:

```text
/Applications/Godot.app/Contents/MacOS/Godot
```

Run a full import/parse check after structural, script, scene, or resource
changes:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --import --no-header
```

Smoke-test both entry points:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --quit-after 120 --no-header

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --scene res://scenes/world/world.tscn \
  --quit-after 120 --no-header
```

Read the logs. Fail validation on `ERROR`, `SCRIPT ERROR`, parse errors, missing
resources, or failed assertions even when the process exit code is zero.

When a result may depend on stale imports, reproduce in a temporary copy that
excludes `.git` and `.godot`; do not delete the user's cache or interrupt an
open editor merely to diagnose it.

There is currently no automated test suite or CI pipeline, so changes need a
focused manual/runtime smoke test. Add small deterministic tests alongside a
test framework when one is introduced; do not invent a one-off framework in an
unrelated feature.

## Completion checklist

- Inspect the final diff and `git status`.
- Confirm every new or moved `res://` reference resolves.
- Run the narrowest relevant scene plus the main-scene smoke test.
- Report exact commands and all remaining warnings/errors.
- Do not stage, commit, push, or alter user saves unless requested.
