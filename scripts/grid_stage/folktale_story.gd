extends Node3D
# Supplied stories only: red/blue fans (4), the mouse (5), and the bridge of birds (8).
var world:GridStageWorld
var camera:Camera3D
var number:=0
var path_open:=false
var items:Dictionary={}
var targets:Dictionary={}
var labels:Dictionary={}
var bridges:Dictionary={}
var overlay:CanvasLayer
var hint:Label
var stroke:Line2D
var drawing:=false
var start:=Vector2.ZERO
var dragging:=""
var pointer:=Vector2.ZERO
var grab_offset:=Vector2.ZERO
var base_camera:=Vector3.ZERO
var fan_step:=0
var mouse_step:=0
enum BirdPhase { CUTTING, CROSSING, FADING, RETURNING, TALKED }
var bird_step:=BirdPhase.CUTTING
const CHART_TURN_SECONDS:=180.0
const COUPLE_FADE_SECONDS:=1.0
var chart_angle:=0.0
var chart_spinning:=false
# Verbatim speech from the two supplied map-layout screenshots; do not add hint lines.
const PHOTO_DIALOGUE:={
	"crow_npc":"옥황상제의 미움을 받아\n떨어져 지내게 된 남녀가 있다지",
	"magpie_npc":"보기가 안쓰러워\n다리라도 놓이면 좋으련만",
	"couple":"다음 칠석날까지 당신을\n잊지 않을게요"
}
var speech_bubbles:Dictionary={}
var speech_overlay:CanvasLayer
const SPEECH_UI=preload("res://scripts/grid_stage/npc_speech_bubble.gd")
const SPEECH_DISPLAY_SECONDS:=3.0
const SPEECH_FADE_SECONDS:=.8
var timer:=0.0
var bridge_failures:=0
var hint_index:=0
var red_blocks:Array[StaticBody3D]=[]
var falling_blocks:Array[StaticBody3D]=[]
var routes:Array[Array]=[]
const BIRD_ART:="res://art/minhwa/gyonwu_v2/"
const PROP:="res://art/story_props/"
const FAN:="res://stages/4-빨강파랑부채/"
const MOUSE:="res://stages/5-손톱/"
const BIRDS:="res://stages/8-견우와직녀/"

func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;camera=world.camera;number=world.stage_number-3;base_camera=camera.position
	for candidate in world.rune_candidates:candidate.enabled=false
	overlay=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	hint=Label.new();hint.hide();hint.position=Vector2(30,76);hint.add_theme_font_size_override("font_size",18)
	var font:Font=preload("res://art/fonts/HS-Winter-Snowflake.ttf");hint.add_theme_font_override("font",font)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("f3e7ce");paper.set_corner_radius_all(5)
	paper.content_margin_left=12;paper.content_margin_right=12;paper.content_margin_top=8;paper.content_margin_bottom=8
	# Stage8 uses NPC speech bubbles; do not draw a screen-wide instruction panel.
	if number!=8:
		hint.add_theme_stylebox_override("normal",paper)
		world.label.add_theme_stylebox_override("normal",paper)
	hint.hide()
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color",Color("4b493b"));overlay.add_child(hint)
	if number!=8:
		world.label.add_theme_font_override("font",font)
		world.label.add_theme_font_size_override("font_size",18);world.label.add_theme_color_override("font_color",Color("4b493b"))
	stroke=Line2D.new();stroke.width=2;stroke.default_color=Color("f3e7ce");overlay.add_child(stroke)
	match number:
		4:_setup_fans()
		5:_setup_mouse()
		8:_setup_birds()
	_layout()

func _texture(path:String) -> Texture2D:
	return load(path)

func _picture(id:String,texture:Texture2D,position:Vector3,height:float,cuttable:=false,loose:=false,anchor:=Vector2(-1,-1)) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.name=id;sprite.texture=texture
	sprite.set_meta("story_actor",true);sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader");ink.render_priority=115
	# Mesh UVs and shader sampler refer to the same isolated image.
	if texture is AtlasTexture:sprite.texture=ImageTexture.create_from_image(texture.get_image())
	ink.set_shader_parameter("illustration",sprite.texture);sprite.material_override=ink
	sprite.pixel_size=height/maxf(1,sprite.texture.get_height())
	add_child(sprite);sprite.position=position;sprite.global_basis=camera.global_basis
	if anchor.x>=0:sprite.global_position=camera.project_position(anchor*get_viewport().get_visible_rect().size,20)
	var entry:Dictionary={"sprite":sprite,"home":sprite.position,"anchor":anchor,"cuttable":cuttable,"loose":loose,"used":false,"delay":-1.0,"cutter":null}
	items[id]=entry
	if cuttable or loose:preload("res://scripts/grid_stage/sticker_sprite.gd").install(sprite,camera)
	if cuttable:
		var cutter:=GridPaperCutting.new();add_child(cutter)
		if number==8:sprite.set_meta("triangle_cut_collision",true)
		sprite.set_meta("background_depth",20.0)
		cutter.configure(camera,[sprite]);cutter.set_process_unhandled_input(false)
		entry.cutter=cutter
	return sprite

func _target(id:String,position:Vector3,text:="") -> void:
	if number==8:
		# An empty spatial anchor keeps placement working without any hint or painted marker.
		var slot:=Node3D.new();slot.name="BirdDropSlot_"+id
		add_child(slot);slot.position=position;targets[id]=slot
		return
	var sprite:=_picture("target_"+id,_texture(PROP+"target.svg"),position,1.0)
	targets[id]=sprite
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("fff0d0"))
	label.add_theme_color_override("font_outline_color",Color("3e3831"));label.add_theme_constant_override("outline_size",5)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(label);labels[id]=label

func _setup_fans() -> void:
	_picture("red",_texture(PROP+"red_fan.svg"),Vector3.ZERO,2,true,false,Vector2(.16,.72))
	_picture("blue",_texture(PROP+"blue_fan.svg"),Vector3.ZERO,2,true,false,Vector2(.84,.72))
	var emperor:=_picture("emperor",_texture(FAN+"remove_background-6.png"),Vector3(6,6,-3)+camera.global_basis.x*2,15)
	var brows:=_picture("brows",_texture(PROP+"angry_brows.svg"),emperor.position+camera.global_basis.y*4.5+camera.global_basis.z*.05,1.2)
	brows.hide()
	_target("red",world.rune_candidates[0].body.position+Vector3.UP*.2,"빨강 부채")
	_target("blue",world.rune_candidates[1].body.position+Vector3.UP*.2,"O · 파랑 부채")
	for x in [2.6,3.2,3.8]:
		var block:=_solid_box(Vector3(x,10.5,-.35),Vector3(.55,3,.5),Color("b65c56"))
		red_blocks.append(block)
	hint.text="부채를 기본 자르기로 떼어내세요. 빨강 부채를 첫 발판에 붙이고 올라타세요."

func _setup_mouse() -> void:
	camera.size=16.6
	routes=[[Vector3(0,0,1.2),Vector3(0,1.8,-1.2)],[Vector3(-.4,1.8,-2.4),Vector3(-2.8,3.6,-2.4)]]
	_picture("bridge",_texture(PROP+"bridge.svg"),Vector3.ZERO,1.8,true,false,Vector2(.15,.74))
	_picture("roof",_texture(MOUSE+"주막.png"),Vector3(3.3,3.2,-2.3),2.7,true)
	_picture("beauty",_texture(MOUSE+"미인.png"),Vector3(-3.3,4.5,-3.1),1.7,false,true)
	_picture("cat",_texture(MOUSE+"고양이.png"),Vector3(3.3,4.9,-2.3),1.2)
	_picture("uncle",_texture(MOUSE+"주막 옆 아저씨.png"),Vector3(1,2.5,-1),1.5)
	_picture("table",_texture(MOUSE+"술상.png"),Vector3(1.6,2.1,-1.8),1)
	var frame:Texture2D=world.player.sprite.sprite_frames.get_frame_texture("idle_southeast",0)
	_picture("impostor",frame,Vector3(.3,2.5,-1.6),1.7)
	var mouse:=_picture("mouse",_texture(MOUSE+"손톱먹은쥐.png"),Vector3(1.7,2.3,-1.9),.9)
	mouse.hide()
	_target("bridge",Vector3(0,1,.1),"다리")
	_target("beauty",Vector3(1.5,2.6,-1.6),"주막 옆")
	_target("cat",Vector3(2.2,2.2,-1.3),"고양이 디딤돌")
	hint.text="다리를 잘라 붙여보세요. 가짜가 방해한다면 미인을 주막 옆으로 옮겨보세요. 아저씨 근처 E: 힌트"

func _setup_birds() -> void:
	routes.assign(world.stage_data.bird_bridges)
	# Add the supplied chart and branches to the existing sky backdrop.
	var chart_source:=_texture(BIRDS+"remove_background-5.png")
	var chart_region:=AtlasTexture.new();chart_region.atlas=chart_source
	chart_region.region=Rect2(12,158,820,820)
	# This paper lies below the authored column bottoms, in the world's XZ floor plane.
	var floor_center:=Vector3(world.stage_data.focus.x,-1.2,world.stage_data.focus.z)
	var chart:=_picture("star_chart",chart_region,floor_center,camera.size*1.32)
	chart.material_override.render_priority=-64
	for side:int in range(2):
		var id:="chart_branches_%d"%side
		# Keep the original picture height; reserve the outer edges for noninteractive birds.
		var branches:=_picture(id,_texture(BIRDS+"background_birds.png"),Vector3.ZERO,camera.size*.95,false,false,Vector2(0.0 if side==0 else 1.01,.45))
		branches.material_override.render_priority=-32
		items[id]["depth"]=55.0
	_picture("crow",_texture(BIRD_ART+"crow.png"),Vector3.ZERO,5.6,true,false,Vector2(.33,.12))
	_picture("magpie",_texture(BIRD_ART+"magpie.png"),Vector3.ZERO,6.0,true,false,Vector2(.70,.20))
	var center:Vector3=(routes[0][0]+routes[0][1])*.5+Vector3.UP*.15
	_target("crow",center+Vector3.LEFT*.4)
	_target("magpie",center+Vector3.RIGHT*.4)
	var original:=AtlasTexture.new();original.atlas=_texture(BIRDS+"Unknown.png")
	# The original silhouette occupies these source pixels; remove transparent margins only.
	original.region=Rect2(560,270,470,430)
	var feet:Vector3=routes[0][0].lerp(routes[0][1],.3)+Vector3.RIGHT*.25
	var couple:=_picture("couple",original,feet+camera.global_basis.y*.9,1.8)
	items.couple["feet"]=feet
	couple.hide()
	_create_dialogue("couple")
	_setup_bird_npcs()
	hint.text="발판에 올라타면 자동으로 올라갑니다. 까마귀와 까치를 잘라 위쪽 끊어진 곳에 둘 다 붙이세요."

func _setup_bird_npcs() -> void:
	var sources:=["remove_background.png","remove_background-3.png"]
	var regions:=[Rect2(0,8,512,300),Rect2(72,104,352,280)]
	for i:int in range(2):
		var id:String="crow_npc" if i==0 else "magpie_npc"
		var original:=AtlasTexture.new();original.atlas=_texture(BIRDS+sources[i]);original.region=regions[i]
		var feet:=Vector3(-2.4 if i==0 else 2.4,1.8,0)
		_picture(id,original,feet+camera.global_basis.y*.9,1.8)
		items[id]["feet"]=feet;items[id]["height"]=1.8
		_create_dialogue(id)

func _create_dialogue(actor:String) -> void:
	if not is_instance_valid(speech_overlay):
		speech_overlay=CanvasLayer.new();speech_overlay.layer=8;add_child(speech_overlay)
	var speech:=SPEECH_UI.new();speech_overlay.add_child(speech)
	var dimensions:=Vector2(360,140) if actor=="crow_npc" else Vector2(320,110)
	speech.configure(world.stage_intro.title.get_theme_font("font"),dimensions);speech.hide()
	speech_bubbles[actor]={"panel":speech,"label":speech.line,"active":false,"elapsed":0.0}

func _layout_dialogue() -> void:
	for actor:String in speech_bubbles:
		var bubble:Dictionary=speech_bubbles[actor]
		var panel:Control=bubble.panel
		var sprite:Sprite3D=items[actor].sprite
		var head:Vector3=sprite.global_position+camera.global_basis.y*(float(items[actor].get("height",1.8))*.5+.05)
		panel.position=camera.unproject_position(head)-Vector2(panel.size.x*.5,panel.size.y)+Vector2(0,-minf(float(bubble.elapsed)/.25,1)*5)
		panel.visible=bool(bubble.active) and sprite.visible and not camera.is_position_behind(head) and not world.transition.active

func _advance_dialogue(delta:float) -> void:
	for actor:String in speech_bubbles:
		var bubble:Dictionary=speech_bubbles[actor]
		if not bubble.active:continue
		bubble.elapsed+=delta
		bubble.panel.modulate.a=minf(float(bubble.elapsed)/.18,1.0)*(1.0-clampf((float(bubble.elapsed)-SPEECH_DISPLAY_SECONDS)/SPEECH_FADE_SECONDS,0,1))
		if bubble.elapsed>=SPEECH_DISPLAY_SECONDS+SPEECH_FADE_SECONDS:
			bubble.active=false;bubble.panel.hide()

func cancel_dialogue() -> void:
	for actor:String in speech_bubbles:
		var bubble:Dictionary=speech_bubbles[actor]
		bubble.active=false;bubble.elapsed=0.0;bubble.panel.hide()

func interaction_target() -> Node3D:
	if number!=8 or _interaction_locked():return null
	var actor:=_nearest_speaker()
	return null if actor.is_empty() else items[actor].sprite

func interaction_anchor(target:Node3D) -> Vector3:
	var actor:=String(target.name)
	return target.global_position+camera.global_basis.y*(float(items[actor].get("height",1.8))*.5+.05)

func is_speaking(target:Node3D) -> bool:
	return bool(speech_bubbles[String(target.name)].active)

func _nearest_speaker() -> String:
	if not world.player.is_on_floor():return ""
	var actor:="";var distance:=1.5
	for id:String in speech_bubbles:
		if id=="couple" and bird_step not in [BirdPhase.RETURNING,BirdPhase.TALKED]:continue
		var candidate_distance:float=world.player.position.distance_to(items[id].feet)
		if items[id].sprite.visible and candidate_distance<distance:actor=id;distance=candidate_distance
	return actor

func _solid_box(position:Vector3,size:Vector3,color:Color) -> StaticBody3D:
	return preload("res://scripts/grid_stage/story_geometry.gd").box(self,position,size,color,number!=8)

func _build_bridge(index:int) -> void:
	if bridges.has(index):return
	var a:Vector3=routes[index][0];var b:Vector3=routes[index][1]
	# End at the terrace edge at exactly its height. An overshooting ramp
	# creates a raised lip that blocks the required return trip.
	var approach:=a-b;approach.y=0
	if number!=8:b+=approach.normalized()*.2
	var direction:Vector3=(b-a).normalized()
	var right:Vector3=direction.cross(Vector3.UP).normalized()
	var up:Vector3=right.cross(direction).normalized()
	var bridge:=_solid_box((a+b)*.5-up*.09,Vector3(1.25,.18,a.distance_to(b)),Color("c3b58a"))
	bridge.basis=Basis(right,up,-direction)
	bridge.name="StoryBridge%d"%index;bridges[index]=bridge
	if number==8:
		# Three flat painted bird ribbons cover the walkable width without stretching birds.
		var sheet:=_texture(BIRD_ART+"ojak_bridge.png")
		var region:=AtlasTexture.new();region.atlas=sheet
		region.region=Rect2(0,sheet.get_height()*.22,sheet.get_width(),sheet.get_height()*.51)
		var length:=a.distance_to(b)+.28
		for lane in range(3):
			var id:="ojak_span_%d_%d"%[index,lane]
			var art:=_picture(id,region,(a+b)*.5+up*.018+right*(lane-1)*.36,length*region.get_height()/region.get_width())
			art.basis=Basis(direction,-right,up)
			items[id]["fixed_basis"]=art.basis
		return
	var seam_ink:=StandardMaterial3D.new();seam_ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;seam_ink.albedo_color=Color("857451")
	for i in range(1,9):
		var seam:=MeshInstance3D.new();var plank:=BoxMesh.new();plank.size=Vector3(1.23,.008,.025)
		seam.mesh=plank;seam.material_override=seam_ink;bridge.add_child(seam)
		seam.position=Vector3(0,.094,lerpf(-a.distance_to(b)*.5,a.distance_to(b)*.5,i/9.0))
func _rect(sprite:Sprite3D) -> Rect2:
	var image_size:=Vector2(sprite.texture.get_size())
	var used:Rect2=Rect2(sprite.texture.get_image().get_used_rect())
	var factor:float=sprite.pixel_size*get_viewport().get_visible_rect().size.y/camera.size
	var center:Vector2=camera.unproject_position(sprite.global_position)+(used.get_center()-image_size*.5)*factor
	return Rect2(center-used.size*factor*.5,used.size*factor)

func _drop_rect(id:String) -> Rect2:
	if number!=8:return _rect(targets[id])
	var center:=camera.unproject_position(targets[id].global_position)
	var size:=Vector2.ONE*.9*get_viewport().get_visible_rect().size.y/camera.size
	return Rect2(center-size*.5,size)

func _layout() -> void:
	for id:String in items:
		var item:Dictionary=items[id];var sprite:Sprite3D=item.sprite
		if item.get("managed_pose",false):continue
		if item.has("fixed_basis"):sprite.basis=item.fixed_basis
		else:sprite.global_basis=camera.global_basis
		if id=="star_chart":
			# Rotate within the floor plane, preserving the ellipse/tilt seen by the fixed camera.
			sprite.global_basis=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)*Basis(Vector3.BACK,deg_to_rad(-12)+chart_angle)
			sprite.pixel_size=minf(camera.size*1.32,camera.size*get_viewport().get_visible_rect().size.aspect()*.82)/sprite.texture.get_height()
		if id==dragging:sprite.global_position=camera.project_position(pointer+grab_offset,3)
		elif item.anchor.x>=0:sprite.global_position=camera.project_position(item.anchor*get_viewport().get_visible_rect().size,float(item.get("depth",20.0)))
	if number==4:
		for i in range(2):targets["red" if i==0 else "blue"].global_position=world.rune_candidates[i].body.global_position+Vector3.UP*.2
	for id:String in labels:
		var sprite:Sprite3D=targets[id];var label:Label=labels[id]
		label.visible=sprite.visible and not camera.is_position_behind(sprite.global_position)
		label.position=camera.unproject_position(sprite.global_position)+Vector2(-label.size.x*.5,24)
	if number==8:_layout_dialogue()

func _cancel() -> void:
	drawing=false;stroke.clear_points()
	if not dragging.is_empty():
		var item:Dictionary=items[dragging];item.sprite.position=item.home
		dragging="";_layout()

func _interaction_locked() -> bool:
	return world==null or world.paused or world.transition.active or world.completed or world.player.input_locked

func _input(event:InputEvent) -> void:
	if _interaction_locked():_cancel();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pointer=event.position
		if event.pressed:
			for id:String in items:
				var item:Dictionary=items[id]
				if not event.shift_pressed and item.loose and not item.used and item.sprite.visible and _rect(item.sprite).has_point(pointer):
					dragging=id;grab_offset=camera.unproject_position(item.sprite.global_position)-pointer
					BgmPlayer.play_drag()
					get_viewport().set_input_as_handled();return
			drawing=true;start=pointer
		else:
			if not dragging.is_empty():
				BgmPlayer.play_drop()
				var id:=dragging;dragging=""
				var delivered:=false
				# Prefer the matching slot when the two nearby bird targets overlap on screen.
				var delivery_targets:Array=targets.keys()
				if targets.has(id):delivery_targets.erase(id);delivery_targets.push_front(id)
				for target:String in delivery_targets:
					if targets[target].visible and _drop_rect(target).grow(18).has_point(pointer):
						delivered=drop_item(id,target);break
				if not delivered:
					items[id].sprite.position=items[id].home
					hint.text="여기에는 놓을 수 없습니다. 표시된 자리로 옮겨주세요."
				_layout();get_viewport().set_input_as_handled()
			elif drawing:
				drawing=false;stroke.clear_points()
				if cut_at(start,pointer):get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		pointer=event.position
		if not dragging.is_empty():_layout();get_viewport().set_input_as_handled()
		elif drawing:stroke.points=PackedVector2Array([start,pointer])

func cut_at(a:Vector2,b:Vector2) -> bool:
	if _interaction_locked():return false
	var changed:=false
	for id:String in items:
		var item:Dictionary=items[id]
		if not item.cuttable or item.used or item.delay>=0:continue
		var cutter:GridPaperCutting=item.cutter
		if not is_instance_valid(cutter):continue
		var before:=cutter.pieces.size()
		cutter._cut(cutter._screen(a),cutter._screen(b))
		if cutter.pieces.size()>before:
			item.cuttable=false;item.delay=0.0;changed=true
	if changed:
		for node in world.stage_root.find_children("*","",true,false):
			if node is GridPaperCutting:node.drawing=false;node.stroke.clear_points()
		hint.text="잘린 조각을 표시된 자리로 옮겨주세요."
	return changed

func _resolve_piece(id:String) -> void:
	var item:Dictionary=items[id];item.cutter.queue_free();item.delay=-1.0;item.loose=true
	if id=="bridge" and bridge_failures>0 and mouse_step==0:item.anchor=Vector2(.83,.78)
	if id=="roof":
		var full:Texture2D=item.sprite.texture
		var region:=AtlasTexture.new();region.atlas=full;region.region=Rect2(0,0,full.get_width(),full.get_height()*.53)
		var body_region:=AtlasTexture.new();body_region.atlas=full;body_region.region=Rect2(0,full.get_height()*.53,full.get_width(),full.get_height()*.47)
		var pixel:float=item.sprite.pixel_size
		var body:=_picture("inn_body",body_region,item.home-camera.global_basis.y*full.get_height()*.265*pixel,full.get_height()*.47*pixel)
		body.pixel_size=pixel
		item.sprite.texture=ImageTexture.create_from_image(region.get_image())
		item.sprite.material_override.set_shader_parameter("illustration",item.sprite.texture)
		item.home+=camera.global_basis.y*full.get_height()*.235*pixel
		item.sprite.position=item.home
	item.sprite.show()

func _consume(id:String,target:String) -> void:
	var item:Dictionary=items[id];item.used=true;item.sprite.hide()
	if targets.has(target):targets[target].hide()

func drop_item(id:String,target:String) -> bool:
	if _interaction_locked() or not items.has(id):return false
	if not items[id].loose or items[id].used:return false
	match number:
		4:
			if id=="red" and target=="red" and fan_step==0:
				_consume(id,target);fan_step=1
				hint.text="빨강 부채를 붙였습니다. 첫 발판 위에 올라타세요."
				return true
			if id=="blue" and target=="blue" and fan_step==3:
				_consume(id,target);fan_step=4
				hint.text="파랑 부채가 O 발판을 내립니다. 내려오면 올라타세요."
				return true
		5:
			if id=="beauty" and target=="beauty" and mouse_step==0:
				_consume(id,target);items.beauty.sprite.show();items.beauty.sprite.position=targets.beauty.position
				items.beauty.home=targets.beauty.position;mouse_step=1;timer=0
				hint.text="가짜가 미인에게 정신이 팔렸습니다. 이제 다리를 놓을 수 있습니다."
				return true
			if id=="bridge" and target=="bridge":
				if mouse_step==0:
					bridge_failures+=1
					var piece:Dictionary=items.bridge;piece.anchor=Vector2(-1,-1);piece.home=piece.sprite.position;piece.loose=false
					var cutter:=GridPaperCutting.new();add_child(cutter);cutter.configure(camera,[piece.sprite]);cutter.set_process_unhandled_input(false)
					piece.cutter=cutter;piece.delay=0.0
					var rect:=_rect(piece.sprite)
					cutter._cut(cutter._screen(rect.get_center()-rect.size*.7),cutter._screen(rect.get_center()+rect.size*.7))
					hint.text="가짜가 다리를 잘라 다른 곳으로 옮겼습니다! 미인을 주막 옆으로 옮겨보세요."
					return true
				if mouse_step==1:
					_consume(id,target);_build_bridge(0);mouse_step=2
					hint.text="첫 다리가 놓였습니다. 주막 지붕을 잘라 고양이 아래 디딤돌 자리에 놓으세요."
					return true
			if id=="roof" and target=="cat" and mouse_step==2:
				_consume(id,target);items.roof.sprite.show();items.roof.sprite.position=targets.cat.position
				items.roof.home=targets.cat.position;mouse_step=3;timer=0
				hint.text="지붕 조각을 딛고 고양이가 내려옵니다."
				return true
		8:
			if (id=="crow" and target=="crow") or (id=="magpie" and target=="magpie"):
				_consume(id,target)
				var item:Dictionary=items[id]
				item.anchor=Vector2(-1,-1);item.home=targets[target].position
				item.sprite.position=item.home;item.sprite.pixel_size=.65/item.sprite.texture.get_height();item.sprite.show()
				if items.crow.used and items.magpie.used:
					items.crow.sprite.hide();items.magpie.sprite.hide();_build_bridge(0)
					chart_spinning=true;bird_step=BirdPhase.CROSSING;timer=0
					hint.text="두 새가 오작교를 이었습니다. 뒤의 지도가 회전합니다. 다리를 건너보세요."
				else:hint.text="새 한 마리를 붙였습니다. 나머지 새도 같은 끊어진 곳에 붙이면 다리가 생깁니다."
				return true
	return false

func interact() -> bool:
	if _interaction_locked():return false
	if number==5 and world.player.position.distance_to(items.uncle.sprite.position-Vector3.UP*.7)<2.4:
		var lines:=["거기 아가씨, 이리 와서 같이 술 안 마실래?","내 몸을 소중히 여겨야 해. 손톱 먹은 쥐가 진짜 행세를 할 수도 있다고.","쥐의 천적은 괭이지, 암."]
		hint.text=lines[hint_index%lines.size()];hint_index+=1;return true
	if number==8:
		var actor:=_nearest_speaker()
		if actor.is_empty():return false
		if speech_bubbles[actor].active:return true
		cancel_dialogue()
		var bubble:Dictionary=speech_bubbles[actor]
		bubble.label.text=PHOTO_DIALOGUE[actor];bubble.active=true;bubble.elapsed=0.0
		bubble.panel.modulate.a=0;_layout_dialogue()
		if actor=="couple":
			hint.text="견우와 직녀와 대화를 마쳤습니다. 다리를 건너 도착점으로 가세요."
			path_open=true;bird_step=BirdPhase.TALKED
		return true
	return false

func _process(delta:float) -> void:
	if world==null:return
	if world.transition.active:cancel_dialogue()
	if world.paused or world.transition.active:_cancel();return
	if number==8:_advance_dialogue(delta)
	# Snapshot keys: resolving the inn roof adds the remaining wall as a new item.
	for id in items.keys():
		var item:Dictionary=items[id]
		if item.delay>=0:
			item.delay+=delta
			if item.delay>=.7:_resolve_piece(id)
	match number:
		4:_advance_fans(delta)
		5:_advance_mouse(delta)
		8:_advance_birds(delta)
	_layout()

func _advance_fans(delta:float) -> void:
	var first:AnimatableBody3D=world.rune_candidates[0].body
	var second:AnimatableBody3D=world.rune_candidates[1].body
	camera.position.y=lerpf(camera.position.y,base_camera.y+maxf(0,world.player.position.y)*.94,1-exp(-5*delta))
	if fan_step==1 and world.on_lift(first):fan_step=2
	if fan_step==2:
		first.position.y=move_toward(first.position.y,9,delta*2.5)
		if first.position.y>=8.99:
			fan_step=3;items.brows.sprite.show()
			for block in red_blocks:block.collision_layer=0;falling_blocks.append(block)
			hint.text="옥황상제: 감히 하늘까지 올라오다니!  ·  붉은 장벽이 무너졌습니다. 파랑 부채로 O 발판을 내리세요."
	if fan_step==4:
		second.position.y=move_toward(second.position.y,9,delta*1.8)
		if second.position.y<=9.01 and world.on_lift(second):fan_step=5
	if fan_step==5:
		second.position.y=move_toward(second.position.y,10.8,delta*1.2)
		if second.position.y>=10.79:
			fan_step=6;path_open=true
			hint.text="O 발판이 자동으로 올라왔습니다. 위쪽 도착점으로 건너가세요."
	for block in falling_blocks:
		if is_instance_valid(block):block.position.y-=delta*5;block.rotation.z+=delta*.6
	falling_blocks=falling_blocks.filter(func(block):return is_instance_valid(block) and block.position.y> -15)

func _advance_mouse(delta:float) -> void:
	if mouse_step in [1,2]:
		timer+=delta
		var sprite:Sprite3D=items.impostor.sprite
		sprite.position=sprite.position.move_toward(Vector3(1.8,2.5+sin(timer*4)*.035,-1.8),delta*1.5)
		items.impostor.home=sprite.position
	if mouse_step==3:
		timer+=delta
		items.cat.sprite.position=items.cat.sprite.position.move_toward(Vector3(2.2,2.8,-1.3),delta*1.8)
		if timer>1:
			items.impostor.sprite.hide();items.mouse.sprite.show()
			items.mouse.sprite.material_override.set_shader_parameter("opacity",clampf(2.3-timer,0,1))
		if timer>=2.3:
			items.mouse.sprite.hide();mouse_step=4;_build_bridge(1);path_open=true
			hint.text="고양이를 본 가짜가 쥐로 변해 사라졌습니다. 두 번째 다리로 올라가세요."

func _advance_birds(delta:float) -> void:
	if chart_spinning:chart_angle=wrapf(chart_angle+TAU*delta/CHART_TURN_SECONDS,0,TAU)
	if bird_step==BirdPhase.CROSSING and _on_far_terrace():
		bird_step=BirdPhase.FADING;timer=0;items.couple.sprite.show()
		items.couple.sprite.material_override.set_shader_parameter("opacity",0)
		hint.text="오작교 위에 견우와 직녀의 그림자가 나타납니다. 다리를 되돌아와 머리 위 말풍선 근처에서 E로 대화하세요."
	if bird_step==BirdPhase.FADING:
		timer+=delta
		items.couple.sprite.material_override.set_shader_parameter("opacity",clampf(timer/COUPLE_FADE_SECONDS,0,1))
		if timer>=COUPLE_FADE_SECONDS:bird_step=BirdPhase.RETURNING

func _on_far_terrace() -> bool:
	if not world.player.is_on_floor():return false
	var feet:Vector3=world.player.position
	for part:Array in world.stage_data.raised:
		var height:float=part[1].y*.2
		if absf(height-3.6)>.01 or absf(feet.y-height)>.08:continue
		var footprint:=Rect2(part[0].x*.2,part[0].z*.2,(part[1].x-part[0].x)*.2,(part[1].z-part[0].z)*.2)
		if footprint.has_point(Vector2(feet.x,feet.z)):return true
	return false
