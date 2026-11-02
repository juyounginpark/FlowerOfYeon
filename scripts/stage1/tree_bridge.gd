extends "res://scripts/grid_stage/stage6_crossings.gd"
# Stage1 shares assembly and the completed minhwa deck with Stages5/6.
var tree_art:Array[Sprite3D]=[]
var speech:Node3D
var cut_done:Array[bool]=[false,false]
var warned:=false
var start:=Vector3.ZERO
var crest:=Vector3.ZERO
var finish:=Vector3.ZERO
var installed:=false
var background_cutters:Array[GridPaperCutting]=[]
var regrowing:Dictionary={}
var tutorial:Node

func setup(owner_world:GridStageWorld,left:Sprite3D,right:Sprite3D,woman:Node3D) -> void:
	world=owner_world;camera=world.camera;speech=woman;tree_art=[left,right]
	# Stage-local gate resets on a new visit, but survives falls and dialogue.
	world.stage_root.set_meta("paper_cutting_enabled",false)
	var low:Array=world.stage_data.low[0];var high:Array=world.stage_data.raised[0]
	var x:float=(high[0].x+high[1].x)*StageCells.UNIT*.5
	start=Vector3(x,low[1].y*StageCells.UNIT,low[0].z*StageCells.UNIT+.5)
	crest=Vector3(x,high[1].y*StageCells.UNIT+.015,high[1].z*StageCells.UNIT+.4)
	finish=Vector3(x,crest.y,high[1].z*StageCells.UNIT-.4)
	routes=[[start,crest]]
	var overlay:=CanvasLayer.new();overlay.layer=3;add_child(overlay)
	hint=Label.new();hint.hide();hint.position=Vector2(30,76)
	hint.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	hint.add_theme_font_size_override("font_size",22)
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(hint)
	hint.text="나무를 잘라 투명 다리에 붙이세요. 55% 이상 덮으면 건널 수 있어요."
	for tree:Sprite3D in tree_art:
		var proxy:=Sprite3D.new();proxy.name=tree.name+"CutSource"
		proxy.texture=tree.texture;proxy.pixel_size=tree.pixel_size
		# A convex cutting hull avoids thousands of needle-sized physics shapes.
		# The original PNG and alpha border still supply the detailed silhouette.
		proxy.set_meta("paper_convex_outline",true)
		proxy.set_meta("paper_convex_collision",true)
		proxy.set_meta("paper_alpha_border",true)
		proxy.set_meta("paper_outline_fallback",true)
		proxy.set_meta("paper_minimum_piece_area",10.0)
		proxy.set_meta("paper_extend_cut",true)
		if tree==speech.rope_tree:
			# A short stroke through the painted trunk can split the broad canopy hull.
			proxy.set_meta("paper_extend_cut",true)
			proxy.set_meta("swing_cut_margin",14.0)
		proxy.set_meta("paper_standing_layer",11)
		var ink:=StandardMaterial3D.new()
		ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.albedo_texture=tree.texture;ink.no_depth_test=true;ink.render_priority=110
		proxy.material_override=ink;add_child(proxy)
		proxy.global_basis=camera.global_basis
		proxy.global_position=tree.global_position+camera.global_basis*Vector3(tree.offset.x,tree.offset.y,0)*tree.pixel_size
		proxy.set_meta("background_depth",(camera.global_position-proxy.global_position).dot(camera.global_basis.z))
		trees.append(proxy)
		# Retain the original swing anchor node; the cut paper supplies its artwork.
		tree.modulate.a=0
	paper=preload("res://scripts/stage1/tree_cutting.gd").new()
	paper.name="Stage1TreePaper";paper.puzzle=self;add_child(paper)
	paper.configure(camera,trees);paper.max_fragments=256
	tree_bridge=preload("res://scripts/grid_stage/stage5_tree_bridge.gd").new()
	add_child(tree_bridge);tree_bridge.configure(self)
	paper.source_cut.connect(_on_tree_cut);paper.piece_dropped.connect(_on_piece_dropped)
	bridge_previews.append(_create_bridge(0,true))
	bridge_previews[0].hide()
	_collect_background_cutters(world.stage_root)
	tutorial=preload("res://scripts/stage1/tree_tutorial.gd").new()
	add_child(tutorial);tutorial.configure(self)
	speech.first_player_interaction.connect(tutorial.start)

func _on_tree_cut(source:Sprite3D) -> void:
	var index:=trees.find(source)
	if index<0:return
	var swing_tree:bool=tree_art[index]==speech.rope_tree
	if not cut_done[index]:
		cut_done[index]=true;tree_art[index].hide()
		if swing_tree:speech.drop_to_platform()
	# Both trees remain cut until an explicit stage restart.
	tutorial.tree_cut(source)
	_cancel_background_strokes(world.stage_root)

func _on_piece_dropped(piece:Dictionary,point:Vector2) -> void:
	var index:=_bridge_candidate(piece,point)
	if index>=0:tree_bridge.mount(index,piece,point)

func _cancel_background_strokes(_node:Node) -> void:
	for cutter:GridPaperCutting in background_cutters:
		if is_instance_valid(cutter):cutter.drawing=false;cutter.stroke.clear_points()

func _collect_background_cutters(node:Node) -> void:
	if node is GridPaperCutting and node!=paper:
		background_cutters.append(node)
	for child:Node in node.get_children():_collect_background_cutters(child)

func _physics_process(delta:float) -> void:
	if world==null:return
	if world.paused or world.transition.active or world.player.input_locked or world.completed:
		bridge_previews[0].hide();return
	tree_bridge.tick(delta)
	_tick_regrowth(delta)
	installed=tree_bridge.ready_to_walk(0)
	if installed:tutorial.finish()
	# Completed artwork stays clear even when the player grabs another tree scrap.
	bridge_previews[0].visible=not installed and ((is_instance_valid(paper.grabbed) and not paper.locked) or tutorial.is_drag_step())

func regrow_source(sprite:Sprite3D) -> void:
	if regrowing.has(sprite):return
	var index:=trees.find(sprite)
	if index<0 or tree_art[index]==speech.rope_tree:return
	var stumps:Array[Dictionary]=[]
	for piece:Dictionary in paper.pieces:
		if piece.source.sprite==sprite and piece.attached:stumps.append(piece)
	for source:Dictionary in paper.sources:
		if source.sprite!=sprite:continue
		var pose:=Transform2D(0,paper._screen(camera.unproject_position(sprite.global_position)))
		paper._add_piece(source,source.polygon,pose,true)
		var fresh:Dictionary=paper.pieces.back()
		var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/stage1_growing_tree.gdshader")
		ink.render_priority=111;ink.set_shader_parameter("illustration",source.texture)
		ink.set_shader_parameter("root_point",Vector2(source.stem.x,-source.stem.y))
		fresh["regrow_material"]=ink;fresh["regrowing"]=true;fresh["permanent"]=true
		fresh.visual.material_override=ink;fresh.shadow.hide();fresh.border.hide()
		regrowing[sprite]={"piece":fresh,"stumps":stumps,"time":0.0}
		break

func _tick_regrowth(delta:float) -> void:
	for sprite:Sprite3D in regrowing.keys():
		var entry:Dictionary=regrowing[sprite]
		entry.time+=delta
		var t:=clampf(float(entry.time)/1.4,0,1)
		entry.piece.regrow_material.set_shader_parameter("growth",smoothstep(0,1,t))
		if t<1:continue
		for stump:Dictionary in entry.stumps:
			if paper.pieces.has(stump) and stump.attached:
				stump.body.queue_free();stump.visual.queue_free();paper.pieces.erase(stump)
		entry.piece.erase("regrow_material");entry.piece.erase("regrowing");entry.piece.erase("permanent")
		entry.piece.visual.material_override=sprite.material_override
		entry.piece.shadow.show();entry.piece.border.show()
		regrowing.erase(sprite)

func _create_bridge(index:int,preview:=false) -> Node3D:
	var crossing:=Node3D.new()
	crossing.name="TreeBridgePreview%d"%index if preview else "TreeBridge%d"%index
	add_child(crossing)
	var horizontal:=Vector3(crest.x-start.x,0,crest.z-start.z).normalized()
	for span:Array in [[start-horizontal*.35,start],[start,crest],[crest,finish]]:
		_bridge_span(crossing,span[0],span[1],preview)
	if not preview:preload("res://scripts/grid_stage/tree_bridge_collision.gd").join_spans(crossing)
	return crossing
