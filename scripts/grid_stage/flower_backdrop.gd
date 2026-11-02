class_name GridFlowerBackdrop
extends Node3D
# User-supplied alpha collage, in editable map-part-relative depth bands.
# Screen-relative placement is stable under the fixed orthographic camera.
var camera:Camera3D
var arrangements:Array=[]
var flowers:Array[Sprite3D]=[]
var stem_positions:Array[Vector3]=[]
var stem_offsets:Array[Vector3]=[]
var sway_elapsed:=0.0
var stem_ratios:Array[Vector2]=[]
var sway_phases:Array[float]=[]
var sway_rates:Array[float]=[]
var world:Node
# Keep the orchestration boundary duck-typed: configure must be resolvable
# while the editor is loading the separate layer-controller script.
var layers = null
const SIZE_RATIO:=2.0/3.0
func configure(view:Camera3D,stage:int,layer_controller=null) -> void:
	layers=layer_controller
	camera=view
	world=camera.get_parent()
	# Generate once per stage, never during resize/frame updates. Restarting the
	# same stage reproduces its collage, sizes and sway without layout jitter.
	var rng:=RandomNumberGenerator.new()
	rng.seed=73129+stage*4099
	var flower_count:=rng.randi_range(4,5)
	var leaf_count:=rng.randi_range(10,12)
	var flower_image:Texture2D=load("res://art/dummys/dummyFlower.png")
	var leaf_image:Texture2D=load("res://art/dummys/dummyLeaf.png")
	for kind:int in [0,1]:
		var count:int=flower_count if kind==0 else leaf_count
		for index:int in range(count):
			# Evenly spaced peripheral slots with bounded jitter leave the center
			# clear. Leaves use an offset ring and a slightly smaller reference.
			var theta:float=TAU*float(index)/float(count)+(.24 if kind==0 else .47)+stage*.12+rng.randf_range(-.055,.055)
			var center:=Vector2(.5+cos(theta)*.48,.5+sin(theta)*.47)
			var reference_height:float=.50 if kind==0 else .42
			var multiplier:float=rng.randf_range(.8,1.2)
			arrangements.append(Vector4(center.x,center.y,reference_height*multiplier,rng.randf_range(-22,22)))
			stem_ratios.append(Vector2(.18,-.48) if kind==0 else Vector2(.12,-.47))
			sway_phases.append(rng.randf_range(0,TAU))
			sway_rates.append(rng.randf_range(.57,.79))
			var flower:=Sprite3D.new()
			flower.name=("PaintedLotus%d" if kind==0 else "PaintedLeaf%d")%(index+1)
			flower.texture=flower_image if kind==0 else leaf_image
			flower.shaded=false;flower.no_depth_test=false
			flower.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flower.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
			flower.double_sided=true
			# Keep leaves slightly farther away, behind the flowers where they overlap.
			var band:String=layers.botanical_band(kind==1) if layers!=null else "far_pond"
			flower.set_meta("collage_band",band)
			flower.set_meta("depth_offset",0.0 if kind==0 else .12)
			flower.set_meta("background_depth",(layers.depth_for_band(band) if layers!=null else 55.0)+(0.0 if kind==0 else .12))
			add_child(flower);flowers.append(flower)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var paper = preload("res://scripts/grid_stage/paper_cutting.gd").new()
	add_child(paper);paper.configure(camera,flowers)
func _layout() -> void:
	if not is_instance_valid(camera):return
	var viewport_size:=get_viewport().get_visible_rect().size
	if viewport_size.y<=0:return
	var height:=camera.size
	var width:=height*viewport_size.x/viewport_size.y
	# Depth is relative to each configured map part. Normal depth testing stays enabled.
	var depth_center:=camera.global_position-camera.global_basis.z*55.0
	stem_positions.clear();stem_offsets.clear()
	for index in flowers.size():
		var layout:Vector4=arrangements[index]
		var flower:=flowers[index]
		var layer_center:=depth_center-camera.global_basis.z*(float(flower.get_meta("background_depth",55.0))-55.0)
		flower.global_position=layer_center+camera.global_basis.x*((layout.x-.5)*width)+camera.global_basis.y*((.5-layout.y)*height)
		flower.global_basis=camera.global_basis*Basis(Vector3.BACK,deg_to_rad(layout.w))
		flower.pixel_size=height*layout.z*SIZE_RATIO/float(flower.texture.get_height())
		# The painted stem ends slightly right of bottom center. Keep that point
		# anchored while the complete flower gently rocks, rather than spins.
		var offset:=Vector3(float(flower.texture.get_width())*stem_ratios[index].x,float(flower.texture.get_height())*stem_ratios[index].y,0)*flower.pixel_size
		stem_offsets.append(offset)
		stem_positions.append(flower.global_position+flower.global_basis*offset)
	_apply_sway()
func _process(delta:float) -> void:
	if not is_instance_valid(world) or bool(world.get("paused")):return
	sway_elapsed+=delta
	_apply_sway()
func _apply_sway() -> void:
	if not is_instance_valid(camera):return
	for index in flowers.size():
		if index>=stem_positions.size():continue
		if layers!=null:
			var previous_depth:float=float(flowers[index].get_meta("background_depth",55.0))
			var current_depth:float=layers.depth_for_band(str(flowers[index].get_meta("collage_band","far_pond")))+float(flowers[index].get_meta("depth_offset",0.0))
			stem_positions[index]-=camera.global_basis.z*(current_depth-previous_depth)
			flowers[index].set_meta("background_depth",current_depth)
		var layout:Vector4=arrangements[index]
		# Deterministic different phases and slow periods; 2.3 degree sway.
		var angle:float=deg_to_rad(layout.w+2.3*sin(sway_elapsed*sway_rates[index]+sway_phases[index]))
		flowers[index].global_basis=camera.global_basis*Basis(Vector3.BACK,angle)
		flowers[index].global_position=stem_positions[index]-flowers[index].global_basis*stem_offsets[index]
