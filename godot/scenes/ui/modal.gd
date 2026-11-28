class_name Modal
extends Control
## Base for the dialog scenes (scenes/ui/dialogs): dim backdrop, a frame with a title strip,
## Esc closes only the top-most dialog, focus stays inside while open and returns afterwards.

signal closed

static var stack: Array[Modal] = []

@export var title := ""
@export var closable := true

var _prev_focus: Control

@onready var _title_label: Label = %Title
@onready var body: VBoxContainer = %Body
@onready var buttons: HBoxContainer = %Buttons


static func is_open() -> bool:
	return not stack.is_empty()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_label.text = title
	_prev_focus = get_viewport().gui_get_focus_owner()
	stack.append(self)
	build()
	await get_tree().process_frame
	_focus_first(self)


## Subclasses fill their nodes here.
func build() -> void:
	pass


func _focus_first(n: Node) -> bool:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if (c is BaseButton or c is Slider) and (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			return true
		if _focus_first(c):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and closable and _is_top():
		get_viewport().set_input_as_handled()
		close()


func _is_top() -> bool:
	return not stack.is_empty() and stack.back() == self


## Keep keyboard focus inside the top dialog.
func _process(_delta: float) -> void:
	if not _is_top():
		return
	var f := get_viewport().gui_get_focus_owner()
	if f != null and not is_ancestor_of(f):
		_focus_first(self)


func close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	Sfx.ui_click()
	stack.erase(self)
	closed.emit()
	if is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		_prev_focus.grab_focus()
	queue_free()


func _exit_tree() -> void:
	stack.erase(self)
