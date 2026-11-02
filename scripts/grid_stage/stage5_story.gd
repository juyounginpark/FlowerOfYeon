extends "res://scripts/grid_stage/stage5_props.gd"
# Story state only. GridPaperCutting owns cutting, dragging and surface sticking.
const RAT_HOME:=Vector3(.1,1.8,-1.4)
const GEOMETRY=preload("res://scripts/grid_stage/story_geometry.gd")
var world:GridStageWorld
var camera:Camera3D
var path_open:=false
var mouse_sound:AudioStreamPlayer
var paper:GridPaperCutting
var trees:Array[Sprite3D]=[]
var bridges:Dictionary={}
var bridge_age:Dictionary={}
var tree_bridge:Node
var kick:Node
var bridge_previews:Array[Node3D]=[]
var crossed:Array[bool]=[false,false]
var routes:Array=[]
var distracted:=false
var caught:=false
var cat_time:=-1.0
var reveal_time:=0.0
var rat_base:=RAT_HOME
var guard:=RAT_HOME
var guard_time:=0.0
var previous_player:=Vector3.ZERO
var beauty_home:=Vector3.ZERO
var rat_view:=RAT_HOME
var painting:Dictionary={}
var cat_arrived:=false
var chasing:=false
var chase_angle:=0.0
var chase_direction:=1.0
var chase_center:=Vector3.ZERO
var chase_radius:=Vector2.ONE
var cat_jump_start:=Vector3.ZERO
var cat_target:=Vector3.ZERO
var fish:Sprite3D
var beauty:Sprite3D
var cat:Sprite3D
var impostor:Sprite3D
var mouse:Sprite3D
var hint:Label
const REWORK_ART:="res://art/minhwa/stage5_rework/"
const SCHOLAR_SCALE:=RAT_SCALE
var roof_cats:Array[Sprite3D]=[]
var rat_marker:Sprite3D
var cats:Node
var mural:MeshInstance3D
const MOUNTED_SIZE:=Vector2(1.2,2.4)

func configure(owner_world:GridStageWorld) -> void:
	mouse_sound=AudioStreamPlayer.new()
	var sound:AudioStreamMP3=load("res://music/mouse-5.mp3").duplicate()
	sound.loop=true;mouse_sound.stream=sound
	mouse_sound.volume_db=BgmPlayer.BASE_VOLUME_DB
	add_child(mouse_sound)
	super.configure(owner_world)
	world=owner_world;camera=world.camera;routes=world.stage_data.tree_routes
	var terrace:Array=world.stage_data.raised[0]
	chase_center=Vector3((terrace[0].x+terrace[1].x)*.1,terrace[1].y*.2,(terrace[0].z+terrace[1].z)*.1)
	chase_radius=Vector2((terrace[1].x-terrace[0].x)*.1-.45,(terrace[1].z-terrace[0].z)*.1-.45)
	world.player.sprite.set_meta("paper_foreground",true)
	beauty=get_node("Beauty");cat=get_node("Cat")
	impostor=get_node("Impostor");mouse=get_node("Mouse")
	_install_cats()
	cats=preload("res://scripts/grid_stage/stage5_cats.gd").new();cats.name="FishChasingCats";add_child(cats)
	cats.configure(world,self,roof_cats)
	rat_marker=_picture("RatMarker",load(REWORK_ART+"rat_marker.png"),rat_base,.48*RAT_SCALE,camera)
	_add_rat_border(rat_marker,camera)
	_update_rat_marker()
	var hearts:=preload("res://scripts/grid_stage/stage5_hearts.gd").new()
	hearts.name="BeautyAffectionHearts";add_child(hearts);hearts.configure(self)
	beauty_home=beauty.position;previous_player=world.player.position
	_split_fish()
	fish.set_meta("paper_surface_filter",Callable(self,"_fish_surface_allowed"))
	# Use the existing earth wildlife perspective for near/middle/far trees.
	var tree_anchors:=[Vector2(.075,.88),Vector2(.16,.71),Vector2(.235,.54),Vector2(.30,.38)]
	for i:int in range(tree_anchors.size()):
		var tree_texture:Texture2D=load(REWORK_ART+"pine_%02d_clean.png"%(i+1))
		var anchor:Vector2=tree_anchors[i]
		var plane:Dictionary=preload("res://scripts/grid_stage/earth_wildlife.gd").perspective(anchor.y)
		var base:Vector3=camera.project_position(get_viewport().get_visible_rect().size*anchor,float(plane.depth))
		var tree:Sprite3D=_picture("Tree%d"%i,tree_texture,base,2.4*float(plane.width)/.040,camera)
		tree.set_meta("background_depth",plane.depth)
		tree.set_meta("paper_grounded",true);tree.set_meta("paper_foreground",false);tree.set_meta("screen_band",10)
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_wildlife.gdshader")
		ink.render_priority=1 # Whole tree above background ink, below foreground ridges.
		ink.set_shader_parameter("animal_sheet",tree.texture)
		ink.set_shader_parameter("opacity",lerpf(.78,1.0,float(plane.nearness)))
		ink.set_shader_parameter("haze",float(plane.haze)*.4)
		ink.set_shader_parameter("ground_y",anchor.y)
		tree.material_override=ink
		tree.set_meta("triangle_cut_collision",true);tree.set_meta("paper_outline_fallback",true)
		tree.set_meta("paper_extend_cut",true)
		tree.set_meta("paper_alpha_border",true)
		tree.set_meta("paper_minimum_piece_area",10.0)
		trees.append(tree)
	beauty.set_meta("paper_movable",true);beauty.set_meta("paper_cuttable",false)
	beauty.set_meta("paper_wall_only",true)
	beauty.set_meta("paper_surface_filter",Callable(self,"_painting_surface_allowed"))
	beauty.set_meta("paper_mounted_texture",load(REWORK_ART+"beauty_mounted.png"))
	beauty.set_meta("paper_mounted_size",MOUNTED_SIZE)
	paper=GridPaperCutting.new();paper.name="StoryPaper";add_child(paper)
	var cuttable:Array[Sprite3D]=trees.duplicate();cuttable.append(fish);cuttable.append(beauty)
	for source:Sprite3D in cuttable:source.set_meta("paper_grab_margin",24.0)
	paper.configure(camera,cuttable)
	paper.max_fragments=192
	tree_bridge=preload("res://scripts/grid_stage/stage5_tree_bridge.gd").new();add_child(tree_bridge);tree_bridge.configure(self)
	tree_bridge.required_coverage=.35
	tree_bridge.walk_condition=Callable(self,"_can_walk_tree_bridges")
	kick=preload("res://scripts/grid_stage/stage5_bridge_kick.gd").new();add_child(kick);kick.configure(self)
	paper.source_cut.connect(_on_source_cut);paper.piece_dropped.connect(_on_piece_dropped)
	for index:int in range(routes.size()):bridge_previews.append(_create_bridge(index,true))
	var overlay:=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	hint=Label.new();hint.hide();hint.position=Vector2(30,76);hint.add_theme_font_size_override("font_size",18)
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Malgun Gothic"])
	hint.add_theme_font_override("font",font);hint.add_theme_color_override("font_color",Color("4b493b"))
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color("f3e7ce");hint.add_theme_stylebox_override("normal",style)
	overlay.add_child(hint)
	hint.text="나무를 잘라 발판 사이에 놓으세요. 미인도는 출구 발판의 오른쪽 옆벽에만 붙일 수 있습니다. 아기고양이에게 E로 말을 걸어보세요."

func _install_cats() -> void:
	remove_child(cat);cat.queue_free()
	var inn:Sprite3D=get_node("Inn")
	# Foot anchors are on painted straw, in original inn image pixels.
	var anchors:=[Vector2(220,345),Vector2(385,295),Vector2(550,345)]
	var crop:Rect2i=inn.get_meta("source_crop")
	var sheets:=["tabby_joseon.png","piebald_joseon.png","ink_joseon.png"]
	for index:int in range(3):
		var actor=preload("res://scripts/grid_stage/minhwa_idle_sprite.gd").new()
		actor.name="RoofCat%d"%index;add_child(actor)
		var offset:Vector2=anchors[index]-Vector2(crop.position)-inn.texture.get_size()*.5
		var foot:Vector3=inn.position+camera.global_basis.x*offset.x*inn.pixel_size-camera.global_basis.y*offset.y*inn.pixel_size
		actor.configure(world,REWORK_ART+sheets[index],1.70,foot,index*.23)
		roof_cats.append(actor)
	cat=roof_cats[0]

func _update_rat_marker() -> void:
	rat_marker.position=rat_base+camera.global_basis.y*(1.5*SCHOLAR_SCALE+.12+.24*RAT_SCALE)
	rat_marker.visible=not caught

func _painting_surface_allowed(hit:Dictionary,pose:Transform3D,polygon:PackedVector2Array) -> bool:
	# The highlighted east (+X) face of the upper/exit block, not other walls.
	if hit.collider.name!="HighGoalAndTerrace" or Vector3(hit.normal).dot(Vector3.RIGHT)<.99:return false
	var block:Array=world.stage_data.raised[1]
	var minimum:Vector3=Vector3(block[0])*.2
	var maximum:Vector3=Vector3(block[1])*.2
	if absf(Vector3(hit.position).x-maximum.x)>.03:return false
	var touch:Vector3=hit.position
	return touch.y>=minimum.y and touch.y<=maximum.y and touch.z>=minimum.z and touch.z<=maximum.z

func _fish_surface_allowed(hit:Dictionary,_pose:Transform3D,_polygon:PackedVector2Array) -> bool:
	# Only the marked top face of the middle terrace, shared by the pursuing cats.
	if hit.collider.name!="HighGoalAndTerrace":return false
	var normal:Vector3=world.stage_root.global_basis.inverse()*Vector3(hit.normal)
	if normal.dot(Vector3.UP)<.99:return false
	var block:Array=world.stage_data.raised[0]
	var minimum:=Vector3(block[0])*.2
	var maximum:=Vector3(block[1])*.2
	var point:Vector3=world.stage_root.to_local(hit.position)
	return absf(point.y-maximum.y)<=.03 and point.x>=minimum.x and point.x<=maximum.x and point.z>=minimum.z and point.z<=maximum.z

func _split_fish() -> void:
	var inn:Sprite3D=get_node("Inn")
	var image:Image=inn.texture.get_image()
	# The supplied v2 asset's left eave has a separate hanging gulbi bundle.
	# Convert original PNG coordinates to the cropped picture's local coordinates.
	var source_crop:Rect2i=inn.get_meta("source_crop")
	var region:=Rect2i(Vector2i(250,505)-source_crop.position,Vector2i(180,289))
	var fish_image:Image=image.get_region(region)
	var used:Rect2i=fish_image.get_used_rect()
	var crop:=Rect2i(region.position+used.position,used.size)
	var texture:=ImageTexture.create_from_image(image.get_region(crop))
	var pixel:float=inn.pixel_size
	fish=_picture("Fish",texture,Vector3.ZERO,crop.size.y*pixel,camera)
	var offset:Vector2=Vector2(crop.get_center())-Vector2(image.get_size())*.5
	fish.position=inn.position+camera.global_basis.x*offset.x*pixel-camera.global_basis.y*offset.y*pixel
	fish.set_meta("paper_hanging",true);fish.set_meta("paper_extend_cut",true)
	fish.set_meta("paper_minimum_piece_area",1.0)
	inn.material_override.set_shader_parameter("hidden_region",Vector4(float(region.position.x)/image.get_width(),float(region.position.y)/image.get_height(),float(region.size.x)/image.get_width(),float(region.size.y)/image.get_height()))

func _on_source_cut(sprite:Sprite3D) -> void:
	if trees.has(sprite):tree_bridge.cut_tree(sprite)
	if sprite==fish:hint.text="잘린 굴비를 가운데 발판의 윗면에 붙여 고양이를 불러보세요."
	elif trees.has(sprite):hint.text="조각을 발판 사이로 옮기세요. 조각을 다시 자를 때는 Shift를 누르고 드래그하세요."

func _map_sticker(piece:Dictionary) -> bool:
	return piece.sticker and is_instance_valid(piece.host) and piece.host.name in ["StartAndPath","HighGoalAndTerrace"]

func _central_point(point:Vector3) -> Vector3:
	var middle:Array=world.stage_data.raised[0]
	return Vector3(clampf(point.x,middle[0].x*.2+.35,middle[1].x*.2-.35),middle[1].y*.2,clampf(point.z,middle[0].z*.2+.35,middle[1].z*.2-.35))

func _on_piece_dropped(piece:Dictionary,point:Vector2) -> void:
	for preview:Node3D in bridge_previews:preview.hide()
	var sprite:Sprite3D=piece.source.sprite
	if sprite==beauty:
		if not caught and _map_sticker(piece):
			painting=piece;distracted=true
			piece["permanent"]=true;piece["consumed_by_mural"]=true
			piece.visual.hide();piece.border.hide();piece.shadow.hide()
			if not is_instance_valid(mural):
				mural=preload("res://scripts/grid_stage/stage5_mural.gd").new()
				mural.name="PermanentBeautyMural";add_child(mural)
				mural.configure(world,piece.host,world.stage_data.raised[1],piece.visual.global_position,beauty.get_meta("paper_mounted_texture"))
			# The rat watches from the central terrace instead of walking down a wall.
			rat_view=_central_point(piece.visual.global_position)
			hint.text="미인 그림을 벽에 붙였습니다. 굴비를 가운데 발판의 윗면에 붙여 고양이를 불러보세요."
		else:
			painting={};distracted=false;beauty.position=beauty_home;paper.restore_source(beauty)
			hint.text="미인도 전체가 출구 발판의 오른쪽 옆벽 안에 들어가도록 붙여주세요."
		return
	if sprite==fish:
		if piece.sticker:cats.target_piece=piece;cats.active=false
		if caught or not _map_sticker(piece) or piece.attached:return
		if paper._area(piece.polygon)<maxf(3.0,paper._area(piece.source.polygon)*.06):
			hint.text="굴비가 남아 있는 큰 조각을 가운데 발판의 윗면에 붙여주세요.";return
		hint.text="네 마리 고양이가 모두 생선을 쫓습니다. 미인도로 가짜의 시선을 붙잡고 생선으로 고양이를 유인하세요."
		return
	if not trees.has(sprite) or piece.attached:return
	var index:=_bridge_candidate(piece,point)
	if index<0:
		hint.text="잘린 나무 조각을 아직 다리가 없는 발판 사이에 놓아주세요.";return
	tree_bridge.mount(index,piece,point)

func _bridge_candidate(piece:Dictionary,point:Vector2) -> int:
	if not trees.has(piece.source.sprite) or piece.attached:return -1
	# Any source tree can supply either crossing. Use the dropped piece's actual
	# outline as well as the grab point so the bridge does not depend on grip.
	var outline:=PackedVector2Array()
	for vertex:Vector2 in piece.polygon:
		outline.append(paper._screen(camera.unproject_position(piece.visual.global_transform*Vector3(vertex.x,-vertex.y,0))))
	var index:=-1;var nearest:=INF
	for candidate:int in range(routes.size()):
		if tree_bridge.is_complete(candidate):continue
		var a:Vector2=paper._screen(camera.unproject_position(routes[candidate][0]))
		var b:Vector2=paper._screen(camera.unproject_position(routes[candidate][1]))
		var distance:float=point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))
		var overlaps:bool=Geometry2D.is_point_in_polygon((a+b)*.5,outline)
		for edge:int in range(outline.size()):
			if Geometry2D.segment_intersects_segment(a,b,outline[edge],outline[(edge+1)%outline.size()])!=null:overlaps=true
		if (overlaps or distance<=1000.0/camera.size*1.6) and distance<nearest:
			index=candidate;nearest=distance
	return index

func _update_bridge_preview() -> void:
	for preview:Node3D in bridge_previews:preview.hide()
	if world.paused or world.transition.active or world.player.input_locked or world.completed:return
	if not is_instance_valid(paper.grabbed) or paper.locked:return
	var index:=_bridge_candidate(paper.grabbed_piece,paper._mouse())
	if index>=0:bridge_previews[index].show()

func _build_bridge(index:int) -> void:
	bridges[index]=_create_bridge(index);bridge_age[index]=0.0

func _create_bridge(index:int,preview:=false) -> Node3D:
	var a:Vector3=routes[index][0];var b:Vector3=routes[index][1]
	var horizontal:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var crossing:=Node3D.new()
	crossing.name=("TreeBridgePreview%d" if preview else "TreeBridge%d")%index
	if preview:crossing.hide()
	add_child(crossing)
	for span:Array in [[a-horizontal*.35,a],[a,b],[b,b+horizontal*.4]]:
		_bridge_span(crossing,span[0],span[1],preview)
	if not preview:preload("res://scripts/grid_stage/tree_bridge_collision.gd").join_spans(crossing)
	return crossing

func _bridge_span(crossing:Node3D,a:Vector3,b:Vector3,preview:=false) -> void:
	var forward:Vector3=(b-a).normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	var up:=right.cross(forward).normalized()
	var size:=Vector3(1.6,.18,a.distance_to(b))
	var body:Node3D
	if preview:
		body=Node3D.new();crossing.add_child(body);body.position=(a+b)*.5-up*.09
	else:
		body=GEOMETRY.box(crossing,(a+b)*.5-up*.09,size,Color("a28359"),false)
		body.collision_layer=0
	body.basis=Basis(right,up,-forward)
	if not preview:return # TreeBridgeArt supplies the painted deck after assembly.
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color=Color(.35,.85,.65,.45) if preview else Color("a28359")
	if preview:ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh:=MeshInstance3D.new();var wood:=CylinderMesh.new()
	mesh.set_meta("paper_protect_player",true);mesh.set_meta("bridge_draw_priority",125)
	wood.top_radius=.5;wood.bottom_radius=.5;wood.height=size.z;wood.radial_segments=12
	mesh.mesh=wood;mesh.material_override=ink
	mesh.rotation.x=PI*.5;mesh.scale=Vector3(size.x,1,size.y);body.add_child(mesh)

func _on_crossing(index:int) -> bool:
	var a:Vector3=routes[index][0];var b:Vector3=routes[index][1]
	var player:Vector3=world.player.position
	var delta:=Vector2(b.x-a.x,b.z-a.z)
	var t:float=Vector2(player.x-a.x,player.z-a.z).dot(delta)/delta.length_squared()
	if t<0 or t>1.15:return false
	var closest:Vector3=a.lerp(b,clampf(t,0,1))
	return Vector2(player.x-closest.x,player.z-closest.z).length()<1.1 and absf(player.y-closest.y)<.5

func _sabotage_stopped() -> bool:
	return caught or (distracted and not cats._find_fish().is_empty())

func _can_walk_tree_bridges() -> bool:
	# Distracting the impostor only stops sabotage; support unlocks after capture.
	return caught

func _process(delta:float) -> void:
	if world==null:return
	_update_bridge_preview()
	var player_step:Vector3=world.player.position-previous_player
	previous_player=world.player.position
	mouse_sound.stream_paused=world.paused or world.transition.active or world.player.input_locked
	if mouse_sound.stream_paused:return
	if not caught and not mouse_sound.playing:mouse_sound.play()
	tree_bridge.tick(delta)
	var kicking:bool=kick.tick(delta)
	player_step.y=0
	# Respawn/restart displacement is not walking and must not teleport the rat.
	if player_step.length()>1.0:player_step=Vector3.ZERO
	if caught:
		reveal_time+=delta;mouse.material_override.set_shader_parameter("opacity",maxf(0,1.0-reveal_time))
		if reveal_time>=1:
			mouse.hide();mouse_sound.stop()
		return
	# A mounted painting remains a lure after the player interrupts admiration.
	var was_distracted:bool=distracted
	var mounted:bool=not painting.is_empty() and _map_sticker(painting)
	var player_near:bool=world.player.position.y>1.3 and world.player.position.distance_to(rat_view)<1.4
	distracted=mounted and not player_near
	if mounted and distracted!=was_distracted:
		hint.text="멀어지자 가짜가 다시 미인도를 감상합니다." if distracted else "가까이 가자 가짜가 경계합니다. 잠시 떨어지면 다시 그림을 봅니다."
	for index:int in bridges.keys():
		bridge_age[index]+=delta
		if not tree_bridge.is_complete(index) or kick.index>=0 or _sabotage_stopped() or bridge_age[index]<.8:continue
		kick.begin(index)
	var rat_before:Vector3=rat_base
	if kicking:
		pass
	elif distracted:
		chasing=false;rat_base=rat_base.move_toward(rat_view,delta*2)
	elif cat_arrived:
		_flee_cat(delta)
	elif guard_time>0:
		guard_time=maxf(0,guard_time-delta);rat_base=rat_base.move_toward(guard,delta*2)
	else:
		# Reflect screen-left/right travel while retaining screen-up/down travel.
		var screen_right:=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
		var mirrored_step:Vector3=player_step-2.0*player_step.dot(screen_right)*screen_right
		rat_base=_central_point(rat_base+mirrored_step)
	impostor.position=rat_base+camera.global_basis.y*(.75*SCHOLAR_SCALE)
	_update_rat_marker()
	if distracted and not painting.is_empty():
		impostor.flip_h=camera.unproject_position(painting.visual.global_position).x<camera.unproject_position(impostor.global_position).x
	elif (rat_base-rat_before).length_squared()>.0001:
		impostor.flip_h=(rat_base-rat_before).dot(camera.global_basis.x)<0
	_advance_cat(delta)

func _circle_point(angle:float) -> Vector3:
	return chase_center+Vector3(cos(angle)*chase_radius.x,0,sin(angle)*chase_radius.y)

func _flee_cat(delta:float) -> void:
	if not chasing:
		chasing=true
		chase_angle=atan2((rat_base.z-chase_center.z)/chase_radius.y,(rat_base.x-chase_center.x)/chase_radius.x)
		var tangent:=Vector3(-sin(chase_angle)*chase_radius.x,0,cos(chase_angle)*chase_radius.y)
		# Start around the loop in the direction away from the arriving cat.
		chase_direction=-1.0 if tangent.dot(cat.position-rat_base)>0 else 1.0
	chase_angle=wrapf(chase_angle+delta*1.8*chase_direction,-PI,PI)
	rat_base=rat_base.move_toward(_circle_point(chase_angle),delta*3.2)

func _advance_cat(delta:float) -> void:
	if not cats.active:return
	if distracted and rat_base.distance_to(rat_view)<.3 and cats.distance_to(rat_base)<1.1:
		caught=true;path_open=true;impostor.hide()
		rat_marker.hide()
		mouse.position=rat_base+camera.global_basis.y*(.3*RAT_SCALE);mouse.show()
		mouse_sound.play()
		hint.text="가짜가 쥐로 돌아가 도망쳤습니다. 남은 다리를 놓아 출구로 올라가세요."
