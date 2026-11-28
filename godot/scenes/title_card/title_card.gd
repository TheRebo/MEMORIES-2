extends Control
## The end: logo on the team's olive background, a thank-you, then back to the menu.

var args: Dictionary = {}
var main: Node


func _ready() -> void:
	(%Thanks as Label).text = String((Db.story.get("credits", {}) as Dictionary).get("thanks", ""))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.6)
	await get_tree().create_timer(6.0).timeout
	if is_inside_tree():
		main.go("Menu", {}, 1.2)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if (mb != null and mb.pressed) or event.is_action_pressed("ui_accept"):
		main.go("Menu", {}, 1.2)
