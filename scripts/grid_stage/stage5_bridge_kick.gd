extends Node
const LINE:="찍찍 얄밉지?"
var story:Node3D
var index:=-1
var phase:="idle"
var elapsed:=0.0
var impacted:=false
var actor:Sprite3D
var effect:Sprite3D
var frames:Array[Texture2D]=[]
var offsets:Array[Vector2]=[]
var impacts:Array[Texture2D]=[]
var bubble:Control
var speech_time:=0.0

func configure(owner_story:Node3D) -> void:
	story=owner_story
	var sheet:Image=load(story.REWORK_ART+"impostor_kick.png").get_image()
	if sheet.is_compressed():sheet.decompress()
	# The follow-through tail extends right; use its full isolated region.
	var regions:=[Rect2i(0,0,647,608),Rect2i(647,0,647,608),Rect2i(0,608,748,608),Rect2i(748,608,546,608)]
	var maximum:=0
	for region:Rect2i in regions:
		var cell:=sheet.get_region(region);var used:=cell.get_used_rect()
		frames.append(ImageTexture.create_from_image(cell))
		offsets.append(Vector2(region.size.x*.5-used.get_center().x,used.end.y-region.size.y*.5))
		maximum=maxi(maximum,used.size.y)
	actor=_sprite();actor.pixel_size=1.5*story.RAT_SCALE/maximum;actor.hide()
	var dust:Image=load(story.REWORK_ART+"bridge_kick_impact.png").get_image()
	if dust.is_compressed():dust.decompress()
	var size:=dust.get_size()/2
	for frame:int in range(4):impacts.append(ImageTexture.create_from_image(dust.get_region(Rect2i(Vector2i(frame%2,frame/2)*size,size))))
	effect=_sprite();effect.pixel_size=2.3/size.y;effect.hide()
	var overlay:=CanvasLayer.new();overlay.layer=8;add_child(overlay)
	bubble=preload("res://scripts/grid_stage/speech_bubble.gd").new();bubble.automatic=false;overlay.add_child(bubble)

func _sprite() -> Sprite3D:
	var sprite:=Sprite3D.new();story.add_child(sprite);sprite.global_basis=story.camera.global_basis
	sprite.set_meta("paper_foreground",true)
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
	ink.render_priority=126;sprite.material_override=ink;return sprite

func begin(bridge_index:int) -> void:
	if index>=0:return
	index=bridge_index;phase="approach";elapsed=0;impacted=false
	story.hint.text="가짜가 다리로 다가옵니다! 미인도로 주의를 돌려보세요."

func cancel() -> void:
	index=-1;phase="idle";actor.hide();effect.hide()
	if not story.caught:story.impostor.show()

func tick(delta:float) -> bool:
	if bubble.visible:
		speech_time+=delta
		bubble.modulate.a=minf(speech_time/.18,1.0)*(1-clampf((speech_time-3.0)/.8,0,1))
		bubble.place(story.camera.unproject_position(story.rat_base+story.camera.global_basis.y*1.7))
		if speech_time>=3.8:bubble.hide()
	if index<0:return false
	if story.caught or (not impacted and (story._sabotage_stopped() or not story.bridges.has(index))):cancel();return false
	var foot:Vector3=story.routes[0][1] if index==0 else story.routes[1][0]
	var away:Vector3=story.routes[index][0] if index==0 else story.routes[index][1]
	var direction:Vector3=(away-foot).normalized()
	if phase=="approach":
		story.rat_base=story.rat_base.move_toward(foot,delta*3.0)
		if story.rat_base.distance_to(foot)<.08:phase="kick";elapsed=0
		return true
	elapsed+=delta
	story.impostor.hide();actor.show();actor.position=story.rat_base
	var frame:=0 if elapsed<.30 else (1 if elapsed<.48 else (2 if elapsed<.78 else 3))
	actor.texture=frames[frame];actor.offset=offsets[frame]
	actor.flip_h=direction.dot(story.camera.global_basis.x)>0
	actor.material_override.set_shader_parameter("illustration",actor.texture)
	if elapsed>=.48 and not impacted:
		impacted=true;story.tree_bridge.knock_down(index)
		BgmPlayer.play_punch()
		effect.position=foot+direction*.5+story.camera.global_basis.y*.28
		bubble.present("분신",LINE);speech_time=0
		story.hint.text="가짜가 다리를 걷어찼습니다! 나무 조각을 다시 붙이거나 미인도로 시선을 돌려보세요."
	if impacted:
		var fx_time:=elapsed-.48
		effect.visible=fx_time<.64
		effect.texture=impacts[mini(int(fx_time/.16),3)]
		effect.material_override.set_shader_parameter("illustration",effect.texture)
		effect.material_override.set_shader_parameter("opacity",1.0-clampf((fx_time-.42)/.22,0,1))
	if elapsed>=1.15:cancel()
	return true
