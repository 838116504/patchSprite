tool
extends Node2D

const SpriteFrame = preload("spriteFrame.gd")
const SPLIT_FLAG_PATCH_BIT = 0x1
const SPLIT_FLAG_FRAME_BIT = 0x2

signal patches_changed
signal frame_changed
signal offset_changed
signal size_changed
signal draw_finished

enum { MODE_STRETCH = 0, MODE_TILE, MODE_TILE_FIT }

export var offset := Vector2.ZERO setget set_offset, get_offset
export var size := Vector2.ZERO setget set_size, get_size

export var texture :Texture = Object() setget set_texture, get_texture
export var normalMap :Texture = Object() setget set_normal_map, get_normal_map
export var centeredH := true setget set_centered_h, is_centered_h
export var centeredV := true setget set_centered_v, is_centered_v
export var flipH := false setget set_flip_h, is_flip_h
export var flipV := false setget set_flip_v, is_flip_v
export var frame := -1 setget set_frame, get_frame

var patches setget set_patches, get_patches
var dirtyDraw := true
var dirtyFrames := false
var frameData := []			# frame data(SpriteFrame node, patch and min size )
var textureScale := Vector2(1.0, 1.0) setget set_texture_scale, get_texture_scale
var usingIsometric := false setget set_using_isometric, is_using_isometric
var isometric:Vector2 = Vector2(128.0, 64.0) setget set_isometric, get_isometric
var isometricNormal:PoolVector2Array = PoolVector2Array([ isometric.normalized(), Vector2(-isometric.x, isometric.y).normalized() ])
var isometricTop:Vector2 = Vector2.ZERO setget set_isometric_top, get_isometric_top
var isometricSize:Vector2 = Vector2.ZERO setget set_isometric_size, get_isometric_size
var usingTextureScale := false

func _init():
	set_notify_local_transform(true)
	set_notify_transform(true)
	self.patches = _create_patch()

func _ready():
	if dirtyDraw:
		_draw_texture()

func _notification(what):
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			_update_transform()
		SpriteFrame.NOTIFICATION_ADDED_SPRITE_FRAME:
			var spriteFrame = get_child(get_child_count() - 1)
			var data = _get_region_patch_and_min_size(spriteFrame.region)
			data.push_front(spriteFrame)
			frameData.append(data)
			_spriteFrame_reconnect(frameData.size() - 1)
		NOTIFICATION_DRAW:
			_draw_texture()

func _set(p_property, p_value):
	if p_property == "isometricBottom":
		set_isometric_bottom(p_value)
		property_list_changed_notify()
		return true
	elif p_property == "texture_scale":
		var isUsing = is_using_texture_scale()
		var nextUse = p_value != null && p_value != Vector2.ZERO
		if !nextUse && isUsing:
			disable_texture_scale()
		elif not isUsing:
			enable_texture_scale()
			if not is_using_texture_scale():
				property_list_changed_notify()
		if is_using_texture_scale() && nextUse:
			set_texture_scale(p_value)
		return true
	return false

func _get(p_property):
	if p_property == "isometricBottom":
		return get_isometric_bottom()
	elif p_property == "texture_scale":
		return get_texture_scale()
	return null


func _get_property_list():
	var ret := []
	
	ret.append({ "name":"patches", "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Patch,HPatchContainer,VPatchContainer,TPatchContainer", "usage":PROPERTY_USAGE_DEFAULT })
	if not is_using_texture_scale():
		ret.append({ "name":"texture_scale", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE })
	else:
		ret.append({ "name":"texture_scale", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	if is_using_isometric():
		ret.append({ "name":"isometric", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
		ret.append({ "name":"isometricTop", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT })
		ret.append({ "name":"isometricBottom", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT })
		ret.append({ "name":"isometricSize", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT })
	else:
		ret.append( { "name":"isometric", "type":TYPE_VECTOR2, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE })
	
	return ret

func _spriteFrame_disconnect(p_spriteFrame):
	if p_spriteFrame.is_connected("moved_in_parent", self, "_on_spriteFrame_moved_in_parent"):
		p_spriteFrame.disconnect("moved_in_parent", self, "_on_spriteFrame_moved_in_parent")
	if p_spriteFrame.is_connected("unparented", self, "_on_spriteFrame_unparented"):
		p_spriteFrame.disconnect("unparented", self, "_on_spriteFrame_unparented")
	if p_spriteFrame.is_connected("offset_changed", self, "_on_spriteFrame_offset_changed"):
		p_spriteFrame.disconnect("offset_changed", self, "_on_spriteFrame_offset_changed")
	if p_spriteFrame.is_connected("region_changed", self, "_on_spriteFrame_region_changed"):
		p_spriteFrame.disconnect("region_changed", self, "_on_spriteFrame_region_changed")

func _spriteFrame_reconnect(p_id:int):
	var spriteFrame:Node = frameData[p_id][0]
	_spriteFrame_disconnect(spriteFrame)
	spriteFrame.connect("moved_in_parent", self, "_on_spriteFrame_moved_in_parent")
	spriteFrame.connect("unparented", self, "_on_spriteFrame_unparented", [p_id])
	spriteFrame.connect("offset_changed", self, "_on_spriteFrame_offset_changed", [p_id])
	spriteFrame.connect("region_changed", self, "_on_spriteFrame_region_changed", [p_id])

func _on_spriteFrame_moved_in_parent():
	var curFrameData
	if frame >= 0:
		curFrameData = frameData[frame]
	var newFrameData = []
	for i in get_children():
		if not i is SpriteFrame:
			continue
		
		for j in frameData.size():
			if frameData[j][0] != i:
				continue
			newFrameData.append(frameData[j])
			frameData.remove(j)
			break
	
	frameData = newFrameData
	for i in frameData.size():
		_spriteFrame_reconnect(i)
	
	if frame >= 0 && curFrameData != frameData[frame]:
		_update_draw()

func _on_spriteFrame_unparented(p_id:int):
	var spriteFrame = frameData[p_id][0]
	_spriteFrame_disconnect(spriteFrame)
	frameData.remove(p_id)
	
	for i in frameData.size():
		_spriteFrame_reconnect(i)
	
	if p_id < frame:
		frame -= 1
	elif p_id == frame:
		if p_id >= frameData.size():
			frame -= 1
		_update_draw()

func _on_spriteFrame_offset_changed(p_id:int):
	if p_id == frame:
		_update_draw()

func _on_spriteFrame_region_changed(p_id:int):
	if not dirtyFrames:
		var spriteFrame = frameData[p_id][0]
		var data = _get_region_patch_and_min_size(spriteFrame.region)
		data.push_front(spriteFrame)
		frameData[p_id] = data
	if p_id == frame:
		_update_draw()

func _create_patch():
	var ret = Patch.new()
	if texture:
		ret.region = Rect2(Vector2.ZERO, texture.get_size())
	return ret

func _on_patches_mode_changed():
	_update_draw()
	emit_signal("patches_changed")

func _on_patches_min_size_changed():
	dirtyFrames = true
	_update_draw()
	emit_signal("patches_changed")

func _on_patches_region_changed(p_length, p_flag):
	dirtyFrames = true
	_update_draw()
	emit_signal("patches_changed")

func _on_patches_ratio_changed():
	_update_draw()
	emit_signal("patches_changed")

func _on_patches_children_changed():
	dirtyFrames = true
	_update_draw()
	emit_signal("patches_changed")

func _update_transform():
	var offsetTransform = Transform2D(0.0, offset)
	if (flipH || flipV) && (is_using_texture_scale() || (size.x > 0.0 && size.y > 0.0)):
		var flipTransform = Transform2D(0.0, - size / 2)
		offsetTransform = offsetTransform * (flipTransform.scaled(Vector2(-1 if flipH else 1.0, -1 if flipV else 1.0)).translated(size/2))
	
	VisualServer.canvas_item_set_transform(get_canvas_item(), .get_transform() * offsetTransform)

func _isometric_rect_to_points(p_rect:Rect2) -> PoolVector2Array:
	return PoolVector2Array([ p_rect.position, p_rect.position + isometricNormal[0] * p_rect.size.x,  
			p_rect.position + isometricNormal[0] * p_rect.size.x + isometricNormal[1] * p_rect.size.y, p_rect.position + isometricNormal[1] * p_rect.size.y])

func _update_frames():
	if not dirtyFrames:
		return
	
	dirtyFrames = false
	var temp
	for i in frameData.size():
		temp = _get_region_patch_and_min_size(frameData[i][0].region)
		temp.push_front(frameData[i][0])
		frameData[i] = temp

func _update_draw():
	if dirtyDraw:
		return
	
	dirtyDraw = true
	if is_inside_tree():
		yield(get_tree(), "idle_frame")
		_draw_texture()

func _draw_texture():
	dirtyDraw = false
	var rid = get_canvas_item()
	VisualServer.canvas_item_clear(rid)
	_update_transform()
	if texture == null:
		return
	
	_update_frames()
	var realSize:Vector2 = get_combo_size()
	if realSize.x <= 0 || realSize.y <= 0:
		return
	
	var sourcePolygon :PoolVector2Array
	var pos := Vector2.ZERO
	sourcePolygon = patches._rect_to_points(patches.region)
	if centeredH:
		pos.x += -realSize.x * 0.5
	if centeredV:
		pos.y += -realSize.y * 0.5

	if frame >= 0 && frame < frameData.size():
		sourcePolygon = PoolVector2Array([ to_global(frameData[frame][0].region.position), to_global(frameData[frame][0].region.position + Vector2(frameData[frame][0].region.size.x, 0.0)),  
			to_global(frameData[frame][0].region.end), to_global(frameData[frame][0].region.position + Vector2(0.0, frameData[frame][0].region.size.y)) ])
		if is_using_isometric():
			pos += _world_to_isometric(frameData[frame][0].offset)
		else:
			pos += frameData[frame][0].offset
	
	var rect = Rect2(pos, realSize)
	patches._draw(get_canvas_item(), rect, sourcePolygon, texture, normalMap)
	
	emit_signal("draw_finished")

func _draw_scale_rect(p_rect:Rect2, p_source:Rect2, p_xMode:int, p_yMode:int):
	if normalMap == null:
		VisualServer.canvas_item_add_nine_patch(get_canvas_item(), p_rect, p_source, texture.get_rid(), Vector2.ZERO, Vector2.ZERO, p_xMode, p_yMode)
	else:
		VisualServer.canvas_item_add_nine_patch(get_canvas_item(), p_rect, p_source, texture.get_rid(), Vector2.ZERO, Vector2.ZERO, p_xMode, p_yMode, true, Color(0xFFFFFFFF), normalMap.get_rid())

func set_using_isometric(p_value:bool):
	if p_value == usingIsometric:
		return
	
	set_using_isometric_no_signal(p_value)
	emit_signal("patches_changed")

func set_using_isometric_no_signal(p_value:bool):
	usingIsometric = p_value
	if texture && usingIsometric:
		self.isometricTop = Vector2(texture.get_size().x * 0.5, 0.0)
		set_isometric_bottom(Vector2(texture.get_size().x * 0.5, texture.get_size().y))
	
	if usingIsometric:
		patches.set_x_axis(isometric)
		patches.set_y_axis(Vector2(-isometric.x, isometric.y))
	else:
		patches.set_x_axis(Vector2(1.0, 0.0))
		patches.set_y_axis(Vector2(0.0, 1.0))
	property_list_changed_notify()
	_update_draw()

func is_using_isometric() -> bool:
	return usingIsometric

func _get_region_patch_and_min_size(p_region:Rect2):
	if p_region == null || p_region.size.x <= 0 || p_region.size.y <= 0:
		return [ patches, Vector2.ZERO ]
	
	var target = patches
	var find:bool
	while not target is Patch:
		find = false
		for i in target.children:
			if i.region && i.region.encloses(p_region):
				find = true
				break
		if not find:
			break
	
	if target is Patch:
		return [ target, Vector2(target.minSize.x * (p_region.size.x/target.region.size.x), target.minSize.y * (p_region.size.y/target.region.size.y))]
	
	var minSize := Vector2.ZERO
	var needProcess := [ target ]
	var process
	var clipRect
	while needProcess.size() > 0:
		process = needProcess.back()
		needProcess.pop_back()
		for i in process.children:
			if i is Patch:
				if not i.region.intersects(p_region):
					continue
				clipRect = i.region.clip(p_region)
				minSize += Vector2(i.minSize.x * (clipRect.size.x / i.region.size.x), i.minSize.y * (clipRect.size.y / i.region.size.y))
			else:
				if not i.region.intersects(p_region):
					continue
				needProcess.append(i)
	
	return [ target, minSize ]

func sprite_sheet_split(p_xCount:int, p_yCount:int, p_flag:int):
	if texture == null || p_flag & 3 == 0:
		return
	
	p_xCount = 1 if p_xCount < 1 else p_xCount
	p_yCount = 1 if p_yCount < 1 else p_yCount
	if p_xCount == 1 && p_yCount == 1:
		return
	
	if p_flag & SPLIT_FLAG_PATCH_BIT:
		var sourceSize
		if is_using_isometric():
			sourceSize = isometricSize
		else:
			sourceSize = texture.get_size()
		var spriteSize = sourceSize / Vector2(p_xCount, p_yCount)
		var tempPatches := []
		for i in p_xCount * p_yCount:
			tempPatches.append(Patch.new())
		
		if p_xCount > 1:
			var containers := []
			containers.resize(p_yCount)
			var patch
			for i in p_yCount:
				containers[i] = HPatchContainer.new()
				for j in p_xCount:
					patch = tempPatches.back()
					tempPatches.pop_back()
					patch.length = spriteSize.x
					containers[i].add_child(patch)
			
			tempPatches = containers
		
		if p_yCount > 1:
			var container = VPatchContainer.new()
			for i in tempPatches:
				i.length = spriteSize.y
				container.add_child(i)
			self.patches = container
		else:
			self.patches = tempPatches
	
	if p_flag & SPLIT_FLAG_FRAME_BIT:
		clear_frames()
		var frameSize = texture.get_size() / Vector2(p_xCount, p_yCount)
		for i in p_yCount:
			for j in p_yCount:
				add_frame(Vector2.ZERO, Rect2(Vector2(i, j) * frameSize, frameSize))

func _get_pixel_neighbor(p_pos:Vector2):
	var ret := []
	if p_pos.x > 0:
		ret.append(Vector2(p_pos.x - 1, p_pos.y))
		if p_pos.y > 0:
			ret.append(Vector2(p_pos.x - 1, p_pos.y - 1))
		if p_pos.y + 1 < texture.get_size().y:
			ret.append(Vector2(p_pos.x - 1, p_pos.y + 1))
	if p_pos.y > 0:
		ret.append(Vector2(p_pos.x, p_pos.y - 1))
		if p_pos.x + 1 < texture.get_size().x:
			ret.append(Vector2(p_pos.x + 1, p_pos.y - 1))
	if p_pos.y + 1 < texture.get_size().y:
		ret.append(Vector2(p_pos.x, p_pos.y + 1))
		if p_pos.x + 1 < texture.get_size().x:
			ret.append(Vector2(p_pos.x + 1, p_pos.y + 1))
	if p_pos.x + 1 < texture.get_size().x:
		ret.append(Vector2(p_pos.x + 1, p_pos.y))
	
	return ret

func _get_opaque_rect(p_pos:Vector2):
	var needProcess := { p_pos:true }
	var processed := {}
	var current:Vector2
	var ret :Rect2 = Rect2(texture.get_size(), Vector2.ZERO)
	var img := texture.get_data()
	var find:bool
	var neighbor
	while needProcess.size() > 0:
		current = needProcess.keys().back()
		needProcess.erase(current)
		processed[current] = true
		
		img.lock()
		if img.get_pixelv(current).a == 0.0:
			img.unlock()
			continue
		find = false
		neighbor = _get_pixel_neighbor(current)
		if current.x <= 0.0 || current.x >= img.get_size().x - 1.0 || current.y <= 0.0 || current.y >= img.get_size().y -1.0:
			find = true
		else:
			for i in neighbor:
				if img.get_pixelv(i).a == 0.0:
					find = true
					break
		img.unlock()
		if not find:
			continue
		
		ret.position = Vector2(min(current.x, ret.position.x), min(current.y, ret.position.y))
		ret.end = Vector2(max(current.x + 1.0, ret.end.x), max(current.y + 1.0, ret.end.y))
		
		for i in neighbor:
			if not processed.has(i):
				needProcess[i] = true
	
	return ret

func _rects_to_patches(p_rects:Array, p_range:Rect2):
	var data := []
	var dir = 0
	var axises = [ "x", "y" ]
	
	while dir < 2:
		var axis = axises[dir]
		if p_rects[0].position[axis] > p_range.position[axis]:
			data.append([])
			data.append(Vector2(p_range.position[axis], p_rects[0].position[axis]))
			data.append([p_rects[0]])
		
		if p_rects[0].end[axis] < p_range.end[axis]:
			if data.size() == 0:
				data.append([p_rects[0]])
			data.append(Vector2(p_rects[0].end[axis], p_range.end[axis]))
			data.append([])
		
		if data.size() > 0:
			for i in range(1, p_rects.size()):
				for j in range(1, data.size(), 2):
					if data[j].x > p_rects[i].end[axis]:
						data[j - 1].append(p_rects[i])
						break
					if p_rects[i].position[axis] > data[j].y:
						continue
					
					if p_rects[i].position[axis] <= data[j].x:
						if data[j].y <= p_rects[i].end[axis]:
							for k in data[j + 1]:
								data[j - 1].append(k)
							data.remove(j + 1)
							data.remove(j)
							if data.size() < 2:
								break
						else:
							data[j].y = p_rects[i].end[axis]
							data[j - 1].append(p_rects[i])
							break
					else:
						if data[j].y > p_rects[i].end[axis]:
							data.insert(j + 1, [p_rects[i]])
							data.insert(j + 2, Vector2(p_rects[i].end[axis], data[j].y))
							data[j].y = p_rects[i].position[axis]
							break
						else:
							data[j].y = p_rects[i].position[axis]
				
				if data.size() < 2:
					break
		
		if data.size() >= 2:
			break
		else:
			data.clear()
		dir += 1
	
	if dir == 2:
		return Patch.new()
	
	var container
	if dir == 1:
		container = VPatchContainer.new()
	else:
		container = HPatchContainer.new()
	var patch
	var start = 0.0
	var end
	var size
	for i in range(0, data.size(), 2):
		if i != data.size() -1:
			end = (data[i + 1].x + data[i + 1].y) * 0.5
		else:
			end = p_range.end[axises[dir]]
		if data[i].size() <= 0:
			continue
		size = end - start
		if dir == 1:
			patch = _rects_to_patches(data[i], Rect2(p_range.position + Vector2(0.0, start), Vector2(p_range.size.x, size)))
		else:
			patch = _rects_to_patches(data[i], Rect2(p_range.position + Vector2(start, 0.0), Vector2(size, p_range.size.y)))
		start = end
		patch.length = size
		container.add_child(patch)
	
	return container

func auto_split(p_flag:int):
	if texture == null || p_flag & 3 == 0:
		return
	
	var rects := []
	var temp
	for i in texture.get_size().y:
		for j in texture.get_size().x:
			temp = false
			for k in rects:
				if k.has_point(Vector2(j, i)):
					temp = true
					break
			if temp:
				continue
			temp = _get_opaque_rect(Vector2(j, i))
			if temp.position.x < texture.get_size().x:
				rects.append(temp)
	
	if p_flag & SPLIT_FLAG_PATCH_BIT:
		if rects.size() > 1:
			self.patches = _rects_to_patches(rects, Rect2(Vector2.ZERO, texture.get_size()))
		else:
			self.patches = Patch.new()
	
	if p_flag & SPLIT_FLAG_FRAME_BIT:
		clear_frames()
		for i in rects.size():
			add_frame(Vector2.ZERO, rects[i])

func add_frame(p_offset:Vector2, p_region:Rect2):
	var spriteFrame = SpriteFrame.new()
	spriteFrame.offset = p_offset
	spriteFrame.region = p_region
	add_child(spriteFrame)
	if owner:
		spriteFrame.owner = owner
	else:
		spriteFrame.owner = self
	return spriteFrame

func clear_frames():
	for i in frameData:
		i[0].queue_free()
	
	frameData.clear()

func get_global_transform() -> Transform2D:
	return .get_global_transform() * Transform2D(0.0, offset)

func get_transform() -> Transform2D:
	return .get_transform() * Transform2D(0.0, offset)

func get_rect():
	var realSize := get_combo_size()
	var ret:Rect2
	if is_using_isometric():
		var xVec := isometricNormal[0] * realSize.x
		var yVec := isometricNormal[1] * realSize.y
		ret = Rect2(Vector2(-yVec.x, 0.0), Vector2(yVec.x + xVec.x, yVec.y + xVec.y))
	else:
		ret = Rect2(Vector2.ZERO, realSize)
	
	ret.position += get_combo_offset()
	return ret

func get_combo_offset() -> Vector2:
	var ret = Vector2.ZERO
	if centeredH || centeredV:
		var realSize := get_combo_size()
		if is_using_isometric():
			if centeredH:
				ret -= isometricNormal[0] * realSize.x * 0.5
			if centeredV:
				ret -= isometricNormal[1] * realSize.y * 0.5
		else:
			if centeredH:
				ret.x = -realSize.x * 0.5
			if centeredV:
				ret.y = -realSize.y * 0.5
	if frame < 0:
		return ret
	return frameData[frame][0].offset + ret

func get_combo_size() -> Vector2:
	var minSize = get_min_size()
	if is_using_texture_scale():
		var realSize
		if frame < 0:
			if is_using_isometric():
				realSize = isometricSize * get_texture_scale()
			else:
				realSize = texture.get_size() * get_texture_scale()
		else:
			realSize = frameData[frame][0].region.size * get_texture_scale()
		return Vector2(max(minSize.x, realSize.x), max(minSize.y, realSize.y))
	return Vector2(max(minSize.x, size.x), max(minSize.y, size.y))

func is_using_texture_scale() -> bool:
	return texture != null && usingTextureScale

func enable_texture_scale():
	if usingTextureScale:
		return
	if is_using_isometric():
		if isometricSize.x == 0.0 || isometricSize.y == 0.0:
			return
	elif texture == null:
		return
	
	usingTextureScale = true
	if texture:
		_update_draw()
	emit_signal("size_changed")

func disable_texture_scale():
	if not usingTextureScale:
		return
	
	usingTextureScale = false
	
	if texture:
		_update_draw()
	emit_signal("size_changed")

func get_min_size() -> Vector2:
	if frame < 0:
		return patches.minSize
	
	return frameData[frame][2]

func get_sprite_frame(p_frame:int):
	return frameData[p_frame][0]

func get_frame_count() -> int:
	return frameData.size()

func merge_patch(p_patchA:Patch, p_patchB:Patch):
	if p_patchA == p_patchB || p_patchA.parent != p_patchB.parent || abs(p_patchA.index - p_patchB.index) > 1:
		return null
	var newPatch = Patch.new()
	var p = p_patchA.parent
	if p is TPatchContainer:
		newPatch.length = p.length
		newPatch.ratio = p.ratio
		newPatch.xMode = p_patchA.xMode
		newPatch.yMode = p_patchA.yMode
		newPatch.minSize = p.minSize
		if p == patches:
			self.patches = newPatch
		else:
			var id = p.index
			var grandparent = p.parent
			if grandparent:
				if grandparent is TPatchContainer:
					grandparent.set_child(id, newPatch)
				else:
					grandparent.remove_child(p)
					grandparent.add_child(newPatch)
					grandparent.move_child(newPatch, id)
				grandparent.check_region()
		return newPatch
	var id = int(min(p_patchA.index, p_patchB.index))
	newPatch.length = p_patchA.length + p_patchB.length
	newPatch.ratio = p_patchA.ratio + p_patchB.ratio
	if p is HPatchContainer:
		newPatch.minSize = Vector2(p_patchA.minSize.x + p_patchB.minSize.x, max(p_patchA.minSize.y, p_patchB.minSize.y))
	else:
		newPatch.minSize = Vector2(max(p_patchA.minSize.x, p_patchB.minSize.x), p_patchA.minSize.y + p_patchB.minSize.y)
	newPatch.xMode = p_patchA.xMode
	newPatch.yMode = p_patchA.yMode
	
	if p.get_child_count() == 2:
		newPatch.ratio = p.ratio
		if p.parent:
			id = p.index
			var temp = p.parent
			newPatch.length = p.length
			if temp is TPatchContainer:
				temp.set_child(id, newPatch)
				p = temp
			else:
				temp.remove_child(p)
				p = temp
				p.add_child(newPatch)
				p.move_child(newPatch, id)
			p.check_region()
		elif p == patches:
			self.patches = newPatch
	else:
		p.remove_child(p_patchA)
		p.remove_child(p_patchB)
		p.add_child(newPatch)
		p.move_child(newPatch, id)
		p.check_region()
		_update_draw()
	return newPatch

func t_split_patch(p_patch:Patch, p_topLength:float):
	var tPC := TPatchContainer.new()
	tPC.set_ratio(p_patch.ratio)
	tPC.set_length(p_patch.length)
	tPC.xAxis = p_patch.xAxis
	tPC.yAxis = p_patch.yAxis
	tPC.region = p_patch.region
	tPC.rect = p_patch.rect
	
	var topPatch = tPC.get_top()
	var leftPatch = tPC.get_left()
	var rightPatch = tPC.get_right()
	topPatch.xMode = p_patch.xMode
	topPatch.yMode = p_patch.yMode
	leftPatch.xMode = p_patch.xMode
	leftPatch.yMode = p_patch.yMode
	rightPatch.xMode = p_patch.xMode
	rightPatch.yMode = p_patch.yMode
	
	var totalLen
	if p_patch.is_normal_axis():
		totalLen = p_patch.region.size.y
		topPatch.minSize.x = p_patch.minSize.x
		topPatch.minSize.y = p_patch.minSize.y * p_topLength / totalLen
		leftPatch.minSize.x = p_patch.minSize.x * 0.5
		leftPatch.minSize.y = p_patch.minSize.y - topPatch.minSize.y
		rightPatch.set_min_size(leftPatch.minSize)
	elif p_patch.yAxis == Vector2.DOWN:
		totalLen = p_patch.region.size.x
		topPatch.minSize.x = p_patch.minSize.x * p_topLength / totalLen
		leftPatch.minSize.y = p_patch.minSize.y * p_topLength / totalLen
		rightPatch.set_min_size(leftPatch.minSize)
	else:
		var topPos = p_patch.get_global_region_top_pos()
		var bottomPos = p_patch.get_global_region_bottom_pos()
		var splitTopPos
		if bottomPos.x < topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, p_patch.yAxis, bottomPos, Vector2.UP)
		elif bottomPos.x > topPos.x:
			splitTopPos = Geometry.line_intersects_line_2d(topPos, p_patch.xAxis, bottomPos, Vector2.UP)
		else:
			splitTopPos = topPos
		totalLen = bottomPos.y - splitTopPos.y
		
		if p_patch.minSize.y > 0:
			var leftSplitPos = Geometry.line_intersects_line_2d(topPos, p_patch.yAxis, splitTopPos + Vector2(0.0, p_topLength), p_patch.xAxis)
			topPatch.minSize.y = p_patch.minSize.y * leftSplitPos.distance_to(topPos) / p_patch.region.size.y
			rightPatch.set_min_size(Vector2(topPatch.minSize.x, 0.0))
		
		if p_patch.minSize.x > 0:
			var rightSplitPos = Geometry.line_intersects_line_2d(topPos, p_patch.xAxis, splitTopPos + Vector2(0.0, p_topLength), p_patch.yAxis)
			topPatch.minSize.x = p_patch.minSize.x * rightSplitPos.distance_to(topPos) / p_patch.region.size.x
			leftPatch.set_min_size(Vector2(topPatch.minSize.x, 0.0))
	
	leftPatch.ratio = totalLen - p_topLength
	rightPatch.ratio = totalLen - p_topLength
	topPatch.set_ratio(p_topLength)
	
	p_topLength = clamp(p_topLength, 0.0, totalLen)
	leftPatch.length = totalLen - p_topLength
	rightPatch.length = totalLen - p_topLength
	topPatch.set_length(p_topLength)
	
	if p_patch == patches:
		self.patches = tPC
	elif p_patch.parent:
		var id = p_patch.index
		var p = p_patch.parent
		if p is TPatchContainer:
			p.set_child(id, tPC)
		elif p is HPatchContainer || p is VPatchContainer:
			p.remove_child(p_patch)
			p.add_child(tPC)
			p.move_child(tPC, id)
		
		p.check_region()
	
	return tPC

func split_patch(p_patch:Patch, p_vertical:bool, p_pos:float):
	var patchA = Patch.new()
	var patchB = Patch.new()
	var axis = "y" if p_vertical else "x"
	p_pos = clamp(p_pos, 0.0, p_patch.region.size[axis])
	var ratio = p_pos / p_patch.region.size[axis]
	var p = p_patch.parent
	if p_patch.ratio > 0.0:
		patchA.ratio = p_patch.ratio * ratio
		patchB.ratio = p_patch.ratio - patchA.ratio
	elif p_patch.parent && p_patch.parent is preload("basePatchContainer.gd") && p_patch.parent.vertical == p_vertical && p_patch.parent.rect.size[axis] > 0.0:
		var r = p_patch.rect.size[axis] / p_patch.parent.rect.size[axis]
		patchA.ratio = r * ratio
		patchB.ratio = r - patchA.ratio
	else:
		patchA.ratio = p_patch.rect.size[axis] * ratio
		patchB.ratio = p_patch.rect.size[axis] - patchA.ratio
	patchA.length = p_pos
	patchB.length = p_patch.region.size[axis] - patchA.length
	if p_vertical:
		patchA.minSize = Vector2(p_patch.minSize.x, p_patch.minSize.y * ratio)
		patchB.minSize = Vector2(p_patch.minSize.x, p_patch.minSize.y - patchA.minSize.y)
	else:
		patchA.minSize = Vector2(p_patch.minSize.x * ratio, p_patch.minSize.y)
		patchB.minSize = Vector2(p_patch.minSize.x - patchA.minSize.x, p_patch.minSize.y)
	patchA.xMode = p_patch.xMode
	patchB.xMode = p_patch.xMode
	patchA.yMode = p_patch.yMode
	patchB.yMode = p_patch.yMode
	
	if p_patch == patches:
		var container
		if p_vertical:
			container = VPatchContainer.new()
		else:
			container = HPatchContainer.new()
		container.length = p_patch.length
		container.ratio = p_patch.ratio
		container.add_child(patchA)
		container.add_child(patchB)
		self.patches = container
	elif p:
		var id = p_patch.index
		if p is VPatchContainer || p is HPatchContainer:
			p.remove_child(p_patch)
			if p.vertical == p_vertical:
				p.add_child(patchA)
				p.move_child(patchA, id)
				p.add_child(patchB)
				p.move_child(patchB, id + 1)
			else:
				var container
				if p_vertical:
					container = VPatchContainer.new()
				else:
					container = HPatchContainer.new()
				container.length = p_patch.length
				container.ratio = p_patch.ratio
				container.minSize = p_patch.minSize
				container.add_child(patchA)
				container.add_child(patchB)
				p.add_child(container)
				p.move_child(container, id)
		elif p is TPatchContainer:
			var container
			if p_vertical:
				container = VPatchContainer.new()
			else:
				container = HPatchContainer.new()
			container.length = p_patch.length
			container.ratio = p_patch.ratio
			container.minSize = p_patch.minSize
			container.add_child(patchA)
			container.add_child(patchB)
			p.set_child(id, container)
		p.check_region()
	
	return [patchA, patchB]

func set_offset(p_value:Vector2):
	if offset == p_value:
		return
	
	offset = p_value
	
	_update_transform()
	emit_signal("offset_changed")

func get_offset() -> Vector2:
	return offset

func set_size(p_value:Vector2):
	p_value = Vector2(max(p_value.x, 0.0), max(p_value.y, 0.0))
	if p_value == size:
		return
	
	size = p_value
	
	if not is_using_texture_scale():
		_update_draw()
		emit_signal("size_changed")

func can_scale() -> bool:
	return not is_using_texture_scale() || ((is_using_isometric() && isometricSize.x != 0.0 && isometricSize.y != 0.0) || \
			(not is_using_isometric() && texture && texture.get_size().x * texture.get_size().y != 0.0))

func scale_with_pivot(p_globalPivot:Vector2, p_size:Vector2):
	if !can_scale():
		return
	
	var curSize = get_combo_size()
	var minSize = get_min_size()
	p_size = Vector2(max(minSize.x, p_size.x), max(minSize.y, p_size.y))
	if curSize == p_size:
		return
	
	var s = p_size / curSize
	if is_using_texture_scale():
		set_texture_scale(get_texture_scale() * s)
	else:
		self.size = p_size
	
	var localPivot = get_global_transform().xform_inv(p_globalPivot)
	if frame >= 0:
		localPivot -= frameData[frame][0].offset
	
	self.offset -= localPivot * (s - Vector2(1.0, 1.0))

func get_size() -> Vector2:
	return size

func set_texture_scale(p_value:Vector2):
	if textureScale == p_value:
		return
	
	textureScale = p_value
	
	if is_using_texture_scale():
		_update_draw()
		emit_signal("size_changed")

func get_texture_scale() -> Vector2:
	return textureScale

func set_texture(p_value:Texture):
	if texture == p_value:
		return
	
	texture = p_value
	if texture:
		patches.set_region(Rect2(Vector2.ZERO, texture.get_size()))
		if not is_using_texture_scale():
			self.size = texture.get_size()
	
	_update_draw()
	if is_using_texture_scale():
		emit_signal("size_changed")
	if not is_using_isometric():
		_update_patches_region()
		
	property_list_changed_notify()

func get_texture() -> Texture:
	return texture

func set_normal_map(p_value:Texture):
	if normalMap == p_value:
		return
	
	normalMap = p_value
	
	_update_draw()

func get_normal_map() -> Texture:
	return normalMap

func set_centered_h(p_value:bool):
	if p_value == centeredH:
		return
	
	centeredH = p_value
	_update_draw()
	emit_signal("offset_changed")

func is_centered_h() -> bool:
	return centeredH

func set_centered_v(p_value:bool):
	if p_value == centeredV:
		return
	
	centeredV = p_value
	_update_draw()
	emit_signal("offset_changed")

func is_centered_v() -> bool:
	return centeredV

func set_flip_h(p_value:bool):
	if p_value == flipH:
		return
	
	flipH = p_value
	_update_transform()

func is_flip_h() -> bool:
	return flipH

func set_flip_v(p_value:bool):
	if p_value == flipV:
		return
	
	flipV = p_value
	_update_transform()

func is_flip_v() -> bool:
	return flipV

func set_patches(p_value):
	if p_value == null:
		p_value = _create_patch()
	
	if not p_value is Patch && not p_value is HPatchContainer && not p_value is VPatchContainer && not p_value is TPatchContainer || p_value == patches:
		return
	
	if p_value.has_method("update_children"):
		p_value.update_children()
	
	if patches:
		if patches.is_connected("mode_changed", self, "_on_patches_mode_changed"):
			patches.disconnect("mode_changed", self, "_on_patches_mode_changed")
		if patches.is_connected("min_size_changed", self, "_on_patches_min_size_changed"):
			patches.disconnect("min_size_changed", self, "_on_patches_min_size_changed")
		if patches.is_connected("ratio_changed", self, "_on_patches_ratio_changed"):
			patches.disconnect("ratio_changed", self, "_on_patches_ratio_changed")
		if patches.is_connected("region_changed", self, "_on_patches_region_changed"):
			patches.disconnect("region_changed", self, "_on_patches_region_changed")
		if patches.has_signal("children_changed") && patches.is_connected("children_changed", self, "_on_patches_children_changed"):
			patches.disconnect("children_changed", self, "_on_patches_children_changed")
	
	patches = p_value
	if patches.has_method("check_child_count"):
		patches.check_child_count()
	if is_using_isometric():
		patches.set_x_axis(isometric)
		patches.set_y_axis(Vector2(-isometric.x, isometric.y))
	else:
		patches.set_x_axis(Vector2.RIGHT)
		patches.set_y_axis(Vector2.DOWN)
	patches.connect("mode_changed", self, "_on_patches_mode_changed")
	patches.connect("min_size_changed", self, "_on_patches_min_size_changed")
	patches.connect("ratio_changed", self, "_on_patches_ratio_changed")
	patches.connect("region_changed", self, "_on_patches_region_changed")
	if patches.has_signal("children_changed"):
		patches.connect("children_changed", self, "_on_patches_children_changed")
	if texture:
		_update_patches_region()
	
	_update_draw()
	emit_signal("patches_changed")
	property_list_changed_notify()

func get_patches():
	return patches

func _update_patches_region():
	if is_using_isometric():
		patches.set_region(Rect2(_world_to_isometric(isometricTop), isometricSize))
	elif texture:
		patches.set_region(Rect2(Vector2.ZERO, texture.get_size()))
	else:
		patches.set_region(Rect2())

func set_isometric(p_value):
	if p_value == isometric:
		return
	
	var isIsometric = p_value != Vector2.ZERO && p_value != null
	if not is_using_isometric() && not isIsometric:
		isIsometric = true
	if p_value == Vector2.ZERO:
		p_value = Vector2(128.0, 64.0)
	if isIsometric != is_using_isometric():
		if isIsometric:
			isometric = p_value
			isometricNormal = PoolVector2Array([ isometric.normalized(), Vector2(-isometric.x, isometric.y).normalized() ])
			
			patches.set_x_axis(isometric)
			patches.set_y_axis(Vector2(-isometric.x, isometric.y))
		set_using_isometric_no_signal(isIsometric)
	else:
		isometric = p_value
		isometricNormal = PoolVector2Array([ isometric.normalized(), Vector2(-isometric.x, isometric.y).normalized() ])
	
	
	_update_patches_region()
	_update_draw()
	emit_signal("patches_changed")

func get_isometric() -> Vector2:
	return isometric


func set_isometric_top(p_value:Vector2):
	if p_value == isometricTop:
		return
	
	isometricTop = p_value
	
	if is_using_isometric():
		_update_patches_region()
		_update_draw()
		property_list_changed_notify()

func _world_to_isometric(p_pos:Vector2) -> Vector2:
	if not is_using_isometric():
		return Vector2.ZERO
	
	var dx = isometricNormal[0].y / isometricNormal[0].x
	var dy = isometricNormal[1].y / isometricNormal[1].x
	var x = (dy * p_pos.x - p_pos.y) / (dy - dx)
	return Vector2(x / isometricNormal[0].x, (p_pos.x - x) / isometricNormal[1].x)

func _isometric_bottom_to_size(p_bottom:Vector2) -> Vector2:
	if not is_using_isometric():
		return Vector2.ZERO
	
	var ret = _world_to_isometric(p_bottom - isometricTop)
	return Vector2(abs(ret.x), abs(ret.y))

func set_isometric_bottom(p_value:Vector2):
	self.isometricSize = _isometric_bottom_to_size(p_value)

func get_isometric_bottom() -> Vector2:
	if not is_using_isometric():
		return Vector2.ZERO
	
	return isometricTop + isometricNormal[0] * isometricSize.x + isometricNormal[1] * isometricSize.y

func get_isometric_top() -> Vector2:
	return isometricTop

func set_isometric_size(p_value:Vector2):
	if p_value == isometricSize:
		return
	
	isometricSize = p_value
	
	if is_using_isometric():
		_update_patches_region()
		_update_draw()
		property_list_changed_notify()
		
		if is_using_texture_scale() && frame < 0:
			emit_signal("size_changed")

func get_isometric_size() -> Vector2:
	return isometricSize

func set_frame(p_value:int):
	p_value = int(min(p_value, frameData.size() - 1))
	if frame == p_value:
		return
	
	var prevFrame = frame
	var prevSize
	if is_using_texture_scale():
		prevSize = get_combo_size()
	frame = p_value
	
	_update_draw()
	emit_signal("frame_changed")
	var prevOffset
	if prevFrame < 0:
		prevOffset = Vector2.ZERO
	else:
		prevOffset = frameData[prevFrame][0].offset
	if frame < 0:
		if prevOffset != Vector2.ZERO:
			emit_signal("offset_changed")
	else:
		if prevOffset != frameData[frame][0].offset:
			emit_signal("offset_changed")
	if is_using_texture_scale():
		if get_combo_size() != prevSize:
			emit_signal("size_changed")

func get_frame() -> int:
	return frame

func has_global_point(p_globalPos:Vector2) -> bool:
	return has_point(get_global_transform().xform_inv(p_globalPos))

func has_point(p_localPos:Vector2) -> bool:
	var localPos = p_localPos - get_combo_offset()
	if localPos.y < 0.0:
		return false
	var curSize = get_combo_size()
	if not is_using_isometric():
		return localPos.x > 0.0 && localPos.x < curSize.x && localPos.y < curSize.y
	
	localPos = _world_to_isometric(localPos)
	return localPos.y > 0.0 && localPos.x > 0.0 && localPos.x < curSize.x && localPos.y < curSize.y

func get_patch_by_pos(p_localPos:Vector2):
	if not has_point(p_localPos):
		return null
	
	if dirtyDraw:
		_draw_texture()
	
	var current = patches
	var find
	while !current is Patch:
		find = false
		for i in current.children:
			if i.has_point(p_localPos):
				current = i
				find = true
				break
		
		if !find:
			break
	
	if current is Patch:
		return current
	
	return null
