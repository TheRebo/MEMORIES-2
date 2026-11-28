class_name Roach
extends Sprite2D
## Wanders the floor; cleaning is blocked until it is clicked.

var area := Rect2()
var speed := 40.0
var dead := false
var _target := Vector2.ZERO
var _pause := 0.0


func setup(pos: Vector2, walk: Rect2, spd: float) -> Roach:
	texture = Db.tex(String(Db.named.get("roach", "kecoa")))
	scale = Vector2(0.5, 0.5)
	position = pos
	area = walk
	speed = spd
	z_index = 3500
	z_as_relative = false
	_pick()
	return self


func _pick() -> void:
	_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _process(dt: float) -> void:
	if dead:
		return
	if _pause > 0.0:
		_pause -= dt
		return
	var d := _target - position
	var dist := d.length()
	if dist < 2.0:
		if randf() < 0.3:
			_pause = randf_range(0.3, 0.9)
		_pick()
		return
	position += d / dist * minf(dist, speed * dt)
	# The art faces up; turn toward the way it runs.
	rotation = d.angle() + PI / 2.0


## Generous hit radius: it is small and quick.
func hit(p: Vector2) -> bool:
	return not dead and p.distance_to(position) <= 11.0


func squish() -> void:
	if dead:
		return
	dead = true
	Sfx.play("shard", 0.7, 120)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.4, 0.1), 0.12)
	t.tween_interval(0.2)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)
