class_name ResultCard
extends Control
## Room finished: stars, time and best time on a taped paper card. Closes on a click on the
## card, Enter, Space or Esc (after a short delay), or by itself after 6 s.

signal dismissed

var armed := false
var _closed := false

@onready var _card: PanelContainer = %Card
@onready var _tape: Control = %Tape


func show_result(stars: int, seconds: float, par: float, best: float, record: bool, center_x: float) -> void:
	(%Title as Label).text = "Perfect!" if stars == 3 else ("Great!" if stars == 2 else "Selesai!")
	(%TimeValue as Label).text = Db.clock(seconds)
	(%ParValue as Label).text = Db.clock(par)
	var shown_best := seconds if (best < 0.0 or record) else minf(best, seconds)
	(%BestValue as Label).text = Db.clock(shown_best)
	(%Record as Control).visible = record and best >= 0.0
	for i in 3:
		var s: Star = get_node("%%Star%d" % (i + 1))
		s.color = UI.PAPER_SHADE
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
	_card.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if armed and mb != null and mb.pressed:
			dismiss())
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void: armed = true)
	get_tree().create_timer(6.0, false).timeout.connect(dismiss)
	modulate.a = 0.0
	await get_tree().process_frame
	_card.reset_size()
	position = Vector2(center_x - _card.size.x / 2.0, (720.0 - _card.size.y) / 2.0)
	_tape.position = Vector2(_card.size.x / 2.0 - _tape.size.x / 2.0, -10)
	pivot_offset = _card.size / 2.0
	scale = Vector2(0.85, 0.85)
	rotation_degrees = -3.0
	var tin := create_tween().set_parallel(true)
	tin.tween_property(self, "modulate:a", 1.0, 0.3)
	tin.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(self, "rotation_degrees", 0.0, 0.42)


func dismiss() -> void:
	if _closed:
		return
	_closed = true
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.26)
	t.tween_property(self, "position:y", position.y - 40.0, 0.26)
	t.chain().tween_callback(queue_free)
	dismissed.emit()
