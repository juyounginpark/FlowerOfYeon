extends AudioStreamPlayer
## Persistent page BGM plus a separate, progressively louder boss-clear layer.
const TITLE := "res://music/title.mp3"
const BOSS_DEFAULT := "res://music/mainboss_default.mp3"
const BASE_VOLUME_DB := -10.0
var current_track := ""
var boss_clear: AudioStreamPlayer
var mix_tween: Tween
var boss_ducked := false
var sea_background: AudioStreamPlayer
var cut_sound: AudioStreamPlayer
var page_sound: AudioStreamPlayer
var last_cut_frame := -1
var walk_sound: AudioStreamPlayer
var drag_sound: AudioStreamPlayer
var landing_sound: AudioStreamPlayer
var roar_sound: AudioStreamPlayer
var breath_sound: AudioStreamPlayer
var ui_sound: AudioStreamPlayer
var clear_sound: AudioStreamPlayer
var brush_sound: AudioStreamPlayer
var brush_tween: Tween
var thunder_sound: AudioStreamPlayer
var splash_sound: AudioStreamPlayer
var water_up_sound: AudioStreamPlayer
var fish_splash_sound: AudioStreamPlayer
var cat_sound: AudioStreamPlayer
var punch_sound: AudioStreamPlayer
var bridge_sound: AudioStreamPlayer
var house_collapse_sound: AudioStreamPlayer
var boss_collapse_sound: AudioStreamPlayer
var gulp_sound: AudioStreamPlayer
var falling_sound: AudioStreamPlayer
var gourd_tada_sound: AudioStreamPlayer
var gourd_fail_sound: AudioStreamPlayer
var boss_raining:=false
var boss_fade:Tween
var stage_start_sound: AudioStreamPlayer
var drop_sound: AudioStreamPlayer

func _ready() -> void:
	boss_clear=AudioStreamPlayer.new();boss_clear.name="BossClearLayer"
	add_child(boss_clear)
	sea_background=AudioStreamPlayer.new();sea_background.name="SeaBackground"
	add_child(sea_background)
	cut_sound=_make_effect("res://music/cut.mp3")
	page_sound=_make_effect("res://music/flipping-book-page.mp3")
	walk_sound=_make_effect("res://music/walk.mp3")
	(walk_sound.stream as AudioStreamMP3).loop=true
	walk_sound.max_polyphony=1;walk_sound.volume_db=BASE_VOLUME_DB-6.0+linear_to_db(1.69)
	drag_sound=_make_effect("res://music/drag.mp3")
	drag_sound.volume_db+=linear_to_db(1.1)
	landing_sound=_make_effect("res://music/landing.mp3")
	landing_sound.volume_db+=linear_to_db(1.69)
	roar_sound=_make_effect("res://music/boss-roar.mp3")
	breath_sound=_make_effect("res://music/boss-breathing-fire.mp3")
	ui_sound=_make_effect("res://music/ui_click.mp3")
	clear_sound=_make_effect("res://music/clear-effect.mp3")
	brush_sound=_make_effect("res://music/brush.mp3")
	brush_sound.volume_db+=linear_to_db(1.5)
	stage_start_sound=_make_effect("res://music/start-stage.mp3")
	stage_start_sound.volume_db+=linear_to_db(1.5)
	drop_sound=_make_effect("res://music/drop.mp3")
	thunder_sound=_make_effect("res://music/thunder-4.mp3")
	splash_sound=_make_effect("res://music/water-splash-3.mp3")
	water_up_sound=_make_effect("res://music/water-up-3.mp3")
	fish_splash_sound=_make_effect("res://music/fish-splash-3.mp3")
	fish_splash_sound.max_polyphony=1
	cat_sound=_make_effect("res://music/cat-5.mp3")
	punch_sound=_make_effect("res://music/punch-2.mp3")
	bridge_sound=_make_effect("res://music/bridge-8.mp3")
	house_collapse_sound=_make_effect("res://music/house-collapse-7.mp3")
	boss_collapse_sound=_make_effect("res://music/boss-collapse.mp3")
	gulp_sound=_make_effect("res://music/gulp-6.mp3")
	falling_sound=_make_effect("res://music/falling-6.mp3")
	gourd_tada_sound=_make_effect("res://music/tada-7.mp3")
	gourd_fail_sound=_make_effect("res://music/fail-7.mp3")
	play_title()

func play_title() -> void:
	set_walking(false)
	_stop_boss_clear()
	_play_track(TITLE)

func play_stage(number: int) -> void:
	set_walking(false)
	_stop_boss_clear()
	# Runtime stages 1-3 are PreMaps; story Stage1 starts at runtime stage 4.
	if number==12:
		_play_track(BOSS_DEFAULT)
	elif number>=4 and number<=6:
		_play_track("res://music/sea.mp3")
	elif number>=7 and number<=9:
		_play_track("res://music/ground.mp3")
	elif number>=10 and number<=11:
		_play_track("res://music/sky.mp3",1.29)
	else:
		play_title()

func _play_track(path: String,gain: float=1.0) -> void:
	volume_db=BASE_VOLUME_DB+linear_to_db(gain)
	if path=="res://music/sea.mp3":
		if not sea_background.playing:
			var ambience: AudioStreamMP3 = load("res://music/sea_background.mp3")
			ambience.loop=true;sea_background.stream=ambience
			sea_background.volume_db=BASE_VOLUME_DB+linear_to_db(.30)
			sea_background.play()
	else:
		sea_background.stop();sea_background.stream=null
	if current_track==path and playing:return
	var next_stream: AudioStreamMP3 = load(path)
	next_stream.loop=true
	stream=next_stream;current_track=path
	play()

func start_boss_clear() -> void:
	if current_track!=BOSS_DEFAULT or boss_clear.playing:return
	var track: AudioStreamMP3 = load("res://music/mainboss_clear.mp3")
	track.loop=true;boss_clear.stream=track
	boss_clear.volume_db=BASE_VOLUME_DB+linear_to_db(.30)
	boss_clear.play()

func set_boss_clear_level(instrument_count: int) -> void:
	start_boss_clear()
	if not boss_clear.playing:return
	var gains := [.30,.50,1.0]
	if instrument_count>=2:boss_ducked=true
	var target := BASE_VOLUME_DB+linear_to_db(float(gains[clampi(instrument_count,0,2)]))
	if mix_tween!=null:mix_tween.kill()
	mix_tween=create_tween()
	mix_tween.tween_property(boss_clear,"volume_db",target,.7)
	if boss_ducked and not boss_raining:
		mix_tween.parallel().tween_property(self,"volume_db",BASE_VOLUME_DB+linear_to_db(.45),.7)

func _stop_boss_clear() -> void:
	if boss_fade!=null:boss_fade.kill();boss_fade=null
	boss_raining=false
	if mix_tween!=null:mix_tween.kill();mix_tween=null
	boss_ducked=false
	boss_clear.stop();boss_clear.stream=null

func _make_effect(path: String) -> AudioStreamPlayer:
	var effect := AudioStreamPlayer.new()
	var sound: AudioStreamMP3 = load(path)
	sound.loop=false;effect.stream=sound;effect.volume_db=BASE_VOLUME_DB
	effect.max_polyphony=4
	add_child(effect)
	return effect

func play_cut() -> void:
	# One stroke can successfully cut several props/cutters in the same frame.
	var frame := Engine.get_process_frames()
	if frame==last_cut_frame:return
	last_cut_frame=frame
	cut_sound.play()

func play_page_turn() -> void:
	page_sound.play()

func set_walking(walking: bool) -> void:
	if walking:
		if not walk_sound.playing:walk_sound.play()
	elif walk_sound.playing:walk_sound.stop()

func play_drag() -> void:
	drag_sound.play()

func play_landing() -> void:
	landing_sound.play()

func play_boss_roar() -> void:
	roar_sound.play()

func play_boss_fire() -> void:
	breath_sound.play()

func play_ui_click() -> void:
	ui_sound.play()

func play_clear() -> void:
	clear_sound.play()

func play_brush() -> void:
	if brush_tween!=null:brush_tween.kill();brush_tween=null
	brush_sound.volume_db=BASE_VOLUME_DB+linear_to_db(1.5)
	brush_sound.play()

func fade_out_brush() -> void:
	if brush_tween!=null:brush_tween.kill()
	brush_tween=create_tween()
	brush_tween.tween_property(brush_sound,"volume_db",-60.0,.45)
	brush_tween.tween_callback(brush_sound.stop)

func play_thunder() -> void:
	thunder_sound.play()

func play_water_splash() -> void:
	splash_sound.play()

func play_water_up() -> void:
	water_up_sound.play()

func stop_water_up() -> void:
	water_up_sound.stop()

func play_fish_splash() -> void:
	if not fish_splash_sound.playing:fish_splash_sound.play()

func play_stage_start() -> void:
	stage_start_sound.play()

func play_drop() -> void:
	drop_sound.play()

func play_cat() -> void:
	cat_sound.play()

func play_bridge_reunion() -> void:
	bridge_sound.play()

func play_gulp() -> void:
	gulp_sound.play()

func play_tiger_falling() -> void:
	falling_sound.play()

func play_gourd_tada() -> void:
	gourd_tada_sound.play()

func play_gourd_fail() -> void:
	gourd_fail_sound.play()

func play_house_collapse() -> void:
	house_collapse_sound.play()

func play_boss_collapse() -> void:
	boss_collapse_sound.play()

func fade_out_boss_default() -> void:
	if current_track!=BOSS_DEFAULT or boss_raining:return
	boss_raining=true
	if mix_tween!=null:mix_tween.kill();mix_tween=null
	boss_fade=create_tween()
	boss_fade.tween_property(self,"volume_db",-60.0,1.5)
	boss_fade.tween_callback(stop)

func play_punch(gain: float=1.0) -> void:
	punch_sound.volume_db=BASE_VOLUME_DB+linear_to_db(gain)
	punch_sound.play()
