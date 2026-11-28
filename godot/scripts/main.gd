extends Node
## Root of the game: holds the current screen and changes screens behind an iris transition,
## like an old film (closes on the centre, opens on the next screen).

const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius : hint_range(0.0, 1.6) = 1.6;
uniform vec2 aspect = vec2(1.7778, 1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p) / length(aspect * 0.5);
	COLOR = vec4(0.051, 0.035, 0.027, step(radius, d));
}
"""

const SCREENS := {
	"Menu": preload("res://scripts/screens/menu.gd"),
	"Story": preload("res://scripts/screens/story.gd"),
	"Room": preload("res://scripts/screens/room.gd"),
	"TitleCard": preload("res://scripts/screens/title_card.gd"),
}

var current: Node
var _iris: ColorRect
var _mat: ShaderMaterial
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var top := CanvasLayer.new()
	top.layer = 100
	add_child(top)
	_iris = ColorRect.new()
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = IRIS_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("radius", 0.0)
	_iris.material = _mat
	top.add_child(_iris)
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
	_mat.set_shader_parameter("radius", r)


func _show(screen: String, args: Dictionary) -> void:
	if current:
		current.queue_free()
	var script: GDScript = SCREENS[screen]
	current = script.new()
	# The router keeps running while paused (for the iris); screens pause with the tree.
	current.process_mode = Node.PROCESS_MODE_PAUSABLE
	current.set("args", args)
	current.set("main", self)
	add_child(current)
	move_child(current, 0)
