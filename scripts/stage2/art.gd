extends RefCounted
## Decode and split once; restarting never reads PNGs or copies atlas pixels.
static var cache: Dictionary = {}
static var manifest: Dictionary = {}
const ROOT := "res://art/stage2/minhwa/"

static func frames(asset: String) -> Array:
	if cache.has(asset): return cache[asset]
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "frames.json"))
	var path := ROOT + asset + ".png"
	var source: Image
	if FileAccess.file_exists(path + ".import") or not FileAccess.file_exists(path):
		var texture := load(path) as Texture2D
		if texture != null: source = texture.get_image()
	if source == null:
		source = Image.load_from_file(path)
	if source.is_compressed(): source.decompress()
	var result: Array = []
	for entry: Dictionary in manifest[asset]:
		var r: Array = entry.rect
		var b: Array = entry.painted
		var image := source.get_region(Rect2i(r[0], r[1], r[2], r[3]))
		result.append({"texture": ImageTexture.create_from_image(image), "image": image,
			"painted": Rect2(b[0], b[1], b[2], b[3])})
	cache[asset] = result
	return result

static func texture(asset: String) -> Texture2D:
	return frames(asset)[0].texture

static func sliced_sprite(sprite: SpriteBase3D, texture_: Texture2D, upright: bool = true) -> void:
	var ink := sprite.material_override as ShaderMaterial
	if ink == null:
		ink = ShaderMaterial.new()
		ink.shader = preload("res://shaders/grid_traveler_slice.gdshader")
		sprite.material_override = ink
		# Existing compositor routes story actors through every terrain depth band.
		sprite.set_meta("story_actor", true)
	ink.set_shader_parameter("upright_card", upright)
	ink.set_shader_parameter("frame_texture", texture_.atlas if texture_ is AtlasTexture else texture_)

	var outline := Color(0,0,0,0)
	if sprite.name == "BathingFairy": outline = Color("f5ce42")
	elif sprite.name == "Stage2Woodcutter": outline = Color("5aaa56")
	ink.set_shader_parameter("outline_color", outline)
