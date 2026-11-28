class_name RoomEvent
extends Node
## Base room event. Starts when room progress reaches `triggerProgress`, can come back after a
## delay, and keeps the room from completing while it runs. Timers follow the scene tree, so
## they stop while the game is paused.

const BASE := {
	"enabled": true,
	"triggerProgress": 50.0,
	"repeatEnabled": true,
	"repeatInterval": 90.0,
	"repeatJitter": 20.0,
	"maxRepeats": 2,
	"introSpeaker": "Kejadian!",
	"introText": "",
	"introDuration": 4.5,
	"startSfx": "warning",
	"tutorialEveryTime": false,
}

var room: RoomScreen
var id := ""
var cfg: Dictionary = {}
var tutorial: Array = []
var running := false
var _started := false
var _repeats := 0


func setup(r: RoomScreen, def: Dictionary, defaults: Dictionary) -> RoomEvent:
	room = r
	id = String(def.get("kind", "event"))
	name = "Event_" + id
	var merged := BASE.duplicate(true)
	merged.merge(defaults, true)
	for key: String in merged.keys():
		if def.has(key) and def[key] != null:
			var v: Variant = def[key]
			var fallback: Variant = merged[key]
			if typeof(v) == typeof(fallback) or (fallback is float and v is int) or (fallback is int and v is float):
				merged[key] = v
	cfg = merged
	tutorial = def.get("tutorial", [])
	if GameState.is_completed(String(room.def["id"])):
		cfg["enabled"] = false
	room.ctx.progress.connect(_on_progress)
	return self


func _on_progress(pct: float) -> void:
	if not bool(cfg["enabled"]) or _started or pct < float(cfg["triggerProgress"]) or not can_start(pct):
		return
	_started = true
	# Never stack two events: wait for the running one (or a cutscene) to finish first.
	if room.ctx.events_active() or room.ctx.cinematic:
		later(6.0, _try_start.bind(false))
		return
	_launch()


func _launch() -> void:
	if running or room.finished:
		return
	running = true
	room.ctx.begin_event(id)
	var sfx := String(cfg["startSfx"])
	if sfx != "":
		Sfx.play(sfx, 0.7)
	if String(cfg["introText"]) != "":
		room.ctx.dialog.emit(String(cfg["introSpeaker"]), String(cfg["introText"]), float(cfg["introDuration"]))
	_show_tutorial()
	on_start()


func _show_tutorial() -> void:
	if tutorial.is_empty():
		return
	var key := "event:" + id
	if not bool(cfg["tutorialEveryTime"]) and GameState.has_seen(key):
		return
	GameState.mark_seen(key)
	# Let the event's first beat land before pausing for the explanation.
	later(0.9, func() -> void: room.show_tutorial(tutorial, "Kejadian"))


## Extra start condition.
func can_start(_pct: float) -> bool:
	return true


func on_start() -> void:
	pass


func finish() -> void:
	if not running:
		return
	running = false
	# An ended event never leaves its card or bar behind, whatever a subclass forgot.
	set_objective("")
	room.ctx.end_event(id)
	_schedule_repeat()


func _schedule_repeat() -> void:
	if not bool(cfg["repeatEnabled"]) or not bool(cfg["enabled"]):
		return
	if int(cfg["maxRepeats"]) > 0 and _repeats >= int(cfg["maxRepeats"]):
		return
	var j := float(cfg["repeatJitter"])
	later(maxf(5.0, float(cfg["repeatInterval"]) + randf_range(-j, j)), _try_start.bind(true))


func _try_start(repeat: bool) -> void:
	if room.finished:
		return
	if room.ctx.events_active() or room.ctx.cinematic or not can_start(room.percent()):
		later(8.0 if repeat else 6.0, _try_start.bind(repeat))
		return
	if repeat:
		_repeats += 1
	_launch()


# ---------------- Helpers ----------------

## Call `fn` after `seconds` of unpaused time, unless this event is gone by then.
func later(seconds: float, fn: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(_fire.bind(fn))


func _fire(fn: Callable) -> void:
	if is_inside_tree():
		fn.call()


func set_objective(text: String) -> void:
	room.ctx.objective.emit(id, text)


func set_bar(label: String, value: float) -> void:
	room.ctx.event_bar.emit(id, label, value)


func point_at(key: String, target: Callable) -> void:
	room.ctx.pointer.emit("%s:%s" % [id, key], target)


func clear_point(key: String) -> void:
	room.ctx.pointer_clear.emit("%s:%s" % [id, key])


func rect(key: String) -> Rect2:
	var a: Dictionary = cfg[key]
	return Rect2(float(a["x"]), float(a["y"]), float(a["w"]), float(a["h"]))


func point(key: String) -> Vector2:
	var a: Dictionary = cfg[key]
	return Vector2(float(a["x"]), float(a["y"]))


func random_in(a: Rect2) -> Vector2:
	return Vector2(randf_range(a.position.x, a.end.x), randf_range(a.position.y, a.end.y))


func spawn_dirt(spec: Dictionary, parent: Thing = null) -> Dirt:
	var s := spec.duplicate()
	s["id"] = "%s-%d" % [id, randi()]
	var d := room.spawn_dirt(s, parent)
	# Pop in with scale: alpha is reserved for how clean a spot is.
	d.scale = d.base_scale * 0.3
	d.create_tween().tween_property(d, "scale", d.base_scale, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return d


## Items already put away whose type is in `types`.
func eligible_items(types: Array) -> Array:
	var out: Array = []
	for it: Item in room.items:
		if it.done and it.zone != null and types.has(it.type):
			out.append(it)
	return out


## Throw `n` tidied items back on the floor. Returns how many moved.
func scatter(n: int, types: Array, area: Rect2) -> int:
	var cands := eligible_items(types)
	cands.shuffle()
	var count := 0
	for it: Item in cands:
		if count >= n:
			break
		it.scatter_to(random_in(area))
		count += 1
	if count > 0:
		room.ctx.tasks_changed.emit()
	return count


func random_furniture() -> Thing:
	var list: Array = []
	for f: Thing in room.furniture:
		if f.layer_name == "ysort" and f.origin_at_base:
			list.append(f)
	return list.pick_random() if not list.is_empty() else null
