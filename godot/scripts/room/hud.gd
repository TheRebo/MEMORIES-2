class_name Hud
extends CanvasLayer
## Room HUD, laid out like the web build: wooden plaque with progress at the top left, timer
## and buttons at the top right, the task note pinned on the left, the tool bar at the bottom,
## messages in the middle and event cards at the top right. Updated by the room through calls
## (events in, never polling game state).

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

var room_id := ""
var todo_open := true
var _root: Control
var _vignette: TextureRect
var _glow: TextureRect
var _grain: ColorRect
var _fade: ColorRect
var _letterbox: Array[ColorRect] = []
var _pointer_layer: Control
var _top: Control
var _bottom: Control
var _todo: PanelContainer
var _todo_list: VBoxContainer
var _todo_done: VBoxContainer
var _todo_done_head: Button
var _todo_count: Label
var _progress_fill: ColorRect
var _progress_back: ColorRect
var _progress_text: Label
var _timer_text: Label
var _timer_box: PanelContainer
var _stars: Array[Label] = []
var _slots: Dictionary = {}
var _candle_slot: Button
var _candle_count: Label
var _trash_count: Label
var _nav: HBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _dialog: PanelContainer
var _dialog_speaker: Label
var _dialog_text: Typer
var _dialog_hint: Label
var _banner: Label
var _hint: PanelContainer
var _hint_label: Label
var _hover: PanelContainer
var _hover_label: Label
var _cursor: TextureRect
var _cards: VBoxContainer
var _card_map: Dictionary = {}
var _pointers: Dictionary = {}
var _held := ""
var _hovered_tool := ""
var _suggested := ""
var _candle_held := false
var _last_second := -1
var _last_stars := 3
var _last_groups: Dictionary = {}
var _seq := 0
var _show_done := false
var _done_names: Array = []
var _close_result := Callable()


func setup(def: Dictionary) -> void:
	room_id = String(def["id"])
	todo_open = true
	_root = UI.layer()
	add_child(_root)
	_build_ambient()
	_build_top(def)
	_build_todo()
	_build_bottom()
	_build_messages()
	_apply_todo()


# ================= Build =================

func _radial_tex(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	g.add_point(0.55, inner)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 320
	t.height = 180
	return t


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


func _build_ambient() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = _radial_tex(Color(0.05, 0.03, 0.02, 0.0), Color(0.05, 0.03, 0.02, 0.95))
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_full(_vignette)
	_vignette.modulate.a = 0.6
	_glow = TextureRect.new()
	_glow.texture = _radial_tex(Color(1.0, 0.8, 0.45, 0.0), Color(1.0, 0.75, 0.35, 0.35))
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_full(_glow)
	_glow.modulate.a = 0.0
	_grain = ColorRect.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.12;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 3.0);
	float n = h(cell + floor(TIME * 18.0));
	float flick = 0.04 * sin(TIME * 23.0);
	vec2 uv = UV - 0.5;
	float vig = smoothstep(0.35, 0.75, length(uv));
	COLOR = vec4(vec3(0.25, 0.18, 0.1), clamp((n - 0.5) * strength * 2.0 + vig * 0.35 + flick, 0.0, 1.0));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_grain.material = mat
	_full(_grain)
	_grain.visible = false
	_pointer_layer = _full(Control.new())


func _build_top(def: Dictionary) -> void:
	_top = _full(Control.new())
	var order: Array = Db.room_order
	var step := order.find(room_id) + 1
	var plaque := UI.panel(UI.wood_panel(12))
	plaque.position = Vector2(16, 12)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	plaque.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var badge := UI.panel(UI.box(UI.AMBER_DEEP, UI.INK, 2, Color.TRANSPARENT, 4))
	badge.add_child(UI.label("%d/%d" % [step, order.size()], 16, UI.INK, true, false))
	badge.tooltip_text = "Ruangan %d dari %d" % [step, order.size()]
	row.add_child(badge)
	row.add_child(UI.label(String(def["name"]), 26, UI.AMBER_ON_WOOD, true))
	col.add_child(row)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	_progress_back = ColorRect.new()
	_progress_back.color = UI.WOOD_900
	_progress_back.custom_minimum_size = Vector2(250, 14)
	_progress_fill = ColorRect.new()
	_progress_fill.color = UI.SAGE
	_progress_fill.size = Vector2(0, 14)
	_progress_back.add_child(_progress_fill)
	var pv := CenterContainer.new()
	pv.add_child(_progress_back)
	prow.add_child(pv)
	_progress_text = UI.label("0%", 18, UI.CREAM, true)
	_progress_text.custom_minimum_size = Vector2(52, 0)
	prow.add_child(_progress_text)
	col.add_child(prow)
	_top.add_child(plaque)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions.position = Vector2(VIEW.x - 16 - 470, 16)
	actions.size = Vector2(470, 56)
	_timer_box = UI.panel(UI.wood_panel(8))
	_timer_box.tooltip_text = "Waktu di ruangan ini. Bersihkan lebih cepat untuk bintang lebih banyak."
	_timer_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	for i in 3:
		var s := UI.label("*", 24, UI.AMBER, true)
		_stars.append(s)
		trow.add_child(s)
	_timer_text = UI.label("0:00", 22, UI.CREAM, true)
	_timer_text.custom_minimum_size = Vector2(64, 0)
	_timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(_timer_text)
	_timer_box.add_child(trow)
	actions.add_child(_timer_box)
	var notes := UI.text_button("Catatan [T]", true)
	notes.tooltip_text = "Buka/tutup catatan (T)"
	notes.pressed.connect(toggle_todo)
	actions.add_child(notes)
	var menu := UI.art_button("btn_menu", "Jeda (Esc)", 2, Vector2(24, 24))
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	actions.add_child(menu)
	_top.add_child(actions)


func _build_todo() -> void:
	_todo = UI.panel(UI.paper_panel(14))
	_todo.position = Vector2(16, TOP + 18)
	_todo.custom_minimum_size = Vector2(TODO_W - 24, 0)
	_todo.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_todo.add_child(col)
	var head := HBoxContainer.new()
	var title := UI.label("Catatan", 24, UI.PAPER_INK, true, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_todo_count = UI.label("", 18, UI.PAPER_INK_SOFT, true, false)
	head.add_child(_todo_count)
	col.add_child(head)
	var rule := ColorRect.new()
	rule.color = UI.PAPER_EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(TODO_W - 52, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_todo_list = VBoxContainer.new()
	_todo_list.add_theme_constant_override("separation", 2)
	inner.add_child(_todo_list)
	_todo_done_head = Button.new()
	_todo_done_head.flat = true
	_todo_done_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_todo_done_head.add_theme_font_override("font", UI.body_font())
	_todo_done_head.add_theme_font_size_override("font_size", 18)
	_todo_done_head.add_theme_color_override("font_color", UI.PAPER_INK_SOFT)
	_todo_done_head.add_theme_color_override("font_hover_color", UI.PAPER_INK)
	_todo_done_head.pressed.connect(func() -> void:
		_show_done = not _show_done
		_todo_done.visible = _show_done
		_render_done_head())
	inner.add_child(_todo_done_head)
	_todo_done = VBoxContainer.new()
	_todo_done.visible = false
	inner.add_child(_todo_done)
	scroll.add_child(inner)
	col.add_child(scroll)
	_root.add_child(_todo)
	var tp := UI.tape(86)
	tp.position = Vector2(TODO_W / 2.0 - 52, -12)
	_todo.add_child(tp)
	# The tape sits over the paper, not inside the container's layout.
	tp.top_level = false
	_todo.resized.connect(func() -> void: tp.position = Vector2(_todo.size.x / 2.0 - 43, -12))


func _slot_style(border: Color, bg: Color = UI.WOOD_800) -> StyleBoxFlat:
	var s := UI.box(bg, border, 2, Color.TRANSPARENT, 6)
	s.border_width_bottom = 4
	return s


func _make_slot(icon: String, key: String, name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 88)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _slot_style(UI.INK))
	b.add_theme_stylebox_override("hover", _slot_style(UI.AMBER_DEEP, UI.WOOD_700))
	b.add_theme_stylebox_override("pressed", _slot_style(UI.AMBER, UI.WOOD_600))
	b.add_theme_stylebox_override("focus", UI.focus_ring())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.name = "Col"
	var img := TextureRect.new()
	img.texture = Db.tex(icon)
	img.custom_minimum_size = Vector2(44, 44)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.name = "Icon"
	col.add_child(img)
	var n := UI.label(name, 16, UI.CREAM)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(n)
	b.add_child(col)
	var k := UI.label(key, 16, UI.AMBER_ON_WOOD, true)
	k.position = Vector2(6, 2)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(k)
	b.mouse_entered.connect(Sfx.ui_hover)
	return b


func _build_bottom() -> void:
	_bottom = _full(Control.new())
	var shelf := ColorRect.new()
	shelf.color = Color(0.09, 0.06, 0.04, 0.0)
	_bottom.add_child(shelf)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var tools: Array = Db.game.get("tools", [])
	for t: Dictionary in tools:
		var id := String(t["id"])
		var b := _make_slot(String(t["icon"]), String(t["keyLabel"]), String(t["name"]))
		b.tooltip_text = "%s: tahan %s, atau klik sekali untuk memegang" % [t["name"], t["keyLabel"]]
		b.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				tool_slot_down.emit(id)
			elif e.is_action_pressed("ui_accept"):
				b.accept_event()
				tool_slot_activate.emit(id))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		pips.position = Vector2(84 - 6 - 5 * 9, 6)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var max_lv := int(Db.game["tool_levels"]["maxLevel"])
		for i in max_lv:
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(7, 7)
			p.color = UI.WOOD_600
			pips.add_child(p)
		b.add_child(pips)
		bar.add_child(b)
		_slots[id] = {"button": b, "pips": pips}
		set_tool_level(id, GameState.tool_level(id), false)
	_candle_slot = _make_slot(String(Db.named.get("candle", "lilin")), String(Db.game["candle_key"]["label"]), "Lilin")
	_candle_slot.tooltip_text = "Lilin: tahan %s lalu lepas di lantai" % Db.game["candle_key"]["label"]
	_candle_count = UI.label("0", 18, UI.AMBER_ON_WOOD, true)
	_candle_count.position = Vector2(62, 2)
	_candle_slot.add_child(_candle_count)
	_candle_slot.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			candle_slot_down.emit())
	_candle_slot.visible = false
	bar.add_child(_candle_slot)
	var bar_w := 4 * 92 + 84
	bar.position = Vector2((VIEW.x - bar_w) / 2.0, VIEW.y - 98)
	_bottom.add_child(bar)

	var trash := UI.panel(UI.wood_panel(8))
	trash.tooltip_text = "Sampah terkumpul"
	trash.mouse_filter = Control.MOUSE_FILTER_STOP
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	var ti := TextureRect.new()
	ti.texture = Db.tex(String(Db.named.get("trash_bag", "trash_bag")))
	ti.custom_minimum_size = Vector2(36, 36)
	ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trow.add_child(ti)
	trow.add_child(UI.label("Sampah", 18, UI.CREAM_DIM))
	_trash_count = UI.label(str(GameState.trash_total()), 22, UI.AMBER_ON_WOOD, true)
	trow.add_child(_trash_count)
	trash.add_child(trow)
	trash.position = Vector2(16, VIEW.y - 78)
	_bottom.add_child(trash)

	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 8)
	_nav.alignment = BoxContainer.ALIGNMENT_END
	_nav.position = Vector2(VIEW.x - 16 - 380, VIEW.y - 74)
	_nav.size = Vector2(380, 50)
	_nav.visible = false
	_bottom.add_child(_nav)


func _build_messages() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.015, 0.0)
	_full(_fade)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.015, 0.01)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(VIEW.x, 0)
		bar.position = Vector2(0, 0 if i == 0 else VIEW.y)
		_root.add_child(bar)
		_letterbox.append(bar)

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.position = Vector2(VIEW.x - 16 - 340, TOP + 10)
	_cards.custom_minimum_size = Vector2(340, 0)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cards)

	_toast = UI.panel(UI.wood_panel(10))
	_toast_label = UI.label("", 20, UI.CREAM)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_dialog = UI.panel(UI.paper_panel(16))
	_dialog.custom_minimum_size = Vector2(720, 0)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 4)
	_dialog_speaker = UI.label("", 22, UI.PAPER_RED, true, false)
	dcol.add_child(_dialog_speaker)
	_dialog_text = Typer.new()
	_dialog_text.add_theme_font_override("font", UI.body_font())
	_dialog_text.add_theme_font_size_override("font_size", 24)
	_dialog_text.add_theme_color_override("font_color", UI.PAPER_INK)
	_dialog_text.custom_minimum_size = Vector2(688, 56)
	dcol.add_child(_dialog_text)
	_dialog_hint = UI.label("Klik atau Enter untuk lanjut, Esc untuk lewati", 16, UI.PAPER_INK_SOFT, false, false)
	_dialog_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialog_hint.modulate.a = 0.0
	dcol.add_child(_dialog_hint)
	_dialog.add_child(dcol)
	_dialog.visible = false
	_root.add_child(_dialog)

	_banner = UI.label("", 56, UI.AMBER_ON_WOOD, true)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(VIEW.x, 80)
	_banner.position = Vector2(0, VIEW.y * 0.36)
	_banner.pivot_offset = _banner.size / 2.0
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

	_hint = UI.panel(UI.box(UI.PAPER_RED, UI.INK, 2, Color.TRANSPARENT, 6))
	_hint_label = UI.label("", 18, UI.CREAM)
	_hint.add_child(_hint_label)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	_root.add_child(_hint)

	_hover = UI.panel(UI.box(Color(UI.WOOD_900, 0.92), UI.INK, 2, Color.TRANSPARENT, 5))
	_hover_label = UI.label("", 16, UI.CREAM)
	_hover.add_child(_hover_label)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.visible = false
	_root.add_child(_hover)

	_cursor = TextureRect.new()
	_cursor.custom_minimum_size = Vector2(64, 64)
	_cursor.size = Vector2(64, 64)
	_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.pivot_offset = Vector2(16, 48)
	_cursor.visible = false
	_root.add_child(_cursor)


# ================= Progress & tasks =================

func set_progress(pct: float) -> void:
	var w := _progress_back.custom_minimum_size.x
	create_tween().tween_property(_progress_fill, "size:x", w * clampf(pct, 0, 100) / 100.0, 0.3)
	_progress_text.text = "%d%%" % roundi(pct)
	_progress_fill.color = UI.AMBER if pct >= 100.0 else UI.SAGE


func _kind_icon(kind: String) -> Control:
	if kind == "hand" or kind == "click" or kind == "":
		var l := UI.label("2x" if kind == "click" else ("o" if kind == "hand" else ""), 14, UI.PAPER_INK_SOFT, true, false)
		l.custom_minimum_size = Vector2(18, 18)
		l.tooltip_text = "Klik 2x" if kind == "click" else "Seret ke tempatnya"
		return l
	var t := TextureRect.new()
	t.texture = Db.tex(String(Db.tool_info(kind).get("icon", "")))
	t.custom_minimum_size = Vector2(18, 18)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func set_groups(groups: Array, kinds: Dictionary) -> void:
	for c in _todo_list.get_children():
		c.queue_free()
	for c in _todo_done.get_children():
		c.queue_free()
	var done_n := 0
	var total_n := 0
	var open_n := 0
	_done_names.clear()
	for g: Dictionary in groups:
		var name := String(g["name"])
		done_n += int(g["done"])
		total_n += int(g["total"])
		var fin: bool = g["done"] >= g["total"]
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE if fin else Control.FOCUS_ALL
		row.mouse_default_cursor_shape = Control.CURSOR_ARROW if fin else Control.CURSOR_POINTING_HAND
		row.custom_minimum_size = Vector2(TODO_W - 60, 30)
		row.add_theme_stylebox_override("focus", UI.focus_ring())
		var hover := UI.box(Color(UI.PAPER_SHADE, 0.7), Color.TRANSPARENT, 0, Color.TRANSPARENT, 2)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_stylebox_override("pressed", hover)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var check := UI.label("v" if fin else "-", 16, UI.PAPER_DONE if fin else UI.PAPER_INK_SOFT, true, false)
		check.custom_minimum_size = Vector2(12, 0)
		h.add_child(check)
		var icon := _kind_icon(String(kinds.get(name, "")))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
		var n := UI.label(name, 18, UI.PAPER_DONE if fin else UI.PAPER_INK, false, false)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(n)
		var cnt := UI.label("" if fin else "%d/%d" % [g["done"], g["total"]], 16, UI.PAPER_INK_SOFT, true, false)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cnt)
		row.add_child(h)
		if fin:
			row.disabled = true
			_todo_done.add_child(row)
			_done_names.append(name)
		else:
			open_n += 1
			row.tooltip_text = "Tunjukkan di ruangan"
			row.pressed.connect(func() -> void:
				Sfx.ui_click()
				_flash_row(row)
				task_clicked.emit(name))
			_todo_list.add_child(row)
			# An event added work to this task (new puddles): flash it so the change is seen.
			var prev: Variant = _last_groups.get(name)
			if (prev == null and not _last_groups.is_empty()) or (prev is Dictionary and int(prev["total"]) < int(g["total"])):
				_flash_row(row)
	if open_n == 0:
		_todo_list.add_child(UI.label("Semua beres!" if not groups.is_empty() else "Tidak ada tugas.", 18, UI.PAPER_DONE, false, false))
	_todo_count.text = "%d/%d" % [done_n, total_n]
	_todo_done_head.visible = not _done_names.is_empty()
	_render_done_head()
	_last_groups.clear()
	for g: Dictionary in groups:
		_last_groups[g["name"]] = g


func _render_done_head() -> void:
	_todo_done_head.text = "%s Sudah selesai (%d)" % ["v" if _show_done else ">", _done_names.size()]


func _flash_row(row: Control) -> void:
	row.modulate = Color(1.3, 1.1, 0.6)
	create_tween().tween_property(row, "modulate", Color.WHITE, 0.9)


func flash_group(name: String) -> void:
	toast("Selesai: %s" % name)


func toggle_todo() -> void:
	todo_open = not todo_open
	_apply_todo()
	Sfx.ui_click()
	todo_toggled.emit()


func _apply_todo() -> void:
	_todo.visible = todo_open
	_todo.custom_minimum_size.y = VIEW.y - TOP - BOTTOM - 36


func todo_inset() -> float:
	return TODO_W if todo_open and _top.visible else 0.0


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
			_stars[i].add_theme_color_override("font_color", UI.AMBER if i < stars else UI.WOOD_500)
		var lost := _stars[stars]
		lost.pivot_offset = lost.size / 2.0
		var t := create_tween()
		t.tween_property(lost, "scale", Vector2(1.6, 1.6), 0.12)
		t.tween_property(lost, "scale", Vector2.ONE, 0.25)
		toast("Bintang ketiga lepas. Masih bisa dapat dua!" if stars == 2 else "Tinggal satu bintang. Ayo selesaikan!")
	var nxt := par if stars == 3 else (par * 1.5 if stars == 2 else INF)
	_timer_text.add_theme_color_override("font_color", UI.WARN if nxt - seconds < 30.0 else UI.CREAM)


## Room finished: stars, time and best time on a paper card. Emits result_closed when dismissed.
func show_result(stars: int, seconds: float, par: float, best: float, record: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := UI.panel(UI.paper_panel(22))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	var title := UI.label("Sempurna!" if stars == 3 else ("Bagus!" if stars == 2 else "Selesai!"), 40, UI.PAPER_INK, true, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 14)
	col.add_child(srow)
	for i in 3:
		var s := UI.label("*", 72, UI.AMBER if i < stars else UI.PAPER_SHADE, true, i < stars)
		s.custom_minimum_size = Vector2(56, 64)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.pivot_offset = Vector2(28, 32)
		s.scale = Vector2.ZERO
		srow.add_child(s)
		var t := s.create_tween()
		t.tween_interval(0.3 + i * 0.26)
		t.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < stars:
			t.tween_callback(func() -> void: Sfx.play("reward", 0.5, i * 150.0))
	var shown_best := seconds if (best < 0.0 or record) else minf(best, seconds)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 26)
	for pair: Array in [["Waktu", Db.clock(seconds)], ["Target 3 bintang", Db.clock(par)], ["Rekor", Db.clock(shown_best)]]:
		stats.add_child(UI.label(String(pair[0]), 20, UI.PAPER_INK_SOFT, false, false))
		stats.add_child(UI.label(String(pair[1]), 22, UI.PAPER_INK, true, false))
	var sc := CenterContainer.new()
	sc.add_child(stats)
	col.add_child(sc)
	if record and best >= 0.0:
		var rl := UI.label("Rekor baru!", 22, UI.PAPER_RED, true, false)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rl)
	var ok := UI.text_button("Lanjut", false, true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ok)
	card.pivot_offset = card.size / 2.0
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.3)
	var closed := {"v": false}
	var close := func() -> void:
		if closed["v"]:
			return
		closed["v"] = true
		_close_result = Callable()
		var t := dim.create_tween()
		t.tween_property(dim, "modulate:a", 0.0, 0.25)
		t.tween_callback(dim.queue_free)
		result_closed.emit()
	ok.pressed.connect(close)
	_close_result = close
	await get_tree().process_frame
	ok.grab_focus()


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
	_cursor.visible = tool != ""
	if tool != "":
		_cursor.texture = Db.tex(String(Db.tool_info(tool).get("icon", "")))


func suggest_tool(tool: String, seconds: float) -> void:
	_suggested = tool
	_refresh_slots()
	var t := get_tree().create_timer(seconds, false)
	t.timeout.connect(func() -> void:
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
		var b: Button = _slots[id]["button"]
		var held := id == _held
		var cue := not held and (id == _suggested or id == _hovered_tool)
		var border := UI.AMBER if held else (UI.SAGE if cue else UI.INK)
		var bg := UI.WOOD_600 if held else (UI.WOOD_700 if cue else UI.WOOD_800)
		b.add_theme_stylebox_override("normal", _slot_style(border, bg))
		var icon := b.get_node_or_null("Col/Icon") as Control
		if icon:
			icon.modulate = Color(1.25, 1.18, 1.0) if held else Color.WHITE
	_candle_slot.add_theme_stylebox_override("normal", _slot_style(UI.AMBER if _candle_held else UI.INK))


func set_candle_held(on: bool) -> void:
	_candle_held = on
	_refresh_slots()
	_cursor.visible = on or _held != ""
	if on:
		_cursor.texture = Db.tex(String(Db.named.get("candle", "lilin")))


func set_tool_level(tool: String, level: int, leveled_up: bool) -> void:
	if not _slots.has(tool):
		return
	var pips: HBoxContainer = _slots[tool]["pips"]
	var i := 0
	for p: ColorRect in pips.get_children():
		p.color = UI.AMBER if i < level else UI.WOOD_600
		i += 1
	if leveled_up:
		var b: Button = _slots[tool]["button"]
		b.pivot_offset = b.size / 2.0
		var t := create_tween()
		t.tween_property(b, "scale", Vector2(1.15, 1.15), 0.12)
		t.tween_property(b, "scale", Vector2.ONE, 0.25)


func move_cursor(p: Vector2, working: bool) -> void:
	if not _cursor.visible:
		return
	_cursor.position = p - Vector2(16, 48)
	_cursor.rotation = sin(Time.get_ticks_msec() / 60.0) * 0.18 if working else -0.25


func set_candles(n: int) -> void:
	_candle_count.text = str(n)
	_candle_slot.visible = n > 0 or _candle_held
	_candle_slot.modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.5)


func set_trash(n: int) -> void:
	_trash_count.text = str(n)
	_trash_count.pivot_offset = _trash_count.size / 2.0
	var t := create_tween()
	t.tween_property(_trash_count, "scale", Vector2(1.4, 1.4), 0.1)
	t.tween_property(_trash_count, "scale", Vector2.ONE, 0.2)


# ================= Messages =================

func toast(text: String) -> void:
	_seq += 1
	var my := _seq
	_toast_label.text = text
	_toast.reset_size()
	await get_tree().process_frame
	_toast.position = Vector2((VIEW.x - _toast.size.x) / 2.0, TOP - 18)
	var t := _toast.create_tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(2.8, false).timeout
	if my == _seq and is_instance_valid(_toast):
		_toast.create_tween().tween_property(_toast, "modulate:a", 0.0, 0.3)


func dialog(speaker: String, text: String, duration: float) -> void:
	_seq += 1
	var my := _seq
	_dialog_speaker.text = speaker
	_dialog_speaker.visible = speaker != ""
	_dialog.visible = true
	_dialog.reset_size()
	_dialog_text.start(text, Settings.chars_per_second())
	await get_tree().process_frame
	_dialog.position = Vector2((VIEW.x - _dialog.size.x) / 2.0, VIEW.y - BOTTOM - _dialog.size.y - 18)
	if duration > 0.0:
		await get_tree().create_timer(duration + text.length() / Settings.chars_per_second(), false).timeout
		if my == _seq:
			hide_dialog()


func typing() -> bool:
	return _dialog_text.running


func finish_typing() -> void:
	_dialog_text.finish()


func hide_dialog() -> void:
	_dialog_text.stop()
	_dialog.visible = false
	_dialog_hint.modulate.a = 0.0


func dialog_hint(on: bool) -> void:
	_dialog_hint.modulate.a = 1.0 if on else 0.0


## Instruction card for one running event; empty text removes it (and its bar).
func objective(id: String, text: String) -> void:
	if text == "":
		if _card_map.has(id):
			var c: Control = _card_map[id]["card"]
			_card_map.erase(id)
			var t := c.create_tween()
			t.tween_property(c, "modulate:a", 0.0, 0.25)
			t.tween_callback(c.queue_free)
		return
	if not _card_map.has(id):
		var card := UI.panel(UI.box(Color(UI.WOOD_800, 0.95), UI.AMBER_DEEP, 3, Color.TRANSPARENT, 12))
		card.custom_minimum_size = Vector2(340, 0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var head := UI.label("! Kejadian", 18, UI.AMBER_ON_WOOD, true)
		col.add_child(head)
		var l := UI.label("", 19, UI.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(312, 0)
		col.add_child(l)
		card.add_child(col)
		_cards.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
		Sfx.play("warning", 0.4, 0.0, 600)
		_card_map[id] = {"card": card, "label": l, "col": col, "bar": null}
	(_card_map[id]["label"] as Label).text = text


func event_bar(id: String, label: String, value: float) -> void:
	if not _card_map.has(id):
		return
	var entry: Dictionary = _card_map[id]
	if value < 0.0:
		if entry["bar"]:
			(entry["bar"] as Control).queue_free()
			entry["bar"] = null
		return
	if entry["bar"] == null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.label(label, 16, UI.CREAM_DIM))
		var bg := ColorRect.new()
		bg.color = UI.WOOD_900
		bg.custom_minimum_size = Vector2(200, 12)
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = UI.AMBER
		fill.size = Vector2(0, 12)
		bg.add_child(fill)
		row.add_child(bg)
		(entry["col"] as VBoxContainer).add_child(row)
		entry["bar"] = row
		entry["fill"] = fill
	(entry["fill"] as ColorRect).size.x = 200.0 * clampf(value, 0.0, 1.0)


func banner(text: String, hold: float = 1.8) -> void:
	_banner.text = text
	_banner.scale = Vector2(0.85, 0.85)
	var t := _banner.create_tween()
	t.set_parallel(true)
	t.tween_property(_banner, "modulate:a", 1.0, 0.3)
	t.tween_property(_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(hold)
	t.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


func hint(p: Vector2, text: String) -> void:
	_hint_label.text = text
	_hint.reset_size()
	await get_tree().process_frame
	_hint.position = (p + Vector2(18, -46)).clamp(Vector2(8, 8), VIEW - _hint.size - Vector2(8, 8))
	var t := _hint.create_tween()
	t.tween_property(_hint, "modulate:a", 1.0, 0.1)
	t.tween_interval(1.4)
	t.tween_property(_hint, "modulate:a", 0.0, 0.3)


func hover_label(p: Vector2, text: String) -> void:
	if text == "":
		_hover.visible = false
		return
	if _hover_label.text != text:
		_hover_label.text = text
		_hover.reset_size()
	_hover.visible = true
	_hover.position = (p + Vector2(18, 18)).clamp(Vector2(8, 8), VIEW - _hover.size - Vector2(8, 8))


# ================= Pointers =================

func set_pointer(id: String, target: Callable) -> void:
	if _pointers.has(id):
		(_pointers[id]["node"] as Node).queue_free()
	var arrow := Arrow.new()
	_pointer_layer.add_child(arrow)
	_pointers[id] = {"get": target, "node": arrow}


func clear_pointer(id: String) -> void:
	if _pointers.has(id):
		(_pointers[id]["node"] as Node).queue_free()
		_pointers.erase(id)


func update_pointers(cam: CameraRig) -> void:
	var u := cam.usable().grow(-24)
	var bob := sin(Time.get_ticks_msec() / 180.0) * 4.0
	for id: String in _pointers.keys():
		var entry: Dictionary = _pointers[id]
		var target: Variant = (entry["get"] as Callable).call()
		var arrow: Arrow = entry["node"]
		if target == null:
			arrow.visible = false
			continue
		arrow.visible = true
		var s := cam.world_to_screen(target as Vector2)
		if u.has_point(s):
			arrow.position = s + Vector2(0, -14 + bob)
			arrow.rotation = 0.0
		else:
			var c := u.get_center()
			var clamped := s.clamp(u.position, u.end)
			arrow.position = clamped
			arrow.rotation = (s - c).angle() - PI / 2.0


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
		var b := _nav_button(String(r["short"]) if done else "Lanjut: %s" % r["short"], func() -> void: go_room.emit(id), not done)
		b.tooltip_text = ("Kunjungi lagi %s" if done else "Pergi ke %s") % r["name"]
		if not done:
			first = b
	if first:
		_nav.move_child(first, _nav.get_child_count() - 1)
	_nav.visible = true
	_nav.modulate.a = 0.0
	create_tween().tween_property(_nav, "modulate:a", 1.0, 0.4)
	if first:
		first.grab_focus()


func _nav_button(text: String, fn: Callable, primary: bool) -> Button:
	var b := UI.text_button(text, true, primary)
	b.pressed.connect(fn)
	_nav.add_child(b)
	return b


func set_cinematic(on: bool) -> void:
	var t := create_tween().set_parallel(true)
	var h := 64.0 if on else 0.0
	t.tween_property(_letterbox[0], "size:y", h, 0.5)
	t.tween_property(_letterbox[1], "size:y", h, 0.5)
	t.tween_property(_letterbox[1], "position:y", VIEW.y - h, 0.5)
	_top.visible = not on
	_bottom.visible = not on
	_todo.visible = todo_open and not on
	_cards.visible = not on
	_pointer_layer.visible = not on
	if on:
		_hover.visible = false
		_cursor.visible = false


## Old-film look while a remembered line plays.
func set_memory(on: bool) -> void:
	_grain.visible = on


func fade(to_black: bool, ms: float) -> void:
	create_tween().tween_property(_fade, "color:a", 1.0 if to_black else 0.0, ms / 1000.0)


func set_vignette(strength: float) -> void:
	_vignette.modulate.a = strength


func set_glow(on: bool, instant: bool = false) -> void:
	if instant:
		_glow.modulate.a = 1.0 if on else 0.0
	else:
		create_tween().tween_property(_glow, "modulate:a", 1.0 if on else 0.0, 2.0)


## True when screen point `p` is over a HUD panel (so it is not a click into the room).
func blocks_point(p: Vector2) -> bool:
	for c: Control in [_todo, _toast]:
		if c.visible and c.modulate.a > 0.5 and c.get_global_rect().has_point(p):
			return true
	if _top.visible and p.y < TOP:
		return true
	if _bottom.visible and p.y > VIEW.y - BOTTOM:
		return true
	return false


## Little bobbing arrow that points at what an event needs.
class Arrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(0, 2)])
		draw_colored_polygon(pts, UI.AMBER)
		pts.append(pts[0])
		draw_polyline(pts, UI.INK, 2.0)
