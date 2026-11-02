extends Node3D
## One title-following breath: four paths from the dragon toward the marked areas.
const TARGETS := [Vector2(.18,.28),Vector2(.18,.62),Vector2(.32,.91),Vector2(.64,.91)]
var world: GridStageWorld
var frames: Array[Texture2D] = []
var flames: Array[Dictionary] = []
var started := false
var finished := false
var clock := 0.0

func configure(owner_world: GridStageWorld,art: Array[Texture2D]) -> void:
	world=owner_world;frames=art
	process_physics_priority=-10
	world.player.input_locked=true
	for lane in range(TARGETS.size()):
		var sprite := Sprite3D.new();sprite.texture=frames[0]
		var ink := ShaderMaterial.new();ink.shader=preload("res://shaders/grid_paper_foreground.gdshader")
		ink.set_shader_parameter("illustration",frames[0]);ink.render_priority=126
		sprite.material_override=ink;sprite.set_meta("paper_foreground",true)
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite);sprite.hide()
		flames.append({"sprite":sprite,"lane":lane,"delay":0.0})

func _physics_process(_delta: float) -> void:
	if not finished:world.player.input_locked=true

func _process(delta: float) -> void:
	if finished or world.paused:return
	if not started:
		if world.transition.active or not world.stage_intro.is_finished():return
		started=true
		BgmPlayer.play_boss_fire()
		world.stage_root.get_node("FalseExitTrap").call("shake",3.0)
	clock+=delta
	var frame := get_viewport().get_visible_rect().size
	var source := Vector2(.59,.25)
	var index := int(clock*8.0)%8
	var branches := world.stage_root.get_node("PeachBranches")
	for flame in flames:
		var sprite: Sprite3D = flame.sprite
		var age: float = clock-float(flame.delay)
		var t := clampf(age/1.4,0,1)
		sprite.visible=age>=0 and age<2.4
		var target: Vector2 = TARGETS[int(flame.lane)]
		var branch_rect := Rect2()
		if int(flame.lane)<2:
			branch_rect=branches.call("branch_screen_rect",int(flame.lane))
			target=branch_rect.get_center()/frame
		var point := source.lerp(target,smoothstep(0,1,t))
		var direction := (target-source)*frame
		var angle := atan2(-direction.y,direction.x)-PI*.5
		var height := world.camera.size*lerpf(.338,.5408,t)
		if int(flame.lane)<2:
			var aspect := float(frames[index].get_width())/frames[index].get_height()
			var width_factor := absf(cos(angle))*aspect+absf(sin(angle))
			var height_factor := absf(sin(angle))*aspect+absf(cos(angle))
			var cover := maxf(branch_rect.size.x/width_factor,branch_rect.size.y/height_factor)*1.6*world.camera.size/frame.y
			height=lerpf(height,maxf(height,cover),smoothstep(.55,.95,t))
		sprite.pixel_size=height/frames[index].get_height()
		sprite.global_basis=world.camera.global_basis*Basis(Vector3.BACK,angle)
		sprite.global_position=world.camera.project_position(point*frame,2.0)
		sprite.material_override.set_shader_parameter("illustration",frames[index])
		sprite.material_override.set_shader_parameter("opacity",1-smoothstep(1.9,2.4,age))
		if int(flame.lane)<2 and age<1.9:
			var extent := Vector2(absf(cos(angle))*sprite.texture.get_width()+absf(sin(angle))*sprite.texture.get_height(),absf(sin(angle))*sprite.texture.get_width()+absf(cos(angle))*sprite.texture.get_height())*sprite.pixel_size*frame.y/world.camera.size
			if Rect2(point*frame-extent*.5,extent).encloses(branch_rect):
				branches.call("burn_branch",int(flame.lane))
	if clock>=2.6:
		finished=true;world.player.input_locked=false
		for flame in flames:flame.sprite.queue_free()
		flames.clear()
