@tool
extends EditorPlugin

const AUTOLOAD_NAME = "GodotCLI"
const AUTOLOAD_SETTING = "autoload/" + AUTOLOAD_NAME
const AUTOLOAD_PATH = "res://addons/godot_cli/cli_server.gd"

func _enter_tree() -> void:
	if not ProjectSettings.has_setting(AUTOLOAD_SETTING):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		print("GodotCLI: Plugin enabled - autoload added")

func _exit_tree() -> void:
	if ProjectSettings.has_setting(AUTOLOAD_SETTING):
		remove_autoload_singleton(AUTOLOAD_NAME)
		print("GodotCLI: Plugin disabled - autoload removed")
