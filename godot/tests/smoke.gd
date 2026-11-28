# Plays the game headless: menu, new game, prologue, every room (finished by a debug helper,
# with events forced on), the flashback and the ending. Godot exits 0 even after script
# errors, so CI greps the log for "SCRIPT ERROR" / "ERROR:" as well as this exit code.
extends SceneTree

var main: Node
var failures := 0


func _initialize() -> void:
	_run()


## Waits in game time (headless runs uncapped, so frame counts mean nothing).
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame


func _close_dialogs() -> void:
	for i in 6:
		if not Modal.is_open():
			return
		await _press("ui_cancel")
		await _wait(0.3)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		failures += 1
		printerr("FAIL ", what)


func _screen() -> Node:
	return main.get("current")


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.call("new_game")
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = packed.instantiate()
	root.add_child(main)
	await _wait(1.00)
	_check(_screen() != null and String(_screen().name).begins_with("Menu"), "menu shows")

	# Prologue: skip through.
	main.call("go", "Story", {"which": "intro"}, 0.2)
	await _wait(1.00)
	_check(String(_screen().name).begins_with("Story"), "prologue shows")
	await _press("ui_cancel")
	await _wait(1.50)

	var db: Node = root.get_node("Db")
	for id: String in db.get("room_order"):
		main.call("go", "Room", {"room": id}, 0.2)
		await _wait(1.5)
		var room := _screen()
		_check(String(room.name).begins_with("Room"), "room %s loads" % id)
		# The first-time tutorial opens after 1.7 s.
		await _wait(2.5)
		await _close_dialogs()
		room.call("debug_events")
		await _wait(4.0)
		await _close_dialogs()
		room.call("debug_end_events")
		await _wait(1.0)
		await _close_dialogs()
		room.call("debug_finish")
		# Celebration, then the result card (closes by itself after 6 s).
		await _wait(4.0)
		await _press("ui_accept")
		await _wait(2.0)
		# Flashback: Esc skips it.
		for i in 10:
			if not room.get("ctx").get("cinematic"):
				break
			await _press("ui_cancel")
			await _wait(1.0)
		await _wait(2.0)
		_check(gs.call("is_completed", id), "room %s completes" % id)
		_check(not room.get("ctx").get("cinematic"), "room %s flashback ends" % id)

	main.call("go", "Story", {"which": "ending"}, 0.2)
	await _wait(1.00)
	await _press("ui_cancel")
	await _wait(2.00)
	_check(String(_screen().name).begins_with("TitleCard"), "title card after the ending")
	print("smoke failures: %d" % failures)
	quit(1 if failures > 0 else 0)
