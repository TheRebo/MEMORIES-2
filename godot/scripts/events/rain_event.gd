class_name RainEvent
extends RoomEvent
## Sudden heavy rain: blue gloom, lightning, and new puddles to mop.

const DEFAULTS := {
	"puddleCount": 4,
	"puddleTaskGroup": "Pel genangan air (hujan)",
	"puddleSize": {"x": 30, "y": 14},
	"puddleEffort": 220.0,
	"spawnArea": {"x": 50, "y": 110, "w": 340, "h": 190},
	"rainDuration": 14.0,
	"rainTint": [0.78, 0.84, 1.0, 1.0],
}

var _rain: CPUParticles2D
var _loop: AudioStreamPlayer


func on_start() -> void:
	room.lighting.add_tint("rain", cfg["rainTint"])
	var size: Dictionary = room.def["size"]
	_rain = CPUParticles2D.new()
	_rain.texture = Fx.px()
	_rain.amount = 260
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(float(size["w"]) / 2.0 + 60, 2)
	_rain.position = Vector2(float(size["w"]) / 2.0, -20)
	_rain.direction = Vector2(-0.18, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 300
	_rain.initial_velocity_max = 380
	_rain.scale_amount_min = 0.5
	_rain.scale_amount_max = 0.5
	_rain.particle_flag_align_y = true
	_rain.color = Color(0.77, 0.85, 1.0, 0.5)
	_rain.z_index = 3700
	_rain.z_as_relative = false
	room.world.add_child(_rain)
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
	if _rain:
		_rain.emitting = false
		var r := _rain
		get_tree().create_timer(1.2, false).timeout.connect(r.queue_free)
		_rain = null
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
