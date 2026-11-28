class_name Fx
extends Node2D
## Particles and small effects in world space (fx.tscn). Bursts copy the one-shot emitters
## under Templates, so their look is edited in the scene; copies free themselves.

const WINDOW_LIGHT := preload("res://scenes/room/window_light.tscn")

@onready var _motes: CPUParticles2D = %Motes
@onready var _scrub: CPUParticles2D = %Scrub
@onready var _sparkle: CPUParticles2D = %Sparkle
@onready var _puff: CPUParticles2D = %Puff


func setup(size: Vector2) -> void:
	_motes.emission_rect_extents = size / 2.0
	_motes.position = size / 2.0
	set_motes(0.5, Color("d9d0c0"))
	_motes.emitting = not Settings.reduced_motion()


## Ambient dust: dense and grey while dirty, sparse warm gold once clean.
func set_motes(alpha: float, tint: Color) -> void:
	_motes.modulate = Color(tint, alpha)


func _burst(template: CPUParticles2D, pos: Vector2, n: int, color: Color = Color(0, 0, 0, 0)) -> void:
	if n <= 0:
		return
	var p := template.duplicate() as CPUParticles2D
	p.position = pos
	p.amount = n
	if color.a > 0.0:
		p.color = color
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func scrub_at(pos: Vector2, tint: Color) -> void:
	_burst(_scrub, pos, 1 if Settings.reduced_motion() else 3, tint)


func clean_burst(pos: Vector2) -> void:
	var calm := Settings.reduced_motion()
	_burst(_sparkle, pos, 4 if calm else 12)
	puff_at(pos, 2 if calm else 6)


func puff_at(pos: Vector2, n: int = 6) -> void:
	_burst(_puff, pos, 2 if Settings.reduced_motion() else n)


func celebrate(size: Vector2) -> void:
	if Settings.reduced_motion():
		return
	for i in 40:
		get_tree().create_timer(i * 0.035, false).timeout.connect(_celebrate_one.bind(size))


func _celebrate_one(size: Vector2) -> void:
	var tint: Color = [Color("fff2b0"), Color("f2b84b"), Color.WHITE].pick_random()
	_burst(_sparkle, Vector2(randf_range(16, size.x - 16), randf_range(40, size.y - 16)), 2, tint)


## Expanding amber rings that say "here".
func ping(pos: Vector2) -> void:
	for i in 2:
		var r := Ring.new()
		r.position = pos
		add_child(r)
		var t := r.create_tween()
		t.tween_interval(i * 0.26)
		t.tween_property(r, "radius", 22.0, 0.75).from(6.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(r, "modulate:a", 0.0, 0.75).from(1.0)
		t.tween_callback(r.queue_free)


## Daylight falling from a window onto the floor. Returns a setter for its strength.
func window_light(x: float, wall_y: float, width: float) -> Callable:
	var w: WindowLight = WINDOW_LIGHT.instantiate()
	add_child(w)
	w.place(x, wall_y, width)
	return w.set_strength


class Ring extends Node2D:
	var radius := 6.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color("f2b84b"), 1.5)
