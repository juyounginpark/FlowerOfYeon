extends Node3D
# Decorative, non-colliding five-frame wildlife jumps, only created by EarthBackdrop.
var camera:Camera3D
var rng:=RandomNumberGenerator.new()
var actor:AnimatedSprite3D
var ink:ShaderMaterial
var frame_sets:Array[SpriteFrames]=[]
var textures:Array[Texture2D]=[]
var wait_time:float=1.8
var jump_time:float=-1.0
var duration:float=1.7
var episode:int=0
var anchor:=Vector2.ZERO
var direction:float=1.0
var travel:float=.15
var jump_height:float=.16
var image_height:float=.07
var actor_width:float=.06
var depth:float=66.0
var opacity:float=.7
const POSES:Array[int]=[0,1,2,3,4,3,1]
func configure(view:Camera3D,stage_number:int) -> void:
	camera=view;rng.seed=92713+stage_number*137
	for path:String in ["res://art/minhwa/wildlife/boar_jump.png","res://art/minhwa/wildlife/deer_jump.png"]:
		var texture:Texture2D=load(path)
		textures.append(texture)
		var used:Rect2i=texture.get_image().get_used_rect()
		var frames:=SpriteFrames.new();frames.add_animation("jump");frames.set_animation_loop("jump",false)
		# Authored sheet boundaries avoid the adjacent animal's antlers/tail.
		var boundaries:Array=[0,428,836,1205,1603,2048] if path.ends_with("deer_jump.png") else [0,411,813,1205,1612,2048]
		for i:int in range(5):
			var left:int=roundi(float(texture.get_width())*boundaries[i]/2048.0)
			var right:int=roundi(float(texture.get_width())*boundaries[i+1]/2048.0)
			var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.filter_clip=true
			atlas.region=Rect2(left,used.position.y,right-left,used.size.y)
			frames.add_frame("jump",atlas)
		frame_sets.append(frames)
	actor=AnimatedSprite3D.new();actor.name="RidgeWildlife"
	actor.shaded=false;actor.double_sided=true
	actor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	actor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.set_meta("screen_band",0);actor.set_meta("ridge_wildlife",true)
	ink=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_wildlife.gdshader")
	actor.material_override=ink
	add_child(actor);actor.visible=false
	wait_time+=float(stage_number-4)*.7
# Shared depth, scale and ink strength for actors placed on the earth collage.
static func perspective(anchor_y:float) -> Dictionary:
	var near:float=clampf((anchor_y-.45)/.40,0.0,1.0)
	return {"nearness":near,"width":lerpf(.040,.078,near),"opacity":lerpf(.58,.82,near),"depth":58.0-near*5.0,"haze":lerpf(.25,.06,near)}

func _start_jump() -> void:
	var species:int=episode%2;episode+=1
	actor.sprite_frames=frame_sets[species];actor.animation="jump";actor.frame=0
	ink.set_shader_parameter("animal_sheet",textures[species])
	var spots:Array[Vector2]=[Vector2(.16,.51),Vector2(.85,.55),Vector2(.19,.68),Vector2(.87,.74),Vector2(.12,.80)]
	anchor=spots[rng.randi_range(0,spots.size()-1)]
	anchor.x+=rng.randf_range(-.025,.025)
	var plane:Dictionary=perspective(anchor.y)
	var nearness:float=plane.nearness
	actor_width=float(plane.width)*(1.0 if species==0 else .9)
	opacity=plane.opacity
	depth=plane.depth # Above background ridges, behind foreground ridges and map.
	jump_height=lerpf(.13,.21,nearness)
	travel=rng.randf_range(.10,.16)
	direction=1.0 if rng.randf()>.5 else -1.0
	actor.flip_h=direction>0.0
	duration=rng.randf_range(1.5,1.9)
	ink.set_shader_parameter("haze",plane.haze)
	ink.set_shader_parameter("ground_y",anchor.y)
	jump_time=0.0;actor.visible=true
	_layout()
func _process(delta:float) -> void:
	if not is_instance_valid(camera) or bool(camera.get_parent().get("paused")):return
	if jump_time<0.0:
		wait_time-=delta
		if wait_time<=0.0:_start_jump()
		return
	jump_time+=delta
	if jump_time>=duration:
		jump_time=-1.0;actor.visible=false;wait_time=rng.randf_range(4.5,9.0)
		return
	_layout()
func _layout() -> void:
	var size_:Vector2=get_viewport().get_visible_rect().size
	if size_.y<=0:return
	var t:float=clampf(jump_time/duration,0.0,1.0)
	actor.frame=POSES[mini(POSES.size()-1,int(t*POSES.size()))]
	var texture:Texture2D=actor.sprite_frames.get_frame_texture("jump",actor.frame)
	var view_width:float=camera.size*size_.x/size_.y
	actor.pixel_size=view_width*actor_width/float(texture.get_width())
	image_height=actor_width*(size_.x/size_.y)*float(texture.get_height())/float(texture.get_width())
	var foot_y:float=anchor.y+image_height*.95-jump_height*4.0*t*(1.0-t)
	var center:=Vector2(anchor.x+direction*travel*(t-.5),foot_y-image_height*.5)
	actor.global_basis=camera.global_basis
	actor.global_position=camera.global_position-camera.global_basis.z*depth+camera.global_basis.x*((center.x-.5)*view_width)+camera.global_basis.y*((.5-center.y)*camera.size)
	ink.set_shader_parameter("opacity",opacity*smoothstep(0.0,.12,t)*(1.0-smoothstep(.84,1.0,t)))
