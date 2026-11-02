extends Sprite3D
# Separate seated idle and existing gallop art, normalized to the same height.
var frames:Array[Texture2D]=[]
var frame_offsets:Array[Vector2]=[]
var clock:=0.0
var frame_index:=0
var world:GridStageWorld
var bounds:Rect2i
var animation:="idle"
var animations:Dictionary={}
var animation_offsets:Dictionary={}
var animation_sizes:Dictionary={}

func configure(owner_world:GridStageWorld,path:String,height:float,foot:Vector3,phase:=0.0) -> void:
	world=owner_world;clock=phase
	var sheet:Texture2D=load(path)
	var cell:=Vector2i(sheet.get_width()/4,sheet.get_height()/2)
	var image:=sheet.get_image()
	if image.is_compressed():image.decompress()
	var region_map:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/minhwa/stage5_rework/frame-regions.json"))
	var regions:Array=region_map[path.get_file()]
	for row:int in range(2):
		var textures:Array[Texture2D]=[]
		var offsets:Array[Vector2]=[]
		for column:int in range(4):
			var coordinates:Array=regions[row*4+column]
			var rect:=Rect2i(int(coordinates[0]),int(coordinates[1]),int(coordinates[2]),int(coordinates[3]))
			var frame_image:=image.get_region(rect)
			var used:=frame_image.get_used_rect()
			if row==0:bounds=used if column==0 else bounds.merge(used)
			textures.append(ImageTexture.create_from_image(frame_image))
			offsets.append(Vector2(rect.size.x*.5-used.get_center().x,used.end.y-rect.size.y*.5))
		var key:String="idle" if row==0 else "chase"
		animations[key]=textures;animation_offsets[key]=offsets
	frames=animations.idle;frame_offsets=animation_offsets.idle
	pixel_size=height/maxf(1,bounds.size.y)
	animation_sizes={"idle":pixel_size,"chase":pixel_size}
	_install_seated(path.replace("_joseon.png","_sitting.png"),height)
	frames=animations.idle;frame_offsets=animation_offsets.idle;pixel_size=animation_sizes.idle
	offset=Vector2(cell.x*.5-bounds.get_center().x,bounds.end.y-cell.y*.5)
	position=foot;global_basis=world.camera.global_basis
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("paper_foreground",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
	ink.render_priority=125;material_override=ink
	_set_frame(0)

func _install_seated(path:String,height:float) -> void:
	var sheet:Texture2D=load(path)
	var image:=sheet.get_image()
	if image.is_compressed():image.decompress()
	var cell:=Vector2i(image.get_size())/2
	var textures:Array[Texture2D]=[];var offsets:Array[Vector2]=[]
	var maximum_height:=0
	for index:int in range(4):
		var frame:=image.get_region(Rect2i(Vector2i(index%2,index/2)*cell,cell))
		var used:=frame.get_used_rect();maximum_height=maxi(maximum_height,used.size.y)
		textures.append(ImageTexture.create_from_image(frame))
		offsets.append(Vector2(cell.x*.5-used.get_center().x,used.end.y-cell.y*.5))
	animations.idle=textures;animation_offsets.idle=offsets
	animation_sizes.idle=height/maxf(1,maximum_height)

func play_animation(next:String) -> void:
	if animation==next:return
	animation=next;frames=animations[next];frame_offsets=animation_offsets[next]
	pixel_size=animation_sizes[next]
	clock=0;_set_frame(0)

func _set_frame(index:int) -> void:
	frame_index=index;texture=frames[index]
	offset=frame_offsets[index]
	material_override.set_shader_parameter("illustration",texture)

func _process(delta:float) -> void:
	if world==null or world.paused or world.transition.active:return
	clock+=delta
	var index:=int(floor(clock*(10.0 if animation=="chase" else 3.0)))%4
	if index!=frame_index:_set_frame(index)
