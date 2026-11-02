extends RefCounted
## Reviewed opaque regions, not equal cells: generated sheets have uneven spacing.
const ROOT := "res://art/stage7/minhwa/"
const OBJECTS := {
	"house": Rect2i(16,52,465,326), "ruins": Rect2i(482,91,491,295),
	"gourd": Rect2i(1015,24,251,371), "shells": Rect2i(1387,103,356,266),
	"hat": Rect2i(38,467,403,390), "bridge": Rect2i(567,442,261,420),
	"poor": Rect2i(1049,416,197,455), "nolbu": Rect2i(1435,403,265,465)}
const PEOPLE := {"noble":Rect2i(161,8,160,419), "hatted":Rect2i(576,0,157,433), "prone":Rect2i(945,25,323,410)}
const RUN := [Rect2i(15,468,369,378),Rect2i(410,463,332,381),Rect2i(758,459,323,343),Rect2i(1087,478,329,368),Rect2i(1420,461,343,400)]
const GOBLIN := [Rect2i(30,168,371,477),Rect2i(406,170,348,486),Rect2i(778,175,362,473),Rect2i(1158,170,411,430),Rect2i(1578,178,359,479)]
const BIRDS := [
	[Rect2i(42,25,278,263),Rect2i(359,119,275,174),Rect2i(670,163,283,179),Rect2i(1028,94,271,205),Rect2i(1331,26,260,276)],
	[Rect2i(42,339,279,261),Rect2i(358,433,276,176),Rect2i(670,476,284,180),Rect2i(1028,407,272,208),Rect2i(1331,339,260,274)],
	[Rect2i(42,648,278,268),Rect2i(358,744,276,173),Rect2i(670,786,283,172),Rect2i(1027,718,272,213),Rect2i(1331,649,260,273)]]
const BEAK_Y := [[184,184,184,185,184],[498,498,498,498,499],[808,808,808,809,810]]
const DUNG := [Rect2i(83,119,256,227),Rect2i(456,106,345,238),Rect2i(877,199,339,143)]
const FLIES := [Rect2i(49,569,324,207),Rect2i(503,522,280,260),Rect2i(919,497,278,289)]
static var images:Dictionary={}
static var textures:Dictionary={}
static var animations:Dictionary={}
static var stem_anchors:Dictionary={}

static func style_goblin(actor:AnimatedSprite3D,foreground:bool=false) -> void:
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/heungbu_goblin_outline.gdshader")
	if foreground:
		# Chase actors retain their red outline and rotation in the final map pass.
		ink.shader=preload("res://shaders/heungbu_chase_foreground.gdshader")
		ink.render_priority=127
		actor.set_meta("paper_foreground",true)
		actor.set_meta("paper_foreground_original",true)
		actor.no_depth_test=true;actor.render_priority=127;actor.sorting_offset=1000
	actor.material_override=ink
	var refresh:=func():
		if actor.sprite_frames.has_animation(actor.animation):
			ink.set_shader_parameter("illustration",actor.sprite_frames.get_frame_texture(actor.animation,actor.frame))
	actor.frame_changed.connect(refresh);actor.animation_changed.connect(refresh)
	refresh.call()

static func house_stage(stage:int) -> Texture2D:
	var index:int=clampi(stage,0,4)
	var key:="house_stage%d"%index
	if textures.has(key):return textures[key]
	# Full-resolution frames retain their shared canvas and stone foundation.
	# Do not reduce to atlas cells or fit the shrinking rubble silhouette.
	var original:=image_file("house_hd_%d"%index)
	var canvas:=original.get_region(Rect2i(Vector2i.ZERO,original.get_size()))
	canvas.generate_mipmaps()
	textures[key]=ImageTexture.create_from_image(canvas)
	return textures[key]

static func demolition_frames(variant:int=0) -> SpriteFrames:
	var key:="demolition%d"%variant
	if animations.has(key):return animations[key]
	var result:=SpriteFrames.new();result.remove_animation("default")
	for action:String in ["fly","smash"]:
		result.add_animation(action);result.set_animation_speed(action,8)
		var row:int=clampi(variant,0,3)*2+(1 if action=="smash" else 0)
		for frame:int in 4:
			result.add_frame(action,crop("dokkaebi_demolition",Rect2i(frame*256,row*192,256,192)))
	animations[key]=result
	return result

static func junk(index:int) -> Texture2D:
	# Separate opaque object bounds in the reviewed generated atlas.
	var regions:=[Rect2i(48,0,378,724),Rect2i(494,0,362,724),Rect2i(948,0,318,724),Rect2i(1348,0,490,724),Rect2i(1938,0,152,724)]
	var region:Rect2i=regions[clampi(index,0,4)]
	var used:=image_file("house_junk").get_region(region).get_used_rect()
	return crop("house_junk",Rect2i(region.position+used.position,used.size))

static func stem_anchor(texture:Texture2D) -> Vector2:
	var key:=texture.get_instance_id()
	if stem_anchors.has(key):return stem_anchors[key]
	var image:=texture.get_image()
	if image.is_compressed():image.decompress()
	for y:int in image.get_height():
		var sum:=0.0;var count:=0
		for x:int in image.get_width():
			if image.get_pixel(x,y).a>.5:sum+=x;count+=1
		if count>0:
			var anchor:=Vector2(sum/count-image.get_width()*.5,image.get_height()*.5-y-2)
			stem_anchors[key]=anchor;return anchor
	return Vector2.ZERO

static func image_file(file:String) -> Image:
	if not images.has(file):
		var path:=ROOT+file+".png"
		var texture:Texture2D=load(path) if ResourceLoader.exists(path) else null
		var image:Image=texture.get_image() if texture else Image.load_from_file(path)
		if image.is_compressed():image.decompress()
		images[file]=image
	return images[file]

static func crop(file:String,rect:Rect2i) -> Texture2D:
	var key:=file+str(rect)
	if not textures.has(key):textures[key]=ImageTexture.create_from_image(image_file(file).get_region(rect))
	return textures[key]

static func texture(key:String) -> Texture2D:
	if key=="rotten":return crop("rotten_gourd",image_file("rotten_gourd").get_used_rect())
	if key=="gourd":return crop("round_gourd",Rect2i(312,45,784,1113))
	if key=="house":return house_stage(0)
	if key=="ruins":return house_stage(4)
	if OBJECTS.has(key):return crop("objects",OBJECTS[key])
	if PEOPLE.has(key):return crop("people",PEOPLE[key])
	if key=="sticker":return crop("effects",Rect2i(30,960,370,175))
	return crop("effects",DUNG[int(key.trim_prefix("dung"))])

static func frames(kind:String,variant:int=0) -> SpriteFrames:
	var key:=kind+str(variant)
	if animations.has(key):return animations[key]
	var regions:Array=GOBLIN if kind=="goblin" else RUN
	var file:="dokkaebi" if kind=="goblin" else "people"
	if kind=="bird":regions=BIRDS[variant];file="swallows"
	if kind=="fly":regions=FLIES;file="effects"
	var result:=SpriteFrames.new();result.set_animation_speed("default",16 if kind=="fly" else 8)
	for index:int in regions.size():
		var region:Rect2i=regions[index]
		var tile:=image_file(file).get_region(region)
		var canvas:=Image.create(640,640,false,Image.FORMAT_RGBA8)
		var anchor:=Vector2i(region.size.x/2,region.size.y)
		var target:=Vector2i(320,600)
		if kind=="bird":anchor=Vector2i(region.size.x-1,int(BEAK_Y[variant][index])-region.position.y);target=Vector2i(500,320)
		if kind=="fly":anchor=Vector2i(region.size.x-1,680-region.position.y);target=Vector2i(480,320)
		canvas.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),target-anchor)
		result.add_frame("default",ImageTexture.create_from_image(canvas))
	animations[key]=result
	return result
