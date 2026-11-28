@tool
class_name Actor
extends Thing
## A character for the flashback cutscenes (Nenek, MC kecil, MC). Hidden in the game until a
## line shows it; visible in the editor so it can be placed.

## Name used by the flashback lines ("nenek", "mc_kecil", "mc").
@export var actor := ""


func _ready() -> void:
	has_shadow = true
	super()
	if not Engine.is_editor_hint():
		hide()


func appear() -> void:
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func vanish() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


## Walk to a point with a little step bob; returns when there.
func walk_to(to: Vector2) -> void:
	var dist := position.distance_to(to)
	var secs := clampf(dist / 40.0, 0.3, 3.0)
	if to.x != position.x:
		flip_h = to.x < position.x
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", to, secs)
	var bob := create_tween().set_loops(int(secs / 0.24) + 1)
	bob.tween_property(self, "offset:y", offset.y - 1.5, 0.12)
	bob.tween_property(self, "offset:y", offset.y, 0.12)
	await t.finished
	apply_depth()
