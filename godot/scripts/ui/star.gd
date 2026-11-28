class_name Star
extends Control
## Five-point pixel star (same shape as the web build's CSS clip-path).

const SHAPE := [Vector2(0.5, 0), Vector2(0.62, 0.35), Vector2(1, 0.38), Vector2(0.7, 0.6), Vector2(0.8, 1),
	Vector2(0.5, 0.76), Vector2(0.2, 1), Vector2(0.3, 0.6), Vector2(0, 0.38), Vector2(0.38, 0.35)]

var color := UI.WOOD_600:
	set(v):
		color = v
		queue_redraw()


func _init(px: float = 16.0, c: Color = UI.WOOD_600) -> void:
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	pivot_offset = size / 2.0
	color = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in SHAPE:
		pts.append(p * size)
	draw_colored_polygon(pts, color)
