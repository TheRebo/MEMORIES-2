class_name TaskRow
extends PanelContainer
## One line of the task note: check box, what it needs (tool, hand or double click), the task
## and how many parts are left. Unfinished rows are clickable to locate the task in the room.

signal chosen(group: String)

var group := ""
var finished := false

@onready var _check: Panel = %Check
@onready var _kind_icon: TextureRect = %KindIcon
@onready var _kind_box: PanelContainer = %KindBox
@onready var _kind_text: Label = %KindText
@onready var _name: Label = %Name
@onready var _count: Label = %Count


func setup(g: Dictionary, kind: String) -> TaskRow:
	group = String(g["name"])
	finished = int(g["done"]) >= int(g["total"])
	_check.theme_type_variation = &"CheckDone" if finished else &"CheckOpen"
	var tool := kind == "broom" or kind == "mop" or kind == "cloth" or kind == "duster"
	_kind_icon.visible = tool or kind == "hand"
	_kind_box.visible = not tool and kind != ""
	_kind_text.visible = kind == "click"
	if tool:
		_kind_icon.texture = Db.tex(String(Db.tool_info(kind).get("icon", "")))
	elif kind == "hand":
		_kind_icon.texture = Db.tex(String(Db.named.get("glove_open", "glove_open")))
	if finished:
		_kind_icon.modulate.a = 0.5
		_kind_box.modulate.a = 0.5
	_name.text = group
	_name.theme_type_variation = &"PaperDoneLabel" if finished else &"PaperLabel"
	_count.text = "" if finished else "%d/%d" % [g["done"], g["total"]]
	if finished:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	else:
		tooltip_text = "Show me in the room"
		mouse_entered.connect(_style.bind(&"TaskRowHover"))
		mouse_exited.connect(_style.bind(&"TaskRow"))
		focus_entered.connect(_style.bind(&"TaskRowHover"))
		focus_exited.connect(_style.bind(&"TaskRow"))
	return self


func _style(v: StringName) -> void:
	theme_type_variation = v


func _gui_input(e: InputEvent) -> void:
	if finished:
		return
	var mb := e as InputEventMouseButton
	var click: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if click or e.is_action_pressed("ui_accept"):
		accept_event()
		Sfx.ui_click()
		flash(&"TaskRowFlash")
		chosen.emit(group)


## Short highlight: green when located, red when an event added work to it.
func flash(v: StringName) -> void:
	theme_type_variation = v
	get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			theme_type_variation = &"TaskRow")
