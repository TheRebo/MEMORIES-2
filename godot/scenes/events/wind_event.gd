class_name WindEvent
extends RoomEvent
## A gale blows the window open. Click it again and again to close it (progress fades if you
## stop). While it is open, wind streams in: the room turns cold, loose things slide and
## shake, and every gust throws tidied things back on the floor, brings in dust and dirties
## cleaned spots again. The longer it stays open, the harder the gusts.

const DEFAULTS := {
	"windowId": "Jendela",
	"clickGain": 0.06,
	"decayPerSecond": 0.14,
	"clickMargin": 6.0,
	"shakeWhileOpen": 1.4,
	"penaltyEnabled": true,
	"penaltyGrace": 3.0,
	"penaltyInterval": 6.0,
	"scatterTypes": ["desk_item", "clothes", "trash", "book", "pajangan"],
	"scatterBase": 2,
	"scatterPerTier": 1.0,
	"maxScatter": 6,
	"dustBase": 2,
	"dustPerTier": 1.0,
	"maxDust": 6,
	"maxExtraDust": 30,
	## Cleaned spots the gust dirties again, growing per gust.
	"redirtyBase": 1,
	"redirtyPerTier": 1.0,
	"maxRedirty": 5,
	## How far loose things on the floor slide per gust (room pixels).
	"pushDistance": 26.0,
	"windTint": [0.86, 0.9, 1.0, 1.0],
	"floorArea": {"x": 40, "y": 100, "w": 368, "h": 200},
	"dustSize": {"x": 28, "y": 14},
	"dustEffort": 200.0,
	"dustFloorGroup": "Sapu debu yang terbawa angin",
	"dustClothGroup": "Lap debu yang terbawa angin",
}

## Window pictures while it is blown open, half closed and closed (empty: its own picture).
@export var open_texture: Texture2D
@export var half_texture: Texture2D
@export var closed_texture: Texture2D

var _win: Thing
var _gust_t := 0.0

@onready var _gust: CPUParticles2D = %Gust
@onready var _leaves: CPUParticles2D = %Leaves
var _original: Texture2D
var _progress := 0.0
var _floor := 0.0
var _state := 0
var _elapsed := 0.0
var _wave_t := 0.0
var _shake_t := 0.0
var _dust_total := 0
var _loop: AudioStreamPlayer
var _intercept: Callable


func on_start() -> void:
	_win = room.find_thing(String(cfg["windowId"]))
	if _win == null:
		finish()
		return
	if _original == null:
		_original = _win.texture
	_progress = 0.0
	_floor = 0.0
	_elapsed = 0.0
	_wave_t = 0.0
	_dust_total = 0
	_set_state(0)
	Sfx.play("door_close", 0.9)
	_loop = Sfx.loop("wind_strong", 0.95, 0.6)
	room.lighting.add_tint("wind", cfg["windTint"])
	# The wind streams in from the window's sill toward the room.
	var b := _win.bounds()
	for p: CPUParticles2D in [_gust, _leaves]:
		p.position = Vector2(b.get_center().x, b.end.y)
		p.emission_rect_extents = Vector2(maxf(16.0, b.size.x / 2.0), 4)
		p.emitting = not Settings.reduced_motion()
	var w := _win
	point_at("window", func() -> Variant: return Vector2(w.position.x, w.bounds().position.y - 4))
	room.ctx.attend.emit(w.center())
	set_objective("Klik jendelanya terus sampai tertutup!")
	_emit_bar()
	_intercept = _on_click
	room.add_click_interceptor(_intercept)


func _set_state(s: int) -> void:
	_state = s
	if _win == null:
		return
	var pics: Array[Texture2D] = [open_texture, half_texture, closed_texture]
	var pic := pics[clampi(s, 0, 2)]
	if s == 2 and pic == null:
		pic = _original
	if pic:
		_win.set_tex(pic)


func _emit_bar() -> void:
	if running:
		set_bar("Jendela", _progress)


func _process(dt: float) -> void:
	if not running or _win == null:
		return
	_progress = maxf(_floor, _progress - float(cfg["decayPerSecond"]) * dt)
	_elapsed += dt
	_shake_t -= dt
	if _shake_t <= 0.0:
		room.ctx.shake.emit(float(cfg["shakeWhileOpen"]), 0.3)
		_shake_t = 0.4
	# Loose things on the floor and the window itself rattle in the draught.
	_gust_t += dt
	var still := Settings.reduced_motion()
	for it: Item in room.items:
		if not it.done and it.visible and it.z_index < Thing.Z_DRAGGED:
			it.rotation = 0.0 if still else sin(_gust_t * 9.0 + it.position.x) * 0.09
	if not still:
		_win.rotation = sin(_gust_t * 23.0) * 0.015
	if bool(cfg["penaltyEnabled"]) and _elapsed >= float(cfg["penaltyGrace"]):
		_wave_t += dt
		if _wave_t >= float(cfg["penaltyInterval"]):
			_wave_t = 0.0
			_penalty_wave()
	_emit_bar()


func _penalty_wave() -> void:
	var tier := floori((_elapsed - float(cfg["penaltyGrace"])) / float(cfg["penaltyInterval"]))
	var n_scatter := mini(int(cfg["maxScatter"]), int(cfg["scatterBase"]) + floori(tier * float(cfg["scatterPerTier"])))
	var n_dust := mini(int(cfg["maxDust"]), int(cfg["dustBase"]) + floori(tier * float(cfg["dustPerTier"])))
	var area := rect("floorArea")
	scatter(n_scatter, cfg["scatterTypes"], area)
	_push_loose(area)
	_redirty(mini(int(cfg["maxRedirty"]), int(cfg["redirtyBase"]) + floori(tier * float(cfg["redirtyPerTier"]))))
	var size: Dictionary = cfg["dustSize"]
	for i in n_dust:
		if _dust_total < int(cfg["maxExtraDust"]):
			var p := random_in(area)
			spawn_dirt({"x": p.x, "y": p.y, "w": size["x"], "h": size["y"], "tool": "broom",
				"effort": cfg["dustEffort"], "group": cfg["dustFloorGroup"], "tex": "debu_ulahan_daus"})
			_dust_total += 1
		var f := random_furniture()
		if f and _dust_total < int(cfg["maxExtraDust"]):
			var b := f.bounds()
			spawn_dirt({
				"x": b.get_center().x + randf_range(-0.35, 0.35) * b.size.x,
				"y": b.position.y + b.size.y * randf_range(0.15, 0.75),
				"w": 16, "h": 10, "tool": "cloth", "effort": float(cfg["dustEffort"]) * 0.8, "group": cfg["dustClothGroup"],
			}, f)
			_dust_total += 1
	Sfx.play("rattle", 1.0)
	Sfx.play("wind_strong", 0.8, -200)
	room.ctx.shake.emit(float(cfg["shakeWhileOpen"]) * 2.5, 0.5)
	room.camera.zoom_pulse(-0.12, 0.6)
	if not Settings.reduced_motion():
		_gust.amount = 90
		_gust.restart()
		_gust.emitting = true
	room.ctx.toast.emit("Anginnya makin kencang! Barang beterbangan dan debu mulai masuk!")
	room.ctx.tasks_changed.emit()


## Things still lying on the floor slide away from the window.
func _push_loose(area: Rect2) -> void:
	var from := _win.global_position
	for it: Item in room.items:
		if it.done or not it.visible or it.z_index >= Thing.Z_DRAGGED:
			continue
		var dir := (it.position - from).normalized()
		var to := it.position + dir * float(cfg["pushDistance"]) * randf_range(0.6, 1.2)
		to = to.clamp(area.position, area.end)
		it.home = to
		var t := it.create_tween()
		t.tween_property(it, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(it.apply_depth)


## Dust settles again on spots that were already clean.
func _redirty(n: int) -> void:
	if room.finished or n <= 0:
		return
	var clean: Array = []
	for d: Dirt in room.dirt:
		if d.done and (d.tool == "broom" or d.tool == "cloth" or d.tool == "duster"):
			clean.append(d)
	clean.shuffle()
	for d: Dirt in clean.slice(0, n):
		d.dirty_again(0.7)
	if not clean.is_empty():
		room.ctx.toast.emit("Angin membawa debu lagi ke tempat yang sudah bersih!")


func _on_click(p: Vector2) -> bool:
	if _win == null or not running or not _win.has_point(p, float(cfg["clickMargin"])):
		return false
	_progress = minf(1.0, _progress + float(cfg["clickGain"]))
	Sfx.play("window_close", 0.45, 200, 30)
	var x0 := _win.position.x
	var t := _win.create_tween()
	t.tween_property(_win, "position:x", x0 + 1.0, 0.04)
	t.tween_property(_win, "position:x", x0, 0.04)
	if _progress >= 0.5 and _state == 0:
		_floor = 0.5
		_set_state(1)
		room.ctx.toast.emit("Jendelanya sudah setengah tertutup! Terus klik!")
	if _progress >= 1.0:
		_close()
		return true
	_emit_bar()
	return true


func _close() -> void:
	room.remove_click_interceptor(_intercept)
	_set_state(2)
	Sfx.play("window_close", 0.9)
	Sfx.stop_loop(_loop, 0.6)
	_loop = null
	_gust.emitting = false
	_leaves.emitting = false
	_win.rotation = 0.0
	for it: Item in room.items:
		it.rotation = 0.0
	room.lighting.remove_tint("wind")
	clear_point("window")
	set_bar("", -1.0)
	set_objective("")
	room.ctx.dialog.emit("MC", "Fiuh... jendelanya akhirnya tertutup.", 3.0)
	finish()


func _exit_tree() -> void:
	Sfx.stop_loop(_loop, 0.2)


func debug_end() -> void:
	if running:
		_close()
