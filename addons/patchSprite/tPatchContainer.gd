tool
class_name TPatchContainer
extends "basePatch.gd"

enum { CHILD_ID_TOP = 0, CHILD_ID_LEFT, CHILD_ID_RIGHT }

signal children_changed

var children := [ null, null, null ] setget set_children, get_children
var dirtyChildRegion := false setget , get_dirty_child_region
var splitEdgeVertices := []		# centered point, left point, right point, bottom point
var splitEdgeIndices := [ 1, 0, 0, 2, 0, 3 ]

func _init():
	set_children([])

func _get_min_heights(p_rect:Rect2) -> Array:
	var topPatch = get_top()
	var leftPatch = get_left()
	var rightPatch = get_right()
	if is_normal_axis():
		return [topPatch.minSize.y, max(leftPatch.minSize.y, rightPatch.minSize.y)]
	var ret = [ 0.0, 0.0 ]
	var bottomPos = to_global(p_rect.end)
	var topPos = to_global(p_rect.position)
	var leftPos = to_global(p_rect.position + Vector2(0.0, p_rect.size.y))
	var rightPos = to_global(p_rect.position + Vector2(p_rect.size.x, 0.0))
	if yAxis != Vector2.DOWN:
		var intersections = [ Geometry.line_intersects_line_2d(topPos, yAxis, bottomPos, Vector2.UP), 
				Geometry.line_intersects_line_2d(topPos, xAxis, bottomPos, Vector2.UP) ]
		if topPatch.minSize.x > 0.0:
			var xVec = xAxis * topPatch.minSize.x
			var lVec = leftPos - intersections[0]
			ret[0] = abs(xVec.y) + abs(tan(PI/2.0 - abs(lVec.angle_to(Vector2.DOWN)) * xVec.x))
			if topPos.x < bottomPos.x:
				ret[0] -= abs(intersections[1].y - intersections[0].y)
		if topPatch.minSize.y > 0.0:
			var yVec = yAxis * topPatch.minSize.y
			var rVec = rightPos - intersections[1]
			var temp = abs(yVec.y) + abs(tan(PI/2.0 - abs(rVec.angle_to(Vector2.DOWN)) * yVec.x))
			if topPos.x > bottomPos.x:
				temp -= abs(intersections[0].y - intersections[1].y)
			ret[0] = max(temp, ret[0])
		ret[1] = max(leftPatch.minSize.y, rightPatch.minSize.y)
	else:
		var rVec = rightPos - topPos
		var yVec = Vector2(-xAxis.x, xAxis.y) * max(topPatch.minSize.y, rightPatch.minSize.x)
		ret[0] = abs(yVec.x / sin(abs(rVec.angle_to(Vector2.DOWN))))
		ret[1] = max(topPatch.minSize.x, leftPatch.minSize.x)
	
	return ret

func _get_top_rect_and_height(p_rect:Rect2) -> Array:
	var topPatch = get_top()
	var leftPatch = get_left()
	var totalRatio = topPatch.ratio + leftPatch.ratio
	var ratio
	if totalRatio <= 0.0:
		ratio = 0.5
	else:
		ratio = topPatch.ratio / totalRatio
	var minHs = _get_min_heights(p_rect)
	
	if is_normal_axis():
		var topH = p_rect.size.y * ratio
		if topH < minHs[0]:
			topH = minHs[0]
		elif p_rect.size.y - topH < minHs[1]:
			topH = p_rect.size.y - minHs[1]
		return [Rect2(p_rect.position, Vector2(p_rect.size.x, topH)), p_rect.size.y - topH]
	
	var topPos = get_global_top_pos()
	var bottomPos = get_global_bottom_pos()
	var leftPos = get_global_left_pos()
	var rightPos = get_global_right_pos()
	if yAxis != Vector2.DOWN:
		var topRect = Rect2(p_rect.position, Vector2.ZERO)
		var splitTopPos
		if bottomPos.x < topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, yAxis, bottomPos, Vector2.UP)
		elif bottomPos.x > topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, xAxis, bottomPos, Vector2.UP)
		else:
			splitTopPos = topPos
		var yLen = abs(bottomPos.y - splitTopPos.y)
		ratio = ratio * yLen
		ratio = max(ratio, minHs[0])
		ratio = yLen - max(yLen - ratio, minHs[1])
		topRect.size = to_local(splitTopPos + Vector2(0.0, ratio) - topPos)
		return [topRect, bottomPos.y - splitTopPos.y - ratio]
	else:
		var xLen = p_rect.size.x
		ratio = (1.0 - ratio) * xLen
		ratio = max(ratio, minHs[0])
		ratio = xLen - max(xLen - ratio, minHs[1])
		var topTopPos = topPos + xAxis * ratio
		var topRect = Rect2(topPatch.to_local(topTopPos), Vector2.ZERO)
		topRect.size.x = xLen - ratio
		var topLeftPos = Geometry.line_intersects_line_2d(topPos, Vector2.DOWN, topTopPos, Vector2(-xAxis.x, xAxis.y))
		topRect.size.y = (topLeftPos - topTopPos).length()
		return [topRect, leftPos.y - topLeftPos.y]

func _get_point_global_uv(p_localPoint:Vector2, p_rect:Rect2):
	p_localPoint -= p_rect.position
	p_localPoint.x = clamp(p_localPoint.x, 0.0, p_rect.size.x - 1.0)
	p_localPoint.y = clamp(p_localPoint.y, 0.0, p_rect.size.y - 1.0)
	var uvScale = region.size / p_rect.size
	return to_global(region.position + p_localPoint * uvScale)

func _get_extra_polygons(p_rect:Rect2, p_topRect:Rect2, p_height:float, p_texture:Texture) -> Array:
	if is_normal_axis():
		return []
	
	var ret := []
	var topPatch = get_top()
	var rightPatch = get_right()
	var polygonUVs = PoolVector2Array()
	var uvScale = region.size / p_rect.size
	if yAxis == Vector2.DOWN:
		polygonUVs.append(get_global_region_top_pos())
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position)) - p_rect.position) * uvScale + region.position))
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(0.0, p_topRect.size.y))) - p_rect.position) * uvScale + region.position))
		var result = _clip_uvs(polygonUVs, p_texture)
		if result[0].size() > 2:
			ret.append(result)
		
		polygonUVs = PoolVector2Array()
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(p_topRect.size.x, 0.0)) + Vector2(0.0, p_height)) - p_rect.position) * uvScale + region.position))
		polygonUVs.append(get_global_region_bottom_pos())
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.end) + Vector2(0.0, p_height)) - p_rect.position) * uvScale + region.position))
		result = _clip_uvs(polygonUVs, p_texture)
		if result[0].size() > 2:
			ret.append(result)
	else:
		var leftPatch = get_left()
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(0.0, p_topRect.size.y))) - p_rect.position) * uvScale + region.position))
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(0.0, p_topRect.size.y)) + Vector2(0.0, p_height)) - p_rect.position) * uvScale + region.position))
		polygonUVs.append(get_global_region_left_pos())
		var result = _clip_uvs(polygonUVs, p_texture)
		if result[0].size() > 2:
			ret.append(result)
		
		polygonUVs = PoolVector2Array()
		polygonUVs.append(get_global_region_right_pos())
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(p_topRect.size.x, 0.0)) + Vector2(0.0, p_height)) - p_rect.position) * uvScale + region.position))
		polygonUVs.append(to_global((to_local(topPatch.to_global(p_topRect.position + Vector2(p_topRect.size.x, 0.0))) - p_rect.position) * uvScale + region.position))
		result = _clip_uvs(polygonUVs, p_texture)
		if result[0].size() > 2:
			ret.append(result)
	
	for i in ret:
		for j in i[1].size():
			i[1][j] = i[1][j] / p_texture.get_size()
	
	return ret

func _draw_child(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	var topPatch = get_top()
	var rightPatch = get_right()
	var leftPatch = get_left()
	if is_normal_axis():
		var data = _get_top_rect_and_height(p_rect)
		var topRect = data[0]
		var h = data[1]
		topPatch._draw(p_item, topRect, p_sourcePolygon, p_texture, p_normalMap)
		var halfOfW = p_rect.size.x * 0.5
		var leftRect = Rect2(p_rect.position + Vector2(0.0, topRect.size.y), Vector2(halfOfW, h))
		leftPatch._draw(p_item, leftRect, p_sourcePolygon, p_texture, p_normalMap)
		var rightRect = Rect2(p_rect.position + Vector2(halfOfW, topRect.size.y), leftRect.size)
		rightPatch._draw(p_item, rightRect, p_sourcePolygon, p_texture, p_normalMap)
		
		splitEdgeVertices.clear()
		splitEdgeVertices.append(rightPatch.to_global(rightRect.position))
		splitEdgeVertices.append(leftPatch.to_global(leftRect.position))
		splitEdgeVertices.append(rightPatch.to_global(rightRect.position + Vector2(rightRect.size.x, 0.0)))
		splitEdgeVertices.append(leftPatch.to_global(leftRect.end))
	else:
		var data = _get_top_rect_and_height(p_rect)
		var topRect = data[0]
		var h = data[1]
		var polys = _get_extra_polygons(p_rect, topRect, h, p_texture)
		
		if p_normalMap:
			for i in polys:
				VisualServer.canvas_item_add_polygon(p_item, i[0], [Color.white], i[1], p_texture.get_rid(), p_normalMap.get_rid())
				polygons.append(i[0])
		else:
			for i in polys:
				VisualServer.canvas_item_add_polygon(p_item, i[0], [Color.white], i[1], p_texture.get_rid())
				polygons.append(i[0])
		
		topPatch._draw(p_item, topRect, p_sourcePolygon, p_texture, p_normalMap)
		
		var leftRect:Rect2
		var leftTopPos = topPatch.to_global(topRect.position + Vector2(0.0, topRect.size.y))
		leftRect.position = leftPatch.to_local(leftTopPos)
		var bottomPos = topPatch.to_global(topRect.end) + Vector2(0.0, h)
		leftRect.size = leftPatch.to_local(bottomPos - leftTopPos)
		leftPatch._draw(p_item, leftRect, p_sourcePolygon, p_texture, p_normalMap)
		
		var rightRect:Rect2
		var rightTopPos = topPatch.to_global(topRect.position + Vector2(topRect.size.x, 0.0))
		rightRect.position = rightPatch.to_local(rightTopPos)
		rightRect.size = rightPatch.to_local(bottomPos - rightTopPos)
		rightPatch._draw(p_item, rightRect, p_sourcePolygon, p_texture, p_normalMap)
		
		splitEdgeVertices.clear()
		splitEdgeVertices.append(topPatch.to_global(topRect.end))
		splitEdgeVertices.append(topPatch.to_global(topRect.position + Vector2(0.0, topRect.size.y)))
		splitEdgeVertices.append(topPatch.to_global(topRect.position + Vector2(topRect.size.x, 0.0)))
		splitEdgeVertices.append(splitEdgeVertices[0] + Vector2(0.0, h))

func _draw(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	check_region()
	if p_rect.size.x <= 0.0 || p_rect.size.y <= 0.0 || region == null || region.size.x * region.size.y <= 0.0 || p_sourcePolygon.size() < 3:
		rect = Rect2(p_rect.position, Vector2.ZERO)
		polygons.clear()
		return
	rect = p_rect
	polygons.clear()
	_draw_child(p_item, p_rect, p_sourcePolygon, p_texture, p_normalMap)
	
	for i in children:
		for j in i.polygons:
			polygons.append(j)

func _set(p_property, p_value):
	if p_property == "top":
		set_top(p_value)
	elif p_property == "left":
		set_left(p_value)
	elif p_property == "right":
		set_right(p_value)
	else:
		return false
	
	return true

func _get(p_property):
	if p_property == "top":
		return get_top()
	elif p_property == "left":
		return get_left()
	elif p_property == "right":
		return get_right()
	
	return null

func _get_property_list():
	var ret := []
	ret.append({ "name":"top", "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Patch,HPatchContainer,VPatchContainer,TPatchContainer", "usage":PROPERTY_USAGE_DEFAULT })
	ret.append({ "name":"left", "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Patch,HPatchContainer,VPatchContainer,TPatchContainer", "usage":PROPERTY_USAGE_DEFAULT })
	ret.append({ "name":"right", "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Patch,HPatchContainer,VPatchContainer,TPatchContainer", "usage":PROPERTY_USAGE_DEFAULT })
	return ret

func _set_child(p_id:int, p_child):
	if p_id < 0 || p_id >= children.size():
		return
	
	if p_child == null:
		p_child = Patch.new()
	elif p_child.has_method("check_child_count"):
		p_child.check_child_count()
	
	p_child.index = p_id
	p_child.parent = self
	_remove_child(p_id)
	children[p_id] = p_child
	p_child.connect("min_size_changed", self, "_on_child_min_size_changed")
	p_child.connect("region_changed", self, "_on_child_region_changed", [p_child])
	p_child.connect("ratio_changed", self, "_on_child_ratio_changed", [p_child])
	p_child.connect("mode_changed", self, "_on_child_mode_changed")
	if p_child.has_signal("children_changed"):
		p_child.connect("children_changed", self, "_on_child_children_changed")
	match p_id:
		CHILD_ID_TOP:
			p_child.xAxis = xAxis
			if  is_normal_axis():
				p_child.yAxis = yAxis
			else:
				p_child.yAxis = Vector2(-xAxis.x, xAxis.y)
		CHILD_ID_LEFT:
			p_child.yAxis = Vector2.DOWN
			if is_normal_axis():
				p_child.xAxis = Vector2.RIGHT
			else:
				p_child.xAxis = xAxis
		CHILD_ID_RIGHT:
			p_child.yAxis = Vector2.DOWN
			if is_normal_axis():
				p_child.xAxis = Vector2.RIGHT
			else:
				p_child.xAxis = Vector2(-xAxis.x, xAxis.y)
	dirtyChildRegion = true

func set_child(p_id:int, p_child):
	_set_child(p_id, p_child)
	emit_signal("children_changed")

func set_top(p_child):
	set_child(CHILD_ID_TOP, p_child)

func set_left(p_child):
	set_child(CHILD_ID_LEFT, p_child)

func set_right(p_child):
	set_child(CHILD_ID_RIGHT, p_child)

func get_top():
	return children[CHILD_ID_TOP]

func get_left():
	return children[CHILD_ID_LEFT]

func get_right():
	return children[CHILD_ID_RIGHT]

func _remove_child(p_id):
	var child = children[p_id]
	children[p_id] = null
	if child:
		child.parent = null
		child.disconnect("min_size_changed", self, "_on_child_min_size_changed")
		child.disconnect("region_changed", self, "_on_child_region_changed")
		child.disconnect("ratio_changed", self, "_on_child_ratio_changed")
		child.disconnect("mode_changed", self, "_on_child_mode_changed")
		if child.has_signal("children_changed"):
			child.disconnect("children_changed", self, "_on_child_children_changed")

func _on_child_mode_changed():
	emit_signal("mode_changed")

func _on_child_region_changed(p_value, p_flag, p_child):
	if p_flag == REGION_FLAG_ONLY_CHILD || region == null:
		emit_signal("region_changed", length, REGION_FLAG_ONLY_CHILD)
		return
	
	if dirtyChildRegion:
		update_child_region()
	
	p_child.length = p_value
	
	if is_normal_axis():
		var h = region.size.y
		if p_child.length > h:
			p_child.length = h
		if p_child == get_top():
			get_left().length = h - p_child.length
			get_right().length = get_left().length
		elif p_child == get_left():
			get_right().length = p_child.length
			get_top().length = h - p_child.length
		else:
			get_left().length = p_child.length
			get_top().length = h - p_child.length
	elif yAxis != Vector2.DOWN:
		var topPos = get_global_region_top_pos()
		var bottomPos = get_global_region_bottom_pos()
		var splitTopPos
		if bottomPos.x < topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, yAxis, bottomPos, Vector2.UP)
		elif bottomPos.x > topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, xAxis, bottomPos, Vector2.UP)
		else:
			splitTopPos = topPos
		var h = bottomPos.y - splitTopPos.y
		if p_child.length > h:
			p_child.length = h
		if p_child == get_top():
			get_left().length = h - p_child.length
			get_right().length = get_left().length
		elif p_child == get_left():
			get_right().length = p_child.length
			get_top().length = h - p_child.length
		else:
			get_left().length = p_child.length
			get_top().length = h - p_child.length
	else:
		if region.size.x * region.size.y == 0.0:
			get_top().length = 0.0
			get_left().length = 0.0
			get_right().length = 0.0
		else:
			var topPatch = get_top()
			var leftPatch = get_left()
			var rightPatch = get_right()
			if p_child == topPatch:
				if p_child.length > region.size.x:
					p_child.length = region.size.x
				var topPatchTopPos = to_global(region.position + Vector2(region.size.x - topPatch.length, 0.0))
				var yLen = (get_global_region_left_pos() + xAxis * topPatch.length).distance_to(topPatchTopPos + 
						topPatch.to_global(Vector2(topPatch.length, (topPatchTopPos.x - get_global_region_top_pos().x) / topPatch.xAxis.x)))
				if rightPatch.length != yLen:
					rightPatch.length = yLen
				if leftPatch.length != rightPatch.length:
					leftPatch.length = rightPatch.length
				get_right().length = get_left().length
			else:
				if p_child.length > region.size.y:
					p_child.length = region.size.y
				if p_child == leftPatch:
					rightPatch.length = leftPatch.length
				else:
					leftPatch.length = rightPatch.length
				var topSplitPos = Geometry.line_intersects_line_2d(get_global_region_left_pos() - Vector2(0.0, rightPatch.length), Vector2(-xAxis.x, xAxis.y), get_global_region_top_pos(), xAxis)
				topPatch.length = topSplitPos.distance_to(get_global_region_right_pos())

	_update_child_region()
	emit_signal("region_changed", length, REGION_FLAG_ONLY_CHILD)

func _on_child_min_size_changed():
	emit_signal("min_size_changed")

func _on_child_ratio_changed(p_child):
	if p_child == get_left():
		get_right().ratio = p_child.ratio
	elif p_child == get_right():
		get_left().ratio = p_child.ratio
	emit_signal("ratio_changed")

func _on_child_children_changed():
	emit_signal("children_changed")

func update_child_region():
	dirtyChildRegion = false
	if parent && parent.dirtyChildRegion:
		parent.update_child_region()
	
	if region:
		var topPatch = get_top()
		var rightPatch = get_right()
		var leftPatch = get_left()
		if is_normal_axis():
			if leftPatch.length != rightPatch.length:
				leftPatch.length = rightPatch.length
			var totalLen = topPatch.length + rightPatch.length
			if totalLen == 0.0:
				var l = region.size.y * 0.5
				topPatch.length = l
				leftPatch.length = l
				rightPatch.length = l
			elif totalLen != region.size.y:
				var avail = region.size.y - totalLen
				topPatch.length += avail * topPatch.length / totalLen
				rightPatch.length += avail * rightPatch.length / totalLen
				leftPatch.length = rightPatch.length
		elif yAxis == Vector2.DOWN:
			if region.size.x * region.size.y == 0.0:
				topPatch.length = 0.0
				leftPatch.length = 0.0
				rightPatch.length = 0.0
			else:
				if topPatch.length > region.size.x:
					topPatch.length = region.size.x
				if rightPatch.length > region.size.y:
					rightPatch.length = region.size.y
				var topPatchTopPos = to_global(region.position + Vector2(region.size.x - topPatch.length, 0.0))
				var yLen = (get_global_region_left_pos() + xAxis * topPatch.length).distance_to(topPatchTopPos + 
						topPatch.to_global(Vector2(topPatch.length, (topPatchTopPos.x - get_global_region_top_pos().x) / topPatch.xAxis.x)))
				if rightPatch.length != yLen:
					rightPatch.length = yLen
				if leftPatch.length != rightPatch.length:
					leftPatch.length = rightPatch.length
		else:
			var topPos = to_global(region.position)
			var bottomPos = to_global(region.end)
			var splitTopPos
			if bottomPos.x < topPos.x:
				splitTopPos = Geometry.line_intersects_line_2d(topPos, yAxis, bottomPos, Vector2.UP)
			elif bottomPos.x > topPos.x:
				splitTopPos = Geometry.line_intersects_line_2d(topPos, xAxis, bottomPos, Vector2.UP)
			else:
				splitTopPos = topPos
			var height = bottomPos.y - splitTopPos.y
			if leftPatch.length != rightPatch.length:
				leftPatch.length = rightPatch.length
			var totalLen = rightPatch.length + topPatch.length
			if totalLen == 0.0:
				leftPatch.length = height * 0.5
				rightPatch.length = leftPatch.length
				topPatch.length = height * 0.5
			else:
				var avail = height - totalLen
				if avail != 0.0:
					leftPatch.length += avail * leftPatch.length / totalLen
					rightPatch.length = leftPatch.length
					topPatch.length += avail * topPatch.length / totalLen
	
	_update_child_region()

func _update_child_region():
	if !region || region.size.x * region.size.y == 0.0:
		get_top().region = Rect2()
		get_left().region = Rect2()
		get_right().region = Rect2()
		return
	
	var topPatch = get_top()
	var rightPatch = get_right()
	var leftPatch = get_left()
	if is_normal_axis():
		topPatch.region = Rect2(region.position, Vector2(region.size.x, topPatch.length))
		leftPatch.region = Rect2(region.position + Vector2(0.0, topPatch.region.size.y), Vector2(region.size.x * 0.5, leftPatch.length))
		rightPatch.region = Rect2(leftPatch.region.position + Vector2(leftPatch.region.size.x, 0.0), leftPatch.region.size)
	elif yAxis == Vector2.DOWN:
		var topPatchTopPos = to_global(region.position + Vector2(region.size.x - topPatch.length, 0.0))
		var topPos = get_global_region_top_pos()
		topPatch.region = Rect2(topPatch.to_local(topPatchTopPos), Vector2(topPatch.length, (topPatchTopPos.x - topPos.x) / topPatch.xAxis.x))
		leftPatch.region = Rect2(leftPatch.to_local(topPatch.get_global_region_left_pos()), Vector2(topPatch.length, leftPatch.length))
		rightPatch.region = Rect2(rightPatch.to_local(topPatch.get_global_region_right_pos()), Vector2(topPatch.region.size.y, rightPatch.length))
	else:
		var topPos = get_global_region_top_pos()
		var bottomPos = get_global_region_bottom_pos()
		var pos = bottomPos - Vector2(0.0, rightPatch.length)
		topPatch.region = Rect2(region.position, topPatch.to_local(pos - topPos))
		leftPatch.region = Rect2(leftPatch.to_local(topPatch.get_global_region_left_pos()), Vector2(topPatch.region.size.x, leftPatch.length))
		rightPatch.region = Rect2(rightPatch.to_local(topPatch.get_global_region_right_pos()), Vector2(topPatch.region.size.y, rightPatch.length))

func update_min_size_by_child():
	var topPatch = get_top()
	var leftPatch = get_left()
	var rightPatch = get_right()
	if is_normal_axis():
		minSize.x = max(topPatch.minSize.x, max(leftPatch.minSzie.x, rightPatch.minSize.x) * 2.0)
		minSize.y = topPatch.minSize.y + max(leftPatch.minSize.y, rightPatch.minSize.y)
	elif yAxis == Vector2.DOWN:
		var minY = max(topPatch.minSize.y, rightPatch.minSize.x)
		var yA = Vector2(-xAxis.x, xAxis.y)
		var topAngle = abs(xAxis.angle_to(yAxis))
		var minTopX = abs((yA * minY).x) / sin(topAngle)
		var minTopY = cos(topAngle) * minTopX + abs((yA * minY).y)
		var minBottomX = max(topPatch.minSize.x, leftPatch.minSize.x)
		var minBottomY = max(leftPatch.minSize.y, rightPatch.minSize.y)
		minSize.x = minTopX + minBottomX
		minSize.y = minTopY + minBottomY
	else:
		var minTopY = max(topPatch.minSize.y, rightPatch.minSize.x)
		var minTopX = max(topPatch.minSize.x, leftPatch.minSize.x)
		var minBottom = to_local(Vector2(0.0, max(leftPatch.minSize.y, rightPatch.minSize.y)))
		minSize.x = minTopX + abs(minBottom.x)
		minSize.y = minTopY + abs(minBottom.y)

func set_x_axis(p_value:Vector2):
	p_value = p_value.normalized()
	if p_value == xAxis:
		return
	
	var isNormal = is_normal_axis()
	xAxis = p_value
	if is_normal_axis():
		get_top().set_x_axis(xAxis)
		get_top().set_y_axis(yAxis)
		get_left().set_x_axis(xAxis)
		get_right().set_x_axis(xAxis)
	elif yAxis == Vector2.DOWN:
		get_top().set_x_axis(xAxis)
		get_top().set_y_axis(Vector2(-xAxis.x, xAxis.y))
		get_left().set_x_axis(xAxis)
		get_right().set_x_axis(Vector2(-xAxis.x, xAxis.y))
	else:
		get_top().set_x_axis(xAxis)
		get_top().set_y_axis(yAxis)
		get_left().set_x_axis(xAxis)
		get_right().set_x_axis(yAxis)
	
	if isNormal != is_normal_axis():
		update_child_region()

func set_y_axis(p_value:Vector2):
	p_value = p_value.normalized()
	if p_value == yAxis:
		return
	
	var isNormal = is_normal_axis()
	var isDown = p_value == Vector2.DOWN
	var isDownChanged = (yAxis == Vector2.DOWN) != isDown
	yAxis = p_value
	
	if is_normal_axis():
		get_top().set_x_axis(xAxis)
		get_top().set_y_axis(yAxis)
		get_left().set_x_axis(xAxis)
		get_right().set_x_axis(xAxis)
	else:
		if isDown:
			get_top().set_y_axis(Vector2(-xAxis.x, xAxis.y))
			get_right().set_x_axis(Vector2(-xAxis.x, xAxis.y))
		else:
			get_top().set_y_axis(yAxis)
			get_right().set_x_axis(yAxis)
		
		get_left().set_y_axis(Vector2.DOWN)
		get_right().set_y_axis(Vector2.DOWN)
	
	if isDownChanged || isNormal != is_normal_axis():
		update_child_region()

func set_region(p_value:Rect2):
	if p_value == region:
		return
	
	region = p_value
	update_child_region()

func check_region():
	if dirtyChildRegion:
		update_child_region()

func set_children(p_value:Array):
	for i in children.size():
		_remove_child(i)
	
	for i in min(p_value.size(), 3):
		_set_child(i, p_value[i])
	
	for i in range(p_value.size(), 3):
		_set_child(i, null)
	
	dirtyChildRegion = true
	
	emit_signal("children_changed")

func get_children():
	return children

func get_dirty_child_region() -> bool:
	return dirtyChildRegion

func get_split_edge_count():
	if splitEdgeVertices.size() <= 0:
		return 0
	
	return splitEdgeIndices.size() / 2

func get_split_edge_first_vertex(p_id:int):
	if p_id > get_split_edge_count():
		return null
	
	return splitEdgeVertices[splitEdgeIndices[p_id * 2]]

func get_split_edge_last_vertex(p_id:int):
	if p_id > get_split_edge_count():
		return null
	
	return splitEdgeVertices[splitEdgeIndices[p_id * 2 + 1]]
