@tool
class_name Item
extends Thing
## Something lying around that belongs somewhere: dragged into its zone (shelf, bin, sink).

## Matches a Zone's `accepts` ("book", "dish", "trash", ...).
@export var type := ""
## Counts toward the trash total when put in a bin.
@export var trash := false
@export var group := ""

var done := false
var zone: Zone
var home := Vector2.ZERO
var _grab := Vector2.ZERO
var _hovered := false


func _ready() -> void:
	has_shadow = true
	super()
	home = position


func set_hover(on: bool) -> void:
	if _hovered == on or done:
		return
	_hovered = on
	modulate = Color(1.0, 0.95, 0.84) if on else Color.WHITE
	create_tween().tween_property(self, "scale", base_scale * (1.12 if on else 1.0), 0.09)


func begin_drag(p: Vector2) -> void:
	_hovered = false
	modulate = Color.WHITE
	_grab = position - p
	z_index = Z_DRAGGED
	create_tween().tween_property(self, "scale", base_scale * Vector2(1.2, 1.1), 0.08).set_trans(Tween.TRANS_BACK)


func drag_to(p: Vector2) -> void:
	position = p + _grab + Vector2(0, -3)


## Dropped somewhere invalid: glide back with a little bounce.
func return_home() -> void:
	_end_drag()
	var t := create_tween()
	t.tween_property(self, "position", home, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(apply_depth)


## Slide into the zone and vanish.
func consume_into(z: Zone) -> void:
	zone = z
	done = true
	_end_drag()
	if shadow:
		shadow.hide()
	z_index = Z_DRAGGED
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", z.center(), 0.23).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", base_scale * 0.25, 0.23)
	t.tween_property(self, "modulate:a", 0.0, 0.23)
	t.chain().tween_callback(hide)


## Knocked out of its zone (cat, wind) and lands at `to`.
func scatter_to(to: Vector2) -> void:
	var from := zone.center() if zone else position
	if trash and zone:
		GameState.add_trash(-1)
	if zone:
		zone.release_one()
	zone = null
	done = false
	home = to
	show()
	modulate = Color.WHITE
	scale = base_scale * 0.5
	position = from
	if shadow:
		shadow.show()
	z_index = Z_DRAGGED
	var peak := minf(from.y, to.y) - 18.0
	var tx := create_tween().set_parallel(true)
	tx.tween_property(self, "position:x", to.x, 0.52)
	tx.tween_property(self, "scale", base_scale, 0.52)
	var ty := create_tween()
	ty.tween_property(self, "position:y", peak, 0.22).set_ease(Tween.EASE_OUT)
	ty.tween_property(self, "position:y", to.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	ty.tween_callback(apply_depth)


func restore_done(z: Zone) -> void:
	done = true
	zone = z
	hide()


func _end_drag() -> void:
	create_tween().tween_property(self, "scale", base_scale, 0.09)
	apply_depth()
