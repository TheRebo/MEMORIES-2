class_name RoomCtx
extends RefCounted
## Per-room runtime state and message bus shared by the systems and events.
## Made fresh for every room visit, so nothing leaks from one room to the next.

signal tasks_changed
signal progress(pct: float)
signal toast(text: String)
signal dialog(speaker: String, text: String, duration: float)
signal dialog_hide
signal objective(id: String, text: String)
## value < 0 removes the bar.
signal event_bar(id: String, label: String, value: float)
signal hint(screen_pos: Vector2, text: String)
signal shake(strength: float, duration: float)
signal attend(world_pos: Vector2)
signal pointer(id: String, target: Callable)
signal pointer_clear(id: String)
signal tool_changed(tool: String, source: String)
signal candle_held(on: bool)
signal blackout_changed(on: bool)
signal cinematic_changed(on: bool)

var def: Dictionary
var held_tool := ""
var held_source := ""
var holding_candle := false
var dragging := false
var blackout := false
var cinematic := false
var _blocks: Dictionary = {}
var _active: Dictionary = {}
var _last_blocked_notice := -100000


func _init(room_def: Dictionary) -> void:
	def = room_def


func begin_event(id: String) -> void:
	_active[id] = true
	tasks_changed.emit()


func end_event(id: String) -> void:
	_active.erase(id)
	tasks_changed.emit()


func events_active() -> bool:
	return not _active.is_empty()


func set_blocked(reason: String, on: bool, message: String = "") -> void:
	if on:
		_blocks[reason] = message
	else:
		_blocks.erase(reason)


func blocked() -> bool:
	return not _blocks.is_empty()


## Rate-limited toast explaining why cleaning is blocked.
func notify_blocked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_blocked_notice < 2500:
		return
	_last_blocked_notice = now
	for msg: String in _blocks.values():
		if msg != "":
			toast.emit(msg)
			return


func hands_busy() -> bool:
	return held_tool != "" or holding_candle


func set_cinematic(on: bool) -> void:
	cinematic = on
	cinematic_changed.emit(on)
