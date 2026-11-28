class_name SfxButton
extends Button
## Wooden plank button (look comes from the theme) with the UI sounds.


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(Sfx.ui_hover)
	pressed.connect(Sfx.ui_click)
