extends MeshInstance3D
signal moved_aside
## Rigged flight, followed by an eight-frame rain-weakened posture change.
const CENTER := Vector2(.74,.375)
const HEIGHT_FRACTION := .68
const DEPTH := 18.0
const HOVER_AMPLITUDE := .14
const HOVER_PERIOD := 4.8
var world: GridStageWorld
var frames: Dictionary
var clock := 0.0
var current_frame := -1
var base_position := Vector3.ZERO
var layout_state: Array = []
var ink: ShaderMaterial
const DRAGON_RIG = preload("res://scripts/finalstage/dragon_rig.gd")
var rig: DRAGON_RIG
var weakening := false
var weakening_time := 0.0
var weakening_frames: Array[Texture2D] = []
var sag_bend := Vector2.ZERO
var start_center := Vector3.ZERO
var start_height := 0.0
var weak_frame := -1
const NORMAL_ART = preload("res://art/finalstage/dragon_normal_selected_8frames.png")
const SAG_ART = preload("res://art/finalstage/kkwangcheol_sag_reference.png")
var gift_received := false
var gift_time := 0.0
var gift_origin := Vector3.ZERO
var gift_height := 0.0
var gift_hold: Texture2D
var gift_flight: Array[Texture2D] = []
var aside_sent := false
var normal_frames: Array[Texture2D] = []
var clean_bounds: Dictionary
var flight_aspect := 1.0

func configure(owner_world: GridStageWorld) -> void:
	world = owner_world
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/finalstage/dragon-normal-selected-frames.json"))
	clean_bounds=JSON.parse_string(FileAccess.get_file_as_string("res://art/finalstage/dragon-clean-frame-bounds.json"))
	_load_normal_art()
	_load_weakening_frames()
	_load_gift_art()
	moved_aside.connect(Callable(world.story,"on_dragon_moved_aside"))
	rig = DRAGON_RIG.new()
	rig.name = "DragonSkeleton"
	add_child(rig)
	mesh = rig.build()
	skeleton = NodePath("DragonSkeleton")
	skin = rig.create_skin_from_rest_transforms()
	ink = ShaderMaterial.new()
	ink.shader = preload("res://scripts/finalstage/kkwangcheol.gdshader")
	ink.set_shader_parameter("illustration",NORMAL_ART)
	material_override = ink
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = HOVER_AMPLITUDE
	custom_aabb = AABB(Vector3(-.65,-.65,-.1),Vector3(1.3,1.3,.2))
	_layout()
	_set_frame(0)

func _load_normal_art() -> void:
	var sheet := NORMAL_ART.get_image()
	if sheet.is_compressed():sheet.decompress()
	for index in range(8):
		var bounds: Array = clean_bounds.normal[index]
		var image := sheet.get_region(Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]))
		var isolated := Image.create_empty(image.get_width()+8,image.get_height()+8,false,Image.FORMAT_RGBA8)
		for run: Array in clean_bounds.normal_keep_runs[index]:
			isolated.blit_rect(image,Rect2i(run[1],run[0],run[2],1),Vector2i(run[1]+4,run[0]+4))
		normal_frames.append(ImageTexture.create_from_image(isolated))
	# Separate textures prevent filtering from sampling another atlas cell.
	frames.occupied_height=1.0;frames.frame_aspect=clean_bounds.normal_aspect
	for index in range(8):frames.bounds[index]=[0.0,0.0,1.0,1.0]

func _load_gift_art() -> void:
	var hold := preload("res://art/finalstage/dragon_peach_hold.png").get_image()
	if hold.is_compressed():hold.decompress()
	gift_hold=ImageTexture.create_from_image(hold.get_region(hold.get_used_rect()))
	var sheet := preload("res://art/finalstage/dragon_peach_flight_8frames.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	for bounds: Array in clean_bounds.flight:
		var cell := sheet.get_region(Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]))
		gift_flight.append(ImageTexture.create_from_image(cell))
	flight_aspect=float(clean_bounds.flight_aspect)

func offer_peach(screen: Vector2) -> bool:
	if not weakening or gift_received:return false
	var point := global_transform.affine_inverse()*world.camera.project_position(screen,DEPTH)
	var uv := Vector2(point.x+.5,.5-point.y)
	if not Rect2(0,.05,.55,.48).has_point(uv):return false
	gift_received=true;gift_time=0
	BgmPlayer.set_boss_clear_level(0)
	gift_origin=global_position;gift_height=scale.y
	ink.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
	_layout_gift()
	return true

func _layout_gift() -> void:
	var texture: Texture2D = gift_hold
	var t := clampf((gift_time-2.0)/2.4,0,1)
	if gift_time>=2.0:texture=gift_flight[int((gift_time-2.0)*8.0)%8]
	ink.set_shader_parameter("illustration",texture)
	var camera := world.camera
	var destination := camera.project_position(get_viewport().get_visible_rect().size*Vector2(.90,.42),DEPTH)
	var ease := smoothstep(0,1,t)
	var height := lerpf(gift_height,camera.size*.58,ease)
	global_basis=camera.global_basis
	var aspect := flight_aspect if gift_time>=2.0 else float(texture.get_width())/texture.get_height()
	scale=Vector3(height*aspect,height,1)
	global_position=gift_origin.lerp(destination,ease)+camera.global_basis.y*(sin(t*PI)*.4)
	if t>=1 and not aside_sent:
		aside_sent=true;moved_aside.emit()

func _load_weakening_frames() -> void:
	var sheet := preload("res://art/finalstage/kkwangcheol_weakening_8frames_v2.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	for index in range(8):
		var column := index%4
		var row := floori(index/4.0)
		var first := Vector2i(roundi(column*sheet.get_width()/4.0),roundi(row*sheet.get_height()/2.0))
		var last := Vector2i(roundi((column+1)*sheet.get_width()/4.0),roundi((row+1)*sheet.get_height()/2.0))
		var cell := sheet.get_region(Rect2i(first,last-first))
		weakening_frames.append(ImageTexture.create_from_image(cell.get_region(cell.get_used_rect())))
	var image := SAG_ART.get_image()
	if image.is_compressed():image.decompress()
	var bounds := image.get_used_rect()
	sag_bend=(Vector2(image.get_size())*Vector2(.80,.34)-Vector2(bounds.position))/Vector2(bounds.size)
	# The eighth pose uses the supplied master exactly, without a final texture jump.
	weakening_frames[7]=ImageTexture.create_from_image(image.get_region(bounds))

func begin_weakening() -> void:
	if weakening:return
	weakening=true;weakening_time=0
	var bounds: Array = frames.bounds[current_frame]
	var center := Vector2(bounds[0]+bounds[2]*.5,bounds[1]+bounds[3]*.5)
	start_center=global_position+world.camera.global_basis.x*((center.x-.5)*scale.x)-world.camera.global_basis.y*((center.y-.5)*scale.y)
	start_height=scale.y*float(bounds[3])
	skeleton=NodePath("");skin=null
	rig.queue_free();rig=null
	var quad := QuadMesh.new();quad.size=Vector2.ONE;mesh=quad
	ink.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
	_layout_weakening()

func _layout_weakening() -> void:
	var t := smoothstep(0,1,clampf(weakening_time/1.6,0,1))
	var index := mini(int(weakening_time*8.0/1.6),7)
	var texture: Texture2D = weakening_frames[index]
	if index!=weak_frame:
		weak_frame=index;ink.set_shader_parameter("illustration",texture)
	var camera := world.camera
	var bounds: Array = world.stage_data.raised[0]
	var last: Vector3i = bounds[1]
	var edge := Vector3(last.x*.2,world.stage_data.goal_height,-1.0)
	var target_height := start_height
	var final_texture: Texture2D = weakening_frames[7]
	var target_width := target_height*final_texture.get_width()/final_texture.get_height()
	var contact := camera.project_position(camera.unproject_position(edge),DEPTH)
	var destination := contact+camera.global_basis.x*((.5-sag_bend.x)*target_width)+camera.global_basis.y*((sag_bend.y-.5)*target_height)
	var height := lerpf(start_height,target_height,t)
	global_basis=camera.global_basis
	scale=Vector3(height*texture.get_width()/texture.get_height(),height,1)
	global_position=start_center.lerp(destination,t)

func _layout() -> void:
	var camera := world.camera
	var viewport_size := get_viewport().get_visible_rect().size
	var state: Array = [camera.global_transform,camera.size,viewport_size]
	if state == layout_state: return
	layout_state = state
	var height := camera.size*HEIGHT_FRACTION/float(frames.occupied_height)
	global_basis = camera.global_basis
	scale = Vector3(height*float(frames.frame_aspect),height,1)
	base_position = camera.project_position(viewport_size*CENTER,DEPTH)
	global_position = base_position

func _set_frame(index: int) -> void:
	if current_frame == index: return
	current_frame = index
	ink.set_shader_parameter("illustration",normal_frames[index])
	ink.set_shader_parameter("frame_uv",Vector4(0,0,1,1))

func _process(delta: float) -> void:
	if world.paused or world.transition.active: return
	if gift_received:
		gift_time+=delta
		_layout_gift()
		return
	if weakening:
		weakening_time+=delta
		_layout_weakening()
		return
	clock += delta
	_layout()
	_set_frame(int(floor(clock*6.0))%8)
	rig.animate(clock)
	global_position = base_position+world.camera.global_basis.y*(sin(clock*TAU/HOVER_PERIOD)*HOVER_AMPLITUDE)
