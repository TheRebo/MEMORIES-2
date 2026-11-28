class_name Hud
extends CanvasLayer
## Room HUD (hud.tscn), laid out like the web build: wooden plaque with progress at the top
## left, timer and buttons at the top right, the paper task note pinned on the left, the tool
## belt at the bottom centre and room navigation on the right. Messages
## centre on the part of the room that is still visible. The room drives it through calls.

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
const TASK_ROW := preload("res://scenes/room/hud/task_row.tscn")
const ALERT_CARD := preload("res://scenes/room/hud/alert_card.tscn")
const RESULT_CARD := preload("res://scenes/room/hud/result_card.tscn")
const POINTER := preload("res://scenes/room/hud/pointer_arrow.tscn")

var room_id := ""
var todo_open := true
var cinematic := false
var _slots: Dictionary = {}
var _alert_map: Dictionary = {}
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
var _result: ResultCard
var _chip_until := 0
var _clock := 0.0

@onready var _vignette: Control = %Vignette
@onready var _glow: Control = %Glow
@onready var _grain: Control = %Grain
@onready var _pointer_layer: Control = %Pointers
@onready var _top: Control = %Top
@onready var _bottom: Control = %Bottom
@onready var _step_text: Label = %StepText
@onready var _room_name: Label = %RoomName
@onready var _progress_bar: Control = %ProgressBar
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _progress_lip: ColorRect = %ProgressLip
@onready var _progress_shine: ColorRect = %ProgressShine
@onready var _progress_text: Label = %ProgressText
@onready var _timer: PanelContainer = %Timer
@onready var _time_text: Label = %TimeText
@onready var _stars: Array = [%TimerStar1, %TimerStar2, %TimerStar3]
@onready var _note: Control = %Note
@onready var _note_paper: PanelContainer = %NotePaper
@onready var _task_count: Label = %TaskCount
@onready var _task_scroll: ScrollContainer = %TaskScroll
@onready var _task_list: VBoxContainer = %TaskList
@onready var _done_box: Control = %DoneBox
@onready var _done_toggle: Button = %DoneToggle
@onready var _done_list: VBoxContainer = %DoneList
@onready var _candle_slot: ToolSlot = %CandleSlot
@onready var _nav: HBoxContainer = %Nav
@onready var _fade: ColorRect = %Fade
@onready var _letter_top: Control = %LetterTop
@onready var _letter_bottom: Control = %LetterBottom
@onready var _alerts: VBoxContainer = %Alerts
@onready var _toast: PanelContainer = %Toast
@onready var _toast_text: Label = %ToastText
@onready var _dialog: Control = %Dialog
@onready var _dialog_panel: PanelContainer = %DialogPanel
@onready var _dialog_tab: Control = %DialogTab
@onready var _dialog_speaker: Label = %DialogSpeaker
@onready var _dialog_text: Typer = %DialogText
@onready var _dialog_hint: Label = %DialogHint
@onready var _banner: Label = %Banner
@onready var _chip: PanelContainer = %Chip
@onready var _chip_text: Label = %ChipText
@onready var _cursor: TextureRect = %Cursor


func setup(def: Dictionary) -> void:
	room_id = String(def["id"])
	var order: Array = Db.room_order
	var step := order.find(room_id) + 1
	_step_text.text = "%d/%d" % [step, order.size()]
	(_step_text.get_parent() as Control).tooltip_text = "Ruangan %d dari %d" % [step, order.size()]
	_room_name.text = String(def["name"])
	# The note stays as the player left it, from room to room.
	todo_open = Settings.notes_open
	(%MenuButton as BaseButton).pressed.connect(func() -> void: menu_pressed.emit())
	(%NotesButton as BaseButton).pressed.connect(toggle_todo)
	_done_toggle.pressed.connect(func() -> void:
		_show_done = not _show_done
		_done_list.visible = _show_done
		_render_done_toggle()
		_fit_note())
	var max_lv := int(Db.game["tool_levels"]["maxLevel"])
	for slot: ToolSlot in (%Slots as Node).get_children():
		if slot.is_candle:
			slot.slot_down.connect(func() -> void: candle_slot_down.emit())
			continue
		var id := slot.tool_id
		_slots[id] = slot
		slot.slot_down.connect(func() -> void: tool_slot_down.emit(id))
		slot.slot_activate.connect(func() -> void: tool_slot_activate.emit(id))
		slot.set_level(GameState.tool_level(id), max_lv)
	_vignette.modulate.a = 0.6
	_apply_note(true)
	_refresh_slots()


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
		_time_text.add_theme_color_override("font_color", UI.WARN if int(_clock * 2.0) % 2 == 0 else UI.AMBER)
	var bob := 0.0 if still else (-3.0 if int(_clock / 0.35) % 2 == 0 else 0.0)
	var blink := not still and int(_clock / 0.3) % 2 == 0
	for id: String in _slots:
		var s: ToolSlot = _slots[id]
		s.bob(bob)
		s.pulse(blink and id == _suggested and id != _held)
	if _chip.visible and _chip_until > 0 and Time.get_ticks_msec() > _chip_until:
		_chip_until = 0
		_chip.visible = false


func _inset() -> float:
	return TODO_W if todo_open and not cinematic else 0.0


## Horizontal centre of the room area that is still visible.
func _visible_center() -> float:
	var i := _inset()
	return i + (VIEW.x - i) / 2.0


# ================= Progress & tasks =================

func set_progress(pct: float) -> void:
	var w := _progress_bar.size.x if _progress_bar.size.x > 0.0 else 270.0
	create_tween().tween_property(_progress_fill, "size:x", w * clampf(pct, 0, 100) / 100.0, 0.4).set_ease(Tween.EASE_OUT)
	_progress_text.text = "%d%%" % roundi(pct)
	var clean := roundi(pct) >= 100
	_progress_fill.color = UI.SAGE if clean else UI.AMBER
	_progress_lip.color = Color("6f9e5a") if clean else UI.AMBER_DEEP
	_progress_text.add_theme_color_override("font_color", UI.SAGE if clean else UI.CREAM)


func set_groups(groups: Array, kinds: Dictionary) -> void:
	for c in _task_list.get_children():
		c.queue_free()
	for c in _done_list.get_children():
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
		var row: TaskRow = TASK_ROW.instantiate()
		(_done_list if fin else _task_list).add_child(row)
		row.setup(g, String(kinds.get(name_text, "")))
		if fin:
			_done_count += 1
			continue
		open_n += 1
		row.chosen.connect(func(group: String) -> void: task_clicked.emit(group))
		# An event added work (new puddles): flash it so the change is noticed.
		var prev: Variant = _last_groups.get(name_text)
		if (prev == null and not _last_groups.is_empty()) or (prev is Dictionary and int(prev["total"]) < int(g["total"])):
			row.flash(&"TaskRowGrew")
	if open_n == 0:
		var empty := UI.label("Semua beres!" if not groups.is_empty() else "Tidak ada tugas.", "PaperDoneLabel", 19)
		_task_list.add_child(empty)
	_task_count.text = "%d/%d" % [done_n, total_n]
	_task_count.tooltip_text = "Tinggal %d lagi" % (total_n - done_n)
	_done_box.visible = _done_count > 0
	_render_done_toggle()
	_last_groups.clear()
	for g: Dictionary in groups:
		_last_groups[g["name"]] = g
	_fit_note()


func _render_done_toggle() -> void:
	_done_toggle.text = "%s Selesai (%d)" % ["-" if _show_done else "+", _done_count]


## The note grows with its list up to 500px, then the list scrolls.
func _fit_note() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_task_list):
		return
	var done_h := _done_box.get_combined_minimum_size().y if _done_box.visible else 0.0
	var room_for_list := 500.0 - 80.0 - done_h
	_task_scroll.custom_minimum_size.y = clampf(_task_list.get_combined_minimum_size().y, 28.0, maxf(60.0, room_for_list))
	_note_paper.reset_size()


func flash_group(name_text: String) -> void:
	toast("Selesai: %s" % name_text)


func toggle_todo() -> void:
	todo_open = not todo_open
	Settings.set_value("notesOpen", todo_open)
	_apply_note(false)
	Sfx.ui_click()
	todo_toggled.emit()


func _apply_note(instant: bool) -> void:
	var show := todo_open and not cinematic
	var x := 12.0 if show else -300.0
	var a := 1.0 if show else 0.0
	_note_paper.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	if instant:
		_note.position.x = x
		_note.modulate.a = a
	else:
		var t := create_tween().set_parallel(true)
		t.tween_property(_note, "position:x", x, 0.3).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_note, "modulate:a", a, 0.3)
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
	_time_text.text = Db.clock(s)
	var stars := Db.stars_for(par, seconds)
	if stars != _last_stars:
		_last_stars = stars
		for i in 3:
			(_stars[i] as Star).color = UI.AMBER if i < stars else UI.WOOD_600
		var lost: Star = _stars[stars]
		lost.color = UI.WARN
		var t := lost.create_tween()
		t.tween_property(lost, "scale", Vector2(1.6, 1.6), 0.1)
		t.tween_property(lost, "scale", Vector2.ONE, 0.5)
		t.tween_callback(func() -> void: lost.color = UI.WOOD_600)
		_timer.theme_type_variation = &"AlertFrame"
		get_tree().create_timer(1.2, false).timeout.connect(func() -> void: _timer.theme_type_variation = &"WoodDarkFrame")
		toast("Bintang ketiga hilang. Dua lagi masih aman!" if stars == 2 else "Tinggal satu bintang. Ayo selesaikan!")
	# The last 30 s before the next star is lost: the timer warms up as a nudge.
	var nxt := par if stars == 3 else (par * 1.5 if stars == 2 else INF)
	_hurry = nxt - seconds < 30.0
	if not _hurry:
		_time_text.add_theme_color_override("font_color", UI.CREAM)


func show_result(stars: int, seconds: float, par: float, best: float, record: bool) -> void:
	_result = RESULT_CARD.instantiate()
	(%Root as Control).add_child(_result)
	_result.dismissed.connect(func() -> void:
		_result = null
		result_closed.emit())
	_result.show_result(stars, seconds, par, best, record, _visible_center())


func result_open() -> bool:
	return _result != null and _result.armed


## Esc, Enter or Space on the result card.
func close_result() -> void:
	if _result:
		_result.dismiss()


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
		var s: ToolSlot = _slots[id]
		s.set_state(id == _held, id == _suggested, id == _hovered_tool, _held != "" and id != _held)
	_candle_slot.set_state(_candle_held, false, false, false)


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
	var s: ToolSlot = _slots[tool]
	s.set_level(level, int(Db.game["tool_levels"]["maxLevel"]))
	if leveled_up:
		s.flash_level_up()
		get_tree().create_timer(1.2, false).timeout.connect(_refresh_slots)


## Tool sprite that follows the pointer; wiggles while it is cleaning.
func move_cursor(p: Vector2, working: bool) -> void:
	if not _cursor.visible:
		return
	_cursor.position = p - Vector2(18, 50)
	var wiggle := working and not Settings.reduced_motion()
	_cursor.rotation = deg_to_rad(sin(Time.get_ticks_msec() / 45.0) * 14.0) if wiggle else 0.0


func set_candles(n: int) -> void:
	_candle_slot.set_count(n)
	_candle_slot.visible = n > 0 or _candle_held


# ================= Messages =================

func toast(text: String) -> void:
	_seq_toast += 1
	var my := _seq_toast
	var w := _toast_text.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > 560.0 else TextServer.AUTOWRAP_OFF
	_toast_text.custom_minimum_size.x = 560.0 if w > 560.0 else 0.0
	_toast_text.text = text
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


func _alert(id: String) -> AlertCard:
	if not _alert_map.has(id):
		var card: AlertCard = ALERT_CARD.instantiate()
		_alerts.add_child(card)
		_alert_map[id] = card
	return _alert_map[id]


## Instruction card for one running event; empty text removes it (and its bar).
func objective(id: String, text: String) -> void:
	if text == "":
		if _alert_map.has(id):
			(_alert_map[id] as Node).queue_free()
			_alert_map.erase(id)
		return
	_alert(id).set_text(text)


## Progress bar inside an event's card; value < 0 hides it.
func event_bar(id: String, label: String, value: float) -> void:
	if not _alert_map.has(id) and value < 0.0:
		return
	_alert(id).set_bar(label, value)


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
	_chip_text.text = text
	_chip.theme_type_variation = &"ChipWarnFrame"
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
	_chip.theme_type_variation = &"ChipFrame"
	if _chip_text.text != text:
		_chip_text.text = text
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
	var arrow: PointerArrow = POINTER.instantiate()
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
		var arrow: PointerArrow = entry["node"]
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
	var b := SfxButton.new()
	b.text = text
	b.theme_type_variation = &"PrimarySmallButton" if primary else &"SmallButton"
	b.custom_minimum_size = Vector2(0, 46)
	if primary:
		b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(fn)
	_nav.add_child(b)
	return b


func set_cinematic(on: bool) -> void:
	cinematic = on
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_letter_top, "position:y", 0.0 if on else -56.0, 0.5)
	t.tween_property(_letter_bottom, "position:y", VIEW.y - 56.0 if on else VIEW.y, 0.5)
	t.tween_property(_top, "position:y", -110.0 if on else 0.0, 0.3)
	t.tween_property(_bottom, "position:y", 130.0 if on else 0.0, 0.3)
	_apply_note(false)
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


## Opacity as in the web build: 0.6 while filthy, down to about 0.15 when clean.
func set_vignette(strength: float) -> void:
	create_tween().tween_property(_vignette, "modulate:a", clampf(strength, 0.0, 1.0), 0.8)


func set_glow(on: bool, instant: bool = false) -> void:
	if instant:
		_glow.modulate.a = 1.0 if on else 0.0
	else:
		create_tween().tween_property(_glow, "modulate:a", 1.0 if on else 0.0, 2.0)


## True when screen point `p` is over a HUD panel (so a press there is not a click in the room).
func blocks_point(p: Vector2) -> bool:
	if _note_paper.mouse_filter == Control.MOUSE_FILTER_STOP and _note_paper.get_global_rect().has_point(p):
		return true
	if cinematic:
		return false
	var panels: Array = [%Plaque, _timer, %NotesButton, %MenuButton, %Belt]
	if _nav.visible:
		panels.append_array(_nav.get_children())
	for c: Control in panels:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false
