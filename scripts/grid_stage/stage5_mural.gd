extends MeshInstance3D
var world:GridStageWorld
var elapsed:=0.0
const SOAK_SECONDS:=2.4

func configure(owner_world:GridStageWorld,host:Node3D,block:Array,touch:Vector3,texture:Texture2D) -> void:
	world=owner_world
	var lo:=Vector3(block[0])*.2;var hi:=Vector3(block[1])*.2
	var width:float=hi.z-lo.z;var height:float=hi.y-lo.y
	var quad:=QuadMesh.new();quad.size=Vector2(width,height);mesh=quad
	global_transform=Transform3D(Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT),Vector3(hi.x+.012,(lo.y+hi.y)*.5,(lo.z+hi.z)*.5))
	set_meta("wall_layer_attached",true);set_meta("slice_whole",false)
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/stage5_wall_mural.gdshader")
	ink.render_priority=1
	ink.set_shader_parameter("illustration",texture)
	ink.set_shader_parameter("wall_height",height)
	ink.set_shader_parameter("origin_uv",Vector2((hi.z-touch.z)/width,(hi.y-touch.y)/height))
	material_override=ink

func _process(delta:float) -> void:
	if world.paused or world.transition.active:return
	elapsed=minf(elapsed+delta,SOAK_SECONDS)
	material_override.set_shader_parameter("progress",elapsed/SOAK_SECONDS)
