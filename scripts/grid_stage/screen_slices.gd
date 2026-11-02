extends Node
# Twelve genuine screen-band render passes of ONE shared physics/world scene.
# Map surfaces are clipped per fragment; whole illustrations belong to a band
# and may overlap other bands. Later (lower) bands are composited on top.
const BAND_COUNT:int=12
const ART_BIT_START:int=8
const COMMON_GEOMETRY:int=1
const PLAYER_MASK_LAYER:int=1<<20
const WOOD_WAVE_MASK_LAYER:int=1<<22
const PAPER_DRAG_LAYER:int=1<<23
var paper_drag_view:SubViewport
var paper_drag_panel:TextureRect
var player_mask:SubViewport
var wave_mask:SubViewport
# Render at native resolution; do not upscale a pixelated half-size image.
const RENDER_SCALE:float=1.0
var camera_state:Array=[]
var camera:Camera3D
var layered_waves:bool=false
var stage:Node3D
var panels:Array[TextureRect]=[]
var views:Array[SubViewport]=[]
var cameras:Array[Camera3D]=[]
var records:Array[Dictionary]=[]
var registered:Dictionary={}
var canvas:CanvasLayer
var miniature:ColorRect
var miniature_focus:=.52
func configure(view:Camera3D,stage_root:Node3D) -> void:
	# Apply final slice materials after late-created Stage1 cutters update theirs.
	process_priority=100
	camera=view;stage=stage_root
	layered_waves=int(camera.get_parent().stage_number)==5
	canvas=CanvasLayer.new();canvas.layer=1;add_child(canvas)
	for band:int in range(BAND_COUNT):
		var viewport:=SubViewport.new();viewport.name="HorizontalSlice%d"%band
		viewport.world_3d=stage.get_world_3d();viewport.world_2d=World2D.new();viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d=Viewport.MSAA_DISABLED
		add_child(viewport);views.append(viewport)
		var pass_camera:=Camera3D.new();viewport.add_child(pass_camera)
		pass_camera.cull_mask=COMMON_GEOMETRY|(1<<(ART_BIT_START+band));pass_camera.current=true
		# A camera-local clear environment prevents the shared opaque pond color
		# from being composited twelve times. Native main viewport draws it once.
		var environment:=Environment.new()
		environment.background_mode=Environment.BG_CLEAR_COLOR
		environment.background_color=Color(0,0,0,0)
		environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
		environment.fog_enabled=false
		pass_camera.environment=environment;cameras.append(pass_camera)
		var panel:=TextureRect.new();panel.name="CompositeBand%d"%band
		panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		panel.texture=viewport.get_texture();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;panel.stretch_mode=TextureRect.STRETCH_SCALE
		canvas.add_child(panel);panels.append(panel)
	# Run after all world bands, before the HUD on layer 2.
	miniature=ColorRect.new();miniature.name="MiniatureLens"
	miniature.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lens:=ShaderMaterial.new();lens.shader=preload("res://shaders/grid_miniature.gdshader")
	miniature.material=lens;canvas.add_child(miniature)
	# A live silhouette lets waves avoid the player across all composite bands.
	player_mask=SubViewport.new();player_mask.name="PlayerWaveProtection"
	player_mask.world_3d=stage.get_world_3d();player_mask.transparent_bg=true
	player_mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(player_mask);views.append(player_mask)
	var mask_camera:=Camera3D.new();player_mask.add_child(mask_camera)
	mask_camera.cull_mask=PLAYER_MASK_LAYER;mask_camera.current=true
	mask_camera.environment=cameras[0].environment
	cameras.append(mask_camera)
	wave_mask=player_mask
	if camera.get_parent().stage_number==4:
		# Wood samples the player mask, so keep its wave mask separate to avoid feedback.
		wave_mask=SubViewport.new();wave_mask.name="Stage1WoodWaveProtection"
		wave_mask.world_3d=stage.get_world_3d();wave_mask.transparent_bg=true
		wave_mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(wave_mask);views.append(wave_mask)
		var wave_camera:=Camera3D.new();wave_mask.add_child(wave_camera)
		wave_camera.cull_mask=PLAYER_MASK_LAYER|WOOD_WAVE_MASK_LAYER;wave_camera.current=true
		wave_camera.environment=cameras[0].environment;cameras.append(wave_camera)
	camera.cull_mask=0 # Still the logical camera for picking, projection, and gameplay.
	_sync_cameras()
	_register_tree(stage)
	get_tree().node_added.connect(_on_node_added)
func _ensure_paper_drag_view() -> void:
	if is_instance_valid(paper_drag_view):return
	paper_drag_view=SubViewport.new();paper_drag_view.name="DraggedPaperView"
	paper_drag_view.world_3d=stage.get_world_3d();paper_drag_view.transparent_bg=true
	paper_drag_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(paper_drag_view);views.append(paper_drag_view)
	var drag_camera:=Camera3D.new();paper_drag_view.add_child(drag_camera)
	drag_camera.cull_mask=PAPER_DRAG_LAYER;drag_camera.current=true
	drag_camera.environment=cameras[0].environment;cameras.append(drag_camera)
	var drag_canvas:=CanvasLayer.new();drag_canvas.layer=12;add_child(drag_canvas)
	paper_drag_panel=TextureRect.new();paper_drag_panel.texture=paper_drag_view.get_texture()
	paper_drag_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	paper_drag_panel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	paper_drag_panel.stretch_mode=TextureRect.STRETCH_SCALE
	drag_canvas.add_child(paper_drag_panel)
	camera_state=[];_sync_cameras()

func _on_node_added(node:Node) -> void:
	if stage.is_ancestor_of(node) and not is_ancestor_of(node):call_deferred("_register_id",node.get_instance_id())
func _register_id(id:int) -> void:
	var node=instance_from_id(id)
	if is_instance_valid(node):_register(node)
func _register_tree(node:Node) -> void:
	if node==self:return
	_register(node)
	for child:Node in node.get_children():_register_tree(child)
func _register(node:Node) -> void:
	if not is_instance_valid(node) or not node is GeometryInstance3D:return
	if node.get_viewport()!=stage.get_viewport():return # Cinematic worlds render themselves.
	# An inserted story scene owns a different World3D and renders in its own viewport.
	if node.get_world_3d()!=stage.get_world_3d():return
	if registered.has(node.get_instance_id()):return
	registered[node.get_instance_id()]=true
	var original:Material=node.material_override
	if original is ShaderMaterial and original.shader!=null:
		if original.shader.resource_path.get_file() in ["grid_pond_wave.gdshader","grid_shore_wave.gdshader","grid_earth_inlet.gdshader"]:
			if not layered_waves:original.set_shader_parameter("player_silhouette",wave_mask.get_texture())
			original.set_shader_parameter("protect_player",not layered_waves)
	var clipped:ShaderMaterial=null
	if original is StandardMaterial3D:
		clipped=ShaderMaterial.new()
		clipped.render_priority=original.render_priority
		clipped.shader=preload("res://shaders/grid_slice_alpha.gdshader") if original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED else preload("res://shaders/grid_slice_opaque.gdshader")
		records.append({"visual":node,"original":original,"clipped":clipped})
	else:records.append({"visual":node,"original":original,"clipped":null})
func _whole_band(visual:GeometryInstance3D) -> int:
	if visual.has_meta("story_layer"):return int(visual.get_meta("story_layer"))
	if visual.has_meta("cut_paper_owner"):
		var owner_visual=instance_from_id(int(visual.get_meta("cut_paper_owner")))
		if is_instance_valid(owner_visual):return _whole_band(owner_visual)
	if visual.has_meta("screen_band"):return clampi(int(visual.get_meta("screen_band")),0,BAND_COUNT-1)
	var y:float=camera.unproject_position(visual.global_position).y
	if visual is SpriteBase3D and visual.name=="IllustratedTraveler":
		y=camera.unproject_position(visual.get_parent().global_position).y
	elif visual is MeshInstance3D:
		# Whole paper is ordered by its lower edge, not its stale 2D body origin.
		var bounds:AABB=visual.get_aabb()
		for corner:int in range(8):
			y=maxf(y,camera.unproject_position(visual.global_transform*bounds.get_endpoint(corner)).y)
	var height:float=maxf(get_viewport().get_visible_rect().size.y,1)
	return clampi(int(floor(y/height*BAND_COUNT)),0,BAND_COUNT-1)
func _slice_layers(visual:GeometryInstance3D,record:Dictionary) -> int:
	# Only bound shaders whose vertices stay inside the mesh AABB. Billboards,
	# story actors and deforming waves retain the common-layer fallback.
	if not visual is MeshInstance3D or camera.projection!=Camera3D.PROJECTION_ORTHOGONAL:return COMMON_GEOMETRY
	var original:Material=record.original
	if original is StandardMaterial3D:
		if original.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or original.grow:return COMMON_GEOMETRY
	elif original is ShaderMaterial and original.shader!=null:
		if original.shader.resource_path.get_file() not in ["grid_paper_surface.gdshader","grid_paper_trim.gdshader"]:return COMMON_GEOMETRY
	else:return COMMON_GEOMETRY
	var bounds:AABB=visual.get_aabb()
	var state:Array=[visual.global_transform,bounds,camera_state]
	if record.get("slice_state",[])==state:return int(record.slice_layers)
	var first_y:=INF;var last_y:=-INF
	for corner:int in range(8):
		var point:Vector3=visual.global_transform*bounds.get_endpoint(corner)
		if camera.is_position_behind(point):return COMMON_GEOMETRY
		var y:float=camera.unproject_position(point).y
		first_y=minf(first_y,y);last_y=maxf(last_y,y)
	var height:float=maxf(get_viewport().get_visible_rect().size.y,1)
	# Include the shader's one-pixel overlap and an extra rounding guard.
	var first:int=clampi(floori((first_y-2.0)/height*BAND_COUNT),0,BAND_COUNT-1)
	var last:int=clampi(floori((last_y+2.0)/height*BAND_COUNT),0,BAND_COUNT-1)
	var mask:int=0
	for band:int in range(first,last+1):mask|=1<<(ART_BIT_START+band)
	record["slice_state"]=state;record["slice_layers"]=mask
	return mask
func _sync_cameras() -> void:
	var frame:Vector2=get_viewport().get_visible_rect().size
	var state:Array=[frame,camera.global_transform,camera.projection,camera.size,camera.fov,camera.near,camera.far,camera.keep_aspect,camera.h_offset,camera.v_offset]
	if state==camera_state:return
	camera_state=state
	var dimensions:=Vector2i(maxi(1,int(round(frame.x*RENDER_SCALE))),maxi(1,int(round(frame.y*RENDER_SCALE))))
	miniature.size=frame
	if is_instance_valid(paper_drag_panel):paper_drag_panel.size=frame
	for band:int in range(cameras.size()):
		if views[band].size!=dimensions:views[band].size=dimensions
		if band<panels.size():panels[band].size=frame
		var pass_camera:Camera3D=cameras[band]
		pass_camera.global_transform=camera.global_transform
		pass_camera.projection=camera.projection;pass_camera.size=camera.size
		pass_camera.fov=camera.fov;pass_camera.near=camera.near;pass_camera.far=camera.far
		pass_camera.keep_aspect=camera.keep_aspect;pass_camera.h_offset=camera.h_offset;pass_camera.v_offset=camera.v_offset
func _process(_delta:float) -> void:
	if not is_instance_valid(camera):return
	_sync_cameras()
	var world:=camera.get_parent()
	if is_instance_valid(world.player) and not world.paused:
		var focus:Vector2=camera.unproject_position(world.player.global_position+Vector3.UP*.65)
		var target:=clampf(focus.y/maxf(1,get_viewport().get_visible_rect().size.y),.2,.8)
		miniature_focus=lerpf(miniature_focus,target,1.0-exp(-4.0*_delta))
		miniature.material.set_shader_parameter("focus_y",miniature_focus)
	for index:int in range(records.size()-1,-1,-1):
		var record:Dictionary=records[index]
		if not is_instance_valid(record.visual):records.remove_at(index);continue
		var visual:GeometryInstance3D=record.visual
		if bool(visual.get_meta("paper_drag_front",false)):
			_ensure_paper_drag_view()
			if not record.has("drag_ink"):
				var ink:Material=record.original.duplicate()
				if ink is StandardMaterial3D:ink.no_depth_test=true
				elif ink is ShaderMaterial:
					ink.set_shader_parameter("protect_player",false)
					ink.set_shader_parameter("sliced",false)
				record["drag_ink"]=ink
			visual.layers=PAPER_DRAG_LAYER;visual.material_override=record.drag_ink
			continue
		record.erase("drag_ink")
		var bridge_ink:Material=record.clipped if record.clipped!=null else record.original
		if bridge_ink!=null:
			if visual.has_meta("bridge_draw_priority"):
				if not record.has("before_bridge_priority"):record["before_bridge_priority"]=bridge_ink.render_priority
				bridge_ink.render_priority=int(visual.get_meta("bridge_draw_priority"))
			elif record.has("before_bridge_priority"):
				bridge_ink.render_priority=int(record.before_bridge_priority);record.erase("before_bridge_priority")
		var protect:bool=bool(visual.get_meta("paper_protect_player",false))
		if bool(record.get("paper_protect_player",false))!=protect:
			var paper_ink:Material=record.clipped if record.clipped!=null else record.original
			if paper_ink is ShaderMaterial:
				paper_ink.set_shader_parameter("protect_player",protect)
				if protect:paper_ink.set_shader_parameter("player_silhouette",player_mask.get_texture())
			record["paper_protect_player"]=protect
		if visual.has_meta("story_layer"):
			if visual is AnimatedSprite3D:
				var actor:AnimatedSprite3D=visual
				var ink:ShaderMaterial=record.get("story_ink")
				if ink==null:
					ink=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_stage6_actor.gdshader")
					ink.set_shader_parameter("billboard",true);ink.render_priority=126;record["story_ink"]=ink
				var frame:Texture2D=actor.sprite_frames.get_frame_texture(actor.animation,actor.frame)
				ink.set_shader_parameter("illustration",frame.atlas if frame is AtlasTexture else frame)
				actor.material_override=ink;actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
			visual.layers=1<<(ART_BIT_START+int(visual.get_meta("story_layer")))
			visual.set_meta("resolved_screen_band",visual.get_meta("story_layer"))
			continue
		if bool(visual.get_meta("completed_bridge_overlay",false)):
			var deck:ShaderMaterial=record.get("completed_bridge_ink")
			if deck==null:
				deck=ShaderMaterial.new();deck.shader=preload("res://shaders/grid_completed_bridge.gdshader")
				deck.render_priority=120
				deck.set_shader_parameter("player_silhouette",player_mask.get_texture())
				record["completed_bridge_ink"]=deck
			var source:StandardMaterial3D=record.original
			deck.set_shader_parameter("illustration",source.albedo_texture)
			deck.set_shader_parameter("opacity",source.albedo_color.a)
			visual.material_override=deck
			# Final map band, excluding the sampled player mask to avoid feedback.
			visual.layers=(1<<(ART_BIT_START+BAND_COUNT-1))|WOOD_WAVE_MASK_LAYER
			visual.set_meta("resolved_screen_band",BAND_COUNT-1)
			continue
		if bool(visual.get_meta("drag_front",false)):
			visual.layers=1<<21;visual.material_override=record.original;continue
		if visual.get_viewport()!=stage.get_viewport():
			visual.layers=1;visual.material_override=record.original;continue
		if bool(visual.get_meta("paper_foreground",false)):
			# Explicit foreground paper belongs to the last pass, ahead of all map bands.
			# Opt-in actors keep their own Y rotation and material draw order.
			if visual is AnimatedSprite3D and not bool(visual.get_meta("paper_foreground_original",false)):
				var actor:AnimatedSprite3D=visual
				var ink:ShaderMaterial=record.get("foreground_ink")
				if ink==null:
					ink=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
					ink.render_priority=126;ink.set_shader_parameter("billboard",true);record["foreground_ink"]=ink
				var texture:Texture2D=actor.sprite_frames.get_frame_texture(actor.animation,actor.frame)
				ink.set_shader_parameter("illustration",texture.atlas if texture is AtlasTexture else texture)
				actor.material_override=ink;actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
			else:
				visual.material_override=record.original
			visual.layers=(1<<(ART_BIT_START+BAND_COUNT-1))|PLAYER_MASK_LAYER
			visual.set_meta("resolved_screen_band",BAND_COUNT-1)
			continue
		if bool(visual.get_meta("story_actor",false)):
			visual.layers=COMMON_GEOMETRY|PLAYER_MASK_LAYER
			continue
		if visual is AnimatedSprite3D and visual.name=="IllustratedTraveler":
			# Render each character fragment beside the same band's architecture.
			# The final band alone has no depth from the upper map bands.
			var traveler:AnimatedSprite3D=visual
			if traveler.layers!=(COMMON_GEOMETRY|PLAYER_MASK_LAYER):traveler.layers=COMMON_GEOMETRY|PLAYER_MASK_LAYER
			var traveler_ink:ShaderMaterial=record.get("traveler_ink")
			if traveler_ink==null:
				traveler_ink=ShaderMaterial.new()
				traveler_ink.shader=preload("res://shaders/grid_traveler_slice.gdshader")
				traveler_ink.render_priority=126
				record["traveler_ink"]=traveler_ink
			var frame_texture:Texture2D=traveler.sprite_frames.get_frame_texture(traveler.animation,traveler.frame)
			# AnimatedSprite3D already supplies atlas-adjusted mesh UVs.
			traveler_ink.set_shader_parameter("frame_texture",frame_texture.atlas if frame_texture is AtlasTexture else frame_texture)
			var neck_length:float=traveler.get_meta("neck_length",0.0)
			traveler_ink.set_shader_parameter("neck_length",neck_length)
			if neck_length>0:
				var atlas:AtlasTexture=frame_texture as AtlasTexture
				if atlas!=null:
					var size_:Vector2=atlas.atlas.get_size()
					traveler_ink.set_shader_parameter("frame_region",Vector4(atlas.region.position.x/size_.x,atlas.region.position.y/size_.y,atlas.region.size.x/size_.x,atlas.region.size.y/size_.y))
					traveler_ink.set_shader_parameter("frame_size",atlas.region.size)
					traveler_ink.set_shader_parameter("head_seam",230.0 if atlas.region.size.y>600 else 140.0)
					traveler_ink.set_shader_parameter("head_bounds",Vector2(110,290) if atlas.region.size.y>600 else Vector2(65,325))
				traveler_ink.set_shader_parameter("neck_texture",load("res://art/minhwa/fan_story/long_neck_v1.png"))
				traveler.extra_cull_margin=neck_length
			traveler.material_override=traveler_ink
			if traveler.alpha_cut!=SpriteBase3D.ALPHA_CUT_DISABLED:traveler.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
			traveler.render_priority=126
			traveler.no_depth_test=false
			traveler.set_meta("resolved_screen_band",-1)
			continue
		if bool(visual.get_meta("pond_wave",false)) and record.original is ShaderMaterial:
			if record.original.render_priority!=-20:record.original.render_priority=-20
		if layered_waves and bool(visual.get_meta("pond_wave",false)) and not bool(visual.get_meta("wall_layer_attached",false)):
			# Background water precedes map and paper; wall waves retain depth testing.
			visual.layers=1<<ART_BIT_START
			visual.material_override=record.original
			visual.set_meta("resolved_screen_band",0)
			continue
		if bool(visual.get_meta("boundary_wave",false)) and not bool(visual.get_meta("wall_layer_attached",false)):
			# Final existing band draws the whole shore painting after background
			# water. Whole-map alpha mask still protects every architectural band.
			var shore_layers:int=1<<(ART_BIT_START+BAND_COUNT-1)
			if visual.layers!=shore_layers:visual.layers=shore_layers
			continue
		var whole:bool=(visual is SpriteBase3D or bool(visual.get_meta("slice_whole",false))) and not bool(visual.get_meta("wall_layer_attached",false))
		if whole:
			var band:int=_whole_band(visual)
			if int(visual.get_meta("resolved_screen_band",-2))!=band:visual.set_meta("resolved_screen_band",band)
			var wanted_layers:int=1<<(ART_BIT_START+band)
			if bool(visual.get_meta("wave_protected",false)):wanted_layers|=PLAYER_MASK_LAYER
			if bool(visual.get_meta("wood_wave_protected",false)):wanted_layers|=WOOD_WAVE_MASK_LAYER
			if visual.layers!=wanted_layers:visual.layers=wanted_layers
			if visual.material_override!=record.original:visual.material_override=record.original
		else:
			if int(visual.get_meta("resolved_screen_band",-2))!=-1:visual.set_meta("resolved_screen_band",-1)
			var slice_layers:int=_slice_layers(visual,record)
			if bool(visual.get_meta("wave_protected",false)):slice_layers|=PLAYER_MASK_LAYER
			if bool(visual.get_meta("wood_wave_protected",false)):slice_layers|=WOOD_WAVE_MASK_LAYER
			if visual.layers!=slice_layers:visual.layers=slice_layers
			if record.clipped!=null:
				# Keep original materials/resources live for fading footprints and
				# interaction color changes; only the render override is replaced.
				var ink:StandardMaterial3D=record.original
				var clipped:ShaderMaterial=record.clipped
				var ink_state:Array=[ink.albedo_color,ink.vertex_color_use_as_albedo,ink.albedo_texture]
				if record.get("ink_state",[])!=ink_state:
					record["ink_state"]=ink_state
					clipped.set_shader_parameter("ink_color",ink.albedo_color)
					clipped.set_shader_parameter("vertex_ink",ink.vertex_color_use_as_albedo)
					clipped.set_shader_parameter("textured",ink.albedo_texture!=null)
					clipped.set_shader_parameter("ink_texture",ink.albedo_texture)
				if visual.material_override!=clipped:visual.material_override=clipped
