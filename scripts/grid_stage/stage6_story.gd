extends "res://scripts/grid_stage/stage6_crossings.gd"
# Feeding survives falls within this visit, but resets with the stage instance.
var fed_total:int=0
var tense_sound:AudioStreamPlayer
enum Phase { HUNT, EAT, FED_RETREAT, SLEEP_WALK, SLEEP, ROPE_DOWN, READY, ASCEND, WAKE, CHASE, ESCAPE, FAILED, CLEARED }
const ART:="res://art/minhwa/stage6_rework/"
const OLD_ART:="res://stages/6-해와달이된오누이/"
# Just outside the right terrace (edge x=4.2), matching the red reference line.
# Reachable from the ledge, with room for the severed body's .23 m radius.
const ROPE_FOOT:=Vector3(4.5,1.8,-1.35)
const SLEEP_FOOT:=Vector3(-3.1,1.8,.05)
const ASCENT_HEIGHT:=7.0
const CHASE_HEIGHT:=ASCENT_HEIGHT*.85
const ESCAPE_SPEED:=2.6
const CUT_SECONDS:=3.0
const TIGER_SCALE:=3.0
const ROPE_WIDTH:=.48
const TREE_ART_LAYER:=10
var phase:=Phase.HUNT
var phase_time:=0.0
var path_open:=false
var controls_camera:=true
var sister:Sprite3D
var sister_base:=Vector3.ZERO
var trail:Array[Vector3]=[]
var tiger:Sprite3D
var tiger_base:=Vector3.ZERO
var tiger_from:=Vector3.ZERO
var rush_from:=Vector3.ZERO
var rush_target:=Vector3.ZERO
var rush_time:=0.0
var rush_episode:=0
var rush_hit:=false
var rush_fed:=false
var rush_started:=false
var frames:Array[Texture2D]=[]
var frame_ink:Array[Rect2i]=[]
var eat_frames:Array[Texture2D]=[]
var eat_ink:Array[Rect2i]=[]
var eat_origin:=Vector3.ZERO
var retreat_origin:=Vector3.ZERO
var climb_art:Sprite3D
var textures:Dictionary={}
var rice:Sprite3D
var rope:Sprite3D
var upper_rope:Sprite3D
var rope_bottom:=ROPE_FOOT
var rope_top:=ROPE_FOOT+Vector3.UP*13
var cut_bottom:=Vector3.ZERO
var cut_top:=Vector3.ZERO
var cut_start:=Vector2.ZERO
var cutting:=false
var cut_line:Line2D
var falling_tiger:RigidBody3D
var climb_origin:=Vector3.ZERO
var escape_height:=CHASE_HEIGHT
var impact:Sprite3D
var impact_time:=0.0
var rope_shake:=0.0
var rope_warning=preload("res://scripts/grid_stage/speech_bubble.gd").new()

func configure(owner_world:GridStageWorld) -> void:
	tense_sound=AudioStreamPlayer.new()
	var sound:AudioStreamMP3=load("res://music/tense-6.mp3").duplicate()
	sound.loop=true;tense_sound.stream=sound
	tense_sound.volume_db=BgmPlayer.BASE_VOLUME_DB
	add_child(tense_sound)
	world=owner_world;camera=world.camera;routes=world.stage_data.bridge_routes
	process_physics_priority=10
	_load_art();_create_hint()
	sister_base=world.start_position+Vector3(-.42,0,.25)
	sister=_picture("Sister",load(OLD_ART+"여동생.png"),sister_base,1.25)
	world.dialogue=preload("res://scripts/grid_stage/woodcutter_dialogue.gd").new()
	world.dialogue.name="SisterDialogue";add_child(world.dialogue)
	world.dialogue.lines=PackedStringArray(["호랑이가 떡을 좋아한대"])
	world.dialogue.configure(world,sister)
	tiger=_picture("Tiger",frames[0],world.start_position,1.7)
	tiger.material_override.shader=preload("res://shaders/grid_stage6_tiger.gdshader")
	# Share the trees' composite pass, then draw the tiger after their ink.
	tiger.set_meta("story_layer",TREE_ART_LAYER)
	tiger.material_override.render_priority=5
	tiger.material_override.set_shader_parameter("clip_to_slice",false)
	climb_art=_picture("ClimbingSiblings",textures.siblings_climb,Vector3.ZERO,2.7)
	climb_art.offset.x=-climb_art.texture.get_width()*.28;climb_art.hide()
	climb_art.material_override.render_priority=3
	impact=_picture("KnockbackImpact",textures.knockback_impact,Vector3.ZERO,1.3)
	impact.material_override.render_priority=4;impact.hide()
	var mother_image:Image=load(ART+"mother.png").get_image()
	if mother_image.is_compressed():mother_image.decompress()
	var mother_bounds:=mother_image.get_used_rect()
	var mother:=_picture("RiceWoman",ImageTexture.create_from_image(mother_image),_screen_base(Vector2(.18,.93),25),3.8)
	# Anchor the separately cuttable basket on the painted cloth head pad.
	var head_pixel:=Vector2(525,135)
	var head_offset:=head_pixel-Vector2(mother_bounds.get_center())
	var head:=mother.global_position+(camera.global_basis.x*head_offset.x-camera.global_basis.y*head_offset.y)*mother.pixel_size
	var basket_height:float=860.0*mother.pixel_size*textures.rice_basket.get_height()/textures.rice_basket.get_width()
	rice=_picture("RiceBasket",textures.rice_basket,head+camera.global_basis.z*.04,basket_height)
	rice.set_meta("paper_cuttable",true);rice.set_meta("paper_extend_cut",true)
	rice.set_meta("paper_minimum_piece_area",4.0)
	rice.set_meta("paper_story_layer",10)
	# A real collision shelf stops loose rice around the mother's waist.
	rice.set_meta("paper_floor_y",camera.unproject_position(mother.global_position).y*1000.0/get_viewport().get_visible_rect().size.y)
	rice.set_meta("paper_grab_margin",16.0)
	rice.set_meta("paper_loose_foreground",true)
	_create_trees()
	paper=GridPaperCutting.new();paper.name="Stage6Paper";add_child(paper)
	var sources:Array[Sprite3D]=trees.duplicate();sources.append(rice)
	paper.configure(camera,sources);paper.max_fragments=256
	tree_bridge=preload("res://scripts/grid_stage/stage5_tree_bridge.gd").new();add_child(tree_bridge);tree_bridge.configure(self)
	paper.source_cut.connect(_on_cut);paper.piece_dropped.connect(_on_drop)
	for index:int in range(routes.size()):bridge_previews.append(_create_bridge(index,true))
	rope=_picture("HeavenRope",textures.rope,ROPE_FOOT,13)
	upper_rope=_picture("AnchoredRope",textures.rope,ROPE_FOOT,13)
	rope.material_override.shader=preload("res://shaders/grid_stage6_rope.gdshader")
	rope.hide();upper_rope.hide();_reset_attempt()

func _load_art() -> void:
	var regions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"frame-regions.json"))
	for id:String in ["rice_basket","siblings_climb","rope","tiger_sleep","tiger_climb","tiger_fall","knockback_impact"]:
		var image:Image=load(ART+id+".png").get_image()
		if image.is_compressed():image.decompress()
		var r:Array=regions.images[id]
		var bounds:=Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])).grow(12).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		textures[id]=ImageTexture.create_from_image(image.get_region(bounds))
	var sheet:Image=load(ART+"tiger_run.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	# Five separate textures: no atlas filtering can reach a neighboring frame.
	var cell:=Vector2i(sheet.get_width()/3,sheet.get_height()/2)
	for index:int in range(5):
		var pose:=sheet.get_region(Rect2i(Vector2i(index%3,index/3)*cell,cell))
		frames.append(ImageTexture.create_from_image(pose))
		var r:Array=regions.frames[index].ink
		frame_ink.append(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))
	var eating:Image=load(ART+"tiger_eat.png").get_image()
	if eating.is_compressed():eating.decompress()
	for entry:Dictionary in regions.eat_frames:
		var c:Array=entry.cell;var r:Array=entry.ink
		eat_frames.append(ImageTexture.create_from_image(eating.get_region(Rect2i(int(c[0]),int(c[1]),int(c[2]),int(c[3])))))
		eat_ink.append(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))

func _picture(label:String,texture:Texture2D,foot:Vector3,height:float) -> Sprite3D:
	var source:=texture.get_image()
	if source.is_compressed():source.decompress()
	var sprite:=Sprite3D.new();sprite.name=label
	sprite.texture=ImageTexture.create_from_image(source.get_region(source.get_used_rect()))
	sprite.pixel_size=height/sprite.texture.get_height()
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("story_actor",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
	ink.set_shader_parameter("illustration",sprite.texture);sprite.material_override=ink
	add_child(sprite);sprite.global_basis=camera.global_basis
	sprite.position=foot+camera.global_basis.y*height*.5
	return sprite

func _screen_base(anchor:Vector2,depth:float) -> Vector3:
	return camera.project_position(get_viewport().get_visible_rect().size*anchor,depth)

func _create_trees() -> void:
	# Stage5's four clean pines, perspective, cut settings and alpha borders.
	var anchors:=[Vector2(.07,.86),Vector2(.16,.69),Vector2(.24,.52),Vector2(.31,.37),Vector2(.92,.87),Vector2(.85,.70),Vector2(.81,.51),Vector2(.88,.34)]
	for i:int in range(anchors.size()):
		if i==1:continue # Leave clear space above the mother's head basket.
		var anchor:Vector2=anchors[i]
		var plane:Dictionary=preload("res://scripts/grid_stage/earth_wildlife.gd").perspective(anchor.y)
		var tree:=_picture("BridgeTree%d"%i,load("res://art/minhwa/stage5_rework/pine_%02d_clean.png"%(i%4+1)),_screen_base(anchor,plane.depth),2.4*float(plane.width)/.040)
		tree.remove_meta("story_actor")
		tree.set_meta("background_depth",plane.depth);tree.set_meta("paper_standing_layer",TREE_ART_LAYER)
		tree.set_meta("triangle_cut_collision",true);tree.set_meta("paper_outline_fallback",true)
		tree.set_meta("paper_extend_cut",true);tree.set_meta("paper_alpha_border",true)
		tree.set_meta("paper_minimum_piece_area",10.0)
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_wildlife.gdshader")
		ink.render_priority=1;ink.set_shader_parameter("animal_sheet",tree.texture)
		ink.set_shader_parameter("opacity",lerpf(.78,1.0,float(plane.nearness)))
		ink.set_shader_parameter("haze",float(plane.haze)*.4);ink.set_shader_parameter("ground_y",anchor.y)
		tree.material_override=ink;trees.append(tree)

func _create_hint() -> void:
	var overlay:=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	hint=Label.new();hint.hide();hint.position=Vector2(30,76);hint.add_theme_font_size_override("font_size",22)
	hint.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(hint)
	cut_line=Line2D.new();cut_line.width=2;cut_line.default_color=Color("f1d389");overlay.add_child(cut_line)
	overlay.add_child(rope_warning)

func _on_cut(sprite:Sprite3D) -> void:
	if trees.has(sprite) or sprite==rice:tree_bridge.cut_tree(sprite)

func _on_drop(piece:Dictionary,point:Vector2) -> void:
	if piece.source.sprite==rice:
		if not piece.attached and phase==Phase.HUNT and rush_started and rush_time<=.95 and not rush_fed and _hits_tiger(point):
			rush_fed=true;fed_total=mini(3,fed_total+1)
			# Consume this one bitten portion; every other cut keeps its state.
			piece.body.queue_free();piece.visual.queue_free();paper.pieces.erase(piece)
			eat_origin=tiger_base;_enter(Phase.EAT)
		return
	if not trees.has(piece.source.sprite) or piece.attached:return
	var index:=_bridge_candidate(piece,point)
	if index>=0:tree_bridge.mount(index,piece,point)

func _hits_tiger(point:Vector2) -> bool:
	var screen:Vector2=point*get_viewport().get_visible_rect().size.y/1000.0
	var center:Vector2=camera.unproject_position(tiger.global_position)
	var scale:float=get_viewport().get_visible_rect().size.y/camera.size
	var offset:=Vector2(tiger.offset.x,-tiger.offset.y)*tiger.pixel_size*scale
	var pixel:Vector2=(screen-center-offset)/(tiger.pixel_size*scale)+Vector2(tiger.texture.get_size())*.5
	if tiger.flip_h:pixel.x=tiger.texture.get_width()-pixel.x-1
	var cell:=Vector2i(pixel)
	if not Rect2i(Vector2i.ZERO,tiger.texture.get_size()).has_point(cell):return false
	return tiger.texture.get_image().get_pixelv(cell).a>.12

func _enter(next:Phase) -> void:
	phase=next;phase_time=0
	if next==Phase.EAT:BgmPlayer.play_gulp()
	if next!=Phase.CHASE:tense_sound.stop()
	if next==Phase.CHASE:
		tense_sound.play()
		rope_warning.present("누이","빨리 줄을 잘라!")
		rope_warning.place(camera.unproject_position(sister_base+Vector3.UP*.85))
	else:rope_warning.close()

func _reset_attempt() -> void:
	world.player.position=world.start_position;world.player.velocity=Vector3.ZERO
	world.player.knockback_time=0;world.player.input_locked=false
	world.player.sprite.show();sister.show();climb_art.hide()
	world.player.prevent_walk_off_edges=true
	world.dialogue.cancel();paper.locked=false;cutting=false
	rope.hide();upper_rope.hide();cut_line.clear_points()
	rope.material_override.set_shader_parameter("cut_enabled",false)
	_set_rope_shake(0.0);impact_time=0;impact.hide()
	rope.hide()
	sister_base=world.start_position+Vector3(-.42,0,.25);trail=[world.start_position]
	sister.position=sister_base+camera.global_basis.y*.625
	rope_bottom=ROPE_FOOT;path_open=false;rush_started=false
	tiger.show();tiger.material_override.set_shader_parameter("opacity",1.0)
	_set_tiger_texture(frames[0],1.7)
	if fed_total>=3:
		tiger_base=SLEEP_FOOT;tiger.flip_h=false;_set_tiger_texture(textures.tiger_sleep,.95);_enter(Phase.SLEEP)
	else:tiger.hide();_enter(Phase.HUNT)
	_place_tiger()

func player_fell() -> void:
	if phase in [Phase.ASCEND,Phase.WAKE,Phase.CHASE,Phase.ESCAPE,Phase.CLEARED]:return
	# Falling never restores cut trees or erases the accumulated bridge/rice state.
	_reset_attempt()

func _set_tiger_texture(texture:Texture2D,height:float) -> void:
	tiger.texture=texture;tiger.pixel_size=height*TIGER_SCALE/texture.get_height()
	tiger.offset=Vector2.ZERO
	var frame_index:=frames.find(texture)
	if frame_index>=0:
		var ink:Rect2i=frame_ink[frame_index]
		tiger.offset=Vector2(texture.get_width()*.5-ink.get_center().x,ink.end.y-texture.get_height())
	elif texture==textures.tiger_climb:
		# Align the painted gripping paws with the separately drawn rope.
		tiger.offset.x=-texture.get_width()*.38
	var eating_index:=eat_frames.find(texture)
	if eating_index>=0:
		var ink:Rect2i=eat_ink[eating_index]
		tiger.offset=Vector2(texture.get_width()*.5-ink.get_center().x,ink.end.y-texture.get_height())
	tiger.material_override.set_shader_parameter("illustration",texture)

func _place_tiger() -> void:
	tiger.global_basis=camera.global_basis
	tiger.position=tiger_base+camera.global_basis.y*tiger.texture.get_height()*tiger.pixel_size*.5

func _start_rush() -> void:
	tiger.show()
	rush_episode+=1;rush_time=0;rush_hit=false;rush_fed=false;rush_started=true
	rush_target=world.player.position
	var side:float=-1.0 if rush_episode%2==0 else 1.0
	var lateral:=camera.global_basis.x;lateral.y=0;lateral=lateral.normalized()
	rush_from=rush_target+lateral*side*4.0-Vector3.UP*.7
	tiger.flip_h=side>0

func _hunt(delta:float) -> void:
	if not rush_started:_start_rush()
	rush_time+=delta
	var t:=clampf(rush_time/.95,0,1)
	var leaving:=rush_time>.95
	if leaving:t=clampf((rush_time-.95)/.8,0,1)
	var a:=rush_target if leaving else rush_from
	var b:=rush_from if leaving else rush_target
	tiger_base=a.lerp(b,t)+Vector3.UP*sin(PI*t)*.7
	_set_tiger_texture(frames[mini(4,int(t*5))],1.7)
	tiger.flip_h=(camera.unproject_position(b).x<camera.unproject_position(a).x)
	var opacity:=1.0-smoothstep(.7,1,t) if leaving else smoothstep(0,.22,t)
	tiger.material_override.set_shader_parameter("opacity",opacity)
	if not leaving and not rush_hit and not rush_fed and tiger_base.distance_to(world.player.position)<.9:
		rush_hit=true
		var direction:Vector3=(rush_target-rush_from);direction.y=0
		world.player.apply_knockback(direction.normalized()*2.7+Vector3.UP*1.25,.32)
		_show_impact()
	if rush_time>=1.78:_start_rush()

func _follow_sister(delta:float) -> void:
	var current:=world.player.position
	if trail.is_empty() or trail[-1].distance_to(current)>.14:trail.append(current)
	if sister_base.distance_to(current)>.55 and not trail.is_empty():
		sister_base=sister_base.move_toward(trail[0],delta*2.1)
		if sister_base.distance_to(trail[0])<.06:trail.pop_front()
	if trail.size()>240:trail.pop_front()
	sister.position=sister_base+camera.global_basis.y*.625

func _physics_process(delta:float) -> void:
	if world==null:return
	tense_sound.stream_paused=world.paused or world.transition.active
	rope_warning.blocked=world.paused or world.transition.active
	if is_instance_valid(falling_tiger):falling_tiger.freeze=world.paused or world.transition.active
	if world.paused or world.transition.active:return
	if world.player.input_locked and phase not in [Phase.ASCEND,Phase.WAKE,Phase.CHASE,Phase.ESCAPE,Phase.FAILED,Phase.CLEARED]:return
	phase_time+=delta;tree_bridge.tick(delta);_update_bridge_preview()
	if impact_time>0:
		impact_time=maxf(0,impact_time-delta)
		impact.scale=Vector3.ONE*lerpf(1.45,.65,impact_time/.45)
		impact.material_override.set_shader_parameter("opacity",minf(1.0,impact_time/.18))
		if impact_time<=0:impact.hide()
	match phase:
		Phase.HUNT:
			_hunt(delta);_follow_sister(delta)
			hint.text="떡 바구니를 잘라 조각을 호랑이에게 주세요. %d / 3 · 나무 조각으로 다리를 만드세요."%fed_total
		Phase.EAT:
			_follow_sister(delta)
			tiger_base=eat_origin+Vector3.UP*sin(minf(phase_time/1.05,1)*PI)*.18
			_set_tiger_texture(eat_frames[mini(2,int(phase_time/.35))],1.7)
			tiger.material_override.set_shader_parameter("opacity",1.0)
			if phase_time>=1.05:retreat_origin=tiger_base;_enter(Phase.FED_RETREAT)
		Phase.FED_RETREAT:
			_follow_sister(delta)
			var t:=minf(phase_time/.8,1)
			tiger_base=retreat_origin.lerp(rush_from,t)+Vector3.UP*sin(PI*t)*.3
			_set_tiger_texture(eat_frames[2],1.7)
			tiger.flip_h=camera.unproject_position(rush_from).x<camera.unproject_position(retreat_origin).x
			tiger.material_override.set_shader_parameter("opacity",1.0-smoothstep(.65,1,t))
			if t>=1:
				if fed_total>=3:tiger_from=tiger_base;_enter(Phase.SLEEP_WALK)
				else:rush_started=false;_enter(Phase.HUNT)
		Phase.SLEEP_WALK:
			tiger_base=tiger_from.lerp(SLEEP_FOOT,smoothstep(0,1,minf(phase_time/1.5,1)))
			tiger.material_override.set_shader_parameter("opacity",1.0);_follow_sister(delta)
			if phase_time>=1.5:
				tiger.flip_h=false;_set_tiger_texture(textures.tiger_sleep,.95);_enter(Phase.SLEEP)
		Phase.SLEEP:
			_follow_sister(delta)
			if phase_time>=.6:rope.show();_enter(Phase.ROPE_DOWN)
		Phase.ROPE_DOWN:
			_follow_sister(delta)
			rope_bottom=ROPE_FOOT+Vector3.UP*lerpf(13,0,smoothstep(0,1,minf(phase_time/2,1)))
			_layout_rope(rope,rope_bottom,rope_top)
			if phase_time>=2:_enter(Phase.READY)
		Phase.READY:
			_follow_sister(delta)
			hint.text="호랑이가 잠들었어요. 오른쪽에 내려온 동아줄에 닿으세요."
			if world.player.position.distance_to(ROPE_FOOT)<.75:_begin_ascent()
		Phase.ASCEND:
			var t:=minf(phase_time/4.5,1)
			_place_climbers(climb_origin.lerp(ROPE_FOOT+Vector3.UP*CHASE_HEIGHT,t))
			if t>=1:
				tiger_from=SLEEP_FOOT;_enter(Phase.WAKE)
		Phase.WAKE:
			var t:=minf(phase_time/.9,1)
			tiger_base=tiger_from.lerp(ROPE_FOOT,t)+Vector3.UP*sin(t*PI)*.9
			_set_tiger_texture(frames[mini(4,int(t*5))],1.7)
			tiger.flip_h=false
			if t>=1:
				_set_tiger_texture(textures.tiger_climb,1.65)
				cut_bottom=ROPE_FOOT+Vector3.UP*(CHASE_HEIGHT-4.0)
				cut_top=cut_bottom+Vector3.UP*2.4
				rope.material_override.set_shader_parameter("cut_enabled",true)
				rope.material_override.set_shader_parameter("cut_range",Vector2((rope_top.y-cut_top.y)/13,(rope_top.y-cut_bottom.y)/13))
				_enter(Phase.CHASE)
		Phase.CHASE:
			_set_rope_shake(sin(phase_time*32.0)*.055+sin(phase_time*19.0)*.025)
			_place_climbers(ROPE_FOOT+Vector3.UP*CHASE_HEIGHT)
			rope_warning.place(camera.unproject_position(sister_base+Vector3.UP*.85))
			# The gripping paws remain below every legal cut point.
			tiger_base=(cut_bottom-Vector3.UP*(1.65*TIGER_SCALE+.9)).lerp(cut_bottom-Vector3.UP*(1.65*TIGER_SCALE+.05),minf(phase_time/CUT_SECONDS,1))
			tiger_base+=camera.global_basis.x*rope_shake*clampf((rope_top.y-cut_bottom.y)/13.0,0,1)
			hint.text="아래쪽 테두리 동아줄을 드래그해 자르세요! %.1f초"%maxf(0,CUT_SECONDS-phase_time)
			if phase_time>=CUT_SECONDS:_fail_rope()
		Phase.ESCAPE:
			escape_height+=ESCAPE_SPEED*delta
			_place_climbers(ROPE_FOOT+Vector3.UP*escape_height)
			if _climbers_above_screen():
				_enter(Phase.CLEARED);path_open=true
				world.complete_stage()
		Phase.FAILED:
			sister_base=world.player.position+camera.global_basis.x*.3
			sister.position=sister_base+camera.global_basis.y*.625
			if phase_time>=1.5:_reset_attempt()
	if phase not in [Phase.ESCAPE,Phase.CLEARED]:_place_tiger()

func _begin_ascent() -> void:
	world.dialogue.cancel();paper.locked=true
	if is_instance_valid(paper.grabbed):paper._finish_drag(false)
	world.player.input_locked=true;world.player.velocity=Vector3.ZERO
	world.player.sprite.hide();sister.hide();climb_art.show()
	climb_origin=world.player.position;_enter(Phase.ASCEND)
	hint.text="동아줄을 타고 올라갑니다."

func _place_climbers(foot:Vector3) -> void:
	world.player.position=foot-camera.global_basis.x*.18
	sister_base=foot-Vector3.UP*1.25
	sister.position=sister_base+camera.global_basis.y*.625
	climb_art.global_basis=camera.global_basis
	# Keep normal terrain depth testing; only order the siblings ahead of the rope.
	climb_art.position=foot+camera.global_basis.y*.1+camera.global_basis.z*.12
	if phase==Phase.CHASE:
		climb_art.position+=camera.global_basis.x*rope_shake*clampf((rope_top.y-foot.y)/13.0,0,1)

func _climbers_above_screen() -> bool:
	# Check every sprite corner so the younger sibling and feet also leave view.
	var half:=Vector2(climb_art.texture.get_size())*climb_art.pixel_size*.5
	var offset:=climb_art.offset*climb_art.pixel_size
	for x:float in [-half.x,half.x]:
		for y:float in [-half.y,half.y]:
			var corner:=climb_art.global_position+camera.global_basis.x*(x+offset.x)+camera.global_basis.y*(y+offset.y)
			if camera.unproject_position(corner).y>=-32:return false
	return true

func _set_rope_shake(amount:float) -> void:
	rope_shake=amount
	# Pivot at the ceiling: the painted rope, cut line and hit target agree.
	_layout_rope(rope,ROPE_FOOT+camera.global_basis.x*amount,rope_top)

func _shaken_point(point:Vector3) -> Vector3:
	return point+camera.global_basis.x*rope_shake*clampf((rope_top.y-point.y)/13.0,0,1)

func _show_impact() -> void:
	BgmPlayer.play_punch(.35)
	impact_time=.45
	impact.global_basis=camera.global_basis
	impact.scale=Vector3.ONE*.65
	impact.global_position=world.player.global_position+camera.global_basis.y*.65+camera.global_basis.z*.2
	impact.material_override.set_shader_parameter("opacity",1.0);impact.show()

func _layout_rope(sprite:Sprite3D,bottom:Vector3,top:Vector3) -> void:
	var direction:=top-bottom
	if direction.length()<.01:sprite.hide();return
	sprite.show()
	var up:=direction.normalized();var right:=camera.global_basis.z.cross(up).normalized()
	sprite.global_basis=Basis(right,up,right.cross(up).normalized())
	sprite.pixel_size=1.0
	sprite.scale=Vector3(ROPE_WIDTH/sprite.texture.get_width(),direction.length()/sprite.texture.get_height(),1)
	sprite.global_position=(bottom+top)*.5

func _unhandled_input(event:InputEvent) -> void:
	if phase!=Phase.CHASE or world.paused or world.transition.active:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:cut_start=event.position;cutting=true
		elif cutting:
			cutting=false;cut_line.clear_points()
			var a:=camera.unproject_position(_shaken_point(cut_bottom));var b:=camera.unproject_position(_shaken_point(cut_top))
			if event.position.distance_to(cut_start)>12:
				var hit:Variant=Geometry2D.segment_intersects_segment(cut_start,event.position,a,b)
				if hit!=null:
					var t:=clampf(Vector2(hit).distance_to(a)/maxf(a.distance_to(b),1),0,1)
					_cut_rope(cut_bottom.lerp(cut_top,t))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and cutting:
		cut_line.points=PackedVector2Array([cut_start,event.position]);get_viewport().set_input_as_handled()

func _cut_rope(at:Vector3) -> void:
	if phase!=Phase.CHASE:return
	tense_sound.stop()
	BgmPlayer.play_tiger_falling()
	_set_rope_shake(0.0);escape_height=CHASE_HEIGHT
	rope.material_override.set_shader_parameter("cut_enabled",false)
	var image:Image=rope.texture.get_image()
	var split:=clampi(roundi((rope_top.y-at.y)/(rope_top.y-ROPE_FOOT.y)*image.get_height()),1,image.get_height()-1)
	upper_rope.texture=ImageTexture.create_from_image(image.get_region(Rect2i(0,0,image.get_width(),split)))
	upper_rope.material_override.set_shader_parameter("illustration",upper_rope.texture)
	rope.hide();_layout_rope(upper_rope,at,rope_top)
	falling_tiger=RigidBody3D.new();falling_tiger.name="FallingTigerAndRope"
	falling_tiger.collision_layer=4;falling_tiger.collision_mask=1;falling_tiger.mass=4
	var friction:=PhysicsMaterial.new();friction.friction=0;friction.bounce=0
	falling_tiger.physics_material_override=friction;falling_tiger.linear_damp=.05
	add_child(falling_tiger);falling_tiger.global_position=tiger_base
	var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
	shape.radius=.23;shape.height=1.2;collision.shape=shape;collision.position.y=.6;falling_tiger.add_child(collision)
	_set_tiger_texture(textures.tiger_fall,1.65);_place_tiger();tiger.reparent(falling_tiger,true)
	# Severed objects return to per-fragment terrain occlusion while falling.
	tiger.remove_meta("story_layer")
	tiger.material_override.render_priority=0
	tiger.material_override.set_shader_parameter("clip_to_slice",true)
	var lower_texture:=ImageTexture.create_from_image(image.get_region(Rect2i(0,split,image.get_width(),image.get_height()-split)))
	var lower:=_picture("SeveredRope",lower_texture,ROPE_FOOT,1)
	_layout_rope(lower,ROPE_FOOT,at);lower.reparent(falling_tiger,true)
	var rope_shape:=CollisionShape3D.new();var rope_box:=BoxShape3D.new()
	rope_box.size=Vector3(.3,at.y-ROPE_FOOT.y,.3);rope_shape.shape=rope_box
	falling_tiger.add_child(rope_shape);rope_shape.global_position=(ROPE_FOOT+at)*.5
	# The rope hangs outside the ledge. Fall vertically through the ridge layers.
	falling_tiger.linear_velocity=Vector3(.1,-.4,0);falling_tiger.angular_velocity=Vector3(0,0,-.12)
	BgmPlayer.play_cut()
	hint.text="동아줄을 잘랐어요! 오누이가 하늘로 올라갑니다.";_enter(Phase.ESCAPE)

func _fail_rope() -> void:
	_set_rope_shake(0.0)
	rope.material_override.set_shader_parameter("cut_enabled",false)
	cut_line.clear_points();cutting=false
	world.player.input_locked=false;world.player.prevent_walk_off_edges=false
	world.player.sprite.show();sister.show();climb_art.hide()
	world.player.apply_knockback(Vector3(4,1,1),.6);world.player.velocity.y=-2
	_show_impact()
	paper.locked=true;_enter(Phase.FAILED)
	hint.text="호랑이에게 밀렸어요. 먹인 떡은 유지한 채 다시 시작합니다."

func can_complete() -> bool:
	return false # Rope escape, rather than the former goal tile, triggers clear.

func clear_animation_finished() -> bool:
	return phase==Phase.CLEARED
