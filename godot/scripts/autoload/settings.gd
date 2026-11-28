extends Node
## Player settings (user://settings.json): volumes, screen motion, text speed.

signal changed

const PATH := "user://settings.json"

var master := 0.9
var music := 0.7
var sfx := 0.9
## Camera shake, flashes, drifting backgrounds and ambient dust. Also the pause control for looping motion.
var screen_shake := true
var text_speed := "normal"


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var raw: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if raw is Dictionary:
			var d: Dictionary = raw
			master = clampf(float(d.get("master", master)), 0.0, 1.0)
			music = clampf(float(d.get("music", music)), 0.0, 1.0)
			sfx = clampf(float(d.get("sfx", sfx)), 0.0, 1.0)
			screen_shake = bool(d.get("screenShake", screen_shake))
			var ts := String(d.get("textSpeed", text_speed))
			if ts in ["slow", "normal", "fast"]:
				text_speed = ts


func set_value(key: String, value: Variant) -> void:
	match key:
		"master": master = float(value)
		"music": music = float(value)
		"sfx": sfx = float(value)
		"screenShake": screen_shake = bool(value)
		"textSpeed": text_speed = String(value)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"master": master, "music": music, "sfx": sfx,
			"screenShake": screen_shake, "textSpeed": text_speed}))
	changed.emit()


func chars_per_second() -> float:
	return {"slow": 28.0, "normal": 48.0, "fast": 90.0}.get(text_speed, 48.0)


func reduced_motion() -> bool:
	return not screen_shake
