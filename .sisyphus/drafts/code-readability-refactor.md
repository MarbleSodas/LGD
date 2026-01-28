# Draft: Code Readability Refactor

## Project Overview
- **Type**: Godot 4.5 top-down cozy farming/automation game
- **Core Systems**: PlantingSystem, Rat AI automation, Building/Plant management
- **Structure**: Manager-Component pattern with autoloads

## Research Findings

### Current Class Hierarchy (Inconsistent)
```
Node2D
├── DirectionalBuilding
│   ├── BuildingBase (abstract)
│   ├── ProcessorBuilding (NOT extending BuildingBase!)
│   └── StorageBuilding (NOT extending BuildingBase!)
├── MushroomHouse (standalone, no shared base)

Sprite2D
├── Plant
│   ├── TreePlant
│   └── StoneDeposit
```

### Identified Code Smells

1. **Duplicated Interaction Code** (~4 implementations)
   - `interact()`, `close_interaction()`, `on_ui_closed()` in:
     - `BuildingBase` (lines 33-48)
     - `ProcessorBuilding` (lines 74-88)
     - `StorageBuilding` (lines 34-76)
     - `MushroomHouse` (lines 105-127)
   
2. **Duplicated Harvest Logic** (~3 implementations)
   - `harvest()` method nearly identical in:
     - `BuildingBase` (lines 69-103)
     - `ProcessorBuilding` (lines 356-395)
     - `StorageBuilding` (lines 88-124)

3. **Duplicated Save/Load Patterns**
   - `get_save_data()`, `load_save_data()` in every building
   - `load_base_save_data()` exists but not used consistently

4. **Hardcoded Node Paths**
   - `$AnimationPlayer`, `$Layers`, `$Layers/ArmsLayer`
   - `get_parent().get_node_or_null("Hana")` for player reference

5. **Limited Editor Configuration**
   - Few `@export` variables
   - No `@tool` scripts for preview
   - Node structure not visible in scene tree

### Potential Refactoring Approaches

**Option A: Fix Inheritance (Minimal)**
- Make `ProcessorBuilding` and `StorageBuilding` extend `BuildingBase`
- Move common interaction code to `BuildingBase`

**Option B: Component-Based Architecture**
- Create separate component nodes:
  - `InteractionComponent` (handles interact/close)
  - `HarvestComponent` (handles harvest logic)
  - `SaveableComponent` (handles save/load)
  - `ContainerComponent` (wraps inventory)
- Buildings compose components instead of inheriting behavior

**Option C: Hybrid (Inheritance + Composition)**
- Keep `BuildingBase` for common logic
- Add components for specialized behavior
- Use `@export` to configure components in editor

## User Decisions (Interview)

### Architecture Choice: COMPONENT NODES
- User wants reusable child nodes (InteractionComponent, HarvestComponent)
- Add to scenes and configure via @export
- Maximum editor visibility

### Editor Workflow: VERY IMPORTANT
- User wants to tweak harvest amounts, timers, recipes, storage slots in Inspector
- Minimal code editing for configuration

### Scope: BUILDINGS + PLANTS
- Refactor both building hierarchy AND plant hierarchy
- Create consistent component patterns across all placeable objects

### Components to Create: ALL CORE COMPONENTS
- InteractionComponent (UI binding)
- HarvestComponent (harvest logic)
- ContainerComponent (inventory wrapper)
- SaveableComponent (save/load)

### Tool Scripts: YES, LIVE PREVIEW
- Components will use @tool
- Enable footprint visualization, IO tile markers in 2D editor

### Plant Refactor: FULL COMPONENT CONVERSION
- Plants will use same component system
- GrowthComponent for growth stages
- HarvestComponent for harvest behavior
- Consistent patterns across all placeable objects

## Open Questions
- Component file organization (single folder vs per-category)?
- Should existing classes be deprecated or removed?
- Migration strategy for existing scenes?
