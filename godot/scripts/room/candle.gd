class_name Candle
extends Node2D
## Placed during a blackout. Lights a circle, burns down, flickers, then goes out.

var burn_time := 45.0
var base_radius := 200.0
var remaining := 45.0
var radius := 200.0
var alive := true
var _sprite: Sprite2D
var _light: PointLight2D
var _label: Label


func setup(pos: Vector2, burn: float, r: float) -> Candle:
	position = pos
	burn_time = burn
	remaining = burn
	base_radius = r
	radius = r
	z_index = 1000 + int(pos.y)
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.texture = Db.tex(String(Db.named.get("candle", "lilin")))
	if _sprite.texture:
		_sprite.offset = Vector2(0, -_sprite.texture.get_height() / 2.0)
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = Fx.radial()
	_light.color = Color(1.0, 0.82, 0.58)
	_light.energy = 1.2
	_light.position = Vector2(0, -10)
	add_child(_light)
	_label = Label.new()
	_label.add_theme_font_override("font", UI.body_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", UI.CREAM)
	_label.add_theme_color_override("font_outline_color", UI.INK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.position = Vector2(-12, -34)
	_label.size = Vector2(24, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("candle_light", 0.8)
	return self


func light_pos() -> Vector2:
	return position + Vector2(0, -10)


func is_lit(p: Vector2) -> bool:
	return alive and p.distance_to(light_pos()) <= radius


## False once burnt out.
func tick(dt: float) -> bool:
	if not alive:
		return false
	remaining -= dt
	var fade := clampf(remaining / (burn_time * 0.2), 0.0, 1.0)
	var flicker := 1.0 + randf_range(-0.04, 0.04)
	radius = base_radius * (0.55 + 0.45 * fade) * flicker
	_light.texture_scale = radius * 2.4 / 256.0
	_light.energy = 1.2 * (0.4 + 0.6 * fade)
	_label.text = "%ds" % maxi(0, ceili(remaining))
	_label.add_theme_color_override("font_color", UI.WARN if remaining < 8.0 else UI.CREAM)
	if remaining <= 0.0:
		snuff()
		Sfx.play("candle_out", 0.8)
		return false
	return true


func snuff() -> void:
	alive = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_property(_light, "energy", 0.0, 0.5)
	t.chain().tween_callback(queue_free)
