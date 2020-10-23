tool
extends EditorPlugin

var patchSpriteEditor = preload("patchSpriteEditor.gd").new()
var spriteFrameEditor = preload("spriteFrameEditor.gd").new()
var basePatchEditor = preload("basePatchEditor.gd").new()
var currentEditor


func _enter_tree():
	patchSpriteEditor.setup(self)
	basePatchEditor.setup(self)
	add_custom_type("PatchSprite", "Node2D", preload("patchSprite.gd"), get_editor_interface().get_base_control().get_icon("Node2D", "EditorIcons"))
	add_custom_type("SpriteFrame", "Node", preload("spriteFrame.gd"), null)

func _exit_tree():
	patchSpriteEditor.unsetup(self)
	basePatchEditor.unsetup(self)
	remove_custom_type("PatchSprite")
	remove_custom_type("SpriteFrame")

func handles(p_object):
	return p_object is preload("patchSprite.gd") || p_object is preload("basePatch.gd")# || p_object is preload("spriteFrame.gd")

func edit(p_object):
	if p_object is preload("patchSprite.gd"):
		patchSpriteEditor.edit(p_object)
		currentEditor = patchSpriteEditor
#	elif p_object is preload("spriteFrame.gd"):
#		spriteFrameEditor.edit(p_object)
#		currentEditor = spriteFrameEditor
	elif p_object is preload("basePatch.gd"):
		basePatchEditor.edit(p_object)
		currentEditor = basePatchEditor
	elif currentEditor:
		currentEditor.edit(null)
		currentEditor = null

func make_visible(p_visible):
	if currentEditor:
		currentEditor.make_visible(p_visible)

func forward_canvas_draw_over_viewport(p_overlay):
	if currentEditor:
		currentEditor.forward_canvas_draw_over_viewport(p_overlay)

func forward_canvas_gui_input(p_event):
	if currentEditor:
		currentEditor.forward_canvas_gui_input(p_event)
