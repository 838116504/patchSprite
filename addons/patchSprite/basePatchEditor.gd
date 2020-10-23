tool
extends Reference

const LINE_HALF_WIDTH = 2.0

var editObj = null
var editorInterface:EditorInterface
var viewport:Viewport
var patchSprite = null

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
	find_patch_sprite()
	
	if editObj:
		if patchSprite:
			patchSprite.connect("patches_changed", self, "_on_patchSprite_patches_changed")
			patchSprite.connect("size_changed", self, "_on_patchSprite_size_changed")
			patchSprite.connect("offset_changed", self, "_on_patchSprite_offset_changed")
		viewport = editorInterface.get_edited_scene_root().get_parent()
	else:
		viewport = null
	
	update_viewport()

func make_visible(p_visible):
	if not p_visible:
		edit(null)

func forward_canvas_draw_over_viewport(p_overlay:Control):
	if patchSprite == null || editObj == null:
		return
	
	var edgeColor := Color(0xDE8B61FF)
	var edgeColor2 := Color(0x916A56FF)
	var xform:Transform2D= viewport.global_canvas_transform * patchSprite.get_global_transform()
	var points:Array = [ xform.xform(editObj.get_global_top_pos()), xform.xform(editObj.get_global_right_pos()), 
			xform.xform(editObj.get_global_bottom_pos()), xform.xform(editObj.get_global_left_pos())]
	var verticalVec:Vector2
	
	for i in points.size():
		p_overlay.draw_line(points[i-1], points[i], edgeColor, LINE_HALF_WIDTH * 2.0 - 2.0)
		verticalVec = (points[i-1] - points[i]).rotated(PI/2.0).normalized() * (LINE_HALF_WIDTH - 1.0)
		p_overlay.draw_line(points[i - 1] + verticalVec, points[i] + verticalVec, edgeColor2, 1.0)
		p_overlay.draw_line(points[i - 1] - verticalVec, points[i] - verticalVec, edgeColor2, 1.0)
	
func forward_canvas_gui_input(p_event):
	return false

func find_patch_sprite():
	if patchSprite:
		if patchSprite.is_connected("patches_changed", self, "_on_patchSprite_patches_changed"):
			patchSprite.disconnect("patches_changed", self, "_on_patchSprite_patches_changed")
		if patchSprite.is_connected("size_changed", self, "_on_patchSprite_size_changed"):
			patchSprite.disconnect("size_changed", self, "_on_patchSprite_size_changed")
		if patchSprite.is_connected("offset_changed", self, "_on_patchSprite_offset_changed"):
			patchSprite.disconnect("offset_changed", self, "_on_patchSprite_offset_changed")
		patchSprite = null
	if editObj == null:
		return null
	
	var root = editObj
	while root.parent:
		root = root.parent
	
	var current = editorInterface.get_edited_scene_root()
	var needProcess = []
	
	while current:
		if current is preload("patchSprite.gd"):
			if current.patches == root:
				patchSprite = current
				break
		
		for i in current.get_children():
			needProcess.append(i)
		
		if needProcess.size() <= 0:
			break
		
		current = needProcess.back()
		needProcess.pop_back()

func get_canvas_item_editor():
	return editorInterface.get_editor_viewport().get_child(0)

func update_viewport():
	get_canvas_item_editor().update_viewport()

func update():
	if !patchSprite:
		return
	
	if patchSprite.dirtyDraw:
		yield(patchSprite, "draw_finished")
	
	update_viewport()

func _on_patchSprite_patches_changed():
	update()

func _on_patchSprite_size_changed():
	update()

func _on_patchSprite_offset_changed():
	update()
