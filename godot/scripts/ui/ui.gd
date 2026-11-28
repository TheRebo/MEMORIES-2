class_name UI
extends RefCounted
## Shared look: wood for the game's own chrome, cream paper with dark ink for what MC writes.

const CREAM := Color("f4e6c8")
const CREAM_DIM := Color("d3bf9b")
const AMBER := Color("f2b84b")
const AMBER_DEEP := Color("c98a2b")
const AMBER_ON_WOOD := Color("ffe08f")
const INK := Color("120b07")
const WOOD_900 := Color("170f0a")
const WOOD_800 := Color("241811")
const WOOD_700 := Color("33231a")
const WOOD_600 := Color("4a3324")
const WOOD_500 := Color("6b4a33")
const PAPER := Color("efe2c3")
const PAPER_SHADE := Color("ddc9a0")
const PAPER_EDGE := Color("b89c6c")
const PAPER_INK := Color("2a1b11")
const PAPER_INK_SOFT := Color("6a5038")
const PAPER_DONE := Color("3d6a31")
const PAPER_RED := Color("9a3622")
const SAGE := Color("a9d18e")
const WARN := Color("f08a72")

static var _body: Font
static var _display: Font


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/Cairopixel.ttf")
	return _body


static func display_font() -> Font:
	if _display == null:
		_display = load("res://assets/fonts/yoster.ttf")
	return _display


static func label(text: String, size: int = 21, color: Color = CREAM, display: bool = false, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font() if display else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 4)
	return l


static func box(bg: Color, border: Color, width: int = 2, inner: Color = Color.TRANSPARENT, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 0
	s.shadow_offset = Vector2(4, 4)
	if inner.a > 0.0:
		s.expand_margin_left = 0
	return s


static func wood_panel(pad: int = 14) -> StyleBoxFlat:
	var s := box(WOOD_800, INK, 2, Color.TRANSPARENT, pad)
	s.border_width_bottom = 5
	s.shadow_size = 1
	return s


static func paper_panel(pad: int = 14) -> StyleBoxFlat:
	var s := box(PAPER, INK, 2, Color.TRANSPARENT, pad)
	s.border_width_bottom = 5
	s.border_color = INK
	s.shadow_size = 1
	return s


static func panel(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


## Strip of tape on top of a paper card (same as the task note), as a child to position.
static func tape(width: float = 78.0) -> ColorRect:
	var t := ColorRect.new()
	t.color = Color(0.84, 0.77, 0.59, 0.88)
	t.size = Vector2(width, 20)
	t.rotation_degrees = 3.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Wooden text button (blank plank art behind the label).
static func text_button(text: String, small: bool = false, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", 18 if small else 24)
	b.add_theme_color_override("font_color", AMBER_ON_WOOD if primary else CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 4)
	var plank := StyleBoxTexture.new()
	plank.texture = Db.tex("ui/btn_long_blank.png")
	plank.texture_margin_left = 6
	plank.texture_margin_right = 6
	plank.texture_margin_top = 6
	plank.texture_margin_bottom = 8
	plank.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	plank.set_content_margin_all(14 if not small else 8)
	var hover := plank.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.15, 1.15, 1.15)
	var pressed := plank.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.9, 0.9, 0.9)
	b.add_theme_stylebox_override("normal", plank)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus_ring())
	b.custom_minimum_size = Vector2(0, 44 if small else 64)
	b.mouse_entered.connect(Sfx.ui_hover)
	b.pressed.connect(Sfx.ui_click)
	return b


## The team's lettered button art (PLAY, SETTING, ...). `tooltip` carries the meaning in Indonesian.
static func art_button(file: String, tooltip: String, scale: int, size: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Db.tex("ui/%s.png" % file)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = size * scale
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		Sfx.ui_hover()
		b.modulate = Color(1.15, 1.15, 1.15))
	b.mouse_exited.connect(func() -> void: b.modulate = Color.WHITE)
	b.pressed.connect(Sfx.ui_click)
	b.focus_entered.connect(func() -> void: b.modulate = Color(1.2, 1.1, 0.9))
	b.focus_exited.connect(func() -> void: b.modulate = Color.WHITE)
	return b


static func focus_ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = AMBER
	s.set_border_width_all(3)
	s.expand_margin_left = 4
	s.expand_margin_right = 4
	s.expand_margin_top = 4
	s.expand_margin_bottom = 4
	return s


## Full-rect Control that lets mouse through (layout helper).
static func layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
