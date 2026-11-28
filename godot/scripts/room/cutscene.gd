class_name RoomCutscene
extends Node
## Flashback played inside the room once it is clean: actors appear and walk, the camera frames
## them, the room tints. Click or Enter advances (after a short lock), Esc skips the rest.

signal advanced

var room: RoomScreen
var _waiting := false
var _skip := false
var _locked_until := 0
var _faded := false
var _hint_timer: SceneTreeTimer


func _init(r: RoomScreen) -> void:
	room = r


func play(lines: Array) -> void:
	var c := room.ctx
	c.set_cinematic(true)
	room.camera.begin_cinematic()
	Sfx.play_music("flashback", 1.6)
	await _wait(1.0)
	for line: Dictionary in lines:
		if _skip:
			break
		await _run_line(line)
	room.hud.hide_dialog()
	room.hud.dialog_hint(false)
	for a: Actor in room.actors:
		if a.visible:
			a.vanish()
	if _faded:
		room.hud.fade(false, 800)
		await _wait(0.9)
	await _wait(0.6)
	room.lighting.remove_tint("cutscene")
	room.camera.end_cinematic()
	c.set_cinematic(false)
	queue_free()


func _run_line(line: Dictionary) -> void:
	if bool(line.get("fadeToBlack", false)) and not _faded:
		_faded = true
		room.hud.fade(true, 900)
		await _wait(1.0)
	var tint: Variant = line.get("tint")
	if tint is Array:
		room.lighting.add_tint("cutscene", tint)
		var memory := false
		for i in 3:
			if float(tint[i]) < 0.99:
				memory = true
		room.hud.set_memory(memory)
	for id: String in line.get("hide", []):
		var a := _actor(id)
		if a:
			a.vanish()
	for id: String in line.get("show", []):
		var a := _actor(id)
		if a:
			a.appear()
	for m: Dictionary in line.get("moves", []):
		var a := _actor(String(m["actor"]))
		if a:
			a.walk_to(Vector2(float(m["x"]), float(m["y"])))
	var focus: Variant = line.get("focus")
	if focus is Array:
		var cam: Dictionary = Db.game.get("camera", {})
		room.camera.focus(Vector2(float(focus[0]), float(focus[1])), float(line.get("zoom", cam.get("cinematicZoom", 3.5))))
	var text := String(line.get("text", ""))
	if text != "":
		room.hud.dialog(String(line.get("speaker", "")), text, 0.0)
	else:
		room.hud.hide_dialog()
	room.hud.dialog_hint(false)
	# The lock follows text speed, so slow readers are not skipped past by an eager click.
	var lock := 1.4 if Settings.text_speed == "slow" else 1.0
	_locked_until = Time.get_ticks_msec() + int(lock * 1000)
	_hint_timer = get_tree().create_timer(lock, false)
	_hint_timer.timeout.connect(func() -> void:
		if _waiting:
			room.hud.dialog_hint(true))
	_waiting = true
	var hold := float(line.get("hold", 0.0))
	if hold > 0.0:
		var t := get_tree().create_timer(hold, false)
		t.timeout.connect(func() -> void:
			if _waiting:
				_finish_wait())
	await advanced


func _finish_wait() -> void:
	_waiting = false
	advanced.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or Modal.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip = true
		_finish_wait()
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("ui_accept") or click:
		get_viewport().set_input_as_handled()
		_press()


func _press() -> void:
	if room.hud.typing():
		room.hud.finish_typing()
		return
	if Time.get_ticks_msec() < _locked_until:
		return
	Sfx.ui_click()
	_finish_wait()


func _actor(id: String) -> Actor:
	for a: Actor in room.actors:
		if a.actor == id:
			return a
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
