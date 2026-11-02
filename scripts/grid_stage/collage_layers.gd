class_name GridCollageLayers
extends Node3D
# Editable art/dummys/layers.json selects each image's band and real map-part
# anchor. Geometry/colliders never move for compositing; normal depth applies.
@export_range(0.0,0.1,0.001) var flow_speed:float=0.025 # Viewport widths per second; positive travels left.
var camera:Camera3D
var stage:Node3D
var world:Node
var configuration:Dictionary={}
var depths:Dictionary={}
var waves:Array[Dictionary]=[]
var elapsed:=0.0
var map_mask = null
var edge_water = null
var refresh_clock:float=0.0
var background_depth_cache:float=60.0
var background_bounds_ready:bool=false
func configure(view:Camera3D,stage_root:Node3D) -> void:
	camera=view;stage=stage_root;world=camera.get_parent()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://art/dummys/layers.json").trim_prefix("\ufeff"))
	if parsed is Dictionary:configuration=parsed
	_refresh_depths()
	map_mask=preload("res://scripts/grid_stage/map_silhouette.gd").new()
	map_mask.configure(camera,stage)
	var sheet:ArrayMesh=_sheet_mesh()
	for entry:Dictionary in configuration.get("waves",[]):
		var texture:Texture2D=load("res://art/dummys/"+str(entry.image))
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_pond_wave.gdshader")
		ink.set_shader_parameter("wave_image",texture)
		ink.set_shader_parameter("phase",float(entry.phase))
		ink.set_shader_parameter("rate",float(entry.rate))
		ink.set_shader_parameter("amplitude",float(entry.amplitude))
		ink.set_shader_parameter("opacity",float(entry.alpha))
		ink.set_shader_parameter("map_silhouette",map_mask.texture)
		ink.set_shader_parameter("flip_x",bool(entry.get("flip_x",false)))
		var crop:Array=entry.get("crop_uv",[0.0,0.0,1.0,1.0])
		ink.set_shader_parameter("crop_uv",Vector4(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3])))
		var visual:=MeshInstance3D.new();visual.name=str(entry.image).get_basename()
		visual.mesh=sheet;visual.material_override=ink
		visual.set_meta("slice_whole",true);visual.set_meta("screen_band",int(entry.get("screen_band",0)));visual.set_meta("pond_wave",true)
		visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Shader deformation extends slightly beyond the undeformed mesh bounds.
		visual.extra_cull_margin=.15;add_child(visual)
		waves.append({"visual":visual,"ink":ink,"entry":entry,"texture":texture,"copy":0})
		var repeat_visual:MeshInstance3D=visual.duplicate() as MeshInstance3D
		add_child(repeat_visual)
		waves.append({"visual":repeat_visual,"ink":ink,"entry":entry,"texture":texture,"copy":1})
	_layout_waves()
	edge_water=preload("res://scripts/grid_stage/edge_waves.gd").new()
	add_child(edge_water);edge_water.configure(camera,stage,map_mask,sheet)
func botanical_band(leaves:bool) -> String:
	return str(configuration.get("botanical_bands",{}).get("leaves" if leaves else "flowers","far_pond"))
func depth_for_band(band:String) -> float:return float(depths.get(band,58.0))
func _depth_bounds(part_name:String) -> Vector2:
	var part:Node=stage.get_node_or_null(NodePath(part_name))
	if part==null:return Vector2(INF,-INF)
	var result:=Vector2(INF,-INF)
	var pending:Array[Node]=[part]
	while not pending.is_empty():
		var node:Node=pending.pop_back()
		if node is MeshInstance3D:
			var bounds:AABB=node.get_aabb()
			for corner:int in range(8):
				var point:Vector3=node.global_transform*bounds.get_endpoint(corner)
				var depth:float=(point-camera.global_position).dot(-camera.global_basis.z)
				result.x=minf(result.x,depth);result.y=maxf(result.y,depth)
		for child in node.get_children():pending.append(child)
	return result
func _refresh_depths() -> void:
	for name_:String in configuration.get("bands",{}):
		var band:Dictionary=configuration.bands[name_]
		var bounds:=_depth_bounds(str(band.anchor))
		var resolved:float=float(band.get("fallback_depth",58.0))
		if bounds.y>camera.near and is_finite(bounds.x):
			resolved=bounds.x-float(band.offset) if str(band.side)=="front" else bounds.y+float(band.offset)
			if band.has("behind"):
				var foreground:=_depth_bounds(str(band.behind))
				if is_finite(foreground.x) and foreground.y>camera.near:
					var lower:float=foreground.y+.15
					if lower<=resolved:resolved=maxf(lower,resolved)
					else:
						# Interpenetrating depth ranges cannot be arbitrarily sorted
						# without moving geometry. Keep the art behind both instead.
						resolved=maxf(bounds.y,foreground.y)+.3
		depths[name_]=clampf(resolved,camera.near+.3,camera.far-1.0)
func _sheet_mesh() -> ArrayMesh:
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	const COLUMNS:=24
	const ROWS:=8
	for y:int in range(ROWS+1):
		for x:int in range(COLUMNS+1):
			var uv:=Vector2(float(x)/COLUMNS,float(y)/ROWS)
			uvs.append(uv);vertices.append(Vector3(uv.x-.5,.5-uv.y,0))
	for y:int in range(ROWS):
		for x:int in range(COLUMNS):
			var a:int=y*(COLUMNS+1)+x;var b:int=a+COLUMNS+1
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func _wave_background_depth() -> float:
	var backdrop_far:float=20.0
	# All water stays physically behind other scene imagery; the silhouette
	# texture additionally prevents lower compositing bands from painting over it.
	for node:Node in stage.find_children("*","GeometryInstance3D",true,false):
		if bool(node.get_meta("pond_wave",false)):continue
		var visual:GeometryInstance3D=node as GeometryInstance3D
		if not visual.is_visible_in_tree():continue
		var bounds:AABB=visual.get_aabb()
		for corner:int in range(8):
			var point:Vector3=visual.global_transform*bounds.get_endpoint(corner)
			backdrop_far=maxf(backdrop_far,(point-camera.global_position).dot(-camera.global_basis.z))
	return clampf(backdrop_far+2,camera.near+.5,camera.far-1)
func _flow_x(initial_x:float,_half_extent:float,time:float) -> float:
	# The neighboring fixed copy preserves coverage during this phase wrap.
	var period:float=float(configuration.get("flow",{}).get("repeat_period",1.15))
	return fposmod(initial_x-time*flow_speed+.075,period)-.075
func _layout_waves() -> void:
	var frame:Vector2=get_viewport().get_visible_rect().size
	if frame.y<=0:return
	var height:float=camera.size;var width:float=height*frame.x/frame.y
	var background_depth:float=background_depth_cache
	for index:int in range(waves.size()):
		var wave:Dictionary=waves[index]
		var entry:Dictionary=wave.entry
		var depth:float=background_depth-float(index)*.002+float(entry.get("extra_depth",0.0))
		var center:Vector2=Vector2(float(entry.center[0]),float(entry.center[1]))
		var angle:float=deg_to_rad(float(entry.get("rotation_degrees",0.0)))
		var aspect:float=float(entry.get("cropped_aspect",float(wave.texture.get_height())/float(wave.texture.get_width())))
		var half_extent:float=float(entry.width)*.5*(absf(cos(angle))+aspect*absf(sin(angle)))
		var speeds:Array=configuration.get("flow",{}).get("speed_multipliers",[])
		var band:int=clampi(int(entry.get("screen_band",0)),0,11)
		var speed_multiplier:float=float(speeds[band]) if speeds.size()==12 else .55+band*.085
		var period:float=float(configuration.get("flow",{}).get("repeat_period",1.15))
		# Two fixed copies span neighboring periods. Shared phase makes seam
		# recycling identical and avoids independently drifting holes between tiles.
		center.x=_flow_x(center.x,half_extent,elapsed*speed_multiplier)
		if int(wave.copy)==1:center.x+=period if center.x<.5 else -period
		var front_x:float=center.x-half_extent
		if edge_water!=null and wave.has("front_x"):
			var previous:float=float(wave.front_x)
			if previous>front_x and previous-front_x<.1:
				edge_water.observe_front(previous*frame.x,front_x*frame.x,(center.y-float(entry.width)*aspect*frame.x/frame.y*.5)*frame.y,(center.y+float(entry.width)*aspect*frame.x/frame.y*.5)*frame.y)
		wave["front_x"]=front_x
		# Small painted deformation remains in the shader, while the whole sheet
		# travels monotonically left instead of rocking back and forth.
		var drift:float=0.0
		var surge:float=sin(elapsed*float(entry.rate)*.53+float(entry.phase))*.0015
		var position:Vector3=camera.global_position-camera.global_basis.z*depth+camera.global_basis.x*((center.x-.5+drift)*width)+camera.global_basis.y*((.5-center.y+surge)*height)
		wave.visual.global_position=position
		var sheet_width:float=width*float(entry.width)
		var sheet_height:float=sheet_width*float(entry.get("cropped_aspect",float(wave.texture.get_height())/float(wave.texture.get_width())))
		var basis:Basis=camera.global_basis*Basis(Vector3.BACK,deg_to_rad(float(entry.get("rotation_degrees",0.0))))*Basis.from_scale(Vector3(sheet_width,sheet_height,1))
		wave.visual.global_basis=basis
		wave.ink.set_shader_parameter("elapsed",elapsed)
func _process(delta:float) -> void:
	if not is_instance_valid(world):return
	# Stage construction adds paper/player after configure. Resolve bounds once
	# on the first process, then only when architectural/camera state changes.
	if not background_bounds_ready:
		background_depth_cache=_wave_background_depth()
		background_bounds_ready=true
	if bool(world.get("paused")):return
	elapsed+=delta
	refresh_clock+=delta
	var changed:bool=false
	if refresh_clock>=0.1:
		refresh_clock=fmod(refresh_clock,0.1)
		changed=map_mask!=null and map_mask.refresh()
		if changed:
			_refresh_depths()
			background_depth_cache=_wave_background_depth()
			# ImageTexture is updated in place; no repeated material rebinding.
	_layout_waves()
	if edge_water!=null:edge_water.advance(elapsed,changed)
