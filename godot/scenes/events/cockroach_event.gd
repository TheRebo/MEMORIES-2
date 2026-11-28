class_name CockroachEvent
extends RoomEvent
## A cockroach blocks cleaning until the player clicks it.

const DEFAULTS := {
	"roachCount": 1,
	"roachSpeed": 40.0,
	"walkArea": {"x": 40, "y": 100, "w": 368, "h": 200},
	"spawnPoint": {"x": 224, "y": 290},
}

const ROACH := preload("res://scenes/world/roach.tscn")

var _roaches: Array[Roach] = []
var _intercept: Callable


func on_start() -> void:
	var area := rect("walkArea")
	var spawn := point("spawnPoint")
	for i in int(cfg["roachCount"]):
		var r: Roach = ROACH.instantiate()
		room.things.add_child(r)
		r.setup(spawn + Vector2(i * 14, 0), area, float(cfg["roachSpeed"]))
		_roaches.append(r)
		point_at("roach%d" % i, func() -> Variant: return null if not is_instance_valid(r) or r.dead else r.position + Vector2(0, -6))
	room.ctx.attend.emit(spawn)
	room.ctx.set_blocked("roach", true, "A cockroach! Click it first.")
	set_objective("A cockroach! Click it to keep cleaning.")
	_intercept = _on_click
	room.add_click_interceptor(_intercept)


func _on_click(p: Vector2) -> bool:
	for r in _roaches:
		if r.hit(p):
			r.squish()
			room.fx.puff_at(r.position, 6)
			_roaches.erase(r)
			if _roaches.is_empty():
				_cleared()
			return true
	return false


func _cleared() -> void:
	room.remove_click_interceptor(_intercept)
	room.ctx.set_blocked("roach", false)
	set_objective("")
	room.ctx.dialog.emit("MC", "Hih... kecoanya sudah pergi. Lanjut bersih-bersih!", 3.0)
	finish()


func _exit_tree() -> void:
	if room:
		room.ctx.set_blocked("roach", false)


func debug_end() -> void:
	if running:
		_cleared()
