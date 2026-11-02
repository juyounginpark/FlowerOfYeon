class_name StageCells
extends RefCounted
const UNIT:=.2
var occupied:Dictionary={}
var top_tints:Dictionary={}
var exposed_face_count:=0
var merged_quad_count:=0
var trim_meshes:Array=[]
func fill(first:Vector3i,last:Vector3i) -> void:
	for x in range(first.x,last.x):
		for y in range(first.y,last.y):
			for z in range(first.z,last.z):occupied[Vector3i(x,y,z)]=true
func mesh(top_color:=Color("f3e7ce")) -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes:Dictionary={}
	var outlines:Dictionary={}
	exposed_face_count=0;merged_quad_count=0
	var directions:Array[Vector3i]=[Vector3i.UP,Vector3i.DOWN,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
	for cell:Vector3i in occupied:
		var lo:=Vector3(cell)*UNIT
		for direction in directions:
			if occupied.has(cell+direction):continue
			var n:=Vector3(direction)
			var u:=Vector3.RIGHT if absf(n.y)>.5 else Vector3.UP
			var v:=n.cross(u)
			var center:=lo+Vector3.ONE*UNIT*.5+n*UNIT*.5
			var color:Color=top_tints.get(cell,top_color) if n.y>.5 else (Color("dca2bb") if absf(n.x)>.5 else Color("64bfb2"))
			var plane:=int(round(center.dot(n)/UNIT))
			var key:="%s/%d/%s"%[direction,plane,color.to_html()]
			if not planes.has(key):planes[key]={"normal":n,"u":u,"v":v,"plane":plane,"color":color,"cells":{}}
			var coordinate:=Vector2i(roundi(center.dot(u)/UNIT-.5),roundi(center.dot(v)/UNIT-.5))
			planes[key].cells[coordinate]=true
			# Ignore goal tint subdivisions when tracing the physical face outline.
			var outline_key:String="%s/%d"%[direction,plane]
			if not outlines.has(outline_key):outlines[outline_key]={"normal":n,"u":u,"v":v,"plane":plane,"cells":{}}
			outlines[outline_key].cells[coordinate]=true
			exposed_face_count+=1
	# Merge only adjacent, coplanar, identically colored exposed cell faces.
	# Occupancy remains the source of truth; no gaps or silhouette cells are filled.
	for key in planes:
		var group:Dictionary=planes[key]
		var cells:Dictionary=group.cells
		while not cells.is_empty():
			var first:Vector2i=cells.keys()[0]
			for candidate:Vector2i in cells:
				if candidate.y<first.y or (candidate.y==first.y and candidate.x<first.x):first=candidate
			var width:=1
			while cells.has(first+Vector2i(width,0)):width+=1
			var height:=1
			var complete:=true
			while complete:
				for x in width:
					if not cells.has(first+Vector2i(x,height)):complete=false;break
				if complete:height+=1
			for x in width:
				for y in height:cells.erase(first+Vector2i(x,y))
			var n:Vector3=group.normal;var u:Vector3=group.u;var v:Vector3=group.v
			var center:Vector3=n*float(group.plane)*UNIT+u*(float(first.x)+width*.5)*UNIT+v*(float(first.y)+height*.5)*UNIT
			for corner in [Vector2(-1,-1),Vector2(1,1),Vector2(1,-1),Vector2(-1,-1),Vector2(-1,1),Vector2(1,1)]:
				surface.set_normal(n);surface.set_color((group.color as Color).srgb_to_linear())
				var point:Vector3=center+(u*corner.x*width+v*corner.y*height)*UNIT*.5
				surface.set_uv(Vector2(point.dot(u),point.dot(v)))
				surface.add_vertex(point)
			merged_quad_count+=1
	trim_meshes=preload("res://scripts/grid_stage/paper_trim.gd").build(outlines)
	return surface.commit()
func install(parent:Node3D,name_:String,top_color:=Color("f3e7ce"),moving:=false) -> PhysicsBody3D:
	var body:PhysicsBody3D=AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name=name_;body.collision_layer=4 if moving else 1
	if moving:body.sync_to_physics=false
	var shared:=mesh(top_color)
	var display:=MeshInstance3D.new();display.mesh=shared
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/grid_paper_surface.gdshader")
	display.material_override=material;display.name="CleanSurface";body.add_child(display)
	for i:int in range(trim_meshes.size()):
		if trim_meshes[i]==null:continue
		var trim:=MeshInstance3D.new();trim.name="PaperCornerOrnaments" if i==1 else "PaperEdgeTrim"
		trim.mesh=trim_meshes[i]
		var trim_ink:=ShaderMaterial.new();trim_ink.shader=preload("res://shaders/grid_paper_trim.gdshader")
		trim_ink.set_shader_parameter("corner",i==1)
		trim_ink.set_shader_parameter("corner_image",preload("res://art/materials/hanji/ornament_corner.svg"))
		trim.material_override=trim_ink;body.add_child(trim)
	var collision:=CollisionShape3D.new();collision.shape=shared.create_trimesh_shape();body.add_child(collision)
	body.set_meta("occupied_cell_count",occupied.size())
	body.set_meta("exposed_cell_faces",exposed_face_count)
	body.set_meta("merged_quads",merged_quad_count)
	parent.add_child(body)
	return body

