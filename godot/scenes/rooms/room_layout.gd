class_name RoomLayout
extends Node2D
## One room of the house as laid out in the editor: background, furniture (with the dirt on
## it as children), floor dirt, items, their zones, double-click objects, flashback actors and
## the room's events. scenes/room/room.tscn loads it and runs the game on top.

@export var room_id := ""
@export var room_name := ""
## Short name for the room buttons ("R. Keluarga").
@export var short_name := ""
## World size in pixels (the background picture).
@export var room_size := Vector2(512, 352)
## Height of the back wall: dust never settles above it.
@export var wall_height := 64
## Lines of the flashback played once the room is clean. Keys: speaker, text, show, hide,
## moves [{actor, x, y}], focus [x, y], zoom, tint [r, g, b, a], fadeToBlack, hold.
@export var flashback: Array[Dictionary] = []


## The parts of the layout, by kind.
func things_of(container: String) -> Array:
	var n := get_node_or_null(container)
	return n.get_children() if n else []


## Every dirty spot: on the floor and on any piece of furniture.
func all_dirt() -> Array:
	var out: Array = []
	_collect_dirt(self, out)
	return out


func _collect_dirt(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Dirt:
			out.append(c)
		_collect_dirt(c, out)
