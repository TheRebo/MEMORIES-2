class_name Interactable
extends Thing
## Double-click objects: tidy the pillow, throw out the wilted vase.

var group := ""
var trash := false
var label_text := ""
var done := false
var _needed := 1
var _after := ""
var _hide_after := false
var _count := 0
var _hovered := false


func setup_interact(def: Dictionary) -> Interactable:
	var s := def.duplicate()
	s["originAtBase"] = true
	s["layer"] = "ysort"
	setup(s)
	group = String(def.get("group", ""))
	trash = bool(def.get("trash", false))
	label_text = String(def.get("label", ""))
	_needed = maxi(1, int(def.get("needed", 1)))
	_after = String(def.get("after", ""))
	_hide_after = bool(def.get("hideAfter", false))
	return self


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
	if _count < _needed:
		return false
	_finish(false)
	return true


func restore_done() -> void:
	_count = _needed
	_finish(true)


func _finish(instant: bool) -> void:
	done = true
	_hovered = false
	modulate = Color.WHITE
	if _after != "":
		set_tex(_after)
	if _hide_after:
		if instant:
			hide()
		else:
			if shadow:
				shadow.hide()
			var t := create_tween().set_parallel(true)
			t.tween_property(self, "modulate:a", 0.0, 0.26)
			t.tween_property(self, "position:y", position.y - 6.0, 0.26)
			t.chain().tween_callback(hide)
