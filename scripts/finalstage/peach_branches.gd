extends Node3D
## Decorative branches; only the fully grown peach uses the common cutter.
const PLACEMENTS := [
	[preload("res://art/finalstage/peach_branch_tall.png"),Vector2(.045,.38),.74,0.0],
	[preload("res://art/finalstage/peach_branches_cutout_v2.png"),Vector2(.075,.70),.30,90.0],
]
const DEPTH := 20.0
var world: GridStageWorld
var sprites: Array[Sprite3D] = []
var branch_bounds: Array[Rect2] = []
var burned := [false,false]
const BURNED_ART := [preload("res://art/finalstage/peach_burned_upper.png"),preload("res://art/finalstage/peach_burned_lower.png")]
var peach: MeshInstance3D
var peach_ink: ShaderMaterial
var growth_frame := 0
var peach_source: Sprite3D
var peach_cutter: GridPaperCutting
var peach_given := false
var growth_fade := .45

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	for placement: Array in PLACEMENTS:
		var sprite := Sprite3D.new()
		sprite.texture=placement[0]
		sprite.pixel_size=world.camera.size*float(placement[2])/sprite.texture.get_height()
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink := ShaderMaterial.new();ink.shader=preload("res://shaders/grid_story_sprite.gdshader")
		ink.set_shader_parameter("illustration",sprite.texture);sprite.material_override=ink
		sprite.set_meta("story_actor",true)
		var image := sprite.texture.get_image()
		if image.is_compressed():image.decompress()
		var used := image.get_used_rect()
		branch_bounds.append(Rect2(Vector2(used.position)/Vector2(image.get_size()),Vector2(used.size)/Vector2(image.get_size())))
		add_child(sprite);sprites.append(sprite)
	_layout()
	peach=MeshInstance3D.new();peach.name="RemainingPeach"
	var quad := QuadMesh.new();quad.size=Vector2.ONE*world.camera.size*.16
	peach.mesh=quad
	peach_ink=ShaderMaterial.new();peach_ink.shader=preload("res://scripts/finalstage/peach_growth.gdshader")
	peach_ink.set_shader_parameter("illustration",preload("res://art/finalstage/peach_growth_8frames.png"))
	peach_ink.render_priority=115
	peach.material_override=peach_ink
	peach.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(peach);peach.hide()
	set_growth_frame(0)

func burn_branch(index: int) -> void:
	if burned[index]:return
	burned[index]=true
	var sprite := sprites[index]
	sprite.texture=BURNED_ART[index]
	sprite.pixel_size=world.camera.size*float(PLACEMENTS[index][2])/sprite.texture.get_height()
	sprite.material_override.set_shader_parameter("illustration",sprite.texture)
	if index==0:peach.show()

func branch_screen_rect(index: int) -> Rect2:
	var sprite := sprites[index]
	var rect := branch_bounds[index]
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for uv: Vector2 in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
		var point := (uv-Vector2(.5,.5))*Vector2(sprite.texture.get_size())*sprite.pixel_size
		var screen := world.camera.unproject_position(sprite.global_transform*Vector3(point.x,-point.y,0))
		low=low.min(screen);high=high.max(screen)
	return Rect2(low,high-low)

func set_growth_frame(index: int) -> void:
	# Progress survives phase retries and cannot undo a later instrument milestone.
	var next := maxi(growth_frame,clampi(index,0,7))
	if next==growth_frame:return
	peach_ink.set_shader_parameter("previous_uv",Vector4((growth_frame%4)*.25,floori(growth_frame/4.0)*.5,.25,.5))
	growth_frame=next;growth_fade=0
	peach_ink.set_shader_parameter("frame_blend",0.0)
	peach_ink.set_shader_parameter("frame_uv",Vector4((growth_frame%4)*.25,floori(growth_frame/4.0)*.5,.25,.5))

func _enable_peach_cutting() -> void:
	var sheet := preload("res://art/finalstage/peach_growth_8frames.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	var first := Vector2i(roundi(sheet.get_width()*.75),roundi(sheet.get_height()*.5))
	var image := sheet.get_region(Rect2i(first,sheet.get_size()-first))
	peach_source=Sprite3D.new();peach_source.texture=ImageTexture.create_from_image(image)
	peach_source.pixel_size=world.camera.size*.16/image.get_height()
	var ink := ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
	ink.render_priority=127;ink.set_shader_parameter("illustration",peach_source.texture)
	peach_source.material_override=ink
	peach_source.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	peach_source.set_meta("background_depth",2.0)
	peach_source.set_meta("paper_foreground",true)
	peach_source.set_meta("paper_hanging",true)
	peach_source.set_meta("paper_extend_cut",true)
	peach_source.set_meta("paper_minimum_piece_area",16.0)
	add_child(peach_source);_layout();peach.hide()
	peach_cutter=GridPaperCutting.new();peach_cutter.name="FinalPeachCutting"
	add_child(peach_cutter);peach_cutter.configure(world.camera,[peach_source])
	for source: Dictionary in peach_cutter.sources:
		source.baseline=700.0;source.floor.position.y=712.0
	_promote_peach();peach_cutter._process(0)
	peach_cutter.source_cut.connect(_on_peach_cut)
	peach_cutter.piece_dropped.connect(_on_peach_dropped)

func _promote_peach() -> void:
	for piece: Dictionary in peach_cutter.pieces:
		for visual: MeshInstance3D in [piece.visual,piece.shadow,piece.border]:
			visual.set_meta("paper_foreground",true)
			var ink: StandardMaterial3D = visual.material_override
			ink.no_depth_test=true
			ink.render_priority=127 if visual==piece.visual else 126 if visual==piece.border else 125

func _on_peach_cut(_sprite: Sprite3D) -> void:
	peach_source.set_meta("cuttable",false)
	_promote_peach()

func _on_peach_dropped(piece: Dictionary,point: Vector2) -> void:
	if peach_given or piece.source.sprite!=peach_source or piece.attached:return
	var screen := point*get_viewport().get_visible_rect().size.y/1000.0
	var accepted: bool = world.stage_root.get_node("Kkwangcheol").call("offer_peach",screen)
	if not accepted:return
	peach_given=true
	peach_cutter.hide_source(peach_source)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for index in range(sprites.size()):
		var placement: Array = PLACEMENTS[index]
		sprites[index].global_position=world.camera.project_position(viewport_size*Vector2(placement[1]),DEPTH)
		sprites[index].global_basis=world.camera.global_basis*Basis(Vector3.BACK,deg_to_rad(placement[3]))
	if is_instance_valid(peach):
		peach.global_position=world.camera.project_position(viewport_size*Vector2(.13,.25),DEPTH-.3)
		peach.global_basis=world.camera.global_basis
	if is_instance_valid(peach_source):
		peach_source.global_position=world.camera.project_position(viewport_size*Vector2(.13,.25),2.0)
		peach_source.global_basis=world.camera.global_basis

func _process(delta: float) -> void:
	_layout()
	if world.paused or world.transition.active:return
	growth_fade=minf(.45,growth_fade+delta)
	peach_ink.set_shader_parameter("frame_blend",smoothstep(0,1,growth_fade/.45))
	if growth_frame==7 and growth_fade>=.45 and peach_cutter==null:_enable_peach_cutting()
