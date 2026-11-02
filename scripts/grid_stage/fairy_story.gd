extends Node3D
# Stage 2's folktale puzzle: cut the robe, dress the fairy, open the passage.
enum Phase { ROBE_ON_ROCK, SPLITTING, ROBE_LOOSE, DRESSING, FLYING, ASCENDING, OPEN }
var world:GridStageWorld
var camera:Camera3D
var phase:=Phase.ROBE_ON_ROCK
var path_open:=false
var elapsed:=0.0
var phase_time:=0.0
var wood:Sprite3D
var rock:Sprite3D
var fairy:Sprite3D
var robe:Sprite3D
var couple:Sprite3D
var blocker:StaticBody3D
var wood_sheet:Texture2D
var fairy_sheet:Texture2D
var bath_sheet:Texture2D
var couple_sheet:Texture2D
var props_sheet:Texture2D
var overlay:CanvasLayer
var hint:Label
var stroke:Line2D
var cut_claimed:=false
var cutter:GridPaperCutting
var prop_pixel_size:=0.0
var drawing:=false
var dragging:=false
var cut_start:=Vector2.ZERO
var drag_position:=Vector2.ZERO
var flight_start:=Vector3.ZERO
var wood_foot:=Vector3(-1.2,0,1.8)
var rock_anchor:=Vector2(.28,.65)
var bath_anchor:=Vector2(.76,.61)
var frame_bounds:Dictionary={}
func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;camera=world.camera
	wood_sheet=load("res://art/minhwa/fairy_story/woodcutter_swing.png")
	fairy_sheet=load("res://art/minhwa/fairy_story/fairy_flight.png")
	bath_sheet=load("res://art/minhwa/fairy_story/fairy_bathing.png")
	couple_sheet=load("res://art/minhwa/fairy_story/couple_ascent.png")
	props_sheet=load("res://art/minhwa/fairy_story/robe_rock.png")
	wood=_sprite("Woodcutter");rock=_sprite("RobeRock");fairy=_sprite("BathingFairy")
	robe=_sprite("CutRobe");couple=_sprite("AscendingCouple")
	robe.hide();couple.hide()
	_frame(wood,wood_sheet,2,2,0,1.65,true)
	_frame(rock,props_sheet,3,1,0,2.2)
	prop_pixel_size=rock.pixel_size
	wood.material_override.shader=preload("res://shaders/grid_woodcutter.gdshader")
	wood.material_override.render_priority=127
	_frame(fairy,bath_sheet,1,1,0,2.0)
	_frame(robe,props_sheet,3,1,2,1.4)
	blocker=StaticBody3D.new();blocker.name="WoodcutterPassageBlocker";blocker.collision_layer=1;blocker.collision_mask=2
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.45,6.0,2.0)
	shape.shape=box;shape.position.y=3.0;blocker.add_child(shape);blocker.position=wood_foot;add_child(blocker)
	overlay=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	hint=Label.new();hint.hide();hint.position=Vector2(30,76);hint.add_theme_font_size_override("font_size",19)
	hint.add_theme_color_override("font_color",Color("f3e7ce"));hint.add_theme_color_override("font_shadow_color",Color("342e26"));hint.add_theme_constant_override("shadow_offset_x",1);hint.add_theme_constant_override("shadow_offset_y",2)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color(.94,.89,.77,.94);paper.set_corner_radius_all(5)
	paper.content_margin_left=12;paper.content_margin_right=12;paper.content_margin_top=7;paper.content_margin_bottom=7
	hint.add_theme_stylebox_override("normal",paper);hint.add_theme_color_override("font_color",Color("4b493b"));hint.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var font:Font=preload("res://art/fonts/HS-Winter-Snowflake.ttf");hint.add_theme_font_override("font",font)
	world.label.add_theme_stylebox_override("normal",paper)
	world.label.add_theme_color_override("font_color",Color("4b493b"))
	world.label.add_theme_font_override("font",font)
	world.label.add_theme_font_size_override("font_size",19)
	overlay.add_child(hint)
	stroke=Line2D.new();stroke.width=2;stroke.default_color=Color("f3e7ce");overlay.add_child(stroke)
	_layout();_update_hint()
	cutter=GridPaperCutting.new();add_child(cutter)
	# Use the identical polygon clipping, rigid bodies and fresh-edge rotation as lotus paper.
	rock.offset=Vector2.ZERO
	cutter.configure(camera,[rock]);cutter.set_process_unhandled_input(false)
func _sprite(title:String) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.name=title;sprite.set_meta("story_actor",true)
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader");ink.render_priority=110
	sprite.material_override=ink;add_child(sprite);return sprite
func _frame(sprite:Sprite3D,sheet:Texture2D,cols:int,rows:int,index:int,size:float,feet:=false) -> void:
	if int(sprite.get_meta("frame_index",-1))==index and sprite.get_meta("sheet",null)==sheet:return
	var cell:=Vector2(sheet.get_size())/Vector2(cols,rows)
	var atlas:=AtlasTexture.new();atlas.atlas=sheet;atlas.region=Rect2(Vector2(index%cols,index/cols)*cell,cell)
	if sheet==wood_sheet:
		var row_start:float=0.0 if index<2 else .49
		var row_height:float=.49 if index<2 else .51
		atlas.region=Rect2((index%2)*cell.x,row_start*sheet.get_height(),cell.x,row_height*sheet.get_height());cell=atlas.region.size
	if sheet==fairy_sheet:
		var col_start:float=0.0 if index%2==0 else .52
		var col_width:float=.52 if index%2==0 else .48
		atlas.region=Rect2(col_start*sheet.get_width(),(index/2)*cell.y,col_width*sheet.get_width(),cell.y);cell=atlas.region.size
	if sheet==props_sheet:
		var edges:Array[float]=[0.0,.34,.674,1.0]
		atlas.region=Rect2(edges[index]*sheet.get_width(),0,(edges[index+1]-edges[index])*sheet.get_width(),sheet.get_height())
		cell=atlas.region.size
	var key:String=sheet.resource_path+str(index)
	if not frame_bounds.has(key):frame_bounds[key]=atlas.get_image().get_used_rect()
	var used:Rect2=Rect2(frame_bounds[key])
	sprite.texture=atlas;sprite.pixel_size=size/maxf(used.size.y,1.0)
	sprite.offset=Vector2(cell.x*.5-used.get_center().x,used.end.y-cell.y*.5 if feet else used.get_center().y-cell.y*.5)
	sprite.set_meta("ink_bounds",used)
	sprite.material_override.set_shader_parameter("illustration",sheet)
	sprite.set_meta("frame_index",index);sprite.set_meta("sheet",sheet)
func _screen_world(point:Vector2,depth:float) -> Vector3:
	return camera.project_position(point,depth)
func _anchor(normalized:Vector2,depth:=30.0) -> Vector3:
	return _screen_world(normalized*get_viewport().get_visible_rect().size,depth)
func _rect(sprite:Sprite3D) -> Rect2:
	var used:Rect2=sprite.get_meta("ink_bounds")
	var factor:float=sprite.pixel_size*get_viewport().get_visible_rect().size.y/camera.size
	var size:=used.size*factor
	var delta:=used.get_center()-Vector2(sprite.texture.get_size())*.5+Vector2(sprite.offset.x,-sprite.offset.y)
	var center:=camera.unproject_position(sprite.global_position)+delta*factor
	return Rect2(center-size*.5,size)
func _layout() -> void:
	for sprite:Sprite3D in [wood,rock,fairy,robe,couple]:sprite.global_basis=camera.global_basis
	wood.global_position=wood_foot
	rock.global_position=_anchor(rock_anchor)
	if phase<Phase.DRESSING:fairy.global_position=_anchor(bath_anchor)+camera.global_basis.y*sin(elapsed*.8)*.025
	if phase==Phase.ROBE_LOOSE:
		robe.global_position=_screen_world(drag_position,12.0) if dragging else _anchor(rock_anchor+Vector2(0,-.11),12.0)
func _update_hint() -> void:
	match phase:
		Phase.SPLITTING:hint.text="잘린 조각이 옷과 바위로 분리됩니다."
		Phase.ROBE_ON_ROCK:hint.text="선녀와 나무꾼  ·  다른 오브제처럼 옷바위를 가로질러 그어 분리하세요."
		Phase.ROBE_LOOSE:hint.text="잘라낸 날개옷을 선녀에게 드래그하세요."
		Phase.DRESSING,Phase.FLYING:hint.text="날개옷을 되찾은 선녀가 나무꾼에게 날아갑니다."
		Phase.ASCENDING:hint.text="선녀와 나무꾼이 함께 하늘로 올라갑니다."
		Phase.OPEN:hint.text="길이 열렸습니다.  ·  문양 발판 위에서 E로 올라간 뒤 Space로 건너가세요."
func _set_phase(next:Phase) -> void:
	phase=next;phase_time=0.0;_update_hint()
func try_cut(a:Vector2,b:Vector2) -> bool:
	if phase!=Phase.ROBE_ON_ROCK or world.paused or world.transition.active:return false
	var before:=cutter.pieces.size()
	cutter._cut(cutter._screen(a),cutter._screen(b))
	if cutter.pieces.size()<=before:return false
	for node in world.stage_root.find_children("*","",true,false):
		if node is GridPaperCutting:
			node.drawing=false;node.stroke.clear_points()
	_set_phase(Phase.SPLITTING)
	return true
func _finish_split() -> void:
	var bottom:=_rect(rock).end.y
	cutter.queue_free()
	_frame(rock,props_sheet,3,1,1,2.2)
	rock.pixel_size=prop_pixel_size
	rock_anchor.y+=(bottom-_rect(rock).end.y)/get_viewport().get_visible_rect().size.y
	robe.pixel_size=prop_pixel_size
	rock.show();robe.show();_set_phase(Phase.ROBE_LOOSE);_layout()
func drop_robe(point:Vector2) -> bool:
	if phase!=Phase.ROBE_LOOSE or world.paused or world.transition.active:return false
	dragging=false
	if not _rect(fairy).grow(12).has_point(point):_layout();return false
	robe.hide();flight_start=fairy.global_position
	_frame(fairy,fairy_sheet,2,2,0,1.65,true)
	_set_phase(Phase.DRESSING);return true
func _cancel_gesture() -> void:
	drawing=false
	if is_instance_valid(stroke):stroke.clear_points()
	if dragging:
		dragging=false
		_layout()
func _input(event:InputEvent) -> void:
	if world==null or world.paused or world.transition.active:
		_cancel_gesture()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if phase==Phase.ROBE_LOOSE and _rect(robe).has_point(event.position):
				BgmPlayer.play_drag()
				dragging=true;drag_position=event.position;get_viewport().set_input_as_handled()
			elif phase==Phase.ROBE_ON_ROCK:
				drawing=true;cut_start=event.position
				cut_claimed=_rect(rock).grow(15).has_point(event.position)
				if cut_claimed:get_viewport().set_input_as_handled()
		elif dragging:
			BgmPlayer.play_drop()
			drop_robe(event.position);get_viewport().set_input_as_handled()
		elif drawing:
			drawing=false;stroke.clear_points()
			if try_cut(cut_start,event.position):get_viewport().set_input_as_handled()
			elif cut_claimed:hint.text="옷바위의 윤곽을 가로질러 길게 그어주세요."
	elif event is InputEventMouseMotion:
		if dragging:drag_position=event.position;_layout();get_viewport().set_input_as_handled()
		if drawing and cut_claimed:stroke.points=PackedVector2Array([cut_start,event.position]);get_viewport().set_input_as_handled()
func _process(delta:float) -> void:
	if world==null or world.paused or world.transition.active:
		_cancel_gesture()
		return
	if phase<Phase.FLYING and absf(world.player.position.x-blocker.position.x)<2.5:
		wood_foot.z=move_toward(wood_foot.z,clampf(world.player.position.z,1.05,2.55),delta*3.5)
	elapsed+=delta;phase_time+=delta
	_layout()
	if phase<Phase.ASCENDING:
		var cycle:=fmod(elapsed,4.0)
		_frame(wood,wood_sheet,2,2,mini(int(cycle*3),3) if cycle<1.34 else 0,1.65,true)
	match phase:
		Phase.SPLITTING:
			if phase_time>=.85:_finish_split()
		Phase.DRESSING:
			if phase_time>=.65:_set_phase(Phase.FLYING)
		Phase.FLYING:
			var t:=clampf(phase_time/2.6,0,1)
			_frame(fairy,fairy_sheet,2,2,mini(1+int(t*3),3),1.65,true)
			fairy.global_position=flight_start.lerp(wood_foot,smoothstep(0,1,t))+camera.global_basis.y*sin(t*PI)*4.8
			if t>=1:
				fairy.hide();wood.hide();couple.show();_frame(couple,couple_sheet,2,2,0,1.8,true)
				couple.global_position=wood_foot
				_set_phase(Phase.ASCENDING)
		Phase.ASCENDING:
			var t:=clampf(phase_time/3.2,0,1)
			_frame(couple,couple_sheet,2,2,int(fmod(phase_time*4,4)),1.8,true)
			couple.global_position=wood_foot+camera.global_basis.y*(t*t*camera.size*1.2)+camera.global_basis.x*sin(t*PI)*.4
			couple.material_override.set_shader_parameter("opacity",1.0-smoothstep(.65,1.0,t))
			if t>=1:
				couple.hide();blocker.collision_layer=0;blocker.hide();path_open=true;_set_phase(Phase.OPEN)

func _outline_area(points:PackedVector2Array) -> float:
	var area:=0.0
	for i in points.size():area+=points[i].cross(points[(i+1)%points.size()])
	return absf(area)*.5
