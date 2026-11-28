class_name Hud
extends CanvasLayer
## Room HUD, laid out and styled like the web build (src/ui/layout.css):
## wooden plaque with progress at the top left, timer and buttons at the top right, the paper
## task note pinned on the left, the tool belt at the bottom centre, trash on the left and room
## navigation on the right. Messages centre on the part of the room that is still visible.
## The room drives it through calls; it never polls game state.

signal menu_pressed
signal tool_slot_down(tool: String)
signal tool_slot_activate(tool: String)
signal candle_slot_down
signal go_room(id: String)
signal go_home
signal todo_toggled
signal task_clicked(group: String)
signal result_closed

const TOP := 92.0
const BOTTOM := 108.0
const TODO_W := 296.0
const VIEW := Vector2(1280, 720)
const SLOT := Vector2(76, 72)
const CANDLE_BG := Color("3b2a16")

var room_id := ""
var todo_open := true
var cinematic := false
var _root: Control
var _vignette: TextureRect
var _glow: TextureRect
var _grain: ColorRect
var _fade: ColorRect
var _letterbox: Array[ColorRect] = []
var _pointer_layer: Control
var _top: Control
var _bottom: Control
var _todo: Control
var _todo_panel: PanelContainer
var _todo_scroll: ScrollContainer
var _todo_list: VBoxContainer
var _todo_done_box: VBoxContainer
var _todo_done: VBoxContainer
var _todo_done_head: Button
var _todo_count: Label
var _progress_back: Control
var _progress_fill: ColorRect
var _progress_shine: ColorRect
var _progress_text: Label
var _timer_ring: StyleBoxFlat
var _timer_text: Label
var _stars: Array[Star] = []
var _slots: Dictionary = {}
var _candle_holder: Control
var _candle_slot: Button
var _candle_count: Label
var _trash_box: Control
var _trash_count: Label
var _nav: HBoxContainer
var _toast: Control
var _toast_label: Label
var _alerts: VBoxContainer
var _alert_map: Dictionary = {}
var _dialog: Control
var _dialog_panel: PanelContainer
var _dialog_tab: Control
var _dialog_speaker: Label
var _dialog_text: Typer
var _dialog_hint: Label
var _banner: Label
var _chip: Control
var _chip_ring: StyleBoxFlat
var _chip_label: Label
var _chip_until := 0
var _cursor: TextureRect
var _pointers: Dictionary = {}
var _held := ""
var _hovered_tool := ""
var _suggested := ""
var _candle_held := false
var _last_second := -1
var _last_stars := 3
var _hurry := false
var _last_groups: Dictionary = {}
var _seq_toast := 0
var _seq_dialog := 0
var _show_done := false
var _done_count := 0
var _close_result := Callable()
var _clock := 0.0


func setup(def: Dictionary) -> void:
	layer = 2
	room_id = String(def["id"])
	# Short windows start with the note folded so the room stays visible.
	todo_open = DisplayServer.window_get_size().y >= 500
	_root = UI.layer()
	add_child(_root)
	_build_ambient()
	_build_top(def)
	_build_todo()
	_build_bottom()
	_build_messages()
	_apply_todo(true)


func _process(dt: float) -> void:
	_clock += dt
	var still := Settings.reduced_motion()
	# Glint running across the progress bar.
	var w := _progress_fill.size.x
	if w > 14.0 and not still:
		_progress_shine.position.x = fmod(_clock / 2.8, 1.0) / 0.7 * (w + 12.0) - 12.0
		_progress_shine.visible = _progress_shine.position.x < w
	else:
		_progress_shine.visible = false
	if _hurry:
		_timer_text.add_theme_color_override("font_color", UI.WARN if int(_clock * 2.0) % 2 == 0 else UI.AMBER)
	# Bobbing markers above slots that are hinted or suggested.
	var bob := 0.0 if still else (-3.0 if int(_clock / 0.35) % 2 == 0 else 0.0)
	for id: String in _slots:
		var s: Dictionary = _slots[id]
		(s["marker"] as Control).position.y = -16.0 + bob
		if id == _suggested and id != _held and not still:
			(s["button"] as Control).modulate = Color(1.25, 1.25, 1.25) if int(_clock / 0.3) % 2 == 0 else Color.WHITE
	if _chip.visible and _chip_until > 0 and Time.get_ticks_msec() > _chip_until:
		_chip_until = 0
		_chip.visible = false


# ================= Helpers =================

func _full(c: Control, parent: Control = null) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else _root).add_child(c)
	return c


func _inset() -> float:
	return TODO_W if todo_open and not cinematic else 0.0


## Horizontal centre of the room area that is still visible.
func _visible_center() -> float:
	var i := _inset()
	return i + (VIEW.x - i) / 2.0


func _radial(outer: Color, from: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(outer, 0.0))
	g.set_color(1, outer)
	g.add_point(from, Color(outer, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 144
	return t


func _icon(key: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	if key != "":
		t.texture = Db.tex(key)
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Let clicks pass through a message panel and everything inside it.
func _passthrough(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in c.get_children():
		if child is Control:
			_passthrough(child as Control)


func _ring_of(inner: PanelContainer) -> StyleBoxFlat:
	return inner.get_theme_stylebox("panel") as StyleBoxFlat


# ================= Build =================

func _build_ambient() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = _radial(Color(0.04, 0.024, 0.016, 0.75), 0.45)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_full(_vignette)
	_vignette.modulate.a = 1.0
	_glow = TextureRect.new()
	_glow.texture = _radial(Color(UI.AMBER, 0.22), 0.55)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_full(_glow)
	_glow.modulate.a = 0.0
	_grain = ColorRect.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 3.0);
	float n = h(cell + floor(TIME * 8.0) * 17.0);
	float flick = 0.05 * step(0.5, fract(TIME * 1.25)) - 0.03 * step(0.85, fract(TIME * 2.5));
	COLOR = vec4(0.35, 0.25, 0.12, clamp(n * 0.32 + flick, 0.0, 1.0));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_grain.material = mat
	_full(_grain)
	_grain.modulate.a = 0.0
	_pointer_layer = _full(Control.new())


func _build_top(def: Dictionary) -> void:
	_top = _full(Control.new())
	var order: Array = Db.room_order
	var step := order.find(room_id) + 1

	var plaque: Array = UI.framed(UI.WOOD_800, UI.WOOD_600, 8, UI.WOOD_900)
	var pl: PanelContainer = plaque[0]
	pl.position = Vector2(12, 10)
	pl.custom_minimum_size = Vector2(364, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	(plaque[1] as PanelContainer).add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var badge := UI.panel(UI.box(UI.CREAM_DIM, Color("a8916b"), 0, Color.TRANSPARENT, 3))
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 3
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 7
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 7
	badge.add_child(UI.label("%d/%d" % [step, order.size()], 15, UI.INK, true, false))
	badge.tooltip_text = "Ruangan %d dari %d" % [step, order.size()]
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	row.add_child(UI.label(String(def["name"]), 23, UI.CREAM, true))
	col.add_child(row)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	var track: Array = UI.framed(UI.WOOD_900, UI.WOOD_600, 0, Color.TRANSPARENT, false)
	var tr: PanelContainer = track[0]
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_back = Control.new()
	_progress_back.clip_contents = true
	_progress_back.custom_minimum_size = Vector2(0, 12)
	(track[1] as PanelContainer).add_child(_progress_back)
	_progress_fill = ColorRect.new()
	_progress_fill.color = UI.AMBER
	_progress_fill.size = Vector2(0, 12)
	_progress_back.add_child(_progress_fill)
	var lip := ColorRect.new()
	lip.name = "Lip"
	lip.color = UI.AMBER_DEEP
	lip.anchor_right = 1.0
	lip.anchor_top = 1.0
	lip.anchor_bottom = 1.0
	lip.offset_top = -4
	_progress_fill.add_child(lip)
	_progress_shine = ColorRect.new()
	_progress_shine.color = Color(1.0, 0.96, 0.86, 0.7)
	_progress_shine.size = Vector2(12, 12)
	_progress_back.add_child(_progress_shine)
	# Quarter marks over the bar.
	for q: float in [0.25, 0.5, 0.75]:
		var tick := ColorRect.new()
		tick.color = Color(UI.INK, 0.55)
		tick.anchor_left = q
		tick.anchor_right = q
		tick.anchor_bottom = 1.0
		tick.offset_left = -1
		_progress_back.add_child(tick)
	prow.add_child(tr)
	_progress_text = UI.label("0%", 17, UI.CREAM, true)
	_progress_text.custom_minimum_size = Vector2(50, 0)
	prow.add_child(_progress_text)
	col.add_child(prow)
	_top.add_child(pl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.position = Vector2(VIEW.x - 12 - 520, 10)
	actions.size = Vector2(520, 50)
	var timer: Array = UI.framed(UI.WOOD_900, UI.WOOD_600, 0)
	var tp: PanelContainer = timer[0]
	tp.tooltip_text = "Waktu di ruangan ini. Bersihkan lebih cepat untuk bintang lebih banyak."
	tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_ring = _ring_of(timer[1])
	_timer_ring.content_margin_left = 10
	_timer_ring.content_margin_right = 14
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	trow.custom_minimum_size = Vector2(0, 40)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 3)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := Star.new(16.0, UI.AMBER)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stars.append(s)
		stars.add_child(s)
	trow.add_child(stars)
	_timer_text = UI.label("0:00", 20, UI.CREAM, true)
	_timer_text.custom_minimum_size = Vector2(52, 0)
	_timer_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(_timer_text)
	(timer[1] as PanelContainer).add_child(trow)
	actions.add_child(tp)
	var notes := UI.text_button("Catatan  T", true)
	notes.custom_minimum_size = Vector2(0, 46)
	notes.tooltip_text = "Buka/tutup catatan (T)"
	notes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notes.pressed.connect(toggle_todo)
	actions.add_child(notes)
	var menu := UI.art_button("btn_menu", "Jeda (Esc)", 2, Vector2(23, 23))
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	actions.add_child(menu)
	_top.add_child(actions)


func _build_todo() -> void:
	_todo = Control.new()
	_todo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_todo.position = Vector2(12, 104)
	_root.add_child(_todo)
	_todo_panel = UI.panel(UI.paper_panel(12))
	var ps := _todo_panel.get_theme_stylebox("panel") as StyleBoxFlat
	ps.content_margin_left = 14
	ps.content_margin_right = 14
	_todo_panel.custom_minimum_size = Vector2(272, 0)
	_todo_panel.size = Vector2(272, 0)
	_todo_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_todo.add_child(_todo_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_todo_panel.add_child(col)
	var head := HBoxContainer.new()
	var title := UI.label("Catatan", 22, UI.PAPER_INK, true, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_todo_count = UI.label("", 17, UI.PAPER_INK_SOFT, true, false)
	_todo_count.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_todo_count)
	col.add_child(head)
	col.add_child(_dashed())
	_todo_scroll = ScrollContainer.new()
	_todo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_todo_list = VBoxContainer.new()
	_todo_list.add_theme_constant_override("separation", 2)
	_todo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_todo_scroll.add_child(_todo_list)
	col.add_child(_todo_scroll)
	_todo_done_box = VBoxContainer.new()
	_todo_done_box.add_theme_constant_override("separation", 2)
	_todo_done_box.add_child(_dashed())
	_todo_done_head = Button.new()
	_todo_done_head.flat = true
	_todo_done_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_todo_done_head.add_theme_font_override("font", UI.body_font())
	_todo_done_head.add_theme_font_size_override("font_size", 18)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_todo_done_head.add_theme_color_override(state, UI.PAPER_INK_SOFT)
	_todo_done_head.add_theme_stylebox_override("focus", _paper_focus())
	_todo_done_head.pressed.connect(func() -> void:
		_show_done = not _show_done
		_todo_done.visible = _show_done
		_render_done_head()
		_fit_todo())
	_todo_done_box.add_child(_todo_done_head)
	_todo_done = VBoxContainer.new()
	_todo_done.add_theme_constant_override("separation", 2)
	_todo_done.visible = false
	_todo_done_box.add_child(_todo_done)
	col.add_child(_todo_done_box)
	var tape := ColorRect.new()
	tape.color = Color(0.84, 0.77, 0.59, 0.85)
	tape.size = Vector2(72, 18)
	tape.position = Vector2(136 - 36, -9)
	tape.rotation_degrees = -2.0
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_todo.add_child(tape)


func _dashed() -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.clip_contents = true
	line.custom_minimum_size = Vector2(0, 2)
	for i in 30:
		var d := ColorRect.new()
		d.color = UI.PAPER_EDGE
		d.custom_minimum_size = Vector2(4, 2)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(d)
	return line


func _paper_focus() -> StyleBoxFlat:
	var f := UI.focus_ring()
	f.border_color = UI.PAPER_INK
	f.set_border_width_all(2)
	return f


func _slot_style(bg: Color, ring: Color, ring_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = ring
	s.set_border_width_all(ring_w)
	s.border_width_bottom = ring_w + 3
	return s


func _make_slot(icon: String, key: String, name_text: String, bg: Color) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = SLOT
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.size = SLOT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _slot_style(bg, UI.WOOD_500, 2))
	b.add_theme_stylebox_override("hover", _slot_style(bg, UI.AMBER_DEEP, 2))
	b.add_theme_stylebox_override("pressed", _slot_style(UI.WOOD_500, UI.AMBER, 3))
	b.add_theme_stylebox_override("focus", UI.focus_ring())
	b.mouse_entered.connect(Sfx.ui_hover)
	holder.add_child(b)
	var img := _icon(icon, 40)
	img.position = Vector2((SLOT.x - 40) / 2.0, 6)
	b.add_child(img)
	var n := UI.label(name_text, 16, UI.CREAM)
	n.add_theme_constant_override("outline_size", 3)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(0, 46)
	n.size = Vector2(SLOT.x, 18)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	var kp := UI.panel(UI.box(UI.WOOD_900, UI.WOOD_600, 1, Color.TRANSPARENT, 1))
	(kp.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 3
	(kp.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 3
	kp.add_child(UI.label(key, 12, UI.AMBER_ON_WOOD, true, false))
	kp.position = Vector2(3, 3)
	kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(kp)
	var marker := Arrow.new()
	marker.small = true
	marker.position = Vector2(SLOT.x / 2.0, -16)
	marker.visible = false
	holder.add_child(marker)
	return {"holder": holder, "button": b, "icon": img, "marker": marker}


func _build_bottom() -> void:
	_bottom = _full(Control.new())
	# Tool belt, centred.
	var belt: Array = UI.framed(UI.WOOD_800, UI.WOOD_600, 0, UI.WOOD_900)
	var bp: PanelContainer = belt[0]
	var ring := _ring_of(belt[1])
	ring.content_margin_left = 10
	ring.content_margin_right = 10
	ring.content_margin_top = 8
	ring.content_margin_bottom = 8
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	(belt[1] as PanelContainer).add_child(bar)
	var max_lv := int(Db.game["tool_levels"]["maxLevel"])
	for t: Dictionary in Db.game.get("tools", []):
		var id := String(t["id"])
		var s := _make_slot(String(t["icon"]), String(t["keyLabel"]), String(t["name"]), UI.WOOD_700)
		var b: Button = s["button"]
		b.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				tool_slot_down.emit(id)
			elif e.is_action_pressed("ui_accept"):
				b.accept_event()
				tool_slot_activate.emit(id))
		var pips: Array[ColorRect] = []
		for i in max_lv:
			var p := ColorRect.new()
			p.size = Vector2(6, 4)
			# Fills from the bottom up.
			p.position = Vector2(SLOT.x - 5 - 6, 5 + (max_lv - 1 - i) * 6)
			p.color = UI.WOOD_900
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(p)
			pips.append(p)
		s["pips"] = pips
		s["name"] = String(t["name"])
		s["key"] = String(t["keyLabel"])
		bar.add_child(s["holder"])
		_slots[id] = s
		set_tool_level(id, GameState.tool_level(id), false)
	var candle_key := String(Db.game["candle_key"]["label"])
	var cs := _make_slot(String(Db.named.get("candle", "lilin")), candle_key, "Lilin", CANDLE_BG)
	_candle_holder = cs["holder"]
	_candle_holder.custom_minimum_size.x = SLOT.x + 8
	(cs["button"] as Control).position.x = 8
	(cs["marker"] as Control).position.x += 8
	var sep := ColorRect.new()
	sep.color = UI.WOOD_600
	sep.position = Vector2(2, 8)
	sep.size = Vector2(2, SLOT.y - 16)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candle_holder.add_child(sep)
	_candle_slot = cs["button"]
	_candle_slot.tooltip_text = "Lilin: tahan %s lalu lepas di lantai" % candle_key
	_candle_count = UI.label("0", 15, UI.AMBER_ON_WOOD, true)
	_candle_count.position = Vector2(SLOT.x - 6 - 14, 3)
	_candle_count.size = Vector2(14, 16)
	_candle_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_candle_slot.add_child(_candle_count)
	_candle_slot.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			candle_slot_down.emit())
	_candle_holder.visible = false
	bar.add_child(_candle_holder)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.position = Vector2(0, VIEW.y - 10 - 100)
	center.size = Vector2(VIEW.x, 100)
	bp.size_flags_vertical = Control.SIZE_SHRINK_END
	center.add_child(bp)
	_bottom.add_child(center)

	# Trash, bottom left.
	var trash: Array = UI.framed(UI.WOOD_900, UI.WOOD_700, 4)
	_trash_box = trash[0]
	var tring := _ring_of(trash[1])
	tring.content_margin_left = 8
	tring.content_margin_right = 14
	_trash_box.tooltip_text = "Sampah terkumpul"
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(_icon(String(Db.named.get("trash_bag", "trash_bag")), 32))
	var tl := UI.label("Sampah", 18, UI.CREAM_DIM)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(tl)
	_trash_count = UI.label(str(GameState.trash_total()), 22, UI.CREAM, true)
	_trash_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(_trash_count)
	(trash[1] as PanelContainer).add_child(trow)
	_bottom.add_child(_trash_box)
	_trash_box.position = Vector2(12, VIEW.y - 10 - 48)

	# Room navigation, bottom right.
	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 8)
	_nav.alignment = BoxContainer.ALIGNMENT_END
	_nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.position = Vector2(VIEW.x - 12 - 400, VIEW.y - 10 - 50)
	_nav.size = Vector2(400, 50)
	_nav.visible = false
	_bottom.add_child(_nav)


func _build_messages() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_full(_fade)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(VIEW.x, 56)
		bar.position = Vector2(0, -56.0 if i == 0 else VIEW.y)
		_root.add_child(bar)
		_letterbox.append(bar)

	_alerts = VBoxContainer.new()
	_alerts.add_theme_constant_override("separation", 8)
	_alerts.position = Vector2(VIEW.x - 12 - 420, 66)
	_alerts.custom_minimum_size = Vector2(420, 0)
	_alerts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_alerts)

	var toast_fr: Array = UI.framed(UI.WOOD_800, UI.AMBER_DEEP, 0)
	_toast = toast_fr[0]
	var tr := _ring_of(toast_fr[1])
	tr.content_margin_left = 18
	tr.content_margin_right = 18
	tr.content_margin_top = 8
	tr.content_margin_bottom = 10
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(toast_fr[1] as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UI.label("", 21, UI.CREAM)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(toast_fr[1] as PanelContainer).add_child(_toast_label)
	_toast.modulate.a = 0.0
	_passthrough(_toast)
	_root.add_child(_toast)

	_dialog = Control.new()
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	_root.add_child(_dialog)
	var dp: Array = UI.framed(UI.PAPER, Color("f8efd9"), 0, UI.PAPER_SHADE, true)
	_dialog_panel = dp[0]
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dr := _ring_of(dp[1])
	dr.content_margin_left = 24
	dr.content_margin_right = 24
	dr.content_margin_top = 20
	dr.content_margin_bottom = 12
	_dialog_panel.custom_minimum_size = Vector2(720, 0)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 6)
	_dialog_text = Typer.new()
	_dialog_text.add_theme_font_override("font", UI.body_font())
	_dialog_text.add_theme_font_size_override("font_size", 24)
	_dialog_text.add_theme_color_override("font_color", UI.PAPER_INK)
	_dialog_text.custom_minimum_size = Vector2(660, 30)
	dcol.add_child(_dialog_text)
	_dialog_hint = UI.label("Klik atau Enter untuk lanjut, Esc untuk lewati", 17, UI.PAPER_INK_SOFT, false, false)
	_dialog_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialog_hint.modulate.a = 0.0
	dcol.add_child(_dialog_hint)
	(dp[1] as PanelContainer).add_child(dcol)
	_dialog.add_child(_dialog_panel)
	var tab := UI.panel(UI.box(UI.WOOD_700, UI.INK, 2, Color.TRANSPARENT, 0))
	var ts := tab.get_theme_stylebox("panel") as StyleBoxFlat
	ts.content_margin_left = 12
	ts.content_margin_right = 12
	ts.content_margin_top = 3
	ts.content_margin_bottom = 5
	ts.border_width_bottom = 4
	_dialog_speaker = UI.label("", 19, UI.CREAM, true)
	tab.add_child(_dialog_speaker)
	tab.position = Vector2(16, -18)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_tab = tab
	_dialog.add_child(tab)
	_passthrough(_dialog)

	_banner = UI.label("", 54, UI.CREAM, true)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_shadow_color", UI.INK)
	_banner.add_theme_constant_override("shadow_offset_x", 4)
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(VIEW.x, 72)
	_banner.position = Vector2(0, 250)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

	var chip: Array = UI.framed(UI.WOOD_900, UI.WOOD_500, 0, Color.TRANSPARENT, false)
	_chip = chip[0]
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(chip[1] as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_ring = _ring_of(chip[1])
	_chip_ring.content_margin_left = 10
	_chip_ring.content_margin_right = 10
	_chip_ring.content_margin_top = 3
	_chip_ring.content_margin_bottom = 5
	_chip_label = UI.label("", 19, UI.CREAM)
	(chip[1] as PanelContainer).add_child(_chip_label)
	_chip.visible = false
	_passthrough(_chip)
	_root.add_child(_chip)

	_cursor = _icon("", 64)
	_cursor.pivot_offset = Vector2(18, 50)
	_cursor.visible = false
	_root.add_child(_cursor)


# ================= Progress & tasks =================

func set_progress(pct: float) -> void:
	var w := _progress_back.size.x if _progress_back.size.x > 0.0 else 270.0
	_progress_fill.size.y = 12
	create_tween().tween_property(_progress_fill, "size:x", w * clampf(pct, 0, 100) / 100.0, 0.4).set_ease(Tween.EASE_OUT)
	_progress_text.text = "%d%%" % roundi(pct)
	var clean := roundi(pct) >= 100
	_progress_fill.color = UI.SAGE if clean else UI.AMBER
	(_progress_fill.get_node("Lip") as ColorRect).color = Color("6f9e5a") if clean else UI.AMBER_DEEP
	_progress_text.add_theme_color_override("font_color", UI.SAGE if clean else UI.CREAM)


func _kind_icon(kind: String) -> Control:
	if kind == "broom" or kind == "mop" or kind == "cloth" or kind == "duster":
		return _icon(String(Db.tool_info(kind).get("icon", "")), 16)
	var box := UI.panel(UI.box(Color.TRANSPARENT, UI.PAPER_EDGE, 2 if kind != "" else 0, Color.TRANSPARENT, 0))
	box.custom_minimum_size = Vector2(18, 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "click":
		var l := UI.label("2x", 11, UI.PAPER_INK_SOFT, true, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(l)
	elif kind == "hand":
		box.add_child(_icon(String(Db.named.get("glove_open", "glove_open")), 14))
	return box


func _check_box(done: bool) -> Control:
	var s := StyleBoxFlat.new()
	s.bg_color = UI.PAPER_DONE if done else Color("fbf5e6")
	s.border_color = Color("2a4a22") if done else UI.PAPER_INK_SOFT
	s.set_border_width_all(0 if done else 2)
	if done:
		s.border_width_bottom = 3
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(14, 14)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 3)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(p)
	return wrap


func _task_row(g: Dictionary, kind: String) -> PanelContainer:
	var name_text := String(g["name"])
	var fin: bool = int(g["done"]) >= int(g["total"])
	var row := PanelContainer.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.set_content_margin_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(UI.PAPER_INK, 0.08)
	row.add_theme_stylebox_override("panel", normal)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_check_box(fin))
	var icon := _kind_icon(kind)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if fin:
		icon.modulate.a = 0.5
	h.add_child(icon)
	var n := UI.label(name_text, 19, UI.PAPER_DONE if fin else UI.PAPER_INK, false, false)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.custom_minimum_size = Vector2(120, 0)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	if not fin:
		var cnt := UI.label("%d/%d" % [g["done"], g["total"]], 16, UI.PAPER_INK_SOFT, true, false)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cnt)
	row.add_child(h)
	if fin:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return row
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "Tunjukkan di ruangan"
	row.mouse_entered.connect(func() -> void: row.add_theme_stylebox_override("panel", hover))
	row.mouse_exited.connect(func() -> void: row.add_theme_stylebox_override("panel", normal))
	row.focus_entered.connect(func() -> void: row.add_theme_stylebox_override("panel", hover))
	row.focus_exited.connect(func() -> void: row.add_theme_stylebox_override("panel", normal))
	row.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		var click: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		if click or e.is_action_pressed("ui_accept"):
			row.accept_event()
			Sfx.ui_click()
			_flash(row, Color(0.24, 0.42, 0.19, 0.22))
			task_clicked.emit(name_text))
	return row


## Short highlight on a row (a task grew, or it was located).
func _flash(row: PanelContainer, c: Color) -> void:
	var normal := row.get_theme_stylebox("panel") as StyleBoxFlat
	var lit := normal.duplicate() as StyleBoxFlat
	lit.bg_color = c
	row.add_theme_stylebox_override("panel", lit)
	get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
		if is_instance_valid(row):
			row.add_theme_stylebox_override("panel", normal))


func set_groups(groups: Array, kinds: Dictionary) -> void:
	for c in _todo_list.get_children():
		c.queue_free()
	for c in _todo_done.get_children():
		c.queue_free()
	var done_n := 0
	var total_n := 0
	var open_n := 0
	_done_count = 0
	for g: Dictionary in groups:
		var name_text := String(g["name"])
		done_n += int(g["done"])
		total_n += int(g["total"])
		var fin: bool = int(g["done"]) >= int(g["total"])
		var row := _task_row(g, String(kinds.get(name_text, "")))
		if fin:
			_todo_done.add_child(row)
			_done_count += 1
		else:
			open_n += 1
			_todo_list.add_child(row)
			# An event added work (new puddles): flash it so the change is noticed.
			var prev: Variant = _last_groups.get(name_text)
			if (prev == null and not _last_groups.is_empty()) or (prev is Dictionary and int(prev["total"]) < int(g["total"])):
				_flash(row, Color(0.6, 0.21, 0.13, 0.2))
	if open_n == 0:
		var empty := UI.label("Semua beres!" if not groups.is_empty() else "Tidak ada tugas.", 19, UI.PAPER_DONE, false, false)
		_todo_list.add_child(empty)
	_todo_count.text = "%d/%d" % [done_n, total_n]
	_todo_count.tooltip_text = "%d bagian lagi" % (total_n - done_n)
	_todo_done_box.visible = _done_count > 0
	_render_done_head()
	_last_groups.clear()
	for g: Dictionary in groups:
		_last_groups[g["name"]] = g
	_fit_todo()


func _render_done_head() -> void:
	_todo_done_head.text = "%s Sudah selesai (%d)" % ["-" if _show_done else "+", _done_count]


## The note grows with its list up to 500px, then the list scrolls.
func _fit_todo() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_todo_list):
		return
	var done_h := _todo_done_box.get_combined_minimum_size().y if _todo_done_box.visible else 0.0
	var room_for_list := 500.0 - 80.0 - done_h
	_todo_scroll.custom_minimum_size.y = clampf(_todo_list.get_combined_minimum_size().y, 28.0, maxf(60.0, room_for_list))
	_todo_panel.reset_size()


func flash_group(name_text: String) -> void:
	toast("Selesai: %s" % name_text)


func toggle_todo() -> void:
	todo_open = not todo_open
	_apply_todo(false)
	Sfx.ui_click()
	todo_toggled.emit()


func _apply_todo(instant: bool) -> void:
	var show := todo_open and not cinematic
	var x := 12.0 if show else -300.0
	var a := 1.0 if show else 0.0
	_todo_panel.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	if instant:
		_todo.position.x = x
		_todo.modulate.a = a
	else:
		var t := create_tween().set_parallel(true)
		t.tween_property(_todo, "position:x", x, 0.3).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_todo, "modulate:a", a, 0.3)
	_relayout_messages()


func todo_inset() -> float:
	return _inset()


## Messages centre on the visible room.
func _relayout_messages() -> void:
	var cx := _visible_center()
	_banner.position.x = cx - VIEW.x / 2.0
	if _toast.modulate.a > 0.0:
		_toast.position.x = cx - _toast.size.x / 2.0
	if _dialog.visible:
		_place_dialog()


# ================= Timer & result =================

func set_time(seconds: float, par: float) -> void:
	var s := int(seconds)
	if s == _last_second:
		return
	_last_second = s
	_timer_text.text = Db.clock(s)
	var stars := Db.stars_for(par, seconds)
	if stars != _last_stars:
		_last_stars = stars
		for i in 3:
			_stars[i].color = UI.AMBER if i < stars else UI.WOOD_600
		var lost := _stars[stars]
		lost.color = UI.WARN
		var t := lost.create_tween()
		t.tween_property(lost, "scale", Vector2(1.6, 1.6), 0.1)
		t.tween_property(lost, "scale", Vector2.ONE, 0.5)
		t.tween_callback(func() -> void: lost.color = UI.WOOD_600)
		_timer_ring.border_color = UI.WARN
		get_tree().create_timer(1.2, false).timeout.connect(func() -> void: _timer_ring.border_color = UI.WOOD_600)
		toast("Bintang ketiga lepas. Masih bisa dapat dua!" if stars == 2 else "Tinggal satu bintang. Ayo selesaikan!")
	# The last 30 s before the next star is lost: the timer warms up as a nudge.
	var nxt := par if stars == 3 else (par * 1.5 if stars == 2 else INF)
	_hurry = nxt - seconds < 30.0
	if not _hurry:
		_timer_text.add_theme_color_override("font_color", UI.CREAM)


## Room finished: stars, time and best time on a taped paper card. Closes on a click on the card,
## Enter, Space or Esc (after a short delay), or by itself after 6 s; then emits result_closed.
func show_result(stars: int, seconds: float, par: float, best: float, record: bool) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	var card := UI.panel(UI.paper_panel(0))
	var cs := card.get_theme_stylebox("panel") as StyleBoxFlat
	cs.content_margin_left = 26
	cs.content_margin_right = 26
	cs.content_margin_top = 22
	cs.content_margin_bottom = 16
	card.custom_minimum_size = Vector2(380, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var title := UI.label("Sempurna!" if stars == 3 else ("Bagus!" if stars == 2 else "Selesai!"), 32, UI.PAPER_INK, true, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 12)
	col.add_child(srow)
	for i in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(54, 54)
		var s := Star.new(54.0, UI.PAPER_SHADE)
		slot.add_child(s)
		srow.add_child(slot)
		if i < stars:
			s.scale = Vector2.ZERO
			s.rotation = -PI / 2.0
			var t := s.create_tween()
			t.tween_interval(0.3 + i * 0.26)
			t.tween_callback(func() -> void:
				s.color = UI.AMBER_DEEP
				Sfx.play("reward", 0.6, i * 200.0))
			t.tween_property(s, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(s, "rotation", 0.0, 0.42)
	var shown_best := seconds if (best < 0.0 or record) else minf(best, seconds)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 4)
	for pair: Array in [["Waktu", Db.clock(seconds)], ["Target 3 bintang", Db.clock(par)], ["Rekor", Db.clock(shown_best)]]:
		var k := UI.label(String(pair[0]), 19, UI.PAPER_INK_SOFT, false, false)
		k.custom_minimum_size = Vector2(180, 0)
		stats.add_child(k)
		var v := UI.label(String(pair[1]), 18, UI.PAPER_INK, true, false)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size = Vector2(70, 0)
		stats.add_child(v)
	var sc := CenterContainer.new()
	sc.add_child(stats)
	col.add_child(sc)
	if record and best >= 0.0:
		var rl := UI.label("Rekor baru!", 20, UI.PAPER_RED, true, false)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rl)
	var hint_l := UI.label("Klik atau Enter untuk lanjut", 16, UI.PAPER_INK_SOFT, false, false)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint_l)
	var tape := ColorRect.new()
	tape.color = Color(0.84, 0.77, 0.59, 0.88)
	tape.size = Vector2(78, 20)
	tape.rotation_degrees = -2.0
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tape)
	var state := {"closed": false, "armed": false}
	var pos := Vector2.ZERO
	var close := func() -> void:
		if state["closed"]:
			return
		state["closed"] = true
		_close_result = Callable()
		var t := holder.create_tween().set_parallel(true)
		t.tween_property(holder, "modulate:a", 0.0, 0.26)
		t.tween_property(holder, "position:y", holder.position.y - 40.0, 0.26)
		t.chain().tween_callback(holder.queue_free)
		result_closed.emit()
	card.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if state["armed"] and mb != null and mb.pressed:
			close.call())
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
		state["armed"] = true
		if not state["closed"]:
			_close_result = close)
	get_tree().create_timer(6.0, false).timeout.connect(close)
	holder.modulate.a = 0.0
	await get_tree().process_frame
	card.reset_size()
	pos = Vector2(_visible_center() - card.size.x / 2.0, (VIEW.y - card.size.y) / 2.0)
	holder.position = pos
	tape.position = Vector2(card.size.x / 2.0 - 39, -10)
	holder.pivot_offset = card.size / 2.0
	holder.scale = Vector2(0.85, 0.85)
	holder.rotation_degrees = -3.0
	var tin := holder.create_tween().set_parallel(true)
	tin.tween_property(holder, "modulate:a", 1.0, 0.3)
	tin.tween_property(holder, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(holder, "rotation_degrees", 0.0, 0.42)


func result_open() -> bool:
	return _close_result.is_valid()


## Esc, Enter or Space on the result card.
func close_result() -> void:
	if _close_result.is_valid():
		var c := _close_result
		_close_result = Callable()
		c.call()


# ================= Tools =================

func set_tool(tool: String) -> void:
	_held = tool
	_refresh_slots()
	_update_cursor()


func suggest_tool(tool: String, seconds: float) -> void:
	_suggested = tool
	_refresh_slots()
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if _suggested == tool:
			_suggested = ""
			_refresh_slots())


func hover_tool(tool: String) -> void:
	if tool == _hovered_tool:
		return
	_hovered_tool = tool
	_refresh_slots()


func _refresh_slots() -> void:
	for id: String in _slots:
		var s: Dictionary = _slots[id]
		var b: Button = s["button"]
		var active := id == _held
		var lit := active or (id == _suggested)
		var ring := UI.AMBER if lit else UI.WOOD_500
		var bg := UI.WOOD_500 if active else UI.WOOD_700
		b.add_theme_stylebox_override("normal", _slot_style(bg, ring, 3 if lit else 2))
		b.add_theme_stylebox_override("hover", _slot_style(bg, UI.AMBER if lit else UI.AMBER_DEEP, 3 if lit else 2))
		b.position.y = -8.0 if active else 0.0
		(s["icon"] as Control).modulate.a = 0.3 if active else 1.0
		b.modulate = Color(1, 1, 1, 0.5) if (_held != "" and not active) else Color.WHITE
		(s["marker"] as Control).visible = not active and (id == _hovered_tool or id == _suggested)
	var bg_c := UI.WOOD_500 if _candle_held else CANDLE_BG
	_candle_slot.add_theme_stylebox_override("normal", _slot_style(bg_c, UI.AMBER if _candle_held else UI.WOOD_500, 3 if _candle_held else 2))
	_candle_slot.position.y = -8.0 if _candle_held else 0.0


func set_candle_held(on: bool) -> void:
	_candle_held = on
	_refresh_slots()
	_update_cursor()
	set_candles(GameState.count("candle"))


func _update_cursor() -> void:
	if _candle_held:
		_cursor.texture = Db.tex(String(Db.named.get("candle", "lilin")))
	elif _held != "":
		_cursor.texture = Db.tex(String(Db.tool_info(_held).get("icon", "")))
	_cursor.visible = (_candle_held or _held != "") and not cinematic


func set_tool_level(tool: String, level: int, leveled_up: bool) -> void:
	if not _slots.has(tool):
		return
	var s: Dictionary = _slots[tool]
	var i := 0
	for p: ColorRect in s["pips"]:
		p.color = UI.AMBER if i < level else UI.WOOD_900
		i += 1
	var max_lv := int(Db.game["tool_levels"]["maxLevel"])
	(s["button"] as Control).tooltip_text = "%s - level %d/%d. Tahan tombol %s atau tahan slot ini." % [s["name"], level, max_lv, s["key"]]
	if leveled_up:
		var b: Button = s["button"]
		b.add_theme_stylebox_override("normal", _slot_style(UI.WOOD_500, UI.AMBER, 3))
		get_tree().create_timer(1.2, false).timeout.connect(_refresh_slots)


## Tool sprite that follows the pointer; wiggles while it is cleaning.
func move_cursor(p: Vector2, working: bool) -> void:
	if not _cursor.visible:
		return
	_cursor.position = p - Vector2(18, 50)
	var wiggle := working and not Settings.reduced_motion()
	_cursor.rotation = deg_to_rad(sin(Time.get_ticks_msec() / 45.0) * 14.0) if wiggle else 0.0


func set_candles(n: int) -> void:
	_candle_count.text = str(n)
	_candle_holder.visible = n > 0 or _candle_held


func set_trash(n: int) -> void:
	_trash_count.text = str(n)
	_trash_box.pivot_offset = _trash_box.size / 2.0
	var t := _trash_box.create_tween()
	t.tween_property(_trash_box, "scale", Vector2(1.12, 1.12), 0.15)
	t.tween_property(_trash_box, "scale", Vector2.ONE, 0.15)


# ================= Messages =================

func toast(text: String) -> void:
	_seq_toast += 1
	var my := _seq_toast
	var w := UI.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > 560.0 else TextServer.AUTOWRAP_OFF
	_toast_label.custom_minimum_size.x = 560.0 if w > 560.0 else 0.0
	_toast_label.text = text
	_toast.reset_size()
	await get_tree().process_frame
	if my != _seq_toast:
		return
	_toast.reset_size()
	_toast.position = Vector2(_visible_center() - _toast.size.x / 2.0, 80)
	var t := _toast.create_tween().set_parallel(true)
	t.tween_property(_toast, "modulate:a", 1.0, 0.18)
	t.tween_property(_toast, "position:y", 74.0, 0.18)
	await get_tree().create_timer(2.8, false).timeout
	if my == _seq_toast:
		_toast.create_tween().tween_property(_toast, "modulate:a", 0.0, 0.3)


func _place_dialog() -> void:
	var w := minf(720.0, VIEW.x - _inset() - 48.0)
	_dialog_panel.custom_minimum_size.x = w
	_dialog_text.custom_minimum_size.x = w - 52.0
	_dialog_panel.reset_size()
	var bottom := 76.0 if cinematic else 118.0
	_dialog.position = Vector2(_visible_center() - w / 2.0, VIEW.y - bottom - _dialog_panel.size.y)


func dialog(speaker: String, text: String, duration: float) -> void:
	_seq_dialog += 1
	var my := _seq_dialog
	_dialog_speaker.text = speaker
	_dialog_tab.visible = speaker != ""
	_dialog_hint.modulate.a = 0.0
	_dialog_text.start(text, Settings.chars_per_second())
	var was_visible := _dialog.visible
	_dialog.visible = true
	_place_dialog()
	await get_tree().process_frame
	if my != _seq_dialog:
		return
	_place_dialog()
	if not was_visible:
		var y := _dialog.position.y
		_dialog.modulate.a = 0.0
		_dialog.position.y = y + 12.0
		var t := _dialog.create_tween().set_parallel(true)
		t.tween_property(_dialog, "modulate:a", 1.0, 0.2)
		t.tween_property(_dialog, "position:y", y, 0.22)
	if duration > 0.0:
		await get_tree().create_timer(duration + text.length() / Settings.chars_per_second(), false).timeout
		if my == _seq_dialog:
			hide_dialog()


func typing() -> bool:
	return _dialog_text.running


func finish_typing() -> void:
	_dialog_text.finish()


func hide_dialog() -> void:
	_seq_dialog += 1
	_dialog_text.stop()
	_dialog.visible = false
	_dialog_hint.modulate.a = 0.0


func dialog_hint(on: bool) -> void:
	_dialog_hint.create_tween().tween_property(_dialog_hint, "modulate:a", 1.0 if on else 0.0, 0.3)


func _make_alert(id: String) -> Dictionary:
	var fr: Array = UI.framed(UI.WOOD_900, UI.WARN, 0)
	var card: PanelContainer = fr[0]
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(fr[1] as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := _ring_of(fr[1])
	r.content_margin_left = 10
	r.content_margin_right = 14
	r.content_margin_top = 10
	r.content_margin_bottom = 12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var mark_style := UI.box(UI.WARN, Color("b8533f"), 0, Color.TRANSPARENT, 0)
	mark_style.border_width_bottom = 4
	var mark := UI.panel(mark_style)
	mark.custom_minimum_size = Vector2(32, 32)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ml := UI.label("!", 22, UI.INK, true, false)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(ml)
	row.add_child(mark)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := UI.label("", 21, UI.CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(340, 0)
	body.add_child(text)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.visible = false
	var bl := UI.label("", 16, UI.CREAM_DIM, true)
	bar.add_child(bl)
	var track: Array = UI.framed(Color("0d0806"), UI.WOOD_600, 0, Color.TRANSPARENT, false)
	var tr: PanelContainer = track[0]
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var area := Control.new()
	area.custom_minimum_size = Vector2(0, 10)
	area.clip_contents = true
	(track[1] as PanelContainer).add_child(area)
	var fill := ColorRect.new()
	fill.color = UI.WARN
	fill.size = Vector2(0, 10)
	area.add_child(fill)
	bar.add_child(tr)
	var bv := UI.label("0%", 16, UI.CREAM, true)
	bv.custom_minimum_size = Vector2(44, 0)
	bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(bv)
	body.add_child(bar)
	row.add_child(body)
	(fr[1] as PanelContainer).add_child(row)
	_passthrough(card)
	_alerts.add_child(card)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.24)
	# The mark blinks three times.
	var blink := mark.create_tween().set_loops(3)
	blink.tween_callback(func() -> void: mark_style.bg_color = UI.CREAM).set_delay(0.6)
	blink.tween_callback(func() -> void: mark_style.bg_color = UI.WARN).set_delay(0.6)
	var a := {"card": card, "text": text, "bar": bar, "label": bl, "area": area, "fill": fill, "value": bv}
	_alert_map[id] = a
	return a


## Instruction card for one running event; empty text removes it (and its bar).
func objective(id: String, text: String) -> void:
	if text == "":
		if _alert_map.has(id):
			(_alert_map[id]["card"] as Node).queue_free()
			_alert_map.erase(id)
		return
	var a: Dictionary = _alert_map[id] if _alert_map.has(id) else _make_alert(id)
	(a["text"] as Label).text = text


## Progress bar inside an event's card; value < 0 hides it.
func event_bar(id: String, label: String, value: float) -> void:
	var a: Dictionary
	if _alert_map.has(id):
		a = _alert_map[id]
	elif value >= 0.0:
		a = _make_alert(id)
	else:
		return
	var bar: Control = a["bar"]
	bar.visible = value >= 0.0
	if value < 0.0:
		return
	var v := clampf(value, 0.0, 1.0)
	(a["label"] as Label).text = label
	var area: Control = a["area"]
	var fill: ColorRect = a["fill"]
	fill.size = Vector2(area.size.x * v, area.size.y)
	fill.color = UI.AMBER if v >= 0.5 else UI.WARN
	(a["value"] as Label).text = "%d%%" % roundi(v * 100.0)


func banner(text: String, hold: float = 1.8) -> void:
	_banner.text = text
	_relayout_messages()
	var y := 250.0
	_banner.position.y = y + 8.0
	_banner.modulate.a = 0.0
	var total := hold + 0.8
	var t := _banner.create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, total * 0.15)
	t.parallel().tween_property(_banner, "position:y", y, total * 0.15).set_ease(Tween.EASE_OUT)
	t.tween_interval(total * 0.6)
	t.tween_property(_banner, "modulate:a", 0.0, total * 0.25)
	t.parallel().tween_property(_banner, "position:y", y - 6.0, total * 0.25)


## Small warning tip near the pointer, e.g. "Butuh: Kain Lap".
func hint(p: Vector2, text: String) -> void:
	_chip_label.text = text
	_chip_ring.border_color = UI.WARN
	_chip_until = Time.get_ticks_msec() + 1200
	_show_chip(p)


## Persistent hover label ("Vas layu: klik 2x"); empty text hides it.
func hover_label(p: Vector2, text: String) -> void:
	# A timed hint (wrong tool) keeps the chip until it expires.
	if _chip_until > 0:
		return
	if text == "" or cinematic:
		_chip.visible = false
		return
	_chip_ring.border_color = UI.WOOD_500
	if _chip_label.text != text:
		_chip_label.text = text
	_show_chip(p)


func _show_chip(p: Vector2) -> void:
	_chip.visible = true
	_chip.reset_size()
	var w := _chip.size.x
	var px := p.x - 18.0 - w if p.x + 18.0 + w > VIEW.x - 8.0 else p.x + 18.0
	_chip.position = Vector2(roundf(px), roundf(maxf(8.0, p.y - 34.0)))


# ================= Pointers =================

func set_pointer(id: String, target: Callable) -> void:
	clear_pointer(id)
	var arrow := Arrow.new()
	_pointer_layer.add_child(arrow)
	_pointers[id] = {"get": target, "node": arrow}


func clear_pointer(id: String) -> void:
	if _pointers.has(id):
		(_pointers[id]["node"] as Node).queue_free()
		_pointers.erase(id)


func update_pointers(cam: CameraRig) -> void:
	var u := cam.usable().grow(-24)
	var bob := 0.0 if Settings.reduced_motion() else sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 4.0
	for id: String in _pointers.keys():
		var entry: Dictionary = _pointers[id]
		var target: Variant = (entry["get"] as Callable).call()
		if target == null:
			# Done with that spot (puddle mopped, candle lit): the arrow goes away.
			clear_pointer(id)
			continue
		var arrow: Arrow = entry["node"]
		var s := cam.world_to_screen(target as Vector2)
		if u.has_point(s):
			arrow.position = s + Vector2(0, -20 + bob)
			arrow.rotation = 0.0
			arrow.edge = false
		else:
			arrow.position = s.clamp(u.position, u.end)
			arrow.rotation = (s - u.get_center()).angle() - PI / 2.0
			arrow.edge = true


# ================= Navigation & screen =================

func show_nav() -> void:
	for c in _nav.get_children():
		c.queue_free()
	if not GameState.is_completed(room_id):
		_nav.visible = false
		return
	var nxt := Db.next_room(room_id)
	var first: Button = null
	if GameState.all_completed():
		first = _nav_button("Pulang", func() -> void: go_home.emit(), true)
	for id: String in Db.room_order:
		if id == room_id:
			continue
		var done := GameState.is_completed(id)
		if not done and id != nxt:
			continue
		var r := Db.room(id)
		var text := String(r["short"]) if done else "Lanjut: %s" % r["short"]
		var b := _nav_button(text, func() -> void: go_room.emit(id), not done)
		b.tooltip_text = ("Kunjungi lagi %s" if done else "Pergi ke %s") % r["name"]
		if not done:
			first = b
	# The main action sits first in the row.
	if first:
		_nav.move_child(first, 0)
	_nav.visible = true
	_nav.modulate.a = 0.0
	var y := VIEW.y - 10 - 50
	_nav.position.y = y + 10.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_nav, "modulate:a", 1.0, 0.36)
	t.tween_property(_nav, "position:y", y, 0.36)
	if first:
		first.grab_focus()


func _nav_button(text: String, fn: Callable, primary: bool) -> Button:
	var b := UI.text_button(text, true, primary)
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20 if primary else 18)
	b.pressed.connect(fn)
	_nav.add_child(b)
	return b


func set_cinematic(on: bool) -> void:
	cinematic = on
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_letterbox[0], "position:y", 0.0 if on else -56.0, 0.5)
	t.tween_property(_letterbox[1], "position:y", VIEW.y - 56.0 if on else VIEW.y, 0.5)
	t.tween_property(_top, "position:y", -110.0 if on else 0.0, 0.3)
	t.tween_property(_bottom, "position:y", 130.0 if on else 0.0, 0.3)
	_apply_todo(false)
	_alerts.visible = not on
	_pointer_layer.visible = not on
	if on:
		_chip.visible = false
	_update_cursor()


## Old-film look while a remembered line plays.
func set_memory(on: bool) -> void:
	create_tween().tween_property(_grain, "modulate:a", 1.0 if on else 0.0, 0.9)


func fade(to_black: bool, ms: float) -> void:
	create_tween().tween_property(_fade, "color:a", 1.0 if to_black else 0.0, ms / 1000.0)


## strength follows the web values: 0.6 while filthy down to about 0.15 when clean.
func set_vignette(strength: float) -> void:
	create_tween().tween_property(_vignette, "modulate:a", clampf(strength / 0.6, 0.0, 1.0), 0.8)


func set_glow(on: bool, instant: bool = false) -> void:
	if instant:
		_glow.modulate.a = 1.0 if on else 0.0
	else:
		create_tween().tween_property(_glow, "modulate:a", 1.0 if on else 0.0, 2.0)


## True when screen point `p` is over a HUD panel (so a press there is not a click in the room).
func blocks_point(p: Vector2) -> bool:
	if _todo_panel.mouse_filter == Control.MOUSE_FILTER_STOP and _todo_panel.get_global_rect().has_point(p):
		return true
	if cinematic:
		return false
	var panels: Array = [_trash_box]
	for c in _top.get_children():
		panels.append(c)
	if _nav.visible:
		panels.append_array(_nav.get_children())
	for c in _bottom.get_children():
		if c is HBoxContainer and c != _nav:
			panels.append_array(c.get_children())
	for c: Control in panels:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


## Amber arrow pointing down at what an event needs; red when the target is off screen.
class Arrow extends Control:
	const SHAPE := [Vector2(0.5, 1), Vector2(0, 0.3), Vector2(0.3, 0.3), Vector2(0.3, 0), Vector2(0.7, 0), Vector2(0.7, 0.3), Vector2(1, 0.3)]

	var small := false
	var edge := false:
		set(v):
			if v != edge:
				edge = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if small:
			# Little triangle above a tool slot.
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 7)]), UI.AMBER)
			return
		# 28px arrow with a stem, tip at (0, 0): same shape as the web pointer.
		var pts := PackedVector2Array()
		var sh := PackedVector2Array()
		for v: Vector2 in SHAPE:
			var q := (v - Vector2(0.5, 1.0)) * 28.0
			pts.append(q)
			sh.append(q + Vector2(2, 2))
		draw_colored_polygon(sh, UI.INK)
		draw_colored_polygon(pts, UI.WARN if edge else UI.AMBER)
