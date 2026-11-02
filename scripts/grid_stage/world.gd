class_name GridStageWorld
extends Node3D
signal map_selection_requested
## Optional stage features attach after terrain, player and transitions are ready.
signal stage_loaded(number: int)
signal entry_prepared
var incremental_entry := false
enum LiftPhase { IDLE, RISING, HOLDING, WARNING, RETURNING }
@export_range(1,12) var stage_number:=1
@export_range(0,90) var camera_yaw_degrees:=15.0
var book_on_entry:=false
var player:WorldPilgrim
var camera:Camera3D
var camera_map_anchor:=Vector3.ZERO
var lift:AnimatableBody3D
var phase:=LiftPhase.IDLE
var phase_time:=0.0
var elapsed:=0.0
var completion_time:=-1.0
var completed:=false
var paused:=false
var hud:CanvasLayer
var label:Label
var stage_root:Node3D
var stage_data:Dictionary
var stage_environment:Environment
var rune_candidates:Array[Dictionary]=[]
var start_position:=Vector3.ZERO
var transition:GridClearTransition
var transition_consumed:=false
var story:Node3D
var stage7_puzzle:Node3D
var dialogue:Node3D
var interaction_icon:Label
var interaction_clock:=0.0
var stage_intro:CanvasLayer
var stage_help:CanvasLayer
var pause_menu:CanvasLayer
var ending:GridEndingComic
var ending_layer:CanvasLayer
const HOLD_SECONDS:=8.0
const WARNING_SECONDS:=2.0
func _ready() -> void:
	process_physics_priority=-20
	_install_inputs();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("64bfb2").lightened(.22)
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	stage_environment=environment.environment
	add_child(environment);get_viewport().msaa_3d=Viewport.MSAA_DISABLED
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera);camera.current=true
	hud=CanvasLayer.new();hud.layer=2;add_child(hud)
	interaction_icon=Label.new()
	interaction_icon.text="E"
	interaction_icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	interaction_icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	interaction_icon.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	interaction_icon.add_theme_font_size_override("font_size",28)
	interaction_icon.add_theme_color_override("font_color",Color("f6edda"))
	var interaction_circle:=StyleBoxFlat.new()
	interaction_circle.bg_color=Color(.10,.19,.16,.62)
	interaction_circle.border_color=Color(.91,.84,.65,.75)
	interaction_circle.set_border_width_all(1)
	interaction_circle.set_corner_radius_all(22)
	interaction_circle.corner_detail=16
	interaction_icon.add_theme_stylebox_override("normal",interaction_circle)
	interaction_icon.modulate.a=.82
	interaction_icon.size=Vector2(44,44)
	interaction_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(interaction_icon);interaction_icon.hide()
	label=Label.new();label.hide();label.position=Vector2(30,26);label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color("f3e7ce"));hud.add_child(label)
	var overlay:=CanvasLayer.new();overlay.layer=5;add_child(overlay)
	transition=GridClearTransition.new();transition.world=self;overlay.add_child(transition)
	stage_intro=preload("res://scripts/grid_stage/stage_intro.gd").new()
	add_child(stage_intro);stage_intro.configure(self)
	await load_stage(stage_number)
	stage_help=preload("res://scripts/grid_stage/stage_help.gd").new()
	stage_help.name="StageHelp";add_child(stage_help);stage_help.configure(self)
	pause_menu=preload("res://scripts/grid_stage/pause_menu.gd").new()
	pause_menu.name="PauseMenu";add_child(pause_menu);pause_menu.configure(self)
	if incremental_entry:
		incremental_entry = false
		_start_stage_entry()
		entry_prepared.emit()

func _entry_build_step() -> void:
	# Only first entry from the lobby yields. Restarts and book transitions keep
	# their existing synchronous contract. The lobby disables processing until ready.
	if incremental_entry:
		await get_tree().process_frame

func _start_stage_entry() -> void:
	if book_on_entry:
		book_on_entry=false
		transition.start_selection_entry()
	else:transition.start_entry()
func _uses_default_woodcutter() -> bool:
	return true
func load_stage(number:int,preserve_transition:=false) -> void:
	Analytics.begin_level(self, clampi(number,1,12))
	if is_instance_valid(ending_layer):
		remove_child(ending_layer);ending_layer.queue_free()
	ending=null;ending_layer=null
	hud.show()
	stage7_puzzle=null
	if is_instance_valid(dialogue):dialogue.cancel()
	if is_instance_valid(story) and story.has_method("cancel_dialogue"):story.cancel_dialogue()
	dialogue=null
	if is_instance_valid(transition) and not preserve_transition:transition.cancel()
	if is_instance_valid(stage_root):remove_child(stage_root);stage_root.queue_free()
	stage_number=clampi(number,1,12);stage_data=GridStageDefinitions.get_stage(stage_number)
	BgmPlayer.play_stage(stage_number)
	story=null
	label.remove_theme_stylebox_override("normal")
	label.remove_theme_font_override("font")
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color("f3e7ce"))
	start_position=stage_data.start
	rune_candidates.clear();phase=LiftPhase.IDLE;phase_time=0
	elapsed=0;completion_time=-1;completed=false;paused=false;transition_consumed=false
	stage_root=Node3D.new();stage_root.name="Stage%d"%stage_number;add_child(stage_root)
	await _entry_build_step()
	var low:=StageCells.new()
	for box in stage_data.low:low.fill(box[0],box[1])
	if stage_number!=12:low.install(stage_root,"StartAndPath")
	var high:=StageCells.new()
	for box in stage_data.raised:
		if stage_number!=12:high.fill(box[0],box[1])
	var goal_start:Vector3i=stage_data.goal_cells[0];var goal_end:Vector3i=stage_data.goal_cells[1]
	for x in range(goal_start.x,goal_end.x):
		for z in range(goal_start.z,goal_end.z):high.top_tints[Vector3i(x,goal_start.y,z)]=Color("dca2bb")
	if stage_number!=12:high.install(stage_root,"HighGoalAndTerrace")
	await _entry_build_step()
	for origin:Vector3 in stage_data.lifts:
		var moving:=StageCells.new();moving.fill(Vector3i(-4,-4,-4),Vector3i(4,0,4))
		var body:AnimatableBody3D=moving.install(stage_root,"RuneLift%d"%rune_candidates.size(),Color("dca2bb"),true)
		body.position=origin
		rune_candidates.append({"body":body,"origin":origin,"delta":stage_data.get("lift_delta",Vector3.UP*1.8),"radius":2.0,"enabled":true,"auto_board":stage_data.get("auto_lifts",false),"phase":LiftPhase.IDLE,"time":0.0})
		_add_engraving(body)
		if stage_number==7:body.set_meta("no_surface_marks",true)
	lift=null if rune_candidates.is_empty() else rune_candidates[0].body
	camera.size=stage_data.camera_size
	camera.h_offset=0;camera.v_offset=0
	var yaw:=deg_to_rad(camera_yaw_degrees)
	# Rotate around the map vertically; retain each camera's elevation and distance.
	var camera_arm:=Vector3(-sin(yaw),0,cos(yaw))*Vector2(10.6,14).length()+Vector3.UP*11.6
	if stage_data.get("fixed_camera",false):
		# Keep the view independent of the goal so offset endings remain visible.
		camera_arm=Vector3(sin(yaw),0,cos(yaw))*17.5+Vector3.UP*16.0
	if stage_number>=4 and not stage_data.get("fixed_camera",false):
		var goal_center:Vector2=stage_data.goal_rect.get_center()
		var toward:=Vector3(goal_center.x-start_position.x,0,goal_center.y-start_position.z).normalized()
		var side:=Vector3(-toward.z,0,toward.x)
		camera_arm=(-toward*cos(yaw)+side*sin(yaw))*17.5+Vector3.UP*11.6
	camera.position=stage_data.focus+camera_arm
	camera.look_at(stage_data.focus)
	if stage_number>=4 and not stage_data.get("fixed_camera",false):
		_fit_catalog_camera()
		camera.size*=.85
		camera_map_anchor=camera.position
		_follow_player_camera(0.0,true)
	var theme:String=stage_data.get("theme","water")
	stage_environment.background_color=Color("64bfb2").lightened(.22) if theme=="water" else Color("eee1c7") if theme=="sky" else Color("d9cbb0")
	if stage_number==11:stage_environment.background_color=Color("111426")
	await _entry_build_step()
	if theme=="water":
		var layers = preload("res://scripts/grid_stage/collage_layers.gd").new()
		stage_root.add_child(layers);layers.configure(camera,stage_root)
		if stage_number>=4:
			var ground = preload("res://scripts/grid_stage/pond_ground.gd").new()
			ground.name="PondGround"
			stage_root.add_child(ground);ground.configure(camera,layers,stage_number-3)
		var collage = preload("res://scripts/grid_stage/flower_backdrop.gd").new()
		stage_root.add_child(collage);collage.configure(camera,stage_number,layers)
	elif theme=="earth":
		var earth = preload("res://scripts/grid_stage/earth_backdrop.gd").new()
		earth.name="EarthBackdrop"
		stage_root.add_child(earth);earth.configure(camera,stage_number-3)
		if stage_number==7:
			var fans=preload("res://scripts/grid_stage/fan_backdrop.gd").new()
			fans.name="FanDecorations";stage_root.add_child(fans);fans.configure(camera,4)
	elif theme=="sky":
		var sky = preload("res://scripts/grid_stage/sky_backdrop.gd").new()
		sky.name="SkyBackdrop"
		stage_root.add_child(sky);sky.configure(camera,7 if stage_number==12 else stage_number-3)
	await _entry_build_step()
	player=preload("res://scripts/grid_stage/player.gd").new()
	# All story stages guard walking at cliffs; jumping still permits sea entry and gap crossings.
	player.prevent_walk_off_edges=true
	player.route=preload("res://scripts/grid_stage/route.gd").new();player.tower_root=stage_root
	player.camera=camera;player.position=start_position;stage_root.add_child(player);player.fell.connect(_respawn)
	await _entry_build_step()
	if stage_number==9:
		var tale=preload("res://scripts/grid_stage/stage6_story.gd").new()
		tale.name="Stage6Story";stage_root.add_child(tale);story=tale;tale.configure(self)
	# Stage5 uses felled trees instead of rune lifts.
	elif stage_number==8: # Three PreMaps precede the story stages.
		var props=preload("res://scripts/grid_stage/stage5_story.gd").new()
		props.name="Stage5Story";stage_root.add_child(props);story=props;props.configure(self)
	# Preserve Stage8's bird puzzle alongside main's optional Stage2 dialogue.
	elif stage_number==11:
		story=preload("res://scripts/grid_stage/gyeonwu_story.gd").new()
		story.name="GyeonwuStory";stage_root.add_child(story);story.configure(self)
	elif stage_number==7:
		story=preload("res://scripts/grid_stage/fan_story.gd").new()
		story.name="RedBlueFanStory";stage_root.add_child(story);story.configure(self)
	elif stage_number==6:
		story=preload("res://scripts/stage3/sea_story.gd").new()
		story.name="Stage3SeaStory";stage_root.add_child(story);story.configure(self)
	# Stage2 keeps its optional woodcutter dialogue encounter.
	await _entry_build_step()
	if stage_number==5 and _uses_default_woodcutter():
		dialogue=preload("res://scripts/grid_stage/woodcutter_dialogue.gd").new()
		dialogue.name="WoodcutterDialogue";stage_root.add_child(dialogue);dialogue.configure(self)
	elif stage_number==8:
		dialogue=preload("res://scripts/grid_stage/kitten_dialogue.gd").new()
		dialogue.name="KittenDialogue";stage_root.add_child(dialogue);dialogue.configure(self)
		story.cats.register_kitten(dialogue)
	if stage_number==12:
		var trap=preload("res://scripts/finalstage/false_exit.gd").new()
		trap.name="FalseExitTrap";stage_root.add_child(trap);trap.configure(self)
		var battle=preload("res://scripts/finalstage/battle.gd").new()
		battle.name="FinalBattle";stage_root.add_child(battle);battle.configure(self);story=battle
		trap.collapsed.connect(battle.start_phase_one)
	await _entry_build_step()
	var butterfly=preload("res://scripts/grid_stage/butterfly_guide.gd").new()
	butterfly.name="ButterflyGuide";stage_root.add_child(butterfly);butterfly.configure(self)
	if stage_number==12:stage_root.get_node("FalseExitTrap").connect("collapsed",butterfly.begin_roaming)
	if stage_number==12:
		var creature=preload("res://scripts/finalstage/kkwangcheol.gd").new()
		creature.name="Kkwangcheol";stage_root.add_child(creature);creature.configure(self)
		var branches=preload("res://scripts/finalstage/peach_branches.gd").new()
		branches.name="PeachBranches";stage_root.add_child(branches);branches.configure(self)
	await _entry_build_step()
	var slices = preload("res://scripts/grid_stage/screen_slices.gd").new()
	stage_root.add_child(slices);slices.configure(camera,stage_root)
	# Catalog Stage7 (Heungbu/Nolbu) is runtime stage 10, after three PreMaps.
	# Owned by this stage_root so restart/Back/stage changes dispose its state.
	if stage_number==10:
		stage7_puzzle=preload("res://scripts/grid_stage/heungbu_story.gd").new()
		stage7_puzzle.name="HeungbuNolbuPuzzle"
		stage_root.add_child(stage7_puzzle);stage7_puzzle.setup(self)
		for rune:Dictionary in rune_candidates:rune.body.queue_free()
		rune_candidates.clear();lift=null
	stage_intro.begin(stage_number,true)
	if not preserve_transition and not incremental_entry:
		_start_stage_entry()
	stage_loaded.emit(stage_number)
func _add_engraving(body:AnimatableBody3D) -> void:
	var marks:=StageCells.new()
	for x in range(-2,2):
		for z in range(-2,2):
			if x in [-2,1] or z in [-2,1]:marks.fill(Vector3i(x,0,z),Vector3i(x+1,1,z+1))
	var ink:=MeshInstance3D.new();ink.name="SquareEngraving";ink.mesh=marks.mesh(Color("64bfb2"));ink.scale.y=.005;ink.position.y=.002
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("64bfb2");ink.material_override=material;body.add_child(ink)
func _install_inputs() -> void:
	# Active grid stages have architectural interaction, not instrument slots.
	# Clear inherited project bindings so Q/F and locked E/R slots cannot fire.
	for obsolete in ["use","instrument_wind","instrument_water","instrument_fire"]:
		if InputMap.has_action(obsolete):InputMap.action_erase_events(obsolete)
	var mapping:Dictionary={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"interact":[KEY_E],"reset":[KEY_HOME],"stage_next":[KEY_ENTER,KEY_KP_ENTER],"stage_1":[KEY_1],"stage_2":[KEY_2],"stage_3":[KEY_3]}
	for action in mapping:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in mapping[action]:
			var key:=InputEventKey.new();key.physical_keycode=code;InputMap.action_add_event(action,key)
func on_lift(body:AnimatableBody3D=null) -> bool:
	if body==null:body=lift
	if not is_instance_valid(body):return false
	var relative:=player.global_position-body.global_position
	return absf(relative.x)<.83 and absf(relative.z)<.83 and absf(relative.y)<.16 and player.is_on_floor()
func occupied(body:AnimatableBody3D=null) -> bool:
	if body==null:body=lift
	if not is_instance_valid(body):return false
	var relative:=player.global_position-body.global_position
	return absf(relative.x)<1.03 and absf(relative.z)<1.03 and relative.y>=-.2 and relative.y<2
func nearest_rune() -> AnimatableBody3D:
	if paused:return null
	var nearest:AnimatableBody3D=null;var nearest_distance:=INF
	var anchor:=player.global_position+Vector3.UP*.65
	for candidate in rune_candidates:
		if not candidate.enabled or candidate.phase!=LiftPhase.IDLE:continue
		var body:AnimatableBody3D=candidate.body
		var target:=body.global_position+Vector3.UP*.025
		var distance:=anchor.distance_to(target)
		var selection_distance:=player.global_position.distance_to(body.global_position)
		if distance>float(candidate.radius) or selection_distance>=nearest_distance:continue
		var query:=PhysicsRayQueryParameters3D.create(anchor,target,5);query.exclude=[player.get_rid()]
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=body:continue
		nearest=body;nearest_distance=selection_distance
	return nearest
func use_rune() -> bool:
	# Historical scripted callers retain the same physical interaction contract.
	return interact_stone()
func nearest_interaction() -> Node3D:
	if paused or completed or player.input_locked or transition.active:return null
	var selected:Node3D=nearest_rune()
	var distance:=INF if selected==null else player.global_position.distance_squared_to(selected.global_position)
	if is_instance_valid(dialogue) and dialogue.can_interact():
		var dialogue_distance:=player.global_position.distance_squared_to(dialogue.global_position)
		if dialogue_distance<distance:selected=dialogue;distance=dialogue_distance
	if is_instance_valid(story) and story.has_method("interaction_target"):
		var candidate:Node3D=story.interaction_target()
		if candidate!=null and player.global_position.distance_squared_to(candidate.global_position)<distance:selected=candidate
	elif is_instance_valid(story) and story.has_method("can_interact") and story.can_interact():
		if player.global_position.distance_squared_to(story.NPC_FOOT)<distance:selected=story.items.fan_boy.sprite
	return selected
func _update_interaction_icon(delta:float) -> void:
	interaction_clock+=delta
	var selected:=nearest_interaction()
	interaction_icon.hide()
	if selected==null:return
	if selected==dialogue and dialogue.active:return
	var dialogue_height:float=1.6 if stage_number==8 else 2.05
	var anchor:=selected.global_position+Vector3.UP*(dialogue_height if selected==dialogue else .55)
	if is_instance_valid(story) and story.has_method("interaction_target") and selected==story.interaction_target():
		if story.is_speaking(selected):return
		anchor=story.interaction_anchor(selected)
	elif is_instance_valid(story) and story.has_method("can_interact") and selected==story.items.fan_boy.sprite:
		if story.npc_intro.visible:return
		anchor=story.NPC_FOOT+Vector3.UP*2.05
	if camera.is_position_behind(anchor):return
	interaction_icon.position=camera.unproject_position(anchor)-Vector2(22,44)+Vector2(0,sin(interaction_clock*2.8)*3)
	interaction_icon.show()
func interact_stone() -> bool:
	if paused or player.input_locked or transition.active:return false
	if is_instance_valid(dialogue) and nearest_interaction()==dialogue:return dialogue.begin()
	if is_instance_valid(story) and story.has_method("can_interact"):
		if nearest_interaction()==story.items.fan_boy.sprite:return story.interact()
	elif is_instance_valid(story) and story.has_method("interact"):
		if story.interact():return true
	if is_instance_valid(story) and not story.path_open:return false
	var selected:=nearest_interaction()
	if selected==null:return false
	if selected==dialogue:return dialogue.begin()
	if is_instance_valid(story):
		if story.has_method("interaction_target") and selected==story.interaction_target():return story.interact()
		if not story.path_open:return false
	if is_instance_valid(story) and story.has_method("before_lift") and not story.before_lift():return false
	for candidate in rune_candidates:
		if candidate.body==selected:
			candidate.phase=LiftPhase.RISING;candidate.time=0.0
			return true
	return false
func _physics_process(delta:float) -> void:
	if is_instance_valid(ending):return
	if paused or (is_instance_valid(transition) and transition.active):return
	if not completed:elapsed+=delta
	for candidate in rune_candidates:
		candidate.time+=delta
		var body:AnimatableBody3D=candidate.body
		var origin:Vector3=candidate.origin
		var destination:Vector3=origin+candidate.delta
		match candidate.phase:
			LiftPhase.IDLE:
				if candidate.get("auto_board",false) and not player.input_locked and not completed and on_lift(body):
					candidate.phase=LiftPhase.RISING;candidate.time=0.0
			LiftPhase.RISING:
				body.position=body.position.move_toward(destination,delta*1.2)
				if body.position.distance_to(destination)<.0001:body.position=destination;candidate.phase=LiftPhase.HOLDING;candidate.time=0.0
			LiftPhase.HOLDING:
				if candidate.time>=HOLD_SECONDS:candidate.phase=LiftPhase.WARNING;candidate.time=0.0
			LiftPhase.WARNING:
				if candidate.time>=WARNING_SECONDS and not occupied(body):candidate.phase=LiftPhase.RETURNING;candidate.time=0.0
			LiftPhase.RETURNING:
				if not occupied(body):body.position=body.position.move_toward(origin,delta*.9)
				if body.position.distance_to(origin)<.0001:body.position=origin;candidate.phase=LiftPhase.IDLE;candidate.time=0.0
	if not rune_candidates.is_empty():
		phase=rune_candidates[0].phase;phase_time=rune_candidates[0].time
	var location:=Vector2(player.position.x,player.position.z)
	var guide_ready:=true
	if stage_number==4:
		var guide:=stage_root.get_node_or_null("ButterflyGuide")
		guide_ready=guide!=null and bool(guide.contact_tutorial_finished)
	if not completed and guide_ready and (not is_instance_valid(stage7_puzzle) or (stage7_puzzle.path_open and not stage7_puzzle.reset_pending)) and (not is_instance_valid(story) or story.path_open) and (not is_instance_valid(story) or not story.has_method("can_complete") or story.can_complete()) and player.is_on_floor() and stage_data.goal_rect.has_point(location) and absf(player.position.y-float(stage_data.goal_height))<.08:
		complete_stage()

func complete_stage() -> void:
	if completed:return
	Analytics.complete_level()
	BgmPlayer.play_clear()
	if stage_number==12:BgmPlayer.set_boss_clear_level(0)
	completed=true;completion_time=elapsed
	var progress_error := LotusProgress.record_clear(stage_number)
	if progress_error != OK:push_warning("Could not save lotus progress: %s" % error_string(progress_error))
	player.input_locked=true;player.velocity=Vector3.ZERO
	player._play_directional_animation("idle")
	if is_instance_valid(story) and story.has_method("begin_clear_ascent"):story.begin_clear_ascent()

func _process(_delta:float) -> void:
	if is_instance_valid(ending):return
	_update_interaction_icon(_delta)
	if Input.is_action_just_pressed("reset"):restart();return
	for number in [1,2,3]:
		if Input.is_action_just_pressed("stage_%d"%number):load_stage(number);return
	if transition.active:
		label.text="Pause button | Home restart | 1/2/3 select" if not paused else "Paused | Click close to resume"
		return
	if completed and not transition_consumed:
		if paused:return
		if is_instance_valid(story) and story.has_method("clear_animation_finished") and not story.clear_animation_finished():return
		var butterfly=stage_root.get_node_or_null("ButterflyGuide")
		if butterfly!=null:
			butterfly.begin_departure()
			if not butterfly.departure_ready:return
		transition.start();return
	if not paused and stage_number>=4 and not stage_data.get("fixed_camera",false) and not (is_instance_valid(story) and story.get("controls_camera")==true):_follow_player_camera(_delta)
	if Input.is_action_just_pressed("interact"):
		BgmPlayer.play_ui_click()
		interact_stone()
	label.text="%s   |   WASD / arrows   |   E interact | Mouse cut / drag onto stone (Shift recut) | 1/2/3 select"%stage_title()
	var selected:=nearest_rune()
	if selected!=null:label.text="%s   |   E interact with the marked stone | Mouse cut / drag onto stone (Shift recut)"%stage_title()
	for candidate in rune_candidates:
		if candidate.phase==LiftPhase.WARNING and occupied(candidate.body):label.text="Returning soon  |  waits while occupied"
	if is_instance_valid(story) and stage_number not in [11,12]:label.text="%s  |  WASD 이동 · Space 점프 · E 발판 · Home 재시작"%stage_title()
	if stage_number==12:
		label.text="%s  |  드래그로 불덩이 자르기 · Home 재시작"%stage_title()
	if is_instance_valid(story) and stage_number==7:label.text="%s  |  WASD 이동 · Space 점프 · E 대화 · 드래그 자르기/장착"%stage_title()
	if is_instance_valid(story) and stage_number==6:label.text="%s  |  WASD 이동 · Space 점프 · E 대화 · Home 재시작"%stage_title()
	if is_instance_valid(story) and stage_number==8:label.text="%s  |  WASD 이동 · Space 점프 · 드래그: 절단·이동 / Shift+드래그: 조각 재절단 · Home 재시작"%stage_title()
	if is_instance_valid(story) and stage_number==9:label.text="Stage6 · 해와 달 | WASD 이동 · Space 점프 · 드래그: 떡 주기/나무 자르기 · Shift: 재절단 · E: 대화"
	if completed:label.text="Complete | Home retry | Back to maps"
	if paused:label.text="Paused  |  Click close to resume"
func _respawn() -> void:
	Analytics.fail_level("fall")
	if stage_number==12:player.set("rebounding",false)
	if is_instance_valid(story) and story.has_method("player_fell"):
		story.player_fell();return
	if is_instance_valid(dialogue):dialogue.cancel()
	if is_instance_valid(story) and story.has_method("cancel_dialogue"):story.cancel_dialogue()
	if is_instance_valid(story) and story.has_method("respawn"):
		story.respawn();return
	player.position=start_position;player.velocity=Vector3.ZERO
func restart() -> void:
	Analytics.fail_level("restart", false)
	load_stage(stage_number)

func show_ending() -> void:
	if stage_number!=12 or not completed or is_instance_valid(ending):return
	Analytics.end_session()
	transition_consumed=true
	player.input_locked=true;player.velocity=Vector3.ZERO
	stage_root.process_mode=Node.PROCESS_MODE_DISABLED
	hud.hide();stage_intro.panel.hide()
	ending_layer=CanvasLayer.new();ending_layer.layer=10;add_child(ending_layer)
	ending=preload("res://scenes/grid_stage/ending.tscn").instantiate()
	ending_layer.add_child(ending)

func _return_to_selection() -> void:
	Analytics.end_session()
	BgmPlayer.play_title()
	if is_instance_valid(dialogue):dialogue.cancel()
	if is_instance_valid(story) and story.has_method("cancel_dialogue"):story.cancel_dialogue()
	if is_instance_valid(transition):transition.cancel()
	paused=true
	if is_instance_valid(player):player.paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if map_selection_requested.get_connections().is_empty():
		get_tree().change_scene_to_file("res://scenes/grid_stage/menu.tscn")
	else:map_selection_requested.emit()

func stage_title() -> String:
	if stage_number<=3:return "PreMap%d"%stage_number
	var title:String=stage_data.get("story_title","")
	return "Stage%d · %s"%[stage_number-3,title] if not title.is_empty() else "Stage%d"%(stage_number-3)
func following_stage() -> int:
	return 0 if stage_number in [3,12] else stage_number+1

func _fit_catalog_camera() -> void:
	var points:Array[Vector3]=[]
	for part:Array in stage_data.low+stage_data.raised:
		for x:int in [part[0].x,part[1].x]:
			for y:int in [part[0].y,part[1].y]:
				for z:int in [part[0].z,part[1].z]:points.append(Vector3(x,y,z)*.2)
	for origin:Vector3 in stage_data.lifts:
		for offset:Vector3 in [Vector3.ZERO,stage_data.lift_delta]:
			for x:float in [-.8,.8]:
				for y:float in [-.8,1.5]:
					for z:float in [-.8,.8]:points.append(origin+offset+Vector3(x,y,z))
	var basis_:Basis=camera.global_basis
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for p:Vector3 in points:
		var q:=Vector2(p.dot(basis_.x),p.dot(basis_.y))
		low=low.min(q);high=high.max(q)
	var midpoint:Vector2=(low+high)*.5
	var correction:Vector3=basis_.x*(midpoint.x-camera.position.dot(basis_.x))+basis_.y*(midpoint.y-camera.position.dot(basis_.y))
	camera.position+=correction
	var viewport_size:Vector2=get_viewport().get_visible_rect().size
	var aspect:float=viewport_size.x/maxf(1,viewport_size.y)
	camera.size=maxf(19.5,maxf(high.y-low.y,(high.x-low.x)/aspect)*1.24)

func _follow_player_camera(delta:float,snap:bool=false) -> void:
	# Translate only in the fixed camera plane; yaw, pitch and player physics stay unchanged.
	var actor_point:Vector3=start_position if snap else player.global_position
	actor_point+=Vector3.UP*.7
	var relative:Vector3=actor_point-camera_map_anchor
	var desired:Vector3=camera_map_anchor+(camera.global_basis.x*relative.dot(camera.global_basis.x)+camera.global_basis.y*relative.dot(camera.global_basis.y))*.6
	if snap:
		camera.position=desired
	elif camera.position.distance_to(desired)>.08:
		camera.position=camera.position.lerp(desired,1.0-exp(-4.0*delta))

func _exit_tree() -> void:
	Analytics.end_session()
