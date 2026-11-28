class_name CatEvent
extends RoomEvent
## A cat runs in and knocks tidied things back onto the floor.

const DEFAULTS := {
	"shakeStrength": 2.5,
	"shakeDuration": 0.6,
	"scatterCount": 4,
	"minItemsNeeded": 2,
	"runSpeed": 90.0,
	"catEntry": {"x": 540, "y": 200},
	"catExit": {"x": -30, "y": 260},
	"floorArea": {"x": 60, "y": 110, "w": 392, "h": 210},
}
const SCATTER_TYPES := ["book", "pajangan", "trash"]

var _abort := false

@onready var _cat: AnimatedSprite2D = %Cat


func can_start(pct: float) -> bool:
	return pct >= 85.0 or eligible_items(SCATTER_TYPES).size() >= int(cfg["minItemsNeeded"])


func on_start() -> void:
	_run()


func _run() -> void:
	_abort = false
	Sfx.play("meow", 1.0, 120)
	room.ctx.shake.emit(float(cfg["shakeStrength"]), float(cfg["shakeDuration"]))
	await get_tree().create_timer(0.9, false).timeout
	_cat.position = point("catEntry")
	_cat.show()
	_cat.play("run")
	var left := int(cfg["scatterCount"])
	var total := 0
	var floor_area := rect("floorArea")
	for i in 3:
		await _run_to(random_in(floor_area))
		if _abort:
			return
		var n := ceili(float(left) / (3 - i))
		var moved := scatter(n, SCATTER_TYPES, floor_area)
		left -= moved
		total += moved
		if moved > 0:
			Sfx.play("rattle", 0.7, 100)
		Sfx.play("meow", 0.8, 200)
		room.ctx.shake.emit(float(cfg["shakeStrength"]) * 0.6, 0.35)
	await _run_to(point("catExit"))
	if _abort:
		return
	_cat.stop()
	_cat.hide()
	if total > 0:
		room.ctx.dialog.emit("MC", "Aduh... barang-barangnya berantakan lagi!", 3.5)
	finish()


func _run_to(to: Vector2) -> void:
	var dist := maxf(1.0, _cat.position.distance_to(to))
	# The art faces left.
	_cat.flip_h = to.x > _cat.position.x
	var t := _cat.create_tween()
	t.tween_property(_cat, "position", to, dist / float(cfg["runSpeed"]))
	await t.finished


func _process(_dt: float) -> void:
	if _cat.visible:
		_cat.z_index = 1000 + int(_cat.position.y)


## Tests: the cat leaves at once and touches nothing more.
func debug_end() -> void:
	if not running:
		return
	_abort = true
	_cat.stop()
	_cat.hide()
	finish()
