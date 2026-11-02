extends Node3D
## Reuse the existing shoreline painter on selected lower rock contours.
var world: GridStageWorld
var shore
var contacts: Array[Dictionary] = []
var layout_state: Array = []

func configure(owner_world: GridStageWorld, artwork: Node3D) -> void:
	world = owner_world
	for child in world.stage_root.get_children():
		if child is GridCollageLayers: shore = child.edge_water
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/stage1/dano/rock-wave-contacts.json"))
	var player_mask: SubViewport
	for child in world.stage_root.get_children():
		if child.get("wave_mask") is SubViewport: player_mask = child.get("wave_mask")
	for node_name in ["UpperLeftRock", "LowerLeftRock", "RightRock", "RestingWoman", "BathingWomen"]:
		var rock := artwork.get_node(node_name) as Sprite3D
		var swimming := bool(rock.get_meta("swimming",false))
		var profile: Array
		if swimming:
			var waterline := float(rock.get_meta("waterline"))
			profile = [[.14,waterline],[.52,waterline+.01],[.9,waterline]]
		else:
			profile = profiles.right.points if node_name == "RightRock" else profiles.left.points
		for i in range(profile.size() - 1):
			var visual := MeshInstance3D.new()
			visual.name = node_name + "Foam%d" % i
			visual.mesh = shore.patches[0].visual.mesh
			visual.set_meta("slice_whole", true)
			visual.set_meta("boundary_wave", true)
			visual.set_meta("screen_band", 11)
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.extra_cull_margin = 0.1
			var ink := ShaderMaterial.new()
			ink.shader = preload("res://shaders/grid_shore_wave.gdshader")
			ink.render_priority = 109 if swimming else 100
			ink.set_shader_parameter("map_silhouette", shore.map_mask.texture)
			ink.set_shader_parameter("walking_silhouette", shore.top_mask.texture)
			ink.set_shader_parameter("botanical_silhouette", shore.botanical_mask.texture)
			ink.set_shader_parameter("player_silhouette", player_mask.get_texture())
			ink.set_shader_parameter("protect_player", true)
			ink.set_shader_parameter("amplitude", 0.025 if swimming else 0.045)
			ink.set_shader_parameter("rate", 0.45 + float(i % 3) * 0.025)
			ink.set_shader_parameter("phase", float(contacts.size()) * 1.37)
			ink.set_shader_parameter("opacity", 0.92)
			visual.material_override = ink
			add_child(visual)
			var slot: int = shore.patches.size()
			shore.patches.append({"visual": visual, "ink": ink})
			contacts.append({"rock": rock, "a": Vector2(profile[i][0], profile[i][1]),
				"b": Vector2(profile[i+1][0], profile[i+1][1]), "slot": slot, "swimming":swimming})
	_layout()

func _point(rock: Sprite3D, uv: Vector2) -> Vector3:
	var pixel := (uv - Vector2(0.5, 0.5)) * rock.texture.get_size()
	return rock.global_transform * Vector3(pixel.x * rock.pixel_size, -pixel.y * rock.pixel_size, 0)

func _layout() -> void:
	var camera := world.camera
	var frame := get_viewport().get_visible_rect().size
	var state: Array = [frame, camera.global_transform, camera.size]
	for contact in contacts: state.append(contact.rock.global_transform)
	if state == layout_state: return
	layout_state = state
	for contact in contacts:
		var a := _point(contact.rock, contact.a)
		var b := _point(contact.rock, contact.b)
		var pa := camera.unproject_position(a)
		var pb := camera.unproject_position(b)
		var line := pb - pa
		var outward := Vector2(-line.y, line.x).normalized()
		# Existing _place keeps the native foam aspect and anchors it at the edge.
		shore._place(contact.slot, pa, pb, outward, (a+b)*0.5, frame, 1.1 if contact.swimming else 2.1)
		shore.patches[contact.slot]["surge_units"] = (3.0 if contact.swimming else 5.0)*camera.size/frame.y

func _process(_delta: float) -> void:
	if world.paused: return
	_layout()
	# Shared advance() animates every registered patch, using the same paused clock.
	# Stagger the short splash pulses so the whole rock does not swell at once.
	for contact in contacts:
		var patch: Dictionary = shore.patches[contact.slot]
		patch["pulse_start"] = shore.elapsed - fposmod(shore.elapsed + float(contact.slot)*0.37, 4.8)
