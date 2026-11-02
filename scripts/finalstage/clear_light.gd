extends Node2D
## Warm body light before the existing final-stage clear transition.
var world: GridStageWorld
var clock := 0.0

func configure(owner_world: GridStageWorld) -> void:
	world=owner_world
	hide()

func _process(delta: float) -> void:
	if not world.completed or world.paused:return
	clock+=delta
	var strength := smoothstep(0,1,clampf(clock/1.2,0,1))
	var material: Material = world.player.sprite.material_override
	if material is ShaderMaterial:material.set_shader_parameter("clear_glow",strength)
	var proxy:Sprite2D=world.transition.proxy
	if proxy.material is ShaderMaterial:
		proxy.material.set_shader_parameter("clear_glow",strength)
	visible=world.player.sprite.is_visible_in_tree() or (world.transition.carried and proxy.is_visible_in_tree())
	queue_redraw()

func _draw() -> void:
	if not world.completed:return
	var center := world.camera.unproject_position(world.player.global_position+Vector3.UP*.85)
	if world.transition.carried and world.transition.proxy.is_visible_in_tree():
		center=world.transition.proxy.global_position
	var radius := get_viewport_rect().size.y/world.camera.size*1.15
	var strength := smoothstep(0,1,clampf(clock/1.2,0,1))
	draw_set_transform(center,0,Vector2(.65,1))
	for index in range(12,0,-1):
		var fraction := index/12.0
		draw_circle(Vector2.ZERO,radius*fraction,Color(1.0,.90,.56,.055*strength*(1.1-fraction)))
