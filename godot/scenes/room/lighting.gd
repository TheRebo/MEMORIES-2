class_name Lighting
extends Node
## Room ambience (lighting.tscn): a CanvasModulate that warms up as the room gets cleaner,
## an additive flash (lightning, celebration), and a blackout where only candles light the room.

const DIM := Color(0.8, 0.76, 0.73)
const CLEAN := Color(1.0, 0.97, 0.92)
const WARM := Color(1.0, 0.9, 0.74)
const DARK := Color(0.05, 0.055, 0.09)

var _base := DIM
var _base_target := DIM
var _tints: Dictionary = {}
var _current := DIM
var _flash := 0.0
var _darkness := 0.0
var _darkness_target := 0.0
var _breathe := 0.0
var _time := 0.0

@onready var _modulate: CanvasModulate = %Modulate
@onready var _flash_rect: ColorRect = %Flash


## 0 = filthy, 1 = clean.
func set_cleanliness(t: float) -> void:
	_base_target = DIM.lerp(CLEAN, clampf(t, 0.0, 1.0))


func set_warm(instant: bool) -> void:
	_base_target = WARM
	_breathe = 0.025
	if instant:
		_base = WARM


func add_tint(id: String, c: Array) -> void:
	_tints[id] = Color(float(c[0]), float(c[1]), float(c[2]))


func remove_tint(id: String) -> void:
	_tints.erase(id)


func pulse_flash(peak: float, seconds: float) -> void:
	if Settings.reduced_motion():
		peak *= 0.25
	var t := create_tween()
	t.tween_method(_set_flash.bind(peak), 0.0, 1.0, seconds)
	t.tween_callback(func() -> void: _flash = 0.0)


func _set_flash(v: float, peak: float) -> void:
	_flash = (v / 0.25 if v < 0.25 else 1.0 - (v - 0.25) / 0.75) * peak


func set_blackout(on: bool) -> void:
	_darkness_target = 0.92 if on else 0.0


func _process(dt: float) -> void:
	_time += dt
	_base = _base.lerp(_base_target, 1.0 - exp(-3.0 * dt))
	var target := _base
	for c: Color in _tints.values():
		target = Color(target.r * c.r, target.g * c.g, target.b * c.b)
	_current = _current.lerp(target, 1.0 - exp(-4.0 * dt))
	_darkness += (_darkness_target - _darkness) * (1.0 - exp(-2.5 * dt))
	var b := 1.0 + _breathe * sin(_time * 1.6)
	var lit := Color(_current.r * b, _current.g * b, _current.b * b)
	_modulate.color = lit.lerp(DARK, _darkness)
	_flash_rect.color.a = maxf(0.0, _flash) * 0.6
