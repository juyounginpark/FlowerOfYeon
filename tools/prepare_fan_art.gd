extends SceneTree
# Reproducible silhouette masks for the supplied photographs; originals stay intact.
const SOURCE := "res://stages/4-빨강파랑부채/"
const OUTPUT := "res://art/minhwa/fan_story/"
func _initialize() -> void:
	for color in ["red", "blue"]:
		var image := Image.load_from_file(SOURCE + ("Unknown-3.png" if color == "red" else "Unknown-4.png"))
		var masks:Array[PackedVector2Array] = []
		var circle := PackedVector2Array()
		var center := Vector2(767, 275) if color == "red" else Vector2(770, 267)
		var radii := Vector2(202, 199) if color == "red" else Vector2(200, 190)
		for i in range(96):circle.append(center + Vector2.from_angle(i * TAU / 96) * radii)
		masks.append(circle)
		masks.append(PackedVector2Array([Vector2(487,485),Vector2(502,505),Vector2(963,184),Vector2(954,167)]))
		masks.append(PackedVector2Array([Vector2(502,491),Vector2(511,492),Vector2(533,620),Vector2(522,621)]))
		masks.append(PackedVector2Array([Vector2(522,614),Vector2(538,615),Vector2(543,643),Vector2(566,734),Vector2(555,749),Vector2(518,748),Vector2(506,736),Vector2(519,649)]))
		if color == "blue":
			masks[-1] = PackedVector2Array([Vector2(522,614),Vector2(538,615),Vector2(545,650),Vector2(566,774),Vector2(548,785),Vector2(513,783),Vector2(507,769),Vector2(520,650)])
		_save_mask(image, masks, Rect2i(484,64,486,724), color+"_fan.png")
	var emperor := Image.load_from_file(SOURCE+"remove_background-6.png")
	var outline := PackedVector2Array([Vector2(28,716),Vector2(29,652),Vector2(25,592),Vector2(30,511),Vector2(45,448),Vector2(39,330),Vector2(31,278),Vector2(40,262),Vector2(57,263),Vector2(80,216),Vector2(108,184),Vector2(157,163),Vector2(159,88),Vector2(140,58),Vector2(157,48),Vector2(175,11),Vector2(273,9),Vector2(287,37),Vector2(277,57),Vector2(255,70),Vector2(259,160),Vector2(312,181),Vector2(342,219),Vector2(363,263),Vector2(380,264),Vector2(390,278),Vector2(380,301),Vector2(383,363),Vector2(390,446),Vector2(401,519),Vector2(397,605),Vector2(390,716)])
	_save_mask(emperor,[outline],Rect2i(23,8,380,710),"emperor.png")
	var collage:=Image.load_from_file(SOURCE+"Unknown-5.png")
	var fans:Array[PackedVector2Array]=[]
	for points:Array in [
		[Vector2(800,120),Vector2(870,82),Vector2(970,76),Vector2(1060,93),Vector2(1128,135),Vector2(975,303)],
		[Vector2(1148,169),Vector2(1198,105),Vector2(1290,78),Vector2(1401,83),Vector2(1495,127),Vector2(1295,326)],
		[Vector2(855,199),Vector2(872,200),Vector2(924,289),Vector2(977,291),Vector2(1016,323),Vector2(1048,389),Vector2(1043,459),Vector2(1007,505),Vector2(933,506),Vector2(896,464),Vector2(875,411),Vector2(831,367),Vector2(809,329),Vector2(836,300),Vector2(890,288)],
		[Vector2(1164,374),Vector2(1234,334),Vector2(1342,318),Vector2(1447,342),Vector2(1534,397),Vector2(1386,538),Vector2(1409,588),Vector2(1386,607),Vector2(1339,602),Vector2(1344,565),Vector2(1210,473),Vector2(1165,416)],
		[Vector2(8,647),Vector2(75,632),Vector2(137,595),Vector2(239,557),Vector2(347,548),Vector2(355,616),Vector2(351,743),Vector2(367,771),Vector2(347,786),Vector2(320,768),Vector2(264,786),Vector2(333,867),Vector2(366,933),Vector2(351,944),Vector2(59,941),Vector2(34,950),Vector2(23,925)],
		[Vector2(450,675),Vector2(499,625),Vector2(561,598),Vector2(633,603),Vector2(692,632),Vector2(733,687),Vector2(744,758),Vector2(723,828),Vector2(681,873),Vector2(748,916),Vector2(739,930),Vector2(701,910),Vector2(449,947),Vector2(439,931),Vector2(691,895),Vector2(662,880),Vector2(595,886),Vector2(528,864),Vector2(477,827),Vector2(440,755)],
		[Vector2(802,584),Vector2(879,575),Vector2(956,597),Vector2(1027,641),Vector2(882,816),Vector2(866,826),Vector2(854,811)],
		[Vector2(1088,559),Vector2(1164,532),Vector2(1242,539),Vector2(1334,561),Vector2(1254,693),Vector2(1234,756),Vector2(1219,752),Vector2(1243,696),Vector2(1121,649)],
		[Vector2(1156,747),Vector2(1230,690),Vector2(1326,662),Vector2(1429,659),Vector2(1512,692),Vector2(1495,809),Vector2(1474,918),Vector2(1459,926),Vector2(1441,901),Vector2(1290,892),Vector2(1141,873)]
	]:fans.append(PackedVector2Array(points))
	_save_mask(collage,fans,Rect2i(0,0,1536,1024),"fan_collage.png")
	quit()
func _save_mask(source:Image,masks:Array[PackedVector2Array],rect:Rect2i,filename:String) -> void:
	var output := source.get_region(rect)
	output.convert(Image.FORMAT_RGBA8)
	for y in range(output.get_height()):
		for x in range(output.get_width()):
			var point := Vector2(rect.position + Vector2i(x,y)) + Vector2(.5,.5)
			var inside := false
			for polygon in masks:
				if Geometry2D.is_point_in_polygon(point,polygon):inside=true;break
			if not inside:output.set_pixel(x,y,Color.TRANSPARENT)
	var error := output.save_png(OUTPUT+filename)
	assert(error==OK,"Could not save "+filename)
	print("Prepared supplied art: "+filename)
