class_name BuildableItem
extends Resource

## Unique identifier for the item (e.g., "dandelion")
@export var id: String = ""

## Name displayed in the UI
@export var display_name: String = ""

## Icon used in the build menu and hotbar
@export var icon: Texture2D

## The scene to be instantiated when placed
@export var scene: PackedScene

## Texture used for the placement preview
@export var preview_texture: Texture2D

## Frame index for the preview sprite (if using a spritesheet)
@export var preview_frame: int = 0

## Number of horizontal frames in the preview texture (for calculating frame width)
@export var preview_hframes: int = 1

## Dictionary of required materials: { "item_id": quantity }
## Example: { "dandelion_tuft": 1 } means 1 dandelion tuft is needed to place this
@export var build_costs: Dictionary = {}
