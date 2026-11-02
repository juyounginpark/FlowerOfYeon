extends RefCounted
# Separate trim geometry, measured in metres, follows the true face outline.
static func build(planes:Dictionary) -> Array:
	var lines:=SurfaceTool.new();lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners:=SurfaceTool.new();corners.begin(Mesh.PRIMITIVE_TRIANGLES)
	var line_count:int=0
	var corner_count:int=0
	for group:Dictionary in planes.values():
		var cells:Dictionary=group.cells
		var runs:Dictionary={}
		for cell:Vector2i in cells:
			for side:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if cells.has(cell+side):continue
				var horizontal:bool=side.y!=0
				var fixed:int=(cell.y+maxi(0,side.y)) if horizontal else (cell.x+maxi(0,side.x))
				var inward:int=-side.y if horizontal else -side.x
				var key:String="%s/%d/%d"%[horizontal,fixed,inward]
				if not runs.has(key):runs[key]={"horizontal":horizontal,"fixed":fixed,"inward":inward,"steps":[]}
				runs[key].steps.append(cell.x if horizontal else cell.y)
			if group.normal.y>.5:
				for dx:int in [-1,1]:
					for dy:int in [-1,1]:
						if cells.has(cell+Vector2i(dx,0)) or cells.has(cell+Vector2i(0,dy)):continue
						# A fixed-size corner ornament, inset from both edges.
						var origin:=Vector2(cell.x+maxi(dx,0),cell.y+maxi(dy,0))*.2-Vector2(dx,dy)*.115
						_quad(corners,group,origin,Vector2(-dx,0)*.22,Vector2(0,-dy)*.22)
						corner_count+=1
		for run:Dictionary in runs.values():
			run.steps.sort()
			var first:int=run.steps[0]
			var previous:int=first
			for i:int in range(1,run.steps.size()+1):
				if i<run.steps.size() and int(run.steps[i])==previous+1:
					previous=run.steps[i];continue
				for inset:float in [.045,.090]:
					var fixed:float=float(run.fixed)*.2+float(run.inward)*inset
					var lo:float=first*.2+inset
					var hi:float=(previous+1)*.2-inset
					if hi<=lo:continue
					var a:=Vector2(lo,fixed) if run.horizontal else Vector2(fixed,lo)
					var b:=Vector2(hi,fixed) if run.horizontal else Vector2(fixed,hi)
					_stroke(lines,group,a,b,.012 if inset<.06 else .008)
					line_count+=1
				if i<run.steps.size():first=run.steps[i];previous=first
	return [lines.commit() if line_count>0 else null,corners.commit() if corner_count>0 else null]
static func _point(group:Dictionary,p:Vector2) -> Vector3:
	return group.normal*(float(group.plane)*.2+.006)+group.u*p.x+group.v*p.y
static func _stroke(surface:SurfaceTool,group:Dictionary,a:Vector2,b:Vector2,width:float) -> void:
	var side:Vector2=(b-a).normalized().orthogonal()*width*.5
	_quad(surface,group,a-side,b-a,side*2.0)
static func _quad(surface:SurfaceTool,group:Dictionary,origin:Vector2,u:Vector2,v:Vector2) -> void:
	for uv:Vector2 in [Vector2.ZERO,Vector2.ONE,Vector2.RIGHT,Vector2.ZERO,Vector2.DOWN,Vector2.ONE]:
		surface.set_normal(group.normal);surface.set_uv(uv)
		surface.add_vertex(_point(group,origin+u*uv.x+v*uv.y))
