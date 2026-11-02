extends Node3D
# Stage4: persistent physical paper props, drag-to-equip fans and the nose bridge.
const ART="res://art/minhwa/fan_story/"
const NPC_FOOT=Vector3(-2.8,0,.15)
const NPC_LINES=["부채를 부쳐보겠능감?"]
var world:GridStageWorld
var camera:Camera3D
var items:Dictionary={}
var ropes:Dictionary={}
var held_fan:=""
var path_open:=false
var state:="map"
var controls_camera:=false
var npc_intro:Panel
var npc_interactions:=0
var drawing:=false
var start:=Vector2.ZERO
var pointer:=Vector2.ZERO
var stroke:Line2D
var overlay:CanvasLayer
var nose:MeshInstance3D
var nose_tip:MeshInstance3D
var nose_length:=0.0
var nose_base:=Vector3.ZERO
var nose_direction:=Vector3.UP
var camera_home:=Transform3D.IDENTITY
var state_time:=0.0
var gesture_time:=0.0
var flapping_sound:AudioStreamPlayer
var emperor:Sprite3D
var brows:Sprite3D
var emperor_bubble:Panel
var lightning:Sprite3D
var bridges:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var sky_view:SubViewport
var sky_scene:Node3D
var sky_layer:CanvasLayer
var sky_panel:TextureRect
var sky_fade:=0.0
const GROWTH_CLICKS:=20
const NOSE_THICKNESS:=.32
var growth_clicks:=0
var neck_clicks:=0
var neck_length:=0.0
var body_height:=1.8
var nose_target:=0.0
var nose_step_speed:=0.0
var dragging:=""
var drag_start:=Vector2.ZERO
var drag_scale:=1.0
var drag_depth:=55.0
var drag_angle:=0.0
var drag_point:=Vector2.ZERO
var returns:Array[Dictionary]=[]
var nose_crop:=Vector4(.025,.44,.95,.15)
var severed_nose:RigidBody3D
var drag_view:SubViewport
var drag_camera:Camera3D
var drag_layer:CanvasLayer
var drag_panel:TextureRect

func configure(owner_world:GridStageWorld) -> void:
	flapping_sound=AudioStreamPlayer.new()
	var sound:AudioStreamMP3=load("res://music/flapping-4.mp3").duplicate()
	sound.loop=true;flapping_sound.stream=sound
	flapping_sound.volume_db=BgmPlayer.BASE_VOLUME_DB
	add_child(flapping_sound)
	world=owner_world;camera=world.camera;camera_home=camera.global_transform;rng.randomize()
	preload("res://scripts/grid_stage/fan_animation.gd").install(world.player.sprite.sprite_frames)
	var standing:Texture2D=world.player.sprite.sprite_frames.get_frame_texture("hold_blue",0)
	body_height=standing.get_image().get_used_rect().size.y*world.player.sprite.pixel_size
	overlay=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	stroke=Line2D.new();stroke.width=2;stroke.default_color=Color("f3e7ce");overlay.add_child(stroke)
	npc_intro=preload("res://scripts/grid_stage/speech_bubble.gd").new();overlay.add_child(npc_intro)
	emperor_bubble=preload("res://scripts/grid_stage/speech_bubble.gd").new();overlay.add_child(emperor_bubble)
	var elder:=_sprite(load(ART+"fan_elder_v1.png"),1.8)
	var used:=elder.texture.get_image().get_used_rect()
	elder.position=NPC_FOOT+camera.global_basis.y*(used.end.y-elder.texture.get_height()*.5)*elder.pixel_size
	elder.set_meta("story_actor",true);items.fan_boy={"sprite":elder}
	var cord_image:Image=load(ART+"cord_v2.png").get_image()
	var cord:=ImageTexture.create_from_image(cord_image.get_region(cord_image.get_used_rect()))
	for id:String in ["red","blue"]:
		var fan:=_sprite(load(ART+id+"_folding_v2.png"),camera.size*.30)
		fan.global_basis=camera.global_basis*Basis(Vector3.BACK,PI)
		var anchor:=Vector2(.33 if id=="red" else .12,.49)
		fan.global_position=camera.project_position(anchor*get_viewport().get_visible_rect().size,55)
		fan.set_meta("paper_color",Color("c93632") if id=="red" else Color("2868b5"))
		fan.set_meta("cuttable",false);fan.set_meta("map_occluded",true)
		var cutter:=_cutter(fan)
		# The paper drops a short distance onto its local support, like lotus cuts.
		var fan_floor:float=float(cutter.sources[0].baseline)+75.0
		_set_floor(cutter,fan_floor)
		items[id]={"sprite":fan,"cutter":cutter,"loose":false,"anchor":anchor}
		# Use the visible alpha contour, not faint transparent image padding.
		var fan_piece:Dictionary=cutter.pieces[0]
		var pivot:Vector2=fan_piece.polygon[0]
		for point:Vector2 in fan_piece.polygon:
			if point.y>pivot.y:pivot=point
		var end:Vector2=fan_piece.body.transform*pivot*get_viewport().get_visible_rect().size.y/1000.0
		var top:=Vector2(end.x,-24)
		var rope:=_sprite(cord,(end.y-top.y)*camera.size/get_viewport().get_visible_rect().size.y)
		rope.global_position=camera.project_position((top+end)*.5,55)
		# Continue the fixed cord upward beyond the map camera's ascent range.
		# A cropped shaft avoids duplicating the bottom knot at the join.
		var shaft:=AtlasTexture.new();shaft.atlas=cord
		shaft.region=Rect2(0,0,cord.get_width(),cord.get_height()*.8)
		var extension:=_sprite(shaft,shaft.get_height()*rope.pixel_size)
		extension.set_meta("story_actor",true)
		extension.global_basis=camera.global_basis*Basis.from_scale(Vector3(1,4,1))
		var extension_height:float=shaft.get_height()*rope.pixel_size*4*get_viewport().get_visible_rect().size.y/camera.size
		extension.global_position=camera.project_position(top-Vector2(0,extension_height*.5-2),55)
		# The lower endpoint is tied to the handle; it remains attached until a real cut.
		var rope_cutter:=_cutter(rope)
		# Anchor an actual interior point near the TOP of the rope silhouette.
		# Transparent padding and an off-centre painted strand must not release it.
		rope_cutter.sources[0].stem=_top_anchor(rope_cutter.pieces[0].polygon)
		_set_floor(rope_cutter,fan_floor)
		ropes[id]={"sprite":rope,"cutter":rope_cutter,"intact":true,"top":top,"end":end}
	nose=_nose_mesh();add_child(nose);nose.hide()
	nose_tip=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.17;sphere.height=.34
	nose_tip.mesh=sphere;nose_tip.material_override=nose.material_override;add_child(nose_tip);nose_tip.hide()
	emperor=_sprite(load(ART+"emperor.png"),27);emperor.hide()
	brows=_sprite(load(ART+"emperor_brows.png"),1.5);brows.hide()
	lightning=_sprite(load(ART+"lightning_coil_v2.png"),2.0);lightning.hide()
	lightning.material_override.render_priority=122
	for actor:Sprite3D in [emperor,brows,lightning]:actor.set_meta("story_actor",true)

func _sprite(texture:Texture2D,height:float) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=height/texture.get_height()
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
	ink.set_shader_parameter("illustration",texture);ink.render_priority=115;sprite.material_override=ink
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sprite);sprite.global_basis=camera.global_basis
	return sprite
func _cutter(sprite:Sprite3D) -> GridPaperCutting:
	sprite.set_meta("background_depth",55.0)
	var cutter:=GridPaperCutting.new();add_child(cutter);cutter.configure(camera,[sprite]);cutter.set_process_unhandled_input(false)
	return cutter
func _set_floor(cutter:GridPaperCutting,baseline:float) -> void:
	cutter.sources[0].baseline=baseline
	for child in cutter.simulation.get_children():
		if child is StaticBody2D:child.position.y=baseline+12
func _top_anchor(polygon:PackedVector2Array) -> Vector2:
	var top:Vector2=polygon[0]
	for point in polygon:
		if point.y<top.y:top=point
	for rise:float in [.25,.5,1.0,2.0,4.0,8.0]:
		for offset:float in [0.0,-.25,.25,-.5,.5,-1.0,1.0,-2.0,2.0]:
			var candidate:=top+Vector2(offset,rise)
			if Geometry2D.is_point_in_polygon(candidate,polygon):return candidate
	return top
func can_interact() -> bool:
	if world.paused or world.completed or world.transition.active or world.player.input_locked or state!="map":return false
	var offset:=world.player.global_position-NPC_FOOT
	return Vector2(offset.x,offset.z).length()<=1.65 and absf(offset.y)<.25 and world.player.is_on_floor()
func interact() -> bool:
	if not can_interact():return false
	if npc_intro.visible:return true
	npc_interactions+=1;npc_intro.present("부자 영감",NPC_LINES[0])
	return true
func _input(event:InputEvent) -> void:
	if world==null or world.paused or world.completed or world.transition.active or state in ["anger","strike","falling","return"]:
		if not dragging.is_empty():_cancel_drag()
		drawing=false;stroke.clear_points();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pointer=event.position
		if event.pressed:
			for id:String in ["red","blue"]:
				if world.player.input_locked or is_instance_valid(sky_view):break
				if not items[id].loose or held_fan==id or items[id].get("transit",false):continue
				var cutter:GridPaperCutting=items[id].cutter
				if not cutter._pick(cutter._screen(pointer)).is_empty():
					_begin_drag(id);get_viewport().set_input_as_handled();return
			drawing=true;start=pointer
		else:
			if not dragging.is_empty():
				_update_drag()
				BgmPlayer.play_drop()
				var id:=dragging
				if pointer.distance_to(drag_start)<=12:
					items[id].proxy.hide();items[id].sprite.set_meta("equipped",false)
					items[id].cutter.pieces[0].body.freeze=false;dragging=""
				elif _player_rect().has_point(pointer):
					dragging="";equip(id)
				else:_cancel_drag()
				get_viewport().set_input_as_handled();return
			if not drawing:return
			drawing=false;stroke.clear_points()
			if start.distance_to(pointer)>12:cut_at(start,pointer)
			else:fan()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		pointer=event.position;_update_drag();get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drawing:
		pointer=event.position
		if state=="map" and start.distance_to(pointer)>12:stroke.points=PackedVector2Array([start,pointer])
func _units(point:Vector2) -> Vector2:
	return point*1000.0/get_viewport().get_visible_rect().size.y
func _pixels(point:Vector2) -> Vector2:
	return point*get_viewport().get_visible_rect().size.y/1000.0
func _player_rect() -> Rect2:
	var foot:=camera.unproject_position(world.player.global_position)
	var scale_:float=get_viewport().get_visible_rect().size.y/camera.size
	return Rect2(foot-Vector2(.6,2.2)*scale_,Vector2(1.2,2.35)*scale_)
func _icon_point() -> Vector2:
	return _units(camera.unproject_position(world.player.global_position+camera.global_basis.y*(2.05+neck_length)))
func _icon_scale(id:String) -> float:
	return .52/(items[id].sprite.pixel_size*items[id].sprite.texture.get_height())
func _player_depth() -> float:
	return (camera.global_position-world.player.global_position).dot(camera.global_basis.z)-.1
func _proxy(id:String) -> Sprite3D:
	if is_instance_valid(items[id].get("proxy")):return items[id].proxy
	var sprite:=_sprite(items[id].sprite.texture,items[id].sprite.pixel_size*items[id].sprite.texture.get_height())
	sprite.set_meta("story_actor",true);sprite.set_meta("border_only",true)
	sprite.set_meta("paper_color",items[id].sprite.get_meta("paper_color"))
	preload("res://scripts/grid_stage/sticker_sprite.gd").install(sprite,camera)
	items[id]["proxy"]=sprite
	return sprite
func _pose_proxy(id:String,point:Vector2,ratio:float,angle:float,depth:float) -> void:
	var sprite:=_proxy(id)
	sprite.pixel_size=items[id].sprite.pixel_size*ratio
	sprite.global_basis=camera.global_basis*Basis(Vector3.BACK,angle)
	sprite.global_position=camera.project_position(_pixels(point),depth);sprite.show()
func _begin_drag(id:String) -> void:
	BgmPlayer.play_drag()
	var piece:Dictionary=items[id].cutter.pieces[0]
	items[id]["home_pose"]=piece.body.transform
	items[id].sprite.set_meta("equipped",true);piece.body.freeze=true;piece.visual.hide()
	dragging=id;drag_start=pointer;drag_scale=1;drag_depth=55;drag_angle=-piece.body.rotation
	drag_point=piece.body.position;_pose_proxy(id,drag_point,1,drag_angle,55)
	_set_drag_front(items[id].proxy,true)
	_open_drag_overlay()
func _set_drag_front(node:Node,enabled:bool) -> void:
	if node is GeometryInstance3D:
		node.set_meta("drag_front",enabled)
		node.layers=(1<<21) if enabled else 1
	for child:Node in node.get_children():_set_drag_front(child,enabled)
func _open_drag_overlay() -> void:
	if is_instance_valid(drag_view):return
	drag_view=SubViewport.new();drag_view.world_3d=get_world_3d();drag_view.transparent_bg=true
	drag_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(drag_view)
	drag_camera=Camera3D.new();drag_view.add_child(drag_camera);drag_camera.cull_mask=1<<21;drag_camera.current=true
	var environment:=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.background_color=Color(0,0,0,0);drag_camera.environment=environment
	drag_layer=CanvasLayer.new();drag_layer.layer=100;add_child(drag_layer)
	drag_panel=TextureRect.new();drag_panel.texture=drag_view.get_texture()
	drag_panel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;drag_panel.stretch_mode=TextureRect.STRETCH_SCALE
	drag_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;drag_layer.add_child(drag_panel)
	_sync_drag_overlay()
func _sync_drag_overlay() -> void:
	if not is_instance_valid(drag_view):return
	if dragging.is_empty():
		for id:String in ["red","blue"]:
			if is_instance_valid(items[id].get("proxy")):_set_drag_front(items[id].proxy,false)
		drag_layer.queue_free();drag_view.queue_free();drag_view=null;return
	drag_view.size=Vector2i(get_viewport().get_visible_rect().size);drag_panel.size=Vector2(drag_view.size)
	drag_camera.projection=camera.projection;drag_camera.size=camera.size
	drag_camera.near=camera.near;drag_camera.far=camera.far;drag_camera.global_transform=camera.global_transform
func _update_drag() -> void:
	if dragging.is_empty():return
	var target:Vector2=_units(_player_rect().get_center())
	var distance:float=_units(pointer).distance_to(target)
	var near:float=1.0-smoothstep(35.0,250.0,distance)
	drag_scale=lerpf(1.0,_icon_scale(dragging),near)
	drag_depth=lerpf(55.0,_player_depth(),near)
	drag_angle=lerp_angle(-items[dragging].home_pose.get_rotation(),0.0,near)
	drag_point=_units(pointer).lerp(_icon_point(),near*.85)
	_pose_proxy(dragging,drag_point,drag_scale,drag_angle,drag_depth)
func _cancel_drag() -> void:
	if dragging.is_empty():return
	_start_return(dragging,drag_point,drag_scale,drag_angle,drag_depth);dragging=""
func _start_return(id:String,point:Vector2,ratio:float,angle:float,depth:float) -> void:
	items[id]["transit"]=true;items[id].sprite.set_meta("equipped",true)
	returns.append({"id":id,"time":0.0,"point":point,"ratio":ratio,"angle":angle,"depth":depth})
	_pose_proxy(id,point,ratio,angle,depth)
func _advance_returns(delta:float) -> void:
	for returning in returns.duplicate():
		returning.time+=delta
		var t:float=clampf(returning.time/.7,0,1);var ease:float=smoothstep(0.0,1.0,t)
		var id:String=returning.id;var home:Transform2D=items[id].home_pose
		var destination:=home.origin-Vector2(0,24)
		var point:Vector2=returning.point.lerp(destination,ease)-Vector2(0,sin(t*PI)*35)
		_pose_proxy(id,point,lerpf(returning.ratio,1.0,ease),lerp_angle(returning.angle,-home.get_rotation(),ease),lerpf(returning.depth,55.0,ease))
		if t>=1:
			items[id].proxy.hide();items[id]["transit"]=false
			var piece:Dictionary=items[id].cutter.pieces[0]
			piece.body.transform=home;piece.body.position=destination
			piece.body.linear_velocity=Vector2.ZERO;piece.body.angular_velocity=0
			items[id].sprite.set_meta("equipped",false);piece.body.freeze=false
			returns.erase(returning)
func cut_at(a:Vector2,b:Vector2) -> bool:
	if world.paused or world.transition.active or state!="map" or a.distance_to(b)<12:return false
	var changed:=false
	for id:String in ["red","blue"]:
		if not ropes[id].intact:continue
		var cutter:GridPaperCutting=ropes[id].cutter
		var count:=cutter.pieces.size()
		cutter._cut(cutter._screen(a),cutter._screen(b))
		if cutter.pieces.size()==count:continue
		# Keep the surviving ceiling-side contour rigidly attached after every cut.
		for fragment in cutter.pieces:
			if fragment.attached:fragment.body.freeze=true;fragment.body.linear_velocity=Vector2.ZERO;fragment.body.angular_velocity=0
		ropes[id].intact=false;items[id].loose=true;changed=true
		var piece:Dictionary=items[id].cutter.pieces[0]
		piece.attached=false;piece.body.freeze=false
		piece.body.collision_layer=piece.source.layer;piece.body.collision_mask=piece.source.layer
	return changed
func equip(id:String) -> bool:
	if world.paused or world.transition.active or world.player.input_locked or not items.has(id) or not items[id].get("loose",false) or items[id].get("transit",false):return false
	if held_fan==id:return true
	if not held_fan.is_empty():
		_start_return(held_fan,_icon_point(),_icon_scale(held_fan),0,_player_depth())
	if not items[id].has("home_pose"):items[id]["home_pose"]=items[id].cutter.pieces[0].body.transform
	if is_instance_valid(items[id].get("proxy")):items[id].proxy.hide()
	held_fan=id;items[id].sprite.set_meta("equipped",true)
	world.player.set_held_fan(id)
	return true
func fan() -> bool:
	if held_fan.is_empty() or world.paused or world.transition.active or state not in ["map","growing","shrinking"]:return false
	world.player.set_fan_gesture(held_fan);gesture_time=.35
	if not flapping_sound.playing:flapping_sound.play()
	if held_fan=="blue":
		neck_clicks=mini(neck_clicks+1,GROWTH_CLICKS)
		return true
	if path_open:return true
	if not controls_camera:camera_home=camera.global_transform
	world.player.input_locked=growth_clicks+1>=8
	controls_camera=world.player.input_locked
	state="growing" if held_fan=="red" else "shrinking"
	growth_clicks=clampi(growth_clicks+(1 if held_fan=="red" else -1),0,GROWTH_CLICKS)
	var progress:=float(growth_clicks)/GROWTH_CLICKS
	nose_target=18.0*(.15*progress+.85*pow(progress,3))
	nose_step_speed=maxf(.1,absf(nose_target-nose_length)/.24)
	nose_base=world.player.global_position+camera.global_basis.y*(1.27+neck_length)+camera.global_basis.x*.03
	# Camera-plane axes keep the visible growth line at exactly 45 degrees.
	nose_direction=(camera.global_basis.x+camera.global_basis.y).normalized()
	# Place the huge portrait in the world before ascent. The travelling camera
	# reveals its lower robe first, then torso and finally the face at the tip.
	emperor.position=nose_base+nose_direction*18+camera.global_basis.x*2-camera.global_basis.y*8.8
	brows.position=emperor.position+camera.global_basis.y*9.3+camera.global_basis.z*.1
	return true
func _nose_mesh() -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE;mesh.mesh=quad
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_nose.gdshader");ink.render_priority=120
	var texture:Texture2D=load(ART+"long_nose_v2.png")
	var image:=texture.get_image();var mask:=BitMap.new();mask.create_from_image_alpha(image,.12)
	var bounds:=Rect2()
	for contour:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),2):
		var rect:=Rect2(contour[0],Vector2.ZERO)
		for point in contour:rect=rect.expand(point)
		if rect.size.x>bounds.size.x:bounds=rect
	nose_crop=Vector4(bounds.position.x/image.get_width(),bounds.position.y/image.get_height(),bounds.size.x/image.get_width(),bounds.size.y/image.get_height())
	ink.set_shader_parameter("illustration",texture);ink.set_shader_parameter("crop",nose_crop)
	mesh.material_override=ink
	mesh.set_meta("story_actor",true)
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
func _update_nose() -> void:
	nose.visible=nose_length>.02;nose_tip.hide()
	nose.position=nose_base+nose_direction*nose_length*.5
	nose.basis=camera.global_basis*Basis(Vector3.BACK,PI*.25)*Basis.from_scale(Vector3(maxf(.01,nose_length),NOSE_THICKNESS,1))
	nose.material_override.set_shader_parameter("reveal",nose_length/18.0)
	nose.material_override.set_shader_parameter("tip_fraction",clampf(.28/maxf(nose_length,.01),.015,.8))
	nose_tip.position=nose_base+nose_direction*nose_length
func _physics_process(delta:float) -> void:
	if world==null:return
	flapping_sound.stream_paused=world.paused or world.transition.active
	if world.paused or world.transition.active:return
	if world.completed:return
	_advance_returns(delta)
	neck_length=move_toward(neck_length,neck_clicks*body_height*.1,delta*body_height)
	world.player.set_neck_length(neck_length)
	state_time+=delta
	if gesture_time>0:
		gesture_time-=delta
		if gesture_time<=0:world.player.set_fan_gesture("")
	if state=="growing" or state=="shrinking":
		nose_base=world.player.global_position+camera.global_basis.y*(1.27+neck_length)+camera.global_basis.x*.03
		nose_length=move_toward(nose_length,nose_target,nose_step_speed*delta)
		_update_nose()
		if nose_length>=4 and not is_instance_valid(sky_view):_enter_sky()
		var target:=camera_home.origin+nose_direction*nose_length
		if controls_camera:camera.position=camera.position.lerp(target,1-exp(-3.5*delta))
		if nose_length>=18:_anger()
		elif nose_length<=0 and state=="shrinking":state="return";state_time=0
	elif state=="anger":
		if state_time>=3.8:
			state="strike";state_time=0;lightning.show()
			BgmPlayer.play_thunder()
	elif state=="strike":
		var cut_focus:=camera_home.origin+nose_direction*nose_length*.55
		camera.position=camera.position.lerp(cut_focus,1-exp(-5*delta))
		lightning.visible=state_time<1.65
		sky_scene.set_storm_flash((.5+.5*sin(state_time*45))*clampf(1.0-state_time/1.8,0,1))
		var tighten:=smoothstep(0.0,.85,state_time)
		lightning.global_basis=camera.global_basis*Basis(Vector3.BACK,PI*.25+sin(state_time*18)*.04)*Basis.from_scale(Vector3(1,lerpf(1.5,.65,tighten),1))
		lightning.material_override.set_shader_parameter("opacity",clampf(state_time/.2,0,1)*(.8+.2*sin(state_time*45)))
		if state_time>=.85 and not is_instance_valid(severed_nose):_sever_nose()
		if state_time>=2.4:
			lightning.hide();nose.hide();nose_tip.hide();nose_length=0
			_close_sky()
			_drop_bridges();state="falling";state_time=0
	elif state=="falling":
		camera.position=camera.position.lerp(camera_home.origin,1-exp(-2.2*delta))
		var settled:=true
		for bridge in bridges:
			var body:RigidBody3D=bridge.body
			if not body.freeze:
				if body.get_contact_count()>0 and body.linear_velocity.length()<.2:
					body.freeze=true;bridge["settled"]=true
				else:settled=false
		if settled:state="return";state_time=0;path_open=true
	elif state=="return":
		camera.position=camera.position.lerp(camera_home.origin,1-exp(-4*delta))
		if camera.position.distance_to(camera_home.origin)<.03:
			_close_sky()
			camera.global_transform=camera_home;controls_camera=false;state="map"
			world.player.input_locked=false;world.player.set_fan_gesture("");emperor.hide();brows.hide();emperor_bubble.close()
func _anger() -> void:
	flapping_sound.stop()
	state="anger";state_time=0;world.player.set_fan_gesture("")
	emperor.show();brows.show()
	lightning.position=nose_base+nose_direction*nose_length*.55+camera.global_basis.z*.15
	emperor_bubble.present("옥황상제","네 놈의 코가 하늘을 찌르는구나!")
func _sever_nose() -> void:
	nose.material_override.set_shader_parameter("sever",.55)
	nose.material_override.set_shader_parameter("end_u",.55)
	severed_nose=RigidBody3D.new();severed_nose.name="FallingNoseTip"
	severed_nose.collision_layer=0;severed_nose.collision_mask=0
	severed_nose.gravity_scale=1;severed_nose.linear_damp=.1
	sky_scene.add_child(severed_nose)
	severed_nose.position=nose_base+nose_direction*nose_length*.775
	severed_nose.linear_velocity=camera.global_basis.x*.8+camera.global_basis.y*.5
	severed_nose.angular_velocity=camera.global_basis.z*(-.65)
	var visual:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(nose_length*.45,NOSE_THICKNESS);visual.mesh=quad
	var ink:ShaderMaterial=nose.material_override.duplicate()
	ink.set_shader_parameter("sever",-1.0);ink.set_shader_parameter("end_u",1.0)
	ink.set_shader_parameter("crop",Vector4(nose_crop.x+nose_crop.z*.55,nose_crop.y,nose_crop.z*.45,nose_crop.w))
	ink.set_shader_parameter("reveal",1.0);ink.set_shader_parameter("tip_fraction",.035)
	visual.material_override=ink;severed_nose.add_child(visual)
	visual.basis=camera.global_basis*Basis(Vector3.BACK,PI*.25)
func _enter_sky() -> void:
	sky_view=SubViewport.new();sky_view.own_world_3d=true
	sky_view.size=Vector2i(get_viewport().get_visible_rect().size)
	sky_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(sky_view)
	sky_scene=preload("res://scenes/grid_stage/fan_sky.tscn").instantiate()
	sky_view.add_child(sky_scene);sky_scene.configure(camera)
	for actor:Node3D in [nose,nose_tip,emperor,brows,lightning]:actor.reparent(sky_scene,true)
	emperor_bubble.reparent(sky_scene.ui,false);emperor.show()
	sky_layer=CanvasLayer.new();sky_layer.layer=4;add_child(sky_layer)
	sky_panel=TextureRect.new();sky_panel.texture=sky_view.get_texture()
	sky_panel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sky_panel.stretch_mode=TextureRect.STRETCH_SCALE
	sky_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;sky_panel.size=get_viewport().get_visible_rect().size
	sky_panel.modulate.a=0;sky_layer.add_child(sky_panel);sky_fade=0
func _close_sky() -> void:
	if not is_instance_valid(sky_view):return
	for actor:Node3D in [nose,nose_tip,emperor,brows,lightning]:actor.reparent(self,true);actor.hide()
	emperor_bubble.reparent(overlay,false);emperor_bubble.close()
	sky_layer.queue_free();sky_view.queue_free()
	sky_layer=null;sky_view=null;sky_scene=null;sky_panel=null
	severed_nose=null
func _drop_bridges() -> void:
	# Physical severed lengths land on the existing slabs as two sloping walkways.
	for endpoints:Array in world.stage_data.nose_bridges:
		var a:Vector3=endpoints[0];var b:Vector3=endpoints[1]
		var axis:Vector3=(b-a).normalized();var side:=axis.cross(Vector3.UP).normalized()*NOSE_THICKNESS*.5
		var body:=RigidBody3D.new();body.name="SeveredNoseBridge";body.collision_layer=1;body.collision_mask=1
		body.lock_rotation=true;body.axis_lock_linear_x=true;body.axis_lock_linear_z=true
		body.contact_monitor=true;body.max_contacts_reported=8;body.linear_damp=.2
		var material:=PhysicsMaterial.new();material.friction=1;material.bounce=0;body.physics_material_override=material
		var center:Vector3=(a+b)*.5
		add_child(body);body.position=center+Vector3.UP*8
		# A tapered broken end meets the lower slab without an unwalkable box lip.
		var points:=PackedVector3Array([a-side-center,a+side-center,b-side-center,b+side-center,b-side-center-Vector3.UP*.15,b+side-center-Vector3.UP*.15])
		var collision_points:=PackedVector3Array()
		var lateral:Vector3=side.normalized()
		for point:Vector3 in points:collision_points.append(point+lateral*point.dot(lateral)*1.5)
		var shape:=ConvexPolygonShape3D.new();shape.points=collision_points
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index:int in [0,1,2,1,3,2,0,4,1,1,4,5,0,2,4,1,5,3,2,3,4,3,5,4]:
			# The source nose runs horizontally: U follows each bridge's length.
			surface.set_uv(Vector2(0.0 if index<2 else 1.0,float(index%2)));surface.add_vertex(points[index])
		surface.generate_normals()
		var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var texture:Texture2D=load(ART+"long_nose_v2.png")
		var fragment:=AtlasTexture.new();fragment.atlas=texture
		var first:bool=bridges.is_empty()
		# Crop the corresponding length at the original nose's pixel scale.
		# Keep the original thickness; do not stretch half an image into a bridge.
		var fraction:float=a.distance_to(b)/18.0
		fragment.region=Rect2((nose_crop.x+nose_crop.z*(0.0 if first else 1.0-fraction))*texture.get_width(),nose_crop.y*texture.get_height(),nose_crop.z*fraction*texture.get_width(),nose_crop.w*texture.get_height())
		ink.albedo_texture=ImageTexture.create_from_image(fragment.get_image());ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		var visual:=MeshInstance3D.new();visual.mesh=surface.commit();visual.material_override=ink;body.add_child(visual)
		bridges.append({"body":body,"a":a,"b":b})
func _process(_delta:float) -> void:
	if world==null:return
	_sync_drag_overlay()
	if is_instance_valid(severed_nose):severed_nose.freeze=world.paused
	if is_instance_valid(sky_scene):
		sky_scene.sync(camera,world.paused)
		var frame:=get_viewport().get_visible_rect().size
		sky_view.size=Vector2i(frame);sky_panel.size=frame
		if not world.paused:sky_fade=minf(1,sky_fade+_delta*2.5)
		sky_panel.modulate.a=sky_fade
	npc_intro.blocked=world.paused;emperor_bubble.blocked=world.paused
	npc_intro.place(camera.unproject_position(NPC_FOOT+Vector3.UP*1.92))
	emperor_bubble.place(camera.unproject_position(emperor.position+camera.global_basis.y*10.3))
	for bridge in bridges:bridge.body.freeze=world.paused or bool(bridge.get("settled",false))
func respawn() -> void:
	flapping_sound.stop()
	# Falls never reset severed ropes, fan bodies, inventory or completed bridges.
	_cancel_drag()
	world.player.position=world.start_position;world.player.velocity=Vector3.ZERO
	world.player.input_locked=false;world.player.set_fan_gesture("")
	_close_sky()
	camera.global_transform=camera_home;controls_camera=false
	if state in ["growing","shrinking"]:state="map";nose_length=0;nose_target=0;growth_clicks=0;_update_nose()
