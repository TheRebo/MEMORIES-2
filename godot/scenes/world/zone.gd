class_name Zone
extends Thing
## Where items go: shelf, wardrobe, sink, bin. Its picture can change as it fills.

var accepts := ""
var capacity := 1
var limit := true
var label_text := ""
var states: Array = []
var by_fill := false
var received := 0
var _pulse: Tween
var _glow := false


func setup_zone(def: Dictionary) -> Zone:
	var s := def.duplicate()
	var st: Array = def.get("states", [])
	if not st.is_empty():
		s["tex"] = st[0]
	s["originAtBase"] = true
	s["layer"] = "ysort"
	setup(s)
	accepts = String(def.get("accepts", ""))
	capacity = maxi(1, int(def.get("capacity", 1)))
	limit = bool(def.get("limit", true))
	label_text = String(def.get("label", ""))
	states = st
	by_fill = bool(def.get("statesByFill", false))
	return self


func can_accept(it: Item) -> bool:
	if it.type != accepts or it.done:
		return false
	return not (limit and received >= capacity)


## Cue while a matching item is dragged: gentle pulse, brighter when hovered.
func set_target_state(state: String) -> void:
	modulate = Color(1.0, 0.94, 0.75) if state == "hover" else Color.WHITE
	var on := state != "off"
	if on == _glow and state != "hover":
		return
	_glow = on
	if _pulse:
		_pulse.kill()
	scale = base_scale
	if on:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale:y", base_scale.y * 1.04, 0.42).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "scale:y", base_scale.y, 0.42).set_trans(Tween.TRANS_SINE)


func receive(it: Item) -> void:
	received += 1
	_apply_state()
	it.consume_into(self)
	set_target_state("off")
	var t := create_tween()
	t.tween_interval(0.18)
	t.tween_property(self, "scale", base_scale * Vector2(1.08, 0.94), 0.09)
	t.tween_property(self, "scale", base_scale, 0.09)


func release_one() -> void:
	received = maxi(0, received - 1)
	_apply_state()


func set_fill(n: int) -> void:
	received = n
	_apply_state()


func _apply_state() -> void:
	if states.is_empty():
		return
	var idx := 0
	if by_fill:
		var ratio := float(received) / capacity
		idx = 0 if received == 0 else mini(states.size() - 1, 1 + int(floor(ratio * (states.size() - 1))))
	else:
		idx = mini(received, states.size() - 1)
	set_tex(String(states[idx]))
