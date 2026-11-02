extends CanvasLayer
const ART=preload("res://scripts/grid_stage/pause_art.gd")
const FONT=preload("res://art/fonts/HS-Winter-Snowflake.ttf")
const PANEL_SIZE:=Vector2(640,540)
var world:GridStageWorld
var audio:Node
var pause_button:TextureButton
var shade:ColorRect
var panel:Control
var close_button:TextureButton
var sound_button:TextureButton
var volume_label:Label
var cells:Array[TextureButton]=[]
var opened:=false
var adjusting_volume:=false
var eat_opening_release:=false
var leaving:=false
var player_was_paused:=false

func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;layer=20;process_mode=Node.PROCESS_MODE_ALWAYS
	audio=get_node("/root/GameAudio")
	pause_button=_icon("PauseButton","pause",Vector2.ZERO,Vector2(68,68),self)
	pause_button.tooltip_text="일시정지";pause_button.pressed.connect(open_menu)
	pause_button.focus_mode=Control.FOCUS_NONE
	shade=ColorRect.new();shade.name="PauseShade";shade.color=Color(.06,.08,.06,.60)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	panel=Control.new();panel.name="PausePanel";panel.size=PANEL_SIZE
	panel.mouse_filter=Control.MOUSE_FILTER_STOP;shade.add_child(panel)
	var paper:=TextureRect.new();paper.name="HanjiPanel"
	paper.texture=load("res://art/ui/pause/panel.png")
	paper.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;paper.size=PANEL_SIZE
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(paper)
	_label("일시정지",Vector2(130,58),Vector2(380,62),36)
	close_button=_icon("ClosePause","close",Vector2(528,48),Vector2(56,56),panel)
	close_button.tooltip_text="닫기";close_button.pressed.connect(close_menu)
	close_button.focus_mode=Control.FOCUS_NONE
	_label("소리",Vector2(200,145),Vector2(240,34),23)
	sound_button=_icon("MuteSound","sound",Vector2(78,190),Vector2(64,64),panel)
	sound_button.pressed.connect(audio.toggle_mute)
	for i:int in range(10):
		var cell:=_icon("Volume%d"%(i+1),"empty",Vector2(170+i*32,196),Vector2(27,52),panel)
		cell.tooltip_text="음량 %d%%"%((i+1)*10)
		cell.button_down.connect(_begin_volume.bind(i+1))
		cell.pressed.connect(audio.set_level.bind(i+1))
		cell.mouse_entered.connect(_drag_volume.bind(i+1))
		cell.gui_input.connect(_volume_key)
		cells.append(cell)
	volume_label=_label("",Vector2(220,258),Vector2(200,32),20)
	var lobby:=_text_button("LobbyButton","로비로 나가기",Vector2(154,315))
	lobby.pressed.connect(_queue_leave.bind(false))
	var title:=_text_button("TitleButton","타이틀로 나가기",Vector2(154,404))
	title.pressed.connect(_queue_leave.bind(true))
	audio.volume_changed.connect(_refresh_volume)
	_refresh_volume(int(audio.level))
	get_viewport().size_changed.connect(_layout)
	world.stage_loaded.connect(_stage_loaded)
	shade.hide();_layout()

func _label(text:String,position_:Vector2,size_:Vector2,font_size:int) -> Label:
	var label:=Label.new();label.text=text;label.position=position_;label.size=size_
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("39372d"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(label)
	return label

func _icon(title:String,kind:String,position_:Vector2,size_:Vector2,parent:Node) -> TextureButton:
	var button:=TextureButton.new();button.name=title
	button.texture_normal=ART.texture(kind);button.ignore_texture_size=true
	button.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.position=position_;button.size=size_;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.mouse_filter=Control.MOUSE_FILTER_STOP
	button.mouse_entered.connect(func():button.self_modulate=Color(1.08,1.08,1.08))
	button.mouse_exited.connect(func():button.self_modulate=Color.WHITE)
	button.focus_entered.connect(func():button.self_modulate=Color(1.08,1.08,1.08))
	button.focus_exited.connect(func():button.self_modulate=Color.WHITE)
	parent.add_child(button)
	return button

func _text_button(title:String,text:String,position_:Vector2) -> TextureButton:
	var button:=_icon(title,"button",position_,Vector2(332,76),panel)
	# Text remains editable and readable independently of the generated button art.
	var label:=Label.new();label.text=text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",25)
	label.add_theme_color_override("font_color",Color("39372d"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(label)
	return button

func _layout() -> void:
	var frame:=get_viewport().get_visible_rect().size
	var unit:=clampf(minf(frame.x/1280.0,frame.y/720.0),.65,1.35)
	pause_button.size=Vector2.ONE*68*unit
	pause_button.position=Vector2(frame.x-pause_button.size.x-24*unit,24*unit)
	shade.position=Vector2.ZERO;shade.size=frame
	var panel_scale:=minf(1.2,minf((frame.x-32)/PANEL_SIZE.x,(frame.y-32)/PANEL_SIZE.y))
	panel.scale=Vector2.ONE*panel_scale;panel.position=(frame-PANEL_SIZE*panel_scale)*.5

func _can_open() -> bool:
	return not leaving and is_instance_valid(world.player) and not world.paused and not world.transition.active and not world.completed and world.hud.visible

func open_menu() -> void:
	if opened or not _can_open():return
	player_was_paused=world.player.paused
	opened=true;world.paused=true;world.player.paused=true
	if is_instance_valid(world.stage_help):world.stage_help.hide()
	pause_button.hide();shade.show()
	# Pause the scene tree too: physics, timers, actors and paper all stop together.
	get_tree().paused=true

func close_menu() -> void:
	if not opened:return
	opened=false;adjusting_volume=false;eat_opening_release=false
	shade.hide();get_tree().paused=false
	world.paused=false
	if is_instance_valid(world.player):world.player.paused=player_was_paused
	if is_instance_valid(world.stage_help):world.stage_help.show()
	pause_button.show()

func _stage_loaded(_number:int) -> void:
	if opened:close_menu()
	get_parent().move_child(self,-1)
	_layout()

func _refresh_volume(level:int) -> void:
	for i:int in range(cells.size()):cells[i].texture_normal=ART.texture("filled" if i<level else "empty")
	volume_label.text="음소거" if level==0 else "%d%%"%(level*10)
	sound_button.modulate=Color(.65,.65,.65) if level==0 else Color.WHITE
	sound_button.tooltip_text="소리 켜기" if level==0 else "음소거"

func _begin_volume(level:int) -> void:
	adjusting_volume=true;audio.set_level(level)

func _drag_volume(level:int) -> void:
	if adjusting_volume and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):audio.set_level(level)

func _volume_key(event:InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		audio.set_level(int(audio.level)+(-1 if event.is_action_pressed("ui_left") else 1))
		get_viewport().set_input_as_handled()

func _queue_leave(to_title:bool) -> void:
	if leaving:return
	BgmPlayer.play_ui_click()
	leaving=true
	_leave.call_deferred(to_title)

func _leave(to_title:bool) -> void:
	close_menu()
	if to_title:
		var error:=get_tree().change_scene_to_file("res://scenes/gametitle/GameTitleAnimated.tscn")
		if error!=OK:
			leaving=false;push_error("Could not open title: %s"%error_string(error))
	else:world._return_to_selection()

func _process(_delta:float) -> void:
	if not opened:pause_button.visible=_can_open()

func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			adjusting_volume=false
			if eat_opening_release:
				eat_opening_release=false;get_viewport().set_input_as_handled()
		elif not opened and pause_button.visible and pause_button.get_global_rect().has_point(event.position):
			open_menu();eat_opening_release=opened;get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if opened:get_tree().paused=false
