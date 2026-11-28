class_name Candle
extends Node2D
## Placed during a blackout (candle.tscn). Lights a circle, burns down, flickers, goes out.

var burn_time := 45.0
var base_radius := 200.0
var remaining := 45.0
var radius := 200.0
var alive := true

@onready var _sprite: Sprite2D = %Sprite
@onready var _light: PointLight2D = %Light
@onready var _time: Label = %Time


func setup(pos: Vector2, burn: float, r: float) -> Candle:
	position = pos
	burn_time = burn
	remaining = burn
	base_radius = r
	radius = r
	z_index = 1000 + int(pos.y)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("candle_light", 0.8)
	return self


func light_pos() -> Vector2:
	return position + _light.position


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
	# The texture is 256px across and fades out at its edge: its radius is the lit radius.
	_light.texture_scale = radius * 2.0 / 256.0
	_light.energy = 1.2 * (0.4 + 0.6 * fade)
	_time.text = "%ds" % maxi(0, ceili(remaining))
	_time.add_theme_color_override("font_color", UI.WARN if remaining < 8.0 else UI.CREAM)
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
