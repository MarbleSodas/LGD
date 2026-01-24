# Implementation Plan - Add Build Costs

Add resource costs to Tree, Barrel, and Mushroom House buildable items.

## Proposed Changes

### Configuration
Update `build_costs` dictionary in the following Resource files:

1.  **Tree** (`resources/buildables/tree.tres`)
    - Add: `build_costs = { "acorn": 1 }`

2.  **Barrel** (`resources/buildables/barrel.tres`)
    - Change: `build_costs = {}` -> `build_costs = { "wood": 20 }`

3.  **Mushroom House** (`resources/buildables/mushroom_house.tres`)
    - Change: `build_costs = {}` -> `build_costs = { "shroom": 50 }`

## Verification Plan

### Automated Verification
- Read back the `.tres` files to ensure syntax is correct and values are saved.
- Since these are data resources, no compilation is needed, but we should ensure the file format remains valid for Godot.
