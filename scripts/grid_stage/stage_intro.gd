extends CanvasLayer
var world:GridStageWorld
var panel:Control
var title_group:Control
var dock_progress:=0.0
var docked:=false
var story_chapter:=false
var title:Label
var chapter:Label
var line:ColorRect
var elapsed:=0.0
var fading:=false
var fade_time:=0.0
var waiting_for_hand:=false
var backdrop:ShaderMaterial
var wash:TextureRect
var brush:Sprite2D
const WRITE_END:=2.15
const HOLD_SECONDS:=2.0
const FADE_SECONDS:=.9
const DOCK_SCALE:=.65
var brush_scale:=1.0
var brush_played:=false
var brush_finished:=false
func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;layer=6
	panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	title_group=Control.new();title_group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_group)
	wash=TextureRect.new();wash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	wash.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var source:Texture2D=load("res://art/minhwa/title_brush/stroke.png")
	var crop:=AtlasTexture.new();crop.atlas=source
	crop.region=Rect2(0,source.get_height()*.26,source.get_width(),source.get_height()*.46)
	wash.texture=ImageTexture.create_from_image(crop.get_image())
	backdrop=ShaderMaterial.new();backdrop.shader=preload("res://shaders/grid_title_brush.gdshader")
	wash.material=backdrop;title_group.add_child(wash)
	var traditional:Font=preload("res://scripts/grid_stage/traditional_font.gd").create()
	title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.add_theme_font_override("font",traditional)
	title.add_theme_color_override("font_color",Color("f0e6cf"))
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,.8));title.add_theme_constant_override("shadow_offset_y",3)
	title_group.add_child(title)
	chapter=Label.new();chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	chapter.mouse_filter=Control.MOUSE_FILTER_IGNORE;chapter.add_theme_font_override("font",traditional)
	chapter.add_theme_color_override("font_color",Color.BLACK);title_group.add_child(chapter)
	line=ColorRect.new();line.color=Color("bca575");line.mouse_filter=Control.MOUSE_FILTER_IGNORE;title_group.add_child(line)
	brush=Sprite2D.new();brush.texture=load("res://art/minhwa/bodhisattva_hands/right_brush_wide.png")
	brush.offset=Vector2(brush.texture.get_width()*.5-71,brush.texture.get_height()*.5-712)
	panel.add_child(brush)
	panel.resized.connect(_layout)
	_layout()
func begin(number:int,carried:bool) -> void:
	brush_played=false;brush_finished=false
	elapsed=0;fade_time=0;fading=false;waiting_for_hand=carried
	dock_progress=0;docked=false;story_chapter=number>3
	title_group.position=Vector2.ZERO;title_group.scale=Vector2.ONE
	panel.show();panel.modulate.a=1
	backdrop.set_shader_parameter("sweep",0.0)
	brush.show();brush.modulate.a=0
	title.modulate.a=0;chapter.modulate.a=0;line.modulate.a=0
	if number<=3:
		title.text="첫걸음";chapter.text="서장 · %d"%number
	else:
		var name_:String=preload("res://scripts/grid_stage/lotus_stages.gd").story_title(number-3)
		title.text=name_ if not name_.is_empty() else "스테이지 %d"%(number-3)
		chapter.text="제 %d장"%(number-3)
	_layout()
func release_from_hand() -> void:
	if not panel.visible:return
	waiting_for_hand=false

func is_finished() -> bool:
	# Story titles remain visible in the corner after the entrance animation.
	return not waiting_for_hand and (docked if story_chapter else not panel.visible)

func _layout() -> void:
	if not is_instance_valid(title):return
	var frame:=get_viewport().get_visible_rect().size
	var scale_:float=clampf(minf(frame.x/1280.0,frame.y/720.0),.6,1.5)
	brush_scale=scale_
	wash.position=Vector2(frame.x*.5-410*scale_,frame.y/3.0-66*scale_)
	wash.size=Vector2(820*scale_,132*scale_)
	brush.scale=Vector2.ONE*.55*scale_
	title.add_theme_font_size_override("font_size",roundi(52*scale_))
	chapter.add_theme_font_size_override("font_size",roundi(19*scale_))
	title.position=Vector2(20,frame.y/3.0-40*scale_);title.size=Vector2(frame.x-40,82*scale_)
	chapter.position=Vector2(0,frame.y/3.0-57*scale_);chapter.size=Vector2(frame.x,30*scale_)
	line.position=Vector2(frame.x*.5-270*scale_,frame.y/3.0+42*scale_);line.size=Vector2(540*scale_,1)
	_apply_dock()

func _apply_dock() -> void:
	var amount:=smoothstep(0,1,dock_progress)
	var shrink:=lerpf(1.0,DOCK_SCALE,amount)
	title_group.scale=Vector2.ONE*shrink
	var destination:=Vector2(30,26)*brush_scale-wash.position*DOCK_SCALE
	title_group.position=Vector2.ZERO.lerp(destination,amount)

func _process(delta:float) -> void:
	if world==null or world.paused or not panel.visible or waiting_for_hand:return
	if docked:return
	elapsed+=delta
	if not brush_played and elapsed>=.95:
		brush_played=true;BgmPlayer.play_brush()
	var sweep:=smoothstep(.95,1.95,elapsed)
	backdrop.set_shader_parameter("sweep",sweep*1.03)
	var lift:=smoothstep(1.95,2.4,elapsed)
	brush.position=Vector2(wash.position.x+wash.size.x*sweep,get_viewport().get_visible_rect().size.y/3.0+sin(sweep*PI)*3*brush_scale-lift*45*brush_scale)
	brush.position+=Vector2(100,-160)*brush_scale*(1-smoothstep(0,.95,elapsed))
	brush.rotation=lerpf(-.045,.025,sweep)-lift*.10
	brush.modulate.a=smoothstep(0,.40,elapsed)*(1-lift)
	brush.visible=elapsed<2.4
	if not brush_finished and elapsed>=WRITE_END:
		brush_finished=true;BgmPlayer.fade_out_brush()
	var reveal:=smoothstep(1.8,WRITE_END,elapsed)
	title.modulate.a=reveal;chapter.modulate.a=reveal;line.modulate.a=reveal*.45
	if not waiting_for_hand and not fading and elapsed>=WRITE_END+HOLD_SECONDS:
		fading=true;fade_time=0
	if fading:
		fade_time+=delta
		if story_chapter:
			dock_progress=clampf(fade_time/FADE_SECONDS,0,1);_apply_dock()
			if dock_progress>=1:docked=true
		else:
			panel.modulate.a=1-smoothstep(0,1,fade_time/FADE_SECONDS)
			if fade_time>=FADE_SECONDS:panel.hide()
	else:panel.modulate.a=1
