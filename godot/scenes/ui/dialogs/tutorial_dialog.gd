class_name TutorialDialog
extends Modal
## How-to pages on paper (Nenek's notes). Arrow keys page through.

const SCENE_PATH := "res://scenes/ui/dialogs/tutorial_dialog.tscn"

var pages: Array = []
var index := 0

@onready var _page_title: Label = %PageTitle
@onready var _picture: TextureRect = %Picture
@onready var _text: Label = %Text
@onready var _dots: HBoxContainer = %Dots
@onready var _close: Button = %Close
@onready var _prev: Button = %Prev
@onready var _next: Button = %Next


static func make(t: String, tutorial_pages: Array) -> TutorialDialog:
	var d: TutorialDialog = (load(SCENE_PATH) as PackedScene).instantiate()
	d.title = t
	d.pages = tutorial_pages
	return d


func build() -> void:
	var many := pages.size() > 1
	_close.visible = many
	_prev.visible = many
	_close.pressed.connect(close)
	_prev.pressed.connect(func() -> void: _go(-1))
	_next.pressed.connect(func() -> void:
		if many:
			_go(1)
		else:
			close())
	_render()


func _go(d: int) -> void:
	if index + d >= pages.size():
		close()
		return
	index = clampi(index + d, 0, pages.size() - 1)
	_render()


func _render() -> void:
	var p: Dictionary = pages[index]
	_page_title.text = String(p.get("title", ""))
	_text.text = String(p.get("text", ""))
	var img := String(p.get("image", ""))
	_picture.visible = img != ""
	if img != "":
		_picture.texture = Db.tex(img)
	for c in _dots.get_children():
		c.queue_free()
	if pages.size() > 1:
		for i in pages.size():
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.color = UI.PAPER_INK if i == index else UI.PAPER_SHADE
			_dots.add_child(dot)
		_prev.disabled = index == 0
		_next.text = "Done" if index == pages.size() - 1 else "Next"
	else:
		_next.text = "Got it"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") and pages.size() > 1 and _is_top():
		get_viewport().set_input_as_handled()
		_go(1)
	elif event.is_action_pressed("ui_left") and pages.size() > 1 and _is_top():
		get_viewport().set_input_as_handled()
		_go(-1)
	else:
		super(event)
