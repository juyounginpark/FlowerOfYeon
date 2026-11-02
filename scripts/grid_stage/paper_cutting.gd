class_name GridPaperCutting
extends Node3D
signal source_cut(sprite:Sprite3D)
signal piece_dropped(piece:Dictionary,point:Vector2)
# Real RigidBody2D simulation in a fixed 1000-unit screen-height plane. Only
# intact geometry stays behind the stage; loose pieces use a foreground plane.
# Surface stickers retain ordinary depth testing and collider-local transforms.
@export var max_fragments:=72
@export var minimum_piece_area:=90.0
var camera:Camera3D
var world:Node
var sources:Array=[]
var source_shapes:Dictionary={}
var pieces:Array[Dictionary]=[]
var drawing:=false
var line_start:=Vector2.ZERO
var line_end:=Vector2.ZERO
var pointer_position:=Vector2.ZERO
var pointer_observed:=false
var grabbed:RigidBody2D
var grab_offset:=Vector2.ZERO
var grabbed_piece:Dictionary={}
var grab_local:=Vector2.ZERO
var prior_sticker:Dictionary={}
var surface_preview:Dictionary={}
var stand_perpendicular:=false
const SURFACE_OFFSET:=0.008
# Widths use the same 1000-unit screen-height plane as the cut polygons.
const PAPER_BORDER_WIDTH:=3.2
const PAPER_COLOR:=Color("faf6eb")
var simulation:SubViewport
var overlay:CanvasLayer
var stroke:Line2D
var locked:=false
func configure(view:Camera3D,sprites:Array[Sprite3D]) -> void:
	camera=view;world=camera.get_parent()
	# Separate physics space: collage floors cannot collide with gameplay or UI.
	simulation=SubViewport.new();simulation.size=Vector2i(2,2)
	simulation.world_2d=World2D.new();simulation.disable_3d=true
	simulation.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(simulation)
	overlay=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	stroke=Line2D.new();stroke.width=2.0;stroke.default_color=Color("f3e7ce");overlay.add_child(stroke)
	for sprite:Sprite3D in sprites:add_source(sprite)

func add_source(sprite:Sprite3D) -> void:
	var index:int=sources.size()
	var texture:Texture2D=sprite.texture
	# Preserve dynamic add_source while reusing repeated images' alpha tracing.
	if not source_shapes.has(texture):
		var source_image:=texture.get_image()
		if source_image.is_compressed():source_image.decompress()
		var bitmap:=BitMap.new();bitmap.create_from_image_alpha(source_image,.12)
		var source_outlines:Array[PackedVector2Array]=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,source_image.get_size()),2.5)
		if source_outlines.is_empty():return
		var source_outline:PackedVector2Array=source_outlines[0]
		for candidate:PackedVector2Array in source_outlines:
			if _area(candidate)>_area(source_outline):source_outline=candidate
		var local_texture:Texture2D=ImageTexture.create_from_image(source_image) if texture is AtlasTexture else texture
		source_shapes[texture]={"image":source_image,"outline":source_outline,"outlines":source_outlines,"texture":local_texture}
	var shared:Dictionary=source_shapes[texture]
	var image:Image=shared.image
	var outlines:Array[PackedVector2Array]=shared.outlines
	var outline:PackedVector2Array=shared.outline
	texture=shared.texture
	if bool(sprite.get_meta("paper_convex_outline",false)):
		var all_points:=PackedVector2Array()
		for contour:PackedVector2Array in outlines:all_points.append_array(contour)
		outline=Geometry2D.convex_hull(all_points)
		if outline.size()>1 and outline[0]==outline[outline.size()-1]:outline.remove_at(outline.size()-1)
	# A previously cut Stage7 gourd supplies its exact remaining pixel outline.
	# Keep that contour when transferring from 3D falling physics to paper cutting.
	if sprite.has_meta("paper_source_outline"):outline=sprite.get_meta("paper_source_outline")
	var unit_scale:float=sprite.pixel_size*1000.0/camera.size
	var polygon:=PackedVector2Array()
	for point in outline:polygon.append((point-Vector2(image.get_size())*.5)*unit_scale)
	if sprite.get_meta("paper_outline_fallback",false) and Geometry2D.triangulate_polygon(polygon).is_empty():
		polygon=Geometry2D.convex_hull(polygon)
		if polygon.size()>1 and polygon[0]==polygon[polygon.size()-1]:polygon.remove_at(polygon.size()-1)
	var center:=_screen(camera.unproject_position(sprite.global_position))
	var angle:float=-(camera.global_basis.inverse()*sprite.global_basis).get_euler().z
	var transform:=Transform2D(angle,center)
	var baseline:float=-INF
	for point in polygon:baseline=maxf(baseline,(transform*point).y)
	baseline=maxf(baseline,float(sprite.get_meta("paper_floor_y",baseline)))
	var layer:int=1<<index
	var floor_body:=StaticBody2D.new();floor_body.collision_layer=layer;floor_body.collision_mask=layer
	floor_body.position=Vector2(0,baseline+12);simulation.add_child(floor_body)
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(20000,24);shape.shape=box;floor_body.add_child(shape)
	var source:Dictionary={"sprite":sprite,"texture":texture,"image":image,"scale":unit_scale,"layer":layer,"baseline":baseline,"stem":_stem_point(polygon,bool(sprite.get_meta("paper_hanging",false))),"polygon":polygon.duplicate(),"floor":floor_body,"depth":float(sprite.get_meta("background_depth",55.0))}
	sources.append(source)
	_add_piece(source,polygon,transform,true)
	sprite.visible=false

func hide_source(sprite:Sprite3D) -> void:
	if is_instance_valid(grabbed) and grabbed_piece.source.sprite==sprite:_finish_drag(false)
	for piece:Dictionary in pieces.duplicate():
		if piece.source.sprite!=sprite:continue
		piece.body.queue_free();piece.visual.queue_free();pieces.erase(piece)

func restore_source(sprite:Sprite3D) -> void:
	hide_source(sprite)
	for source:Dictionary in sources:
		if source.sprite!=sprite:continue
		var center:=_screen(camera.unproject_position(sprite.global_position))
		var pose:=Transform2D(-(camera.global_basis.inverse()*sprite.global_basis).get_euler().z,center)
		var baseline:float=-INF
		for point:Vector2 in source.polygon:baseline=maxf(baseline,(pose*point).y)
		baseline=maxf(baseline,float(sprite.get_meta("paper_floor_y",baseline)))
		source.baseline=baseline;source.floor.position.y=baseline+12
		_add_piece(source,source.polygon,pose,true)
		sprite.hide()
		return

func _stem_point(polygon:PackedVector2Array,hanging:=false) -> Vector2:
	# Select an interior point just above the actual opaque bottom, rather than
	# guessing a point in transparent padding of the supplied sheet.
	var bottom:Vector2=polygon[0]
	for point in polygon:
		if (point.y<bottom.y if hanging else point.y>bottom.y):bottom=point
	for rise:float in [1.0,2.0,4.0,8.0]:
		for offset:float in [0.0,-1.0,1.0,-3.0,3.0]:
			var candidate:=bottom+Vector2(offset,rise if hanging else -rise)
			if Geometry2D.is_point_in_polygon(candidate,polygon):return candidate
	return bottom
func _screen(point:Vector2) -> Vector2:
	return point*1000.0/maxf(get_viewport().get_visible_rect().size.y,1)
func _mouse() -> Vector2:
	return _screen(pointer_position if pointer_observed else get_viewport().get_mouse_position())
func _area(polygon:PackedVector2Array) -> float:
	var sum:=0.0
	for i in polygon.size():sum+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(sum)*.5
func _add_piece(source:Dictionary,polygon:PackedVector2Array,pose:Transform2D,attached:bool) -> void:
	var indices:PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():return
	var body:=RigidBody2D.new();body.contact_monitor=true;body.max_contacts_reported=4;body.collision_layer=0 if attached else int(source.layer);body.collision_mask=int(source.layer)
	body.freeze=attached;body.gravity_scale=1;body.linear_damp=.6;body.angular_damp=1.6
	body.lock_rotation=not attached # Detached paper keeps its fresh cut edge as its base.
	var material:=PhysicsMaterial.new();material.friction=.7;material.bounce=.12;body.physics_material_override=material
	simulation.add_child(body);body.transform=pose
	if source.sprite.get_meta("paper_convex_collision",false):
		# Opt-in for convex sources: half-plane cuts preserve convexity.
		var collision:=CollisionShape2D.new();var shape:=ConvexPolygonShape2D.new()
		shape.points=polygon;collision.shape=shape;body.add_child(collision)
	elif source.sprite.get_meta("triangle_cut_collision",false):
		# Fine feather outlines may triangulate but fail the engine's convex merge.
		# Reuse the exact rendering triangles for collision, preserving the cut edge.
		for triangle in range(0,indices.size(),3):
			var collision:=CollisionShape2D.new();var shape:=ConvexPolygonShape2D.new()
			shape.points=PackedVector2Array([polygon[indices[triangle]],polygon[indices[triangle+1]],polygon[indices[triangle+2]]])
			collision.shape=shape;body.add_child(collision)
	else:
		var collision:=CollisionPolygon2D.new();collision.polygon=polygon;body.add_child(collision)
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
	for point in polygon:
		vertices.append(Vector3(point.x,-point.y,0))
		uvs.append((point/float(source.scale)+Vector2(source.image.get_size())*.5)/Vector2(source.image.get_size()))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.albedo_texture=source.texture;ink.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var visual:=MeshInstance3D.new();visual.set_meta("slice_whole",true);visual.mesh=mesh;visual.material_override=ink;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if bool(source.sprite.get_meta("paper_foreground",false)):
		visual.set_meta("paper_foreground",true);visual.set_meta("screen_band",11)
		ink.no_depth_test=true;ink.render_priority=maxi(120,source.sprite.material_override.render_priority)
	var piece:Dictionary={"body":body,"visual":visual,"polygon":polygon,"source":source,"attached":attached,"sticker":false,"perpendicular":false,"host":null,"host_pose":Transform3D.IDENTITY,"paper_material":ink}
	pieces.append(piece);_grounded_piece_layer(piece);add_child(visual)
	piece["shadow"]=_make_cut_layer(polygon,visual,false)
	piece["border"]=_make_cut_layer(polygon,visual,true,source.sprite.get_meta("paper_color",PAPER_COLOR))
	piece.border.visible=bool(source.sprite.get_meta("paper_border",true))
	if attached and bool(source.sprite.get_meta("paper_hide_intact_border",false)):
		piece.shadow.hide();piece.border.hide()
	if bool(source.sprite.get_meta("paper_alpha_border",false)):
		for layer:MeshInstance3D in [piece.shadow,piece.border]:
			var border_ink:=ShaderMaterial.new();border_ink.shader=preload("res://shaders/grid_paper_alpha_border.gdshader")
			border_ink.render_priority=-1 if layer==piece.border else -2
			border_ink.set_shader_parameter("source_ink",source.texture)
			border_ink.set_shader_parameter("source_size",Vector2(source.image.get_size()))
			border_ink.set_shader_parameter("source_scale",source.scale)
			border_ink.set_shader_parameter("radius",PAPER_BORDER_WIDTH if layer==piece.border else 7.0)
			border_ink.set_shader_parameter("shadow_offset",Vector2.ZERO if layer==piece.border else Vector2(4.5,6))
			layer.material_override=border_ink
	# Keep source materials available after screen slices replace render overrides.
	piece["border_material"]=piece.border.material_override
	piece["shadow_material"]=piece.shadow.material_override
	_update_loose_foreground(piece)

func _update_loose_foreground(piece:Dictionary) -> void:
	# Explicit opt-in for the Stage6 rice scraps; physics remains unchanged.
	if not bool(piece.source.sprite.get_meta("paper_loose_foreground",false)):return
	var foreground:bool=not bool(piece.attached)
	var ordered:Array[MeshInstance3D]=[piece.shadow,piece.border,piece.visual]
	for i:int in range(ordered.size()):
		var visual:MeshInstance3D=ordered[i]
		visual.set_meta("paper_foreground",foreground)
		if foreground:
			visual.remove_meta("story_layer")
			visual.layers=(1<<(8+11))|(1<<20)
		var ink:StandardMaterial3D=piece.paper_material if visual==piece.visual else visual.material_override
		ink.no_depth_test=foreground
		ink.render_priority=118+i if foreground else i-2

func _update_surface_art(piece:Dictionary) -> void:
	if not piece.source.sprite.has_meta("paper_mounted_texture"):return
	var mounted_texture:Texture2D=piece.source.sprite.get_meta("paper_mounted_texture",null)
	if mounted_texture==null:return
	var mounted:bool=piece.sticker
	if mounted==bool(piece.get("mounted_art",false)):return
	piece["mounted_art"]=mounted
	if mounted:
		piece["loose_mesh"]=piece.visual.mesh;piece["loose_polygon"]=piece.polygon
		var size:Vector2=piece.source.sprite.get_meta("paper_mounted_size")*1000.0/camera.size
		var quad:=QuadMesh.new();quad.size=size;piece.visual.mesh=quad
		var half:=size*.5
		piece.polygon=PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
		piece.paper_material.albedo_texture=mounted_texture
	else:
		piece.visual.mesh=piece.loose_mesh;piece.polygon=piece.loose_polygon
		piece.paper_material.albedo_texture=piece.source.texture
	piece.border.visible=not mounted;piece.shadow.visible=not mounted

func _grounded_piece_layer(piece:Dictionary) -> void:
	var source_sprite:Sprite3D=piece.source.sprite
	if source_sprite.has_meta("paper_standing_layer") or source_sprite.has_meta("paper_story_layer"):
		var intact:bool=bool(piece.attached) and not bool(piece.sticker)
		if intact:
			var band:int=int(source_sprite.get_meta("paper_standing_layer",source_sprite.get_meta("paper_story_layer",0)))
			piece.visual.set_meta("story_layer",band);piece.visual.set_meta("screen_band",band)
			if source_sprite.has_meta("paper_standing_layer"):piece.visual.material_override=piece.get("regrow_material",source_sprite.material_override)
		else:
			# Released Stage6 paper uses normal depth and band placement.
			piece.visual.remove_meta("story_layer");piece.visual.remove_meta("screen_band")
			piece.visual.material_override=piece.paper_material
			piece.paper_material.no_depth_test=false
		if piece.has("border") and bool(source_sprite.get_meta("paper_hide_intact_border",false)):
			piece.border.visible=not intact;piece.shadow.visible=not intact
		return
	if not bool(piece.source.sprite.get_meta("paper_grounded",false)):return
	var standing:bool=bool(piece.attached) and not bool(piece.sticker)
	piece.visual.set_meta("paper_foreground",false)
	if standing:piece.visual.set_meta("screen_band",int(piece.source.sprite.get_meta("screen_band",0)))
	else:piece.visual.remove_meta("screen_band")
	if standing:
		# Preserve the same perspective/haze/ground fade shader as the source.
		piece.visual.material_override=piece.source.sprite.material_override
	else:
		var ink:StandardMaterial3D=piece.paper_material
		piece.visual.material_override=ink;ink.no_depth_test=false;ink.render_priority=0

static func _make_cut_layer(polygon:PackedVector2Array,visual:GeometryInstance3D,border:bool,paper_color:Color=PAPER_COLOR,border_width:float=PAPER_BORDER_WIDTH) -> MeshInstance3D:
	# Expand the actual silhouette, including fresh cut edges. The warm paper
	# backing sits between the printed art and a soft lower-right drop shadow.
	# A faint outer contour softens the paper edge without enlarging hitboxes.
	var vertices:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	var radii:Array=[border_width+.65,border_width] if border else [14.0,11.5,9.0,6.5,4.5,3.2]
	var opacities:Array=[.24,1.0] if border else [.018,.028,.042,.060,.085,.11]
	var offset:=Vector2.ZERO if border else Vector2(4.5,6.0)
	var tint:Color=paper_color if border else Color("29251e")
	for ring in range(radii.size()):
		for contour:PackedVector2Array in Geometry2D.offset_polygon(polygon,radii[ring],Geometry2D.JOIN_ROUND):
			var triangles:=Geometry2D.triangulate_polygon(contour)
			if triangles.is_empty():continue
			var base:=vertices.size()
			for point in contour:
				vertices.append(Vector3(point.x+offset.x,-point.y-offset.y,-.04 if border else -.1))
				colors.append(Color(tint,opacities[ring]))
			for index in triangles:indices.append(base+index)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	ink.vertex_color_use_as_albedo=true;ink.render_priority=-1 if border else -2
	var layer:=MeshInstance3D.new();layer.name="CuttablePaperBorder" if border else "CuttableDropShadow";layer.mesh=mesh;layer.material_override=ink
	layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.set_meta("slice_whole",true);layer.set_meta("cut_paper_owner",visual.get_instance_id())
	visual.add_child(layer)
	return layer
func _process(_delta:float) -> void:
	var next_lock:bool=bool(world.get("paused")) or world.transition.active or world.player.input_locked or world.completed
	if next_lock and not locked:
		drawing=false;stroke.clear_points()
		if is_instance_valid(grabbed):_finish_drag(false)
	locked=next_lock
	if is_instance_valid(grabbed) and not locked:grabbed.position=_mouse()+grab_offset
	for piece in pieces:
		if bool(piece.get("consumed_by_mural",false)):
			piece.body.freeze=true;piece.visual.hide();continue
		_update_surface_art(piece)
		if bool(piece.source.sprite.get_meta("paper_bridge_only",false)):
			for layer:MeshInstance3D in [piece.visual,piece.border,piece.shadow]:
				layer.set_meta("paper_protect_player",bool(piece.sticker))
				if piece.sticker:layer.set_meta("bridge_draw_priority",125 if layer==piece.visual else (124 if layer==piece.border else 123))
				else:layer.remove_meta("bridge_draw_priority")
		var border_tint:=Color("36d65a") if piece.sticker and bool(piece.get("bridge_ready",false)) else Color.WHITE
		if piece.border.material_override is ShaderMaterial:
			piece.border.material_override.set_shader_parameter("border_tint",border_tint)
		elif piece.border.material_override is StandardMaterial3D:
			piece.border.material_override.albedo_color=border_tint
		_grounded_piece_layer(piece)
		if piece.sticker:
			piece.visual.set_meta("paper_foreground",false)
			piece.paper_material.no_depth_test=false
			piece.paper_material.render_priority=0
		elif bool(piece.source.sprite.get_meta("paper_foreground",false)):
			piece.visual.set_meta("paper_foreground",true)
			piece.paper_material.no_depth_test=true
			piece.paper_material.render_priority=maxi(120,piece.source.sprite.material_override.render_priority)
		_update_loose_foreground(piece)
		var body:RigidBody2D=piece.body
		if bool(piece.source.sprite.get_meta("equipped",false)):
			body.freeze=true;piece.visual.hide();continue
		piece.visual.show()
		if piece.has("bridge_opacity"):
			var opacity:float=piece.bridge_opacity
			piece.paper_material.albedo_color.a=opacity
			piece.visual.visible=opacity>0.0
			for ink:Material in [piece.border_material,piece.shadow_material]:
				if ink is ShaderMaterial:ink.set_shader_parameter("opacity",opacity)
				elif ink is StandardMaterial3D:ink.albedo_color.a=opacity
		# Loose paper and marked props use the same per-row depth pass as terrain.
		# A whole-image band can otherwise paint over a map from an earlier band.
		var map_clipped:bool=bool(piece.sticker) or not bool(piece.attached) or bool(piece.source.sprite.get_meta("map_occluded",false))
		piece.visual.set_meta("slice_whole",not map_clipped)
		piece.visual.set_meta("wall_layer_attached",bool(piece.sticker))
		for layer:MeshInstance3D in [piece.shadow,piece.border]:
			layer.set_meta("slice_whole",not map_clipped)
			layer.set_meta("wall_layer_attached",bool(piece.sticker))
			if bool(piece.source.sprite.get_meta("paper_alpha_border",false)):
				layer.material_override.set_shader_parameter("sliced",map_clipped)
		if piece.sticker:piece.visual.layers=1
		if piece.sticker:
			body.freeze=true
			if is_instance_valid(piece.host):
				piece.visual.global_transform=piece.host.global_transform*piece.host_pose
				continue
			# A removed support releases the paper at its last visible screen position.
			piece.sticker=false;body.position=_screen(camera.unproject_position(piece.visual.global_position))
			body.collision_layer=int(piece.source.layer);body.collision_mask=int(piece.source.layer)
		if piece.attached:
			var sprite:Sprite3D=piece.source.sprite
			piece.source.depth=float(sprite.get_meta("background_depth",55.0))
			body.position=_screen(camera.unproject_position(sprite.global_position))
			body.rotation=-(camera.global_basis.inverse()*sprite.global_basis).get_euler().z
		else:body.freeze=locked or body==grabbed
		var viewport_size:=get_viewport().get_visible_rect().size
		var height:=camera.size
		var point:Vector2=body.position
		piece.visual.global_position=camera.global_position-camera.global_basis.z*(float(piece.source.depth)-.1)+camera.global_basis.x*((point.x-viewport_size.x*500.0/viewport_size.y)*height/1000.0)+camera.global_basis.y*((500-point.y)*height/1000.0)
		piece.visual.global_basis=camera.global_basis*Basis(Vector3.BACK,-body.rotation)
		piece.visual.scale=Vector3.ONE*(height/1000.0)
	if drawing:
		line_end=_mouse();var ratio:=get_viewport().get_visible_rect().size.y/1000.0
		stroke.points=PackedVector2Array([line_start*ratio,line_end*ratio])
	if is_instance_valid(grabbed) and not locked:
		surface_preview=_preview_surface(grabbed_piece)
		if not surface_preview.is_empty():
			grabbed_piece.visual.global_transform=surface_preview.pose
			grabbed_piece.visual.set_meta("slice_whole",false)
			grabbed_piece.visual.set_meta("wall_layer_attached",true)
			for layer:MeshInstance3D in [grabbed_piece.shadow,grabbed_piece.border]:
				layer.set_meta("slice_whole",false)
				layer.set_meta("wall_layer_attached",true)
			grabbed_piece.visual.layers=1
func _local_at(piece:Dictionary,point:Vector2) -> Dictionary:
	# Picking uses the ACTUAL 3D plane, including a moving cube's transform.
	var pixel:=point*get_viewport().get_visible_rect().size.y/1000.0
	var origin:=camera.project_ray_origin(pixel)
	var direction:=camera.project_ray_normal(pixel)
	var pose:Transform3D=piece.visual.global_transform
	var normal:=pose.basis.z.normalized()
	var denominator:=direction.dot(normal)
	if absf(denominator)<.00001:return {}
	var distance:float=(pose.origin-origin).dot(normal)/denominator
	if distance<0:return {}
	var contact:=origin+direction*distance
	var local3:Vector3=pose.affine_inverse()*contact
	return {"local":Vector2(local3.x,-local3.y),"distance":distance,"world":contact,"origin":origin}
func _pick(point:Vector2) -> Dictionary:
	var best:Dictionary={};var nearest:=INF;var best_band:int=-1
	var pointer_band:int=clampi(int(floor(point.y/1000.0*12)),0,11)
	for piece in pieces:
		if bool(piece.get("permanent",false)):continue
		var projected:=_local_at(piece,point)
		if projected.is_empty():continue
		var band:int=pointer_band if piece.sticker else int(piece.visual.get_meta("resolved_screen_band",pointer_band))
		if bool(piece.visual.get_meta("paper_foreground",false)):band=12
		if band<best_band or (band==best_band and float(projected.distance)>=nearest):continue
		var local:Vector2=projected.local
		if not Geometry2D.is_point_in_polygon(local,piece.polygon):continue
		if piece.attached and not bool(piece.get("mounted_art",false)):
			var pixel:Vector2=local/float(piece.source.scale)+Vector2(piece.source.image.get_size())*.5
			var image:Image=piece.source.image
			if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height():continue
			if image.get_pixel(int(pixel.x),int(pixel.y)).a<=.12:continue
		if not piece.source.sprite.has_meta("paper_story_layer") and not bool(piece.source.sprite.get_meta("paper_foreground",false)) and (piece.sticker or band<=pointer_band):
			# A lower screen band's map is composited above this entire picture,
			# even if the picture's physical foreground plane is nearer the camera.
			var ray_end:Vector3=projected.world
			if band<pointer_band:
				var pixel_point:Vector2=point*get_viewport().get_visible_rect().size.y/1000.0
				ray_end=projected.origin+camera.project_ray_normal(pixel_point)*camera.far
			var ray:=PhysicsRayQueryParameters3D.create(projected.origin,ray_end,5)
			ray.exclude=[world.player.get_rid()]
			var obstacle:=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstacle.is_empty() and (band<pointer_band or obstacle.position.distance_to(projected.world)>.025):continue
		best=piece;nearest=float(projected.distance);best_band=band
	return best

func _pick_near_loose(point:Vector2) -> Dictionary:
	# Optional source-specific grab padding, without expanding physics or cuts.
	# Exact visible hits always win; hidden pieces cannot be picked through terrain.
	var best:Dictionary={};var nearest:=INF
	for piece:Dictionary in pieces:
		if piece.attached or piece.sticker or bool(piece.get("permanent",false)):continue
		var margin:float=float(piece.source.sprite.get_meta("paper_grab_margin",0.0))
		if margin<=0:continue
		var outline:=PackedVector2Array()
		for vertex:Vector2 in piece.polygon:
			var position:Vector3=piece.visual.global_transform*Vector3(vertex.x,-vertex.y,0)
			outline.append(_screen(camera.unproject_position(position)))
		for i:int in range(outline.size()):
			var edge:=Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])
			var distance:=point.distance_to(edge)
			if distance>margin or distance>=nearest:continue
			# Probe just inside the polygon boundary with the existing occlusion rules.
			var inward:Vector2=outline[(i+1)%outline.size()]-outline[i]
			inward=inward.orthogonal().normalized()*.35
			for side:float in [-1.0,1.0]:
				var hit:=_pick(edge+inward*side)
				if not hit.is_empty() and hit.body==piece.body:
					best=piece;nearest=distance;break
	return best
func _begin_drag(piece:Dictionary) -> void:
	if bool(piece.get("permanent",false)):return
	var picked:=_local_at(piece,_mouse())
	if picked.is_empty():return
	BgmPlayer.play_drag()
	grabbed_piece=piece;grabbed=piece.body;grab_local=picked.local
	for visual:MeshInstance3D in [piece.visual,piece.border,piece.shadow]:visual.set_meta("paper_drag_front",true)
	var was_attached:bool=piece.attached
	piece.attached=false
	stand_perpendicular=bool(piece.get("perpendicular",false))
	prior_sticker={"attached":was_attached}
	if piece.sticker:
		prior_sticker={"host":piece.host,"host_pose":piece.host_pose,"perpendicular":piece.get("perpendicular",false)}
		# Regrabbing returns to the original cut-paper size in the screen plane.
		var pose:Transform3D=piece.visual.global_transform
		var x_axis:=camera.unproject_position(pose.origin+pose.basis.x.normalized())-camera.unproject_position(pose.origin)
		grabbed.rotation=x_axis.angle()
	piece.sticker=false
	_update_surface_art(piece)
	grabbed.collision_layer=0;grabbed.collision_mask=0
	grab_offset=-grab_local.rotated(grabbed.rotation)
	grabbed.position=_mouse()+grab_offset
	grabbed.freeze=true;grabbed.linear_velocity=Vector2.ZERO;grabbed.angular_velocity=0
	surface_preview={}
func _finish_drag(commit:bool) -> void:
	if not is_instance_valid(grabbed):return
	for visual:MeshInstance3D in [grabbed_piece.visual,grabbed_piece.border,grabbed_piece.shadow]:visual.set_meta("paper_drag_front",false)
	if commit:
		grabbed.position=_mouse()+grab_offset
		# Resolve the current release ray, rather than a stale prior-frame preview.
		surface_preview=_preview_surface(grabbed_piece)
		if not surface_preview.is_empty():
			grabbed_piece.sticker=true;grabbed_piece.host=surface_preview.host
			grabbed_piece.perpendicular=stand_perpendicular
			grabbed_piece.host_pose=surface_preview.host.global_transform.affine_inverse()*surface_preview.pose
			grabbed_piece.visual.global_transform=surface_preview.pose
	elif prior_sticker.has("host") and is_instance_valid(prior_sticker.host):
		grabbed_piece.sticker=true;grabbed_piece.host=prior_sticker.host;grabbed_piece.host_pose=prior_sticker.host_pose
		grabbed_piece.perpendicular=prior_sticker.perpendicular
		grabbed_piece.visual.global_transform=prior_sticker.host.global_transform*prior_sticker.host_pose
	if not grabbed_piece.sticker:
		# A drag may cross below its own floor while frozen. Release on, never
		# inside/below, that physical support before resuming the simulation.
		var bottom:float=-INF
		for point:Vector2 in grabbed_piece.polygon:bottom=maxf(bottom,(grabbed.transform*point).y)
		if bottom>float(grabbed_piece.source.baseline):grabbed.position.y-=bottom-float(grabbed_piece.source.baseline)
	if not commit and bool(prior_sticker.get("attached",false)):
		grabbed_piece.attached=true
	var fixed:bool=bool(grabbed_piece.sticker) or bool(grabbed_piece.attached)
	grabbed.freeze=fixed
	grabbed.collision_layer=0 if fixed else int(grabbed_piece.source.layer)
	grabbed.collision_mask=0 if fixed else int(grabbed_piece.source.layer)
	var released:Dictionary=grabbed_piece
	_update_surface_art(released)
	grabbed=null;grabbed_piece={};prior_sticker={};surface_preview={}
	if commit:
		BgmPlayer.play_drop()
		piece_dropped.emit(released,_mouse())
func _preview_surface(piece:Dictionary) -> Dictionary:
	if bool(piece.source.sprite.get_meta("paper_bridge_only",false)):return {}
	# Rice stays draggable in the screen plane instead of sticking behind a wall.
	if bool(piece.source.sprite.get_meta("paper_loose_foreground",false)):return {}
	var pixel:=_mouse()*get_viewport().get_visible_rect().size.y/1000.0
	var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*camera.far,int(piece.source.sprite.get_meta("paper_target_mask",5)))
	query.exclude=[world.player.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is CollisionObject3D:return {}
	var normal:Vector3=hit.normal.normalized()
	var wall_only:bool=bool(piece.source.sprite.get_meta("paper_wall_only",false))
	if wall_only and absf(normal.y)>.2:return {}
	if wall_only:stand_perpendicular=false
	var right:Vector3=camera.global_basis.x-normal*camera.global_basis.x.dot(normal)
	if right.length_squared()<.001:right=camera.global_basis.y.cross(normal)
	right=right.normalized()
	var up:=normal.cross(right).normalized()
	var orientation:=Basis(right,up,normal)*Basis(Vector3.BACK,0.0 if wall_only else -grabbed.rotation)
	# Preserve the original paper size, even when it overhangs the host face.
	# The hinge is the target-face horizontal axis THROUGH the grabbed contact;
	# thus "upright" is relative to this face, including walls, not world Y.
	if stand_perpendicular:orientation=Basis(right,PI*.5)*orientation
	var basis:=orientation.scaled(Vector3.ONE*(camera.size/1000.0))
	var position:Vector3=hit.position+normal*SURFACE_OFFSET-basis*Vector3(grab_local.x,-grab_local.y,0)
	if stand_perpendicular:
		# Raise only along the face normal so the paper stands on its lowest
		# edge instead of burying half inside the solid. Lateral grab alignment
		# is unchanged; no resizing or restriction against face overhang.
		var lowest:=INF
		for point:Vector2 in piece.polygon:
			lowest=minf(lowest,(position+basis*Vector3(point.x,-point.y,0)-hit.position).dot(normal))
		position+=normal*maxf(0.0,SURFACE_OFFSET-lowest)
	var surface_filter:Callable=piece.source.sprite.get_meta("paper_surface_filter",Callable())
	if surface_filter.is_valid() and not surface_filter.call(hit,Transform3D(basis,position),piece.polygon):return {}
	return {"pose":Transform3D(basis,position),"host":hit.collider}
func cutting_enabled() -> bool:
	return is_instance_valid(world) and bool(world.stage_root.get_meta("paper_cutting_enabled",true))

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position=event.position;pointer_observed=true
	if not cutting_enabled() or locked or bool(world.get("paused")) or world.transition.active or world.player.input_locked or world.completed:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed and is_instance_valid(grabbed):
			var target:=_preview_surface(grabbed_piece)
			if not target.is_empty():
				stand_perpendicular=not stand_perpendicular
				surface_preview=_preview_surface(grabbed_piece)
				grabbed_piece.visual.global_transform=surface_preview.pose
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit:=_pick(_mouse())
			if hit.is_empty() and not event.shift_pressed:hit=_pick_near_loose(_mouse())
			if not hit.is_empty() and (not hit.attached or bool(hit.source.sprite.get_meta("paper_movable",false))) and not event.shift_pressed:
				_begin_drag(hit);get_viewport().set_input_as_handled()
			else:drawing=true;line_start=_mouse();line_end=line_start
		else:
			if is_instance_valid(grabbed):_finish_drag(true)
			elif drawing:
				drawing=false;stroke.clear_points();_cut(line_start,_mouse())
# Check the visible PNG, not transparent holes inside a simplified cut mesh.
func _stroke_hits_ink(source:Dictionary,a:Vector2,b:Vector2) -> bool:
	var image:Image=source.image
	var steps:int=maxi(1,ceili(a.distance_to(b)/float(source.scale)))
	for step:int in range(steps+1):
		var pixel:Vector2=a.lerp(b,float(step)/steps)/float(source.scale)+Vector2(image.get_size())*.5
		if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height():continue
		if image.get_pixel(int(pixel.x),int(pixel.y)).a>.12:return true
	return false

func _cut(start:Vector2,end:Vector2) -> void:
	if not cutting_enabled():return
	if start.distance_to(end)<8 or pieces.size()>=max_fragments:return
	var changed:Array[Sprite3D]=[]
	for piece in pieces.duplicate():
		var results:=_cut_results(piece,start,end)
		if results.is_empty():continue
		var inverse:Transform2D=piece.body.transform.affine_inverse()
		var a:Vector2=inverse*start;var b:Vector2=inverse*end
		var source:Dictionary=piece.source;var pose:Transform2D=piece.body.transform
		for result in results:
			var attached:bool=piece.attached and Geometry2D.is_point_in_polygon(source.stem,result)
			var cut_pose:Transform2D=pose if attached else _cut_base_pose(result,pose,a,b)
			if not attached:
				var bottom:float=-INF
				for point:Vector2 in result:bottom=maxf(bottom,(cut_pose*point).y)
				cut_pose.origin.y-=maxf(0.0,bottom-float(source.baseline))
			_add_piece(source,result,cut_pose,attached)
		piece.body.queue_free();piece.visual.queue_free();pieces.erase(piece)
		if not changed.has(source.sprite):changed.append(source.sprite)
	if not changed.is_empty():BgmPlayer.play_cut()
	for sprite:Sprite3D in changed:source_cut.emit(sprite)

func _cut_results(piece:Dictionary,start:Vector2,end:Vector2) -> Array[PackedVector2Array]:
	if start.distance_to(end)<8 or pieces.size()>=max_fragments:return []
	if not bool(piece.source.sprite.get_meta("paper_cuttable",true)):return []
	if not bool(piece.source.sprite.get_meta("cuttable",true)):return []
	# Pull a sticker off its face before recutting in the camera plane.
	if piece.sticker:return []
	var inverse:Transform2D=piece.body.transform.affine_inverse()
	var a:Vector2=inverse*start;var b:Vector2=inverse*end
	var polygon:PackedVector2Array=piece.polygon
	var crossings:=0
	for i in polygon.size():
		if Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])!=null:crossings+=1
	if bool(piece.source.sprite.get_meta("paper_extend_cut",false)):
		if not _stroke_hits_ink(piece.source,a,b):return []
	elif crossings<2:return []
	var direction:Vector2=(b-a).normalized();var normal:=direction.orthogonal();var reach:=10000.0
	var results:Array[PackedVector2Array]=[]
	for side:float in [-1.0,1.0]:
		var half:=PackedVector2Array([a-direction*reach,a+direction*reach,a+direction*reach+normal*reach*side,a-direction*reach+normal*reach*side])
		for clipped:PackedVector2Array in Geometry2D.intersect_polygons(polygon,half):results.append(clipped)
	if results.size()<2 or pieces.size()+results.size()-1>max_fragments:return []
	# Detailed ink outlines may produce tiny disconnected flecks along the
	# cut. Keep the substantial pieces instead of rejecting the entire cut.
	var minimum:float=float(piece.source.sprite.get_meta("paper_minimum_piece_area",minimum_piece_area))
	results=results.filter(func(result):return _area(result)>=minimum)
	if results.size()<2:return []
	for result:PackedVector2Array in results:
		if Geometry2D.triangulate_polygon(result).is_empty():return []
	return results

static func _cut_base_pose(polygon:PackedVector2Array,pose:Transform2D,a:Vector2,b:Vector2) -> Transform2D:
	# Align the fresh edge horizontally, then choose the half-turn that puts
	# this fragment ABOVE it in the screen's downward-positive Y coordinates.
	var center:=Vector2.ZERO
	for point:Vector2 in polygon:center+=point
	center/=float(polygon.size())
	var angle:float=-(b-a).angle()
	if (center-a).rotated(angle).y>0.0:angle+=PI
	# Rotate about the piece, not the original full image's distant origin.
	return Transform2D(angle,pose*center-center.rotated(angle))
