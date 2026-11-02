extends MeshInstance3D
## Supplied 4x2 sheet: dancers circle in eight successive poses.
var world: GridStageWorld
var clock := 0.0
var rising := false
var frame := -1
var ink: ShaderMaterial
const NOTES = preload("res://scripts/finalstage/music_notes.gd")
var notes: NOTES
var circling := false
var circle_time := 0.0

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	var quad := QuadMesh.new()
	quad.size=Vector2(.75,1)*world.camera.size*.30
	mesh=quad
	ink=ShaderMaterial.new()
	ink.shader=preload("res://scripts/finalstage/pungmul_foreground.gdshader")
	ink.render_priority=127
	ink.set_shader_parameter("illustration",preload("res://art/finalstage/pungmul_dance_8frames.png"))
	material_override=ink
	set_meta("slice_whole",true);set_meta("screen_band",11)
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var overlay := CanvasLayer.new();overlay.layer=8;add_child(overlay)
	notes=NOTES.new();overlay.add_child(notes);notes.configure(world,self)
	hide()

func receive_instrument(all_received: bool) -> void:
	notes.emit_notes()
	if all_received:
		circling=true;circle_time=0
		notes.looping=true

func begin_rise() -> void:
	if rising:return
	rising=true;clock=0
	BgmPlayer.start_boss_clear()
	show();_layout()

func _layout() -> void:
	var t := smoothstep(0,1,clampf(clock/2.4,0,1))
	var center := Vector2(.19,lerpf(1.24,.83,t))
	if circling:
		var angle := PI*.5+circle_time*TAU/8.0
		var target := Vector2(.285,.45)+Vector2(cos(angle)*.075,sin(angle)*.17)
		center=Vector2(.19,.83).lerp(target,smoothstep(0,1,clampf(circle_time/2.0,0,1)))
	global_position=world.camera.project_position(get_viewport().get_visible_rect().size*center,2.0)
	global_basis=world.camera.global_basis
	var next_frame := int(clock*8.0)%8
	if next_frame!=frame:
		frame=next_frame
		ink.set_shader_parameter("frame_uv",Vector4((frame%4)*.25,floori(frame/4.0)*.5,.25,.5))

func _process(delta: float) -> void:
	if not rising or world.paused or world.transition.active:return
	clock+=delta
	if circling:circle_time+=delta
	_layout()
