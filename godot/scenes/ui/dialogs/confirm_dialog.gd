class_name ConfirmDialog
extends Modal
## Yes/no question.

const SCENE_PATH := "res://scenes/ui/dialogs/confirm_dialog.tscn"

var message := ""
var confirm_text := "Ya"
var on_confirm := Callable()

@onready var _message: Label = %Message
@onready var _cancel: Button = %Cancel
@onready var _confirm: Button = %Confirm


static func make(t: String, msg: String, confirm: String, fn: Callable) -> ConfirmDialog:
	var d: ConfirmDialog = (load(SCENE_PATH) as PackedScene).instantiate()
	d.title = t
	d.message = msg
	d.confirm_text = confirm
	d.on_confirm = fn
	return d


func build() -> void:
	_message.text = message
	_confirm.text = confirm_text
	_cancel.pressed.connect(close)
	_confirm.pressed.connect(func() -> void:
		close()
		if on_confirm.is_valid():
			on_confirm.call())
