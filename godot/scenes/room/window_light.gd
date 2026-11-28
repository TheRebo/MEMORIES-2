class_name WindowLight
extends Node2D
## A slanted wedge of daylight from a window with dust drifting in it (window_light.tscn).
## Brighter as the room gets cleaner: grimy glass lets less light through.

var _base := 0.05
var _t := 0.0

@onready var _beam: Polygon2D = %Beam
@onready var _specks: CPUParticles2D = %Specks


func place(x: float, wall_y: float, width: float) -> void:
	position = Vector2(x + 10, wall_y)
	var w := width * 1.6
	_beam.polygon = PackedVector2Array([Vector2(-w * 0.38, 0), Vector2(w * 0.03, 0), Vector2(w * 0.5, 150), Vector2(-w * 0.16, 150)])
	_specks.emission_rect_extents = Vector2(width * 0.6, 60)
	_specks.position = Vector2(width * 0.2 - 10, 70)
	_specks.emitting = not Settings.reduced_motion()


func set_strength(strength: float) -> void:
	_base = 0.04 + 0.16 * clampf(strength, 0.0, 1.2)


func _process(dt: float) -> void:
	_t += dt
	# A slow shimmer, like leaves moving outside.
	var wobble := 0.0 if Settings.reduced_motion() else sin(_t * TAU / 5.2) * 0.15
	_beam.modulate.a = _base * (1.0 + wobble)
