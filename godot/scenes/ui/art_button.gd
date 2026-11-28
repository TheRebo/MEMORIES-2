class_name ArtButton
extends TextureButton
## The team's lettered button art (PLAY, SETTING, ...). Brightens on hover and focus and
## plays the UI sounds; the tooltip carries the meaning in Indonesian.


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(func() -> void: modulate = Color(1.2, 1.1, 0.9))
	focus_exited.connect(func() -> void: modulate = Color.WHITE)
	pressed.connect(Sfx.ui_click)


func _on_hover(on: bool) -> void:
	if on:
		Sfx.ui_hover()
	modulate = Color(1.15, 1.15, 1.15) if on else Color.WHITE
