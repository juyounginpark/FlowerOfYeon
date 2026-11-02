extends Node3D
signal collapsed
## One continuous cuboid until the left-hand volume breaks away.
var world: GridStageWorld
var intact: Node3D
var core: StaticBody3D
var fragment: RigidBody3D
var core_art: Node3D
var fragment_art: Node3D
var triggered := false
var cut_x := 0.0
var roof := 0.0
var fake_exit := Vector3.ZERO
var warning := false
var warning_remaining := 1.0
var shake_remaining := 0.0
var shake_clock := 0.0
var dialogue_shake := false
var battle_shake := false

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	process_priority=-10
	var bounds: Array = world.stage_data.raised[0]
	var first: Vector3i = bounds[0]
	var last: Vector3i = bounds[1]
	var cut := first.x+16
	cut_x=cut*.2;roof=last.y*.2
	fake_exit=world.stage_data.fake_exit
	core=StaticBody3D.new();core.name="RemainingMap";add_child(core)
	_add_collision(core,Vector3i(cut,first.y,first.z),last)
	core_art=_cuboid(Vector3i(cut,first.y,first.z),last)
	core.add_child(core_art);core_art.hide()
	fragment=RigidBody3D.new();fragment.name="FallingCuboid"
	fragment.freeze=true;fragment.collision_layer=4;fragment.collision_mask=1
	fragment.mass=12;fragment.gravity_scale=1;fragment.continuous_cd=true
	fragment.linear_damp=.05;fragment.angular_damp=.8
	add_child(fragment)
	var fragment_last := Vector3i(cut,last.y,last.z)
	fragment.position=(Vector3(first)+Vector3(fragment_last))*.1
	_add_collision(fragment,first,fragment_last)
	fragment_art=_cuboid(first,fragment_last)
	fragment.add_child(fragment_art);fragment_art.position=-fragment.position
	fragment_art.hide()
	intact=_cuboid(first,last);add_child(intact)
	# The decoy uses the same floor mark as the actual goal, without a clear trigger.
	_mark(core,Vector3(world.stage_data.goal_rect.get_center().x,roof,world.stage_data.goal_rect.get_center().y))
	_mark(fragment,fake_exit)

func _add_collision(body: PhysicsBody3D,first: Vector3i,last: Vector3i) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new();box.size=Vector3(last-first)*.2
	collision.shape=box
	body.add_child(collision)
	collision.global_position=(Vector3(first)+Vector3(last))*.1

func _cuboid(first: Vector3i,last: Vector3i) -> Node3D:
	var art := Node3D.new()
	var surface := MeshInstance3D.new()
	var box := BoxMesh.new();box.size=Vector3(last-first)*.2
	surface.mesh=box;surface.position=(Vector3(first)+Vector3(last))*.1
	var ink := ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_surface.gdshader")
	surface.material_override=ink;art.add_child(surface)
	# Reuse the map's paper edge ornaments, without filling thousands of interior voxels.
	var planes: Dictionary = {}
	var center := surface.position
	for normal: Vector3 in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var u := Vector3.RIGHT if absf(normal.y)>.5 else Vector3.UP
		var v := normal.cross(u)
		var face := center+normal*box.size.dot(normal.abs())*.5
		var corner := face-u*box.size.dot(u.abs())*.5-v*box.size.dot(v.abs())*.5
		var cells: Dictionary = {}
		var begin := Vector2i(roundi(corner.dot(u)*5),roundi(corner.dot(v)*5))
		for x in range(roundi(box.size.dot(u.abs())*5)):
			for y in range(roundi(box.size.dot(v.abs())*5)):cells[begin+Vector2i(x,y)]=true
		planes[normal]={"normal":normal,"u":u,"v":v,"plane":roundi(face.dot(normal)*5),"cells":cells}
	var trims: Array = preload("res://scripts/grid_stage/paper_trim.gd").build(planes)
	for index in range(trims.size()):
		if trims[index]==null:continue
		var trim := MeshInstance3D.new();trim.mesh=trims[index]
		var trim_ink := ShaderMaterial.new();trim_ink.shader=preload("res://shaders/grid_paper_trim.gdshader")
		trim_ink.set_shader_parameter("corner",index==1)
		trim_ink.set_shader_parameter("corner_image",preload("res://art/materials/hanji/ornament_corner.svg"))
		trim.material_override=trim_ink;art.add_child(trim)
	return art

func _mark(parent: Node3D,point: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var quad := QuadMesh.new();quad.size=Vector2.ONE
	marker.mesh=quad;marker.rotation.x=-PI*.5
	var ink := StandardMaterial3D.new()
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color=Color("f3e7ce").lerp(Color("bf9784"),.28)
	marker.material_override=ink;parent.add_child(marker)
	marker.global_position=point+Vector3.UP*.008

func _physics_process(delta: float) -> void:
	var locked: bool = world.paused or world.transition.active or world.completed
	fragment.freeze=not triggered or locked
	if triggered or locked or world.player.input_locked:return
	if warning:
		warning_remaining-=delta
		if warning_remaining<=0:_collapse()
		return
	var player := world.player
	var offset := Vector2(player.position.x-fake_exit.x,player.position.z-fake_exit.z)
	if not player.is_on_floor() or absf(player.position.y-roof)>.12 or offset.length()>.8:return
	warning=true

func _collapse() -> void:
	BgmPlayer.play_boss_collapse()
	triggered=true;warning=false;shake_remaining=3.0
	intact.hide();core_art.show();fragment_art.show()
	fragment.freeze=false
	fragment.linear_velocity=Vector3(-.8,0,0)
	fragment.angular_velocity=Vector3(0,0,-.12)
	var landing := Vector3(cut_x+1.2,roof,world.player.position.z)
	world.player.call("rebound_to",landing)
	collapsed.emit()

func _process(delta: float) -> void:
	var locked: bool = world.paused or world.transition.active or world.completed
	if not locked:
		shake_clock+=delta
		shake_remaining=maxf(0,shake_remaining-delta)
	var shaking: bool = not locked and (warning or shake_remaining>0 or dialogue_shake or battle_shake)
	var ambient := .018 if dialogue_shake else .03 if battle_shake else 0.0
	var strength := .065 if warning else maxf(ambient,.11*minf(shake_remaining,1.0))
	world.camera.h_offset=(sin(shake_clock*71.0)+sin(shake_clock*113.0)*.4)*strength if shaking else 0.0
	world.camera.v_offset=sin(shake_clock*89.0)*strength*.75 if shaking else 0.0

func shake(seconds: float) -> void:
	shake_remaining=maxf(shake_remaining,seconds)

func stop_shake() -> void:
	shake_remaining=0;dialogue_shake=false;battle_shake=false
	world.camera.h_offset=0;world.camera.v_offset=0

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.camera):
		world.camera.h_offset=0;world.camera.v_offset=0
