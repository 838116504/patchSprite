tool
extends Resource

enum { REGION_FLAG_FROM_LEFT = 0, REGION_FLAG_FROM_CENTER, REGION_FLAG_FROM_RIGHT, REGION_FLAG_ONLY_CHILD }

signal mode_changed
signal ratio_changed
signal region_changed(p_length, p_flag)
signal min_size_changed

var ratio := 1.0 setget , get_ratio
var length := 1.0 setget , get_length
var minSize := Vector2.ZERO setget , get_min_size

var parent setget , get_parent
var region:Rect2 setget , get_region		# texture uv range
var rect:Rect2 setget , get_rect
var index := 0 setget , get_index
var polygons := [] setget , get_polygons
var xAxis := Vector2.RIGHT setget set_x_axis, get_x_axis
var yAxis := Vector2.DOWN setget set_y_axis, get_y_axis

func _set(p_property, p_value):
	if p_property == "Ratio":
		set_ratio(p_value)
	elif p_property == "Length":
		set_length(p_value)
	elif p_property == "MinSize":
		set_min_size(p_value)
	else:
		return false
	
	return true

func _get(p_property):
	if p_property == "Ratio":
		return get_ratio()
	elif p_property == "Length":
		return get_length()
	elif p_property == "MinSize":
		return get_min_size()
	
	return null

func _get_property_list():
	var ret := []
	ret.append({ "name":"Ratio", "type":TYPE_REAL, "hint":PROPERTY_HINT_RANGE, "hint_string":"0,1,or_greater", "usage":PROPERTY_USAGE_DEFAULT })
	ret.append({ "name":"Length", "type":TYPE_REAL, "hint":PROPERTY_HINT_RANGE, "hint_string":"0,1,1,or_greater", "usage":PROPERTY_USAGE_DEFAULT })
	ret.append({ "name":"MinSize", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT })
	return ret

func _draw(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	pass

func to_local(p_pos:Vector2):
	if is_normal_axis():
		return p_pos
	
	if yAxis.x == 0.0:
		var x = p_pos.x / xAxis.x
		return Vector2(x, p_pos.y - (xAxis * x).y)
	if xAxis.x == 0.0:
		var y = p_pos.x / yAxis.x
		return Vector2(p_pos.y - (yAxis * y).y, y)
	var dx = xAxis.y / xAxis.x
	var dy = yAxis.y / yAxis.x
	var x = (dy * p_pos.x - p_pos.y) / (dy - dx)
	return Vector2(x / xAxis.x, (p_pos.x - x) / yAxis.x)

func to_global(p_pos:Vector2) -> Vector2:
	if is_normal_axis():
		return p_pos
	
	return xAxis * p_pos.x + yAxis * p_pos.y

func has_point(p_pos:Vector2) -> bool:
	var localPos = to_local(p_pos)
	if !rect.has_point(localPos) || polygons.size() <= 0:
		return false
	
	for i in polygons:
		if Geometry.is_point_in_polygon(p_pos, i):
			return true
	
	return false

func get_local_top_pos() -> Vector2:
	return rect.position

func get_local_left_pos() -> Vector2:
	return rect.position + Vector2(0.0, rect.size.y)

func get_local_right_pos() -> Vector2:
	return rect.position + Vector2(rect.size.x, 0.0)

func get_local_bottom_pos() -> Vector2:
	return rect.end

func get_global_top_pos() -> Vector2:
	return to_global(rect.position)

func get_global_left_pos() -> Vector2:
	return to_global(rect.position + Vector2(0.0, rect.size.y))

func get_global_right_pos() -> Vector2:
	return to_global(rect.position + Vector2(rect.size.x, 0.0))

func get_global_bottom_pos() -> Vector2:
	return to_global(rect.end)

func get_local_region_top_pos() -> Vector2:
	return region.position

func get_local_region_left_pos() -> Vector2:
	return region.position + Vector2(0.0, region.size.y)

func get_local_region_right_pos() -> Vector2:
	return region.position + Vector2(region.size.x, 0.0)

func get_local_region_bottom_pos() -> Vector2:
	return region.end

func get_global_region_top_pos() -> Vector2:
	return to_global(region.position)

func get_global_region_left_pos() -> Vector2:
	return to_global(region.position + Vector2(0.0, region.size.y))

func get_global_region_right_pos() -> Vector2:
	return to_global(region.position + Vector2(region.size.x, 0.0))

func get_global_region_bottom_pos() -> Vector2:
	return to_global(region.end)

func is_normal_axis() -> bool:
	return xAxis == Vector2.RIGHT && yAxis == Vector2.DOWN

func _get_rect_by_uv(p_rect:Rect2, p_uvRect:Rect2) -> Rect2:
	if p_uvRect == region:
		return p_rect
	
	var uvScale = p_rect.size / region.size
	var uvRect = p_uvRect.clip(region)
	return Rect2(p_rect.position + (uvRect.position - region.position) * uvScale, uvRect.size * uvScale)

func _rect_to_points(p_rect:Rect2) -> PoolVector2Array:
	return PoolVector2Array([ to_global(p_rect.position), to_global(p_rect.position + Vector2(p_rect.size.x, 0.0)),  
			to_global(p_rect.end), to_global(p_rect.position + Vector2(0.0, p_rect.size.y)) ])

func _get_triangle_area(p_triangle:PoolVector2Array) -> float:
	return abs((p_triangle[1] - p_triangle[0]).cross(p_triangle[2] - p_triangle[0]) * 0.5)

func _get_triangle_interpolate(p_triangle:PoolVector2Array, p_pos:Vector2) -> Vector3:
	if p_triangle.size() != 3:
		return Vector3.ZERO
	
	var triangleArea = _get_triangle_area(p_triangle)
	var smallAreas = []
	for i in 3:
		smallAreas.append(_get_triangle_area(PoolVector2Array([p_triangle[(i+1)%3], p_triangle[(i+2)%3], p_pos])))
	
	return Vector3(smallAreas[0] / triangleArea, smallAreas[1] / triangleArea, smallAreas[2] / triangleArea)

func _clip_uvs(p_uvs:PoolVector2Array, p_texture:Texture):
#	if p_points.size() == 3:
#		var texPoints = [ Vector2.ZERO, Vector2(p_texture.get_size().x, 0.0), p_texture.get_size(), Vector2(0.0, p_texture.get_size().y)]
#		var r_uvs = Geometry.intersect_polygons_2d(texPoints, p_uvs)
#		if r_uvs.size() <= 0:
#			return [ PoolVector2Array(), PoolVector2Array() ]
#		r_uvs = r_uvs[0]
#		var r_points := PoolVector2Array()
#		r_points.resize(r_uvs.size())
#		var interpolate
#		for i in r_uvs.size():
#			interpolate = _get_triangle_interpolate(p_uvs, r_uvs[i])
#			r_points[i] = p_points[0] * interpolate.x + p_points[1] * interpolate.y + p_points[2] * interpolate.z
#
#		return [r_points, r_uvs]
	var scale = rect.size / region.size
	var texPoints = [ Vector2.ZERO, Vector2(p_texture.get_size().x, 0.0), p_texture.get_size(), Vector2(0.0, p_texture.get_size().y)]
	var r_uvs = Geometry.intersect_polygons_2d(texPoints, p_uvs)
	if r_uvs.size() <= 0:
		return [ PoolVector2Array(), PoolVector2Array() ]
	r_uvs = r_uvs[0]
	var r_points := PoolVector2Array()
	r_points.resize(r_uvs.size())
	for i in r_uvs.size():
		r_points[i] = to_global(rect.position + (to_local(r_uvs[i]) - region.position) * scale)
	
	return [r_points, r_uvs]


func set_ratio(p_value:float):
	if p_value == ratio:
		return
	
	ratio = p_value
	
	emit_signal("ratio_changed")

func _set_length(p_value:float, p_flag:int):
	if p_value < 0:
		return
	
	if !parent:
		if length == p_value:
			return
		length = p_value
	elif !parent.dirtyChildRegion && length == p_value:
		return
	
	emit_signal("region_changed", p_value, p_flag)

func set_length(p_value:float):
	_set_length(p_value, REGION_FLAG_FROM_CENTER)

func set_length_from_left(p_value:float):
	_set_length(p_value, REGION_FLAG_FROM_LEFT)

func set_length_from_right(p_value:float):
	_set_length(p_value, REGION_FLAG_FROM_RIGHT)

func set_min_size(p_value:Vector2):
	p_value = Vector2(max(p_value.x, 0.0), max(p_value.y, 0.0))
	if p_value == minSize:
		return
	
	minSize = p_value
	if parent && parent.has_method("update_min_size_by_child"):
		parent.update_min_size_by_child()
	
	emit_signal("min_size_changed")

func get_ratio() -> float:
	return ratio

func get_length() -> float:
	if parent && parent.dirtyChildRegion:
		parent.update_child_region()
	return length

func get_min_size() -> Vector2:
	return minSize

func get_parent():
	return parent

func get_region() -> Rect2:
	if parent && parent.dirtyChildRegion:
		parent.update_child_region()
	return region

func get_rect() -> Rect2:
	return rect

func get_index() -> int:
	if !parent:
		return -1
	
	return index

func get_polygons() -> Array:
	return polygons

func set_x_axis(p_value:Vector2):
	xAxis = p_value.normalized()

func get_x_axis() -> Vector2:
	return xAxis

func set_y_axis(p_value:Vector2):
	yAxis = p_value.normalized()

func get_y_axis() -> Vector2:
	return yAxis

func set_region(p_value:Rect2):
	region = p_value
