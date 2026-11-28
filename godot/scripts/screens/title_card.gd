extends Control
## The end: logo on the team's olive background, a thank-you, then back to the menu.

var args: Dictionary = {}
var main: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("5f6a3c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var logo := TextureRect.new()
	logo.texture = Db.tex("ui/title_logo_trim.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(640, 165)
	v.add_child(logo)
	var thanks := UI.label(String((Db.story.get("credits", {}) as Dictionary).get("thanks", "")), 28, UI.CREAM)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.6)
	await get_tree().create_timer(6.0).timeout
	if is_inside_tree():
		main.go("Menu", {}, 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or event.is_action_pressed("ui_accept"):
		main.go("Menu", {}, 1.2)
