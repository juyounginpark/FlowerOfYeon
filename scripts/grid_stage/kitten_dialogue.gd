extends Node3D
var world:GridStageWorld
var actor:Sprite3D
var active:=false
var elapsed:=0.0
var bubble:Control
const LINE:="배고프다옹\n생선이 좋다옹"
const HEAD_HEIGHT:=1.5
var pursuing:=false

func configure(owner_world:GridStageWorld) -> void:
	world=owner_world;position=Vector3(.3,0,1.35)
	actor=preload("res://scripts/grid_stage/minhwa_idle_sprite.gd").new()
	actor.name="BabyKitten";add_child(actor)
	actor.configure(world,"res://art/minhwa/stage5_rework/kitten_joseon.png",1.30,Vector3.ZERO)
	var overlay:=CanvasLayer.new();overlay.layer=8;add_child(overlay)
	bubble=preload("res://scripts/grid_stage/speech_bubble.gd").new()
	bubble.automatic=false;overlay.add_child(bubble);bubble.body.text=LINE;bubble.fit_to_text();bubble.hide()

func can_interact() -> bool:
	if pursuing or world.paused or world.completed or world.transition.active or world.player.input_locked:return false
	var distance:=world.player.global_position-global_position
	return Vector2(distance.x,distance.z).length()<=1.65 and absf(distance.y)<.3 and world.player.is_on_floor()

func begin() -> bool:
	if not can_interact():return false
	if active:return true
	active=true;elapsed=0;return true

func cancel() -> void:
	active=false;elapsed=0;bubble.hide()

func _process(delta:float) -> void:
	if world==null:return
	if active and not world.paused:
		elapsed+=delta
		bubble.modulate.a=minf(elapsed/.18,1.0)*(1.0-clampf((elapsed-3.0)/.8,0,1))
		if elapsed>=3.8:cancel()
	bubble.position=world.camera.unproject_position(global_position+Vector3.UP*HEAD_HEIGHT)-Vector2(bubble.size.x*.5,bubble.size.y)
	bubble.visible=active and not world.transition.active and not world.camera.is_position_behind(global_position)
