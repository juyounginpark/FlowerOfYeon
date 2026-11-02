extends MeshInstance2D
## A finely tessellated piece of the comic, unfolded in the vertex shader.

const CELL_SIZE := 26.0
const IDLE_FRAME_SECONDS := 0.14
const PAPER_SHADER := preload("res://shaders/opening_paper.gdshader")

@export var outline := PackedVector2Array()
@export var page_size := Vector2(1672, 941)
@export var phase := 0.0
@export var unfold_duration := 1.15
@export var white_border_pixels := 0.0
@export var paper_shadow_enabled := true

var elapsed := 0.0
var unfold_progress := 0.0
var idle_frame := 0
var paper_material: ShaderMaterial
var shadow_material: ShaderMaterial
var narration_labels: Array[Label] = []

func _ready() -> void:
	mesh = _build_mesh()
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	paper_material = _make_material(bounds, false)
	material = paper_material
	var shadow := MeshInstance2D.new()
	shadow.name = "PaperShadow"
	shadow.mesh = mesh
	shadow.texture = texture
	shadow.position = Vector2(2.0, 4.0)
	shadow.z_index = -1
	shadow.visible = paper_shadow_enabled
	shadow_material = _make_material(bounds, true)
	shadow.material = shadow_material
	add_child(shadow)

func _make_material(bounds: Rect2, is_shadow: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = PAPER_SHADER
	result.set_shader_parameter("paper_center", bounds.get_center())
	result.set_shader_parameter("paper_size", bounds.size)
	result.set_shader_parameter("phase", phase)
	result.set_shader_parameter("shadow_pass", is_shadow)
	result.set_shader_parameter("white_border_pixels", white_border_pixels)
	result.set_shader_parameter("unfold", 0.0)
	return result

func reveal() -> void:
	elapsed = 0.0
	unfold_progress = 0.0
	idle_frame = 0
	show()
	_update_materials()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	unfold_progress = clampf(elapsed / unfold_duration, 0.0, 1.0)
	idle_frame = int(floor(maxf(0.0, elapsed - unfold_duration) / IDLE_FRAME_SECONDS)) % 2
	_update_materials()

func _update_materials() -> void:
	for label in narration_labels:
		label.modulate.a = smoothstep(0.72, 1.0, unfold_progress)
	for surface in [paper_material, shadow_material]:
		surface.set_shader_parameter("unfold", unfold_progress)
		surface.set_shader_parameter("idle_frame", float(idle_frame))

func _build_mesh() -> ArrayMesh:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Clip every small cell to the original panel outline, including the
	# diagonal gutter. Interior vertices allow real folds rather than a
	# four-corner scale animation, and keep text attached to its paper.
	var rows := ceili(bounds.size.y / CELL_SIZE)
	var columns := ceili(bounds.size.x / CELL_SIZE)
	for row in range(rows):
		for column in range(columns):
			var corner := bounds.position + Vector2(column, row) * CELL_SIZE
			var cell := PackedVector2Array([corner, corner + Vector2(CELL_SIZE, 0),
				corner + Vector2.ONE * CELL_SIZE, corner + Vector2(0, CELL_SIZE)])
			for clipped in Geometry2D.intersect_polygons(cell, outline):
				var triangles := Geometry2D.triangulate_polygon(clipped)
				var first := vertices.size()
				for point in clipped:
					vertices.append(Vector3(point.x, point.y, 0))
					uvs.append(point / page_size)
				for index in triangles:
					indices.append(first + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
