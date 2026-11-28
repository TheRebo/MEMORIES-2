@tool
class_name PointerArrow
extends Control
## Amber arrow pointing down at what an event needs (tip at the node's origin); red when the
## target is off screen. `small` draws the little marker above a tool slot instead.

const SHAPE := [Vector2(0.5, 1), Vector2(0, 0.3), Vector2(0.3, 0.3), Vector2(0.3, 0), Vector2(0.7, 0),
	Vector2(0.7, 0.3), Vector2(1, 0.3)]

@export var small := false:
	set(v):
		small = v
		queue_redraw()
@export var edge := false:
	set(v):
		if v != edge:
			edge = v
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if small:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 7)]), UI.AMBER)
		return
	var pts := PackedVector2Array()
	var sh := PackedVector2Array()
	for v: Vector2 in SHAPE:
		var q := (v - Vector2(0.5, 1.0)) * 28.0
		pts.append(q)
		sh.append(q + Vector2(2, 2))
	draw_colored_polygon(sh, UI.INK)
	draw_colored_polygon(pts, UI.WARN if edge else UI.AMBER)
