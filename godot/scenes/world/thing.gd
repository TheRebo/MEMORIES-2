@tool
class_name Thing
extends Sprite2D
## A placed sprite in a room layout (scenes/rooms/*.tscn). Base-anchored things stand on their
## position ("feet") and sort by y, in the editor too. The hit area follows the visible pixels
## of the texture, so a 128px canvas with a small vase is only clickable on the vase.

const Z_GROUND := -3000
const Z_FLOOR_DIRT := -2500
const Z_RAISED := 1000
const Z_DRAGGED := 3000

static var _used_rects: Dictionary = {}

@export var object_id := ""
@export var label_text := ""
## "ysort" things sort by their y; "ground" things (rugs) lie under everything.
@export_enum("ysort", "ground") var layer_name := "ysort":
	set(v):
		layer_name = v
		_refresh()
## Above 0 the thing sits on top of furniture (a book on a table).
@export var z_level := 0:
	set(v):
		z_level = v
		_refresh()
## Position is the bottom centre of the picture (otherwise its centre).
@export var origin_at_base := true:
	set(v):
		origin_at_base = v
		_refresh()
@export var has_shadow := false:
	set(v):
		has_shadow = v
		_refresh()
## Hit-area size in texture pixels. Zero uses the texture's own size.
@export var area_size := Vector2.ZERO

var base_scale := Vector2.ONE
var shadow: Polygon2D

var w: float:
	get:
		return area_size.x if area_size.x > 0.0 else (float(texture.get_width()) if texture else 0.0)
var h: float:
	get:
		return area_size.y if area_size.y > 0.0 else (float(texture.get_height()) if texture else 0.0)


func _ready() -> void:
	centered = true
	z_as_relative = false
	base_scale = scale
	_refresh()
	if Engine.is_editor_hint():
		set_notify_transform(true)
		texture_changed.connect(_refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		apply_depth()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_apply_origin()
	if has_shadow and origin_at_base:
		_make_shadow()
	elif shadow:
		shadow.queue_free()
		shadow = null
	apply_depth()


## Swap the picture (window opening, shelf filling). The hit area follows the new picture.
func set_tex(t: Texture2D) -> void:
	texture = t
	area_size = Vector2.ZERO
	_apply_origin()


func _apply_origin() -> void:
	var th := float(texture.get_height()) if texture else h
	offset = Vector2(0, -th / 2.0) if origin_at_base else Vector2.ZERO


func _make_shadow() -> void:
	if shadow == null:
		shadow = Polygon2D.new()
		shadow.color = Color(0, 0, 0, 0.22)
		shadow.show_behind_parent = true
		add_child(shadow)
	var sw := maxf(6.0, w * 0.8) / 2.0
	var sh := minf(10.0, maxf(3.0, w * 0.16)) / 2.0
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(Vector2(cos(a) * sw, sin(a) * sh - 1.0))
	shadow.polygon = pts


func depth_for() -> int:
	if layer_name == "ground":
		return Z_GROUND + z_level * 10
	return (Z_RAISED if z_level > 0 else 0) + int(global_position.y)


func apply_depth(extra: int = 0) -> void:
	z_index = clampi(depth_for() + extra, -4000, 4000)


## Visible pixels of the texture (cached per texture).
func _used_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var key := texture.resource_path
	if key != "" and _used_rects.has(key):
		return _used_rects[key]
	var r := Rect2(Vector2.ZERO, texture.get_size())
	var img := texture.get_image()
	if img:
		var used := img.get_used_rect()
		if used.size.x > 0:
			r = Rect2(used)
	if key != "":
		_used_rects[key] = r
	return r


## World rectangle of the visible pixels.
func bounds() -> Rect2:
	var gs := global_scale.abs()
	var full := Vector2(w * gs.x, h * gs.y)
	var gp := global_position
	var left := gp.x - full.x / 2.0
	var top := gp.y - full.y if origin_at_base else gp.y - full.y / 2.0
	var bb := _used_rect()
	if bb.size == Vector2.ZERO or w <= 0.0 or texture == null:
		return Rect2(left, top, full.x, full.y)
	var kx := full.x / float(texture.get_width())
	var ky := full.y / float(texture.get_height())
	return Rect2(left + bb.position.x * kx, top + bb.position.y * ky, bb.size.x * kx, bb.size.y * ky)


func has_point(p: Vector2, margin: float = 0.0) -> bool:
	return bounds().grow(margin).has_point(p)


func center() -> Vector2:
	return bounds().get_center()
