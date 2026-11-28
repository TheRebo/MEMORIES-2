class_name CameraRig
extends Camera2D
## Top-down room camera: pans while the pointer nears the edge of the free area between HUD
## panels, zooms with the wheel, shakes, briefly frames spots that need the player, and takes
## over during the flashback.

const VIEW := Vector2(1280, 720)
const HUD_TOP := 92.0
const HUD_BOTTOM := 108.0

var world_size := Vector2(512, 352)
var inset_left := 0.0
var cinematic := false
var user_enabled := true
var cfg: Dictionary = {}
var _zoom := 3.0
var _target_zoom := 3.0
var _pos := Vector2.ZERO
var _pan := Vector2.ZERO
var _cin_target := Vector2.ZERO
var _shake_t := 0.0
var _shake_total := 0.1
var _shake_strength := 0.0
var _pulse := 0.0
var _attend_until := 0.0
var _attend_target := Vector2.ZERO
var _clock := 0.0


func setup(size: Vector2) -> void:
	cfg = Db.game.get("camera", {})
	world_size = size
	_zoom = float(cfg.get("defaultZoom", 3))
	_target_zoom = _zoom
	_pos = size / 2.0
	_cin_target = _pos
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	_apply(Vector2.ZERO, _zoom)


func usable() -> Rect2:
	if cinematic:
		return Rect2(Vector2.ZERO, VIEW)
	return Rect2(inset_left, HUD_TOP, VIEW.x - inset_left, VIEW.y - HUD_TOP - HUD_BOTTOM)


func wheel(dir: float) -> void:
	if not user_enabled or cinematic:
		return
	var step := float(cfg.get("zoomStep", 0.25))
	_target_zoom = clampf(_target_zoom - signf(dir) * step, float(cfg.get("minZoom", 1.6)), float(cfg.get("maxZoom", 5)))


func shake_cam(strength: float, duration: float) -> void:
	if not Settings.screen_shake:
		return
	_shake_strength = maxf(_shake_strength if _shake_t > 0.0 else 0.0, strength)
	_shake_total = maxf(0.05, duration)
	_shake_t = _shake_total


func zoom_pulse(amount: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: _pulse = sin(v * PI) * amount, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)


func attend_to(p: Vector2, seconds: float = 2.2) -> void:
	_attend_target = p
	_attend_until = _clock + seconds


func begin_cinematic() -> void:
	cinematic = true
	_cin_target = world_size / 2.0


func focus(p: Vector2, z: float = 0.0) -> void:
	_cin_target = p
	if z > 0.0:
		_target_zoom = clampf(z, float(cfg.get("minZoom", 1.6)), float(cfg.get("maxZoom", 5)))


func end_cinematic() -> void:
	cinematic = false
	_target_zoom = float(cfg.get("defaultZoom", 3))


## World point at the middle of the visible area.
func world_center() -> Vector2:
	return screen_to_world(usable().get_center())


func step(dt: float, pointer: Vector2) -> void:
	_clock += dt
	var k := 1.0 - exp(-float(cfg.get("smoothing", 6)) * dt)
	_zoom += (_target_zoom - _zoom) * k
	var u := usable()
	var eff := _zoom + _pulse
	var view := u.size / eff
	var target: Vector2
	if cinematic:
		var hw := view.x / 2.0
		var hh := view.y / 2.0
		target = Vector2(
			clampf(_cin_target.x, minf(hw, world_size.x / 2.0), maxf(hw, world_size.x - hw)),
			clampf(_cin_target.y, minf(hh, world_size.y / 2.0), maxf(hh, world_size.y - hh)))
	else:
		var max_now := Vector2(maxf(1.0, (world_size.x - view.x) / 2.0), maxf(1.0, (world_size.y - view.y) / 2.0))
		if _clock < _attend_until:
			_pan = Vector2(clampf((_attend_target.x - world_size.x / 2.0) / max_now.x, -1, 1),
				clampf((_attend_target.y - world_size.y / 2.0) / max_now.y, -1, 1))
		elif user_enabled and u.has_point(pointer):
			var nx := clampf((pointer.x - u.get_center().x) / (u.size.x / 2.0), -1, 1)
			var ny := clampf((pointer.y - u.get_center().y) / (u.size.y / 2.0), -1, 1)
			_pan = Vector2(_dead(nx), _dead(ny))
		var max_pan := Vector2(maxf(0.0, (world_size.x - view.x) / 2.0), maxf(0.0, (world_size.y - view.y) / 2.0))
		target = world_size / 2.0 + _pan * max_pan
	_pos += (target - _pos) * k
	var sh := Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= dt
		var s := (maxf(0.0, _shake_t) / _shake_total) * _shake_strength
		sh = Vector2(randf_range(-s, s), randf_range(-s, s))
	_apply(sh, eff)


## Put world point `_pos` at the centre of the usable screen rect.
func _apply(sh: Vector2, z: float) -> void:
	zoom = Vector2(z, z)
	var u := usable()
	position = _pos - (u.get_center() - VIEW / 2.0) / z + sh


func _dead(v: float) -> float:
	var dz := float(cfg.get("deadZone", 0.2))
	var a := absf(v)
	if a <= dz:
		return 0.0
	return signf(v) * (a - dz) / (1.0 - dz)


func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p
