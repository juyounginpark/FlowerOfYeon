extends CanvasLayer
enum Step { WAIT, CUT, DRAG, DONE }
var step:=Step.WAIT
var puzzle:Node3D
var target:Sprite3D
var clock:=0.0
var dashes:TextureRect
var mouse:TextureRect
var cut_hint:Label
var last_origin:=Vector2.ZERO

func configure(owner_puzzle:Node3D) -> void:
	puzzle=owner_puzzle;layer=100
	# Choose the ordinary tree on the left of the screen, never the swing tree.
	for i:int in range(puzzle.trees.size()):
		if puzzle.tree_art[i]==puzzle.speech.rope_tree:continue
		if target==null or puzzle.camera.unproject_position(puzzle.trees[i].global_position).x<puzzle.camera.unproject_position(target.global_position).x:
			target=puzzle.trees[i]
	dashes=_picture("red_cut_dashes")
	mouse=_picture("tutorial_mouse")
	dashes.hide();mouse.hide()
	cut_hint=Label.new();cut_hint.text="하얀 테두리가 있으면 자를 수 있다."
	cut_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cut_hint.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	cut_hint.add_theme_color_override("font_color",Color("30291f"))
	var paper:=StyleBoxFlat.new();paper.bg_color=Color(.97,.93,.82,.94)
	paper.set_corner_radius_all(8);paper.content_margin_left=12;paper.content_margin_right=12
	paper.content_margin_top=8;paper.content_margin_bottom=8
	cut_hint.add_theme_stylebox_override("normal",paper)
	add_child(cut_hint);cut_hint.hide()

func _picture(id:String) -> TextureRect:
	var source:Image=load("res://art/stage1/tutorial/"+id+".png").get_image()
	if source.is_compressed():source.decompress()
	var picture:=TextureRect.new()
	picture.texture=ImageTexture.create_from_image(source.get_region(source.get_used_rect()))
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_SCALE
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(picture);return picture

func start() -> void:
	if step!=Step.WAIT or target==null:return
	var index:int=puzzle.trees.find(target)
	step=Step.DRAG if puzzle.cut_done[index] else Step.CUT
	puzzle.world.stage_root.set_meta("paper_cutting_enabled",true)
	clock=0
	last_origin=puzzle.camera.unproject_position(target.global_position)

func tree_cut(source:Sprite3D) -> void:
	if step==Step.CUT and source==target:
		step=Step.DRAG;clock=0;dashes.hide();cut_hint.hide()

func is_drag_step() -> bool:
	return step==Step.DRAG

func finish() -> void:
	step=Step.DONE;dashes.hide();mouse.hide();cut_hint.hide()

func _source_piece(attached:bool) -> Dictionary:
	var largest:Dictionary={}
	for piece:Dictionary in puzzle.paper.pieces:
		if piece.source.sprite!=target or piece.attached!=attached or piece.sticker:continue
		if bool(piece.get("regrowing",false)):continue
		if largest.is_empty() or puzzle.paper._area(piece.polygon)>puzzle.paper._area(largest.polygon):largest=piece
	return largest

func _bounds(piece:Dictionary) -> Rect2:
	var bounds:=Rect2(piece.polygon[0],Vector2.ZERO)
	for point:Vector2 in piece.polygon:bounds=bounds.expand(point)
	return bounds

func _screen_point(piece:Dictionary,point:Vector2) -> Vector2:
	return puzzle.camera.unproject_position(piece.visual.global_transform*Vector3(point.x,-point.y,0))

func _process(delta:float) -> void:
	if puzzle==null:return
	cut_hint.hide()
	var blocked:bool=puzzle.world.paused or puzzle.world.transition.active or puzzle.world.completed
	if blocked or step in [Step.WAIT,Step.DONE]:
		dashes.hide();mouse.hide();return
	clock+=delta
	var scale_ui:=clampf(get_viewport().get_visible_rect().size.y/900.0,.7,1.5)
	mouse.size=Vector2(42,64)*scale_ui
	mouse.show()
	if step==Step.CUT:
		var piece:=_source_piece(true)
		if piece.is_empty():dashes.hide();mouse.hide();return
		var bounds:=_bounds(piece)
		var y:float=bounds.position.y+bounds.size.y*puzzle.paper.CUT_HEIGHT_RATIO
		var a:=_screen_point(piece,Vector2(bounds.position.x-10,y))
		var b:=_screen_point(piece,Vector2(bounds.end.x+10,y))
		cut_hint.add_theme_font_size_override("font_size",roundi(20*scale_ui))
		cut_hint.size=cut_hint.get_combined_minimum_size()
		var frame:=get_viewport().get_visible_rect().size
		var hint_position:=a.lerp(b,.5)-Vector2(cut_hint.size.x*.5,cut_hint.size.y+28*scale_ui)
		cut_hint.position=Vector2(clampf(hint_position.x,8,maxf(8,frame.x-cut_hint.size.x-8)),clampf(hint_position.y,8,maxf(8,frame.y-cut_hint.size.y-8)))
		cut_hint.show()
		dashes.position=a-Vector2(0,5*scale_ui)
		dashes.size=Vector2(a.distance_to(b),10*scale_ui)
		dashes.rotation=(b-a).angle();dashes.show()
		var t:=clampf(fmod(clock,2.4)/1.8,0,1)
		mouse.position=a.lerp(b,t)-mouse.size*Vector2(.25,.2)
	else:
		dashes.hide()
		var piece:=_source_piece(false)
		if not piece.is_empty():last_origin=_screen_point(piece,_bounds(piece).get_center())
		var destination:Vector2=puzzle.camera.unproject_position((puzzle.start+puzzle.crest)*.5)
		var t:=smoothstep(0,1,clampf(fmod(clock,2.8)/2.1,0,1))
		mouse.position=last_origin.lerp(destination,t)-mouse.size*Vector2(.25,.2)
		mouse.modulate.a=1.0-clampf((fmod(clock,2.8)-2.3)/.5,0,1)
