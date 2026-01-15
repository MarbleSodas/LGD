extends Node

var _items: Dictionary = {}

func _ready() -> void:
	_load_items()

func _load_items() -> void:
	var path = "res://resources/items/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				var load_path = path + file_name.replace(".remap", "")
				var item = load(load_path) as InventoryItem
				if item and item.id != "":
					_items[item.id] = item
			file_name = dir.get_next()
	else:
		push_error("ItemRegistry: Could not open " + path)

func get_item(id: String) -> InventoryItem:
	return _items.get(id)
