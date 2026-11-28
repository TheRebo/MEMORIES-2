class_name AlertCard
extends PanelContainer
## Instruction card for a running room event, with an optional progress bar.

@onready var _mark: PanelContainer = %Mark
@onready var _text: Label = %Text
@onready var _bar: Control = %Bar
@onready var _bar_label: Label = %BarLabel
@onready var _area: Control = %Area
@onready var _fill: ColorRect = %Fill
@onready var _value: Label = %Value


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)
	# The "!" blinks three times.
	var blink := create_tween().set_loops(3)
	blink.tween_property(_mark, "self_modulate", Color(1.6, 1.6, 1.6), 0.0).set_delay(0.6)
	blink.tween_property(_mark, "self_modulate", Color.WHITE, 0.0).set_delay(0.6)


func set_text(t: String) -> void:
	_text.text = t


## value < 0 hides the bar.
func set_bar(label_text: String, value: float) -> void:
	_bar.visible = value >= 0.0
	if value < 0.0:
		return
	var v := clampf(value, 0.0, 1.0)
	_bar_label.text = label_text
	_fill.size = Vector2(_area.size.x * v, _area.size.y)
	_fill.color = UI.AMBER if v >= 0.5 else UI.WARN
	_value.text = "%d%%" % roundi(v * 100.0)
