class_name Thing
extends Sprite2D
## A placed sprite in the room. Base-anchored things stand on their (x, y) "feet" and sort by y.
## The hit area follows the visible pixels (alpha bbox), so a 128px canvas with a small vase
## is only clickable on the vase.

const Z_GROUND := -3000
const Z_FLOOR_DIRT := -2500
const Z_RAISED := 1000
const Z_DRAGGED := 3000

var id := ""
var w := 0.0
var h := 0.0
var origin_at_base := true
var layer_name := "ysort"
var z_level := 0
var tex_key := ""
var base_scale := Vector2.ONE
var shadow: Polygon2D


func setup(spec: Dictionary) -> Thing:
	id = String(spec.get("id", ""))
	w = float(spec.get("w", 0))
	h = float(spec.get("h", 0))
	origin_at_base = bool(spec.get("originAtBase", true))
	layer_name = String(spec.get("layer", "ysort"))
	z_level = int(spec.get("z", 0))
	var sc: Variant = spec.get("scale")
	if sc is Array:
		base_scale = Vector2(float(sc[0]), float(sc[1]))
	scale = base_scale
	position = Vector2(float(spec["x"]), float(spec["y"]))
	rotation = float(spec.get("rotation", 0.0))
	centered = true
	var key := String(spec.get("tex", ""))
	if key != "":
		set_tex(key)
		# The level data's size wins for hit areas (as in the web build); art keeps its own size.
		w = float(spec.get("w", w))
		h = float(spec.get("h", h))
	if bool(spec.get("shadow", false)) and origin_at_base:
		_make_shadow()
	apply_depth()
	return self


func set_tex(key: String) -> void:
	tex_key = key
	texture = Db.tex(key)
	var info := Db.sprite_info(key)
	if not info.is_empty():
		w = float(info["w"])
		h = float(info["h"])
	_apply_origin()


func _apply_origin() -> void:
	# Base-anchored: (x, y) is the bottom centre of the image.
	var th := float(texture.get_height()) if texture else h
	offset = Vector2(0, -th / 2.0) if origin_at_base else Vector2.ZERO


func _make_shadow() -> void:
	shadow = Polygon2D.new()
	var sw := maxf(6.0, w * 0.8) / 2.0
	var sh := minf(10.0, maxf(3.0, w * 0.16)) / 2.0
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(Vector2(cos(a) * sw, sin(a) * sh - 1.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.22)
	shadow.show_behind_parent = true
	add_child(shadow)


func depth_for() -> int:
	if layer_name == "ground":
		return Z_GROUND + z_level * 10
	return (Z_RAISED if z_level > 0 else 0) + int(position.y)


func apply_depth(extra: int = 0) -> void:
	z_index = clampi(depth_for() + extra, -4000, 4000)


## World rectangle of the visible pixels.
func bounds() -> Rect2:
	var sx := absf(scale.x)
	var sy := absf(scale.y)
	var full := Vector2(w * sx, h * sy)
	var left := position.x - full.x / 2.0
	var top := position.y - full.y if origin_at_base else position.y - full.y / 2.0
	var bb := Db.bbox(tex_key) if tex_key != "" else Rect2()
	if bb.size == Vector2.ZERO or w <= 0.0:
		return Rect2(left, top, full.x, full.y)
	var kx := full.x / w
	var ky := full.y / h
	return Rect2(left + bb.position.x * kx, top + bb.position.y * ky, bb.size.x * kx, bb.size.y * ky)


func has_point(p: Vector2, margin: float = 0.0) -> bool:
	return bounds().grow(margin).has_point(p)


func center() -> Vector2:
	return bounds().get_center()
