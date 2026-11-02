class_name HybridStone
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.94
	result.metallic_specular = 0.18
	return result

static func mesh_node(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, node_name: String, collision := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.set_meta("stone_kind",node_name)
	instance.mesh = _metre_uv(mesh)
	instance.position = at
	instance.material_override = material(color)
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "StoneCollision"
		instance.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
	return instance

static func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, sides: int, color: Color, node_name: String, collision := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	return mesh_node(parent, _flat(mesh) if sides <= 12 else mesh, at, color, node_name, collision)

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, node_name: String, collision := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, at, color, node_name, collision)

static func _flat(mesh: Mesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var normal := (c - a).cross(b - a).normalized()
		for vertex in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	return surface.commit()

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uvs:Array = []) -> void:
	var vertices := [a, b, c, d]
	# Godot triangle front faces use clockwise winding. Physics trimesh
	# normals derive from winding, independently of the rendered normal array.
	if (b - a).cross(c - a).dot(normal) > 0:
		vertices = [a, d, c, b]
		if not uvs.is_empty():uvs=[uvs[0],uvs[3],uvs[2],uvs[1]]
	var u_axis:Vector3=(Vector3.RIGHT-normal*normal.x).normalized()
	if u_axis.length_squared()<0.1:u_axis=(Vector3.FORWARD-normal*normal.dot(Vector3.FORWARD)).normalized()
	var v_axis:Vector3=normal.cross(u_axis).normalized()
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(normal)
		surface.set_uv(uvs[index] if not uvs.is_empty() else Vector2(vertices[index].dot(u_axis),vertices[index].dot(v_axis)))
		surface.add_vertex(vertices[index])

static func gallery_mesh(route: HybridRoute, start: float, finish: float, width := 1.42, thickness := 0.24) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(2, int(ceil((finish - start) / 0.25)))
	for i in steps:
		var s0 := lerpf(start, finish, float(i) / steps)
		var s1 := lerpf(start, finish, float(i + 1) / steps)
		var p0 := route.point(s0)
		var p1 := route.point(s1)
		var radial0 := Vector3(p0.x, 0, p0.z).normalized()
		var radial1 := Vector3(p1.x, 0, p1.z).normalized()
		var a := p0 - radial0 * width / 2
		var b := p0 + radial0 * width / 2
		var c := p1 + radial1 * width / 2
		var d := p1 - radial1 * width / 2
		var down := Vector3.DOWN * thickness
		var tangent := (p1 - p0).normalized()
		var normal := Vector3(-tangent.x * HybridRoute.RISE_PER_METRE, 1, -tangent.z * HybridRoute.RISE_PER_METRE).normalized()
		_quad(surface, a, b, c, d, normal)
		_quad(surface, b, b + down, c + down, c, (radial0 + radial1).normalized())
		_quad(surface, d, d + down, a + down, a, -(radial0 + radial1).normalized())
		_quad(surface, a + down, d + down, c + down, b + down, Vector3.DOWN)
		if i == 0:
			_quad(surface, a, a + down, b + down, b, -route.tangent(start))
		if i == steps - 1:
			_quad(surface, c, c + down, d + down, d, route.tangent(finish))
	return surface.commit()

static func _metre_uv(mesh:Mesh) -> ArrayMesh:
	if mesh is ArrayMesh and mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]!=null:
		# Authored module and path UVs already use metres; retain their continuous
		# station/cross-path layout instead of reprojecting individual triangles.
		return mesh
	var result:=ArrayMesh.new()
	if mesh is CylinderMesh:
		var arrays:=mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var circumference:float=TAU*(mesh.top_radius+mesh.bottom_radius)*.5
		var slant:float=sqrt(mesh.height*mesh.height+pow(mesh.bottom_radius-mesh.top_radius,2))
		for i in vertices.size():
			if absf(normals[i].y)>.95:uv[i]=Vector2(vertices[i].x,vertices[i].z)
			else:uv[i]=Vector2(uv[i].x*circumference,(vertices[i].y/mesh.height+.5)*slant)
		arrays[Mesh.ARRAY_TEX_UV]=uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result
	# Flat indexed primitives get one coherent orthonormal UV frame per face.
	var faces:=mesh.get_faces()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,faces.size(),3):
		var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
		var normal:Vector3=(c-a).cross(b-a).normalized()
		var u:Vector3=(Vector3.RIGHT-normal*normal.x).normalized()
		if u.length_squared()<.1:u=(Vector3.FORWARD-normal*normal.dot(Vector3.FORWARD)).normalized()
		var v:=normal.cross(u).normalized()
		for point in [a,b,c]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(point.dot(u),point.dot(v)))
			surface.add_vertex(point)
	return surface.commit()
