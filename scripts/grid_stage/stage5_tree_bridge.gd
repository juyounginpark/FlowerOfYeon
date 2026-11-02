extends Node
# Accumulate real cut paper, then crossfade to a painting of the collision deck.
const BRIDGE_ART=preload("res://scripts/grid_stage/tree_bridge_art.gd")
var required_coverage:=0.55
var walk_condition:Callable
const GRID:=Vector2i(24,64)
const REGROW_SECONDS:=3.0
var story:Node3D
var growth:Dictionary={}
var fading:Array[Dictionary]=[]
var layers:Dictionary={}
var coverage:Dictionary={}
var debris:Array[Dictionary]=[]
var finished_art:Dictionary={}

func _physics_process(_delta:float) -> void:
	if story==null:return
	for index:int in story.bridges.keys():_sync_collision(index)
	for entry:Dictionary in debris:
		entry.body.freeze=story.world.paused or story.world.transition.active or story.world.player.input_locked

func configure(owner_story:Node3D) -> void:
	story=owner_story
	for tree:Sprite3D in story.trees:
		tree.set_meta("paper_bridge_only",true)
		tree.set_meta("paper_grab_margin",24.0)

func cut_tree(sprite:Sprite3D) -> void:
	# Cutting loose scraps does not restart an intact tree's timer.
	for piece:Dictionary in story.paper.pieces:
		if piece.source.sprite==sprite and piece.attached and is_equal_approx(story.paper._area(piece.polygon),story.paper._area(piece.source.polygon)):return
	growth[sprite]=REGROW_SECONDS

func tick(delta:float) -> void:
	for entry:Dictionary in debris.duplicate():
		entry.age+=delta
		entry.material.albedo_color.a=float(entry.get("opacity",1.0))*(1.0-clampf((entry.age-3.0)/1.0,0,1))
		if entry.age>=4.0:
			entry.body.queue_free();debris.erase(entry)
	for sprite:Sprite3D in growth.keys():
		growth[sprite]-=delta
		if growth[sprite]>0:continue
		growth.erase(sprite)
		if story.has_method("regrow_source"):
			story.regrow_source(sprite);continue
		# Replace only the rooted stump. Loose and mounted cut pieces survive.
		for piece:Dictionary in story.paper.pieces.duplicate():
			if piece.source.sprite==sprite and piece.attached:
				piece.body.queue_free();piece.visual.queue_free();story.paper.pieces.erase(piece)
		for source:Dictionary in story.paper.sources:
			if source.sprite!=sprite:continue
			var pose:=Transform2D(-(story.camera.global_basis.inverse()*sprite.global_basis).get_euler().z,story.paper._screen(story.camera.unproject_position(sprite.global_position)))
			story.paper._add_piece(source,source.polygon,pose,true)
			var fresh:Dictionary=story.paper.pieces.back()
			fresh.paper_material.albedo_color.a=0
			fading.append({"piece":fresh,"time":0.0})
	for entry:Dictionary in fading.duplicate():
		if not is_instance_valid(entry.piece.visual):fading.erase(entry);continue
		entry.time+=delta
		entry.piece.paper_material.albedo_color.a=minf(entry.time/.8,1)
		if entry.time>=.8:fading.erase(entry)
	for index:int in layers.keys():
		var remaining:Array=layers[index].filter(func(piece):return story.paper.pieces.has(piece) and piece.sticker and piece.host==story.bridges.get(index))
		if remaining.size()!=layers[index].size():
			layers[index]=remaining;refresh(index)
	if story.world.paused or story.world.transition.active or story.world.player.input_locked:return
	for index:int in finished_art.keys():
		var opacity:float=finished_art[index].advance(delta)
		for piece:Dictionary in layers[index]:piece["bridge_opacity"]=opacity

func mount(index:int,piece:Dictionary,point:Vector2) -> void:
	if is_complete(index):return
	if not story.bridges.has(index):
		story._build_bridge(index);layers[index]=[]
	for previous:int in layers.keys():
		if layers[previous].has(piece):layers[previous].erase(piece);refresh(previous)
	var a:Vector3=story.routes[index][0];var b:Vector3=story.routes[index][1]
	var forward:Vector3=(b-a).normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	var normal:=right.cross(forward).normalized()
	var screen:Vector2=point*story.get_viewport().get_visible_rect().size.y/1000.0
	var plane:=Plane(normal,a)
	var hit:Variant=plane.intersects_ray(story.camera.project_ray_origin(screen),story.camera.project_ray_normal(screen))
	var anchor:Vector3=(a+b)*.5 if hit==null else Vector3(hit)
	var along:=clampf((anchor-a).dot(forward),-.25,a.distance_to(b)+.25)
	var across:=clampf((anchor-a).dot(right),-.75,.75)
	anchor=a+forward*along+right*across
	var bounds:=Rect2(piece.polygon[0],Vector2.ZERO)
	for vertex:Vector2 in piece.polygon:bounds=bounds.expand(vertex)
	# Same scale on both axes, same rotation and UVs as the original cut paper.
	var axes:Basis=story.camera.global_basis*Basis(Vector3.FORWARD,piece.body.rotation)
	axes=axes.scaled(Vector3.ONE*story.camera.size/1000.0)
	var center:=Vector3(bounds.get_center().x,-bounds.get_center().y,0)
	var pose:=Transform3D(axes,anchor+story.camera.global_basis.z*(.035+layers[index].size()*.001)-axes*center)
	piece.attached=false;piece.sticker=true;piece.host=story.bridges[index]
	piece.host_pose=piece.host.global_transform.affine_inverse()*pose
	piece.visual.global_transform=pose;piece.body.freeze=true
	layers[index].append(piece);story.bridge_age[index]=0.0
	refresh(index)
	story.hint.text="나무 다리 %d%% / %d%% — 작은 조각도 겹치지 않게 붙여주세요."%[roundi(coverage[index]*100),roundi(required_coverage*100)]
	if is_complete(index):
		story.hint.text="나무 다리가 이어졌습니다. 이제 건널 수 있습니다." if ready_to_walk(index) else "나무 다리가 완성됐습니다. 가짜를 쫓아낸 뒤 건널 수 있습니다."

func refresh(index:int) -> void:
	if not story.bridges.has(index):return
	if finished_art.has(index):return
	var a:Vector3=story.routes[index][0];var b:Vector3=story.routes[index][1]
	var right:Vector3=(b-a).normalized().cross(Vector3.UP).normalized()
	var occupied:=0
	# Union of actual visible ink: overlaps and transparent PNG areas count once/zero.
	for row:int in range(GRID.y):
		for col:int in range(GRID.x):
			var point:=a.lerp(b,(row+.5)/GRID.y)+right*((col+.5)/GRID.x-.5)*1.6
			var pixel:Vector2=story.paper._screen(story.camera.unproject_position(point))
			for piece:Dictionary in layers[index]:
				var picked:Dictionary=story.paper._local_at(piece,pixel)
				if picked.is_empty() or not Geometry2D.is_point_in_polygon(picked.local,piece.polygon):continue
				var uv:Vector2=Vector2(picked.local)/float(piece.source.scale)+Vector2(piece.source.image.get_size())*.5
				var cell:=Vector2i(uv)
				if not Rect2i(Vector2i.ZERO,piece.source.image.get_size()).has_point(cell):continue
				if piece.source.image.get_pixelv(cell).a>.15:occupied+=1;break
	coverage[index]=float(occupied)/(GRID.x*GRID.y)
	for piece:Dictionary in layers[index]:piece["bridge_ready"]=coverage[index]>=required_coverage
	if is_complete(index):
		var art:=BRIDGE_ART.new();art.configure(story.bridges[index]);finished_art[index]=art
		# Retain assembled pieces and their state, but stop picking invisible wood.
		for piece:Dictionary in layers[index]:
			piece["permanent"]=true;piece["bridge_opacity"]=1.0
	_sync_collision(index)

func is_complete(index:int) -> bool:
	return float(coverage.get(index,0.0))>=required_coverage

func ready_to_walk(index:int) -> bool:
	return is_complete(index) and (not walk_condition.is_valid() or bool(walk_condition.call()))

func _sync_collision(index:int) -> void:
	if not story.bridges.has(index):return
	var enabled:=ready_to_walk(index)
	for body:Node in story.bridges[index].get_children():
		if body is StaticBody3D:body.collision_layer=1 if enabled else 0

func knock_down(index:int) -> void:
	if not story.bridges.has(index):return
	# Remove walkable support immediately, before deferred node deletion.
	for body:Node in story.bridges[index].get_children():
		if body is StaticBody3D:body.collision_layer=0
	var sideways:Vector3=(Vector3(story.routes[index][1])-Vector3(story.routes[index][0])).normalized().cross(Vector3.UP)
	if finished_art.has(index):
		# The replacement painting falls on the same real box shapes as the deck.
		debris.append_array(finished_art[index].release(story,sideways));finished_art.erase(index)
	for piece:Dictionary in layers.get(index,[]):
		# Release the visible fragment into map gravity/collision, retaining its pose.
		# Scraps keep terrain collision without supporting or blocking the player.
		var falling:=RigidBody3D.new();falling.collision_layer=0;falling.collision_mask=1
		story.add_child(falling);falling.global_position=piece.visual.global_position
		piece.visual.reparent(falling,true)
		piece.visual.set_meta("wall_layer_attached",false)
		piece.visual.set_meta("paper_protect_player",false)
		piece.visual.remove_meta("bridge_draw_priority")
		piece.visual.set_meta("paper_foreground",false)
		piece.visual.set_meta("slice_whole",false)
		piece.visual.remove_meta("screen_band")
		piece.visual.material_override=piece.paper_material
		piece.paper_material.no_depth_test=false;piece.paper_material.render_priority=0
		piece.border.hide();piece.shadow.hide()
		var vertices:=PackedVector3Array()
		for vertex:Vector2 in piece.polygon:
			var at:Vector3=falling.to_local(piece.visual.to_global(Vector3(vertex.x,-vertex.y,0)))
			vertices.append(at+Vector3.UP*.025);vertices.append(at-Vector3.UP*.025)
		var shape:=ConvexPolygonShape3D.new();shape.points=vertices
		var collider:=CollisionShape3D.new();collider.shape=shape;falling.add_child(collider)
		falling.linear_velocity=sideways*3.5+Vector3.DOWN*.8
		falling.angular_velocity=Vector3(1.5,0,2.0)
		piece.body.queue_free();story.paper.pieces.erase(piece)
		debris.append({"body":falling,"material":piece.paper_material,"age":0.0,"opacity":piece.paper_material.albedo_color.a})
	story.bridges[index].queue_free();story.bridges.erase(index);story.bridge_age.erase(index)
	layers.erase(index);coverage.erase(index)
