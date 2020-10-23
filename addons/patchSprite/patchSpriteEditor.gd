tool
extends HBoxContainer

enum { MODE_NORMAL = 0, MODE_DRAG_SIZE, MODE_DRAG_ISOMETRIC_POINT, MODE_DRAG_ISOMETRIC_EDGE, MODE_SELECT_PRESSED, MODE_SELECT_PARENT_PRESSED, 
		MODE_SPLIT_PRESSED, MODE_SPLIT_EDGE_PRESSED, MODE_SPLIT_CENTER_PRESSED, MODE_SPLIT, MODE_T_SPLIT_PRESSED, MODE_T_SPLIT }
const SCALE_RADIUS = 6.0
const LINE_HALF_WIDTH = 2.0
const MyToolButton = preload("toolButton.gd")

var editorInterface:EditorInterface
var viewport:Viewport
var undoRedo:UndoRedo
var patchToolBtn:MyToolButton
var editTextureOptBtn:MyToolButton
var editSizeOptBtn:MyToolButton
var autoSplitBtn:MyToolButton
var spriteSheetSplitBtn:MyToolButton
var autoSplitDialog
var autoSplitDialogFrameCheck
var autoSplitDialogPatchCheck
var spriteSheetSplitDialog
var spriteSheetSplitDialogHEdit
var spriteSheetSplitDialogVEdit
var spriteSheetSplitDialogFrameCheck
var spriteSheetSplitDialogPatchCheck
var editObj
var dragMode := MODE_NORMAL
var dragData
var scalePoints := []
var sizePoints := []
var sizePivots := []
var splitPatchPoints := []
var isPendingUpdateSplitData := false
var tPatchContainers := []

func _init():
	add_child(VSeparator.new())
	patchToolBtn = MyToolButton.new()
	patchToolBtn.hint_tooltip = tr("Patch tool")
	patchToolBtn.connect("toggled", self, "_on_patchToolBtn_toggled")
	add_child(patchToolBtn)
	
	editTextureOptBtn = MyToolButton.new()
	editTextureOptBtn.hint_tooltip = tr("Drag egde change patch texture uv")
	editTextureOptBtn.pressed = true
	editTextureOptBtn.connect("toggled", self, "_on_editTextureOptBtn_toggled")
	add_child(editTextureOptBtn)
	
	editSizeOptBtn = MyToolButton.new()
	editSizeOptBtn.hint_tooltip = tr("Drag egde change patch size")
	editSizeOptBtn.pressed = true
	editSizeOptBtn.connect("toggled", self, "_on_editSizeOptBtn_toggled")
	add_child(editSizeOptBtn)
	
	hide_tool_opts()
	
	add_child(VSeparator.new())
	autoSplitBtn = MyToolButton.new()
	autoSplitBtn.hint_tooltip = tr("Split by transparent edge")
	add_child(autoSplitBtn)
	autoSplitBtn.connect("pressed", self, "_on_autoSplitBtn_pressed")
	
	spriteSheetSplitBtn = MyToolButton.new()
	spriteSheetSplitBtn.hint_tooltip = tr("Split equally by specify count")
	add_child(spriteSheetSplitBtn)
	spriteSheetSplitBtn.connect("pressed", self, "_on_spriteSheetSplitBtn_pressed")
	
	autoSplitDialog = ConfirmationDialog.new()
	autoSplitDialog.window_title = tr("Split with transparent pixel")
	var vbox = VBoxContainer.new()
	autoSplitDialogFrameCheck = CheckBox.new()
	autoSplitDialogFrameCheck.text = tr("Frame")
	autoSplitDialogPatchCheck = CheckBox.new()
	autoSplitDialogPatchCheck.text = tr("Patch")
	autoSplitDialogPatchCheck.pressed = true
	vbox.add_child(autoSplitDialogFrameCheck)
	vbox.add_child(autoSplitDialogPatchCheck)
	autoSplitDialog.add_child(vbox)	
	autoSplitBtn.add_child(autoSplitDialog)
	autoSplitDialog.connect("popup_hide", self, "_on_autoSplitDialog_hide")
	autoSplitDialog.connect("confirmed", self, "_on_autoSplitDialog_confirmed")
	
	spriteSheetSplitDialog = ConfirmationDialog.new()
	spriteSheetSplitDialog.window_title = tr("Split with count")
	var vbox2 = VBoxContainer.new()
	var horiLabel = Label.new()
	horiLabel.text = tr("Horizontal count")
	vbox2.add_child(horiLabel)
	spriteSheetSplitDialogHEdit = SpinBox.new()
	spriteSheetSplitDialogHEdit.min_value = 1
	spriteSheetSplitDialogHEdit.allow_greater = true
	spriteSheetSplitDialogHEdit.value = 1
	vbox2.add_child(spriteSheetSplitDialogHEdit)
	var vertLabel = Label.new()
	vertLabel.text = tr("Vertical count")
	vbox2.add_child(vertLabel)
	spriteSheetSplitDialogVEdit = SpinBox.new()
	spriteSheetSplitDialogVEdit.min_value = 1
	spriteSheetSplitDialogVEdit.allow_greater = true
	spriteSheetSplitDialogVEdit.value = 1
	vbox2.add_child(spriteSheetSplitDialogVEdit)
	spriteSheetSplitDialogFrameCheck = CheckBox.new()
	spriteSheetSplitDialogFrameCheck.text = tr("Frame")
	spriteSheetSplitDialogPatchCheck = CheckBox.new()
	spriteSheetSplitDialogPatchCheck.text = tr("Patch")
	spriteSheetSplitDialogPatchCheck.pressed = true
	vbox2.add_child(spriteSheetSplitDialogFrameCheck)
	vbox2.add_child(spriteSheetSplitDialogPatchCheck)
	spriteSheetSplitDialog.add_child(vbox2)	
	spriteSheetSplitBtn.add_child(spriteSheetSplitDialog)
	spriteSheetSplitDialog.connect("popup_hide", self, "_on_spriteSheetSplitDialog_hide")
	spriteSheetSplitDialog.connect("confirmed", self, "_on_spriteSheetSplitDialog_confirmed")
	hide()

func hide_tool_opts():
	editTextureOptBtn.hide()
	editSizeOptBtn.hide()

func show_tool_opts():
	editTextureOptBtn.show()
	editSizeOptBtn.show()

func is_using_patch_tool():
	return patchToolBtn.pressed

func is_patch_tool_edit_uv():
	return editTextureOptBtn.pressed

func is_patch_tool_edit_ratio():
	return editSizeOptBtn.pressed

func setup(p_plugin):
	if editorInterface:
		return
	
	editorInterface = p_plugin.get_editor_interface()
	undoRedo = p_plugin.get_undo_redo()
	p_plugin.add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, self)

func unsetup(p_plugin:EditorPlugin):
	if not editorInterface:
		return
	
	editorInterface = null
	undoRedo = null
	edit(null)
	p_plugin.remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, self)

func _notification(what):
	if what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED || what == NOTIFICATION_READY:
		if get_color("font_color", "Label").r < 0.5:
			autoSplitBtn.icon = preload("autoSplitIcon_dark.png")
			patchToolBtn.icon = preload("patchToolIcon_dark.png")
			editSizeOptBtn.icon = preload("editSizeIcon_dark.png")
			editTextureOptBtn.icon = preload("editTextureIcon_dark.png")
		else:
			autoSplitBtn.icon = preload("autoSplitIcon_light.png")
			patchToolBtn.icon = preload("patchToolIcon_light.png")
			editSizeOptBtn.icon = preload("editSizeIcon_light.png")
			editTextureOptBtn.icon = preload("editTextureIcon_light.png")
		spriteSheetSplitBtn.icon = get_icon("SpriteSheet", "EditorIcons")
	
	if what == NOTIFICATION_READY:
		if isPendingUpdateSplitData:
			_update_split_patch_paires_and_points()

func edit(p_object):
	if editObj == p_object:
		return
	if editObj:
		editObj.disconnect("offset_changed", self, "_on_editObj_offset_changed")
		editObj.disconnect("size_changed", self, "_on_editObj_size_changed")
		editObj.disconnect("patches_changed", self, "_on_editObj_patches_changed")
		editObj.disconnect("frame_changed", self, "_on_editObj_frame_changed")
	editObj = p_object
	if editObj:
		editObj.connect("offset_changed", self, "_on_editObj_offset_changed")
		editObj.connect("size_changed", self, "_on_editObj_size_changed")
		editObj.connect("patches_changed", self, "_on_editObj_patches_changed")
		editObj.connect("frame_changed", self, "_on_editObj_frame_changed")
		viewport = editorInterface.get_edited_scene_root().get_parent()
	else:
		viewport = null

	update_scale_and_size_points()
	update_split_patch_paires_and_points()

func make_visible(p_visible):
	visible = p_visible
	if not p_visible:
		edit(null)

func _on_patchToolBtn_toggled(p_pressed):
	if p_pressed:
		show_tool_opts()
	else:
		if dragMode == MODE_T_SPLIT || dragMode == MODE_SPLIT:
			dragMode = MODE_NORMAL
		hide_tool_opts()
		if dragMode == MODE_SPLIT:
			dragMode = MODE_NORMAL
			dragData = null

func _on_editTextureOptBtn_toggled(p_pressed):
	if !p_pressed:
		editSizeOptBtn.pressed = true

func _on_editSizeOptBtn_toggled(p_pressed):
	if !p_pressed:
		editTextureOptBtn.pressed = true

func _on_editObj_offset_changed():
	update_scale_and_size_points()
	update_split_patch_paires_and_points()

func _on_editObj_size_changed():
	update_scale_and_size_points()
	update_split_patch_paires_and_points()

func _on_editObj_patches_changed():
	update_scale_and_size_points()
	update_split_patch_paires_and_points()

func _on_editObj_frame_changed():
	update_scale_and_size_points()

func _on_autoSplitBtn_pressed():
	autoSplitDialog.popup_centered()

func _on_autoSplitDialog_hide():
	autoSplitBtn.pressed = false

func _on_autoSplitDialog_confirmed():
	var flag = 0
	if autoSplitDialogFrameCheck.pressed:
		flag |= editObj.SPLIT_FLAG_FRAME_BIT
	if autoSplitDialogPatchCheck.pressed:
		flag |= editObj.SPLIT_FLAG_PATCH_BIT
	if flag != 0:
		editObj.auto_split(flag)

func _on_spriteSheetSplitBtn_pressed():
	spriteSheetSplitDialog.popup_centered()

func _on_spriteSheetSplitDialog_hide():
	spriteSheetSplitBtn.pressed = false

func _on_spriteSheetSplitDialog_confirmed():
	var flag = 0
	if spriteSheetSplitDialogFrameCheck.pressed:
		flag |= editObj.SPLIT_FLAG_FRAME_BIT
	if spriteSheetSplitDialogPatchCheck.pressed:
		flag |= editObj.SPLIT_FLAG_PATCH_BIT
	if flag != 0 && spriteSheetSplitDialogHEdit.value + spriteSheetSplitDialogVEdit.value > 2:
		editObj.sprite_sheet_split(spriteSheetSplitDialogHEdit.value, spriteSheetSplitDialogVEdit.value, flag)

func update_scale_and_size_points():
	if editObj == null:
		scalePoints.clear()
		sizePoints.clear()
		sizePivots.clear()
		return
	
	if editObj.is_using_isometric() && editObj.frame < 0.0:
		var pos = editObj.get_combo_offset()
		var topPos = pos
		var size = editObj.get_combo_size()
		var xVec = editObj.isometricNormal[0] * size.x
		var yVec = editObj.isometricNormal[1] * size.y
		var rightPos = topPos + xVec
		var bottomPos = rightPos + yVec
		var leftPos = topPos + yVec
		var rightTopPos = (topPos + rightPos) * 0.5
		var leftBottomPos = (bottomPos + leftPos) * 0.5
		var leftTopPos = (topPos + leftPos) * 0.5
		var rightBottomPos = (bottomPos + rightPos) * 0.5
		if editObj.can_scale():
			scalePoints = [ [topPos, bottomPos], [rightPos, leftPos], 
					[bottomPos, topPos], [leftPos, rightPos], 
					[rightTopPos, leftBottomPos], [rightBottomPos, leftTopPos], 
					[leftBottomPos, rightTopPos], [leftTopPos, rightBottomPos] ]
		else:
			scalePoints.clear()
		
		if not editObj.is_using_texture_scale() || (editObj.get_texture_scale().x != 0.0 && editObj.get_texture_scale().y != 0.0):
			sizePoints = [ topPos, rightPos, bottomPos, leftPos ]
			sizePivots = [ bottomPos, leftPos, topPos, rightPos]
		else:
			sizePivots.clear()
			sizePivots.clear()
	else:
		sizePoints.clear()
		sizePivots.clear()
		if editObj.can_scale():
			var rect = editObj.get_rect()
			var leftTopPos = rect.position
			var rightTopPos = leftTopPos + Vector2(rect.size.x, 0.0)
			var rightBottomPos = leftTopPos + rect.size
			var leftBottomPos = leftTopPos + Vector2(0.0, rect.size.y)
			var topPos = (leftTopPos + rightTopPos) * 0.5
			var rightPos = (rightTopPos + rightBottomPos) * 0.5
			var bottomPos = (rightBottomPos + leftBottomPos) * 0.5
			var leftPos = (leftTopPos + leftBottomPos) * 0.5
			scalePoints = [ [rightTopPos, leftBottomPos], [rightBottomPos, leftTopPos], 
					[leftBottomPos, rightTopPos], [leftTopPos, rightBottomPos],
					[topPos, bottomPos], [rightPos, leftPos], 
					[bottomPos, topPos], [leftPos, rightPos] ]
		else:
			scalePoints.clear()
	
	update_viewport()

func update_split_patch_paires_and_points():
	if isPendingUpdateSplitData:
		return
	
	isPendingUpdateSplitData = true
	if is_inside_tree():
		if editObj != null && editObj.dirtyDraw:
			yield(editObj, "draw_finished")
		_update_split_patch_paires_and_points()

func _update_split_patch_paires_and_points():
	isPendingUpdateSplitData = false
	splitPatchPoints.clear()
	tPatchContainers.clear()
	
	if editObj == null:
		update_viewport()
		return
	
	var needProcess = []
	if not editObj.patches is Patch:
		needProcess.append(editObj.patches)
	var current
	while needProcess.size() > 0:
		current = needProcess.back()
		needProcess.pop_back()
		if current is TPatchContainer:
			tPatchContainers.append(current)
			for i in current.children:
				if not i is Patch:
					needProcess.append(i)
			continue
		
		for i in current.get_split_edge_count():
			splitPatchPoints.append([current.get_split_edge_first_vertex(i), current.get_split_edge_last_vertex(i)])
		
		for i in current.children:
			if not i is Patch:
				needProcess.append(i)
	
	update_viewport()

func update_viewport():
	get_canvas_item_editor().update_viewport()

func get_scale_points(p_leftTop := false):
	var objXform = editObj.get_global_transform()
	var xform:Transform2D = viewport.global_canvas_transform * objXform
	var objScale = xform.get_scale()
	var ret := []
	if objScale.x == 0.0:
		objScale.x = 1.0
	if objScale.y == 0.0:
		objScale.y = 1.0
	var offset = Vector2.ZERO
	if p_leftTop:
		offset = Vector2(SCALE_RADIUS, SCALE_RADIUS)
	for i in scalePoints:
		ret.append(xform.xform(i[0] + ((i[0] - i[1]).normalized() * (SCALE_RADIUS + 3.0) - offset) / objScale))
	return ret

func _draw_patch_hightlight(p_control:Control, p_patch):
	var patchPoints:PoolVector2Array
	var xform = viewport.global_canvas_transform * editObj.get_global_transform()
	for i in p_patch.polygons:
		patchPoints = i
		for j in patchPoints.size():
			patchPoints[j] = xform.xform(patchPoints[j])
		p_control.draw_polygon(patchPoints, [Color(1.0, 1.0, 1.0, 0.1)])

func _draw_isometric(p_control:Control, p_centeredPos:Vector2, p_size:Vector2, p_transform:Transform2D, p_color:Color, p_width := 2.0):
	var points = []
	var halfTB = (editObj.isometricNormal[0] * p_size.x + editObj.isometricNormal[1] * p_size.y) * 0.5
	var halfLR = (editObj.isometricNormal[0] * p_size.x - editObj.isometricNormal[1] * p_size.y) * 0.5
	points.append(p_transform.xform(p_centeredPos - halfTB))
	points.append(p_transform.xform(p_centeredPos + halfLR))
	points.append(p_transform.xform(p_centeredPos + halfTB))
	points.append(p_transform.xform(p_centeredPos - halfLR))
	p_control.draw_polyline(points, p_color, p_width)
	p_control.draw_line(points[0], points[-1], p_color, p_width)

func color_to_gray(p_color:Color):
	var gray = 0.2989 * p_color.r + 0.5870 * p_color.g + 0.1140 * p_color.b
	return Color(gray, gray, gray, p_color.a)

func forward_canvas_draw_over_viewport(p_overlay:Control):
	if editObj == null:
		return
	
	var xform:Transform2D = viewport.global_canvas_transform * editObj.get_global_transform()
	
	var firstPos:Vector2
	var secondPos:Vector2
	var verticalVec:Vector2
	var edgeColor := Color(0xDE8B61FF)
	var edgeColor2 := Color(0x916A56FF)
	if not is_using_patch_tool():
		edgeColor = color_to_gray(edgeColor)
		edgeColor2 = color_to_gray(edgeColor2)
	
	for i in splitPatchPoints:
		firstPos = xform.xform(i[0])
		secondPos = xform.xform(i[1])
		p_overlay.draw_line(firstPos, secondPos,edgeColor, LINE_HALF_WIDTH * 2.0 - 2.0)
		verticalVec = (secondPos - firstPos).rotated(PI/2.0).normalized() * (LINE_HALF_WIDTH - 1.0)
		p_overlay.draw_line(firstPos + verticalVec, secondPos + verticalVec, edgeColor2, 1.0)
		p_overlay.draw_line(firstPos - verticalVec, secondPos - verticalVec, edgeColor2, 1.0)
	
	for i in tPatchContainers:
		for j in i.get_split_edge_count():
			firstPos = xform.xform(i.get_split_edge_first_vertex(j))
			secondPos = xform.xform(i.get_split_edge_last_vertex(j))
			p_overlay.draw_line(firstPos, secondPos,edgeColor, LINE_HALF_WIDTH * 2.0 - 2.0)
			verticalVec = (secondPos - firstPos).rotated(PI/2.0).normalized() * (LINE_HALF_WIDTH - 1.0)
			p_overlay.draw_line(firstPos + verticalVec, secondPos + verticalVec, edgeColor2, 1.0)
			p_overlay.draw_line(firstPos - verticalVec, secondPos - verticalVec, edgeColor2, 1.0)
	
	match dragMode:
		MODE_DRAG_SIZE:
			var size = get_drag_size(Input.is_key_pressed(KEY_SHIFT))
			var pivot = scalePoints[dragData][1]
			var dir = scalePoints[dragData][0] - pivot
			if editObj.is_using_isometric():
				dir = editObj._world_to_isometric(dir)
				dir = Vector2(sign(dir.x), sign(dir.y))
				if dragData == 4 || dragData == 6:
					dir.x = 0.0
				elif dragData == 5 || dragData == 7:
					dir.y = 0.0
				var targetPos = editObj.isometricNormal[0] * size.x * dir.x + editObj.isometricNormal[1] * size.y * dir.y + pivot
				_draw_isometric(p_overlay, ((targetPos + pivot) / 2.0), size, xform, Color(0.5, 0.5, 0.5))
			else:
				dir = Vector2(sign(dir.x), sign(dir.y))
				if dragData == 4 || dragData == 6:
					dir.x = 0.0
				elif dragData == 5 || dragData == 7:
					dir.y = 0.0
				var targetPos = size * dir + pivot
				var leftTop = (targetPos + pivot) / 2 - size * 0.5
				p_overlay.draw_rect(Rect2(xform.xform(leftTop), xform.basis_xform(size)), Color(0.5, 0.5, 0.5), false, 2.0)
		MODE_DRAG_ISOMETRIC_POINT:
			var pivot = sizePivots[dragData]
			var dir = editObj._world_to_isometric(sizePoints[dragData] - pivot)
			var size = get_drag_isometric_point_size(Input.is_key_pressed(KEY_SHIFT))
			dir = Vector2(sign(dir.x), sign(dir.y))
			var targetPos = editObj.isometricNormal[0] * size.x * dir.x + editObj.isometricNormal[1] * size.y * dir.y + pivot
			_draw_isometric(p_overlay, (targetPos + pivot) / 2.0, size, xform, Color(0.5, 0.5, 0.5))
		MODE_DRAG_ISOMETRIC_EDGE:
			var pivot = (sizePoints[dragData - 2] + sizePoints[dragData - 3]) * 0.5
			var size = get_drag_isometric_edge_size()
			var dir = editObj._world_to_isometric((sizePoints[dragData] + sizePoints[dragData - 1]) * 0.5 - pivot)
			dir = Vector2(sign(dir.x), sign(dir.y))
			if dragData == 0 ||  dragData == 2:
				dir.y = 0.0
			else:
				dir.x = 0.0
			var targetPos = editObj.isometricNormal[0] * size.x * dir.x + editObj.isometricNormal[1] * size.y * dir.y + pivot
			_draw_isometric(p_overlay, (targetPos + pivot) / 2.0, size, xform, Color(0.5, 0.5, 0.5))
		MODE_NORMAL:
			var mousePos = viewport.get_mouse_position()
			if is_using_patch_tool():
				var patch = get_split_patch(mousePos)
				if patch:
					if patch is Array:
						p_overlay.draw_line(xform.xform(patch[1][0]), xform.xform(patch[1][1]), Color(1.0, 1.0, 1.0, 0.2), LINE_HALF_WIDTH * 2.0)
					else:
						_draw_patch_hightlight(p_overlay, patch)
			else:
				var patch = editObj.get_patch_by_pos(editObj.get_global_transform().affine_inverse().xform(mousePos))
				if patch:
					_draw_patch_hightlight(p_overlay, patch)
		MODE_SPLIT_PRESSED:
			var patch = dragData
			if patch:
				_draw_patch_hightlight(p_overlay, patch)
		MODE_SPLIT, MODE_SPLIT_CENTER_PRESSED, MODE_SPLIT_EDGE_PRESSED, MODE_T_SPLIT:
			var points = []
			var localMousePos = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
			var target
			if dragMode == MODE_SPLIT || dragMode == MODE_SPLIT_CENTER_PRESSED || dragMode == MODE_T_SPLIT:
				target = dragData
			else:
				target = dragData[3]
			if target is TPatchContainer || dragMode == MODE_T_SPLIT:
				if dragMode == MODE_SPLIT_EDGE_PRESSED || is_using_patch_tool():
					if target.is_normal_axis():
						var rightBottomPos = target.get_global_right_pos()
						var leftX = target.get_global_left_pos().x
						localMousePos.x = (rightBottomPos.x + leftX) * 0.5
						localMousePos.y = clamp(localMousePos.y, target.get_global_top_pos().y, rightBottomPos.y)
						
						points.append(Vector2(leftX, localMousePos.y))
						points.append(Vector2(rightBottomPos.x, localMousePos.y))
						points.append(localMousePos)
						points.append(Vector2(localMousePos.x, rightBottomPos.y))
					elif target.yAxis != Vector2.DOWN:
						var topPos = target.get_global_top_pos()
						var bottomPos = target.get_global_bottom_pos()
						if localMousePos.x < bottomPos.x:
							localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, target.xAxis)
						elif localMousePos.x > bottomPos.x:
							localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, target.yAxis)
						var minY
						if topPos.x < bottomPos.x:
							minY = Geometry.line_intersects_line_2d(topPos, target.xAxis, bottomPos, Vector2.UP).y
						elif topPos.x > bottomPos.x:
							minY = Geometry.line_intersects_line_2d(topPos, target.yAxis, bottomPos, Vector2.UP).y
						else:
							minY = topPos.y
						localMousePos.y = clamp(localMousePos.y, minY, bottomPos.y)
						
						points.append(Geometry.line_intersects_line_2d(topPos, target.yAxis, localMousePos, target.xAxis))
						points.append(localMousePos)
						points.append(Geometry.line_intersects_line_2d(topPos, target.xAxis, localMousePos, target.yAxis))
						points.append(localMousePos)
						points.append(bottomPos)
						points.append(localMousePos)
					else:
						var rightPos = target.get_global_right_pos()
						var leftPos = target.get_global_left_pos()
						var bottomSplitPos = Geometry.line_intersects_line_2d(rightPos, Vector2(-target.xAxis.x, target.xAxis.y), leftPos, target.xAxis)
						
						localMousePos = Geometry.get_closest_point_to_segment_2d(localMousePos, rightPos, bottomSplitPos)
						points.append(Geometry.line_intersects_line_2d(leftPos, Vector2.UP, localMousePos, target.xAxis))
						points.append(localMousePos)
						points.append(rightPos)
						points.append(localMousePos)
						points.append(Geometry.line_intersects_line_2d(localMousePos, Vector2.DOWN, leftPos, target.xAxis))
						points.append(localMousePos)
			elif dragMode == MODE_SPLIT || dragMode == MODE_SPLIT_CENTER_PRESSED:
				if target.rect.has_point(target.to_local(localMousePos)):
					var mousePos = target.to_local(localMousePos)
					
					var closestEdge = 0	# top
					var dist = mousePos.y - target.rect.position.y
					var temp = target.rect.end.y - mousePos.y
					if temp < dist:
						closestEdge = 1	# bottom
						dist = temp
					temp = mousePos.x - target.rect.position.x
					if temp < dist:
						closestEdge = 2	# left
						dist = temp
					temp = target.rect.end.x - mousePos.x
					if temp < dist:
						closestEdge = 3	# right
						dist = temp
					
					match closestEdge:
						0, 1:
							if dragMode == MODE_SPLIT_CENTER_PRESSED:
								mousePos.x = target.rect.position.x + target.size.x * 0.5
							points.append(target.to_global(Vector2(mousePos.x, target.rect.position.y)))
							points.append(target.to_global(Vector2(mousePos.x, target.rect.end.y)))
						_:
							if dragMode == MODE_SPLIT_CENTER_PRESSED:
								mousePos.y = target.rect.position.y + target.size.y * 0.5
							points.append(target.to_global(Vector2(target.rect.position.x, mousePos.y)))
							points.append(target.to_global(Vector2(target.rect.end.x, mousePos.y)))
			else:
				var firstPatch = dragData[3][0]
				var p = firstPatch.parent
				if p is HPatchContainer || p is VPatchContainer:
					var axis = "x" if p is HPatchContainer else "y"
					var axis2 = "y" if axis == "x" else "x"
					var nextPatch = dragData[3][1]
					var minValue
					var maxValue
					minValue = firstPatch.rect.position[axis]
					maxValue = nextPatch.rect.end[axis]
					var mousePos = p.to_local(localMousePos)
					mousePos[axis] = clamp(mousePos[axis], minValue, maxValue)
					if mousePos[axis] - minValue < firstPatch.minSize[axis]:
						mousePos[axis] = firstPatch.minSize[axis] + minValue
					elif maxValue - mousePos[axis] < nextPatch.minSize[axis]:
						mousePos[axis] = maxValue - nextPatch.minSize[axis]
					
					points = [ Vector2.ZERO, Vector2.ZERO ]
					points[0][axis] = mousePos[axis]
					points[1][axis] = mousePos[axis]
					points[0][axis2] = nextPatch.rect.position[axis2]
					points[1][axis2] = nextPatch.rect.end[axis2]
					points[0] = p.to_global(points[0])
					points[1] = p.to_global(points[1])
			
			for i in points.size():
				points[i] = xform.xform(points[i])
			
			if points.size() > 1:
				for i in range(0, points.size(), 2):
					p_overlay.draw_line(points[i], points[i+1], Color(0.5, 0.5, 0.5))
					var lineLength = points[i].distance_to(points[i+1])
					if lineLength > 0.0:
						var hightlightLength = 3.0 / lineLength
						var hightlightSpd = hightlightLength * 4.0
						var time = 1.0 / hightlightSpd
						var t = fmod(float(OS.get_ticks_msec()) / 1000.0, time) * hightlightSpd
						var startPos = points[i].linear_interpolate(points[i+1], t)
						var et = t + hightlightLength
						var endPos = points[i].linear_interpolate(points[i+1], min(et, 1.0))
						p_overlay.draw_line(startPos, endPos, Color(0.6, 0.6, 0.6))
						if et > 1.0:
							startPos = points[i]
							endPos = points[i+1].linear_interpolate(points[i+1], et - 1.0)
							p_overlay.draw_line(startPos, endPos, Color(0.6, 0.6, 0.6))
	
	var scaleIcon = editorInterface.get_base_control().get_icon("EditorHandle", "EditorIcons")
	for i in get_scale_points(true):
		p_overlay.draw_texture(scaleIcon, i)
	
	for i in sizePoints.size():
		p_overlay.draw_line(xform.xform(sizePoints[i-1]), xform.xform(sizePoints[i]), Color(0xFF8484FF), 2.0)

func get_drag_size(p_isRatio:bool) -> Vector2:
	if dragMode != MODE_DRAG_SIZE:
		return Vector2.ZERO
	
	var mousePos:Vector2 = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
	var dir:Vector2 = (scalePoints[dragData][0] - scalePoints[dragData][1]).normalized()
	var vec:Vector2 = mousePos - scalePoints[dragData][1]
	if dragData > 3:
		vec = dir * vec.dot(dir)
	
	var size:Vector2
	if editObj.is_using_isometric():
		dir = editObj._world_to_isometric(dir)
		vec = editObj._world_to_isometric(vec)
	
	size = Vector2(max(vec.x * sign(dir.x), 0.0), max(vec.y * sign(dir.y), 0.0))
	
	if dragData > 3:
		if dir.x == 0.0:
			size.x = editObj.get_combo_size().x
		else:
			size.y = editObj.get_combo_size().y

	if dragData < 4 && p_isRatio:
		var curSize = editObj.get_combo_size()
		if curSize.x == 0.0:
			if curSize.y != 0.0:
				size.x = 0.0
		elif curSize.y == 0.0:
			size.y = 0.0
		else:
			var prevR = curSize.y / curSize.x
			var r = size.y / size.x
			if r > prevR:
				size.y = size.x * prevR
			elif r < prevR:
				size.x = size.y / prevR
		
	return size

func get_drag_isometric_point_size(p_isRatio:bool) -> Vector2:
	if dragMode != MODE_DRAG_ISOMETRIC_POINT:
		return Vector2.ZERO
	
	var ret:Vector2
	var mousePos:Vector2 = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
	var pivot = sizePivots[dragData]
	ret = editObj._world_to_isometric(mousePos - pivot)
	var dir = editObj._world_to_isometric(sizePoints[dragData] - pivot)
	ret = Vector2(max(ret.x * sign(dir.x), 0.0), max(ret.y * sign(dir.y), 0.0))

	if p_isRatio:
		var curSize = editObj.get_combo_size()
		if curSize.x == 0.0:
			if curSize.y != 0.0:
				ret.x = 0.0
		elif curSize.y == 0.0:
			ret.y = 0.0
		else:
			var prevR = curSize.y / curSize.x
			var r = ret.y / ret.x
			if r > prevR:
				ret.y = ret.x * prevR
			elif r < prevR:
				ret.x = ret.y / prevR
	
	return ret

func get_drag_isometric_edge_size() -> Vector2:
	if dragMode != MODE_DRAG_ISOMETRIC_EDGE:
		return Vector2.ZERO
	
	var ret:Vector2
	var mousePos:Vector2 = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
	var pivot = (sizePoints[dragData - 2] + sizePoints[dragData - 3]) * 0.5
	ret = editObj._world_to_isometric(mousePos - pivot)
	var dir = editObj._world_to_isometric((sizePoints[dragData] + sizePoints[dragData - 1]) * 0.5 - pivot)
	if dir.x == 0.0:
		ret.x = 0.0
	if dir.y == 0.0:
		ret.y = 0.0
	ret = Vector2(max(ret.x * sign(dir.x), 0.0), max(ret.y * sign(dir.y), 0.0))
	
	if dir.x == 0.0:
		ret.x = editObj.get_combo_size().x
	else:
		ret.y = editObj.get_combo_size().y
	return ret

func get_canvas_item_editor():
	return editorInterface.get_editor_viewport().get_child(0)

func set_size_offset(p_editObj, p_globalPivot:Vector2, p_size:Vector2):
	p_editObj.scale_with_pivot(p_globalPivot, p_size)

func set_isometric_range(p_editObj, p_top:Vector2, p_size:Vector2):
	if p_editObj.is_using_texture_scale():
		p_editObj.set_texture_scale(p_editObj.get_texture_scale() * p_editObj.isometricSize / p_size)
	p_editObj.isometricTop = p_top
	p_editObj.isometricSize = p_size

func split_patch(p_obj, p_patch, p_dir, p_splitPos):
	var patches = p_obj.split_patch(p_patch, p_dir, p_splitPos)
	if dragMode == MODE_SPLIT_EDGE_PRESSED:
		dragData.resize(3)
		dragData.append(patches)

func undo_split_patch(p_obj, p_patch, p_parent, p_index):
	p_parent = p_parent[0]
	if !p_parent:
		p_obj.patches = p_patch
		return
	
	if p_parent is TPatchContainer:
		p_parent.set_child(p_index, p_patch)
		return
	
	if !p_parent.children[p_index] is Patch:
		p_parent.remove_child(p_parent.children[p_index])
	else:
		p_parent.remove_child(p_parent.children[p_index])
		p_parent.remove_child(p_parent.children[p_index])
	
	p_parent.add_child(p_patch)
	p_parent.move_child(p_patch, p_index)
	p_parent.check_region()
	p_obj._update_draw()
	p_obj.emit_signal("patches_changed")

func t_split_patch(p_obj, p_patch, p_topLength):
	var tPC = p_obj.t_split_patch(p_patch, p_topLength)
	if dragMode == MODE_SPLIT_EDGE_PRESSED && dragData is Array && dragData.size() == 0:
		var topPatch = tPC.get_top()
		dragData = [ topPatch.length, topPatch.rect.size, topPatch.ratio, tPC, tPC.get_left().length, tPC.get_left().ratio ]

func undo_t_split_patch(p_obj, p_patch, p_patchParent):
	if p_patchParent:
		if p_patchParent is TPatchContainer:
			p_patchParent.set_child(p_patch.index, p_patch)
		else:
			var id = p_patch.index
			p_patchParent.remove_child(p_patchParent.children[id])
			p_patchParent.add_child(p_patchParent)
			p_patchParent.move_child(p_patchParent, id)
	else:
		p_obj.patches = p_patch

func merge_patches(p_obj, p_patchA, p_patchB):
	p_obj.merge_patch(p_patchA, p_patchB)

func undo_merge_patches(p_obj, p_patchA, p_patchB, p_mergePatchId, p_parent):
	var idA = p_patchA.index
	var idB = p_patchB.index
	p_parent.remove_child(p_parent.children[p_mergePatchId])
	
	if idB < idA:
		var temp = idA
		idA = idB
		idB = temp
		temp = p_patchA
		p_patchA = p_patchB
		p_patchB = temp
	
	p_parent.add_child(p_patchA)
	p_parent.move_child(p_patchA, idA)
	p_parent.add_child(p_patchB)
	p_parent.move_child(p_patchB, idB)
	p_parent.check_region()

func undo_merge_patches2(p_obj, p_patch, p_mergePatchId, p_grandparent):
	var id = p_mergePatchId
	if p_grandparent == null:
		p_obj.patches = p_patch
	elif p_grandparent is TPatchContainer:
		p_grandparent.set_child(id, p_patch)
		p_grandparent.check_region()
	else:
		p_grandparent.remove_child(p_grandparent[p_mergePatchId])
		p_grandparent.add_child(p_patch)
		p_grandparent.move_child(p_patch, id)
		p_grandparent.check_region()

func set_patches_split(p_patchA, p_patchB, p_lenA, p_ratios):
	p_patchA.set_length_from_left(p_lenA)
	p_patchA.set_ratio(p_ratios[0])
	p_patchB.set_ratio(p_ratios[1])

func get_split_patch(p_globalPos:Vector2):
	var localMousePos = editObj.get_global_transform().affine_inverse().xform(p_globalPos)

	if editObj.patches.has_point(localMousePos):
		var find
		var current = editObj.patches
		var closestPos
		var firstPos
		var secondPos
		while not current is Patch:
			find = false
			if current is TPatchContainer:
				for i in current.get_split_edge_count():
					firstPos = current.get_split_edge_first_vertex(i)
					secondPos = current.get_split_edge_last_vertex(i)
					closestPos = Geometry.get_closest_point_to_segment_2d(localMousePos, firstPos, secondPos)
					if closestPos.distance_to(localMousePos) < LINE_HALF_WIDTH:
						return [[current], [firstPos, secondPos]]
				for i in current.children:
					if i.has_point(localMousePos):
						find = true
						current = i
						break
			else:
				for i in current.get_split_edge_count():
					firstPos = current.get_split_edge_first_vertex(i)
					secondPos = current.get_split_edge_last_vertex(i)
					closestPos = Geometry.get_closest_point_to_segment_2d(localMousePos, firstPos, secondPos)
					if closestPos.distance_to(localMousePos) < LINE_HALF_WIDTH:
						var firstPatch
						var j = i
						var localFirstPos = current.to_local(firstPos)
						var axis = "y" if current.vertical else "x"
						while j < current.children.size() - 1:
							if current.children[j].rect.size.x * current.children[j].rect.size.y > 0 && is_equal_approx(current.children[j].rect.end[axis], localFirstPos[axis]):
								firstPatch = current.children[j]
								break
							j += 1
						if firstPatch:
							while j < current.children.size():
								if current.children[j].rect.size.x * current.children[j].rect.size.y > 0 && is_equal_approx(current.children[j].rect.position[axis], localFirstPos[axis]):
									return [[firstPatch, current.children[j]], [firstPos, secondPos]]
								j += 1
				
				for i in current.children.size():
					if current.children[i].has_point(localMousePos):
						find = true
						current = current.children[i]
						break
			
			if !find:
				return null
		return current
	return null

func forward_canvas_gui_input(p_event):
	if editObj == null:
		return false
	
	if p_event is InputEventMouseButton:
		if p_event.button_index == BUTTON_LEFT:
			if p_event.pressed:
				if dragMode == MODE_SELECT_PARENT_PRESSED || dragMode == MODE_T_SPLIT_PRESSED || dragMode == MODE_SPLIT_CENTER_PRESSED:
					return false
				
				var clickPos:Vector2 = p_event.position
				var points = get_scale_points()
				var find = -1
				for i in points.size():
					if clickPos.distance_to(points[i]) < SCALE_RADIUS:
						find = i
						break
				if find >= 0:
					dragData = find
					dragMode = MODE_DRAG_SIZE
					return true
				if editObj.is_using_isometric():
					var xform:Transform2D = viewport.global_canvas_transform * editObj.get_global_transform()
					var localMousePos = xform.affine_inverse().xform(clickPos)
					for i in sizePoints.size():
						if localMousePos.distance_to(sizePoints[i]) <= LINE_HALF_WIDTH:
							dragData = i
							dragMode = MODE_DRAG_ISOMETRIC_POINT
							return true
					var closestPoint
					for i in sizePoints.size():
						closestPoint = Geometry.get_closest_point_to_segment_2d(localMousePos, sizePoints[i-1], sizePoints[i])
						if closestPoint.distance_to(localMousePos) <= LINE_HALF_WIDTH:
							dragMode = MODE_DRAG_ISOMETRIC_EDGE
							dragData = i
							return true
				
				var globalPressedPos = viewport.global_canvas_transform.affine_inverse().xform(p_event.position)
				if is_using_patch_tool():
					if dragMode == MODE_SPLIT:
						dragMode = MODE_SPLIT_EDGE_PRESSED
						var localMousePos = editObj.get_global_transform().affine_inverse().xform(globalPressedPos)
						if editObj.is_using_isometric():
							localMousePos = dragData.to_local(localMousePos)
						localMousePos.x = clamp(localMousePos.x, dragData.rect.position.x, dragData.rect.end.x)
						localMousePos.y = clamp(localMousePos.y, dragData.rect.position.y, dragData.rect.end.y)
						var dist = localMousePos.y - dragData.rect.position.y
						var dir = 0
						if dragData.rect.end.y - localMousePos.y < dist:
							dir = 1
							dist = dragData.rect.end.y - localMousePos.y
						if localMousePos.x - dragData.rect.position.x < dist:
							dir = 2
							dist = localMousePos.x - dragData.rect.position.x
						if dragData.rect.end.x - localMousePos.x < dist:
							dir = 3
							dist = dragData.rect.end.x - localMousePos.x
						var splitPos
						var w
						var splitPatch = dragData
						match dir:
							0, 1:
								w = localMousePos.x - dragData.rect.position.x
								splitPos = dragData.region.size.x * w / dragData.rect.size.x
								dragData = [ splitPos, w, dragData.ratio * w / dragData.rect.size.x ]
							2, 3:
								w = localMousePos.y - dragData.rect.position.y
								splitPos = dragData.region.size.y * w / dragData.rect.size.y
								dragData = [ splitPos, w, dragData.ratio * w / dragData.rect.size.y ]
						undoRedo.create_action(tr("Split Patch"))
						undoRedo.add_do_method(self, "split_patch", editObj, splitPatch, dir > 1, splitPos)
						undoRedo.add_undo_method(self, "undo_split_patch", editObj, splitPatch, [splitPatch.parent], splitPatch.index)
						undoRedo.commit_action()
						return true
					elif dragMode == MODE_T_SPLIT:
						dragMode = MODE_SPLIT_EDGE_PRESSED
						var topLength:float
						var localMousePos = editObj.get_global_transform().affine_inverse().xform(globalPressedPos)
						var patch = dragData
						if patch.is_normal_axis():
							topLength = clamp(localMousePos.y - patch.get_global_top_pos().y, 0.0, patch.rect.size.y) * patch.region.size.y / patch.rect.size.y
						elif patch.yAxis == Vector2.DOWN:
							var rightPos = patch.get_global_right_pos()
							var bottomSplitPos = Geometry.line_intersects_line_2d(rightPos, Vector2(-patch.xAxis.x, patch.xAxis.y), patch.get_global_left_pos(), patch.xAxis)
							localMousePos = Geometry.get_closest_point_to_segment_2d(localMousePos, bottomSplitPos, rightPos)
							var leftSplitPos = Geometry.line_intersects_line_2d(patch.get_global_top_pos(), Vector2.DOWN, localMousePos, patch.xAxis)
							topLength = leftSplitPos.distance_to(localMousePos) * patch.region.size.x / patch.rect.size.x
						else:
							var bottomPos = patch.get_global_bottom_pos()
							var topPos = patch.get_global_top_pos()
							var topSplitPos
							if localMousePos.x < bottomPos.x:
								localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, patch.xAxis)
							elif localMousePos.x > bottomPos.x:
								localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, patch.yAxis)
							
							if bottomPos.x < topPos.x:
								topSplitPos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, topPos, patch.yAxis)
							elif bottomPos.x > topPos.x:
								topSplitPos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, topPos, patch.xAxis)
							else:
								topSplitPos = topPos
							topLength = patch.to_global(patch.to_local(Vector2(0.0, clamp(localMousePos.y - topSplitPos.y, 0.0, bottomPos.y - topSplitPos.y))) 
									* patch.region.size / patch.rect.size).y
						
						dragData = []
						undoRedo.create_action(tr("T Split Patch"))
						undoRedo.add_do_method(self, "t_split_patch", editObj, patch, topLength)
						undoRedo.add_undo_method(self, "undo_t_split_patch", editObj, patch, patch.parent)
						undoRedo.commit_action()
					else:
						var patch = get_split_patch(globalPressedPos)
						if patch:
							if patch is Array:
								dragMode = MODE_SPLIT_EDGE_PRESSED
								var firstPatch = patch[0][0]
								if firstPatch is TPatchContainer:
									var topPatch = firstPatch.get_top()
									dragData = [ topPatch.length, topPatch.rect.size, topPatch.ratio, firstPatch, firstPatch.get_left().length, firstPatch.get_left().ratio ]
								else:
									var axis = "y" if firstPatch.parent.vertical else "x"
									dragData = [ firstPatch.length, firstPatch.rect.size[axis], firstPatch.ratio, patch[0] ]
							else:
								dragMode = MODE_SPLIT_PRESSED
								dragData = patch
								editorInterface.get_selection().add_node(editObj)
							return true
				else:
					var patch = editObj.get_patch_by_pos(editObj.get_global_transform().affine_inverse().xform(globalPressedPos))
					if patch:
						dragMode = MODE_SELECT_PRESSED
						dragData = patch
						return true
			elif dragMode != MODE_NORMAL:
				match dragMode:
					MODE_SPLIT_CENTER_PRESSED, MODE_T_SPLIT_PRESSED, MODE_SELECT_PARENT_PRESSED:
						return false
					MODE_DRAG_SIZE:
						var size = get_drag_size(p_event.shift)
						var pivot = editObj.get_global_transform().xform(scalePoints[dragData][1])
						undoRedo.create_action(tr("Set Size And Offset"))
						undoRedo.add_do_method(self, "set_size_offset", editObj, pivot, size)
						undoRedo.add_undo_method(self, "set_size_offset", editObj, pivot, editObj.get_combo_size())
						undoRedo.commit_action()
					MODE_DRAG_ISOMETRIC_POINT, MODE_DRAG_ISOMETRIC_EDGE:
						var pivot
						var dir
						var size
						if dragMode == MODE_DRAG_ISOMETRIC_POINT:
							pivot = sizePivots[dragData]
							dir = editObj._world_to_isometric(sizePoints[dragData] - pivot)
							dir = Vector2(sign(dir.x), sign(dir.y))
							size = get_drag_isometric_point_size(p_event.shift)
						else:
							pivot = (sizePoints[dragData - 3] + sizePoints[dragData - 2]) * 0.5
							dir = editObj._world_to_isometric((sizePoints[dragData] + sizePoints[dragData - 1]) * 0.5 - pivot)
							dir = Vector2(sign(dir.x), sign(dir.y))
							if dragData == 0 || dragData == 2:
								dir.y = 0.0
							else:
								dir.x = 0.0
							size = get_drag_isometric_edge_size()
						
						var targetPos = editObj.isometricNormal[0] * size.x * dir.x + editObj.isometricNormal[1] * size.y * dir.y + pivot
						var top = (targetPos + pivot) * 0.5 - editObj.isometricNormal[0] * size.x * 0.5 - editObj.isometricNormal[1] * size.y * 0.5
						var scale := Vector2(1.0, 1.0)
						if editObj.is_using_texture_scale():
							scale = Vector2(1.0, 1.0) / editObj.get_texture_scale()
						elif editObj.isometricSize.x != 0.0 && editObj.isometricSize.y != 0.0:
							scale = editObj.size / editObj.isometricSize
						elif editObj.isometricSize.x != 0.0:
							var temp = editObj.size.x / editObj.isometricSize.x
							scale = Vector2(temp, temp)
						elif editObj.isometricSize.y != 0.0:
							var temp = editObj.size.y / editObj.isometricSize.y
							scale = Vector2(temp, temp)
						var isometricTop = top - editObj.get_combo_offset() + editObj.isometricTop
						var isometricSize = size * scale
						if isometricSize.x <= 0.0:
							isometricSize.x = 1.0
						if isometricSize.y <= 0.0:
							isometricSize.y = 1.0
						undoRedo.create_action(tr("Set Isometric Range"))
						undoRedo.add_do_method(self, "set_isometric_range", editObj, isometricTop, isometricSize)
						undoRedo.add_undo_method(self, "set_isometric_range", editObj, editObj.isometricTop, editObj.isometricSize)
						undoRedo.commit_action()
					MODE_SELECT_PRESSED, MODE_SPLIT_PRESSED:
						var xform = viewport.global_canvas_transform * editObj.get_global_transform()
						var localMousePos = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
						if dragData.has_point(localMousePos):
							if dragMode == MODE_SELECT_PRESSED:
								editorInterface.edit_resource(dragData)
							else:
								dragMode = MODE_SPLIT
								update_viewport()
								return true
					MODE_SPLIT_EDGE_PRESSED:
						if dragData[3] is TPatchContainer:
							var tPC = dragData[3]
							var originalTopLength = dragData[0]
							var originalTopSize = dragData[1]
							var originalTopRatio = dragData[2]
							var originalLeftLength = dragData[4]
							var originalLeftRatio = dragData[5]
							var topPatch = tPC.get_top()
							var leftPatch = tPC.get_left()
							var isTopPatchRatioZero = topPatch.ratio <= 0.0 || is_equal_approx(topPatch.ratio, 0)
							var isBottomPatchRatioZero = leftPatch.ratio <= 0.0 || is_equal_approx(leftPatch.ratio, 0)
							if is_patch_tool_edit_ratio() && (isTopPatchRatioZero || isBottomPatchRatioZero):
								topPatch.length = originalTopLength
								leftPatch.length = originalLeftLength
								topPatch.ratio = originalTopRatio
								leftPatch.ratio = originalLeftRatio
								var rightPatch = tPC.get_right()
								rightPatch.ratio = leftPatch.ratio
								rightPatch.length = leftPatch.length
								undoRedo.create_action(tr("Merge Patches"))
								undoRedo.add_do_method(self, "merge_patches", editObj, topPatch, leftPatch)
								undoRedo.add_undo_method(self, "undo_merge_patches2", editObj, topPatch.parent, topPatch.parent.index, topPatch.parent.parent)
							else:
								undoRedo.create_action(tr("Drag Split Edge"))
								undoRedo.add_do_method(self, "set_patches_split", topPatch, leftPatch, topPatch.length, [topPatch.ratio, leftPatch.ratio])
								undoRedo.add_undo_method(self, "set_patches_split", topPatch, leftPatch, originalTopLength, [originalTopRatio, originalLeftRatio])
							undoRedo.commit_action()
						else:
							var firstPatch = dragData[3][0]
							var secondPatch = dragData[3][1]
							var isFirstPatchRatioZero = firstPatch.ratio <= 0.0 || is_equal_approx(firstPatch.ratio, 0)
							var isSecondPatchRatioZero = secondPatch.ratio <= 0.0 || is_equal_approx(secondPatch.ratio, 0)
							var originalLength = dragData[0]
							var originalWidth = dragData[1]
							var originalRatio = dragData[2]
							if is_patch_tool_edit_ratio() && (isFirstPatchRatioZero || isSecondPatchRatioZero):
								var totalRatio = firstPatch.ratio + secondPatch.ratio
								var totalLength = firstPatch.length + secondPatch.length
								firstPatch.length = originalLength
								firstPatch.ratio = originalRatio
								secondPatch.length = totalLength - firstPatch.length
								secondPatch.ratio = totalRatio - firstPatch.ratio
								undoRedo.create_action(tr("Merge Patches"))
								if isFirstPatchRatioZero:
									undoRedo.add_do_method(self, "merge_patches", editObj, secondPatch, firstPatch)
								else:
									undoRedo.add_do_method(self, "merge_patches", editObj, firstPatch, secondPatch)
								
								if firstPatch.parent is TPatchContainer || firstPatch.parent.children.size() == 2:
									undoRedo.add_undo_method(self, "undo_merge_patches2", editObj, firstPatch.parent, firstPatch.parent.index, firstPatch.parent.parent)
								else:
									var mergeId = int(min(firstPatch.index, secondPatch.index))
									undoRedo.add_undo_method(self, "undo_merge_patches", editObj, firstPatch, secondPatch, mergeId, firstPatch.parent)
							else:
								undoRedo.create_action(tr("Drag Split Edge"))
								undoRedo.add_do_method(self, "set_patches_split", firstPatch, secondPatch, firstPatch.length, [firstPatch.ratio, secondPatch.ratio])
								undoRedo.add_undo_method(self, "set_patches_split", firstPatch, secondPatch, originalLength, 
										[originalRatio, firstPatch.ratio + secondPatch.ratio - originalRatio])
							undoRedo.commit_action()
				dragMode = MODE_NORMAL
				update_viewport()
				return true
		elif p_event.button_index == BUTTON_RIGHT:
			if p_event.pressed:
				if dragMode == MODE_SPLIT:
					dragMode = MODE_SPLIT_CENTER_PRESSED
					return true
				elif dragMode == MODE_NORMAL:
					var patch = editObj.get_patch_by_pos(editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position()))
					if patch:
						if is_using_patch_tool():
							dragMode = MODE_T_SPLIT_PRESSED
							dragData = patch
							return true
						else:
							dragMode = MODE_SELECT_PARENT_PRESSED
							dragData = patch
							return true
			elif dragMode == MODE_SPLIT_CENTER_PRESSED:
				dragMode = MODE_NORMAL
				var patch = dragData
				var localMousePos = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
				if editObj.is_using_isometric():
					localMousePos = editObj._world_to_isometric(localMousePos)
				localMousePos.x = clamp(localMousePos.x, patch.rect.position.x, patch.rect.end.x)
				localMousePos.y = clamp(localMousePos.y, patch.rect.position.y, patch.rect.end.y)
				var dist = localMousePos.y - patch.rect.position.y
				var dir = 0
				if patch.rect.end.y - localMousePos.y < dist:
					dir = 1
					dist = patch.rect.end.y - localMousePos.y
				if localMousePos.x - patch.rect.position.x < dist:
					dir = 2
					dist = localMousePos.x - patch.rect.position.x
				if patch.rect.end.x - localMousePos.x < dist:
					dir = 3
					dist = patch.rect.end.x - localMousePos.x
				var splitPos
				var w
				match dir:
					0, 1:
						w = patch.rect.size.x * 0.5
						splitPos = patch.region.size.x * 0.5
					2, 3:
						w =  patch.rect.size.y * 0.5
						splitPos = patch.region.size.y * 0.5
				
				var splitPatch = patch
				patch = [ splitPos, w, patch.ratio * 0.5 ]
				undoRedo.create_action(tr("Split Patch"))
				undoRedo.add_do_method(self, "split_patch", editObj, splitPatch, dir > 1, splitPos)
				undoRedo.add_undo_method(self, "undo_split_patch", editObj, splitPatch, [splitPatch.parent], splitPatch.index)
				undoRedo.commit_action()
				dragData = null
				
				return true
			elif dragMode == MODE_T_SPLIT_PRESSED:
				if dragData.has_point(editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())):
					dragMode = MODE_T_SPLIT
				else:
					dragMode = MODE_NORMAL
					dragData = null
			elif dragMode == MODE_SELECT_PARENT_PRESSED:
				if dragData.has_point(editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())):
					if dragData.parent:
						editorInterface.edit_resource(dragData.parent)
					else:
						editorInterface.edit_resource(dragData)
				dragMode = MODE_NORMAL
				dragData = null
	elif p_event is InputEventMouseMotion:
		if dragMode == MODE_SPLIT_EDGE_PRESSED:
			var localMousePos = editObj.get_global_transform().affine_inverse().xform(viewport.get_mouse_position())
			if dragData[3] is TPatchContainer:
				var ratio
				var tPC = dragData[3]
				if tPC.is_normal_axis():
					ratio = localMousePos.y - tPC.get_global_top_pos().y
					ratio = clamp(ratio, 0.0, tPC.get_global_bottom_pos().y)
					if is_patch_tool_edit_uv():
						var h = tPC.to_global(dragData[1]).y
						if ratio < h:
							tPC.get_top().set_length(dragData[0] * ratio / h)
						else:
							var bh = tPC.to_global(tPC.rect.size).y - h
							tPC.get_top().set_length(dragData[0] + (tPC.get_top().length + tPC.get_left().length - tPC) * (ratio - h) / bh)
					
					if is_patch_tool_edit_ratio():
						var totalRatio = tPC.get_top().ratio + tPC.get_left().ratio
						if totalRatio <= 0.0:
							totalRatio = 2.0
						var h = tPC.to_global(tPC.rect.size).y
						tPC.get_top().set_ratio(ratio / h * totalRatio)
						tPC.get_left().set_ratio(totalRatio - tPC.get_top().ratio)
				elif tPC.yAxis != Vector2.DOWN: 
					var topPos = tPC.get_global_top_pos()
					var bottomPos = tPC.get_global_bottom_pos()
					var leftPos = tPC.get_global_left_pos()
					var rightPos = tPC.get_global_right_pos()
					var splitTopPos
					if bottomPos.x < topPos.x:
						splitTopPos = Geometry.line_intersects_line_2d(topPos, tPC.yAxis, bottomPos, Vector2.UP)
					elif bottomPos.x > topPos.x:
						splitTopPos = Geometry.line_intersects_line_2d(topPos, tPC.xAxis, bottomPos, Vector2.UP)
					else:
						splitTopPos = topPos
					if localMousePos.x < bottomPos.x:
						localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, tPC.xAxis)
					elif localMousePos.x > bottomPos.x:
						localMousePos = Geometry.line_intersects_line_2d(bottomPos, Vector2.UP, localMousePos, tPC.yAxis)
					ratio = localMousePos.y - splitTopPos.y
					ratio = clamp(ratio, 0.0, bottomPos.y - splitTopPos.y)
					if is_patch_tool_edit_uv():
						var topPatch = tPC.get_top()
						var intersectPos
						var topBottomPos = topPatch.to_global(dragData[1]) + topPos
						if bottomPos.x < topPos.x:
							intersectPos = Geometry.line_intersects_line_2d(splitTopPos, Vector2.DOWN, topBottomPos, topPatch.xAxis)
						elif bottomPos.x > topPos.x:
							intersectPos = Geometry.line_intersects_line_2d(splitTopPos, Vector2.DOWN, topBottomPos,  topPatch.yAxis)
						else:
							intersectPos = topBottomPos
						var h = intersectPos.y - splitTopPos.y
						if ratio < h:
							topPatch.set_length(dragData[0] * ratio / h)
						else:
							topPatch.set_length(dragData[0] + (topPatch.length + tPC.get_left().length - dragData[0]) * (ratio - h) / (bottomPos.y - intersectPos.y))
					
					if is_patch_tool_edit_ratio():
						var totalRatio = tPC.get_top().ratio +  tPC.get_left().ratio
						if totalRatio <= 0.0:
							totalRatio = 2.0
						tPC.get_top().set_ratio(totalRatio * ratio / (bottomPos.y - splitTopPos.y))
						tPC.get_left().set_ratio(totalRatio - tPC.get_top().ratio)
				else:
					var rightPos = tPC.get_global_right_pos()
					var leftPos = tPC.get_global_left_pos()
					var intersectPos = Geometry.line_intersects_line_2d(rightPos, tPC.get_top().yAxis, leftPos, tPC.xAxis)
					localMousePos = Geometry.get_closest_point_to_segment_2d(localMousePos, rightPos, intersectPos)
					var intersectPos2 = Geometry.line_intersects_line_2d(localMousePos, tPC.xAxis, leftPos, Vector2.UP)
					ratio = localMousePos.distance_to(intersectPos2)
					
					if is_patch_tool_edit_uv():
						tPC.get_top().set_length(dragData[0] * ratio / dragData[1].x)
					
					if is_patch_tool_edit_ratio():
						var totalRatio = tPC.get_top().ratio + tPC.get_left().ratio
						if totalRatio <= 0.0:
							totalRatio = 2.0
						tPC.get_top().set_ratio(ratio / tPC.rect.size.x * totalRatio)
						tPC.get_left().set_ratio(totalRatio - tPC.get_top().get_ratio())
			else:
				var firstPatch = dragData[3][0]
				var secondPatch = dragData[3][1]
				localMousePos = firstPatch.to_local(localMousePos)
				var axis = "y" if firstPatch.parent is VPatchContainer else "x"
				localMousePos[axis] = clamp(localMousePos[axis], firstPatch.rect.position[axis], secondPatch.rect.end[axis])
				var firstW = dragData[1]
				var secondW = firstPatch.rect.size[axis] + secondPatch.rect.size[axis] - firstW
				var splitPos = localMousePos[axis] - firstPatch.rect.position[axis]
				if is_patch_tool_edit_uv():
					if splitPos < firstW:
						firstPatch.set_length_from_left(dragData[0] * splitPos / firstW)
					elif secondW > 0:
						var secondLen = firstPatch.length + secondPatch.length - dragData[0]
						firstPatch.set_length_from_left(dragData[0] + secondLen * (splitPos - firstW) / secondW)
				
				if is_patch_tool_edit_ratio():
					var totalRatio = firstPatch.ratio + secondPatch.ratio
					if totalRatio <= 0.0:
						totalRatio = 2.0
					var w = firstW + secondW
					var sr
					if w <= 0.0:
						sr = 0.5 * totalRatio
					else:
						sr = splitPos / w
					firstPatch.set_ratio(sr * totalRatio)
					secondPatch.set_ratio(totalRatio - firstPatch.ratio)
		update_viewport()
		if dragMode != MODE_NORMAL && dragMode != MODE_SPLIT:
			return true
	return false
