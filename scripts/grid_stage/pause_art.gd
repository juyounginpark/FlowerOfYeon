extends RefCounted
const SHEET:="res://art/ui/pause/controls.png"
# Bounds in the original 1536x1024 generated atlas; blank areas retain alpha.
const REGIONS:={
	"pause":Rect2(36,62,466,458),
	"sound":Rect2(534,62,466,458),
	"close":Rect2(1036,62,468,458),
	"button":Rect2(40,648,862,266),
	"empty":Rect2(978,562,144,402),
	"filled":Rect2(1284,562,146,402),
}
static func texture(kind:String) -> AtlasTexture:
	var result:=AtlasTexture.new()
	result.atlas=load(SHEET);result.region=REGIONS[kind]
	result.filter_clip=true
	return result
