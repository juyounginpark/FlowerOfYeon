class_name MinhwaHandPoses
extends Node2D
# Complete anatomically authored poses replace the old independently twisted
# fingers. An optional aligned front mask only covers the supported lower body.
var front:=false
var curl:=0.0
var opened:Sprite2D
var cupped:Sprite2D
func configure(path:String) -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary:return
	for pose in ["open","cupped"]:
		var key:String=pose+"_front" if front else pose
		if not manifest.has(key):continue
		var data:Dictionary=manifest[key]
		var sprite:=Sprite2D.new();sprite.texture=load(str(data.texture));sprite.centered=false
		var pivot:Array=data.get("pivot",[0,0]);var size_scale:float=float(data.get("scale",1))
		sprite.position=-Vector2(pivot[0],pivot[1])*size_scale
		sprite.scale=Vector2.ONE*size_scale
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(sprite)
		if pose=="open":opened=sprite
		else:cupped=sprite
	apply_pose()
func apply_pose() -> void:
	if is_instance_valid(opened):opened.modulate.a=1-curl
	if is_instance_valid(cupped):cupped.modulate.a=curl
