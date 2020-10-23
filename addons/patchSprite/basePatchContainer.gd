tool
extends "basePatch.gd"

signal children_changed

var children := [] setget set_children, get_children
var vertical := false setget , get_vertical
var dirtyChildRegion := false setget , get_dirty_child_region
var splitEdgeVertices := []
var splitEdgeIndices := []

func _draw_child(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	var avail:float
	var scalePatches := []
	var drawPatches := []
	var totalRatio := 0.0
	var axis:String
	var find:int
	var childRect:Rect2 = Rect2(p_rect.position, Vector2.ZERO)
	
	if vertical:
		axis = "y"
		childRect.size.x = p_rect.size.x
	else:
		axis = "x"
		childRect.size.y = p_rect.size.y
	
	avail = p_rect.size[axis] - minSize[axis]
	
	for i in children:
		drawPatches.append(i)
		if i.ratio <= 0.0:
			continue
		
		avail += i.minSize[axis]
		totalRatio += i.ratio
		scalePatches.append(i)
	
	for i in scalePatches:
		if i.ratio / totalRatio * avail <= i.minSize[axis]:
			scalePatches.erase(i)
			totalRatio -= i.ratio
			avail -= i.minSize[axis]
	
	var first := true
	splitEdgeVertices.clear()
	splitEdgeIndices.clear()
	for i in drawPatches:
		find = scalePatches.find(i)
		if find >= 0:
			childRect.size[axis] = i.ratio / totalRatio * avail
		else:
			childRect.size[axis] = i.minSize[axis]
		
		i.rect = childRect
		if i.rect.size[axis] <= 0.0 || i.region == null:
			continue
		
		if first:
			first = false
		else:
			splitEdgeIndices.append(splitEdgeVertices.size())
			splitEdgeVertices.append(i.to_global(childRect.position))
			splitEdgeIndices.append(splitEdgeVertices.size())
			if vertical:
				splitEdgeVertices.append(i.to_global(childRect.position + Vector2(childRect.size.x, 0.0)))
			else:
				splitEdgeVertices.append(i.to_global(childRect.position + Vector2(0.0, childRect.size.y)))
			
		i._draw(p_item, childRect, p_sourcePolygon, p_texture, p_normalMap)
		
		childRect.position[axis] += childRect.size[axis]

func _draw(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	check_region()
	if p_rect.size.x <= 0.0 || p_rect.size.y <= 0.0 || region == null || region.size.x * region.size.y <= 0.0 || p_sourcePolygon.size() < 3:
		rect = Rect2(p_rect.position, Vector2.ZERO)
		polygons.clear()
		return
	rect = p_rect
	
	_draw_child(p_item, p_rect, p_sourcePolygon, p_texture, p_normalMap)
	polygons.clear()
	for i in children:
		for j in i.polygons:
			polygons.append(j)

func _init():
	length = 2.0

func check_child_count():
	while children.size() < 2:
		add_child(null)

func _set(p_property, p_value):
	if p_property == "children":
		children = p_value
	else:
		return false
	
	return true

func _get(p_property):
	if p_property == "children":
		return children
	
	return null

func _get_property_list():
	var ret := []
	ret.append({ "name":"children", "type":TYPE_ARRAY, "hint_string":str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":Patch,HPatchContainer,VPatchContainer,TPatchContainer", "usage":PROPERTY_USAGE_DEFAULT })
	return ret

func _add_child(p_child):
	if p_child == null:
		p_child = load("res://addons/patchSprite/patch.gd").new()
	elif p_child.has_method("check_child_count"):
		p_child.check_child_count()
	
	p_child.index = children.size()
	p_child.parent = self
	children.append(p_child)
	p_child.connect("min_size_changed", self, "_on_child_min_size_changed")
	p_child.connect("region_changed", self, "_on_child_region_changed", [p_child])
	p_child.connect("ratio_changed", self, "_on_child_ratio_changed")
	p_child.connect("mode_changed", self, "_on_child_mode_changed")
	if p_child.has_signal("children_changed"):
		p_child.connect("children_changed", self, "_on_child_children_changed")
	p_child.set_x_axis(xAxis)
	p_child.set_y_axis(yAxis)
	
	dirtyChildRegion = true

func add_child(p_child):
	_add_child(p_child)
	emit_signal("children_changed")

func _clear_children():
	for i in children.size():
		_remove_child(0)
	children.clear()
	
	dirtyChildRegion = true

func clear_children():
	_clear_children()
	emit_signal("children_changed")

func _remove_child(p_id):
	var child = children[p_id]
	children.remove(p_id)
	if child:
		child.parent = null
		child.disconnect("min_size_changed", self, "_on_child_min_size_changed")
		child.disconnect("region_changed", self, "_on_child_region_changed")
		child.disconnect("ratio_changed", self, "_on_child_ratio_changed")
		child.disconnect("mode_changed", self, "_on_child_mode_changed")
		if child.has_signal("children_changed"):
			child.disconnect("children_changed", self, "_on_child_children_changed")

func remove_child(p_child):
	if p_child == null || p_child.index < 0 || p_child.index >= children.size() || children[p_child.index] != p_child:
		return
	
	var id = p_child.index
	_remove_child(p_child.index)
	for i in range(id, children.size()):
		children[i].index -= 1
	
	dirtyChildRegion = true
	emit_signal("children_changed")

func move_child(p_child, p_id:int):
	if p_child == null:
		return
	
	p_id = int(clamp(float(p_id), 0.0, float(children.size())))
	if children[p_child.index] != p_child || p_child.index == p_id || (p_id == children.size() && p_child.index == children.size() - 1):
		return
	
	if p_id < p_child.index:
		for i in range(p_id, p_child.index):
			children[i].index += 1
	else:
		for i in range(p_child.index + 1, p_id):
			children[i].index -= 1
	
	children.remove(p_child.index)
	if p_id < p_child.index:
		children.insert(p_id, p_child)
	else:
		children.insert(p_id - 1, p_child)
	
	p_child.index = p_id if p_id < children.size() else children.size() - 1
	
	dirtyChildRegion = true
	emit_signal("children_changed")


func get_child_count() -> int:
	return children.size()

func _on_child_mode_changed():
	emit_signal("mode_changed")

func _on_child_children_changed():
	emit_signal("children_changed")

func _on_child_region_changed(p_value, p_flag, p_child):
	if p_flag == REGION_FLAG_ONLY_CHILD || region == null:
		emit_signal("region_changed", length, REGION_FLAG_ONLY_CHILD)
		return
	
	if dirtyChildRegion:
		update_child_region()
	
	p_child.length = p_value
	var axis = "y" if vertical else "x"
	var avail := region.size[axis]
	for i in children:
		avail -= i.length
	
	if avail == 0.0:
		emit_signal("region_changed", length, REGION_FLAG_ONLY_CHILD)
		return
	
	var target = []
	match p_flag:
		REGION_FLAG_FROM_CENTER:
			if p_child.index > 0:
				target.append(children[p_child.index - 1])
			if p_child.index < children.size() - 1:
				target.append(children[p_child.index + 1])
		REGION_FLAG_FROM_LEFT:
			if p_child.index < children.size() - 1:
				target.append(children[p_child.index + 1])
			elif p_child.index > 0:
				target.append(children[p_child.index - 1])
		REGION_FLAG_FROM_RIGHT:
			if p_child.index > 0:
				target.append(children[p_child.index - 1])
			elif p_child.index < children.size() - 1:
				target.append(children[p_child.index + 1])
	
	if target.size() > 0:
		var zeroTarget := []
		var perAvail = avail / target.size()
		var t = 0
		while t < target.size():
			if target[t].length > perAvail:
				t += 1
				continue
			
			avail -= target[t].length
			zeroTarget.append(target[t])
			target.remove(t)
			if target.size() <= 0:
				break
			perAvail = avail / target.size()
			t = 0
		for i in zeroTarget:
			i.length = 0
		if target.size() > 0:
			for i in target:
				i.length = i.length + perAvail
		else:
			p_child.length = p_child.length + avail
	else:
		p_child.length = p_child.length + avail
	
	_update_child_region()
	emit_signal("region_changed", length, REGION_FLAG_ONLY_CHILD)


func _on_child_min_size_changed():
	emit_signal("min_size_changed")

func _on_child_ratio_changed():
	emit_signal("ratio_changed")

# child class override
func update_min_size_by_child():
	pass

func set_region(p_value:Rect2):
	if p_value == region:
		return
	
	region = p_value
	update_child_region()

func check_region():
	if dirtyChildRegion:
		update_child_region()

func update_child_region():
	dirtyChildRegion = false
	if parent && parent.dirtyChildRegion:
		parent.update_child_region()
	
	var axis = "y" if vertical else "x"
	if region:
		var totalLen := 0.0
		for i in children:
			totalLen += i.length
		if totalLen != region.size[axis]:
			if totalLen > 0.0:
				var scale = region.size[axis] / totalLen
				for i in children:
					i.length = i.length * scale
			elif children.size() > 0:
				var l = region.size[axis] / children.size()
				for i in children:
					i.length = l
	_update_child_region()

func _update_child_region():
	var pos := 0.0
	var axis = "y" if vertical else "x"
	for i in children:
		i.region = region
		if region:
			i.region.position[axis] += pos
			i.region.size[axis] = i.length
		if i.has_method("update_child_region"):
			i.update_child_region()
		pos += i.length


func set_x_axis(p_value:Vector2):
	p_value = p_value.normalized()
	if p_value == xAxis:
		return
	
	xAxis = p_value
	for i in children:
		i.set_x_axis(xAxis)

func set_y_axis(p_value:Vector2):
	p_value = p_value.normalized()
	if p_value == yAxis:
		return
	
	yAxis = p_value
	for i in children:
		i.set_y_axis(yAxis)

func set_children(p_value:Array):
	if p_value.size() < 2:
		p_value.resize(2)
	
	_clear_children()
	
	for i in p_value:
		_add_child(i)
	
	emit_signal("children_changed")

func get_children() -> Array:
	return children

func get_vertical() -> bool:
	return vertical

func get_dirty_child_region() -> bool:
	return dirtyChildRegion

func get_split_edge_count():
	return splitEdgeIndices.size() / 2

func get_split_edge_first_vertex(p_id:int):
	if p_id > get_split_edge_count():
		return null
	
	return splitEdgeVertices[splitEdgeIndices[p_id * 2]]

func get_split_edge_last_vertex(p_id:int):
	if p_id > get_split_edge_count():
		return null
	
	return splitEdgeVertices[splitEdgeIndices[p_id * 2 + 1]]
