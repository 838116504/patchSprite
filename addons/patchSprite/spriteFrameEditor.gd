tool
extends Reference

var editObj = null
var editorInterface:EditorInterface
var viewport:Viewport

func setup(p_plugin:EditorPlugin):
	editorInterface = p_plugin.get_editor_interface()

func unsetup(p_plugin):
	if not editorInterface:
		return
	editorInterface = null
	viewport = null
	edit(null)

func edit(p_obj):
	if editObj == p_obj:
		return
	
	if editObj:
		pass
	
	editObj = p_obj
	
	if editObj:
		viewport = editorInterface.get_edited_scene_root().get_parent()
	else:
		viewport = null
	
	update_viewport()

func make_visible(p_visible):
	if not p_visible:
		edit(null)

func forward_canvas_draw_over_viewport(p_overlay:Control):
	if editObj == null:
		return
	
	var edgeColor := Color(0xDE8B61FF)
	var edgeColor2 := Color(0x916A56FF)
	
func forward_canvas_gui_input(p_event):
	return false

func get_canvas_item_editor():
	return editorInterface.get_editor_viewport().get_child(0)

func update_viewport():
	get_canvas_item_editor().update_viewport()
