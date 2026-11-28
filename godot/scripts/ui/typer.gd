class_name Typer
extends Label
## Typewriter text: reveals characters at a speed, a soft tick every few letters.

signal finished_typing

var running := false
var _shown := 0.0
var _cps := 48.0


func _init() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


func start(t: String, cps: float) -> void:
	text = t
	_cps = cps
	_shown = 0.0
	visible_characters = 0
	running = true


func finish() -> void:
	if not running:
		return
	running = false
	visible_characters = -1
	finished_typing.emit()


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	var before := int(_shown)
	_shown += _cps * delta
	visible_characters = int(_shown)
	if int(_shown) / 3 != before / 3:
		Sfx.play("type_tick", 0.25, 60.0, 45)
	if int(_shown) >= text.length():
		finish()
