tool
class_name Patch
extends "basePatch.gd"

enum { MODE_STRETCH = 0, MODE_TILE, MODE_TILE_FIT }
var xMode := MODE_STRETCH setget set_x_mode, get_x_mode
var yMode := MODE_STRETCH setget set_y_mode, get_y_mode

func _get_property_list():
	var ret := []
	ret.append({ "name":"xMode", "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":"Stretch,Tile,Tile Fit", "usage":PROPERTY_USAGE_DEFAULT })
	ret.append({ "name":"yMode", "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":"Stretch,Tile,Tile Fit", "usage":PROPERTY_USAGE_DEFAULT })
	return ret

func _draw_rect(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	var scale = p_rect.size / region.size
	if is_normal_axis():
		var uvRect := Rect2(Vector2.ZERO, p_texture.get_size()).clip(region)
		var sourceRect = Rect2(p_sourcePolygon[0], Vector2.ZERO)
		for i in range(1, p_sourcePolygon.size()):
			sourceRect = sourceRect.expand(p_sourcePolygon[i])
		uvRect = uvRect.clip(sourceRect)
		var patchRect = Rect2((uvRect.position - region.position) * scale + p_rect.position, uvRect.size * scale)
		if p_normalMap:
			VisualServer.canvas_item_add_nine_patch(p_item, patchRect, uvRect, p_texture.get_rid(),
					 Vector2.ZERO, Vector2.ZERO, xMode, yMode, true, Color.white, p_normalMap.get_rid())
		else:
			VisualServer.canvas_item_add_nine_patch(p_item, patchRect, uvRect, p_texture.get_rid(),
					 Vector2.ZERO, Vector2.ZERO, xMode, yMode)
		polygons.clear()
		polygons.append(_rect_to_points(patchRect))
		return
	
	var uvs = _rect_to_points(region)
	
	var texPoints = [ Vector2.ZERO, Vector2(p_texture.get_size().x, 0.0), p_texture.get_size(), Vector2(0.0, p_texture.get_size().y)]
	uvs = Geometry.intersect_polygons_2d(texPoints, uvs)
	polygons.clear()
	if uvs.size() <= 0:
		return
	
	uvs = uvs[0]
	var xTileCount:int = 1
	var yTileCount:int = 1
	var globalTileW:Vector2 = xAxis * p_rect.size.x
	var globalTileH:Vector2 = yAxis * p_rect.size.y
	uvs = Geometry.intersect_polygons_2d(p_sourcePolygon, uvs)
	if uvs.size() <= 0:
		return
	
	uvs = uvs[0]
	match xMode:
		MODE_TILE:
			xTileCount = int(max(floor(p_rect.size.x / region.size.x), 1.0))
			scale.x = 1.0
			globalTileW = xAxis * region.size.x
		MODE_TILE_FIT:
			xTileCount = int(max(round(p_rect.size.x / region.size.x), 1.0))
			scale.x /= xTileCount
			globalTileW = xAxis * region.size.x * scale.x
	
	match yMode:
		MODE_TILE:
			yTileCount = int(max(floor(p_rect.size.y / region.size.y), 1.0))
			scale.y = 1.0
			globalTileH = yAxis * region.size.y
		MODE_TILE_FIT:
			yTileCount = int(max(round(p_rect.size.y / region.size.y), 1.0))
			scale.y /= yTileCount
			globalTileH = yAxis * region.size.y * scale.y
	
	var points := PoolVector2Array()
	points.resize(uvs.size())
	for i in points.size():
		points[i] = to_global(p_rect.position + (to_local(uvs[i]) - region.position) * scale)
	
	var realUVs := PoolVector2Array()
	realUVs.resize(uvs.size())
	for i in uvs.size():
		realUVs[i] = uvs[i] / p_texture.get_size()
	
	for x in xTileCount:
		for y in yTileCount:
			polygons.append(points)
			if p_normalMap:
				VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid(), p_normalMap.get_rid())
			else:
				VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid())
			
			for i in points.size():
				points[i] += globalTileH
		
		for i in points.size():
			points[i] += -globalTileH * yTileCount + globalTileW
	
	var isXRest = xMode == MODE_TILE && fmod(p_rect.size.x, region.size.x) > 0.0
	var isYRest = yMode == MODE_TILE && fmod(p_rect.size.y, region.size.y) > 0.0
	if isXRest:
		var w = p_rect.size.x - xTileCount * region.size.x
		var offset = p_rect.position + Vector2(xTileCount * region.size.x, 0.0)

		var newUVs = Geometry.intersect_polygons_2d(uvs, _rect_to_points(Rect2(region.position, Vector2(w, region.size.y))))
		if newUVs.size() > 0:
			newUVs = newUVs[0]
		
			points.resize(newUVs.size())
			for i in newUVs.size():
				points[i] = to_global(offset + (to_local(newUVs[i]) - region.position) * scale)
			
			realUVs.resize(newUVs.size())
			for i in newUVs.size():
				realUVs[i] = newUVs[i] / p_texture.get_size()

			for y in yTileCount:
				polygons.append(points)
				if p_normalMap:
					VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid(), p_normalMap.get_rid())
				else:
					VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid())

				for i in points.size():
					points[i] += globalTileH

		if isYRest:
			var h = p_rect.size.y - yTileCount * region.size.y
			
			if newUVs.size() > 0:
				newUVs = Geometry.intersect_polygons_2d(newUVs, _rect_to_points(Rect2(region.position, Vector2(region.size.x, h))))
				if newUVs.size() > 0:
					newUVs = newUVs[0]
					offset += Vector2(0.0, yTileCount * region.size.y)
					points.resize(newUVs.size())
					for i in newUVs.size():
						points[i] = to_global(offset + (to_local(newUVs[i]) - region.position) * scale)
					
					realUVs.resize(newUVs.size())
					for i in newUVs.size():
						realUVs[i] = newUVs[i] / p_texture.get_size()
					polygons.append(points)
					if p_normalMap:
						VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid(), p_normalMap.get_rid())
					else:
						VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid())
			
			offset = p_rect.position + Vector2(0.0, yTileCount * region.size.y)
			newUVs = Geometry.intersect_polygons_2d(uvs, _rect_to_points(Rect2(region.position, Vector2(region.size.x, h))))
			if newUVs.size() > 0:
				newUVs = newUVs[0]
			
				points.resize(newUVs.size())
				for i in newUVs.size():
					points[i] = to_global(offset + (to_local(newUVs[i]) - region.position) * scale)
				
				realUVs.resize(newUVs.size())
				for i in newUVs.size():
					realUVs[i] = newUVs[i] / p_texture.get_size()
				
				for x in xTileCount:
					polygons.append(points)
					if p_normalMap:
						VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid(), p_normalMap.get_rid())
					else:
						VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid())

					for i in points.size():
						points[i] += globalTileW
	elif isYRest:
		var h = p_rect.size.y - yTileCount * region.size.y
		var offset = p_rect.position + Vector2(0.0, yTileCount * region.size.y)
		var newUVs = Geometry.intersect_polygons_2d(uvs, _rect_to_points(Rect2(region.position, Vector2(region.size.x, h))))
		if newUVs.size() > 0:
			newUVs = newUVs[0]
		
			points.resize(newUVs.size())
			for i in newUVs.size():
				points[i] = to_global(offset + (to_local(newUVs[i]) - region.position) * scale)
			
			realUVs.resize(newUVs.size())
			for i in newUVs.size():
				realUVs[i] = newUVs[i] / p_texture.get_size()
			
			for x in xTileCount:
				polygons.append(points)
				if p_normalMap:
					VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid(), p_normalMap.get_rid())
				else:
					VisualServer.canvas_item_add_polygon(p_item, points, [ Color.white ], realUVs, p_texture.get_rid())

				for i in points.size():
					points[i] += globalTileW

func _draw(p_item:RID, p_rect:Rect2, p_sourcePolygon:PoolVector2Array, p_texture:Texture, p_normalMap:Texture):
	if p_rect.size.x <= 0.0 || p_rect.size.y <= 0.0 || region == null || region.size.x * region.size.y <= 0.0 || p_sourcePolygon.size() < 3:
		rect = Rect2(p_rect.position, Vector2.ZERO)
		polygons.clear()
		return
	
	rect = p_rect
	_draw_rect(p_item, p_rect, p_sourcePolygon, p_texture, p_normalMap)

func set_x_mode(p_value:int):
	if p_value > MODE_TILE_FIT || p_value < 0 || p_value == xMode:
		return
	
	set_x_mode_no_signal(p_value)
	
	emit_signal("mode_changed")

func get_x_mode():
	return xMode

func set_y_mode(p_value:int):
	if p_value > MODE_TILE_FIT || p_value < 0 || p_value == yMode:
		return
	
	set_y_mode_no_signal(p_value)
	
	emit_signal("mode_changed")

func get_y_mode():
	return yMode

func set_x_mode_no_signal(p_value:int):
	xMode = p_value

func set_y_mode_no_signal(p_value:int):
	yMode = p_value
