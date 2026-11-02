extends Skeleton3D
## Native Godot bones and a weighted paper mesh; the painted sheet stays intact.
const SUBDIVISIONS := 48
# Name, parent, image-space joint, swing in degrees, wave phase.
const JOINTS := [
	["body", -1, Vector2(.49,.61), .7, 0.0],
	["neck", 0, Vector2(.47,.44), 1.5, -.5],
	["head", 1, Vector2(.28,.39), 1.2, -1.0],
	["upper_coil", 0, Vector2(.65,.27), 1.0, .5],
	["rear_coil", 3, Vector2(.84,.49), 1.1, 1.0],
	["lower_coil", 4, Vector2(.68,.65), 1.3, 1.5],
	["tail_base", 5, Vector2(.73,.78), 2.0, 2.0],
	["tail_tip", 6, Vector2(.86,.88), 3.0, 2.5],
	["front_arm", 1, Vector2(.22,.58), 1.5, -.8],
	["front_claw", 8, Vector2(.16,.63), 2.0, -1.2],
	["rear_arm", 3, Vector2(.73,.45), 1.4, .7],
	["lower_leg", 0, Vector2(.45,.79), 1.8, 1.3],
]

func _point(uv: Vector2) -> Vector3:
	return Vector3(uv.x-.5,.5-uv.y,0)

func build() -> ArrayMesh:
	for index in range(JOINTS.size()):
		var joint: Array = JOINTS[index]
		add_bone(joint[0])
		var parent: int = joint[1]
		var offset: Vector3 = _point(joint[2])
		if parent>=0:
			set_bone_parent(index,parent)
			offset-=_point(JOINTS[parent][2])
		set_bone_rest(index,Transform3D(Basis.IDENTITY,offset))
	reset_bone_poses()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for y in range(SUBDIVISIONS+1):
		for x in range(SUBDIVISIONS+1):
			var uv := Vector2(x,y)/float(SUBDIVISIONS)
			vertices.append(_point(uv));uvs.append(uv)
			# Blend the closest four joints once at setup, never rebuild per frame.
			var nearest: Array[int] = []
			for index in range(JOINTS.size()):nearest.append(index)
			nearest.sort_custom(func(a: int,b: int) -> bool: return uv.distance_squared_to(JOINTS[a][2])<uv.distance_squared_to(JOINTS[b][2]))
			var influence := PackedFloat32Array()
			var total := 0.0
			for slot in range(4):
				var distance: float = uv.distance_squared_to(JOINTS[nearest[slot]][2])
				var weight := 1.0/pow(maxf(distance,.001),2.0)
				influence.append(weight);total+=weight
			for slot in range(4):
				bones.append(nearest[slot]);weights.append(influence[slot]/total)
	for y in range(SUBDIVISIONS):
		for x in range(SUBDIVISIONS):
			var a := y*(SUBDIVISIONS+1)+x
			var b := a+SUBDIVISIONS+1
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func animate(time: float) -> void:
	for index in range(JOINTS.size()):
		var joint: Array = JOINTS[index]
		var angle: float = deg_to_rad(joint[3])*sin(time*TAU/4.8-joint[4])
		set_bone_pose_rotation(index,Quaternion(Vector3.BACK,angle))
