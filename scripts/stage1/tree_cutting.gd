extends "res://scripts/grid_stage/paper_cutting.gd"
var puzzle:Node3D
var owns_stroke:=false
var fixed_cut_source:Sprite3D
const CUT_HEIGHT_RATIO:=.8

func _pick(point:Vector2) -> Dictionary:
	var exact:=super._pick(point)
	if not exact.is_empty():return exact
	# Only the intact swing tree receives padding; keep the normal occlusion check.
	for radius:float in [7.0,14.0]:
		for direction:int in range(8):
			var hit:=super._pick(point+Vector2.RIGHT.rotated(direction*TAU/8.0)*radius)
			if not hit.is_empty() and hit.attached and hit.source.sprite.has_meta("swing_cut_margin"):
				return hit
	return {}

func _stroke_hits_ink(source:Dictionary,a:Vector2,b:Vector2) -> bool:
	if super._stroke_hits_ink(source,a,b):return true
	var margin:float=float(source.sprite.get_meta("swing_cut_margin",0.0))
	if margin<=0:return false
	var normal:Vector2=(b-a).normalized().orthogonal()
	for offset:float in [-1.0,-.5,.5,1.0]:
		if super._stroke_hits_ink(source,a+normal*margin*offset,b+normal*margin*offset):return true
	return false

func _cut_results(piece:Dictionary,a:Vector2,b:Vector2) -> Array[PackedVector2Array]:
	if bool(piece.get("regrowing",false)):return []
	var index:int=puzzle.trees.find(piece.source.sprite)
	if index<0 or puzzle.cut_done[index]:return []
	if is_instance_valid(fixed_cut_source) and piece.source.sprite!=fixed_cut_source:return []
	return super._cut_results(piece,a,b)

func _cut(a:Vector2,b:Vector2) -> void:
	if not cutting_enabled():return
	if (not puzzle.warned or puzzle.speech.active) and not puzzle.cut_done[puzzle.tree_art.find(puzzle.speech.rope_tree)]:
		for piece:Dictionary in pieces:
			var index:int=puzzle.trees.find(piece.source.sprite)
			if index<0 or not piece.attached:continue
			if puzzle.tree_art[index]!=puzzle.speech.rope_tree:continue
			if not _cut_results(piece,a,b).is_empty():
				if not puzzle.warned:
					puzzle.warned=true;puzzle.speech.warn_wrong_tree()
					puzzle._cancel_background_strokes(world.stage_root)
					return
				if puzzle.speech.active:return
	for piece:Dictionary in pieces.duplicate():
		if not piece.attached or _cut_results(piece,a,b).is_empty():continue
		# The gesture selects the tree; every cut uses the same authored trunk line.
		var bounds:=Rect2(piece.source.polygon[0],Vector2.ZERO)
		for vertex:Vector2 in piece.source.polygon:bounds=bounds.expand(vertex)
		var y:=bounds.position.y+bounds.size.y*CUT_HEIGHT_RATIO
		var start:Vector2=piece.body.transform*Vector2(bounds.position.x-20,y)
		var finish:Vector2=piece.body.transform*Vector2(bounds.end.x+20,y)
		fixed_cut_source=piece.source.sprite
		super._cut(start,finish)
		fixed_cut_source=null
		return

func _preview_surface(_piece:Dictionary) -> Dictionary:
	# Stage5TreeBridge mounts the real wood on the transparent route on release.
	return {}

func _input(event:InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position=event.position;pointer_observed=true
	if not cutting_enabled() or locked or world.paused or world.transition.active or world.player.input_locked:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and is_instance_valid(grabbed):
		_finish_drag(false);owns_stroke=false;get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit:=_pick(_mouse())
			if hit.is_empty():return
			owns_stroke=true
		elif not owns_stroke and not is_instance_valid(grabbed):return
		super._unhandled_input(event)
		if not event.pressed:owns_stroke=false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (owns_stroke or is_instance_valid(grabbed)):
		super._unhandled_input(event);get_viewport().set_input_as_handled()

func _process(delta:float) -> void:
	super._process(delta)
	for piece:Dictionary in pieces:
		for visual:MeshInstance3D in [piece.visual,piece.border,piece.shadow]:
			visual.set_meta("paper_protect_player",bool(piece.sticker))
			visual.set_meta("wood_wave_protected",not piece.attached and visual!=piece.shadow)
	if locked:owns_stroke=false
