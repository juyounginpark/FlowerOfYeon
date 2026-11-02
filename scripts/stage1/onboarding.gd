extends CanvasLayer
enum Step { SPAWN, MOVE, MOVE_HOLD, MOVE_FADE, JUMP, JUMP_HOLD, INTERACT, DONE }
const HOLD_SECONDS:=2.0
const FADE_SECONDS:=.45
const KEY_SHEET:="res://art/stage1/tutorial/keyboard_tutorial_v1.png"
# Boundaries lie in the generated sheet's transparent gutters (1254 px square).
const KEY_ROWS:=[Vector2i(0,636),Vector2i(636,936),Vector2i(936,1254)]
var world:GridStageWorld
var bridge:Node3D
var butterfly:Node3D
var step:=Step.SPAWN
var elapsed:=0.0
var animation_clock:=0.0
var previous_position:=Vector3.ZERO
var panel:Control
var key_image:TextureRect
var instruction:Label
var key_textures:Array[Texture2D]=[]
var arrow:Node2D
var arrow_label:Label
var butterfly_label:Label
var butterfly_message_time:=0.0
var crossed_bridge:=false
var arrow_start:=Vector2.ZERO
var arrow_end:=Vector2.ZERO

func configure(owner_world:GridStageWorld,tree_bridge:Node3D) -> void:
	world=owner_world;bridge=tree_bridge;layer=8
	butterfly=world.stage_root.get_node("ButterflyGuide")
	world.stage_root.set_meta("stage1_interaction_ready",false)
	previous_position=world.player.global_position
	var sheet:Image=load(KEY_SHEET).get_image()
	if sheet.is_compressed():sheet.decompress()
	for index:int in range(3):
		var top:int=KEY_ROWS[index].x
		var bottom:int=KEY_ROWS[index].y
		var row:=sheet.get_region(Rect2i(0,top,sheet.get_width(),bottom-top))
		key_textures.append(ImageTexture.create_from_image(row.get_region(row.get_used_rect())))
	panel=Control.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	key_image=TextureRect.new();key_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	key_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	key_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;panel.add_child(key_image)
	instruction=_label();panel.add_child(instruction);panel.hide()
	arrow=Node2D.new();add_child(arrow);arrow.draw.connect(_draw_arrow);arrow.hide()
	arrow_label=_label();add_child(arrow_label);arrow_label.hide()
	butterfly_label=_label();add_child(butterfly_label);butterfly_label.hide()
	butterfly_label.text="나비는 방향을 알려준다."
	world.player.jumped.connect(_on_jump)
	world.dialogue.first_player_interaction.connect(_on_interaction)

func _label() -> Label:
	var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color("30291f"))
	var paper:=StyleBoxFlat.new();paper.bg_color=Color(.97,.93,.82,.94)
	paper.set_corner_radius_all(8);paper.content_margin_left=12;paper.content_margin_right=12
	paper.content_margin_top=8;paper.content_margin_bottom=8
	label.add_theme_stylebox_override("normal",paper)
	return label

func _show_step(next:Step) -> void:
	step=next;elapsed=0;panel.modulate.a=1.0
	match step:
		Step.MOVE:key_image.texture=key_textures[0];instruction.text="WASD로 이동하세요"
		Step.JUMP:key_image.texture=key_textures[1];instruction.text="스페이스바를 눌러 점프하세요"
		Step.INTERACT:
			key_image.texture=key_textures[2];instruction.text="E키를 눌러 상호작용하세요"
			world.stage_root.set_meta("stage1_interaction_ready",true)

func _on_jump() -> void:
	if step==Step.JUMP:step=Step.JUMP_HOLD;elapsed=0

func _on_interaction() -> void:
	if step==Step.INTERACT:step=Step.DONE;panel.hide()

func _process(delta:float) -> void:
	if world==null:return
	var movement:=world.player.global_position-previous_position
	previous_position=world.player.global_position;movement.y=0
	var blocked:bool=world.paused or world.transition.active or world.player.input_locked or world.completed
	if blocked:
		panel.hide();arrow.hide();arrow_label.hide();butterfly_label.hide();return
	animation_clock+=delta
	if step==Step.SPAWN and world.player.sprite.is_visible_in_tree():_show_step(Step.MOVE)
	elif step==Step.MOVE:
		var input:=Input.get_vector("left","right","back","forward")
		if input.length_squared()>.01 and movement.length()>.001 and movement.length()<world.player.move_speed*delta*3+.05:
			step=Step.MOVE_HOLD;elapsed=0
	elif step==Step.MOVE_HOLD:
		elapsed+=delta
		if elapsed>=HOLD_SECONDS:step=Step.MOVE_FADE;elapsed=0
	elif step==Step.MOVE_FADE:
		elapsed+=delta;panel.modulate.a=1.0-smoothstep(0,FADE_SECONDS,elapsed)
		if elapsed>=FADE_SECONDS:_show_step(Step.JUMP)
	elif step==Step.JUMP_HOLD:
		elapsed+=delta
		if elapsed>=HOLD_SECONDS:_show_step(Step.INTERACT)
	panel.visible=step not in [Step.SPAWN,Step.DONE]
	_layout()
	_update_bridge_arrow()
	butterfly_label.visible=butterfly.state=="tutorial"
	if butterfly_label.visible:
		var at:=world.camera.unproject_position(butterfly.global_position)
		butterfly_label.position=_clamp_panel(at+Vector2(24,-50),butterfly_label.size)
		butterfly_message_time+=delta
		if butterfly_message_time>=3.0:
			butterfly_label.hide()
			butterfly.finish_contact_tutorial()

func _clamp_panel(point:Vector2,size:Vector2) -> Vector2:
	var frame:=get_viewport().get_visible_rect().size
	return Vector2(clampf(point.x,8,maxf(8,frame.x-size.x-8)),clampf(point.y,8,maxf(8,frame.y-size.y-8)))

func _layout() -> void:
	var scale_ui:=clampf(get_viewport().get_visible_rect().size.y/900.0,.7,1.3)
	var dimensions:=Vector2(280,150)*scale_ui
	panel.size=dimensions
	key_image.position=Vector2(55,0)*scale_ui;key_image.size=Vector2(170,100)*scale_ui
	instruction.position=Vector2(0,106)*scale_ui;instruction.size=Vector2(280,44)*scale_ui
	instruction.add_theme_font_size_override("font_size",roundi(20*scale_ui))
	var head:=world.camera.unproject_position(world.player.global_position+world.camera.global_basis.y*1.5)
	panel.position=_clamp_panel(head+Vector2(32,-100)*scale_ui,dimensions)

func _update_bridge_arrow() -> void:
	if bridge.installed and not crossed_bridge:
		var player:Vector3=world.player.global_position
		var finish:Vector3=bridge.to_global(bridge.finish)
		if world.player.is_on_floor() and player.y>=finish.y-.15 and Vector2(player.x-finish.x,player.z-finish.z).length()<.85:crossed_bridge=true
	arrow.visible=bridge.installed and not crossed_bridge
	arrow_label.visible=arrow.visible
	if not arrow.visible:return
	arrow_start=world.camera.unproject_position(bridge.to_global(bridge.start)+Vector3.UP*.25)
	arrow_end=world.camera.unproject_position(bridge.to_global(bridge.finish)+Vector3.UP*.25)
	arrow_label.text="다리 위로 이동하세요"
	arrow_label.position=_clamp_panel(arrow_start.lerp(arrow_end,.5)+Vector2(24,-25),arrow_label.size)
	arrow.queue_redraw()

func _draw_arrow() -> void:
	var direction:Vector2=(arrow_end-arrow_start).normalized()
	var side:=direction.orthogonal()
	var scale_ui:=clampf(get_viewport().get_visible_rect().size.y/900.0,.7,1.3)
	for index:int in range(3):
		var progress:=fmod(animation_clock*.28+float(index)/3.0,1.0)
		var tip:=arrow_start.lerp(arrow_end,.12+progress*.76)
		var points:=PackedVector2Array([tip-direction*18*scale_ui+side*12*scale_ui,tip,tip-direction*18*scale_ui-side*12*scale_ui])
		arrow.draw_polyline(points,Color("4b3726"),8*scale_ui,true)
		arrow.draw_polyline(points,Color("ffe79a"),4*scale_ui,true)
