class_name WindEvent
extends RoomEvent
## Wind blows the window open. Click it again and again to close it (progress fades if you
## stop). While open the camera trembles and waves scatter tidied things and add dust.

const DEFAULTS := {
	"windowId": "Jendela",
	"clickGain": 0.07,
	"decayPerSecond": 0.1,
	"clickMargin": 6.0,
	"shakeWhileOpen": 0.8,
	"penaltyEnabled": true,
	"penaltyGrace": 8.0,
	"penaltyInterval": 10.0,
	"scatterTypes": ["desk_item", "clothes", "trash"],
	"scatterBase": 1,
	"scatterPerTier": 0.5,
	"maxScatter": 4,
	"dustBase": 1,
	"dustPerTier": 0.5,
	"maxDust": 4,
	"maxExtraDust": 20,
	"floorArea": {"x": 40, "y": 100, "w": 368, "h": 200},
	"dustSize": {"x": 28, "y": 14},
	"dustEffort": 200.0,
	"dustFloorGroup": "Sapu debu tertiup angin",
	"dustClothGroup": "Lap debu tertiup angin",
}

## Window pictures while it is blown open, half closed and closed (empty: its own picture).
@export var open_texture: Texture2D
@export var half_texture: Texture2D
@export var closed_texture: Texture2D

var _win: Thing
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
	Sfx.play("door_close", 0.7)
	_loop = Sfx.loop("wind_strong", 0.6, 1.0)
	var w := _win
	point_at("window", func() -> Variant: return Vector2(w.position.x, w.bounds().position.y - 4))
	room.ctx.attend.emit(w.center())
	set_objective("Klik jendela berkali-kali untuk menutupnya!")
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
	Sfx.play("rattle", 0.8)
	room.ctx.shake.emit(float(cfg["shakeWhileOpen"]) * 2.0, 0.4)
	room.ctx.toast.emit("Angin makin kencang! Barang berhamburan dan debu bertambah!")
	room.ctx.tasks_changed.emit()


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
		room.ctx.toast.emit("Jendela setengah tertutup! Terus klik!")
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
