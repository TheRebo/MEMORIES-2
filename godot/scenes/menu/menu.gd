extends Control
## Title screen: the house painting is the menu. Logo over the roof, the team's lettered
## buttons in a row on the path, and a taped note of where the player left off.

var args: Dictionary = {}
var main: Node

@onready var _bg: TextureRect = %Background
@onready var _logo: TextureRect = %Logo
@onready var _buttons: HBoxContainer = %Buttons
@onready var _continue: TextureButton = %Continue
@onready var _new_game: TextureButton = %NewGame
@onready var _play: TextureButton = %Play
@onready var _settings: TextureButton = %Settings
@onready var _credits: TextureButton = %Credits
@onready var _save_note: Control = %SaveNote
@onready var _lines: VBoxContainer = %Lines


func _ready() -> void:
	GameState.load_save()
	Sfx.play_music("menu")
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_confirm_new)
	_play.pressed.connect(_start_new_game)
	_settings.pressed.connect(func() -> void:
		var d := SettingsDialog.make(true)
		d.closed.connect(_refresh)
		add_child(d))
	_credits.pressed.connect(func() -> void: add_child(CreditsDialog.make()))
	var still := Settings.reduced_motion()
	(%Leaves as CPUParticles2D).emitting = not still
	(%Smoke as CPUParticles2D).emitting = not still
	if not still:
		var drift := create_tween().set_loops()
		drift.tween_property(_bg, "position", _bg.position + Vector2(-24, -8), 14.0).set_trans(Tween.TRANS_SINE)
		drift.tween_property(_bg, "position", _bg.position, 14.0).set_trans(Tween.TRANS_SINE)
		var sway := create_tween().set_loops()
		sway.tween_property(_logo, "rotation_degrees", -0.8, 3.5).set_trans(Tween.TRANS_SINE)
		sway.tween_property(_logo, "rotation_degrees", 0.0, 3.5).set_trans(Tween.TRANS_SINE)
	_logo.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_logo, "modulate:a", 1.0, 0.9)
	t.tween_property(_logo, "position:y", _logo.position.y, 0.9).from(_logo.position.y - 40.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()


## Which buttons show depends on the save (and changes after deleting it in the settings).
func _refresh() -> void:
	GameState.load_save()
	var can_continue := GameState.has_progress()
	_continue.visible = can_continue
	_continue.tooltip_text = "Revisit" if GameState.all_completed() else "Continue"
	_new_game.visible = can_continue
	_play.visible = not can_continue
	_save_note.visible = can_continue
	if can_continue:
		_fill_note()
	var i := 0
	for b: Control in _buttons.get_children():
		if not b.visible:
			continue
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.42).set_delay(0.07 * i)
		i += 1
	(_continue if can_continue else _play).call_deferred("grab_focus")


## "Catatan terakhir": one line per room, the next one marked.
func _fill_note() -> void:
	for c in _lines.get_children():
		c.queue_free()
	var next := GameState.first_incomplete()
	for id: String in Db.room_order:
		var done := GameState.is_completed(id)
		var line := HBoxContainer.new()
		var n := UI.label(("> " if id == next else "") + String(Db.room(id)["name"]), "PaperLabel", 20)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		var state := "clean" if done else ("next" if id == next else "not yet")
		var s := UI.label(state, "PaperDisplayLabel", 17)
		s.add_theme_color_override("font_color", UI.PAPER_DONE if done else UI.PAPER_INK_SOFT)
		line.add_child(s)
		_lines.add_child(line)


func _on_continue() -> void:
	var r := GameState.first_incomplete()
	main.go("Room", {"room": r if r != "" else "living_room"})


func _confirm_new() -> void:
	add_child(ConfirmDialog.make("Start over?", "Your finished rooms will be cleared.", "Clear & start", _start_new_game))


func _start_new_game() -> void:
	GameState.new_game()
	main.go("Story", {"which": "intro"}, 0.9)
