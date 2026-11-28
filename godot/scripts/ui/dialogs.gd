class_name Dialogs
extends RefCounted
## The game's dialogs, built on Modal.


class Confirm extends Modal:
	var body_text: String
	var confirm_text: String
	var on_confirm: Callable

	func _init(title: String, body: String, confirm: String, fn: Callable) -> void:
		super(title)
		body_text = body
		confirm_text = confirm
		on_confirm = fn

	func build() -> void:
		var l := UI.label(body_text, 21, UI.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
		box.add_child(l)
		var cancel := UI.text_button("Batal", true)
		cancel.pressed.connect(close)
		var ok := UI.text_button(confirm_text, true, true)
		ok.pressed.connect(func() -> void:
			close()
			on_confirm.call())
		add_button_row([cancel, ok])


class SettingsDlg extends Modal:
	var allow_delete := true
	var _status: Label

	func _init(delete_allowed: bool = true) -> void:
		super("Pengaturan")
		allow_delete = delete_allowed

	func build() -> void:
		for pair: Array in [["master", "Utama"], ["music", "Musik"], ["sfx", "Efek suara"]]:
			_volume_row(String(pair[0]), String(pair[1]))
		var shake := CheckBox.new()
		shake.text = "Efek gerak (guncangan, kilatan, latar bergerak)"
		shake.button_pressed = Settings.screen_shake
		shake.add_theme_color_override("font_color", UI.CREAM)
		shake.toggled.connect(func(on: bool) -> void: Settings.set_value("screenShake", on))
		box.add_child(shake)
		var speed := HBoxContainer.new()
		speed.add_theme_constant_override("separation", 8)
		speed.add_child(UI.label("Kecepatan teks", 20, UI.CREAM_DIM, false, false))
		var group := ButtonGroup.new()
		for pair: Array in [["slow", "Lambat"], ["normal", "Normal"], ["fast", "Cepat"]]:
			var b := UI.text_button(String(pair[1]), true, Settings.text_speed == pair[0])
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = Settings.text_speed == pair[0]
			var v := String(pair[0])
			b.pressed.connect(func() -> void: Settings.set_value("textSpeed", v))
			speed.add_child(b)
		box.add_child(speed)
		var fs := CheckBox.new()
		fs.text = "Layar penuh"
		fs.add_theme_color_override("font_color", UI.CREAM)
		fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fs.toggled.connect(func(on: bool) -> void:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		box.add_child(fs)
		_status = UI.label("", 18, UI.CREAM_DIM, false, false)
		box.add_child(_status)
		var buttons: Array = []
		if allow_delete:
			var del := UI.text_button("Hapus data simpanan", true)
			del.pressed.connect(func() -> void:
				var c := Confirm.new("Hapus data?", "Semua progres ruangan dan level alat akan hilang. Pengaturan tetap tersimpan.", "Hapus",
					func() -> void:
						GameState.new_game()
						_status.text = "Data simpanan dihapus.")
				get_parent().add_child(c))
			buttons.append(del)
		var done := UI.text_button("Selesai", true, true)
		done.pressed.connect(close)
		buttons.append(done)
		add_button_row(buttons)

	func _volume_row(key: String, text: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UI.label(text, 20, UI.CREAM, false, false)
		l.custom_minimum_size = Vector2(140, 0)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.value = roundf(float(Settings.get(key)) * 100.0)
		s.custom_minimum_size = Vector2(300, 28)
		var out := UI.label(str(int(s.value)), 20, UI.AMBER_ON_WOOD, true, false)
		out.custom_minimum_size = Vector2(48, 0)
		s.value_changed.connect(func(v: float) -> void:
			out.text = str(int(v))
			Settings.set_value(key, v / 100.0)
			if key != "music":
				Sfx.play("ui_hover", 0.6, 0.0, 120))
		row.add_child(l)
		row.add_child(s)
		row.add_child(out)
		box.add_child(row)


class Credits extends Modal:
	func _init() -> void:
		super("Kredit")

	func build() -> void:
		var c: Dictionary = Db.story.get("credits", {})
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		for r: Dictionary in c.get("roles", []):
			grid.add_child(UI.label(String(r["role"]), 21, UI.CREAM_DIM, false, false))
			grid.add_child(UI.label(String(r["name"]), 21, UI.AMBER_ON_WOOD, true, false))
		box.add_child(grid)
		for t: String in c.get("thirdParty", []):
			box.add_child(UI.label("- " + t, 18, UI.CREAM_DIM, false, false))
		box.add_child(UI.label(String(c.get("thanks", "")), 21, UI.CREAM))
		var back := UI.text_button("Kembali", true)
		back.pressed.connect(close)
		add_button_row([back])


## How-to pages on paper (MC's grandmother's notes). Arrow keys page through.
class Tutorial extends Modal:
	var pages: Array
	var index := 0
	var _title_l: Label
	var _text_l: Label
	var _img: TextureRect
	var _dots: HBoxContainer
	var _prev: Button
	var _next: Button

	func _init(title: String, tutorial_pages: Array) -> void:
		super(title)
		pages = tutorial_pages

	func _frame_style() -> StyleBox:
		return UI.paper_panel(18)

	func build() -> void:
		_title_l = UI.label("", 23, UI.PAPER_INK, true, false)
		box.add_child(_title_l)
		_img = TextureRect.new()
		_img.custom_minimum_size = Vector2(620, 140)
		_img.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		box.add_child(_img)
		_text_l = UI.label("", 23, UI.PAPER_INK, false, false)
		_text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text_l.custom_minimum_size = Vector2(620, 96)
		box.add_child(_text_l)
		_dots = HBoxContainer.new()
		_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var foot: Array = [_dots]
		if pages.size() > 1:
			var shut := UI.text_button("Tutup", true)
			shut.pressed.connect(close)
			_prev = UI.text_button("Kembali", true)
			_prev.pressed.connect(func() -> void: _go(-1))
			_next = UI.text_button("Lanjut", true, true)
			_next.pressed.connect(func() -> void: _go(1))
			foot.append_array([shut, _prev, _next])
		else:
			var ok := UI.text_button("Mengerti", true, true)
			ok.pressed.connect(close)
			foot.append(ok)
		add_button_row(foot)
		_render()

	func _go(d: int) -> void:
		if index + d >= pages.size():
			close()
			return
		index = clampi(index + d, 0, pages.size() - 1)
		_render()

	func _render() -> void:
		var p: Dictionary = pages[index]
		_title_l.text = String(p.get("title", ""))
		_text_l.text = String(p.get("text", ""))
		var img := String(p.get("image", ""))
		_img.visible = img != ""
		if img != "":
			_img.texture = Db.tex(img)
		for c in _dots.get_children():
			c.queue_free()
		if pages.size() > 1:
			for i in pages.size():
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(12, 12)
				dot.color = UI.PAPER_INK if i == index else UI.PAPER_SHADE
				_dots.add_child(dot)
			_prev.disabled = index == 0
			_next.text = "Selesai" if index == pages.size() - 1 else "Lanjut"

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_right") and pages.size() > 1:
			_go(1)
		elif event.is_action_pressed("ui_left") and pages.size() > 1:
			_go(-1)
		else:
			super(event)


## Pause: lettered CONTINUE / SETTING / QUIT art plus a plank button for the tutorial.
class Pause extends Modal:
	var room_name: String
	var percent: int
	var room_saved: bool
	var on_tutorial: Callable
	var on_main_menu: Callable

	func _init(name: String, pct: int, saved: bool, tutorial_fn: Callable, menu_fn: Callable) -> void:
		super("Jeda")
		room_name = name
		percent = pct
		room_saved = saved
		on_tutorial = tutorial_fn
		on_main_menu = menu_fn

	func build() -> void:
		var info := UI.panel(UI.box(UI.WOOD_900, UI.WOOD_700, 2, Color.TRANSPARENT, 10))
		var row := HBoxContainer.new()
		var n := UI.label(room_name, 20, UI.CREAM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UI.label("%d%% bersih" % percent, 18, UI.AMBER_ON_WOOD, true))
		info.add_child(row)
		box.add_child(info)
		var list := VBoxContainer.new()
		list.alignment = BoxContainer.ALIGNMENT_CENTER
		list.add_theme_constant_override("separation", 10)
		var cont := UI.art_button("btn_continue_long", "Lanjutkan", 2, Vector2(165, 32))
		cont.pressed.connect(close)
		var sett := UI.art_button("btn_setting_long", "Pengaturan", 2, Vector2(165, 32))
		sett.pressed.connect(func() -> void: get_parent().add_child(SettingsDlg.new(false)))
		var tut := UI.text_button("Tutorial")
		tut.custom_minimum_size = Vector2(330, 64)
		tut.pressed.connect(func() -> void:
			close()
			on_tutorial.call())
		var quit := UI.art_button("btn_quit_long", "Menu utama", 2, Vector2(192, 32))
		quit.pressed.connect(_leave)
		for b: Control in [cont, sett, tut, quit]:
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			list.add_child(b)
		box.add_child(list)
		if not room_saved:
			var note := UI.label("Progres tersimpan otomatis setiap kali satu ruangan selesai.", 18, UI.CREAM_DIM, false, false)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(360, 0)
			box.add_child(note)

	func _leave() -> void:
		if room_saved:
			close()
			on_main_menu.call()
			return
		get_parent().add_child(Confirm.new("Kembali ke menu?",
			"Ruangan ini belum selesai, jadi progresnya di ruangan ini akan diulang.", "Ke menu",
			func() -> void:
				close()
				on_main_menu.call()))
