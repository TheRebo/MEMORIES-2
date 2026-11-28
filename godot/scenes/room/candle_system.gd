class_name CandleSystem
extends RefCounted
## Placing candles during a blackout: hold 5 (or the candle slot), release over the floor.

signal burnt_out

const CANDLE := preload("res://scenes/world/candle.tscn")

var room: RoomScreen
var list: Array[Candle] = []
var max_active := 3
var burn_time := 45.0
## Lit radius in room pixels (the room is 512 wide).
var radius := 110.0
var min_y := 70.0
var _source := ""


func _init(r: RoomScreen) -> void:
	room = r


func hold(source: String) -> void:
	var c := room.ctx
	if GameState.count("candle") <= 0 or c.held_tool != "" or c.dragging or c.cinematic:
		return
	_source = source
	c.holding_candle = true
	Sfx.play("pickup", 0.6)
	c.candle_held.emit(true)


func key_up() -> void:
	if _source == "key":
		release()


func pointer_up() -> void:
	if _source == "slot":
		release()


## Put the candle back without placing it (dialog opened, focus lost).
func cancel_hold() -> void:
	if _source == "":
		return
	_source = ""
	room.ctx.holding_candle = false
	room.ctx.candle_held.emit(false)


func release() -> void:
	if _source == "":
		return
	cancel_hold()
	var c := room.ctx
	if not room.pointer_in_world():
		return
	if not c.blackout:
		c.toast.emit("No need for a candle right now.")
		return
	if active_count() >= max_active:
		c.toast.emit("That is enough candles!")
		return
	if not GameState.take_item("candle"):
		return
	var p := room.pointer_world()
	var size: Dictionary = c.def["size"]
	var pos := Vector2(clampf(p.x, 12, float(size["w"]) - 12), clampf(p.y, min_y, float(size["h"]) - 8))
	var cd: Candle = CANDLE.instantiate()
	room.things.add_child(cd)
	cd.setup(pos, burn_time, radius)
	list.append(cd)


func active_count() -> int:
	var n := 0
	for cd in list:
		if is_instance_valid(cd) and cd.alive:
			n += 1
	return n


func is_lit(p: Vector2) -> bool:
	for cd in list:
		if is_instance_valid(cd) and cd.is_lit(p):
			return true
	return false


func update(dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var cd := list[i]
		if not is_instance_valid(cd) or not cd.tick(dt):
			list.remove_at(i)
			burnt_out.emit()


## Lights out at the end of a blackout.
func extinguish_all() -> void:
	for cd in list:
		if is_instance_valid(cd):
			cd.snuff()
	list.clear()
