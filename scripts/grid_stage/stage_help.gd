extends CanvasLayer
const REVEAL_SECONDS:=10.0
const HINTS:={
	1:"문양 발판에서 E를 누르세요.",
	2:"끊어진 길을 점프로 건너세요.",
	3:"문양 발판을 타고 올라가세요.",
	4:"나무를 잘라 다리를 만드세요.",
	5:"나무꾼에게 날개옷을 주세요.",
	6:"물속으로 뛰어드세요.",
	7:"빨간 부채로 부채질하세요.",
	8:"굴비로 고양이를 유인하세요.",
	9:"호랑이에게 떡을 먹이세요.",
	10:"제비가 가져온 박을 자르세요.",
	11:"새가 앉은 나뭇가지를 자르세요.",
}
var world:GridStageWorld
var icon:TextureButton
var bubble:Panel
var elapsed:=0.0
var reveal_age:=0.0
var bubble_alpha:=0.0
var opened:=false
var displayed_hint:=""
var pressed_on_ui:=false
var pressed_on_icon:=false

func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;layer=9
	icon=TextureButton.new();icon.name="MinhwaHelpIcon"
	icon.texture_normal=load("res://art/icons/minhwa_help.png")
	icon.ignore_texture_size=true;icon.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	icon.tooltip_text="클리어 힌트"
	icon.pressed.connect(_toggle)
	add_child(icon);icon.hide()
	bubble=preload("res://scripts/grid_stage/speech_bubble.gd").new()
	bubble.name="StageClearHint";bubble.automatic=false
	add_child(bubble)
	world.stage_loaded.connect(reset)
	get_viewport().size_changed.connect(_layout)
	reset(world.stage_number)

func reset(_number:int) -> void:
	elapsed=0;reveal_age=0;bubble_alpha=0;opened=false;displayed_hint=""
	pressed_on_ui=false;pressed_on_icon=false
	icon.hide();bubble.close()
	# Process UI clicks before any scene-specific cutting _input handlers.
	get_parent().move_child(self,-1)
	_layout()

func _blocked() -> bool:
	return not is_instance_valid(world.player) or world.paused or world.completed or world.transition.active or world.player.input_locked or not world.hud.visible

func _hint() -> String:
	if world.stage_number==12 and is_instance_valid(world.story) and world.story.has_method("clear_hint"):
		return world.story.clear_hint()
	return HINTS.get(world.stage_number,"나비를 따라 도착점으로 이동하세요.")

func _toggle() -> void:
	if _blocked() or elapsed<REVEAL_SECONDS:return
	opened=not opened
	if opened:_refresh_hint()

func _refresh_hint() -> void:
	var text:=_hint()
	if text==displayed_hint and bubble.visible:return
	displayed_hint=text
	bubble.present("도움말",_wrap(text))
	_layout()

func _wrap(text:String) -> String:
	var font:Font=bubble.body.get_theme_font("font")
	var font_size:int=bubble.body.get_theme_font_size("font_size")
	var lines:=PackedStringArray()
	for paragraph:String in text.split("\n"):
		var line:=""
		for word:String in paragraph.split(" "):
			var candidate:=word if line.is_empty() else line+" "+word
			if not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>420:
				lines.append(line);line=word
			else:line=candidate
		lines.append(line)
	return "\n".join(lines)

func _layout() -> void:
	if not is_instance_valid(icon):return
	var frame:=get_viewport().get_visible_rect().size
	var unit:=clampf(minf(frame.x/1280.0,frame.y/720.0),.65,1.35)
	icon.size=Vector2.ONE*68*unit
	icon.position=frame-icon.size-Vector2.ONE*24*unit
	var fit:=minf(unit,(frame.x-24)/maxf(1,bubble.size.x))
	bubble.scale=Vector2.ONE*fit
	bubble.position=Vector2(maxf(8,frame.x-bubble.size.x*fit-24*unit),maxf(8,icon.position.y-bubble.size.y*fit-8*unit))
	# Keep the shared hanji paper, moving its tail toward the help medallion.
	var paper:Control=bubble.get_child(0)
	paper.set("tail_ratio",clampf((icon.position.x+icon.size.x*.5-bubble.position.x)/fit/bubble.size.x,.5,1.0))
	paper.queue_redraw()

func _process(delta:float) -> void:
	if _blocked():
		icon.hide();bubble.close();opened=false;bubble_alpha=0
		pressed_on_ui=false;pressed_on_icon=false
		return
	elapsed+=delta
	if elapsed<REVEAL_SECONDS:return
	icon.show();reveal_age+=delta;icon.modulate.a=minf(1,reveal_age/.3)
	if opened:
		if world.stage_number==12 and _hint()!=displayed_hint:
			# A new boss objective requires another deliberate click, never an auto-reveal.
			opened=false;bubble_alpha=0;bubble.close();pressed_on_icon=false
		else:_refresh_hint()
	bubble_alpha=move_toward(bubble_alpha,1.0 if opened else 0.0,delta/.18)
	bubble.modulate.a=bubble_alpha
	if not opened and bubble_alpha<=0:bubble.close()

func _input(event:InputEvent) -> void:
	if not icon.visible or _blocked():return
	if event is InputEventMouseButton:
		var over_icon:=icon.get_global_rect().has_point(event.position)
		var over_bubble:=bubble.visible and Rect2(bubble.position,bubble.size*bubble.scale).has_point(event.position)
		if event.button_index!=MOUSE_BUTTON_LEFT:
			if over_icon or over_bubble:get_viewport().set_input_as_handled()
			return
		if event.pressed:
			pressed_on_ui=over_icon or over_bubble;pressed_on_icon=over_icon
			if pressed_on_ui:get_viewport().set_input_as_handled()
		elif pressed_on_ui:
			if pressed_on_icon and over_icon:_toggle();icon.grab_focus()
			pressed_on_ui=false;pressed_on_icon=false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pressed_on_ui:
		get_viewport().set_input_as_handled()
