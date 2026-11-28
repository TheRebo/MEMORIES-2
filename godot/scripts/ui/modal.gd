class_name Modal
extends Control
## Base dialog: dim backdrop, wooden box with a title strip, Esc closes only the top-most
## dialog, focus stays inside while open and returns to where it was.

signal closed

static var stack: Array[Modal] = []

var closable := true
var box: VBoxContainer
var _title: String
var _prev_focus: Control


static func is_open() -> bool:
	return not stack.is_empty()


func _init(title: String) -> void:
	_title = title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.04, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := UI.panel(_frame_style())
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	frame.add_child(outer)
	var strip := UI.panel(UI.box(UI.WOOD_700, UI.INK, 0, Color.TRANSPARENT, 10))
	strip.add_child(UI.label(_title, 26, UI.AMBER_ON_WOOD, true))
	outer.add_child(strip)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	outer.add_child(box)
	_prev_focus = get_viewport().gui_get_focus_owner()
	build()
	stack.append(self)
	await get_tree().process_frame
	_focus_first(box)


func _frame_style() -> StyleBox:
	return UI.wood_panel(18)


## Subclasses fill `box`.
func build() -> void:
	pass


func _focus_first(n: Node) -> bool:
	for c in n.get_children():
		if c is BaseButton or c is Slider or c is CheckBox:
			(c as Control).grab_focus()
			return true
		if _focus_first(c):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and closable and not stack.is_empty() and stack.back() == self:
		get_viewport().set_input_as_handled()
		close()


## Keep keyboard focus inside the top dialog.
func _process(_delta: float) -> void:
	if stack.is_empty() or stack.back() != self:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f != null and not is_ancestor_of(f):
		_focus_first(box)


func close() -> void:
	if not is_inside_tree():
		return
	Sfx.ui_click()
	stack.erase(self)
	closed.emit()
	if is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		_prev_focus.grab_focus()
	queue_free()


func add_button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	for b: Control in buttons:
		row.add_child(b)
	box.add_child(row)
	return row
