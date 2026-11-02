extends Node3D
# Story props reuse the exact backing geometry/colors of cut paper.
var sprite:Sprite3D
var reference_pixel_size:float
var layers:Array[MeshInstance3D]=[]
static func install(target:Sprite3D,camera:Camera3D,warm_mask:=false) -> void:
	if target.has_node("PaperSticker"):return
	var effect=load("res://scripts/grid_stage/sticker_sprite.gd").new()
	effect.name="PaperSticker";target.add_child(effect);effect.configure(target,camera,warm_mask)
func configure(target:Sprite3D,camera:Camera3D,warm_mask:bool) -> void:
	sprite=target;reference_pixel_size=sprite.pixel_size
	var image:=sprite.texture.get_image()
	if image.is_compressed():image.decompress()
	if warm_mask:
		image=image.duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color:=image.get_pixel(x,y)
				color.a*=smoothstep(.025,.075,color.r-color.b);image.set_pixel(x,y,color)
	var mask:=BitMap.new();mask.create_from_image_alpha(image,.12)
	var unit_scale:=sprite.pixel_size*1000.0/camera.size
	for outline:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),2.5):
		var polygon:=PackedVector2Array()
		for point in outline:polygon.append((point-Vector2(image.get_size())*.5)*unit_scale)
		for border:bool in [false,true]:
			if not border and sprite.get_meta("border_only",false):continue
			var layer:=GridPaperCutting._make_cut_layer(polygon,sprite,border,sprite.get_meta("paper_color",GridPaperCutting.PAPER_COLOR),float(sprite.get_meta("border_width",GridPaperCutting.PAPER_BORDER_WIDTH)))
			layer.reparent(self,false);layer.scale=Vector3.ONE*camera.size/1000.0
			layer.set_meta("slice_whole",false)
			layer.material_override.render_priority=sprite.material_override.render_priority-(1 if border else 2)
			layer.set_meta("paper_material",layer.material_override)
			layers.append(layer)
func _process(_delta:float) -> void:
	scale=Vector3.ONE*sprite.pixel_size/reference_pixel_size
	if sprite.flip_h:scale.x=-scale.x
	if sprite.flip_v:scale.y=-scale.y
	var parameter=sprite.material_override.get_shader_parameter("opacity")
	var opacity:float=1.0 if parameter==null else float(parameter)
	for layer in layers:
		# Screen slicing retains this original material for dynamic opacity updates.
		var material:StandardMaterial3D=layer.get_meta("paper_material")
		material.albedo_color.a=opacity
