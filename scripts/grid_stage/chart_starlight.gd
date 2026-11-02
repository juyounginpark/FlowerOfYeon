extends Node3D
# Offline-mapped UVs, one static star mesh and one halo. No per-star nodes/lights.
var stars:MeshInstance3D
var halo:MeshInstance3D
var elapsed:=0.0
var activated:=false
var chart:Sprite3D

func configure(source:Sprite3D) -> void:
	chart=source
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/gyeonwu_chart.gdshader")
	ink.set_shader_parameter("illustration",chart.texture);ink.render_priority=-64
	chart.material_override=ink
	var mapping:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/minhwa/gyeonwu_rework/chart_stars.json").trim_prefix("\ufeff"))
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
	var colors:=PackedColorArray();var indices:=PackedInt32Array()
	var index:=0
	for point:Array in mapping.points:
		var center:=Vector2(float(point[0])-.5,.5-float(point[1]))
		var radius:=clampf(float(point[2])*4.0/820.0,.008,.018)
		var offset:=vertices.size()
		var seed:=Color(fmod(index*.618,1),fmod(index*.371,1),fmod(index*.273,1),1)
		for uv:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			vertices.append(Vector3(center.x+(uv.x-.5)*radius*2,center.y+(.5-uv.y)*radius*2,.001))
			uvs.append(uv);colors.append(seed)
		for corner:int in [0,1,2,0,2,3]:indices.append(offset+corner)
		index+=1
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	stars=_layer("MappedChartStars",mesh,-62)
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*1.25
	halo=_layer("ChartLightSpill",quad,-65)
	halo.material_override.set_shader_parameter("disc_halo",true)
	stars.hide()
	advance(0.0)

func start_twinkle() -> void:
	if activated:return
	activated=true;elapsed=0.0;stars.show()

func _layer(id:String,mesh:Mesh,priority:int) -> MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=id;visual.mesh=mesh
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("story_actor",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/gyeonwu_stars.gdshader");ink.render_priority=priority
	visual.material_override=ink;add_child(visual)
	return visual

func advance(delta:float) -> void:
	if activated:elapsed+=delta
	chart.material_override.set_shader_parameter("clock",elapsed)
	stars.material_override.set_shader_parameter("clock",elapsed)
	halo.material_override.set_shader_parameter("clock",elapsed)
	# This node inherits the chart's floor-plane rotation. UV positions never drift.
	var size:Vector2=chart.texture.get_size()*chart.pixel_size
	scale=Vector3(size.x,size.y,1)
