extends Node
## Upper figures use eight drawn arm poses; bathers use eight gentle water poses.
var world: GridStageWorld
var clock := 0.0
var actors: Array[Dictionary] = []

func configure(owner_world: GridStageWorld, artwork: Node3D) -> void:
	world = owner_world
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/stage1/dano/people-animation-atlas.json"))
	_add_actor(artwork,"BraidedWoman","braided_woman_8frames",Vector2(.813,.275),.235,atlas.braided,0)
	_add_actor(artwork,"HairCombingWoman","hair_combing_woman_8frames",Vector2(.9,.31),.215,atlas.combing,0)
	_add_actor(artwork,"RestingWoman","resting_woman_user",Vector2(.17,.81),.16,{},2,true,.81)
	_add_actor(artwork,"BathingWomen","bathing_women_user",Vector2(.26,.84),.19,{},5,true,.79)

func _add_actor(parent: Node3D, node_name: String, asset: String, center: Vector2, height_fraction: float, atlas: Dictionary, phase: int, swimming := false, waterline := .8) -> void:
	var source: Texture2D = load("res://art/stage1/dano/"+asset+".png")
	var frames: Array[Texture2D] = []
	if not atlas.is_empty():
		for pose: Dictionary in atlas.frames:
			var frame := AtlasTexture.new()
			frame.atlas = source
			frame.region = Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3])
			frame.margin = Rect2(pose.margin[0],pose.margin[1],pose.margin[2],pose.margin[3])
			frame.filter_clip = true
			frames.append(frame)
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = source if frames.is_empty() else frames[0]
	var height: float = source.get_height() if atlas.is_empty() else float(atlas.reference_height)
	sprite.pixel_size = world.camera.size*height_fraction/height
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 108
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("screen_band",11)
	sprite.set_meta("swimming",swimming)
	sprite.set_meta("waterline",waterline)
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/stage1/people_ink.gdshader")
	ink.render_priority = 108
	ink.set_shader_parameter("illustration",source)
	if not atlas.is_empty():
		ink.set_shader_parameter("sprite_mask",load("res://art/stage1/dano/"+str(atlas.mask)))
		ink.set_shader_parameter("use_sprite_mask",true)
	ink.set_shader_parameter("actor_height",world.camera.size*height_fraction)
	ink.set_shader_parameter("pose_amplitude",world.camera.size*height_fraction*.012 if swimming else 0.0)
	ink.set_shader_parameter("swimming",swimming)
	ink.set_shader_parameter("waterline",waterline)
	sprite.material_override = ink
	parent.add_child(sprite)
	sprite.global_basis = world.camera.global_basis
	sprite.global_position = world.camera.project_position(get_viewport().get_visible_rect().size*center,40.0)
	actors.append({"sprite":sprite,"frames":frames,"phase":phase,"frame":-1,"ink":ink})

func _process(delta: float) -> void:
	if world.paused or world.transition.active: return
	clock += delta
	for actor in actors:
		var frame := (int(floor(clock*3.0))+int(actor.phase))%8
		if frame == actor.frame: continue
		actor.frame = frame
		if not actor.frames.is_empty(): actor.sprite.texture = actor.frames[frame]
		actor.ink.set_shader_parameter("pose_phase",frame*TAU/8.0)
