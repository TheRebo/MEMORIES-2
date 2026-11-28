extends Node
## Root of the game: holds the current screen and changes screens behind an iris transition,
## like an old film (closes on the centre, opens on the next screen).

const SCREENS := {
	"Menu": preload("res://scenes/menu/menu.tscn"),
	"Story": preload("res://scenes/story/story.tscn"),
	"Room": preload("res://scenes/room/room.tscn"),
	"TitleCard": preload("res://scenes/title_card/title_card.tscn"),
}

var current: Node
var _busy := false

@onready var _holder: Node = %Screen
@onready var _iris: ColorRect = %Iris


func _ready() -> void:
	# The router keeps running while the game is paused, for the iris.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_radius(0.0)
	_show("Menu", {})
	_open(0.5)


## Close the iris, swap the screen, open it again. Ignores re-entry while a switch is running.
func go(screen: String, args: Dictionary = {}, seconds: float = 0.6) -> void:
	if _busy:
		return
	_busy = true
	_iris.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_method(_set_radius, 1.6, 0.0, seconds / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	get_tree().paused = false
	_show(screen, args)
	await get_tree().process_frame
	await _open(seconds / 2.0)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _open(seconds: float) -> void:
	var t := create_tween()
	t.tween_method(_set_radius, 0.0, 1.6, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _set_radius(r: float) -> void:
	(_iris.material as ShaderMaterial).set_shader_parameter("radius", r)


func _show(screen: String, args: Dictionary) -> void:
	if current:
		# Out of the tree at once, so the next screen can take the same name.
		_holder.remove_child(current)
		current.queue_free()
	var packed: PackedScene = SCREENS[screen]
	current = packed.instantiate()
	current.name = screen
	# Screens pause with the tree; only this router keeps running.
	current.process_mode = Node.PROCESS_MODE_PAUSABLE
	current.set("args", args)
	current.set("main", self)
	_holder.add_child(current)
