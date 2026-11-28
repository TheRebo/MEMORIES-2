# Renders key screens (needs a display: run under xvfb with the opengl3 driver) and prints each
# as base64 PNG between markers, so the CI log carries the pictures.
extends SceneTree

var main: Node


func _initialize() -> void:
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var data := img.save_png_to_buffer()
	print("SHOT-BEGIN ", name)
	var b64 := Marshalls.raw_to_base64(data)
	var i := 0
	while i < b64.length():
		print("SHOT ", b64.substr(i, 3000))
		i += 3000
	print("SHOT-END ", name)


func _screen() -> Node:
	return main.get("current")


func _run() -> void:
	root.get_node("GameState").call("new_game")
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = packed.instantiate()
	root.add_child(main)
	await _wait(2.0)
	await _shot("menu_new")

	main.call("go", "Story", {"which": "intro"}, 0.2)
	await _wait(3.0)
	await _shot("story")

	main.call("go", "Room", {"room": "living_room"}, 0.2)
	await _wait(2.5)
	await _shot("room_tutorial")
	await _press("ui_cancel")
	await _wait(1.0)
	await _shot("room")
	var room := _screen()
	room.call("debug_events")
	await _wait(3.0)
	await _shot("room_event")
	room.call("debug_end_events")
	await _wait(1.0)
	await _press("ui_cancel")
	await _wait(0.6)
	await _shot("pause")
	await _press("ui_cancel")
	await _wait(0.5)
	for attempt in 4:
		room.call("debug_end_events")
		room.call("debug_finish")
		await _wait(3.0)
		if room.get("finished"):
			break
	await _wait(1.0)
	await _shot("result")
	await _press("ui_accept")
	await _wait(4.0)
	await _shot("flashback")
	for i in 10:
		if not room.get("ctx").get("cinematic"):
			break
		await _press("ui_cancel")
		await _wait(1.0)
	await _wait(1.5)
	await _shot("room_done")

	main.call("go", "Room", {"room": "kitchen"}, 0.2)
	await _wait(2.0)
	room = _screen()
	room.call("debug_events")
	await _wait(1.0)
	room.call("debug_end_events")
	await _wait(1.0)
	room.call("debug_events")
	await _wait(2.5)
	await _shot("kitchen_event")

	main.call("go", "Menu", {}, 0.2)
	await _wait(2.0)
	await _shot("menu_continue")
	_screen().call("add_child", (load("res://scenes/ui/dialogs/settings_dialog.tscn") as PackedScene).instantiate())
	await _wait(0.8)
	await _shot("settings")
	quit(0)
