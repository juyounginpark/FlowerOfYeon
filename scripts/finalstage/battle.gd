extends Node3D
## Three fireball phases, hanging instruments and the band's rain ritual.
const TOTAL_PHASES := 3
const PUNGMUL = preload("res://scripts/finalstage/pungmul.gd")
const GONG = preload("res://scripts/finalstage/hanging_gong.gd")
const RAIN = preload("res://scripts/finalstage/rain.gd")
const OPENING_FIRE = preload("res://scripts/finalstage/opening_fire.gd")
const CLEAR_LIGHT = preload("res://scripts/finalstage/clear_light.gd")
const PHASE_LINES := [
	"모두들 내 앞에서 썩 꺼지거라!",
	"세상 모든 것이 증오스럽다.",
	"용도 되지 못한 나 자신이 가장 증오스럽다...",
]
var world: GridStageWorld
var phase := 0
var path_open := false
var phase_one_finished := false
var phase_two_finished := false
var phase_two_remaining := 2.4
var phase_three_remaining := 2.4
var phase_three_finished := false
var spawn_remaining := 1.4
var fire: Dictionary = {}
var musicians: PUNGMUL
var gong: GONG
var small_gong: GONG
var rain: RAIN
var received := {"gong":false,"small_gong":false}
var fire_frames: Array[Texture2D] = []
var fire_images: Array[Image] = []
var intro_phase := 0
var intro_clock := 0.0
var phase_line: Label
var failed_phase := 0
var fading_fire: Array[Dictionary] = []
var cut_instruments := {"gong":false,"small_gong":false}
var rain_pending := false
var rain_wait := 0.0

func clear_hint() -> String:
	if path_open:return "나비를 따라가세요."
	var branches:=world.stage_root.get_node_or_null("PeachBranches")
	if branches!=null and bool(branches.get("peach_given")):
		return "꽝철이가 진정할 때까지 기다리세요."
	if received.gong and received.small_gong:
		if rain_pending:return "비가 내리기를 기다리세요."
		return "꽝철이에게 복숭아를 잘라 먹이세요."
	if phase_three_finished:
		return "풍물놀이패에 악기를 주세요."
	var current:=intro_phase if intro_phase>0 else phase
	match current:
		0:return "도착점으로 이동하세요."
		1:return "내려오는 불덩이를 자르세요."
		2:return "빨라진 불덩이를 자르세요."
		_:return "마지막 불덩이를 자르세요."

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	_load_fire_frames()
	var opening := OPENING_FIRE.new();opening.name="OpeningFire"
	add_child(opening);opening.configure(world,fire_frames)
	musicians=PUNGMUL.new();musicians.name="PungmulBand"
	add_child(musicians);musicians.configure(world)
	gong=GONG.new();gong.name="HangingGong"
	add_child(gong);gong.configure(world,preload("res://art/finalstage/gong.png"),Vector2(.225,.32),Vector2(.28,.80),.24)
	gong.delivered.connect(_on_instrument_delivered.bind("gong"))
	gong.cord_cut.connect(_on_instrument_cut.bind("gong"))
	small_gong=GONG.new();small_gong.name="HangingKkwaenggwari"
	add_child(small_gong);small_gong.configure(world,preload("res://art/finalstage/kkwaenggwari.png"),Vector2(.30,.24),Vector2(.33,.80),.20)
	small_gong.delivered.connect(_on_instrument_delivered.bind("small_gong"))
	small_gong.cord_cut.connect(_on_instrument_cut.bind("small_gong"))
	var rain_layer := CanvasLayer.new();rain_layer.layer=4;add_child(rain_layer)
	rain=RAIN.new();rain_layer.add_child(rain);rain.configure(world)
	var light_layer := CanvasLayer.new();light_layer.layer=5;add_child(light_layer)
	var clear_light := CLEAR_LIGHT.new();light_layer.add_child(clear_light);clear_light.configure(world)
	var dialogue_layer := CanvasLayer.new();dialogue_layer.layer=6;add_child(dialogue_layer)
	phase_line=Label.new();dialogue_layer.add_child(phase_line)
	phase_line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	phase_line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	phase_line.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	phase_line.add_theme_font_size_override("font_size",34)
	phase_line.add_theme_color_override("font_color",Color("fff2dc"))
	phase_line.add_theme_color_override("font_outline_color",Color(.08,.04,.03,.85))
	phase_line.add_theme_constant_override("outline_size",6)
	phase_line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	phase_line.hide()

func start_phase_one() -> void:
	if phase!=0 or intro_phase!=0:return
	_queue_phase(1)

func _queue_phase(number: int) -> void:
	BgmPlayer.play_boss_roar()
	intro_phase=number;intro_clock=0
	var camera_effect := world.stage_root.get_node("FalseExitTrap")
	camera_effect.set("dialogue_shake",true);camera_effect.set("battle_shake",true)
	phase_line.text=PHASE_LINES[number-1]
	phase_line.modulate.a=0;phase_line.show()

func _advance_intro(delta: float) -> void:
	intro_clock+=delta
	var frame := get_viewport().get_visible_rect().size
	var fade_in := clampf(intro_clock/.4,0,1)
	var fade_out := clampf((3.0-intro_clock)/.5,0,1)
	phase_line.modulate.a=minf(fade_in,fade_out)
	phase_line.position=Vector2(frame.x*.08,frame.y*.08+18*(1-smoothstep(0,1,fade_in))-10*(1-fade_out))
	phase_line.size=Vector2(frame.x*.84,frame.y*.13)
	if intro_clock<3.5:return
	phase_line.hide()
	phase=intro_phase;intro_phase=0
	world.stage_root.get_node("FalseExitTrap").set("dialogue_shake",false)
	fire={};spawn_remaining=0
	if phase>1:world.stage_root.get_node("FalseExitTrap").call("shake",1.8)

func _load_fire_frames() -> void:
	var sheet := preload("res://art/finalstage/fireball_8frames.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	for index in range(8):
		var column := index%4
		var row := floori(index/4.0)
		var first := Vector2i(roundi(column*sheet.get_width()/4.0),roundi(row*sheet.get_height()/2.0))
		var last := Vector2i(roundi((column+1)*sheet.get_width()/4.0),roundi((row+1)*sheet.get_height()/2.0))
		var image := sheet.get_region(Rect2i(first,last-first))
		fire_images.append(image)
		fire_frames.append(ImageTexture.create_from_image(image))

func _start_phase_two() -> void:
	_queue_phase(2)

func _start_phase_three() -> void:
	_queue_phase(3)

func _on_instrument_delivered(id: String) -> void:
	received[id]=true
	BgmPlayer.set_boss_clear_level(2 if received.gong and received.small_gong else 1)
	musicians.receive_instrument(bool(received.gong and received.small_gong))
	if received.gong and received.small_gong:
		_set_peach_frame(6)
		rain_pending=true;rain_wait=0

func on_dragon_moved_aside() -> void:
	path_open=true
	world.stage_root.get_node("ButterflyGuide").call("guide_to_exit")

func _on_instrument_cut(id: String) -> void:
	cut_instruments[id]=true
	_set_peach_frame(5 if cut_instruments.gong and cut_instruments.small_gong else 4)

func _set_peach_frame(index: int) -> void:
	world.stage_root.get_node("PeachBranches").call("set_growth_frame",index)

func respawn() -> void:
	world.player.position=world.start_position
	world.player.velocity=Vector3.ZERO
	if failed_phase==0:return
	var retry := maxi(1,failed_phase-1)
	failed_phase=0
	if retry==1:
		phase_one_finished=false;phase_two_remaining=2.4
	phase_two_finished=false;phase_three_remaining=2.4
	phase_three_finished=false
	# Rewind only combat. Severed props, deliveries, the collapsed map and band persist.
	fire={}
	_queue_phase(retry)

func _spawn_fire() -> void:
	BgmPlayer.play_boss_fire()
	var roof: float = world.stage_data.goal_height
	var target := Vector3(.2,roof,-.8)
	var body := RigidBody3D.new();body.name="Phase%dFireball"%phase
	body.collision_layer=0;body.collision_mask=1
	var speed := 2.2 if phase==3 else 1.6 if phase==2 else 1.0
	body.gravity_scale=.08*speed;body.linear_damp=.7;body.continuous_cd=true
	add_child(body);body.global_position=target+Vector3.UP*6.0
	body.linear_velocity=Vector3.DOWN*.9*speed
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new();sphere.radius=.5
	collision.shape=sphere;body.add_child(collision)
	var sprite := Sprite3D.new()
	sprite.texture=fire_frames[0]
	sprite.pixel_size=5.6/sprite.texture.get_height()
	sprite.position.y=2.1
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("map_occluded",true)
	sprite.set_meta("paper_alpha_border",true)
	sprite.set_meta("paper_outline_fallback",true)
	sprite.set_meta("paper_extend_cut",true)
	sprite.set_meta("paper_minimum_piece_area",20.0)
	body.add_child(sprite)
	sprite.global_basis=world.camera.global_basis
	_update_depth(sprite)
	var cutter := GridPaperCutting.new();cutter.name="FireballCutting"
	add_child(cutter);cutter.configure(world.camera,[sprite])
	# Cut debris falls onto the roof-height plane, rather than stopping in the sky.
	var floor_y: float = world.camera.unproject_position(target).y*1000.0/get_viewport().get_visible_rect().size.y
	for source: Dictionary in cutter.sources:
		source.baseline=floor_y;source.floor.position.y=floor_y+12
	fire={"body":body,"sprite":sprite,"cutter":cutter,"resolved":false,"roof":roof,"animation_time":0.0,"frame":0}
	cutter.source_cut.connect(_on_fire_cut)

func _animate_fire(delta: float) -> void:
	fire.animation_time+=delta
	var index := int(float(fire.animation_time)*8.0)%8
	if index==int(fire.frame):return
	fire.frame=index
	fire.sprite.texture=fire_frames[index]
	for source: Dictionary in fire.cutter.sources:
		source.texture=fire_frames[index];source.image=fire_images[index]
	for piece: Dictionary in fire.cutter.pieces:
		piece.paper_material.albedo_texture=fire_frames[index]
		for layer: MeshInstance3D in [piece.shadow,piece.border]:
			layer.material_override.set_shader_parameter("source_ink",fire_frames[index])

func _update_depth(sprite: Sprite3D) -> void:
	var depth := (world.camera.global_position-sprite.global_position).dot(world.camera.global_basis.z)
	sprite.set_meta("background_depth",depth)

func _on_fire_cut(_sprite: Sprite3D) -> void:
	if fire.is_empty() or _sprite!=fire.sprite or fire.resolved:return
	fire.resolved=true
	fire.body.freeze=true;fire.body.collision_mask=0
	fire.sprite.set_meta("cuttable",false)
	# Both halves are harmless and released into the existing paper physics.
	for piece: Dictionary in fire.cutter.pieces:
		piece.attached=false;piece.body.freeze=false
		piece.body.collision_layer=int(piece.source.layer)
	fading_fire.append({"paper":fire.cutter,"time":0.0})
	_finish_phase()

func _impact() -> void:
	fire.resolved=true;fire.body.freeze=true
	failed_phase=phase
	fire.sprite.set_meta("cuttable",false)
	fire.cutter.hide_source(fire.sprite)
	var player := world.player
	if player.position.y>=float(fire.roof)-.2:
		var bounds: Array = world.stage_data.raised[0]
		var last: Vector3i = bounds[1]
		var first: Vector3i = bounds[0]
		var cut_x := (first.x+16)*.2
		var exits: Array[Vector3] = [
			Vector3(cut_x-1.3,fire.roof,player.position.z),
			Vector3(last.x*.2+1.3,fire.roof,player.position.z),
			Vector3(player.position.x,fire.roof,first.z*.2-1.3),
			Vector3(player.position.x,fire.roof,last.z*.2+1.3),
		]
		var target: Vector3 = exits[0]
		for exit: Vector3 in exits:
			if player.position.distance_squared_to(exit)<player.position.distance_squared_to(target):target=exit
		player.call("rebound_to",target)
	# Wait for the actual fall/respawn before replaying the previous phase's dialogue.

func _finish_phase() -> void:
	if phase==1:
		phase_one_finished=true
		musicians.begin_rise()
	elif phase==2:
		phase_two_finished=true
		gong.begin_descent()
	elif phase==3:
		phase_three_finished=true
		world.stage_root.get_node("FalseExitTrap").call("stop_shake")
		small_gong.begin_descent()
	_set_peach_frame(phase)

func _process(delta: float) -> void:
	if world.paused or world.transition.active:return
	if rain_pending:
		rain_wait+=delta
		if rain_wait>=.8:
			rain_pending=false
			rain.begin_rain();_set_peach_frame(7)
			world.stage_root.get_node("Kkwangcheol").call("begin_weakening")
	for entry in fading_fire.duplicate():
		entry.time+=delta
		var opacity := 1.0-clampf(float(entry.time)/2.2,0,1)
		for piece: Dictionary in entry.paper.pieces:
			piece.paper_material.albedo_color.a=opacity
			for layer: MeshInstance3D in [piece.shadow,piece.border]:
				layer.material_override.set_shader_parameter("opacity",opacity)
		if opacity<=0:
			entry.paper.queue_free();fading_fire.erase(entry)

func _physics_process(delta: float) -> void:
	var locked: bool = world.paused or world.transition.active or world.completed
	if not fire.is_empty():fire.body.freeze=locked or bool(fire.resolved)
	if locked:return
	if intro_phase!=0:
		_advance_intro(delta)
		return
	if phase==0 or phase_three_finished:return
	if phase==1 and phase_one_finished:
		phase_two_remaining-=delta
		if phase_two_remaining<=0:_start_phase_two()
		return
	if phase==2 and phase_two_finished:
		phase_three_remaining-=delta
		if phase_three_remaining<=0:_start_phase_three()
		return
	if fire.is_empty():
		spawn_remaining-=delta
		if spawn_remaining<=0:_spawn_fire()
		return
	if fire.resolved:return
	fire.sprite.global_basis=world.camera.global_basis
	_update_depth(fire.sprite)
	_animate_fire(delta)
	if fire.body.global_position.y<=float(fire.roof)+.6:_impact()
