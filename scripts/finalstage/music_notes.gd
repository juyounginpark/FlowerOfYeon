extends Node2D
## Small vector notes float out of the band and fade, without font dependencies.
var world: GridStageWorld
var band: Node3D
var notes: Array[Dictionary] = []
var looping := false
var repeat_clock := 0.0
var burst := 0

func configure(owner_world: GridStageWorld,source: Node3D) -> void:
	world=owner_world;band=source
	hide()

func emit_notes() -> void:
	for index in range(4):
		notes.append({"age":-index*.12,"offset":float((index*23+burst*17)%75)-37.0,"phase":float(index+burst)})
	burst+=1;show()
	queue_redraw()

func _process(delta: float) -> void:
	if world.paused or world.transition.active:return
	if looping:
		repeat_clock+=delta
		if repeat_clock>=1.3:repeat_clock=0;emit_notes()
	for note in notes.duplicate():
		note.age+=delta
		if float(note.age)>=1.8:notes.erase(note)
	visible=not notes.is_empty()
	if visible:queue_redraw()

func _draw() -> void:
	var frame := get_viewport_rect().size
	var origin := world.camera.unproject_position(band.global_position)-Vector2(0,frame.y*.08)
	var unit := frame.y/900.0
	for note in notes:
		var age: float = note.age
		if age<0:continue
		var alpha := smoothstep(0,.2,age)*(1-smoothstep(1.1,1.8,age))
		var point := origin+Vector2(float(note.offset)+sin(age*3+float(note.phase))*12,-age*60)*unit
		var color := Color(1.0,.89,.58,alpha)
		draw_set_transform(point,-.1,Vector2.ONE*unit)
		draw_circle(Vector2.ZERO,4.5,color)
		draw_line(Vector2(3,0),Vector2(3,-22),color,2.5)
		draw_polyline(PackedVector2Array([Vector2(3,-22),Vector2(11,-17),Vector2(10,-11)]),color,2.5)
