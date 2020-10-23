tool
extends Node

const NOTIFICATION_ADDED_SPRITE_FRAME = 9991

signal offset_changed
signal region_changed
signal moved_in_parent
signal unparented

export var offset := Vector2(0, 0) setget set_offset
export var region := Rect2(Vector2.ZERO, Vector2.ZERO) setget set_region

func _notification(what):
	match what:
		NOTIFICATION_PARENTED:
			get_parent().notification(NOTIFICATION_ADDED_SPRITE_FRAME)
		NOTIFICATION_MOVED_IN_PARENT:
			emit_signal("moved_in_parent")
		NOTIFICATION_UNPARENTED:
			emit_signal("unparented")

func set_offset(p_value:Vector2):
	if p_value == offset:
		return
	
	offset = p_value
	emit_signal("offset_changed")

func set_region(p_value:Rect2):
	if p_value == region:
		return
	
	region = p_value
	emit_signal("region_changed")
