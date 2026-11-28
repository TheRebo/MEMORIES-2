class_name Roach
extends Sprite2D
## (roach.tscn) Scuttles across the floor in short dashes, turning toward where it runs;
## cleaning is blocked until it is clicked. The art faces right.

const TURN_SPEED := 10.0

var area := Rect2()
var speed := 40.0
var dead := false
var _target := Vector2.ZERO
var _pause := 0.0
var _dash := 0.0
var _t := 0.0


func setup(pos: Vector2, walk: Rect2, spd: float) -> Roach:
	position = pos
	area = walk
	speed = spd
	_pick()
	rotation = (_target - position).angle()
	return self


## Next spot a short run away, kept inside the walk area, so it zigzags instead of crossing
## the whole room in a straight line.
func _pick() -> void:
	var step := randf_range(28.0, 80.0)
	var dir := Vector2.from_angle(rotation + randf_range(-1.4, 1.4))
	var p := position + dir * step
	if not area.has_point(p):
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
	_target = p
	_dash = randf_range(0.6, 1.6)


func _process(dt: float) -> void:
	if dead:
		return
	_t += dt
	if _pause > 0.0:
		_pause -= dt
		# Antennae twitch while it waits.
		rotation += sin(_t * 30.0) * 0.01
		return
	var d := _target - position
	var dist := d.length()
	if dist < 2.0:
		_pause = randf_range(0.15, 0.6) if randf() < 0.6 else 0.0
		_pick()
		return
	# Turn smoothly toward the heading, and only run fast once it faces the way.
	rotation = lerp_angle(rotation, d.angle(), 1.0 - exp(-TURN_SPEED * dt))
	var facing := clampf(Vector2.from_angle(rotation).dot(d / dist), 0.0, 1.0)
	var burst := 1.6 if _dash > 0.0 else 0.8
	_dash -= dt
	position += d / dist * minf(dist, speed * burst * facing * dt)
	# A tiny side-to-side wobble of the legs.
	offset.y = sin(_t * 40.0) * 0.6


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
