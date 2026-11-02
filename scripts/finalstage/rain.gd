extends Node2D
## Lightweight rain strokes; no separate sprite or particle texture required.
var world: GridStageWorld
var drops := PackedVector3Array()
var raining := false
var clock := 0.0
var rain_sound:AudioStreamPlayer

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	rain_sound=AudioStreamPlayer.new()
	var sound:AudioStreamMP3=load("res://music/boss-rain.mp3").duplicate()
	sound.loop=true;rain_sound.stream=sound
	rain_sound.volume_db=BgmPlayer.BASE_VOLUME_DB
	add_child(rain_sound)
	var rng := RandomNumberGenerator.new();rng.seed=93107
	for index in range(150):
		drops.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(.65,1.0)))
	hide()

func begin_rain() -> void:
	if raining:return
	raining=true;clock=0;show()
	rain_sound.play()
	BgmPlayer.fade_out_boss_default()
	world.stage_root.get_node("SkyBackdrop").call("begin_storm")
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(rain_sound):rain_sound.stream_paused=world.paused or world.transition.active
	if not raining or world.paused or world.transition.active:return
	clock+=delta
	queue_redraw()

func _draw() -> void:
	if not raining:return
	var frame := get_viewport_rect().size
	var fade := minf(clock/1.8,1.0)
	draw_rect(Rect2(Vector2.ZERO,frame),Color(.035,.035,.04,.42*fade))
	for drop in drops:
		var point := Vector2(fposmod(drop.x-clock*.04,1.1)-.05,fposmod(drop.y+clock*drop.z,1.15)-.15)*frame
		draw_line(point,point+Vector2(-4,19)*frame.y/900.0,Color(.82,.90,1.0,.72*fade),1.5)
