extends RefCounted
# CPU-only, private images. Never access scene nodes or render resources here.
static func compose(frame:Image,paper:Image) -> Image:
	if paper.is_compressed():paper.decompress()
	var page:=paper.get_region(Rect2i(int(paper.get_width()*.05),int(paper.get_height()*.08),int(paper.get_width()*.45),int(paper.get_height()*.82)))
	page.convert(Image.FORMAT_RGBA8)
	var art:Image=frame.duplicate()
	var width:=int(page.get_width()*.94)
	var height:=int(page.get_height()*.95)
	var factor:=maxf(float(width)/frame.get_width(),float(height)/frame.get_height())
	art.resize(ceili(frame.get_width()*factor),ceili(frame.get_height()*factor),Image.INTERPOLATE_LANCZOS)
	art=art.get_region(Rect2i((art.get_width()-width)/2,(art.get_height()-height)/2,width,height))
	var inset:=Vector2i(int(page.get_width()*.03),int(page.get_height()*.025))
	# Feather the actual screenshot into hanji; preserve the map's final pose.
	for y in range(height):
		for x in range(width):
			var distance:=minf(minf(x,width-1-x),minf(y,height-1-y))
			# A broad, irregular wash dissolves into the underlying paper.
			# Keep the outer edge completely transparent, with no rectangular seam.
			var wash:=sin(x*.047+y*.019)*4+sin(y*.071-x*.013)*3
			var feather:=smoothstep(0,minf(width,height)*.14,maxf(0,distance-9+wash))
			var ink:=art.get_pixel(x,y)
			var grain:=page.get_pixel(inset.x+x,inset.y+y)
			# Antique pigment lives only in the book composite, never in gameplay.
			var luminance:=ink.r*.299+ink.g*.587+ink.b*.114
			ink=Color(luminance,luminance,luminance,1).lerp(ink,.32)
			ink=Color(ink.r*.78+.16,ink.g*.73+.14,ink.b*.62+.11,1)
			ink=ink.lerp(grain,.22);ink.a=feather*.94
			art.set_pixel(x,y,ink)
	page.blend_rect(art,Rect2i(Vector2i.ZERO,art.get_size()),inset)
	return page

