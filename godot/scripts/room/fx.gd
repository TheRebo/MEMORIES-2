class_name Fx
extends Node2D
## Particles and small effects in world space. One-shot bursts free themselves.

const Z_FX := 3600

static var _px: Texture2D
static var _star: Texture2D
static var _radial: Texture2D

var _motes: CPUParticles2D
var _motes_alpha := 0.5


static func px() -> Texture2D:
	if _px == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_px = ImageTexture.create_from_image(img)
	return _px


static func star() -> Texture2D:
	if _star == null:
		var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for i in 5:
			img.set_pixel(2, i, Color.WHITE)
			img.set_pixel(i, 2, Color.WHITE)
		_star = ImageTexture.create_from_image(img)
	return _star


## Soft radial light, used for candle glow and light holes.
static func radial() -> Texture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_radial = t
	return _radial


func setup(size: Vector2) -> void:
	z_index = Z_FX
	z_as_relative = false
	_motes = CPUParticles2D.new()
	_motes.texture = px()
	_motes.amount = 34
	_motes.lifetime = 6.0
	_motes.preprocess = 6.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = size / 2.0
	_motes.position = size / 2.0
	_motes.direction = Vector2(1, 0)
	_motes.spread = 180.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 1.0
	_motes.initial_velocity_max = 4.0
	_motes.scale_amount_min = 0.25
	_motes.scale_amount_max = 0.5
	_motes.color_ramp = _fade_ramp(Color(0.85, 0.82, 0.75))
	add_child(_motes)
	set_motes(0.5, Color("d9d0c0"))
	_motes.emitting = not Settings.reduced_motion()


func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c, 0))
	g.set_color(1, Color(c, 0))
	g.add_point(0.5, Color(c, 1))
	return g


## Ambient dust: dense and grey while dirty, sparse warm gold once clean.
func set_motes(alpha: float, tint: Color) -> void:
	_motes_alpha = alpha
	_motes.modulate = Color(tint, alpha)


func _burst(pos: Vector2, tex: Texture2D, n: int, life: float, vmin: float, vmax: float,
		dir: Vector2, spread: float, grav: float, color: Color, scale_from: float = 1.0) -> void:
	if n <= 0:
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = life
	p.position = pos
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2(0, grav)
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = scale_from * 0.6
	p.scale_amount_max = scale_from
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	p.color_ramp = _alpha_out()
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _alpha_out() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func scrub_at(pos: Vector2, tint: Color) -> void:
	_burst(pos, px(), 1 if Settings.reduced_motion() else 3, 0.45, 12, 40, Vector2(0, -1), 70, 60, tint, 0.5)


func clean_burst(pos: Vector2) -> void:
	var calm := Settings.reduced_motion()
	_burst(pos, star(), 4 if calm else 12, 0.6, 18, 55, Vector2(0, -1), 180, 0, Color("fff2b0"))
	puff_at(pos, 2 if calm else 6)


func puff_at(pos: Vector2, n: int = 6) -> void:
	_burst(pos, px(), 2 if Settings.reduced_motion() else n, 0.38, 8, 26, Vector2(0, -1), 90, 0, Color(0.85, 0.8, 0.7, 0.6), 1.0)


func celebrate(size: Vector2) -> void:
	if Settings.reduced_motion():
		return
	for i in 40:
		var t := get_tree().create_timer(i * 0.035, false)
		t.timeout.connect(func() -> void:
			if is_inside_tree():
				_burst(Vector2(randf_range(16, size.x - 16), randf_range(40, size.y - 16)), star(), 2, 0.6, 18, 55,
					Vector2(0, -1), 180, 0, [Color("fff2b0"), Color("f2b84b"), Color.WHITE].pick_random()))


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


## Daylight falling from a window onto the floor. Returns a setter for its strength (0..1.2).
func window_light(x: float, wall_y: float, width: float) -> Callable:
	var beam := Polygon2D.new()
	var w := width * 1.6
	beam.polygon = PackedVector2Array([Vector2(-w * 0.38, 0), Vector2(w * 0.03, 0), Vector2(w * 0.5, 150), Vector2(-w * 0.16, 150)])
	var top := Color(1.0, 0.94, 0.78, 0.9)
	var bottom := Color(1.0, 0.94, 0.78, 0.0)
	beam.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	beam.position = Vector2(x + 10, wall_y)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = mat
	beam.modulate.a = 0.05
	beam.z_index = -10
	add_child(beam)
	var specks := CPUParticles2D.new()
	specks.texture = px()
	specks.amount = 14
	specks.lifetime = 4.2
	specks.preprocess = 4.0
	specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	specks.emission_rect_extents = Vector2(width * 0.6, 60)
	specks.position = Vector2(x + width * 0.2, wall_y + 70)
	specks.gravity = Vector2(1, 2)
	specks.initial_velocity_min = 0.0
	specks.initial_velocity_max = 2.0
	specks.scale_amount_min = 0.25
	specks.scale_amount_max = 0.5
	specks.color_ramp = _fade_ramp(Color("fff0c8"))
	specks.emitting = not Settings.reduced_motion()
	add_child(specks)
	var state := {"base": 0.05}
	var shimmer := create_tween().set_loops()
	shimmer.tween_method(func(v: float) -> void:
		var wobble := 0.0 if Settings.reduced_motion() else sin(v) * 0.15
		beam.modulate.a = state["base"] * (1.0 + wobble), 0.0, TAU, 5.2)
	return func(strength: float) -> void: state["base"] = 0.04 + 0.16 * clampf(strength, 0.0, 1.2)


class Ring extends Node2D:
	var radius := 6.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color("f2b84b"), 1.5)
