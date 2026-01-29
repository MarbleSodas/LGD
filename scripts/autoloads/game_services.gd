extends Node

## Centralized service locator for global game systems.
## Replaces ad-hoc group/node lookups with a clean API.

const GROUP_PLANTING_SYSTEM = "planting_system"
const GROUP_UI_LAYER = "ui_layer"

# Cached references (cleared on scene change ideally, but robust getters handle it)
var _planting_system_cache: WeakRef
var _ui_root_cache: WeakRef

var planting_system: PlantingSystem:
	get:
		return _get_planting_system()

var ui_root: Control:
	get:
		return _get_ui_root()

func _get_planting_system() -> PlantingSystem:
	if _planting_system_cache and _planting_system_cache.get_ref():
		return _planting_system_cache.get_ref() as PlantingSystem
		
	var node = get_tree().get_first_node_in_group(GROUP_PLANTING_SYSTEM)
	if node is PlantingSystem:
		_planting_system_cache = weakref(node)
		return node
	
	# Fallback: Root scene search
	var root = get_tree().current_scene
	if root:
		if root.has_node("PlantingSystem"):
			var ps = root.get_node("PlantingSystem")
			if ps is PlantingSystem:
				_planting_system_cache = weakref(ps)
				return ps
		# In case the root itself is the planting system (e.g. testing)
		if root is PlantingSystem:
			_planting_system_cache = weakref(root)
			return root
			
	return null

func _get_ui_root() -> Control:
	if _ui_root_cache and _ui_root_cache.get_ref():
		return _ui_root_cache.get_ref() as Control
		
	var node = get_tree().get_first_node_in_group(GROUP_UI_LAYER)
	if node is Control:
		_ui_root_cache = weakref(node)
		return node
		
	# Fallback
	var root = get_tree().current_scene
	if root:
		if root.has_node("UI"):
			var ui = root.get_node("UI")
			if ui is Control:
				_ui_root_cache = weakref(ui)
				return ui
		# In case root itself is UI (unlikely for main game, but possible in testing)
		if root.name == "UI" and root is Control:
			_ui_root_cache = weakref(root)
			return root
			
	return null
