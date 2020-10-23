tool
class_name VPatchContainer
extends "res://addons/patchSprite/basePatchContainer.gd"

func _init():
	vertical = true

func update_min_size():
	minSize = Vector2.ZERO
	for i in children:
		if i.has_method("update_min_size"):
			i.update_min_size()
		
		minSize = Vector2(max(minSize.x, i.minSize.x), minSize.y + i.minSize.y)

func update_min_size_by_child():
	minSize = Vector2.ZERO
	for i in children:
		minSize = Vector2(max(minSize.x, i.minSize.x), minSize.y + i.minSize.y)
	
	if parent != null:
		parent.update_min_size_by_child()
