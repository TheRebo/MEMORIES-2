class_name SfxButton
extends Button
## Wooden plank button (look comes from the theme) with the UI sounds.


func _ready() -> void:
	mouse_entered.connect(Sfx.ui_hover)
	pressed.connect(Sfx.ui_click)
