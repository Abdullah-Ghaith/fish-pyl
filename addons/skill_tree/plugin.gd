@tool
extends EditorPlugin
## Registers the Skill Tree dev tool as a main-screen editor.
##
## Deliberately does NOT implement _handles/_edit. A plugin that owns a main
## screen AND handles a resource type gets _make_visible(false) every time the
## selection changes, which blanks the workspace while its tab stays lit. Trees
## are picked from the tool's own toolbar instead.

const ICON_PATH := "res://addons/skill_tree/icon.svg"
const EditorScript_ := preload("res://addons/skill_tree/editor/skill_tree_editor.gd")

var _editor: EditorScript_


func _enter_tree() -> void:
	_editor = EditorScript_.new()
	_editor.undo_redo = get_undo_redo()
	EditorInterface.get_editor_main_screen().add_child(_editor)
	_editor.hide()


func _exit_tree() -> void:
	if _editor != null:
		_editor.queue_free()
		_editor = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "SkillTree"


func _get_plugin_icon() -> Texture2D:
	if ResourceLoader.exists(ICON_PATH):
		return load(ICON_PATH) as Texture2D
	return null


func _make_visible(visible: bool) -> void:
	if _editor == null:
		return
	_editor.visible = visible
	if visible:
		_editor.refresh_tree_list()
