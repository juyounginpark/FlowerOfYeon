extends Node
## Optional telemetry. No gameplay state is owned or changed here.
var world: Node
var level := 0
var attempt_open := false
var session_open := false
var focused := true
var last_tick := 0
var total_ms := 0
var level_ms := 0
var sent_ms := 0
var checkpoint_ms := 0
var snapshot_tick := 0
var level_pending := false
var session_announced := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(OS.has_feature("web"))
	last_tick = Time.get_ticks_msec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.FlowerAnalytics?.initialized()")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_sample()
		focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		last_tick = Time.get_ticks_msec()

func _playing() -> bool:
	if not session_open or not attempt_open or not focused or get_tree().paused:
		return false
	if not is_instance_valid(world) or not world.is_inside_tree() or not world.can_process():
		return false
	if world.paused or world.completed or is_instance_valid(world.ending):
		return false
	if not is_instance_valid(world.player) or world.player.paused or world.player.input_locked:
		return false
	return not (is_instance_valid(world.transition) and world.transition.active)

func _sample() -> void:
	var now := Time.get_ticks_msec()
	if _playing():
		# Do not count long browser suspension gaps as play.
		var elapsed_ms := clampi(now - last_tick, 0, 1000)
		total_ms += elapsed_ms
		level_ms += elapsed_ms
	last_tick = now

func _process(_delta: float) -> void:
	_sample()
	if _playing() and level_pending:
		if not session_announced:
			_event("game_start", {"game_mode": "story"})
			session_announced = true
		_event("level_start", {"level_number": level})
		level_pending = false
	if total_ms - checkpoint_ms >= 60000:
		_checkpoint()
	if OS.has_feature("web") and session_announced and session_open and Time.get_ticks_msec() - snapshot_tick >= 1000:
		snapshot_tick = Time.get_ticks_msec()
		JavaScriptBridge.eval("window.FlowerAnalytics?.snapshot(%s)" % JSON.stringify({
			"play_seconds": total_ms / 1000.0, "level_number": level,
			"play_delta_seconds": (total_ms - sent_ms) / 1000.0}))

func begin_level(owner_world: Node, number: int) -> void:
	if not OS.has_feature("web"): return
	_sample()
	world = owner_world
	level = number
	level_ms = 0
	attempt_open = true
	level_pending = true
	if not session_open:
		session_open = true
		total_ms = 0
		sent_ms = 0
		checkpoint_ms = 0
		session_announced = false

func complete_level() -> void:
	if not OS.has_feature("web"): return
	_sample()
	if not attempt_open: return
	attempt_open = false
	_event("level_complete", {"level_number": level, "duration_seconds": level_ms / 1000.0})

func fail_level(reason: String, retry := true) -> void:
	if not OS.has_feature("web"): return
	_sample()
	if not attempt_open: return
	attempt_open = false
	_event("level_fail", {"level_number": level, "duration_seconds": level_ms / 1000.0, "failure_type": reason})
	# Existing fall recovery keeps the same stage and cut state; begin a new attempt only.
	level_ms = 0
	attempt_open = retry
	level_pending = retry

func _checkpoint() -> void:
	_event("playtime_checkpoint", {"play_seconds": total_ms / 1000.0,
		"play_delta_seconds": (total_ms - sent_ms) / 1000.0, "level_number": level})
	sent_ms = total_ms
	checkpoint_ms = total_ms

func end_session() -> void:
	if not OS.has_feature("web"): return
	_sample()
	if not session_open: return
	if session_announced:
		_event("game_end", {"play_seconds": total_ms / 1000.0,
			"play_delta_seconds": (total_ms - sent_ms) / 1000.0, "level_number": level})
	session_open = false
	attempt_open = false
	if OS.has_feature("web"): JavaScriptBridge.eval("window.FlowerAnalytics?.snapshot(null)")

func _event(event_name: String, parameters: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.FlowerAnalytics?.event(%s,%s)" % [JSON.stringify(event_name), JSON.stringify(parameters)])
