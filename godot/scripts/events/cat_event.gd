class_name CatEvent
extends RoomEvent
## A cat runs in and knocks tidied things back onto the floor.

const DEFAULTS := {
	"shakeStrength": 2.5,
	"shakeDuration": 0.6,
	"scatterCount": 4,
	"minItemsNeeded": 2,
	"runSpeed": 90.0,
	"catTexture": "cat_run",
	"catEntry": {"x": 540, "y": 200},
	"catExit": {"x": -30, "y": 260},
	"floorArea": {"x": 60, "y": 110, "w": 392, "h": 210},
}
const SCATTER_TYPES := ["book", "pajangan", "trash"]
const FRAME_W := 35

var _cat: Sprite2D
var _anim_t := 0.0


func can_start(pct: float) -> bool:
	return pct >= 85.0 or eligible_items(SCATTER_TYPES).size() >= int(cfg["minItemsNeeded"])


func on_start() -> void:
	_run()


func _run() -> void:
	Sfx.play("meow", 1.0, 120)
	room.ctx.shake.emit(float(cfg["shakeStrength"]), float(cfg["shakeDuration"]))
	await get_tree().create_timer(0.9, false).timeout
	_cat = Sprite2D.new()
	_cat.texture = Db.tex("sprites/%s.png" % cfg["catTexture"])
	if _cat.texture:
		_cat.hframes = maxi(1, _cat.texture.get_width() / FRAME_W)
		_cat.offset = Vector2(0, -_cat.texture.get_height() / 2.0)
	_cat.position = point("catEntry")
	room.world.add_child(_cat)
	var cat := _cat
	point_at("cat", func() -> Variant: return cat.position + Vector2(0, -24) if is_instance_valid(cat) else null)
	var left := int(cfg["scatterCount"])
	var total := 0
	var floor_area := rect("floorArea")
	for i in 3:
		await _run_to(random_in(floor_area))
		var n := ceili(float(left) / (3 - i))
		var moved := scatter(n, SCATTER_TYPES, floor_area)
		left -= moved
		total += moved
		if moved > 0:
			Sfx.play("rattle", 0.7, 100)
		Sfx.play("meow", 0.8, 200)
		room.ctx.shake.emit(float(cfg["shakeStrength"]) * 0.6, 0.35)
	await _run_to(point("catExit"))
	clear_point("cat")
	_cat.queue_free()
	_cat = null
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


func _process(dt: float) -> void:
	if _cat and is_instance_valid(_cat):
		_anim_t += dt
		_cat.frame = int(_anim_t * 12.0) % _cat.hframes
		_cat.z_index = 1000 + int(_cat.position.y)
