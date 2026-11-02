extends Panel
signal dismissed
var speaker:Label
var body:Label
var portrait:TextureRect
var continue_hint:Label
var blocked:=false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("fff3db")
	paper.set_border_width_all(2);paper.border_color=Color("8e714b")
	paper.shadow_color=Color(0.16,.12,.08,.25);paper.shadow_size=8;paper.shadow_offset=Vector2(0,3)
	add_theme_stylebox_override("panel",paper)
	var font:Font=preload("res://art/fonts/HS-Winter-Snowflake.ttf")
	speaker=Label.new();body=Label.new();continue_hint=Label.new()
	for label in [speaker,body,continue_hint]:
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_override("font",font)
		label.add_theme_color_override("font_color",Color("3d3022"));add_child(label)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	continue_hint.text="클릭 / E / Enter로 계속"
	continue_hint.add_theme_color_override("font_color",Color("7c674b"))
	portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(portrait)
	get_viewport().size_changed.connect(_layout);hide();_layout()
func present(name_:String,line:String,art:Texture2D) -> void:
	speaker.text=name_;body.text=line;portrait.texture=art;show();_layout()
func close() -> void:
	if not visible:return
	hide();dismissed.emit()
func handle_event(event:InputEvent) -> bool:
	if not is_visible_in_tree() or blocked:return false
	var advance:bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventKey and event.pressed and not event.echo:
		advance=event.physical_keycode in [KEY_E,KEY_ENTER,KEY_KP_ENTER] or event.keycode in [KEY_E,KEY_ENTER,KEY_KP_ENTER]
	if not advance:return false
	close();return true
func _input(event:InputEvent) -> void:
	if handle_event(event):get_viewport().set_input_as_handled()
func _layout() -> void:
	if not is_instance_valid(body):return
	var frame:=get_viewport().get_visible_rect().size
	var height:=clampf(frame.y*.30,180,260)
	position=Vector2(24,frame.y-height-20);size=Vector2(maxf(300,frame.x-48),height)
	var portrait_width:=clampf(size.x*.22,140,260)
	var text_width:=size.x-portrait_width-68
	var scale_factor:=frame.x/1280.0
	speaker.add_theme_font_size_override("font_size",clampi(roundi(28*scale_factor),24,34))
	body.add_theme_font_size_override("font_size",clampi(roundi(32*scale_factor),26,38))
	continue_hint.add_theme_font_size_override("font_size",clampi(roundi(17*scale_factor),14,20))
	speaker.position=Vector2(24,14);speaker.size=Vector2(text_width,42)
	body.position=Vector2(24,58);body.size=Vector2(text_width,height-100)
	continue_hint.position=Vector2(24,height-30);continue_hint.size=Vector2(text_width,24)
	portrait.position=Vector2(size.x-portrait_width-16,10);portrait.size=Vector2(portrait_width,height-20)
