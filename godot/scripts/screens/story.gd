extends Node2D
## Full-screen illustrated slides for the prolog and the epilog, with a paper text box.

const ROAD_Y := 676.0

var args: Dictionary = {}
var main: Node
var _slides: Array = []
var _which := "intro"
var _index := -1
var _art: Node2D
var _transitioning := false
var _finished := false
var _ui: CanvasLayer
var _box: PanelContainer
var _speaker: Label
var _text: Typer
var _hint: Label
var _visible := false
var _locked_until := 0
var _auto_timer: SceneTreeTimer


func _ready() -> void:
	_which = String(args.get("which", "intro"))
	_slides = Db.story.get(_which, [])
	RenderingServer.set_default_clear_color(Color("0d0907"))
	Sfx.play_music("present" if _which == "intro" else "ending", 1.6)
	_build_ui()
	_next()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_box = UI.panel(UI.paper_panel(22))
	_box.modulate.a = 0.0
	_ui.add_child(_box)
	var v := VBoxContainer.new()
	_box.add_child(v)
	_speaker = UI.label("", 21, UI.CREAM, true)
	var tab := UI.panel(UI.box(UI.WOOD_700, UI.INK, 2, Color.TRANSPARENT, 6))
	tab.add_child(_speaker)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(tab)
	_text = Typer.new()
	_text.add_theme_font_override("font", UI.body_font())
	_text.add_theme_font_size_override("font_size", 27)
	_text.add_theme_color_override("font_color", UI.PAPER_INK)
	_text.custom_minimum_size = Vector2(0, 70)
	_text.finished_typing.connect(func() -> void: _hint.modulate.a = 1.0)
	v.add_child(_text)
	_hint = UI.label("Klik atau tekan Enter untuk lanjut", 18, UI.PAPER_INK_SOFT, false, false)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	var skip := UI.text_button("Lewati", true)
	skip.pressed.connect(_finish)
	_ui.add_child(skip)
	# Pinned to the top-right corner, growing left, so it never runs off screen.
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -24
	skip.offset_top = 24


func _place(where: String) -> void:
	match where:
		"right":
			_box.position = Vector2(600, 520)
			_box.size = Vector2(632, 0)
		"top":
			_box.position = Vector2(160, 44)
			_box.size = Vector2(960, 0)
		_:
			_box.position = Vector2(160, 520)
			_box.size = Vector2(960, 0)
	_box.custom_minimum_size = Vector2(_box.size.x, 0)


func _show_text(slide: Dictionary) -> void:
	_place(String(slide.get("box", "center")))
	_speaker.text = String(slide.get("speaker", ""))
	_speaker.get_parent().visible = _speaker.text != ""
	_hint.modulate.a = 0.0
	_visible = true
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.22)
	_locked_until = Time.get_ticks_msec() + 450
	_text.start(String(slide.get("text", "")), Settings.chars_per_second())
	if slide.has("hold"):
		_auto_timer = get_tree().create_timer(float(slide["hold"]))
		var idx := _index
		_auto_timer.timeout.connect(func() -> void:
			if idx == _index:
				_advance())


func _unhandled_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept"):
		press = true
	elif event.is_action_pressed("ui_cancel"):
		_finish()
		return
	if press:
		get_viewport().set_input_as_handled()
		if not _visible or Time.get_ticks_msec() < _locked_until:
			return
		if _text.running:
			_text.finish()
			return
		Sfx.ui_click()
		_advance()


func _advance() -> void:
	if not _visible:
		return
	_visible = false
	create_tween().tween_property(_box, "modulate:a", 0.0, 0.18)
	_next()


func _next() -> void:
	if _transitioning or _finished:
		return
	_index += 1
	if _index >= _slides.size():
		_finish()
		return
	_transitioning = true
	var slide: Dictionary = _slides[_index]
	var fresh := _build_art(slide)
	fresh.modulate.a = 0.0
	add_child(fresh)
	move_child(fresh, 0)
	var old := _art
	_art = fresh
	create_tween().tween_property(fresh, "modulate:a", 1.0, 0.5 if old else 0.9)
	if old:
		var t := create_tween()
		t.tween_property(old, "modulate:a", 0.0, 0.4)
		t.tween_callback(old.queue_free)
	await get_tree().create_timer(0.45 if old else 0.7).timeout
	_transitioning = false
	if _finished:
		return
	if slide.has("sfx"):
		Sfx.play(String(slide["sfx"]))
	_show_text(slide)


func _art_texture(art: String) -> Texture2D:
	return Db.tex("ui/lobby.png") if art == "lobby" else Db.tex("cutscene/%s.png" % art)


func _build_art(slide: Dictionary) -> Node2D:
	var c := Node2D.new()
	var art := String(slide.get("art", ""))
	var still := Settings.reduced_motion()
	if art == "hand_cut_fix":
		var bg := ColorRect.new()
		bg.color = Color("2e2118")
		bg.size = Vector2(1280, 720)
		c.add_child(bg)
		var hand := Sprite2D.new()
		hand.texture = _art_texture(art)
		hand.scale = Vector2(1.25, 1.25)
		hand.position = Vector2(720, 470 if still else 820)
		c.add_child(hand)
		if not still:
			create_tween().tween_property(hand, "position:y", 470.0, 1.4).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return c
	var img := Sprite2D.new()
	img.texture = _art_texture(art)
	var cover := maxf(1280.0 / img.texture.get_width(), 720.0 / img.texture.get_height())
	img.scale = Vector2(cover, cover)
	img.position = Vector2(640, 360)
	c.add_child(img)
	var motion := String(slide.get("motion", "none"))
	if motion == "busArrive" or motion == "busLeave":
		c.add_child(_ground())
		var shadow := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(Vector2(cos(a) * 235.0, sin(a) * 11.0))
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.28)
		c.add_child(shadow)
		var bus := Sprite2D.new()
		bus.texture = Db.tex("cutscene/bus.png")
		bus.centered = false
		bus.scale = Vector2(0.36, 0.36)
		bus.offset = Vector2(-bus.texture.get_width() / 2.0, -bus.texture.get_height() * 0.985)
		c.add_child(bus)
		var start_x := 520.0 if (still or motion == "busLeave") else -360.0
		bus.position = Vector2(start_x, ROAD_Y)
		shadow.position = Vector2(start_x, ROAD_Y - 2)
		if not still:
			if motion == "busArrive":
				for n: Node2D in [bus, shadow]:
					create_tween().tween_property(n, "position:x", 520.0, 2.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				var bob := create_tween().set_loops(12)
				bob.tween_property(bus, "position:y", ROAD_Y - 3, 0.16)
				bob.tween_property(bus, "position:y", ROAD_Y, 0.16)
				_dust(c, 520.0, 2.6)
			else:
				for n: Node2D in [bus, shadow]:
					create_tween().tween_property(n, "position:x", 1700.0, 3.2).set_delay(0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	elif not still and motion == "panRight":
		img.scale *= 1.12
		img.position.x = 700
		create_tween().tween_property(img, "position:x", 580.0, 12.0).set_trans(Tween.TRANS_SINE)
	elif not still and motion == "slowZoom":
		create_tween().tween_property(img, "scale", img.scale * 1.06, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return c


## The prolog painting has no ground, so bus slides get a grass bank and a village dirt road
## drawn in the painting's 8px grid; the wheels sit on it.
func _ground() -> Node2D:
	var g := Node2D.new()
	var px := 8
	var grass_top := 600
	var add_rect := func(r: Rect2, col: Color) -> void:
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.color = col
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(cr)
	add_rect.call(Rect2(0, grass_top, 1280, 720 - grass_top), Color("1f5a3a"))
	for x in range(0, 1280, px):
		var bump := ((x * 7919) % 23) % 3
		add_rect.call(Rect2(x, grass_top - bump * px, px, px * (2 + bump)), Color("2f7d3b"))
	add_rect.call(Rect2(0, ROAD_Y - 34, 1280, 720 - (ROAD_Y - 34)), Color("7a5a48"))
	add_rect.call(Rect2(0, ROAD_Y - 26, 1280, 12), Color("8c6a52"))
	add_rect.call(Rect2(0, ROAD_Y - 6, 1280, px), Color("5f4436"))
	add_rect.call(Rect2(0, ROAD_Y + 26, 1280, px), Color("5f4436"))
	for x in range(12, 1280, 72):
		add_rect.call(Rect2(x, ROAD_Y + 10 + ((x * 13) % 3) * px, px, px / 2.0), Color("b89a7a"))
	return g


func _dust(c: Node2D, stop_x: float, seconds: float) -> void:
	for i in 10:
		get_tree().create_timer(seconds * 0.35 + i * 0.12).timeout.connect(func() -> void:
			if not is_instance_valid(c):
				return
			var puff := Polygon2D.new()
			var pts := PackedVector2Array()
			for k in 8:
				pts.append(Vector2(cos(TAU * k / 8.0), sin(TAU * k / 8.0)) * randf_range(6, 12))
			puff.polygon = pts
			puff.color = Color(0.78, 0.71, 0.6, 0.7)
			puff.position = Vector2(stop_x - 200 + randf() * 30, ROAD_Y - 6)
			c.add_child(puff)
			var t := create_tween().set_parallel(true)
			t.tween_property(puff, "position", puff.position + Vector2(-60, -18), 0.9)
			t.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.9)
			t.tween_property(puff, "modulate:a", 0.0, 0.9)
			t.chain().tween_callback(puff.queue_free))


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _which == "intro":
		main.go("Room", {"room": "living_room"}, 1.0)
	else:
		main.go("TitleCard", {}, 1.6)
