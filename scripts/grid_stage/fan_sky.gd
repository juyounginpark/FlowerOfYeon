extends Node3D
# An inserted cinematic world owned by Stage4, never a selectable map.
var camera:Camera3D
var paused:=false
var backdrop:Node3D
var ui:CanvasLayer
var storm_environment:Environment
func configure(source:Camera3D) -> void:
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("eee1c7")
	storm_environment=environment.environment
	add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=source.size;camera.cull_mask=1;camera.current=true;camera.far=300
	add_child(camera);camera.global_transform=source.global_transform
	backdrop=preload("res://scripts/grid_stage/sky_backdrop.gd").new()
	add_child(backdrop);backdrop.configure(camera,8)
	for entry:Dictionary in backdrop.clouds:
		entry.depth=float(entry.depth)+60
		entry.visual.no_depth_test=false;entry.visual.render_priority=-10
		if entry.visual.material_override is ShaderMaterial:entry.visual.material_override.render_priority=-10
	for entry:Dictionary in backdrop.mountains:entry.depth=float(entry.depth)+60
	backdrop._layout()
	ui=CanvasLayer.new();ui.layer=8;add_child(ui)
func sync(source:Camera3D,frozen:bool) -> void:
	paused=frozen;camera.global_transform=source.global_transform;camera.size=source.size

func set_storm_flash(amount:float) -> void:
	storm_environment.background_color=Color("24283f").lerp(Color("fff1c5"),amount)
	for entry:Dictionary in backdrop.clouds:
		var opacity:float=entry.visual.modulate.a
		entry.visual.modulate=Color("52576d").lerp(Color("fff4dd"),amount)
		entry.visual.modulate.a=opacity
