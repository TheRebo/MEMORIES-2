class_name RainEvent
extends RoomEvent
## Sudden heavy rain: blue gloom, lightning, and new puddles to mop.

const DEFAULTS := {
	"puddleCount": 4,
	"puddleTaskGroup": "Mop the rain puddles",
	"puddleSize": {"x": 30, "y": 14},
	"puddleEffort": 220.0,
	"spawnArea": {"x": 50, "y": 110, "w": 340, "h": 190},
	"rainDuration": 14.0,
	"rainTint": [0.78, 0.84, 1.0, 1.0],
}

var _loop: AudioStreamPlayer

@onready var _rain: CPUParticles2D = %Rain


func on_start() -> void:
	room.lighting.add_tint("rain", cfg["rainTint"])
	var size: Dictionary = room.def["size"]
	_rain.emission_rect_extents = Vector2(float(size["w"]) / 2.0 + 60, 2)
	_rain.position = Vector2(float(size["w"]) / 2.0, -20)
	_rain.emitting = true
	_loop = Sfx.loop("rain_heavy", 0.7, 1.2)
	_thunder()
	later(1.8, _spawn_puddles)
	later(1.8 + float(cfg["rainDuration"]), _end)


func _thunder() -> void:
	Sfx.play("thunder", 0.9, 150)
	room.ctx.shake.emit(1.5, 0.5)
	room.lighting.pulse_flash(1.0, 0.35)


func _spawn_puddles() -> void:
	var area := rect("spawnArea")
	var size: Dictionary = cfg["puddleSize"]
	for i in int(cfg["puddleCount"]):
		var p := random_in(area)
		var d := spawn_dirt({
			"x": p.x, "y": p.y, "w": size["x"], "h": size["y"], "tool": "mop",
			"effort": cfg["puddleEffort"], "group": cfg["puddleTaskGroup"], "tex": Db.named.get("puddle", "genangan_air"),
		})
		Sfx.play("drip_floor", 0.6, 200)
		point_at("puddle%d" % i, func() -> Variant: return null if d.done else d.position + Vector2(0, -10))
	room.ctx.tasks_changed.emit()
	_thunder()


func _end() -> void:
	_rain.emitting = false
	Sfx.stop_loop(_loop, 1.2)
	_loop = null
	room.lighting.remove_tint("rain")
	room.ctx.dialog.emit("MC", "Hujannya reda... tapi lantainya jadi becek. Harus dipel!", 4.0)
	finish()


func _exit_tree() -> void:
	Sfx.stop_loop(_loop, 0.2)


func debug_end() -> void:
	if running:
		_end()
