extends RefCounted
static func release(story:Node3D,index:int,a:Vector2,b:Vector2) -> bool:
	var bird:Dictionary=story.birds[index]
	var fruit:Sprite3D=bird.gourd
	var stem_region:PackedVector2Array=story._mouth_polygon(index)
	var touches_stem:bool=Geometry2D.is_point_in_polygon(a,stem_region) or Geometry2D.is_point_in_polygon(b,stem_region)
	for edge:int in stem_region.size():
		if Geometry2D.segment_intersects_segment(a,b,stem_region[edge],stem_region[(edge+1)%stem_region.size()])!=null:touches_stem=true
	if not touches_stem:return false
	var image:=fruit.texture.get_image()
	if image.is_compressed():image.decompress()
	if fruit.flip_h:image.flip_x()
	var bitmap:=BitMap.new();bitmap.create_from_image_alpha(image,.12)
	var outlines:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),1.0)
	var polygon:=PackedVector2Array()
	for shape:PackedVector2Array in outlines:
		if story._area(shape)>story._area(polygon):polygon=shape
	var center:Vector2=story._screen(story.camera.unproject_position(fruit.global_position))
	var unit:float=fruit.pixel_size*1000.0/story.camera.size
	var start:Vector2=(a-center)/unit+Vector2(image.get_size())*.5
	var end:Vector2=(b-center)/unit+Vector2(image.get_size())*.5
	var crossings:=0
	for i:int in polygon.size():
		if Geometry2D.segment_intersects_segment(start,end,polygon[i],polygon[(i+1)%polygon.size()])!=null:crossings+=1
	if crossings<2:return false
	var direction:Vector2=(end-start).normalized();var normal:=direction.orthogonal()
	var parts:Array[PackedVector2Array]=[]
	for side:float in [-1.0,1.0]:
		var half:=PackedVector2Array([start-direction*10000,start+direction*10000,start+direction*10000+normal*side*10000,start-direction*10000+normal*side*10000])
		for clipped:PackedVector2Array in Geometry2D.intersect_polygons(polygon,half):
			if story._area(clipped)>4:parts.append(clipped)
	if parts.size()<2:return false
	parts.sort_custom(func(left:PackedVector2Array,right:PackedVector2Array):return story._area(left)>story._area(right))
	var texture:=ImageTexture.create_from_image(image)
	var attachment:Vector2=preload("res://scripts/grid_stage/heungbu_minhwa.gd").stem_anchor(texture)
	var anchor:Vector2=Vector2(image.get_size())*.5+Vector2(attachment.x,-attachment.y)
	var fixed:=-1
	var nearest:=INF
	for part_index:int in parts.size():
		var part:PackedVector2Array=parts[part_index]
		if Geometry2D.is_point_in_polygon(anchor,part):fixed=part_index;break
		for edge:int in part.size():
			var distance:float=anchor.distance_squared_to(Geometry2D.get_closest_point_to_segment(anchor,part[edge],part[(edge+1)%part.size()]))
			if distance<nearest:nearest=distance;fixed=part_index
	# A stem cut must disconnect the heavy fruit from the held tip.
	if fixed==0:return false
	fruit.texture=texture;fruit.flip_h=false
	fruit.set_meta("paper_source_outline",parts[0])
	story.delivery.separate(index)
	var item:Dictionary=bird.item
	var falling:=_mesh(fruit,parts[0]);item.body.add_child(falling)
	falling.global_transform=fruit.global_transform;item["cut_visual"]=falling
	# Replace the temporary sphere with the actual severed silhouette prism.
	for child:Node in item.body.get_children():
		if child is CollisionShape3D:child.shape=_shape(fruit,parts[0],item.body)
	for part_index:int in range(1,parts.size()):
		var stem:=_mesh(fruit,parts[part_index])
		if part_index==fixed:
			bird.sprite.add_child(stem)
		else:
			var body:=RigidBody3D.new();body.name="LooseGourdStem"
			body.collision_layer=0;body.collision_mask=5;body.continuous_cd=true
			story.add_child(body);body.global_position=fruit.global_position
			var collision:=CollisionShape3D.new();collision.shape=_shape(fruit,parts[part_index],body);body.add_child(collision)
			body.add_child(stem);story.loose_stems.append(body)
		stem.global_transform=fruit.global_transform
	fruit.hide()
	return true

static func _shape(source:Sprite3D,polygon:PackedVector2Array,body:RigidBody3D) -> ConvexPolygonShape3D:
	var points:=PackedVector3Array()
	var size_:Vector2=source.texture.get_size()
	var relative:Transform3D=body.global_transform.affine_inverse()*source.global_transform
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for point:Vector2 in polygon:bounds=bounds.expand(point)
	var half_depth:float=maxf(.04,bounds.size.x*source.pixel_size*.18)
	for point:Vector2 in polygon:
		for depth:float in [-half_depth,half_depth]:
			points.append(relative*Vector3((point.x-size_.x*.5)*source.pixel_size,(size_.y*.5-point.y)*source.pixel_size,depth))
	var shape:=ConvexPolygonShape3D.new();shape.points=points
	return shape

static func _mesh(source:Sprite3D,polygon:PackedVector2Array) -> MeshInstance3D:
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
	var size:=source.texture.get_size()
	for point:Vector2 in polygon:
		vertices.append(Vector3((point.x-size.x*.5)*source.pixel_size,(size.y*.5-point.y)*source.pixel_size,0));uvs.append(point/size)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(polygon)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual:=MeshInstance3D.new();visual.mesh=mesh
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.albedo_texture=source.texture
	visual.material_override=ink
	return visual
