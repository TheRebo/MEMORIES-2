@tool
class_name Interactable
extends Thing
## Double-click objects: tidy the pillow, throw out the wilted vase.

@export var group := ""
@export var trash := false
## Double clicks it takes.
@export var needed := 1
## Picture once done (a tidy pillow); empty keeps the picture.
@export var after_texture: Texture2D
## Fades away once done (thrown out).
@export var hide_after := false

var done := false
var _count := 0
var _hovered := false


func set_hover(on: bool) -> void:
	if done:
		on = false
	if _hovered == on:
		return
	_hovered = on
	modulate = Color(1.0, 0.95, 0.84) if on else Color.WHITE


## True when this interaction finished the object.
func interact() -> bool:
	if done:
		return false
	_count += 1
	var t := create_tween()
	t.tween_property(self, "scale", base_scale * Vector2(1.14, 0.9), 0.08)
	t.tween_property(self, "scale", base_scale, 0.08)
	if _count < maxi(1, needed):
		return false
	_finish(false)
	return true


func restore_done() -> void:
	_count = needed
	_finish(true)


func _finish(instant: bool) -> void:
	done = true
	_hovered = false
	modulate = Color.WHITE
	if after_texture:
		set_tex(after_texture)
	if hide_after:
		if instant:
			hide()
		else:
			if shadow:
				shadow.hide()
			var t := create_tween().set_parallel(true)
			t.tween_property(self, "modulate:a", 0.0, 0.26)
			t.tween_property(self, "position:y", position.y - 6.0, 0.26)
			t.chain().tween_callback(hide)
