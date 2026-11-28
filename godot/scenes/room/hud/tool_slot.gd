class_name ToolSlot
extends Control
## One slot of the tool belt: a cleaning tool (with level pips) or the candle (with a count).

signal slot_down
signal slot_activate

@export var tool_id := ""
@export var is_candle := false

var tool_name := ""
var key_label := ""

@onready var _button: Button = %Button
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _key: Label = %Key
@onready var _pips: Control = %Pips
@onready var _count: Label = %Count
@onready var _marker: PointerArrow = %Marker
@onready var _divider: Control = %Divider


func _ready() -> void:
	if is_candle:
		key_label = String(Db.game["candle_key"]["label"])
		tool_name = "Lilin"
		_icon.texture = Db.tex(String(Db.named.get("candle", "lilin")))
		_button.tooltip_text = "Lilin: tahan %s lalu lepas di lantai" % key_label
		_button.theme_type_variation = &"CandleSlot"
	else:
		var info := Db.tool_info(tool_id)
		key_label = String(info.get("keyLabel", ""))
		tool_name = String(info.get("name", tool_id))
		_icon.texture = Db.tex(String(info.get("icon", "")))
	_name.text = tool_name
	_key.text = key_label
	_pips.visible = not is_candle
	_count.visible = is_candle
	_divider.visible = is_candle
	if is_candle:
		# A little gap and a divider set the candle apart from the tools.
		custom_minimum_size.x = 84
		_button.position.x = 8
		_marker.position.x += 8
	_button.mouse_entered.connect(Sfx.ui_hover)
	_button.gui_input.connect(_on_input)


func _on_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		slot_down.emit()
	elif e.is_action_pressed("ui_accept"):
		_button.accept_event()
		slot_activate.emit()


## active: in hand. lit: suggested by a located task. hinted: needed by the grime under the pointer.
func set_state(active: bool, lit: bool, hinted: bool, dimmed: bool) -> void:
	if is_candle:
		_button.theme_type_variation = &"CandleSlotActive" if active else &"CandleSlot"
	else:
		_button.theme_type_variation = &"ToolSlotActive" if active else (&"ToolSlotSuggest" if lit else &"ToolSlot")
	_button.position.y = -8.0 if active else 0.0
	_icon.modulate.a = 0.3 if active else 1.0
	_button.modulate = Color(1, 1, 1, 0.5) if dimmed else Color.WHITE
	_marker.visible = not active and (hinted or lit)


func pulse(on: bool) -> void:
	_button.self_modulate = Color(1.25, 1.25, 1.25) if on else Color.WHITE


func bob(y: float) -> void:
	_marker.position.y = -16.0 + y


func set_level(level: int, max_level: int) -> void:
	var i := 0
	for p: ColorRect in _pips.get_children():
		p.visible = i < max_level
		p.color = UI.AMBER if i < level else UI.WOOD_900
		i += 1
	_button.tooltip_text = "%s - level %d/%d. Tahan tombol %s atau tahan slot ini." % [tool_name, level, max_level, key_label]


func flash_level_up() -> void:
	_button.theme_type_variation = &"ToolSlotActive"


func set_count(n: int) -> void:
	_count.text = str(n)
