extends "res://scripts/grid_stage/folktale_story.gd"
# Stage 8 keeps the shared closest-NPC/E/speech presentation. Only its authored
# puzzle: cut bough -> flight -> regrowth -> ten arrivals -> reunion.
const ART:="res://art/minhwa/gyeonwu_rework/"
const BRANCH=preload("res://scripts/grid_stage/gyeonwu_branch.gd")
const VARIANTS:=["magpie_ink","magpie_jade","magpie_blue","bird_sparrow","bird_oriole","bird_crow"]
const REQUIRED_BIRDS:=10
const REUNION_SECONDS:=5.0
const REUNION_LINE:="사랑해요 견우, 사랑해요 직여\n고마워요 도와줘서."
const FLIGHT_SECONDS:=2.2
const LANDING_SECONDS:=.7
const GYEONWU_LINE:="직녀를 만나러 가고싶어..."
# Foot pivots measured in a normalized 640-unit reference cell keep the bird on its perch as
# differently spread wings change the painted bounds. They are not crop boxes.
const FOOT_PIVOTS:=[
	[Vector2(225,574),Vector2(222,574),Vector2(222,480),Vector2(222,480)],
	[Vector2(198,544),Vector2(198,544),Vector2(198,470),Vector2(198,470)],
	[Vector2(214,540),Vector2(214,540),Vector2(214,445),Vector2(214,445)],
	[Vector2(245,605),Vector2(245,605),Vector2(245,505),Vector2(245,505)],
	[Vector2(210,544),Vector2(210,544),Vector2(210,490),Vector2(210,490)],
	[Vector2(218,595),Vector2(218,595),Vector2(218,480),Vector2(218,480)]
]
# Blue markings in the supplied screenshot, normalized inside the game view.
const PERCH_ANCHORS:=[Vector2(.115,.40),Vector2(.90,.285),Vector2(.958,.275),Vector2(.915,.47)]
var perches:Array[Dictionary]=[]
var flock:Array[Dictionary]=[]
var bird_frames:Dictionary={}
var bird_sheets:Dictionary={}
var bird_quad:Texture2D
var arrived_count:=0
var released_count:=0
var animation_clock:=0.0
var bridge_collision:CollisionShape3D
var reunion_state:="waiting"
var reunion_clock:=0.0
var reunion_paths:Dictionary={}
var walk_frames:Dictionary={}
# Painted figures cross the nominal x=512 / y=768 grid. Split in the actual
# transparent gutters instead, then anchor each independent frame at its feet.
const WALK_REGIONS:=[Rect2i(0,0,560,752),Rect2i(560,0,464,752),Rect2i(0,752,560,784),Rect2i(560,752,464,784)]
const WALK_FEET:={
	"gyeonwu":[Vector2(300,735),Vector2(775,735),Vector2(298,1490),Vector2(770,1490)],
	"jiknyeo":[Vector2(230,732),Vector2(745,736),Vector2(235,1478),Vector2(745,1478)]}
var starlight:Node3D
var wing_sound:AudioStreamPlayer

func _setup_birds() -> void:
	wing_sound=AudioStreamPlayer.new()
	var sound:AudioStreamMP3=load("res://music/bird-8.mp3").duplicate()
	sound.loop=true;wing_sound.stream=sound
	wing_sound.volume_db=BgmPlayer.BASE_VOLUME_DB
	add_child(wing_sound)
	routes.assign(world.stage_data.bird_bridges)
	# Retain the original floor chart, but remove its old edge birds and giant
	# cuttable birds. New bare boughs occupy the marked red areas instead.
	var chart_source:=_texture(BIRDS+"remove_background-5.png")
	var chart_region:=AtlasTexture.new();chart_region.atlas=chart_source
	chart_region.region=Rect2(12,158,820,820)
	var floor_center:=Vector3(world.stage_data.focus.x,-1.2,world.stage_data.focus.z)
	var chart:=_picture("star_chart",chart_region,floor_center,camera.size*1.32)
	chart.material_override.render_priority=-64
	starlight=preload("res://scripts/grid_stage/chart_starlight.gd").new()
	chart.add_child(starlight);starlight.configure(chart)
	_load_bird_frames()
	var branch_texture:=_texture(ART+"perch_branch.png")
	var frame_size:=get_viewport().get_visible_rect().size
	var depth:float=(camera.global_position-Vector3(world.stage_data.focus)).dot(camera.global_basis.z)
	for i in range(PERCH_ANCHORS.size()):
		var branch:=BRANCH.new();branch.name="PerchBranch%d"%i;add_child(branch)
		var height:float=camera.size*[.55,.31,.23,.49][i]
		branch.configure(world,branch_texture,height,i>0)
		branch.global_basis=camera.global_basis
		var foot:=camera.project_position(PERCH_ANCHORS[i]*frame_size,depth)
		branch.global_position+=foot-branch.point_at(Vector2(.55,.505))
		var variant:int=[0,3,5,1][i]
		var perch:Dictionary={"branch":branch,"variant":variant,"state":"perched","clock":0.0,"bird":null,"cycle":0}
		perches.append(perch)
		perch.bird=_new_bird(variant,branch.point_at(Vector2(.55,.505)),i==0)
	_setup_person("gyeonwu",Vector3(-2.4,1.8,0),1.65)
	_setup_person("jiknyeo",Vector3(.8,3.6,-4.2),1.65)
	_create_dialogue("gyeonwu")
	_load_walk_frames()
	var midpoint:Vector3=(Vector3(routes[0][0])+Vector3(routes[0][1]))*.5
	var embrace:=_picture("reunited_couple",_texture(ART+"couple_embrace.png"),midpoint+camera.global_basis.y*1.65*.46,1.65)
	embrace.material_override.render_priority=0;embrace.hide()
	items.reunited_couple.feet=midpoint;items.reunited_couple.height=1.65
	_create_dialogue("reunited_couple")

func _setup_person(id:String,feet:Vector3,height:float) -> void:
	var actor:=_picture(id,_texture(ART+id+".png"),feet+camera.global_basis.y*height*.48,height)
	actor.material_override.render_priority=0
	items[id]["feet"]=feet;items[id]["height"]=height

func _load_walk_frames() -> void:
	for id:String in ["gyeonwu","jiknyeo"]:
		var source:Image=_texture(ART+id+"_walk.png").get_image()
		if source.is_compressed():source.decompress()
		var frames:Array[Dictionary]=[]
		for index in range(4):
			var rect:Rect2i=WALK_REGIONS[index]
			var frame_image:=source.get_region(rect)
			frame_image.generate_mipmaps()
			frames.append({"texture":ImageTexture.create_from_image(frame_image),"size":Vector2(rect.size),"pivot":Vector2(WALK_FEET[id][index])-Vector2(rect.position)})
		walk_frames[id]=frames

func _pose_walker(id:String,foot:Vector3,phase:int) -> void:
	var actor:Sprite3D=items[id].sprite
	var frame:Dictionary=walk_frames[id][phase]
	if int(items[id].walk_phase)!=phase:
		actor.material_override.set_shader_parameter("illustration",frame.texture)
		items[id].walk_phase=phase
	var unit:float=float(items[id].height)/740.0
	var size:Vector2=frame.size*unit
	var pivot:Vector2=frame.pivot
	if actor.flip_h:pivot.x=float(frame.size.x)-pivot.x
	actor.global_basis=camera.global_basis.scaled(Vector3(size.x,size.y,1))
	actor.global_position=foot+camera.global_basis.x*(float(frame.size.x)*.5-pivot.x)*unit+camera.global_basis.y*(pivot.y-float(frame.size.y)*.5)*unit
	items[id].feet=foot

func _load_bird_frames() -> void:
	var pixel:=Image.create(1,1,false,Image.FORMAT_RGBA8);pixel.fill(Color.WHITE)
	bird_quad=ImageTexture.create_from_image(pixel)
	for variant:String in VARIANTS:
		bird_sheets[variant]=_texture(ART+variant+".png")
		var frames:Array[Vector4]=[]
		for index in range(4):
			frames.append(Vector4((index%2)*.5,(index/2)*.5,.5,.5))
		bird_frames[variant]=frames

func _new_bird(variant:int,feet:Vector3,flip:bool) -> Dictionary:
	var id:="perched_bird_%d"%items.size()
	var frames:Array=bird_frames[VARIANTS[variant]]
	var height:float=camera.size*.115
	# Fixed geometry and one shared atlas per variant. Only UV uniforms change.
	var sprite:=_picture(id,bird_quad,feet,height)
	sprite.material_override.set_shader_parameter("illustration",bird_sheets[VARIANTS[variant]])
	sprite.material_override.set_shader_parameter("frame_region",frames[0])
	items[id]["managed_pose"]=true
	sprite.flip_h=flip;sprite.material_override.render_priority=0
	var bird:Dictionary={"sprite":sprite,"variant":variant,"base_pixel":sprite.pixel_size,"height":height,"phase":0,"feet":feet,"pivot":feet,"scale":1.0}
	_position_bird(bird,feet)
	return bird

func _position_bird(bird:Dictionary,position:Vector3) -> void:
	var sprite:Sprite3D=bird.sprite
	var pivot:Vector2=FOOT_PIVOTS[int(bird.variant)][int(bird.phase)]/640.0
	if sprite.flip_h:pivot.x=1.0-pivot.x
	var size:Vector2=sprite.texture.get_size()*sprite.pixel_size*float(bird.scale)
	sprite.global_basis=camera.global_basis.scaled(Vector3.ONE*float(bird.scale))
	sprite.global_position=position+camera.global_basis.x*(.5-pivot.x)*size.x+camera.global_basis.y*(pivot.y-.5)*size.y
	bird.pivot=position

func _set_frame(bird:Dictionary,index:int) -> void:
	if int(bird.phase)==index:return
	var sprite:Sprite3D=bird.sprite
	var frames:Array=bird_frames[VARIANTS[int(bird.variant)]]
	sprite.material_override.set_shader_parameter("frame_region",frames[index])
	bird.phase=index

func cut_at(a:Vector2,b:Vector2) -> bool:
	if _interaction_locked():return false
	var changed:=false
	for perch:Dictionary in perches:
		if perch.state!="perched":continue
		if perch.branch.cut(a,b):
			_depart(perch);changed=true
	return changed

func drop_item(_id:String,_target:String) -> bool:
	# Birds are never cut, dragged or matched to invisible bridge slots.
	return false

func _depart(perch:Dictionary) -> void:
	var bird:Dictionary=perch.bird
	var sprite:Sprite3D=bird.sprite
	var serial:=released_count;released_count+=1
	var a:Vector3=routes[0][0];var b:Vector3=routes[0][1]
	var center:Vector3=a.lerp(b,.03+float(serial%REQUIRED_BIRDS)/float(REQUIRED_BIRDS-1)*.94)
	# The first ten birds gather across the future deck, at 1/3 size.
	# Keep backs level with the walkable ramp; the drawn feet sit below it.
	var destination:Vector3=center+Vector3.RIGHT*(float(serial%3)-1)*.22-camera.global_basis.y*(float(bird.height)/3.0*.38)
	if serial>=REQUIRED_BIRDS:
		destination+=Vector3.RIGHT*(1.0 if serial%2==0 else -1.0)
	flock.append({"bird":bird,"from":bird.pivot,"to":destination,"clock":0.0,"arrived":false,"serial":serial,"perch":perch})
	sprite.flip_h=camera.unproject_position(destination).x>camera.unproject_position(bird.pivot).x
	_position_bird(bird,bird.pivot)
	perch.state="flight";perch.clock=0.0

func _process(delta:float) -> void:
	super._process(delta)
	if is_instance_valid(wing_sound):
		wing_sound.stream_paused=world.paused or world.transition.active

func _advance_birds(delta:float) -> void:
	var flapping:=not flock.is_empty()
	animation_clock+=delta
	for flight:Dictionary in flock:
		var bird:Dictionary=flight.bird;var sprite:Sprite3D=bird.sprite
		if not flight.arrived:
			flight.clock+=delta
			var t:=clampf(float(flight.clock)/FLIGHT_SECONDS,0,1)
			var eased:=smoothstep(0,1,t)
			bird.scale=lerpf(1.0,1.0/3.0,eased)
			_set_frame(bird,int(animation_clock*9)%4)
			_position_bird(bird,Vector3(flight.from).lerp(flight.to,eased)+Vector3.UP*sin(t*PI)*1.2)
			if t>=1.0:
				flight.arrived=true;arrived_count+=1
				var perch:Dictionary=flight.perch
				perch.state="growing";perch.clock=0.0;perch.branch.begin_regrowth()
				if arrived_count>=REQUIRED_BIRDS and bridges.is_empty():_build_bridge(0)
		else:
			var phase:=int(animation_clock*7+int(flight.serial))%4
			if phase!=int(bird.phase):
				_set_frame(bird,phase);_position_bird(bird,flight.to)
	for perch:Dictionary in perches:
		match String(perch.state):
			"perched":
				# Four actual painted frames; short wing stretches between rests.
				var cycle:=fmod(animation_clock+float(perch.variant)*.37,4.0)
				var phase:=0 if cycle<3.45 else 1+mini(2,int((cycle-3.45)*6))
				if phase>0:flapping=true
				if phase!=int(perch.bird.phase):
					_set_frame(perch.bird,phase);_position_bird(perch.bird,perch.bird.feet)
			"growing":
				if perch.branch.advance_regrowth(delta):
					perch.variant=(int(perch.variant)+1)%VARIANTS.size();perch.cycle+=1
					var foot:Vector3=perch.branch.point_at(Vector2(.55,.505))
					perch.bird=_new_bird(int(perch.variant),foot,not perch.branch.mirrored)
					perch.bird.sprite.material_override.set_shader_parameter("opacity",0.0)
					_position_bird(perch.bird,foot+camera.global_basis.y*.85)
					perch.state="landing";perch.clock=0.0
			"landing":
				flapping=true
				perch.clock+=delta
				var t:=clampf(float(perch.clock)/LANDING_SECONDS,0,1)
				var bird:Dictionary=perch.bird;var sprite:Sprite3D=bird.sprite
				sprite.material_override.set_shader_parameter("opacity",smoothstep(0,.3,t))
				_set_frame(bird,int(animation_clock*9)%4)
				if t>=1:perch.state="perched";_set_frame(bird,0)
				_position_bird(bird,Vector3(bird.feet)+camera.global_basis.y*(1-smoothstep(0,1,t))*.85)
	if flapping:
		if not wing_sound.playing:wing_sound.play()
	else:wing_sound.stop()
	if chart_spinning:chart_angle=wrapf(chart_angle+TAU*delta/CHART_TURN_SECONDS,0,TAU)
	_advance_reunion(delta)
	starlight.advance(delta)

func _build_bridge(index:int) -> void:
	if arrived_count<REQUIRED_BIRDS or bridges.has(index):return
	var a:Vector3=routes[index][0];var b:Vector3=routes[index][1]
	var direction:Vector3=(b-a).normalized()
	var right:Vector3=direction.cross(Vector3.UP).normalized()
	var up:Vector3=right.cross(direction).normalized()
	var body:=StaticBody3D.new();body.name="OjakgyoBridge";body.collision_layer=1;body.collision_mask=2
	bridge_collision=CollisionShape3D.new()
	bridge_collision.disabled=true
	var box:=BoxShape3D.new();box.size=Vector3(.8,.18,a.distance_to(b))
	bridge_collision.shape=box;body.add_child(bridge_collision);add_child(body)
	body.position=(a+b)*.5-up*.09;body.basis=Basis(right,up,-direction);bridges[index]=body
	# Birds supply the visible bridge; walking collision opens after the reunion.
	path_open=false;chart_spinning=true
	_start_reunion()

func _start_reunion() -> void:
	if reunion_state!="waiting":return
	cancel_dialogue();reunion_state="walking";reunion_clock=0.0
	var a:Vector3=routes[0][0];var b:Vector3=routes[0][1]
	var middle:=a.lerp(b,.5)
	reunion_paths={
		"gyeonwu":PackedVector3Array([items.gyeonwu.feet,Vector3(0,a.y,0),a,middle]),
		"jiknyeo":PackedVector3Array([items.jiknyeo.feet,Vector3(0,b.y,-3.0),b,middle])}
	for id:String in reunion_paths:
		var actor:Sprite3D=items[id].sprite
		# One fixed unit quad; pre-sliced textures change only at eight fps.
		actor.texture=bird_quad;actor.pixel_size=1.0
		actor.material_override.set_shader_parameter("frame_region",Vector4(0,0,1,1))
		items[id].managed_pose=true;items[id].walk_phase=-1
		_pose_walker(id,items[id].feet,0)

func _advance_reunion(delta:float) -> void:
	if reunion_state!="walking":return
	reunion_clock+=delta
	var progress:=clampf(reunion_clock/REUNION_SECONDS,0,1)
	for id:String in reunion_paths:
		var path:PackedVector3Array=reunion_paths[id]
		var total:=0.0
		for i in range(1,path.size()):total+=path[i-1].distance_to(path[i])
		var remaining:=progress*total
		var foot:Vector3=path[path.size()-1]
		var direction:=Vector3.ZERO
		for i in range(1,path.size()):
			var length:=path[i-1].distance_to(path[i])
			if remaining<=length:
				foot=path[i-1].lerp(path[i],remaining/maxf(length,.001));direction=path[i]-path[i-1];break
			remaining-=length
		var actor:Sprite3D=items[id].sprite
		var faces_right:=direction.dot(camera.global_basis.x)>0
		actor.flip_h=not faces_right if id=="gyeonwu" else faces_right
		var phase:=int(reunion_clock*8)%4
		_pose_walker(id,foot,phase)
	if progress>=1:
		items.reunited_couple.sprite.show()
		items.gyeonwu.sprite.hide();items.jiknyeo.sprite.hide()
		reunion_state="embracing"
		BgmPlayer.play_bridge_reunion()
		bridge_collision.set_deferred("disabled",false)
		path_open=true
		starlight.start_twinkle()

func _nearest_speaker() -> String:
	if reunion_state=="walking":return ""
	return super._nearest_speaker()

func interact() -> bool:
	if _interaction_locked():return false
	var speaker:=_nearest_speaker()
	if speaker.is_empty():return false
	if speech_bubbles[speaker].active:return true
	cancel_dialogue()
	var bubble:Dictionary=speech_bubbles[speaker]
	bubble.label.text=REUNION_LINE if speaker=="reunited_couple" else GYEONWU_LINE
	bubble.panel.fit_to_text()
	bubble.active=true;bubble.elapsed=0.0
	bubble.panel.modulate.a=0;_layout_dialogue()
	return true
