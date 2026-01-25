class_name InventoryItem
extends Resource

## Unique identifier (e.g., "wood", "stone", "seeds")
@export var id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Icon texture for inventory display
@export var icon: Texture2D

## Maximum stack size (1 = non-stackable)
@export var max_stack: int = 400

## Item description for tooltips (future)
@export var description: String = ""

## Item category for sorting/filtering (future)
@export_enum("Material", "Tool", "Consumable", "Misc") var category: String = "Misc"
