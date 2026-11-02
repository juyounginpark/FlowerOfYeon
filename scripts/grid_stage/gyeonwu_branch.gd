extends Node3D
# A paper bough splits along the mouse stroke; detached geometry has real 3D
# mass/collision. Regrowing a new bough never deletes the fallen fragments.
var world:Node3D
var texture:Texture2D
var image_size:=Vector2.ZERO
var polygon:=PackedVector2Array()
var pin:=Vector2.ZERO
var pixel_size:=1.0
var intact:MeshInstance3D
var stump:MeshInstance3D
var fallen:Array[RigidBody3D]=[]
var ready_to_cut:=true
var growth:=1.0
var mirrored:=false
const INK=preload("res://shaders/gyeonwu_branch.gdshader")

func configure(owner_world:Node3D,art:Texture2D,height:float,flip:bool) -> void:
	world=owner_world;texture=art;mirrored=flip
	var source:=art.get_image()
	if source.is_compressed():source.decompress()
	image_size=Vector2(source.get_size());pixel_size=height/image_size.y
	var bitmap:=BitMap.new();bitmap.create_from_image_alpha(source,.25)
	var outlines:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),3.0)
	for outline:PackedVector2Array in outlines:
		var cleaned:=_clean_outline(outline)
		if _area(cleaned)>_area(polygon):polygon=cleaned
	# The thick lower-left root is the fixed end of the supplied branch.
	var root:=Vector2(image_size.x*.08,image_size.y*.94)
	pin=root
	if not Geometry2D.is_point_in_polygon(pin,polygon):
		var nearest:=INF
		for point in polygon:
			var inset:=point.lerp(Vector2(image_size.x*.12,image_size.y*.88),.08)
			if Geometry2D.is_point_in_polygon(inset,polygon) and inset.distance_to(root)<nearest:
				pin=inset;nearest=inset.distance_to(root)
	# Display the original alpha image on a guaranteed two-triangle quad.
	# Fine bark/leaf contours can touch themselves and fail ear clipping; that
	# must never prevent the uncut bough (or its regrowth) from being drawn.
	var quad:=PackedVector2Array([Vector2.ZERO,Vector2(image_size.x,0),image_size,Vector2(0,image_size.y)])
	intact=_visual(quad,PackedInt32Array([0,1,2,0,2,3]),polygon);add_child(intact)
	ready_to_cut=polygon.size()>=3

static func _area(points:PackedVector2Array) -> float:
	var total:=0.0
	for i in range(points.size()):total+=points[i].cross(points[(i+1)%points.size()])
	return absf(total)*.5

static func _clean_outline(outline:PackedVector2Array) -> PackedVector2Array:
	var cleaned:=PackedVector2Array()
	for point in outline:
		if cleaned.is_empty() or not point.is_equal_approx(cleaned[-1]):cleaned.append(point)
	if cleaned.size()>1 and cleaned[0].is_equal_approx(cleaned[-1]):cleaned.resize(cleaned.size()-1)
	return cleaned

static func _piece_geometry(outline:PackedVector2Array) -> Dictionary:
	var cleaned:=_clean_outline(outline)
	if cleaned.size()<3 or _area(cleaned)<=8:return {}
	var indices:=Geometry2D.triangulate_polygon(cleaned)
	if indices.is_empty():
		# A clipped contour may still pinch at a leaf. Its convex hull stays on
		# the same side of the cut; image alpha preserves the painted silhouette.
		# Use a guaranteed convex fan for both rendering and collision in that case.
		cleaned=_clean_outline(Geometry2D.convex_hull(cleaned))
		if cleaned.size()<3 or _area(cleaned)<=8:return {}
		for i in range(1,cleaned.size()-1):indices.append_array(PackedInt32Array([0,i,i+1]))
	return {"outline":cleaned,"indices":indices}

func _vertex(point:Vector2) -> Vector3:
	var relative:Vector2=(point-image_size*.5)*pixel_size
	return Vector3(-relative.x if mirrored else relative.x,-relative.y,0)

func point_at(uv:Vector2) -> Vector3:
	return global_transform*_vertex(uv*image_size)

func _visual(outline:PackedVector2Array,indices:PackedInt32Array,sticker_outline:=PackedVector2Array()) -> MeshInstance3D:
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array()
	for point in outline:
		vertices.append(_vertex(point));uv.append(point/image_size)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ink:=ShaderMaterial.new();ink.shader=INK
	ink.set_shader_parameter("illustration",texture)
	ink.set_shader_parameter("growth",1.06)
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=ink
	visual.set_meta("story_actor",true)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var contour:PackedVector2Array=outline if sticker_outline.is_empty() else sticker_outline
	_add_sticker_layer(visual,contour,false)
	_add_sticker_layer(visual,contour,true)
	return visual

func _add_sticker_layer(owner_visual:MeshInstance3D,outline:PackedVector2Array,border:bool) -> void:
	# Stroke ONLY the perimeter. The previous 12 border + 36 shadow copies
	# shaded the entire transparent image repeatedly in all twelve screen passes.
	# These narrow strips and round joins need neither texture reads nor polygon
	# triangulation, and preserve the paper backing on fresh cut edges.
	var unit:float=world.camera.size/1000.0
	var expanded:=PackedVector3Array();var texcoords:=PackedVector2Array();var triangles:=PackedInt32Array()
	var colors:=PackedColorArray()
	var radius:float=unit*(GridPaperCutting.PAPER_BORDER_WIDTH if border else 10.0)
	var shift:=Vector3(0,0,-.04)*unit if border else Vector3(4.5,-6.0,-.1)*unit
	var inner_alpha:=1.0 if border else .16
	var outer_alpha:=1.0 if border else 0.0
	for i in range(outline.size()):
		var a:=_vertex(outline[i])+shift
		var b:=_vertex(outline[(i+1)%outline.size()])+shift
		var normal:Vector3=(b-a).cross(Vector3.BACK).normalized()*radius
		var base:=expanded.size()
		for point:Vector3 in [a,b,a+normal,b+normal,a-normal,b-normal]:expanded.append(point)
		for index in range(6):
			texcoords.append(outline[i if index%2==0 else (i+1)%outline.size()]/image_size)
			colors.append(Color(1,1,1,inner_alpha if index<2 else outer_alpha))
		for index:int in [0,1,2,2,1,3,0,4,1,4,5,1]:triangles.append(base+index)
		# A six-segment round join seals corners without filling the whole image.
		base=expanded.size();expanded.append(a);texcoords.append(outline[i]/image_size)
		colors.append(Color(1,1,1,inner_alpha))
		for step in range(6):
			var offset:=Vector2.from_angle(TAU*step/6.0)*radius
			expanded.append(a+Vector3(offset.x,offset.y,0));texcoords.append(outline[i]/image_size)
			colors.append(Color(1,1,1,outer_alpha))
		for step in range(6):triangles.append_array(PackedInt32Array([base,base+1+step,base+1+(step+1)%6]))
	if triangles.is_empty():return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=expanded;arrays[Mesh.ARRAY_TEX_UV]=texcoords;arrays[Mesh.ARRAY_INDEX]=triangles
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ink:=ShaderMaterial.new();ink.shader=INK
	ink.set_shader_parameter("illustration",texture);ink.set_shader_parameter("growth",1.06)
	ink.set_shader_parameter("paper_layer",true)
	ink.set_shader_parameter("paper_tint",GridPaperCutting.PAPER_COLOR if border else Color(.16,.145,.12,1.0))
	ink.render_priority=-1 if border else -2
	var layer:=MeshInstance3D.new();layer.name="CuttablePaperBorder" if border else "CuttableDropShadow"
	layer.mesh=mesh;layer.material_override=ink;layer.set_meta("story_actor",true)
	layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;owner_visual.add_child(layer)

func _set_growth(value:float) -> void:
	intact.material_override.set_shader_parameter("growth",value)
	for layer in intact.get_children():
		if layer is MeshInstance3D:layer.material_override.set_shader_parameter("growth",value)

func _local_pixel(screen:Vector2) -> Variant:
	var camera:Camera3D=world.camera
	var origin:=camera.project_ray_origin(screen);var direction:=camera.project_ray_normal(screen)
	var normal:=global_basis.z.normalized();var denominator:=direction.dot(normal)
	if absf(denominator)<.0001:return null
	var distance:float=(global_position-origin).dot(normal)/denominator
	if distance<0:return null
	var local:Vector3=global_transform.affine_inverse()*(origin+direction*distance)
	return Vector2(-local.x if mirrored else local.x,-local.y)/pixel_size+image_size*.5

func cut(a_screen:Vector2,b_screen:Vector2) -> bool:
	if not ready_to_cut or a_screen.distance_to(b_screen)<8:return false
	var a_value:Variant=_local_pixel(a_screen);var b_value:Variant=_local_pixel(b_screen)
	if a_value==null or b_value==null:return false
	var a:Vector2=a_value;var b:Vector2=b_value
	var crossings:=0
	for i in range(polygon.size()):
		if Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])!=null:crossings+=1
	if crossings<2:return false
	var direction:Vector2=(b-a).normalized();var normal:=direction.orthogonal()
	var results:Array[Dictionary]=[]
	for side:float in [-1.0,1.0]:
		var half:=PackedVector2Array([a-direction*10000,a+direction*10000,a+direction*10000+normal*10000*side,a-direction*10000+normal*10000*side])
		for part:PackedVector2Array in Geometry2D.intersect_polygons(polygon,half):
			if _area(part)<=8:continue
			var geometry:=_piece_geometry(part)
			# Validate every resulting surface before replacing the visible bough.
			if geometry.is_empty():return false
			geometry["attached"]=Geometry2D.is_point_in_polygon(pin,part)
			results.append(geometry)
	if results.size()<2:return false
	ready_to_cut=false
	# Replace the intact silhouette by its exact cut polygons in the same pose.
	intact.hide()
	for part in results:
		if part.attached:
			stump=_visual(part.outline,part.indices);add_child(stump)
		else:_release(part.outline,part.indices)
	BgmPlayer.play_cut()
	return true

func _release(outline:PackedVector2Array,triangles:PackedInt32Array) -> void:
	var body:=RigidBody3D.new();body.name="FallingBranch"
	body.collision_layer=8;body.collision_mask=1;body.mass=.35
	body.gravity_scale=1;body.linear_damp=.15;body.angular_damp=.6
	var material:=PhysicsMaterial.new();material.friction=.8;material.bounce=.08
	body.physics_material_override=material
	world.stage_root.add_child(body);body.global_transform=global_transform
	var center:=Vector3.ZERO
	for point in outline:center+=_vertex(point)
	center/=float(outline.size())
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=center
	# One thin convex collider per fragment, instead of one per painted triangle.
	# Debris still collides with terrain under gravity; debris/debris contact pairs
	# do not add quadratic work as more branches are cut.
	var hull:=_clean_outline(Geometry2D.convex_hull(outline))
	var points:=PackedVector3Array()
	for point in hull:
		var vertex:=_vertex(point)
		points.append(vertex+Vector3.BACK*.015);points.append(vertex-Vector3.BACK*.015)
	var shape:=ConvexPolygonShape3D.new();shape.points=points
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	body.add_child(_visual(outline,triangles))
	body.angular_velocity=global_basis.z*.18
	fallen.append(body)

func begin_regrowth() -> void:
	growth=0;_set_growth(0.0);intact.show()

func advance_regrowth(delta:float) -> bool:
	growth=minf(1.0,growth+delta/.9)
	_set_growth(growth*1.06)
	if growth<1:return false
	# Only the fixed stump is covered by the newly grown branch; debris persists.
	if is_instance_valid(stump):stump.queue_free();stump=null
	ready_to_cut=true
	return true

func _physics_process(_delta:float) -> void:
	if world==null:return
	for body in fallen:
		if is_instance_valid(body):body.freeze=world.paused or world.transition.active
