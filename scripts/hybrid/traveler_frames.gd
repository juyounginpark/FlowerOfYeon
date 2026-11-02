class_name TravelerFrames
extends RefCounted

const DIRECTIONS := ["south", "southeast", "east", "northeast", "north", "northwest", "west", "southwest"]
const ACTION_COUNTS := {"idle": 2, "walk": 8, "jump": 2, "land": 3, "play": 6}

static var cached: SpriteFrames

static func create() -> SpriteFrames:
	if cached:
		return cached
	cached = SpriteFrames.new()
	cached.remove_animation("default")
	var counts := ACTION_COUNTS
	for direction in DIRECTIONS:
		for action in counts:
			var animation: String = action + "_" + direction
			cached.add_animation(animation)
			cached.set_animation_speed(animation, 10.0 if action == "walk" else 7.0)
			cached.set_animation_loop(animation, action in ["idle", "walk"])
			for frame in counts[action]:
				cached.add_frame(animation, _texture(action, frame, direction))
	return cached

static func _texture(action: String, frame: int, direction: String) -> ImageTexture:
	var image := Image.new()
	var result := image.load_svg_from_string(svg_source(action, frame, direction), 1.0)
	assert(result == OK, "Original SVG traveler must rasterize")
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

# Authored vector source is inspectable without rasterizing or running a renderer.
static func svg_source(action: String, frame: int, direction: String) -> String:
	if direction in ["southeast", "northeast", "northwest", "southwest"]:
		return _diagonal_svg(action, frame, direction)
	return _cardinal_svg(action, frame, direction)

static func _cardinal_svg(action: String, frame: int, direction: String) -> String:
	var step := sin(frame * TAU / 8.0) * 17 if action == "walk" else 0.0
	var bob := absf(step) * 0.15
	if action == "land":
		bob = 13.0 * (1.0 - float(frame) / 3.0)
	if action == "jump":
		step = 11.0
	var side := direction in ["east", "west"]
	var back := direction == "north"
	var head_x := 201.0 if side else 192.0
	var robe_left := 150.0 if side else 134.0
	var robe_right := 234.0 if side else 250.0
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='384' height='512' viewBox='0 0 384 512'><defs><linearGradient id='robe' x1='0' x2='1'><stop stop-color='#cbd6be'/><stop offset='.45' stop-color='#f4efdc'/><stop offset='1' stop-color='#e3dfca'/></linearGradient><linearGradient id='hat' x1='0' x2='1'><stop stop-color='#c8ad75'/><stop offset='.5' stop-color='#eee2b6'/><stop offset='1' stop-color='#dac79a'/></linearGradient></defs>"
	if direction == "west":
		svg += "<g transform='translate(384 0) scale(-1 1)'>"
	svg += "<path d='M%d 435 L%d 477 L%d 480' stroke='#596863' stroke-width='16' stroke-linecap='round' fill='none'/>" % [175 + step, 174 + step, 165 + step]
	svg += "<path d='M%d 435 L%d 477 L%d 480' stroke='#475b56' stroke-width='16' stroke-linecap='round' fill='none'/>" % [207 - step, 208 - step, 218 - step]
	svg += "<path d='M%d %d Q191 %d %d %d L%d 448 Q192 465 %d 448 Z' fill='url(#robe)' stroke='#7c8e7d' stroke-width='3'/>" % [160, 260 + bob, 247 + bob, 225, 260 + bob, robe_right - step * .2, robe_left - step * .2]
	svg += "<path d='M165 %d L191 364 L159 441 M221 %d L192 365 L224 443' fill='none' stroke='#c0cdb6' stroke-width='5'/>" % [269 + bob, 269 + bob]
	svg += "<path d='M151 347 Q193 358 237 347 L235 366 Q190 378 149 366 Z' fill='#658d84'/>"
	svg += "<path d='M216 359 Q234 397 %d 432 L226 438 Q212 402 203 361 Z' fill='#86aaa0'/>" % [242 + step * .35]
	var hand_y := 328.0 if action == "play" else 355.0 + step * .5
	svg += "<path d='M160 %d Q132 310 145 %d M224 %d Q246 313 233 %d' fill='none' stroke='#e6e4cf' stroke-width='24' stroke-linecap='round'/>" % [279 + bob, hand_y, 279 + bob, hand_y - step]
	svg += "<ellipse cx='%d' cy='%d' rx='28' ry='35' fill='#a98b6c'/>" % [head_x, 235 + bob]
	if not back:
		svg += "<path d='M%d %d L%d %d' stroke='#444c43' stroke-width='4' stroke-linecap='round'/>" % [head_x + 10, 239 + bob, head_x + 14, 239 + bob]
	if back:
		svg += "<path d='M165 %d Q192 %d 219 %d L214 268 L170 268 Z' fill='#59645b'/>" % [220 + bob, 209 + bob, 220 + bob]
	svg += "<path d='M125 %d Q157 %d 192 %d Q224 %d 260 %d Q194 %d 125 %d Z' fill='url(#hat)' stroke='#a99169' stroke-width='3'/>" % [220 + bob, 182 + bob, 111 + bob, 181 + bob, 220 + bob, 238 + bob, 220 + bob]
	svg += "<path d='M135 %d Q192 %d 250 %d' stroke='#f7edcf' stroke-width='5' fill='none'/>" % [218 + bob, 229 + bob, 218 + bob]
	svg += "<path d='M150 %d Q147 266 171 287' fill='none' stroke='#87947c' stroke-width='4'/>" % [224 + bob]
	if action == "play":
		svg += "<path d='M153 321 L190 337 L231 320 L231 365 L190 351 L153 367 Z' fill='#b1844e' stroke='#6b6553' stroke-width='3'/><path d='M151 316 L151 373 M234 315 L234 371' stroke='#e8d8ae' stroke-width='7'/>"
		svg += "<path d='M226 307 L%d %d' stroke='#735b40' stroke-width='6' stroke-linecap='round'/>" % [253 + frame * 2, 287 + frame * 5]
	if direction == "west":
		svg += "</g>"
	svg += "</svg>"
	return svg

# Three-quarter artwork is constructed in its own projected anatomy, never a
# rotated cardinal bitmap. Rear views put the instrument BEHIND the torso;
# the fixed left-hip sash stays anatomically asymmetric in both handed views.
static func _diagonal_svg(action: String, frame: int, direction: String) -> String:
	var right := direction in ["southeast", "northeast"]
	var rear := direction in ["northeast", "northwest"]
	var sign_x := 1.0 if right else -1.0
	var stride := sin(float(frame)*TAU/8.0)*15.0 if action == "walk" else 0.0
	if action == "jump": stride = 10.0
	var bob := absf(stride)*0.13
	if action == "land": bob = 12.0*(1.0-float(frame)/3.0)
	var head := 192.0+sign_x*(9.0 if rear else 15.0)
	var far_foot := 192.0-sign_x*16.0-stride*0.65
	var near_foot := 192.0+sign_x*17.0+stride
	var near_shoulder := 192.0+sign_x*31.0
	var far_shoulder := 192.0-sign_x*21.0
	var hand_y := 327.0 if action == "play" else 355.0-stride*0.45
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='384' height='512' viewBox='0 0 384 512'>"
	# Far sole is higher in the projected ground plane; near sole still ends at488.
	svg += "<path d='M%.1f 431 L%.1f 465 L%.1f 472' fill='none' stroke='#475b56' stroke-width='14' stroke-linecap='round'/>" % [far_foot,far_foot,far_foot+sign_x*9]
	svg += "<path d='M%.1f 440 L%.1f 475 L%.1f 480' fill='none' stroke='#596863' stroke-width='16' stroke-linecap='round'/>" % [near_foot,near_foot,near_foot+sign_x*12]
	var drum := "<path d='M%.1f 316 L%.1f 332 L%.1f 323 L%.1f 363 L%.1f 348 L%.1f 359 Z' fill='#b1844e' stroke='#6b6553' stroke-width='3'/>" % [head-32,head+2,head+35,head+35,head+2,head-32]
	drum += "<path d='M%.1f 314 L%.1f 361 M%.1f 321 L%.1f 366' stroke='#e8d8ae' stroke-width='6'/>" % [head-32,head-32,head+35,head+35]
	if rear and action == "play": svg += drum
	svg += "<path d='M%.1f %.1f Q192 %.1f %.1f %.1f L%.1f 447 Q195 464 %.1f 441 Z' fill='%s' stroke='#7c8e7d' stroke-width='3'/>" % [far_shoulder,267+bob,251+bob,near_shoulder,263+bob,192+sign_x*53-stride*.15,192-sign_x*41-stride*.15,"#cbd6be" if rear else "#eee9d6"]
	# Receding side panel, asymmetrical shoulder seam and diagonal sash.
	svg += "<path d='M%.1f %.1f L%.1f 347 L%.1f 447 L%.1f 438 Z' fill='#b4c3ad'/>" % [far_shoulder,270+bob,192-sign_x*26,192-sign_x*41-stride*.15,192-sign_x*11]
	svg += "<path d='M%.1f 341 Q194 357 %.1f 351 L%.1f 369 Q191 372 %.1f 356 Z' fill='#658d84'/>" % [192-sign_x*32,192+sign_x*39,192+sign_x*40,192-sign_x*34]
	svg += "<path d='M177 359 Q167 400 %.1f 436 L181 440 Q190 401 190 363 Z' fill='#86aaa0'/>" % [168+stride*.25]
	svg += "<path d='M%.1f %.1f Q%.1f 310 %.1f %.1f' fill='none' stroke='#c8d2bc' stroke-width='18' stroke-linecap='round'/>" % [far_shoulder,279+bob,far_shoulder-sign_x*12,far_shoulder-sign_x*8,hand_y-9]
	if not rear and action == "play": svg += drum
	svg += "<path d='M%.1f %.1f Q%.1f 313 %.1f %.1f' fill='none' stroke='#e6e4cf' stroke-width='24' stroke-linecap='round'/>" % [near_shoulder,280+bob,near_shoulder+sign_x*14,near_shoulder+sign_x*7,hand_y]
	svg += "<ellipse cx='%.1f' cy='%.1f' rx='25' ry='34' fill='#a98b6c'/>" % [head,235+bob]
	if rear:
		svg += "<path d='M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f 267 Q%.1f 280 %.1f 263 Z' fill='#59645b'/>" % [head-26,218+bob,head,207+bob,head+25,221+bob,head+19,head-3,head-24]
		svg += "<ellipse cx='%.1f' cy='%.1f' rx='6' ry='9' fill='#b29878'/>" % [head+sign_x*23,245+bob]
	else:
		svg += "<path d='M%.1f %.1f L%.1f %.1f L%.1f %.1f' fill='none' stroke='#88765e' stroke-width='3'/>" % [head+sign_x*17,237+bob,head+sign_x*27,249+bob,head+sign_x*16,252+bob]
		svg += "<path d='M%.1f %.1f L%.1f %.1f' stroke='#444c43' stroke-width='4' stroke-linecap='round'/>" % [head+sign_x*6,239+bob,head+sign_x*12,240+bob]
	var peak := 192.0-sign_x*(9.0 if rear else 4.0)
	svg += "<path d='M128 %.1f Q155 %.1f %.1f %.1f Q222 %.1f 258 %.1f Q%.1f %.1f 128 %.1f Z' fill='%s' stroke='#a99169' stroke-width='3'/>" % [219+bob,183+bob,peak,112+bob,180+bob,223+bob,head,242+bob,219+bob,"#d3c294" if rear else "#e6d7aa"]
	svg += "<path d='M%.1f %.1f Q%.1f %.1f %.1f %.1f' fill='none' stroke='#f7edcf' stroke-width='5'/>" % [137,219+bob,head,235+bob,249,222+bob]
	svg += "<path d='M%.1f %.1f Q%.1f 265 %.1f 285' fill='none' stroke='#87947c' stroke-width='4'/>" % [head-sign_x*27,228+bob,head-sign_x*31,head-sign_x*12]
	if action == "play":
		svg += "<path d='M%.1f 318 L%.1f %.1f' stroke='#735b40' stroke-width='6' stroke-linecap='round'/>" % [near_shoulder+sign_x*7,near_shoulder+sign_x*(23+frame*2),289+frame*5]
	return svg+"</svg>"
