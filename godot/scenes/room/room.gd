class_name RoomScreen
extends Node2D
## One room of the house: cleaning, events, completion, flashback, navigation.

## Scene for each event kind in the room data. Loaded on demand: event scripts refer back to
## RoomScreen, so preloading them here would be a cyclic load.
const EVENT_SCENES := {
	"cat": "res://scenes/events/cat_event.tscn",
	"rain": "res://scenes/events/rain_event.tscn",
	"blackout": "res://scenes/events/blackout_event.tscn",
	"wind": "res://scenes/events/wind_event.tscn",
	"cockroach": "res://scenes/events/cockroach_event.tscn",
}
const THING := preload("res://scenes/world/thing.tscn")
const ZONE := preload("res://scenes/world/zone.tscn")
const ITEM := preload("res://scenes/world/item.tscn")
const DIRT := preload("res://scenes/world/dirt.tscn")
const INTERACTABLE := preload("res://scenes/world/interactable.tscn")
const ACTOR := preload("res://scenes/world/actor.tscn")

var args: Dictionary = {}
var main: Node
var def: Dictionary
var ctx: RoomCtx
var tools: ToolSystem
var hands: HandSystem
var candles: CandleSystem
var tracker: TaskTracker
var items: Array[Item] = []
var zones: Array[Zone] = []
var furniture: Array[Thing] = []
var dirt: Array[Dirt] = []
var interacts: Array[Interactable] = []
var actors: Array[Actor] = []
var finished := false
var pointer_screen := Vector2(640, 360)

var _events: Array[RoomEvent] = []
var _interceptors: Array[Callable] = []
var _beams: Array[Callable] = []
var _elapsed := 0.0
var _drift_timer := 0.0
var _drifts := 0
var _completed_visit := false
var _leaving := false

@onready var world: Node2D = %World
## Everything that sorts by depth in the room: furniture, items, dirt, candles, actors.
@onready var things: Node2D = %Things
@onready var camera: CameraRig = %Camera
@onready var lighting: Lighting = %Lighting
@onready var fx: Fx = %Fx
@onready var hud: Hud = %Hud


func _ready() -> void:
	# Back to the last save: a room left halfway does not keep its rewards, trash or tool XP.
	GameState.load_save()
	var id := String(args.get("room", "living_room"))
	def = Db.room(id)
	if def.is_empty():
		def = Db.room("living_room")
	ctx = RoomCtx.new(def)
	tracker = TaskTracker.new()
	_completed_visit = GameState.is_completed(String(def["id"]))
	RenderingServer.set_default_clear_color(Color("0d0907"))

	(%Background as Sprite2D).texture = Db.tex(String(def["background"]))
	_build_world()

	var size := Vector2(float(def["size"]["w"]), float(def["size"]["h"]))
	fx.setup(size)
	camera.setup(size)
	camera.make_current()
	# Every window throws a beam of daylight that brightens as the room gets clean.
	for pr: Dictionary in def["props"]:
		if String(pr["id"]).begins_with("Jendela") and String(pr.get("tex", "")) != "":
			_beams.append(fx.window_light(float(pr["x"]), float(pr["y"]), float(pr["w"])))

	hud.setup(def)
	tools = ToolSystem.new(self)
	hands = HandSystem.new(self)
	candles = CandleSystem.new(self)
	_wire()
	camera.inset_left = hud.todo_inset()

	for e: Dictionary in def.get("events", []):
		var path := String(EVENT_SCENES.get(String(e.get("kind", "")), ""))
		var packed: PackedScene = load(path) if path != "" else null
		if packed == null:
			push_warning("Unknown event kind %s" % e.get("kind"))
			continue
		var ev: RoomEvent = packed.instantiate()
		%Events.add_child(ev)
		ev.setup(self, e)
		_events.append(ev)

	Sfx.play_music("present", 1.4)
	Sfx.play("room_enter", 0.6)
	hud.banner(String(def["name"]), 1.6)
	if _completed_visit:
		_enter_completed_state()
	else:
		_refresh()
		if not GameState.tutorial_seen():
			GameState.mark_tutorial_seen()
			_later(1.7, func() -> void: show_tutorial(Db.story.get("start_tutorial", []), "Cara bermain"))


func _exit_tree() -> void:
	Sfx.stop_all_loops()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# ================== Debug (tests/smoke.gd) ==================

func modal_open() -> bool:
	return Modal.is_open()


## Finish every task except `leave` of them.
func debug_finish(leave: int = 0) -> void:
	var todo: Array = []
	for d in dirt:
		if not d.done:
			todo.append(d)
	for i in interacts:
		if not i.done:
			todo.append(i)
	for t: Object in todo.slice(leave):
		if t is Dirt:
			(t as Dirt).scrub((t as Dirt).tool, (t as Dirt).effort)
		else:
			(t as Interactable).interact()
	for it in items:
		if it.done:
			continue
		for z in zones:
			if z.can_accept(it):
				z.receive(it)
				break
	ctx.tasks_changed.emit()


## Start every event of this room now, one after another.
func debug_events() -> void:
	for ev in _events:
		ev.cfg["triggerProgress"] = 0.0
		ev.cfg["repeatEnabled"] = false
		ev.cfg["enabled"] = true
	ctx.progress.emit(percent())


func debug_end_events() -> void:
	for ev in _events:
		if ev.running:
			ev.debug_end()


# ================== World ==================

func _build_world() -> void:
	for p: Dictionary in def["props"]:
		var t: Thing = THING.instantiate()
		t.setup(p)
		things.add_child(t)
		furniture.append(t)
		_add_dirt_children(t, p.get("dirt", []))
	for z: Dictionary in def["zones"]:
		var zone: Zone = ZONE.instantiate()
		zone.setup_zone(z)
		things.add_child(zone)
		zones.append(zone)
		furniture.append(zone)
		_add_dirt_children(zone, z.get("dirt", []))
	for d: Dictionary in def["floorDirt"]:
		spawn_dirt(d, null)
	for i: Dictionary in def["items"]:
		var it: Item = ITEM.instantiate()
		it.setup_item(i)
		things.add_child(it)
		items.append(it)
		tracker.add(it)
	for i: Dictionary in def["interacts"]:
		var it: Interactable = INTERACTABLE.instantiate()
		it.setup_interact(i)
		things.add_child(it)
		interacts.append(it)
		tracker.add(it)
	for a: Dictionary in def["actors"]:
		var ac: Actor = ACTOR.instantiate()
		ac.setup_actor(a)
		things.add_child(ac)
		actors.append(ac)


func _add_dirt_children(parent: Thing, list: Array) -> void:
	for d: Dictionary in list:
		spawn_dirt(d, parent)


func spawn_dirt(spec: Dictionary, parent: Thing) -> Dirt:
	var d: Dirt = DIRT.instantiate()
	d.setup_dirt(spec, parent)
	things.add_child(d)
	dirt.append(d)
	tracker.add(d)
	return d


func find_thing(id: String) -> Thing:
	for f in furniture:
		if f.id == id:
			return f
	return null


# ================== Wiring ==================

func _wire() -> void:
	ctx.tasks_changed.connect(_refresh)
	ctx.toast.connect(hud.toast)
	ctx.dialog.connect(func(s: String, t: String, d: float) -> void:
		hud.dialog(s, t, d)
		Sfx.play("pause_open", 0.35, 0.0, 400))
	ctx.dialog_hide.connect(hud.hide_dialog)
	ctx.objective.connect(hud.objective)
	ctx.event_bar.connect(hud.event_bar)
	ctx.hint.connect(hud.hint)
	ctx.shake.connect(camera.shake_cam)
	ctx.attend.connect(func(p: Vector2) -> void: camera.attend_to(p))
	ctx.pointer.connect(hud.set_pointer)
	ctx.pointer_clear.connect(hud.clear_pointer)
	ctx.tool_changed.connect(func(t: String, _s: String) -> void: hud.set_tool(t))
	ctx.candle_held.connect(hud.set_candle_held)
	ctx.cinematic_changed.connect(func(on: bool) -> void:
		hud.set_cinematic(on)
		camera.inset_left = hud.todo_inset())

	GameState.inventory_changed.connect(_on_inventory)
	GameState.trash_changed.connect(hud.set_trash)
	GameState.tool_level_changed.connect(_on_tool_level)
	hud.set_candles(GameState.count("candle"))

	hud.menu_pressed.connect(_open_pause)
	hud.tool_slot_down.connect(tools.slot_down)
	hud.tool_slot_activate.connect(tools.slot_activate)
	hud.candle_slot_down.connect(func() -> void: candles.hold("slot"))
	hud.go_room.connect(func(r: String) -> void: _leave("Room", {"room": r}, 0.8))
	hud.go_home.connect(func() -> void: _leave("Story", {"which": "ending"}, 1.6))
	hud.todo_toggled.connect(func() -> void: camera.inset_left = hud.todo_inset())
	hud.task_clicked.connect(_locate_task)


func _on_inventory() -> void:
	hud.set_candles(GameState.count("candle"))


func _on_tool_level(tool: String, level: int, leveled_up: bool) -> void:
	hud.set_tool_level(tool, level, leveled_up)
	if leveled_up:
		Sfx.play("patch_done", 0.8)
		hud.toast("Alat naik level! %s Lv.%d: membersihkan lebih cepat." % [Db.tool_info(tool).get("name", tool), level])


func add_click_interceptor(fn: Callable) -> void:
	_interceptors.append(fn)


func remove_click_interceptor(fn: Callable) -> void:
	_interceptors.erase(fn)


# ================== Input ==================

const TOOL_ACTIONS := {"tool_broom": "broom", "tool_mop": "mop", "tool_cloth": "cloth", "tool_duster": "duster"}


## Releases are caught here, before the GUI, so letting go over a panel still counts.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tools.pointer_down()
		else:
			tools.pointer_up(pointer_screen)
			hands.drop()
			candles.pointer_up()
	for action: String in TOOL_ACTIONS:
		if event.is_action_released(action):
			tools.key_up(TOOL_ACTIONS[action])
	if event.is_action_released("hold_candle"):
		candles.key_up()


func _unhandled_input(event: InputEvent) -> void:
	if Modal.is_open() or _leaving:
		return
	if hud.result_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			hud.close_result()
		return
	if ctx.cinematic:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.wheel(-1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.wheel(1.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			tools.right_click()
		elif mb.button_index == MOUSE_BUTTON_LEFT and pointer_in_world():
			var w := pointer_world()
			# Event clicks (cockroach, window) work even with a tool in hand.
			for fn in _interceptors.duplicate():
				if fn.call(w):
					return
			hands.pointer_down(w)
		return
	if event is InputEventKey and event.echo:
		return
	for action: String in TOOL_ACTIONS:
		if event.is_action_pressed(action):
			tools.key_down(TOOL_ACTIONS[action])
			return
	if event.is_action_pressed("hold_candle"):
		candles.hold("key")
	elif event.is_action_pressed("toggle_notes"):
		hud.toggle_todo()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not tools.release_sticky():
			_open_pause()


## Switching windows while holding a key never delivers the release: put things down.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and ctx:
		if ctx.held_source == "key" or ctx.held_source == "slot":
			tools.release()
		candles.cancel_hold()
		hands.cancel()


func pointer_world() -> Vector2:
	return camera.screen_to_world(pointer_screen)


## Pointer over the visible room, not over a HUD panel.
func pointer_in_world() -> bool:
	return camera.usable().has_point(pointer_screen) and not hud.blocks_point(pointer_screen)


# ================== Progress ==================

func percent() -> float:
	return 100.0 if finished or _completed_visit else tracker.percent()


func _refresh() -> void:
	var pct := percent()
	hud.set_groups(tracker.groups(), _group_kinds())
	for g: String in tracker.newly_finished():
		hud.flash_group(g)
		Sfx.play("group_done", 0.7)
	hud.set_progress(pct)
	if finished or _completed_visit:
		return
	GameState.set_progress(String(def["id"]), pct)
	var t := pct / 100.0
	lighting.set_cleanliness(t)
	fx.set_motes(0.55 - 0.45 * t, Color("d9d0c0"))
	for b in _beams:
		b.call(t)
	hud.set_vignette(0.6 - 0.45 * t)
	ctx.progress.emit(pct)
	if tracker.all_done() and not ctx.events_active():
		finished = true
		_run_completion()


## What each task group asks for: a tool, dragging by hand, or a double click.
func _group_kinds() -> Dictionary:
	var m: Dictionary = {}
	for d in dirt:
		if not m.has(d.group):
			m[d.group] = d.tool
	for i in items:
		if not m.has(i.group):
			m[i.group] = "hand"
	for i in interacts:
		if not m.has(i.group):
			m[i.group] = "click"
	return m


## Note row clicked: swing the camera to the nearest unfinished part of that task and mark it.
func _locate_task(group: String) -> void:
	if ctx.cinematic:
		return
	var c := camera.world_center()
	var best := Vector2.INF
	var best_d := INF
	var spots: Array[Vector2] = []
	for d in dirt:
		if d.group == group and not d.done and d.visible:
			spots.append(d.center())
	for i in items:
		if i.group == group and not i.done:
			spots.append(i.position + Vector2(0, -6))
	for i in interacts:
		if i.group == group and not i.done:
			spots.append(i.position + Vector2(0, -6))
	for p in spots:
		var dd := p.distance_squared_to(c)
		if dd < best_d:
			best_d = dd
			best = p
	if best == Vector2.INF:
		return
	camera.attend_to(best, 1.6)
	fx.ping(best)
	var kind := String(_group_kinds().get(group, ""))
	if kind != "" and kind != "hand" and kind != "click":
		hud.suggest_tool(kind, 2.2)
	Sfx.play("slide_in", 0.4)


## Work order: sweep dust before mopping the stain under it; dust furniture before wiping it.
func blocker_of(d: Dirt) -> Dirt:
	for o in dirt:
		if o == d or o.done or not o.visible:
			continue
		if d.tool == "mop" and d.parent_thing == null and o.tool == "broom" and o.parent_thing == null \
				and absf(o.position.x - d.position.x) < (o.w + d.w) / 2.0 - 4.0 \
				and absf(o.position.y - d.position.y) < (o.h + d.h) / 2.0 - 2.0:
			return o
		if d.tool == "cloth" and d.parent_thing != null and o.parent_thing == d.parent_thing and o.tool == "duster":
			return o
	return null


# ================== Completion ==================

func _run_completion() -> void:
	tools.release()
	hud.hide_dialog()
	var id := String(def["id"])
	# Save at once: leaving during the celebration or flashback must not lose the room.
	GameState.complete_room(id)
	var seconds := _elapsed
	var prev_best := GameState.best_time(id)
	var record := GameState.record_time(id, seconds)
	await _wait(1.2)
	hud.set_progress(100.0)
	Sfx.play("room_complete", 0.9)
	hud.banner("%s bersih!" % def["name"], 2.2)
	_celebrate(false)
	await _wait(1.4)
	var par := Db.star_par(id)
	hud.show_result(Db.stars_for(par, seconds), seconds, par, prev_best, record)
	await hud.result_closed
	hands.cancel()
	var cs := RoomCutscene.new(self)
	add_child(cs)
	await cs.play(def.get("flashback", []))
	hud.set_memory(false)
	Sfx.play_music("present", 1.6)
	hud.show_nav()
	if GameState.all_completed():
		hud.toast("Semua ruangan bersih. Saatnya pulang.")
	else:
		hud.toast("Ruangan selesai! Pilih ruangan berikutnya di bar bawah.")


func _celebrate(instant: bool) -> void:
	var size := Vector2(float(def["size"]["w"]), float(def["size"]["h"]))
	if not instant:
		camera.zoom_pulse(0.35, 1.3)
		lighting.pulse_flash(0.8, 1.6)
		fx.celebrate(size)
	lighting.set_warm(instant)
	for b in _beams:
		b.call(1.2)
	fx.set_motes(0.6, Color("f2c46a"))
	hud.set_vignette(0.2)
	hud.set_glow(true, instant)


## Coming back to a finished room: everything already clean and put away.
func _enter_completed_state() -> void:
	finished = true
	for d in dirt:
		d.restore_done()
	for i in interacts:
		i.restore_done()
	for z in zones:
		var n := 0
		for it in items:
			if it.type != z.accepts or it.done:
				continue
			if z.limit and n >= z.capacity:
				break
			it.restore_done(z)
			n += 1
		z.set_fill(n)
	_refresh()
	hud.set_progress(100.0)
	_celebrate(true)
	hud.show_nav()


# ================== Overlays ==================

func show_tutorial(pages: Array, title: String) -> void:
	if pages.is_empty():
		return
	# Busy (cutscene or another dialog): try again shortly instead of losing the lesson.
	if ctx.cinematic or Modal.is_open():
		_later(1.5, func() -> void: show_tutorial(pages, title))
		return
	_put_down()
	get_tree().paused = true
	var d := TutorialDialog.make(title, pages)
	d.closed.connect(_unpause)
	hud.add_child(d)


func _open_pause() -> void:
	if Modal.is_open() or ctx.cinematic or _leaving:
		return
	_put_down()
	Sfx.play("pause_open", 0.6)
	get_tree().paused = true
	var d := PauseDialog.make(String(def["name"]), roundi(percent()), GameState.is_completed(String(def["id"])),
		func() -> void: show_tutorial(Db.story.get("start_tutorial", []), "Cara bermain"),
		func() -> void: _leave("Menu", {}, 0.6))
	d.closed.connect(func() -> void:
		Sfx.play("pause_close", 0.6)
		_unpause())
	hud.add_child(d)


func _unpause() -> void:
	if not Modal.is_open():
		get_tree().paused = false


func _put_down() -> void:
	candles.cancel_hold()
	tools.release()
	hands.cancel()


func _leave(screen: String, a: Dictionary, seconds: float) -> void:
	if _leaving:
		return
	_leaving = true
	_put_down()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.go(screen, a, seconds)


# ================== Loop ==================

func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	pointer_screen = get_viewport().get_mouse_position()
	if not finished and not _completed_visit and not ctx.cinematic:
		_elapsed += delta
		hud.set_time(_elapsed, Db.star_par(String(def["id"])))
		_dust_drift(delta)
	_suggest_from_hover()
	camera.step(dt, pointer_screen)
	tools.update()
	hands.update()
	candles.update(dt)
	var in_world := pointer_in_world()
	# The tool or candle itself is the cursor while it is over the room.
	var hide_cursor := ctx.hands_busy() and in_world and not ctx.cinematic and not Modal.is_open()
	var mode := Input.MOUSE_MODE_HIDDEN if hide_cursor else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	hud.move_cursor(pointer_screen, tools.working)
	hud.update_pointers(camera)


## A few times per room, dust settles again on swept floor: the house does not wait.
func _dust_drift(dt: float) -> void:
	if _drifts >= 3 or ctx.events_active() or ctx.blackout:
		return
	_drift_timer += dt
	if _drift_timer < 55.0:
		return
	_drift_timer = 0.0
	if percent() > 92.0:
		return
	var w := float(def["size"]["w"])
	var h := float(def["size"]["h"])
	var p := Vector2(randf_range(48, w - 48), randf_range(float(def["wallHeight"]) + 60, h - 30))
	_drifts += 1
	spawn_dirt({"id": "drift-%d" % _drifts, "x": p.x, "y": p.y, "w": 28, "h": 14, "tool": "broom", "effort": 190,
		"group": "Sapu lantai", "tex": "debu_ulahan_daus"}, null)
	fx.ping(p)
	ctx.toast.emit("Debu kembali menumpuk di lantai!")
	ctx.tasks_changed.emit()


## Empty hand over grime: light up the tool it needs.
func _suggest_from_hover() -> void:
	if ctx.held_tool != "" or ctx.cinematic or not pointer_in_world():
		hud.hover_tool("")
		return
	var w := pointer_world()
	for d in dirt:
		if not d.done and d.visible and d.has_point(w, 2.0):
			hud.hover_tool(d.tool)
			return
	hud.hover_tool("")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _later(seconds: float, fn: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(_fire.bind(fn))


func _fire(fn: Callable) -> void:
	if is_inside_tree():
		fn.call()
