extends Control
## Title screen: the house painting is the menu. Logo over the roof, the team's lettered
## buttons in a row on the path, and a taped note of where the player left off.

var args: Dictionary = {}
var main: Node
var _bg: TextureRect
var _ui: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.load_save()
	Sfx.play_music("menu")
	_bg = TextureRect.new()
	_bg.texture = Db.tex("ui/lobby.png")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.size = Vector2(1280, 720) * 1.06
	_bg.position = Vector2(-20, -10)
	add_child(_bg)
	if not Settings.reduced_motion():
		var drift := create_tween().set_loops()
		drift.tween_property(_bg, "position", Vector2(-44, -18), 14.0).set_trans(Tween.TRANS_SINE)
		drift.tween_property(_bg, "position", Vector2(-20, -10), 14.0).set_trans(Tween.TRANS_SINE)
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.07, 0.04, 0.03, 0.0))
	grad.gradient.set_color(1, Color(0.07, 0.04, 0.03, 0.55))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	shade.texture = grad
	shade.position = Vector2(0, 480)
	shade.size = Vector2(1280, 240)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(shade)
	if not Settings.reduced_motion():
		_ambient()
	_build()


func _build() -> void:
	if _ui:
		_ui.queue_free()
	_ui = UI.layer()
	add_child(_ui)
	# Logo over the roof of the house.
	var logo := TextureRect.new()
	logo.texture = Db.tex("ui/title_logo_trim.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.size = Vector2(680, 175)
	logo.position = Vector2(470, 26)
	logo.pivot_offset = Vector2(340, 0)
	_ui.add_child(logo)
	logo.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(logo, "modulate:a", 1.0, 0.9)
	t.tween_property(logo, "position:y", 26.0, 0.9).from(-14.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not Settings.reduced_motion():
		var sway := create_tween().set_loops()
		sway.tween_property(logo, "rotation_degrees", -0.8, 3.5).set_trans(Tween.TRANS_SINE)
		sway.tween_property(logo, "rotation_degrees", 0.0, 3.5).set_trans(Tween.TRANS_SINE)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.position = Vector2(0, 590)
	row.size = Vector2(1280, 96)
	_ui.add_child(row)
	var can_continue := GameState.has_progress()
	if can_continue:
		_add(row, "btn_load", "Kunjungi lagi" if GameState.all_completed() else "Lanjutkan", _continue)
		_add(row, "btn_new_game", "Mulai baru", _confirm_new)
	else:
		_add(row, "btn_play", "Mulai", _new_game)
	_add(row, "btn_setting", "Pengaturan", func() -> void:
		var d := Dialogs.SettingsDlg.new(true)
		d.closed.connect(_build)
		add_child(d))
	_add(row, "btn_credit", "Kredit", func() -> void: add_child(Dialogs.Credits.new()))
	var i := 0
	for b: Control in row.get_children():
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.42).set_delay(0.07 * i)
		i += 1
	if can_continue:
		_ui.add_child(_save_note())
	(row.get_child(0) as Control).call_deferred("grab_focus")


func _add(row: HBoxContainer, file: String, tip: String, fn: Callable) -> void:
	var b := UI.art_button(file, tip, 3, Vector2(64, 32))
	b.pressed.connect(fn)
	row.add_child(b)


## "Catatan terakhir": one line per room, the next one marked, taped like the task note.
func _save_note() -> Control:
	var holder := Control.new()
	holder.position = Vector2(44, 52)
	holder.rotation_degrees = -1.6
	var p := UI.panel(UI.paper_panel(18))
	p.custom_minimum_size = Vector2(300, 0)
	holder.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.label("Catatan terakhir", 22, UI.PAPER_INK, true, false))
	var next := GameState.first_incomplete()
	for id: String in Db.room_order:
		var done := GameState.is_completed(id)
		var line := HBoxContainer.new()
		var n := UI.label(("> " if id == next else "") + String(Db.room(id)["name"]), 20, UI.PAPER_INK, false, false)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		var state := "bersih" if done else ("berikutnya" if id == next else "belum")
		line.add_child(UI.label(state, 17, UI.PAPER_DONE if done else UI.PAPER_INK_SOFT, true, false))
		v.add_child(line)
	var tape := UI.tape()
	tape.position = Vector2(111, -10)
	holder.add_child(tape)
	return holder


## Leaves from the apple tree and smoke from the chimney.
func _ambient() -> void:
	var leaves := CPUParticles2D.new()
	leaves.position = Vector2(440, -10)
	leaves.amount = 14
	leaves.lifetime = 9.0
	leaves.preprocess = 9.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(260, 4)
	leaves.direction = Vector2(0.2, 1)
	leaves.spread = 25.0
	leaves.gravity = Vector2(6, 22)
	leaves.initial_velocity_min = 20.0
	leaves.initial_velocity_max = 45.0
	leaves.angular_velocity_min = -120.0
	leaves.angular_velocity_max = 120.0
	leaves.scale_amount_min = 3.0
	leaves.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color("c9852f"))
	g.set_color(1, Color("8fae4a"))
	leaves.color_initial_ramp = g
	add_child(leaves)
	var smoke := CPUParticles2D.new()
	smoke.position = Vector2(970, 176)
	smoke.amount = 6
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.direction = Vector2(0.4, -1)
	smoke.spread = 12.0
	smoke.gravity = Vector2(4, -6)
	smoke.initial_velocity_min = 18.0
	smoke.initial_velocity_max = 26.0
	smoke.scale_amount_min = 8.0
	smoke.scale_amount_max = 10.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.6))
	smoke.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(0.88, 0.86, 0.82, 0.6))
	fade.set_color(1, Color(0.88, 0.86, 0.82, 0.0))
	smoke.color_ramp = fade
	add_child(smoke)


func _continue() -> void:
	var r := GameState.first_incomplete()
	main.go("Room", {"room": r if r != "" else "living_room"})


func _confirm_new() -> void:
	add_child(Dialogs.Confirm.new("Mulai baru?", "Progres ruangan yang sudah selesai akan dihapus.", "Hapus & mulai", _new_game))


func _new_game() -> void:
	GameState.new_game()
	main.go("Story", {"which": "intro"}, 0.9)
