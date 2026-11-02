extends Node
signal volume_changed(level:int)
const SETTINGS_PATH:="user://audio_settings.cfg"
const STEPS:=10
var level:=STEPS
var previous_level:=STEPS

func _ready() -> void:
	var settings:=ConfigFile.new()
	if settings.load(SETTINGS_PATH)==OK:
		level=clampi(int(settings.get_value("audio","volume",STEPS)),0,STEPS)
		previous_level=clampi(int(settings.get_value("audio","previous_volume",STEPS)),1,STEPS)
	_apply()

func set_level(value:int) -> void:
	value=clampi(value,0,STEPS)
	if level==value:return
	level=value
	if level>0:previous_level=level
	_apply()
	var settings:=ConfigFile.new()
	settings.set_value("audio","volume",level)
	settings.set_value("audio","previous_volume",previous_level)
	var error:=settings.save(SETTINGS_PATH)
	if error!=OK:push_warning("Could not save volume: %s"%error_string(error))
	volume_changed.emit(level)

func toggle_mute() -> void:
	set_level(previous_level if level==0 else 0)

func _apply() -> void:
	var bus:=AudioServer.get_bus_index("Master")
	if bus<0:return
	AudioServer.set_bus_volume_db(bus,linear_to_db(float(level)/STEPS) if level>0 else -80.0)
	AudioServer.set_bus_mute(bus,level==0)
