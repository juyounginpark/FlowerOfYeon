extends Node3D
# Stage5 crossing geometry and placement contract, using Stage5TreeBridge.
const GEOMETRY=preload("res://scripts/grid_stage/story_geometry.gd")
var world:GridStageWorld
var camera:Camera3D
var paper:GridPaperCutting
var trees:Array[Sprite3D]=[]
var routes:Array=[]
var bridges:Dictionary={}
var bridge_age:Dictionary={}
var bridge_previews:Array[Node3D]=[]
var tree_bridge:Node
var hint:Label

func _bridge_candidate(piece:Dictionary,point:Vector2) -> int:
	if not trees.has(piece.source.sprite) or piece.attached:return -1
	# Any source tree can supply either crossing. Use the dropped piece's actual
	# outline as well as the grab point so the bridge does not depend on grip.
	var outline:=PackedVector2Array()
	for vertex:Vector2 in piece.polygon:
		outline.append(paper._screen(camera.unproject_position(piece.visual.global_transform*Vector3(vertex.x,-vertex.y,0))))
	var index:=-1;var nearest:=INF
	for candidate:int in range(routes.size()):
		if tree_bridge.is_complete(candidate):continue
		var a:Vector2=paper._screen(camera.unproject_position(routes[candidate][0]))
		var b:Vector2=paper._screen(camera.unproject_position(routes[candidate][1]))
		var distance:float=point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))
		var overlaps:bool=Geometry2D.is_point_in_polygon((a+b)*.5,outline)
		for edge:int in range(outline.size()):
			if Geometry2D.segment_intersects_segment(a,b,outline[edge],outline[(edge+1)%outline.size()])!=null:overlaps=true
		if (overlaps or distance<=1000.0/camera.size*1.6) and distance<nearest:
			index=candidate;nearest=distance
	return index

func _update_bridge_preview() -> void:
	for preview:Node3D in bridge_previews:preview.hide()
	if world.paused or world.transition.active or world.player.input_locked or world.completed:return
	if not is_instance_valid(paper.grabbed) or paper.locked:return
	var index:=_bridge_candidate(paper.grabbed_piece,paper._mouse())
	if index>=0:bridge_previews[index].show()

func _build_bridge(index:int) -> void:
	bridges[index]=_create_bridge(index);bridge_age[index]=0.0

func _create_bridge(index:int,preview:=false) -> Node3D:
	var a:Vector3=routes[index][0];var b:Vector3=routes[index][1]
	var horizontal:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var crossing:=Node3D.new()
	crossing.name=("TreeBridgePreview%d" if preview else "TreeBridge%d")%index
	if preview:crossing.hide()
	add_child(crossing)
	for span:Array in [[a-horizontal*.35,a],[a,b],[b,b+horizontal*.4]]:
		_bridge_span(crossing,span[0],span[1],preview)
	if not preview:preload("res://scripts/grid_stage/tree_bridge_collision.gd").join_spans(crossing)
	return crossing

func _bridge_span(crossing:Node3D,a:Vector3,b:Vector3,preview:=false) -> void:
	var forward:Vector3=(b-a).normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	var up:=right.cross(forward).normalized()
	var size:=Vector3(1.6,.18,a.distance_to(b))
	var body:Node3D
	if preview:
		body=Node3D.new();crossing.add_child(body);body.position=(a+b)*.5-up*.09
	else:body=GEOMETRY.box(crossing,(a+b)*.5-up*.09,size,Color("a28359"),false)
	body.basis=Basis(right,up,-forward)
	if not preview:return # TreeBridgeArt supplies the painted deck after assembly.
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color=Color(.35,.85,.65,.45) if preview else Color("a28359")
	if preview:ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh:=MeshInstance3D.new();var wood:=CylinderMesh.new()
	mesh.set_meta("paper_protect_player",true);mesh.set_meta("bridge_draw_priority",125)
	wood.top_radius=.5;wood.bottom_radius=.5;wood.height=size.z;wood.radial_segments=12
	mesh.mesh=wood;mesh.material_override=ink
	mesh.rotation.x=PI*.5;mesh.scale=Vector3(size.x,1,size.y);body.add_child(mesh)

