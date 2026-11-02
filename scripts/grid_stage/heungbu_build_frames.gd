extends SceneTree
## Run with Godot --headless --path . --script res://scripts/grid_stage/heungbu_build_frames.gd
## Source 4x2 cells overlap their nominal boundaries; keep each bird's connected
## silhouette and align all eight frames on its carried fruit. Originals untouched.
const ANCHORS={
	7:[Vector2i(415,294),Vector2i(404,292),Vector2i(391,291),Vector2i(354,291),Vector2i(389,268),Vector2i(405,267),Vector2i(403,267),Vector2i(377,270)],
	6:[Vector2i(417,310),Vector2i(418,311),Vector2i(403,311),Vector2i(386,310),Vector2i(415,277),Vector2i(417,277),Vector2i(404,277),Vector2i(397,276)]}
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://art/stage7/generated")
	for number:int in [6,7]:
		var original:=Image.load_from_file("res://art/stage7/%d.png"%number)
		original.convert(Image.FORMAT_RGBA8)
		var sheets:Array[Image]=[Image.create(2048,1024,false,Image.FORMAT_RGBA8),Image.create(2048,1024,false,Image.FORMAT_RGBA8)]
		for frame:int in 8:
			var col:int=frame%4;var row:int=frame/4
			var origin:int=col*original.get_width()/4
			var left:=maxi(0,origin-24);var top:int=row*original.get_height()/2
			var tile:=original.get_region(Rect2i(left,top,mini(original.get_width(),origin+490)-left,(row+1)*original.get_height()/2-top))
			var w:=tile.get_width();var h:=tile.get_height();var data:=tile.get_data()
			# Exclude the previous cell's fruit and the next cell's wing, whose
			# faint alpha fringe can connect across the nominal cell boundary.
			var anchor:Vector2i=ANCHORS[number][frame]
			for y:int in h:
				for x:int in w:
					var local_x:=x+left-origin
					if (col>0 and local_x<(45 if number==6 else 20) and y>220 and y<350) or (local_x>anchor.x+55 and y<anchor.y-55):data[(y*w+x)*4+3]=0
			var visited:=PackedByteArray();visited.resize(w*h)
			var largest:=PackedInt32Array()
			for seed:int in w*h:
				if visited[seed] or data[seed*4+3]<8:continue
				visited[seed]=1
				var pending:=PackedInt32Array([seed]);var cursor:=0
				while cursor<pending.size():
					var p:=pending[cursor];cursor+=1
					var x:int=p%w;var y:int=p/w
					for offset:Vector2i in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
						var next:=Vector2i(x,y)+offset
						if next.x<0 or next.x>=w or next.y<0 or next.y>=h:continue
						var q:=next.y*w+next.x
						if not visited[q] and data[q*4+3]>=8:visited[q]=1;pending.append(q)
				if pending.size()>largest.size():largest=pending
			var keep:=PackedByteArray();keep.resize(w*h)
			for p:int in largest:keep[p]=1
			for p:int in w*h:
				if not keep[p] or data[p*4+3]==0:
					for channel:int in 4:data[p*4+channel]=0
			tile=Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,data)
			var aligned:=Image.create(512,512,false,Image.FORMAT_RGBA8)
			aligned.blit_rect(tile,Rect2i(0,0,w,h),Vector2i(410-anchor.x-origin+left,300-anchor.y))
			var empty:=aligned.duplicate() as Image
			var radius:=62.0 if number==6 else 49.0
			for y:int in range(240,369):
				for x:int in range(348,473):
					if Vector2((x-410)/radius,(y-308)/60.0).length_squared()<=1 or (x>=392 and x<=427 and y<=270) or (number==6 and x>=425):empty.set_pixel(x,y,Color(0,0,0,0))
			sheets[0].blit_rect(aligned,Rect2i(0,0,512,512),Vector2i(col*512,row*512))
			sheets[1].blit_rect(empty,Rect2i(0,0,512,512),Vector2i(col*512,row*512))
		for index:int in 2:sheets[index].save_png("res://art/stage7/generated/%d_%s.png"%[number,"carrying" if index==0 else "empty"])
		print("Prepared eight aligned carrying/empty frames: ",number)
	quit()
