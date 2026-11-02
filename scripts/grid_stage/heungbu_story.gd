extends "res://scripts/grid_stage/paper_cutting.gd"
## Uses shared stroke input and the same finite silhouette / half-plane cut test.
## Carried gourds become real rigid bodies, then shared cut-paper after landing.
const Minhwa=preload("res://scripts/grid_stage/heungbu_minhwa.gd")
@export var wing_fps:=8.0
@export var bird_width:=5.7
@export var flight_seconds:=1.4
@export var carrier_entry_delay:=2.0
@export var gourd_width:=1.2
@export var gourd_minimum_y:=0.0
@export var gourd_drop_distance:=1.8
@export var drop_position:=Vector3(-2.4,1.8,-.8)
@export var blue_position:=Vector3(3.8,1.8,-1.4)
@export var nolbu_position:=Vector3(2.05,1.8,-1.6)
## Logical passage anchor is independent of this illustration rectangle.
## Exact image transform in ex7-1.pdf (1440 x 810), including deliberate clipping.
@export var house_view_rect:=Rect2(-433.394287/1440.0,-198.238281/810.0,1199.083496/1440.0,799.388916/810.0)
@export var house_art_scale:=1.12
@export var house_block_position:=Vector3(1.2,3.6,-4.25)
@export var house_block_size:=Vector3(4.8,4.0,.65)
@export var heungbu_position:=Vector3(-3.15,0,4.4)
@export var nolbu_height:=2.1
@export var heungbu_height:=2.0
var birds:Array[Dictionary]=[]
var fruits:Array[Dictionary]=[]
var normal_selected:=0
var normal_opened:=0
var provided:=0
var house:Sprite3D
var nolbu:Sprite3D
var heungbu:Sprite3D
var blockers:Array[StaticBody3D]=[]
var goblin:Node3D
var chase_started:=false
var house_collapsed:=false
var house_damage_stage:=0
var heungbu_state:="poor"
var house_block:StaticBody3D
var nolbu_block:StaticBody3D
var nolbu_bridge:StaticBody3D
var goblin_bridge:StaticBody3D
var chase:Node3D
var delivery:RefCounted
var path_open:=false
var reset_pending:=false
var goblin_origin:=Vector3.ZERO
var textures:Dictionary={}
var silhouettes:Dictionary={}
var house_cloud_inks:Array[ShaderMaterial]=[]
var failure_effect:Node3D
var goblin_animation:AnimatedSprite3D
var carrier_layout:Array[Dictionary]=[]
var spawn_retry_elapsed:=0.0
var carrier_entry_elapsed:=0.0
var attempt_number:=1
var opened_count:=0
var rotten_flies:Array[Dictionary]=[]
var idle_clock:=0.0
var demolition:Node3D
var chase_complete:=false
var loose_stems:Array[RigidBody3D]=[]

func setup(owner_world:Node3D) -> void:
	configure(owner_world.camera,[])
	attempt_number=int(owner_world.get_meta("stage7_attempt",0))+1
	owner_world.set_meta("stage7_attempt",attempt_number)
	source_cut.connect(_on_gourd_cut)
	for number:int in [1,2,3,4,5,8]:
		var keys:Dictionary={1:"house",2:"shells",3:"gourd",4:"poor",5:"nolbu",8:"gourd"}
		var original:Texture2D=Minhwa.texture(keys[number])
		var image:=original.get_image()
		if image.is_compressed():image.decompress()
		# The five house stages share one canvas and foundation anchor.
		var bounds:=Rect2i(Vector2i.ZERO,image.get_size()) if number==1 else image.get_used_rect()
		var cropped:=image.get_region(bounds)
		if number==1:cropped.generate_mipmaps()
		textures[number]=ImageTexture.create_from_image(cropped)
		var bitmap:=BitMap.new();bitmap.create_from_image_alpha(cropped,.12)
		var outlines:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,cropped.get_size()),2.5)
		var largest:=PackedVector2Array()
		for outline:PackedVector2Array in outlines:
			if _area(outline)>_area(largest):largest=outline
		silhouettes[number]=largest
	house=_art(1,1.0,house_block_position,"NolbuHouse")
	_layout_house_background()
	heungbu=_art(4,heungbu_height*textures[4].get_width()/float(textures[4].get_height()),heungbu_position,"Heungbu")
	world.dialogue=preload("res://scripts/grid_stage/heungbu_dialogue.gd").new()
	world.dialogue.name="HeungbuDialogue";world.dialogue.puzzle=self
	world.dialogue.lines=PackedStringArray(["작년 이맘때쯤 제비를 치료해줬었지."])
	world.dialogue.speaker_at_feet=true
	add_child(world.dialogue);world.dialogue.configure(world,heungbu)
	nolbu=_art(5,nolbu_height*textures[5].get_width()/float(textures[5].get_height()),nolbu_position,"Nolbu")
	_block(house_block_position,house_block_size,self)
	house_block=blockers.back()
	_block(nolbu_position,Vector3(.65,3.8,1.55),self)
	nolbu_block=blockers.back()
	delivery=preload("res://scripts/grid_stage/heungbu_swallow_delivery.gd").new(self)
	delivery.install_minimum_floor()
	_spawn_carriers()
	# Inspector values belong to this Stage7 node; no project input/resource edits.

func _spawn_carriers() -> void:
	if not birds.is_empty():return
	carrier_layout=preload("res://scripts/grid_stage/heungbu_spawn_layout.gd").build(self)
	if carrier_layout.size()!=3:return
	for index:int in 3:
		_make_bird(index,index)

func _art(number:int,width:float,feet:Vector3,title:String) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.name=title;sprite.texture=textures[number]
	sprite.pixel_size=width/sprite.texture.get_width()
	sprite.offset.y=sprite.texture.get_height()*.5
	sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if number not in [1,2]:_above_clouds(sprite)
	add_child(sprite);sprite.global_basis=camera.global_basis;sprite.global_position=feet
	return sprite

func _layout_house_background() -> void:
	# House belongs to the existing background pass, before map slices. Keep
	# the existing foreground fog elsewhere, masking only its overlap with the
	# house. Every replacement material belongs to this Stage7 instance.
	var sky:Node=world.stage_root.get_node_or_null("SkyBackdrop")
	if sky:
		for cloud:Node in sky.get_children():
			if not cloud is Sprite3D or cloud.get_meta("cloud_layer","") not in ["front","column_cover"]:continue
			var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/heungbu_cloud_mask.gdshader")
			var texture:Texture2D=cloud.texture
			ink.set_shader_parameter("cloud_image",texture.atlas if texture is AtlasTexture else texture)
			ink.set_shader_parameter("cloud_opacity",cloud.modulate.a)
			ink.set_shader_parameter("column_cover",cloud.get_meta("cloud_layer")=="column_cover")
			ink.set_shader_parameter("house_image",textures[1])
			ink.render_priority=cloud.material_override.render_priority if cloud.material_override else cloud.render_priority
			# The compositor retains each instance's original material. Update that
			# reference too, rather than racing its per-frame restoration.
			for child:Node in world.stage_root.get_children():
				if child.get_script()==preload("res://scripts/grid_stage/screen_slices.gd"):
					for record:Dictionary in child.records:
						if record.visual==cloud:record.original=ink
			cloud.material_override=ink;house_cloud_inks.append(ink)
	house.texture=textures[1]
	house.set_meta("screen_band",0)
	house.render_priority=127;house.sorting_offset=200
	var frame:=get_viewport().get_visible_rect().size
	var world_width:float=camera.size*frame.x/frame.y*house_view_rect.size.x*house_art_scale
	house.pixel_size=world_width/house.texture.get_width()
	house.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	house.offset.y=house.texture.get_height()*.5
	var foot:=Vector2(house_view_rect.get_center().x,house_view_rect.end.y)*frame
	house.global_position=camera.project_position(foot,40.0)
	_update_house_cloud_mask()

func _update_house_cloud_mask() -> void:
	var rect:=Vector4.ZERO
	var opacity:=0.0
	if is_instance_valid(house):
		var frame:=get_viewport().get_visible_rect().size
		var size_:Vector2=house.texture.get_size()*house.pixel_size*frame.y/camera.size/frame
		var foot:=camera.unproject_position(house.global_position)/frame
		var corner:=foot-size_*.5+Vector2(house.offset.x,-house.offset.y)*house.pixel_size/camera.size*frame.y/frame
		rect=Vector4(corner.x,corner.y,size_.x,size_.y);opacity=house.modulate.a
	for ink:ShaderMaterial in house_cloud_inks:
		ink.set_shader_parameter("house_rect",rect);ink.set_shader_parameter("house_opacity",opacity)
		if is_instance_valid(house):ink.set_shader_parameter("house_image",house.texture)

func _above_clouds(sprite:SpriteBase3D) -> void:
	# These intact story illustrations sit above the Stage7 foreground cloud
	# collage, as in the supplied PDF. They remain world-positioned sprites.
	# Split fruit is deliberately excluded and retains ordinary map depth.
	sprite.set_meta("screen_band",11)
	sprite.render_priority=127;sprite.sorting_offset=200

func _block(feet:Vector3,size_:Vector3,parent:Node3D) -> void:
	var body:=StaticBody3D.new();body.name="Stage7PassageBlocker"
	body.collision_layer=1;body.collision_mask=0
	parent.add_child(body);body.global_position=feet+Vector3.UP*size_.y*.5
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_;shape.shape=box;body.add_child(shape)
	blockers.append(body)

func _make_bird(index:int,variant:int) -> void:
	var placement:Dictionary=carrier_layout[index]
	var sprite:=AnimatedSprite3D.new();sprite.name="Swallow%d"%index
	sprite.sprite_frames=Minhwa.frames("bird",variant);sprite.pixel_size=float(placement.width)*4.0/440.0
	var facing_left:bool=bool(placement.flip)
	# Turn around the local upright Y axis, keeping the beak at the pivot.
	sprite.flip_h=false;sprite.offset=Vector2(-180,0)
	sprite.shaded=false;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.set_meta("paper_foreground",true)
	sprite.set_meta("paper_foreground_original",true)
	_above_clouds(sprite);add_child(sprite);sprite.global_basis=camera.global_basis
	if facing_left:sprite.global_basis=camera.global_basis*Basis(Vector3.UP,PI)
	var screen_size:=get_viewport().get_visible_rect().size
	var depth:float=(Vector3(placement.beak)-camera.global_position).dot(-camera.global_basis.z)
	var beak:Vector3=placement.beak
	var fruit:=Sprite3D.new();fruit.name="CarriedGourd%d"%index;fruit.texture=textures[3]
	fruit.pixel_size=gourd_width*2.0/fruit.texture.get_width();fruit.shaded=false;fruit.flip_h=facing_left
	add_child(fruit);fruit.global_basis=camera.global_basis
	var stem:Vector2=Minhwa.stem_anchor(fruit.texture)*fruit.pixel_size
	if fruit.flip_h:stem.x=-stem.x
	var attachment:Vector3=camera.global_basis.x*stem.x+camera.global_basis.y*stem.y
	var center:Vector3=placement.center
	fruit.global_position=center
	_above_clouds(fruit)
	fruit.set_meta("paper_foreground",true);fruit.set_meta("paper_loose_foreground",true)
	var fruit_ink:=_sticker_ink(fruit.texture,Vector4(0,0,.60,.37))
	fruit_ink.set_shader_parameter("border_radius",21.6)
	fruit_ink.render_priority=126;fruit.render_priority=126
	fruit.material_override=fruit_ink
	var bird_ink:=_sticker_ink(sprite.sprite_frames.get_frame_texture("default",0),Vector4(.71,.45,.83,.55))
	bird_ink.set_shader_parameter("enabled",false)
	bird_ink.render_priority=127
	sprite.material_override=bird_ink
	sprite.frame_changed.connect(func():bird_ink.set_shader_parameter("illustration",sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)))
	var entry_pixel:=camera.unproject_position(beak)
	entry_pixel.x=screen_size.x+screen_size.y*.5 if facing_left else -screen_size.y*.5
	var entry:Vector3=camera.project_position(entry_pixel,depth)
	sprite.global_position=entry;fruit.global_position=entry-attachment;sprite.play()
	sprite.hide();fruit.hide()
	birds.append({"sprite":sprite,"gourd":fruit,"facing_left":facing_left,"bird_ink":bird_ink,"fruit_ink":fruit_ink,"landing":placement.landing,"evil":false,"state":"waiting","origin":beak,"target":beak,"entry":entry,"attachment":attachment,"delay":index*.25,"time":0.0,"provided":false,"index":index})

func _sticker_ink(texture:Texture2D,area:Vector4) -> ShaderMaterial:
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/heungbu_cut_sticker.gdshader")
	ink.set_shader_parameter("illustration",texture);ink.set_shader_parameter("sticker_area",area)
	return ink

func _pick(_point:Vector2) -> Dictionary:return {}
func _mouse() -> Vector2:return _screen(pointer_position)

func _input(event:InputEvent) -> void:
	if event is InputEventMouse:pointer_position=event.position
	# Resolve our release before the background cutters, but leave unrelated
	# gestures available to them. One gesture can claim exactly one target.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and drawing:
		if not locked and not world.paused and not world.transition.active:
			drawing=false;stroke.clear_points();_cut(line_start,_mouse())

func _cut(a:Vector2,b:Vector2) -> void:
	if reset_pending or world.paused or world.transition.active or a.distance_to(b)<8:return
	for index:int in birds.size():
		if birds[index].state=="idle":
			if preload("res://scripts/grid_stage/heungbu_stem_cut.gd").release(self,index,a,b):
				BgmPlayer.play_cut()
				_consume_stroke();return
	super._cut(a,b)

func _consume_stroke() -> void:
	_cancel_other_strokes(world.stage_root)
	get_viewport().set_input_as_handled()

func _cancel_other_strokes(node:Node) -> void:
	if node!=self and node is GridPaperCutting:
		node.drawing=false;node.stroke.clear_points()
	for child:Node in node.get_children():_cancel_other_strokes(child)

func _crosses(polygon:PackedVector2Array,a:Vector2,b:Vector2) -> bool:
	# Same finite stroke, silhouette crossings, clipping and minimum-area rules
	# as GridPaperCutting._cut; do not substitute a bounding-box click test.
	var crossings:=0
	for i:int in polygon.size():
		if Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])!=null:crossings+=1
	if crossings<2:return false
	var direction:Vector2=(b-a).normalized();var normal:=direction.orthogonal();var reach:=10000.0
	var substantial:=0
	for side:float in [-1.0,1.0]:
		var half:=PackedVector2Array([a-direction*reach,a+direction*reach,a+direction*reach+normal*reach*side,a-direction*reach+normal*reach*side])
		for clipped:PackedVector2Array in Geometry2D.intersect_polygons(polygon,half):
			if _area(clipped)>=minimum_piece_area:substantial+=1
	return substantial>=2

func _mouth_polygon(index:int) -> PackedVector2Array:
	var polygon:=PackedVector2Array()
	var fruit:Sprite3D=birds[index].gourd
	var size_:Vector2=fruit.texture.get_size()
	# The same UV region used by the visible stem outline, including mirroring.
	for uv:Vector2 in [Vector2(0,0),Vector2(.60,0),Vector2(.60,.37),Vector2(0,.37)]:
		var local:=Vector3((uv.x-.5)*size_.x*fruit.pixel_size,(.5-uv.y)*size_.y*fruit.pixel_size,0)
		if fruit.flip_h:local.x=-local.x
		polygon.append(_screen(camera.unproject_position(fruit.global_transform*local)))
	return polygon

func prepare_landed_gourd(item:Dictionary) -> void:
	var fruit:Sprite3D=item.sprite
	fruit.set_meta("paper_convex_collision",true)
	# Preserve the mirrored artwork when the shared cutter takes over the source.
	if fruit.flip_h:
		var mirrored:=fruit.texture.get_image();mirrored.flip_x()
		fruit.texture=ImageTexture.create_from_image(mirrored);fruit.flip_h=false
	fruit.set_meta("paper_convex_outline",true)
	fruit.set_meta("map_occluded",true)
	fruit.set_meta("paper_alpha_border",true)
	fruit.set_meta("paper_outline_fallback",true)
	fruit.set_meta("background_depth",(fruit.global_position-camera.global_position).dot(-camera.global_basis.z))
	fruit.set_meta("paper_floor_y",_screen(camera.unproject_position(fruit.global_position-camera.global_basis.y*fruit.texture.get_height()*fruit.pixel_size*.5)).y+15)
	add_source(fruit)
	if is_instance_valid(item.get("cut_visual")):item.cut_visual.queue_free()

func _on_gourd_cut(sprite:Sprite3D) -> void:
	for item:Dictionary in fruits:
		if item.sprite!=sprite or item.opened:continue
		item.destination=item.body.global_position
		# The 2D cut halves now own the visible geometry; retire the intact
		# 3D collider and wake any whole gourds it may have been supporting.
		item.body.collision_layer=0;item.body.collision_mask=0;item.body.freeze=true
		for other:Dictionary in fruits:
			if other!=item and not other.opened and is_instance_valid(other.body):other.body.sleeping=false
		# Both cut halves use the common gravity/collision simulation.
		for piece:Dictionary in pieces:
			if piece.source.sprite==sprite:
				piece.attached=false;piece.body.freeze=false
				piece.body.collision_layer=int(piece.source.layer);piece.body.lock_rotation=true
				piece.body.linear_velocity=Vector2(25 if piece.body.position.x>=_screen(camera.unproject_position(sprite.global_position)).x else -25,-18)
		_consume_stroke();_open_fruit(item);return

func _fruit_polygon(item:Dictionary) -> PackedVector2Array:
	var polygon:=PackedVector2Array()
	var fruit:Sprite3D=item.sprite
	var original:PackedVector2Array=silhouettes[8 if item.role=="evil" else 3]
	var size_:=fruit.texture.get_size()
	for point:Vector2 in original:
		var local:=Vector3((point.x-size_.x*.5)*fruit.pixel_size,(size_.y*.5-point.y+fruit.offset.y)*fruit.pixel_size,0)
		polygon.append(_screen(camera.unproject_position(fruit.global_transform*local)))
	return polygon

func _open_fruit(item:Dictionary) -> void:
	if item.opened or item.state!="ready":return
	item.opened=true;item.state="opened"
	item["shell_elapsed"]=0.0;item["shells_removed"]=false
	opened_count+=1
	var unlucky:bool=_bad_outcome(opened_count)
	item.role="evil" if unlucky else ("red" if normal_opened==0 else "blue")
	if unlucky:
		BgmPlayer.play_gourd_fail()
		reset_pending=true
		failure_effect=preload("res://scripts/grid_stage/heungbu_bad_gourd.gd").new()
		add_child(failure_effect);failure_effect.setup(self,item.destination)
		return
	BgmPlayer.play_gourd_tada()
	normal_opened+=1
	if normal_opened==2:_spoil_remaining()
	if item.role=="red":
		demolition=preload("res://scripts/grid_stage/heungbu_house_demolition.gd").new()
		add_child(demolition);demolition.setup(self,item.destination)
		if heungbu_state!="hatted":set_heungbu("noble")
	elif not chase_started:
		chase_started=true
		chase=preload("res://scripts/grid_stage/heungbu_nolbu_chase.gd").new();add_child(chase);chase.setup(self,item.destination)

func _bad_outcome(opening:int) -> bool:
	# Guarantee the successful sequence from the third attempt onward.
	if attempt_number>=3:return false
	return opening==2 if attempt_number==1 else randf()<.30

func _spoil_remaining() -> void:
	for bird:Dictionary in birds:
		var item:Dictionary=bird.get("item",{})
		if not item.is_empty() and item.opened:continue
		if item.is_empty():
			bird.sprite.global_position=bird.target;bird.gourd.global_position=bird.target-bird.attachment
			bird.sprite.show();bird.gourd.show();bird.state="idle"
			delivery.separate(int(bird.index));item=bird.item
		item["rotten"]=true
		var fruit:Sprite3D=item.sprite
		if is_instance_valid(item.get("cut_visual")):item.cut_visual.queue_free()
		hide_source(fruit)
		fruit.remove_meta("paper_source_outline")
		fruit.texture=Minhwa.texture("rotten");fruit.flip_h=false
		fruit.pixel_size=gourd_width*2.0/fruit.texture.get_width()
		bird.fruit_ink.set_shader_parameter("illustration",fruit.texture)
		fruit.set_meta("paper_cuttable",false);fruit.show()
		item.body.freeze=false;item.state="falling";bird.state="watch"
		for fly_index:int in 2:
			var fly:=AnimatedSprite3D.new();fly.sprite_frames=Minhwa.frames("fly");fly.pixel_size=.28/300.0
			fly.shaded=false;fly.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			add_child(fly);fly.play()
			rotten_flies.append({"fly":fly,"body":item.body,"phase":fly_index*PI})

func _extra_art(file:String,width:float,feet:Vector3,title:String) -> Sprite3D:
	var sprite:=Sprite3D.new();sprite.name=title;sprite.texture=Minhwa.texture("hat") if file=="검은갓.png" else Minhwa.texture(file)
	sprite.pixel_size=width/sprite.texture.get_width();sprite.offset.y=sprite.texture.get_height()*.5
	_above_clouds(sprite);add_child(sprite);sprite.global_basis=camera.global_basis;sprite.global_position=feet
	return sprite

func set_heungbu(state:String) -> void:
	if heungbu_state=="hatted" and state!="hatted":return
	heungbu_state=state
	preload("res://scripts/grid_stage/heungbu_art.gd").replace_at_feet(heungbu,Minhwa.texture(state),heungbu_height)

func house_impact_point() -> Vector3:
	return camera.project_position(get_viewport().get_visible_rect().size*Vector2(.22,.35),40.0)

func remove_blocker(body:StaticBody3D) -> void:
	if not is_instance_valid(body):return
	body.collision_layer=0;blockers.erase(body);body.queue_free()

func set_house_damage(stage:int) -> void:
	var next_stage:int=clampi(stage,house_damage_stage,4)
	if next_stage==house_damage_stage:return
	house_damage_stage=next_stage
	house.texture=Minhwa.house_stage(house_damage_stage)
	_update_house_cloud_mask()

func collapse_house() -> void:
	if house_collapsed:return
	house_collapsed=true
	BgmPlayer.play_house_collapse()
	set_house_damage(4)
	remove_blocker(house_block)

func update_path_open() -> void:
	path_open=chase_complete and is_instance_valid(demolition) and demolition.finished and not reset_pending

func _spawn_goblin() -> void:
	goblin=Node3D.new();goblin.name="MinhwaDokkaebi";add_child(goblin)
	goblin_origin=drop_position+Vector3.UP*.7;goblin.global_position=goblin_origin
	goblin_animation=AnimatedSprite3D.new();goblin_animation.sprite_frames=Minhwa.demolition_frames(0)
	goblin_animation.pixel_size=2.5/256.0
	Minhwa.style_goblin(goblin_animation,true)
	goblin_animation.shaded=false
	goblin.add_child(goblin_animation);goblin_animation.global_basis=camera.global_basis;goblin_animation.play("fly")

func _process(delta:float) -> void:
	if not is_instance_valid(world):return
	_update_house_cloud_mask()
	if delivery!=null:delivery.sync_bodies()
	super._process(delta)
	for body:RigidBody3D in loose_stems:body.freeze=locked
	if not locked:
		_update_open_shells(delta)
		idle_clock+=delta
		for entry:Dictionary in rotten_flies:
			var phase:float=idle_clock*3.5+entry.phase
			entry.fly.global_position=entry.body.global_position+Vector3.UP*.9+camera.global_basis.x*cos(phase)*.55+camera.global_basis.z*sin(phase)*.3+Vector3.UP*sin(phase*2.3)*.12
	for entry:Dictionary in rotten_flies:entry.fly.speed_scale=0 if locked else 1
	if birds.is_empty() and not locked and not reset_pending:
		spawn_retry_elapsed+=delta
		if spawn_retry_elapsed>=.5:
			spawn_retry_elapsed=0.0;_spawn_carriers()
	if is_instance_valid(goblin_animation):goblin_animation.speed_scale=0 if locked or reset_pending else 1
	if locked or reset_pending:
		for bird:Dictionary in birds:bird.sprite.speed_scale=0
		if is_instance_valid(chase) and is_instance_valid(chase.animation):chase.animation.speed_scale=0
		return
	delivery.tick(delta)

func _update_open_shells(delta:float) -> void:
	# Leave the cut halves in the shared gravity/collision simulation for one
	# active second after the reward/failure effect begins, then retire them.
	# Run before the reset_pending return so dung-burst shells clear as well.
	for item:Dictionary in fruits:
		if not item.opened or bool(item.get("shells_removed",false)):continue
		item["shell_elapsed"]=float(item.get("shell_elapsed",0.0))+delta
		if float(item.shell_elapsed)<1.0:continue
		hide_source(item.sprite)
		item["shells_removed"]=true
