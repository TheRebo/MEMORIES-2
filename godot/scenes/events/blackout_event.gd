class_name BlackoutEvent
extends RoomEvent
## Power cut: only candle-lit spots can be cleaned; staying dark too long grows cobwebs.

const DEFAULTS := {
	"blackoutDuration": 100.0,
	"darkColor": [0.1, 0.1, 0.18, 1.0],
	"emergencyCandles": 2,
	"hintPosition": {"x": 224, "y": 200},
	"cobwebDelay": 12.0,
	"cobwebInterval": 8.0,
	"maxExtraCobwebs": 8,
	"cobwebArea": {"x": 10, "y": 8, "w": 428, "h": 44},
	"cobwebSize": {"x": 20, "y": 16},
	"cobwebTaskGroup": "Dust off the new cobwebs",
	"cobwebEffort": 200.0,
}

var _elapsed := 0.0
var _dark_time := 0.0
var _since_web := 0.0
var _extra := 0
var _given := 0
var _was_lit := true


func _key_label() -> String:
	return String(Db.game["candle_key"]["label"])


func on_start() -> void:
	var c := room.ctx
	c.blackout = true
	c.blackout_changed.emit(true)
	var dark: Array = cfg["darkColor"]
	room.lighting.add_tint("blackout", [0.55 + float(dark[0]), 0.55 + float(dark[1]), 0.55 + float(dark[2]), 1.0])
	room.lighting.set_blackout(true)
	Sfx.play("blackout_on", 0.9)
	if GameState.count("candle") <= 0:
		_grant("You found a candle in the kitchen drawer.")
	if not room.candles.burnt_out.is_connected(_on_burnt):
		room.candles.burnt_out.connect(_on_burnt)
	_elapsed = 0.0
	_dark_time = 0.0
	_since_web = 0.0
	_extra = 0
	_given = 0
	_was_lit = false
	var hint_pos := point("hintPosition")
	point_at("candle", func() -> Variant: return null if _was_lit else hint_pos)
	c.attend.emit(hint_pos)
	set_objective("It is dark! Hold %s (or hold the Candle slot) and release on the floor to place a candle." % _key_label())


func _on_burnt() -> void:
	if running and GameState.count("candle") <= 0:
		_grant("You found a spare candle!")


func _grant(msg: String) -> void:
	if _given >= int(cfg["emergencyCandles"]):
		return
	_given += 1
	GameState.add_item("candle", 1)
	Sfx.play("reward", 0.7)
	room.ctx.toast.emit(msg)


func _process(dt: float) -> void:
	if not running:
		return
	_elapsed += dt
	var lit := room.candles.active_count() > 0
	if lit != _was_lit:
		_was_lit = lit
		if lit:
			set_objective("")
		else:
			var hint_pos := point("hintPosition")
			point_at("candle", func() -> Variant: return null if _was_lit else hint_pos)
			set_objective("The candle went out! Place another one (%s) before more cobwebs grow." % _key_label())
	if lit:
		_dark_time = 0.0
		_since_web = 0.0
	else:
		_dark_time += dt
		if _dark_time >= float(cfg["cobwebDelay"]):
			_since_web += dt
			if _since_web >= float(cfg["cobwebInterval"]):
				_since_web = 0.0
				_spawn_cobweb()
	if _elapsed >= float(cfg["blackoutDuration"]):
		_end()


func _spawn_cobweb() -> void:
	if _extra >= int(cfg["maxExtraCobwebs"]):
		return
	_extra += 1
	var p := random_in(rect("cobwebArea"))
	var size: Dictionary = cfg["cobwebSize"]
	spawn_dirt({
		"x": p.x, "y": p.y, "w": size["x"], "h": size["y"], "tool": "duster", "effort": cfg["cobwebEffort"],
		"group": cfg["cobwebTaskGroup"], "tex": Db.named.get("web_a" if _extra % 2 == 1 else "web_b", ""),
	})
	room.ctx.toast.emit("More cobwebs!")
	room.ctx.tasks_changed.emit()


func _end() -> void:
	var c := room.ctx
	clear_point("candle")
	c.blackout = false
	c.blackout_changed.emit(false)
	room.lighting.remove_tint("blackout")
	room.lighting.set_blackout(false)
	room.candles.extinguish_all()
	Sfx.play("blackout_off", 0.9)
	set_objective("")
	c.dialog.emit("MC", "Listriknya menyala lagi. Syukurlah!", 3.5)
	finish()


func debug_end() -> void:
	if running:
		_end()
