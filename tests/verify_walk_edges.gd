extends SceneTree
var player:WorldPilgrim
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:push_error(message);quit(1);assert(value,message)
func settle(count:int) -> void:
	for tick in count:await physics_frame
func run() -> void:
	for action in ["right","left","back","forward","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,10,10);camera.look_at(Vector3.ZERO)
	var floor_:=AnimatableBody3D.new();floor_.collision_layer=4;floor_.sync_to_physics=false;stage.add_child(floor_)
	var shape:=BoxShape3D.new();shape.size=Vector3(4,.5,4)
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=-.25;floor_.add_child(collision)
	player=WorldPilgrim.new();player.route=WorldRoute.new();player.tower_root=stage;player.camera=camera
	player.camera_relative_movement=true;stage.add_child(player);player.platform_floor_layers=4
	for direction:Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		player.position=Vector3(0,.02,0);player.velocity=Vector3.ZERO;await settle(10)
		Input.action_press("right" if direction.x>0 else "left",absf(direction.x))
		Input.action_press("back" if direction.y>0 else "forward",absf(direction.y))
		await settle(100)
		for action in ["right","left","back","forward"]:Input.action_release(action)
		check(player.is_on_floor() and player.position.y>-.02,"walking must not leave platform: "+str(direction))
		check(absf(player.position.x)<2.0 and absf(player.position.z)<2.0,"feet remain inside edge: "+str(player.position))
	player.position=Vector3(0,.02,0);player.velocity=Vector3.ZERO;await settle(10)
	for tick in 60:floor_.position.y+=.01;await physics_frame
	check(player.position.y>.5 and player.is_on_floor(),"moving lift still carries player")
	Input.action_press("jump");await settle(2);Input.action_release("jump");await settle(8)
	check(player.position.y>floor_.position.y+.3 and not player.is_on_floor(),"intentional jump remains available")
	print("PASS: %d edge protection / lift / jump checks"%checks)
	quit()
