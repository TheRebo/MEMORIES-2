@tool
class_name Zone
extends Thing
## Where items go: shelf, wardrobe, sink, bin. Its picture can change as it fills.

## Item type it takes.
@export var accepts := ""
@export var capacity := 1
## Refuses items once full.
@export var limit := true
## Pictures from empty to full (the first is the starting texture).
@export var states: Array[Texture2D] = []
## Pick the picture by how full it is, instead of one picture per item.
@export var states_by_fill := false
@export var show_counter := false

var received := 0
var _pulse: Tween
var _glow := false


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
	if states_by_fill:
		var ratio := float(received) / capacity
		idx = 0 if received == 0 else mini(states.size() - 1, 1 + int(floor(ratio * (states.size() - 1))))
	else:
		idx = mini(received, states.size() - 1)
	set_tex(states[idx])
