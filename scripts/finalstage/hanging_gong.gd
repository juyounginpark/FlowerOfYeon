extends Node3D
signal delivered
signal cord_cut
## Stage4's cord and top-pinned paper cutting; only the cord is cuttable.
const DEPTH := 2.0
var world: GridStageWorld
var gong: Sprite3D
var rope: Sprite3D
var cutter: GridPaperCutting
var descending := false
var released := false
var clock := 0.0
var anchor := Vector2.ZERO
var drop_anchor := Vector2.ZERO
var height_fraction := .24
var transferring := false
var given := false
var transfer_clock := 0.0
var transfer_origin := Vector2.ZERO
var proxy: Sprite3D
var small_cutter: GridPaperCutting

func configure(owner_world: GridStageWorld,art: Texture2D,position: Vector2,drop: Vector2,height: float) -> void:
	world=owner_world
	anchor=position;drop_anchor=drop;height_fraction=height
	var texture := AtlasTexture.new()
	texture.atlas=art
	texture.region=texture.atlas.get_image().get_used_rect()
	gong=_sprite(texture,world.camera.size*height_fraction)
	gong.set_meta("cuttable",false)
	var cord_image := preload("res://art/minhwa/fan_story/cord_v2.png").get_image()
	var cord := ImageTexture.create_from_image(cord_image.get_region(cord_image.get_used_rect()))
	rope=_sprite(cord,1.0)
	rope.set_meta("paper_hanging",true)
	rope.set_meta("paper_minimum_piece_area",16.0)
	hide()

func _sprite(texture: Texture2D,height: float) -> Sprite3D:
	var sprite := Sprite3D.new();sprite.texture=texture
	if texture is AtlasTexture:sprite.texture=ImageTexture.create_from_image(texture.get_image())
	var ink := ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
	ink.render_priority=127
	ink.set_shader_parameter("illustration",sprite.texture)
	sprite.material_override=ink
	sprite.pixel_size=height/texture.get_height()
	sprite.shaded=false;sprite.double_sided=true
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("background_depth",DEPTH)
	sprite.set_meta("map_occluded",true)
	sprite.set_meta("paper_foreground",true)
	add_child(sprite);sprite.global_basis=world.camera.global_basis
	return sprite

func begin_descent() -> void:
	if descending:return
	descending=true;clock=0
	show();_layout()

func _layout() -> void:
	var frame := get_viewport().get_visible_rect().size
	var t := smoothstep(0,1,clampf(clock/2.0,0,1))
	var center := Vector2(anchor.x,lerpf(-.22,anchor.y,t))
	gong.global_position=world.camera.project_position(frame*center,DEPTH)
	var end := frame*(center-Vector2(0,height_fraction*.48))
	var top := Vector2(end.x,-frame.y*.05)
	var length := maxf(1.0,end.y-top.y)
	rope.pixel_size=length*world.camera.size/frame.y/rope.texture.get_height()
	rope.global_position=world.camera.project_position((top+end)*.5,DEPTH)
	rope.visible=end.y>top.y
	if clock>=2.0:_enable_cutting()

func _enable_cutting() -> void:
	cutter=GridPaperCutting.new();cutter.name="GongCordCutting"
	add_child(cutter);cutter.configure(world.camera,[rope,gong])
	_promote_paper(cutter)
	for source: Dictionary in cutter.sources:
		source.baseline=1080.0;source.floor.position.y=1092.0
	cutter._process(0)
	cutter.source_cut.connect(_on_cord_cut)

func _on_cord_cut(sprite: Sprite3D) -> void:
	if sprite!=rope or released:return
	_promote_paper(cutter)
	released=true
	for piece: Dictionary in cutter.pieces:
		if piece.source.sprite==gong:
			piece.attached=false;piece.body.freeze=false
			piece.body.collision_layer=int(piece.source.layer)
			piece.body.collision_mask=int(piece.source.layer)
		elif piece.attached:
			piece.body.freeze=true;piece.body.linear_velocity=Vector2.ZERO
			piece.body.angular_velocity=0
	# Stage4's proxy transfer: interpolate scale/position, then resume real gravity.
	transferring=true;transfer_clock=0
	cutter.set_process_unhandled_input(false)
	transfer_origin=cutter._screen(world.camera.unproject_position(gong.global_position))
	gong.set_meta("equipped",true)
	cutter._process(0)
	proxy=_sprite(gong.texture,gong.pixel_size*gong.texture.get_height())
	proxy.set_meta("cuttable",false)
	preload("res://scripts/grid_stage/sticker_sprite.gd").install(proxy,world.camera)
	_promote_visual(proxy,127)
	_advance_transfer(0)
	cord_cut.emit()

func _advance_transfer(delta: float) -> void:
	transfer_clock+=delta
	var t := clampf(transfer_clock/.7,0,1)
	var ease := smoothstep(0,1,t)
	var frame := get_viewport().get_visible_rect().size
	var destination := Vector2(drop_anchor.x*frame.x/frame.y,drop_anchor.y)*1000.0
	var point := transfer_origin.lerp(destination,ease)-Vector2(0,sin(t*PI)*35)
	proxy.pixel_size=gong.pixel_size*lerpf(1.0,.30,ease)
	var depth := lerpf(DEPTH,3.0,ease)
	proxy.global_position=world.camera.project_position(point*frame.y/1000.0,depth)
	proxy.set_meta("background_depth",depth)
	if t<1:return
	transferring=false
	cutter.hide_source(gong)
	cutter.set_process_unhandled_input(true)
	small_cutter=GridPaperCutting.new();small_cutter.name="CloudInstrument"
	add_child(small_cutter);small_cutter.configure(world.camera,[proxy])
	_promote_paper(small_cutter)
	for source: Dictionary in small_cutter.sources:
		source.baseline=880.0;source.floor.position.y=892.0
	for piece: Dictionary in small_cutter.pieces:
		piece.attached=false;piece.body.freeze=false
		piece.body.lock_rotation=true
		piece.body.linear_velocity=Vector2.ZERO;piece.body.angular_velocity=0
		piece.body.physics_material_override.bounce=0
		piece.body.physics_material_override.friction=1.0
		piece.body.collision_layer=int(piece.source.layer)
		piece.body.collision_mask=int(piece.source.layer)
	# New paper meshes start at unit scale; pose them before their first rendered frame.
	small_cutter._process(0)
	small_cutter.piece_dropped.connect(_on_piece_dropped)

func _promote_paper(paper: GridPaperCutting) -> void:
	for piece: Dictionary in paper.pieces:
		_promote_visual(piece.visual,127)

func _promote_visual(node: Node,priority: int) -> void:
	if node is GeometryInstance3D:
		node.set_meta("paper_foreground",true)
		var material: Material = node.material_override
		if material!=null:
			material.render_priority=priority
			if material is StandardMaterial3D:material.no_depth_test=true
	for child: Node in node.get_children():_promote_visual(child,maxi(125,priority-1))

func _on_piece_dropped(piece: Dictionary,point: Vector2) -> void:
	if given or piece.source.sprite!=proxy:return
	var frame := get_viewport().get_visible_rect().size
	var normalized := Vector2(point.x*frame.y/frame.x,point.y)/1000.0
	if not Rect2(.12,.68,.15,.30).has_point(normalized):return
	given=true
	small_cutter.hide_source(proxy)
	delivered.emit()

func _process(delta: float) -> void:
	if world.paused or world.transition.active:return
	if transferring:
		_advance_transfer(delta)
		return
	if not descending or cutter!=null:return
	clock+=delta
	_layout()
