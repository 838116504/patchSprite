tool
class_name HPatchContainer
extends "res://addons/patchSprite/basePatchContainer.gd"

func update_min_size():
	minSize = Vector2.ZERO
	for i in children:
		if i.had_method("update_min_size"):
			i.update_min_size()
		
		minSize = Vector2(minSize.x + i.minSize.x, max(minSize.y, i.minSize.y))

func update_min_size_by_child():
	minSize = Vector2.ZERO
	for i in children:
		minSize = Vector2(minSize.x + i.minSize.x, max(minSize.y, i.minSize.y))
	
	if parent != null:
		parent.update_min_size_by_child()
