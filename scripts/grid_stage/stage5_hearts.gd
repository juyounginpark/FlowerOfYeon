extends Node3D
# CPU-updated decorative sprites; no GPU particle simulation is required.
const HEART_PATH:="res://art/minhwa/stage5_rework/affection_heart_v1.png"
const PARTICLE_COUNT:=9
const LIFETIME:=2.4
var story:Node3D
var texture:Texture2D
var overhead:MeshInstance3D
var particles:Array[MeshInstance3D]=[]
var elapsed:=0.0

func configure(owner_story:Node3D) -> void:
	story=owner_story
	process_priority=10
	texture=load(HEART_PATH)
	overhead=_heart("RatAffectionHeart",.52)
	for index:int in range(PARTICLE_COUNT):particles.append(_heart("MuralHeart%d"%index,.16+float(index%3)*.035))
	hide()

func _heart(label:String,size:float) -> MeshInstance3D:
	var heart:=MeshInstance3D.new();heart.name=label
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*size;heart.mesh=quad
	var ink:=StandardMaterial3D.new()
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	ink.albedo_texture=texture;ink.render_priority=120
	heart.material_override=ink;heart.set_meta("slice_whole",false)
	heart.set_meta("heart_ink",ink)
	heart.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(heart);return heart

func _process(delta:float) -> void:
	if story==null:return
	var mounted:bool=is_instance_valid(story.mural) and not story.painting.is_empty() and story._map_sticker(story.painting)
	visible=mounted and not story.world.transition.active
	if not visible:return
	if not story.world.paused and not story.world.player.input_locked:elapsed+=delta
	var camera:Camera3D=story.camera
	overhead.visible=not story.caught
	overhead.global_position=story.rat_base+camera.global_basis.y*(1.5*story.SCHOLAR_SCALE+.72+sin(elapsed*2.8)*.07)
	overhead.global_basis=camera.global_basis.scaled(Vector3.ONE*(1.0+sin(elapsed*4.2)*.07))
	var mural:MeshInstance3D=story.mural
	var size:Vector2=mural.mesh.size
	for index:int in range(particles.size()):
		var heart:MeshInstance3D=particles[index]
		var phase:=fmod(elapsed/LIFETIME+float(index)/PARTICLE_COUNT,1.0)
		var column:=float((index*5)%PARTICLE_COUNT)/float(PARTICLE_COUNT-1)-.5
		var origin:=mural.to_global(Vector3(column*size.x*.8,-size.y*.22,.24))
		heart.global_position=origin+Vector3.UP*(phase*size.y*.65)+camera.global_basis.x*sin(phase*TAU+index)*.10
		heart.global_basis=camera.global_basis.scaled(Vector3.ONE*lerpf(.7,1.15,phase))
		var ink:StandardMaterial3D=heart.get_meta("heart_ink")
		ink.albedo_color.a=smoothstep(0,.15,phase)*(1.0-smoothstep(.65,1,phase))
