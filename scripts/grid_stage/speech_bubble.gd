extends Panel
signal dismissed
const PAPER_UI = preload("res://scripts/grid_stage/stretch_speech_paper.gd")
var body:Label
var blocked:=false
var automatic:=true
var elapsed:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	size=Vector2(320,110)
	var paper:=PAPER_UI.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.modulate.a=.82;paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(paper)
	body=Label.new();body.add_theme_font_override("font",preload("res://art/fonts/HS-Winter-Snowflake.ttf"))
	body.add_theme_font_size_override("font_size",19);body.add_theme_color_override("font_color",Color("393d31"))
	body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	body.position=Vector2(32,10);body.size=Vector2(256,65)
	body.autowrap_mode=TextServer.AUTOWRAP_OFF;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(body)
	body.minimum_size_changed.connect(fit_to_text)
	fit_to_text()
	hide()
func fit_to_text() -> void:
	PAPER_UI.fit(self,body,Vector2(320,110))

func present(_speaker:String,line:String,_portrait:Texture2D=null) -> void:
	body.text=line;fit_to_text();elapsed=0;modulate.a=0;show()
func close() -> void:
	if not visible:return
	hide();dismissed.emit()
func handle_event(_event:InputEvent) -> bool:
	return false
func place(head:Vector2) -> void:
	var frame:=get_viewport().get_visible_rect().size
	position=head-Vector2(size.x*.5,size.y+minf(elapsed/.25,1)*5)
	position.x=clampf(position.x,8,maxf(8,frame.x-size.x-8));position.y=maxf(8,position.y)
func _process(delta:float) -> void:
	if not automatic or blocked or not visible:return
	elapsed+=delta
	modulate.a=minf(elapsed/.18,1.0)*(1.0-clampf((elapsed-3.0)/.8,0,1))
	if elapsed>=3.8:close()
