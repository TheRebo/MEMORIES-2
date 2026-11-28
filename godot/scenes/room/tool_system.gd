class_name ToolSystem
extends RefCounted
## Holding and using cleaning tools.
## - Hold 1-4, or hold a slot: the tool stays in hand until released.
## - Tap a slot (or Enter on it): it stays in hand until tapped again, Esc or right-click,
##   which keeps the game playable on touch screens and trackpads.

const TAP_MS := 220

var room: RoomScreen
var working := false
var _last := Vector2.ZERO
var _slot_down_at := 0
var _slot_down_pos := Vector2.ZERO
var _fresh := false
var _last_dark := -100000
var _last_wrong := -100000
var _smeared := false


func _init(r: RoomScreen) -> void:
	room = r


func ctx() -> RoomCtx:
	return room.ctx


func key_down(tool: String) -> void:
	pick(tool, "key")


func key_up(tool: String) -> void:
	if ctx().held_tool == tool and ctx().held_source == "key":
		release()


func slot_down(tool: String) -> void:
	if ctx().cinematic:
		return
	if ctx().held_source == "toggle" and ctx().held_tool == tool:
		release()
		return
	_slot_down_at = Time.get_ticks_msec()
	_slot_down_pos = room.pointer_screen
	pick(tool, "slot")


func slot_activate(tool: String) -> void:
	if ctx().held_tool == tool:
		release()
	else:
		pick(tool, "toggle")


## Any left button release: a quick tap on a slot makes the tool sticky, a long hold drops it.
func pointer_up(p: Vector2) -> void:
	if ctx().held_source != "slot":
		return
	var quick := Time.get_ticks_msec() - _slot_down_at < TAP_MS and p.distance_to(_slot_down_pos) < 12.0
	if quick:
		ctx().held_source = "toggle"
		_emit()
	else:
		release()


## A new press starts a fresh stroke: jumping to another spot is not scrubbing.
func pointer_down() -> void:
	_fresh = true


func right_click() -> bool:
	if ctx().held_source == "toggle":
		release()
		return true
	return false


## Esc with a sticky tool puts it down instead of pausing.
func release_sticky() -> bool:
	if ctx().held_source != "toggle":
		return false
	release()
	return true


func pick(tool: String, source: String) -> void:
	if ctx().holding_candle or ctx().dragging:
		return
	ctx().held_tool = tool
	ctx().held_source = source
	_last = room.pointer_screen
	Sfx.play("pickup", 0.6, 80)
	_emit()


func release() -> void:
	if ctx().held_tool == "":
		return
	ctx().held_tool = ""
	ctx().held_source = ""
	working = false
	Sfx.play("tool_drop", 0.5)
	_emit()


func _emit() -> void:
	ctx().tool_changed.emit(ctx().held_tool, ctx().held_source)


func speed_of(tool: String) -> float:
	return 1.0 + (GameState.tool_level(tool) - 1) * float(Db.game["tool_levels"]["speedBonusPerLevel"])


static func tint_of(tool: String) -> Color:
	var v := int(Db.tool_info(tool).get("tint", 0xffffff))
	return Color.hex((v << 8) | 0xff)


func update() -> void:
	var c := ctx()
	var tool := c.held_tool
	var p := room.pointer_screen
	var moved := 0.0 if _fresh else p.distance_to(_last)
	_fresh = false
	_last = p
	working = false
	if tool == "" or c.cinematic or Modal.is_open() or moved < 1.0 or not room.pointer_in_world():
		return
	if c.blocked():
		c.notify_blocked()
		return
	var w := room.pointer_world()
	var level := GameState.tool_level(tool)
	var radius := 3.0 + (level - 1) * 0.6
	var amount := minf(moved / 3.0, 20.0) * 3.0 * speed_of(tool)
	var wrong: Dirt = null
	var order: Dirt = null
	var now := Time.get_ticks_msec()
	for d: Dirt in room.dirt.duplicate():
		if d.done or not d.visible or not d.has_point(w, radius):
			continue
		if c.blackout and not room.candles.is_lit(w):
			if now - _last_dark > 2500:
				_last_dark = now
				c.toast.emit("Too dark! Place a candle first.")
			continue
		# Work order: the dust on top goes first (sweep before mopping, dust before wiping).
		if d.tool == tool:
			var blocker := room.blocker_of(d)
			if blocker:
				order = blocker
				continue
		var r := d.scrub(tool, amount)
		if r == "wrong-tool":
			wrong = d
			# Rubbing with the wrong tool spreads the grime a little.
			if d.smear(amount * 0.35):
				_smeared = true
			continue
		if r == "none":
			continue
		working = true
		if r == "cleaned":
			_on_cleaned(d)
	if working:
		room.fx.scrub_at(w, tint_of(tool))
		Sfx.play(String(Db.tool_info(tool).get("sfx", "")), 0.55, 120, 170)
	elif order and now - _last_wrong > 1400:
		_last_wrong = now
		order.nudge()
		Sfx.play("wrong_tool", 0.5)
		c.hint.emit(p, "Sweep the dust first!" if order.tool == "broom" else "Dust it with the Duster first!")
	elif wrong and now - _last_wrong > 1400:
		_last_wrong = now
		wrong.nudge()
		Sfx.play("wrong_tool", 0.6)
		var spread := " The grime spread!" if _smeared else ""
		c.hint.emit(p, "Needs: %s.%s" % [Db.tool_info(wrong.tool).get("name", ""), spread])
		_smeared = false


func _on_cleaned(d: Dirt) -> void:
	room.fx.clean_burst(d.center())
	Sfx.play("clean_done", 0.7, 100)
	GameState.add_tool_clean(d.tool)
	if not d.reward.is_empty():
		GameState.add_item(String(d.reward["item"]), int(d.reward.get("amount", 1)))
		Sfx.play("reward", 0.8)
		var msg := String(d.reward.get("message", ""))
		ctx().toast.emit(msg if msg != "" else "You found %s!" % d.reward["item"])
	ctx().tasks_changed.emit()
