extends Node2D
# The page contains an actual composite of the game's twelve render bands.
# A segmented, curved sheet carries that image through a right-to-left turn.
const BOOK=preload("res://art/minhwa/storybook/open_book_unframed.png")
const FONT=preload("res://art/fonts/HS-Winter-Snowflake.ttf")
const INK_DROP=preload("res://art/minhwa/storybook/ink_drop.png")
const LEFT_HAND=preload("res://art/minhwa/storybook/left_page_hand.png")
const BRUSH=preload("res://art/minhwa/storybook/writing_hand_reference.png")
const CLIP_MASK=preload("res://art/minhwa/storybook/ink_clip_mask.png")
const LINE_DIVIDER=preload("res://art/minhwa/storybook/ink_line_divider.png")
const EMPEROR_SEAL=preload("res://art/minhwa/storybook/emperor_seal.png")
const STAMP_HAND=preload("res://art/minhwa/storybook/emperor_stamp_hand.png")
# Picture and stamp sequences each take 2 seconds before the page turn.
const STAMP_APPROACH_SECONDS:=.5
const STAMP_PRESS_SECONDS:=.2
const STAMP_RETREAT_SECONDS:=.4
const STAMP_HOLD_SECONDS:=.9
const WRITE_SECONDS:=3.0
const SWEEP_SECONDS:=1.5
const PARAGRAPHS:=["연꽃 사이로 이어진 길을 지나,","나그네는 또 하나의 이야기를 남겼다.","","물결은 지나온 발자국을 품고,","바람은 다음 장의 문을 열었다.","","아직 만나지 못한 인연을 찾아","이제 새로운 길로 걸음을 옮긴다."]
const CHAPTER_PARAGRAPHS:={
	"1장 단오": [
		"옥황의 뜻 좇아 **인세**에 드니,",
		"**단옷날** 냇가에 창포 향 짙구나.",
		"그넷줄은 푸른 하늘 오르내리고,",
		"고운 옷자락마다 웃음 어리었네.",
		"비늘 벗은 몸으로 물가에 앉으니,",
		"구름 위의 일이 잠시 아득하더라."],
	"2장 선녀와 나무꾼": [
		"깊은 산 맑은 못에 달빛 들고,",
		"**날개옷** 잃은 이 한숨도 깊더라.",
		"옷을 감춘들 **마음**도 머무르랴.",
		"내 하늘길 막혔다 그리 설워하며,",
		"남의 날갯짓은 헤아리지 못했네.",
		"빈 바위 앞에서 오래 **부끄러웠네**."],
	"3장 심청전": [
		"**인당수** 푸른 물 굽어보노라니,",
		"아비 찾던 목소리 귀에 남더라.",
		"**연꽃**은 깊은 물을 헤치고 피어,",
		"어두운 두 눈에도 새날 들었네.",
		"내 오를 하늘만 멀다 여겼더니,",
		"남의 밤 밝히는 마음 더욱 깊구나."],
	"4장 빨간부채 파란부채": [
		"**붉은 부채** 부치니 코끝 솟고,",
		"**푸른 부채** 끝에는 묘한 바람 이네.",
		"부채 둘로 천하를 얻은 듯하여,",
		"높이 솟다 하늘마저 탐하였구나.",
		"용이 되려 보채던 내 모습 같아,",
		"부채를 접으며 욕심도 접었네."],
	"5장 손톱먹은 쥐": [
		"주막에 나와 닮은 이 앉았는데,",
		"내 **이름**을 제 것인 양 부르더라.",
		"버린 **손톱** 먹은 쥐라 하기에,",
		"무심히 흘린 자취 돌아보았네.",
		"비늘 벗고 사람 모습 얻은들,",
		"이 몸의 참됨은 **행실**에 있구나."],
	"6장 해와 달이 된 오누이": [
		"어미 잃은 오누이 밤길에 떨며,",
		"손 맞잡고 하늘을 우러렀네.",
		"**동아줄**에 어린 숨을 의지하더니,",
		"**해와 달**이 되어 어둠 밝혔구나.",
		"나 홀로 오를 길만 찾던 눈에,",
		"서로 놓지 않는 **두 손** 남았네."],
	"7장 흥부전": [
		"처마 밑 **제비** 다리를 다치니,",
		"가난한 손길이 상처 감싸더라.",
		"작은 **박씨** 돌아와 복을 여는데,",
		"복 탐낸 손에는 화가 들었네.",
		"상을 바라며 선을 셈하였던가.",
		"값 없이 **베푼 정**에 고개 숙였네."],
	"8장 견우와 직녀": [
		"은하수 사이 두고 **그리움** 깊어,",
		"강가에 선 두 사람 눈길 못 거두네.",
		"그 **사랑**에 까치도 마음이 움직여,",
		"날개를 맞대어 먼 물길 이었구나.",
		"마침내 맞잡은 손 오래 바라보다,",
		"내 가슴에도 따스한 물결 일었네."],
	"9장 용이 되지 못한 이무기": [
		"용 못 된 **꽝철이** 세상을 원망하니,",
		"그 성난 눈 속에 지난 내가 보이네.",
		"하늘 탓하던 마음 이제야 돌아보아,",
		"먼저 **내 마음**부터 고쳐 품으리라.",
		"내민 손끝 따라 금빛 비늘 돋으니,",
		"인세의 정을 품고 **용** 되어 오르네."],
}
const SHRINK_SECONDS:=.6
const DROP_SECONDS:=.4
const SPREAD_SECONDS:=1.0
const TURN_SECONDS:=2.0
const EXPAND_SECONDS:=1.8
var world:GridStageWorld
var state:="idle"
var clock:=0.0
var generation:=0
var destination:=0
var selection_entry:=false
var old_frame:Texture2D
var new_frame:Texture2D
var old_page:Texture2D
var new_page:Texture2D
var right_paper:Texture2D
var old_title:=""
var new_title:=""
var saved_hud:=true
var saved_intro:=true
var turn:=0.0
var brush_played:=false
var ink_reveal:TextureRect
var condensing_scene:TextureRect
var brush_tip:=Vector2.ZERO
var written_characters:=0
var view_transform:=Transform2D.IDENTITY
var divider_region:=Rect2()
var writing_text:Node2D
var writing_hand:Node2D
var stamped:=false
var page_workers:Array[Thread]=[]

func _ready() -> void:
	writing_text=Node2D.new();writing_text.z_index=1;add_child(writing_text)
	var text_ink:=ShaderMaterial.new();text_ink.shader=preload("res://shaders/book_text_ink.gdshader")
	text_ink.set_shader_parameter("ink_mask",CLIP_MASK);writing_text.material=text_ink
	writing_text.draw.connect(func():_text_page(new_title,false,1.0,1.0,writing_text))
	writing_text.hide()
	writing_hand=Node2D.new();writing_hand.z_index=2;add_child(writing_hand)
	writing_hand.draw.connect(_draw_writing_brush);writing_hand.hide()
	var divider_image:=LINE_DIVIDER.get_image()
	if divider_image.is_compressed():divider_image.decompress()
	divider_region=Rect2(divider_image.get_used_rect())
	# Ignore almost-transparent canvas pixels when framing the painted stroke.
	var bounds:=Rect2i()
	for y in range(divider_image.get_height()):
		for x in range(divider_image.get_width()):
			if divider_image.get_pixel(x,y).a>.1:
				var pixel:=Rect2i(x,y,1,1)
				bounds=pixel if not bounds.has_area() else bounds.merge(pixel)
	if bounds.has_area():divider_region=Rect2(bounds)
	ink_reveal=TextureRect.new();ink_reveal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ink_reveal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/book_ink_reveal.gdshader")
	ink.set_shader_parameter("ink_mask",CLIP_MASK)
	ink_reveal.material=ink;add_child(ink_reveal);ink_reveal.hide()
	condensing_scene=TextureRect.new();condensing_scene.mouse_filter=Control.MOUSE_FILTER_IGNORE
	condensing_scene.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var compression:=ShaderMaterial.new();compression.shader=preload("res://shaders/book_scene_condense.gdshader")
	compression.set_shader_parameter("ink_mask",CLIP_MASK)
	condensing_scene.material=compression;add_child(condensing_scene);condensing_scene.hide()

func _sync_condense() -> void:
	condensing_scene.visible=state=="shrink"
	if not condensing_scene.visible:return
	var full:=get_viewport_rect()
	var t:=smoothstep(0,1,clock/SHRINK_SECONDS)
	var hover:=_left_rect().get_center()-Vector2(0,full.size.y*.23)
	var size:=full.size.lerp(Vector2(92,108)*full.size.y/720.0,t)
	condensing_scene.texture=old_frame;condensing_scene.size=size
	condensing_scene.position=full.get_center().lerp(hover,t)-size*.5
	condensing_scene.material.set_shader_parameter("progress",t)

func _input(event:InputEvent) -> void:
	if state=="idle":return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		request_turn()

func request_turn() -> bool:
	if world.paused:return false
	if stamped and state in ["stamp_press","stamp_retreat","stamp_hold"]:
		_start_next_chapter()
		return true
	if state=="read":
		BgmPlayer.play_stage_start()
		state="expand";clock=0;queue_redraw()
		return true
	return false

func _start_next_chapter() -> void:
	# Change state before asynchronous loading so repeated clicks cannot reload.
	state="load_next";clock=0;queue_redraw()
	_prepare_next(generation)

func begin(owner_world:GridStageWorld,next_stage:int,from_selection:bool=false) -> void:
	selection_entry=from_selection
	brush_played=false
	stamped=false
	world=owner_world;destination=next_stage;generation+=1
	saved_hud=world.hud.visible;saved_intro=world.stage_intro.visible
	world.hud.hide();world.stage_intro.hide()
	old_title=_chapter_title();new_title=""
	state="capture_old";clock=0;turn=0
	# Cover the selected map while its slice cameras prepare the page image.
	visible=selection_entry
	queue_redraw()
	_prepare_old(generation)

func _frame() -> Image:
	var dimensions:=Vector2i(world.get_viewport().get_visible_rect().size)
	var result:=Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	result.fill(world.stage_environment.background_color)
	if DisplayServer.get_name()=="headless":return result
	for child in world.stage_root.get_children():
		if child.get_script()!=preload("res://scripts/grid_stage/screen_slices.gd"):continue
		for index in range(child.BAND_COUNT):
			var layer:Image=child.views[index].get_texture().get_image()
			if layer==null or layer.is_empty():continue
			layer.convert(Image.FORMAT_RGBA8)
			if layer.get_size()!=dimensions:layer.resize(dimensions.x,dimensions.y)
			result.blend_rect(layer,Rect2i(Vector2i.ZERO,dimensions),Vector2i.ZERO)
	return result

func _page(frame:Image,ticket:int) -> Texture2D:
	# Texture readback/upload stays on the main thread; the pixel loop does not.
	var paper:=BOOK.get_image()
	var worker:=Thread.new()
	var compose:=preload("res://scripts/grid_stage/book_page_image.gd").compose.bind(frame,paper)
	var error:=worker.start(compose)
	var page:Image
	if error==OK:
		page_workers.append(worker)
		while worker.is_alive():
			await get_tree().process_frame
		page=worker.wait_to_finish()
		page_workers.erase(worker)
	else:
		push_warning("Book page worker unavailable: %s"%error_string(error))
		page=compose.call()
	# Restart or Back may invalidate the capture while the worker is running.
	if ticket!=generation or state=="idle":return null
	return ImageTexture.create_from_image(page)

func _exit_tree() -> void:
	generation+=1
	for worker in page_workers:
		worker.wait_to_finish()
	page_workers.clear()

func _prepare_old(ticket:int) -> void:
	# Initial selection needs two frames for slice cameras to register the map.
	if selection_entry:
		await get_tree().process_frame
		if ticket!=generation or state=="idle":return
		await get_tree().process_frame
		if ticket!=generation or state=="idle":return
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	if ticket!=generation or state=="idle":return
	var paper:=BOOK.get_image()
	if paper.is_compressed():paper.decompress()
	right_paper=ImageTexture.create_from_image(paper.get_region(Rect2i(int(paper.get_width()*.5),int(paper.get_height()*.08),int(paper.get_width()*.45),int(paper.get_height()*.82))))
	var frame:=_frame()
	var page:=await _page(frame,ticket)
	if ticket!=generation or state=="idle":return
	old_frame=ImageTexture.create_from_image(frame);old_page=page
	if selection_entry:
		# A selected chapter opens with its illustration already on the paper.
		new_frame=old_frame;new_page=old_page;new_title=old_title;turn=1
		state="write"
	else:
		state="shrink"
	clock=0;show();tick(0);queue_redraw()

func _prepare_next(ticket:int) -> void:
	world.load_stage(destination,true)
	world.player.input_locked=true;world.player.sprite.hide()
	world.stage_intro.hide();world.hud.hide()
	new_title=_chapter_title()
	# Let all slice cameras register the new geometry and render before sampling.
	await get_tree().process_frame
	if ticket!=generation or state=="idle":return
	await get_tree().process_frame
	if ticket!=generation or state=="idle":return
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	if ticket!=generation or state=="idle":return
	var frame:=_frame()
	var page:=await _page(frame,ticket)
	if ticket!=generation or state=="idle":return
	new_frame=ImageTexture.create_from_image(frame);new_page=page
	state="turn";clock=0;queue_redraw()
	BgmPlayer.play_page_turn()

func cancel() -> void:
	writing_text.hide();writing_hand.hide()
	stamped=false
	generation+=1;state="idle";hide()
	ink_reveal.hide()
	condensing_scene.hide()
	if is_instance_valid(world):
		world.hud.visible=saved_hud;world.stage_intro.visible=saved_intro
	old_frame=null;new_frame=null;old_page=null;new_page=null

func tick(delta:float) -> void:
	if state=="idle" or world.paused:return
	clock+=delta
	match state:
		"shrink":
			if clock>=SHRINK_SECONDS:state="drop";clock=0
		"drop":
			if clock>=DROP_SECONDS:state="spread";clock=0
		"spread":
			if clock>=SPREAD_SECONDS:
				clock=0
				if selection_entry:
					new_frame=old_frame;new_page=old_page;new_title=old_title;turn=1
					state="write"
				else:
					state="stamp_approach"
		"turn":
			turn=smoothstep(0,1,clock/TURN_SECONDS)
			if clock>=TURN_SECONDS:state="settle";clock=0
		"settle":
			if clock>=.65:state="write";clock=0
		"write":
			if clock>=WRITE_SECONDS:
				BgmPlayer.fade_out_brush()
				state="read";clock=0
		"stamp_approach":
			if clock>=STAMP_APPROACH_SECONDS:
				stamped=true;state="stamp_press";clock=0
		"stamp_press":
			if clock>=STAMP_PRESS_SECONDS:state="stamp_retreat";clock=0
		"stamp_retreat":
			if clock>=STAMP_RETREAT_SECONDS:state="stamp_hold";clock=0
		"stamp_hold":
			if clock>=STAMP_HOLD_SECONDS:
				_start_next_chapter()
		"expand":
			if clock>=EXPAND_SECONDS:
				cancel();world.stage_intro.show();world.transition.start_entry();return
	ink_reveal.visible=state=="spread"
	writing_text.visible=state=="write";writing_hand.visible=state=="write"
	if state=="write":
		if not brush_played and clock>=.12:
			brush_played=true;BgmPlayer.play_brush()
		var text_page:=_page_rect()
		writing_text.material.set_shader_parameter("page_rect",Vector4(text_page.position.x,text_page.position.y,text_page.size.x,text_page.size.y))
		writing_text.material.set_shader_parameter("progress",clampf(clock/2.9,0,1))
		writing_text.queue_redraw();writing_hand.queue_redraw()
	_sync_condense()
	if ink_reveal.visible:
		var page:=_left_rect()
		ink_reveal.position=page.position;ink_reveal.size=page.size;ink_reveal.texture=old_page
		ink_reveal.material.set_shader_parameter("progress",clampf(clock/SPREAD_SECONDS,0,1))
		ink_reveal.material.set_shader_parameter("aspect",page.size.x/page.size.y)
	queue_redraw()

func _page_rect() -> Rect2:
	var size:=get_viewport_rect().size
	return Rect2(size*Vector2(.5,.08),size*Vector2(.45,.82))

func _art_rect() -> Rect2:
	var page:=_left_rect()
	return Rect2(page.position+page.size*Vector2(.03,.025),page.size*Vector2(.94,.95))

func _crop_rect(texture:Texture2D) -> Rect2:
	var source:=texture.get_size()
	var aspect:float=old_page.get_width()*.94/(old_page.get_height()*.95)
	var cropped:=Vector2(source.y*aspect,source.y)
	if cropped.x>source.x:cropped=Vector2(source.x,source.x/aspect)
	return Rect2((source-cropped)*.5,cropped)
func _point(u:float,v:float,amount:float) -> Vector2:
	var page:=_page_rect()
	var theta:=amount*PI
	var bend:=sin(u*PI)*sin(theta)*.16
	var x:=page.position.x+page.size.x*(u*cos(theta)+bend)
	var lift:=sin(theta)*(u*.11+sin(u*PI)*.07)
	var y:=page.position.y+page.size.y*(v+(v-.5)*lift)
	return Vector2(x,y)

func _chapter_title() -> String:
	return "서장 · %d"%world.stage_number if world.stage_number<=3 else "%d장 %s"%[world.stage_number-3,world.stage_data.get("story_title","연꽃의 길")]

func _left_rect() -> Rect2:
	var size:=get_viewport_rect().size
	return Rect2(size*Vector2(.05,.08),size*Vector2(.45,.82))

func _text_lines(title:String) -> Array[Dictionary]:
	var page:=_page_rect()
	var title_size:=maxi(18,int(get_viewport_rect().size.y*.033))
	var body_size:=maxi(16,int(title_size*.83))
	while title_size>12 and title.length()*title_size*1.2>page.size.y*.74:title_size-=1
	var lines:Array[Dictionary]=[{"text":title,"position":page.size*Vector2(.09,.13),"size":title_size,"title":true}]
	var column:=0
	for paragraph:String in CHAPTER_PARAGRAPHS.get(title,PARAGRAPHS):
		if paragraph.is_empty():continue
		var units:=0.0
		for character in paragraph.replace("**",""):units+=.55 if character==" " else 1.2
		var fitted_size:=mini(body_size,int(page.size.y*.62/maxf(1,units)))
		lines.append({"text":paragraph,"position":page.size*Vector2(.23+column*.12,.13),"size":fitted_size,"title":false})
		column+=1
	return lines

func _text_glyphs(title:String) -> Array[Dictionary]:
	var glyphs:Array[Dictionary]=[]
	for line:Dictionary in _text_lines(title):
		var text:String=line.text
		var y:=0.0
		var emphasized:=false
		var i:=0
		while i<text.length():
			if text.substr(i,2)=="**":
				emphasized=not emphasized;i+=2;continue
			glyphs.append({"char":text[i],"position":line.position+Vector2(0,y),"size":line.size,"title":line.title,"emphasized":emphasized})
			y+=line.size*(.55 if text[i]==" " else 1.2)
			i+=1
	return glyphs

func _text_page(title:String,turning:bool=false,writing:float=1.0,opacity:float=1.0,canvas:Node2D=null) -> void:
	if canvas==null:canvas=self
	var page:=_page_rect()
	var origin:=page.position
	var scale_:=Vector2.ONE
	if turning:
		origin=_point(0,0,turn)
		scale_=Vector2(maxf(.001,cos(turn*PI)),1+sin(turn*PI)*.1)
	var text_transform:=view_transform*Transform2D(0,scale_,0,origin)
	canvas.draw_set_transform_matrix(text_transform)
	var lines:=_text_lines(title)
	for i in range(lines.size()-1):
		var upper:Dictionary=lines[i]
		var lower:Dictionary=lines[i+1]
		var x:float=(upper.position.x+upper.size+lower.position.x)*.5
		canvas.draw_set_transform_matrix(text_transform*Transform2D(PI*.5,Vector2(x,page.size.y*.12)))
		canvas.draw_texture_rect_region(LINE_DIVIDER,Rect2(0,0,page.size.y*.64,maxf(2,page.size.x*.004)),divider_region,Color(1,1,1,opacity*.6))
	canvas.draw_set_transform_matrix(text_transform)
	var glyphs:=_text_glyphs(title)
	var budget:=clampf(writing,0,1)*glyphs.size()
	written_characters=int(budget)
	for i in range(mini(int(budget),glyphs.size())):
		var glyph:Dictionary=glyphs[i]
		var color:=Color("b52b26") if glyph.emphasized else (Color("514333") if glyph.title else Color("74624b"));color.a=opacity
		canvas.draw_string(FONT,glyph.position+Vector2(0,glyph.size),glyph.char,HORIZONTAL_ALIGNMENT_LEFT,-1,glyph.size,color)
	var current:Dictionary=glyphs[mini(int(budget),glyphs.size()-1)]
	# Upright glyphs flow downward; sentence columns advance left to right.
	brush_tip=origin+current.position+Vector2(sin(budget*TAU)*2,current.size*(.25+.75*fmod(budget,1)))
	canvas.draw_set_transform_matrix(view_transform)

func _draw_turning_page() -> void:
	var reverse:=turn>.5
	for i in range(64):
		var u0:=i/64.0;var u1:=(i+1)/64.0
		var points:=PackedVector2Array([_point(u0,0,turn),_point(u1,0,turn),_point(u1,1,turn),_point(u0,1,turn)])
		var uv:=PackedVector2Array([Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)])
		var shade:=1.0-sin(turn*PI)*(.12+.24*sin(u0*PI))
		if reverse:
			uv=PackedVector2Array([Vector2(1-u0,0),Vector2(1-u1,0),Vector2(1-u1,1),Vector2(1-u0,1)])
		draw_polygon(points,PackedColorArray([Color(shade,shade,shade,1)]),uv,new_page if reverse else right_paper)
	if not reverse:
		_text_page(old_title,true)
		_draw_seal(true)
	var edge:=PackedVector2Array()
	for v in range(25):edge.append(_point(1,v/24.0,turn))
	draw_polyline(edge,Color(.81,.69,.47,.9),1.5,true)

func _draw_page_hand() -> void:
	if state not in ["turn","settle"]:return
	var full:=get_viewport_rect().size
	var contact:=_point(1,.72,turn)
	var alpha:=1.0
	if state=="turn" and clock<0:
		contact=Vector2(full.x+300,full.y+320).lerp(contact,smoothstep(-.65,0,clock))
	elif state=="settle":
		var retreat:=smoothstep(0,.65,clock)
		contact=contact.lerp(Vector2(-200,full.y+300),retreat);alpha=1-retreat
	var factor:=full.y/720.0*.40
	draw_set_transform(contact,lerpf(-.55,-.45,turn),Vector2.ONE*factor)
	draw_texture(LEFT_HAND,-LEFT_HAND.get_size()*Vector2(.75,.17),Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_writing_brush() -> void:
	if state!="write":return
	var scale_:float=get_viewport_rect().size.y/720.0*.44
	brush_tip=_sweep_point(clampf(clock/SWEEP_SECONDS,0,1))
	var lift:=1-smoothstep(0,.12,clock)
	lift+=smoothstep(SWEEP_SECONDS,SWEEP_SECONDS+.3,clock)
	writing_hand.draw_set_transform(brush_tip+Vector2(18,-100)*lift,.72+sin(clock*8)*.012,Vector2.ONE*scale_)
	writing_hand.draw_texture(BRUSH,-BRUSH.get_size()*Vector2(.047,.044),Color(1,1,1,1-clampf(lift,0,1)))
	writing_hand.draw_set_transform(Vector2.ZERO)

func _sweep_point(progress:float) -> Vector2:
	var page:=_page_rect()
	var path:=[Vector2(.14,.23),Vector2(.85,.23),Vector2(.14,.46),Vector2(.85,.46),Vector2(.14,.69),Vector2(.85,.69)]
	var phase:=clampf(progress,0,1)*5
	var index:=mini(int(phase),4)
	return page.position+page.size*path[index].lerp(path[index+1],clampf(phase-index,0,1))

func _draw_droplet() -> void:
	var full:=get_viewport_rect()
	var landing:=_left_rect().get_center()
	var hover:=landing-Vector2(0,full.size.y*.23)
	var scale_:float=full.size.y/720.0
	var center:=full.get_center()
	var t:=smoothstep(0,1,clock/SHRINK_SECONDS)
	var drop_alpha:=1.0
	var stretch:=Vector2.ONE
	if state=="shrink":
		center=center.lerp(hover,t)
		drop_alpha=smoothstep(.7,1,t)
	else:
		t=clampf(clock/DROP_SECONDS,0,1)
		center=hover.lerp(landing-Vector2(0,46*scale_),t*t)
		stretch=Vector2(1-.12*sin(t*PI),1+.18*sin(t*PI))
	var drop_size:=Vector2(92,108)*scale_*stretch
	draw_texture_rect(INK_DROP,Rect2(center-drop_size*.5,drop_size),false,Color(1,1,1,drop_alpha))

func _stamp_center() -> Vector2:
	var page:=_page_rect()
	return page.position+page.size*Vector2(.83,.88)

func _stamp_size() -> float:
	return minf(_page_rect().size.x,_page_rect().size.y)*.17

func _draw_seal(turning:bool=false) -> void:
	if not stamped:return
	if turning:
		# Project the ink through the same curved sheet as the cleared chapter.
		# Subdivide both axes because the square is rotated on the page.
		var page:=_page_rect()
		var seal_transform:=Transform2D(PI/4,_stamp_center())
		for y in range(12):
			for x in range(12):
				var uv:=PackedVector2Array([Vector2(x,y)/12.0,Vector2(x+1,y)/12.0,Vector2(x+1,y+1)/12.0,Vector2(x,y+1)/12.0])
				var points:=PackedVector2Array()
				for corner in uv:
					var local:Vector2=(seal_transform*((corner-Vector2.ONE*.5)*_stamp_size())-page.position)/page.size
					points.append(_point(local.x,local.y,turn))
				draw_polygon(points,PackedColorArray([Color.WHITE]),uv,EMPEROR_SEAL)
	else:
		draw_set_transform_matrix(view_transform*Transform2D(PI/4,_stamp_center()))
		var side:=_stamp_size()
		draw_texture_rect(EMPEROR_SEAL,Rect2(Vector2.ONE*-side*.5,Vector2.ONE*side),false)
	draw_set_transform_matrix(view_transform)

func _draw_stamp() -> void:
	var contact:=_stamp_center()
	_draw_seal()
	if state in ["stamp_approach","stamp_press","stamp_retreat"]:
		var lift:=0.0
		if state=="stamp_approach":lift=1-smoothstep(0,STAMP_APPROACH_SECONDS,clock)
		elif state=="stamp_retreat":lift=smoothstep(0,STAMP_RETREAT_SECONDS,clock)
		var factor:=_stamp_size()/STAMP_HAND.get_width()*3.0
		var position:=contact+Vector2(260,-300)*(get_viewport_rect().size.y/720.0)*lift
		# The photographed base's contact center is below the dragon grip.
		draw_set_transform_matrix(view_transform*Transform2D(0,Vector2.ONE*factor*(1+.15*lift),0,position))
		draw_texture(STAMP_HAND,-STAMP_HAND.get_size()*Vector2(.35,.49),Color(1,1,1,1-smoothstep(.75,1,lift)))
	draw_set_transform_matrix(view_transform)

func _draw() -> void:
	if state=="idle":return
	var full:=get_viewport_rect()
	var zoom:=smoothstep(0,1,clock/EXPAND_SECONDS) if state=="expand" else 0.0
	draw_set_transform(Vector2.ZERO)
	draw_rect(full,Color("15363b"))
	view_transform=Transform2D.IDENTITY
	if state=="expand":
		var art:=_art_rect()
		var factor:=lerpf(1.0,full.size.x/art.size.x,zoom)
		var position:=Vector2.ZERO.lerp(full.get_center()-art.get_center()*factor,zoom)
		view_transform=Transform2D(0,Vector2.ONE*factor,0,position)
	draw_set_transform_matrix(view_transform)
	draw_texture_rect(BOOK,full,false)
	if state=="capture_old" or old_frame==null:return
	if state in ["shrink","drop","spread","stamp_approach","stamp_press","stamp_retreat","stamp_hold","load_next"]:
		if not selection_entry:_text_page(old_title)
		if state in ["stamp_approach","stamp_press","stamp_retreat","stamp_hold","load_next"]:
			draw_texture_rect(old_page,_left_rect(),false)
			_draw_stamp()
		elif state in ["shrink","drop"]:_draw_droplet()
		elif state=="spread" and clock<.3:
			draw_texture_rect(INK_DROP,Rect2(_left_rect().get_center()-Vector2(70,18)*full.size.y/720.0,Vector2(140,36)*full.size.y/720.0),false,Color(1,1,1,1-smoothstep(0,.3,clock)))
	elif new_page!=null:
		draw_texture_rect(old_page,_left_rect(),false)
		if state in ["read","expand"]:_text_page(new_title)
		_draw_turning_page()
		_draw_page_hand()
		if state=="read":
			draw_string(FONT,full.size*Vector2(.62,.84),"클릭하여 그림 속으로",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(16,int(full.size.y*.025)),Color(.39,.32,.23,.8))
		if state=="expand":
			draw_set_transform(Vector2.ZERO)
			draw_texture_rect(new_frame,full,false,Color(1,1,1,smoothstep(.35,1.0,zoom)))
