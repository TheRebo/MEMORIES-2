class_name HandSystem
extends RefCounted
## Empty-hand interaction: hover feedback, dragging items into zones and double-clicking
## objects. Valid zones pulse while a matching item is carried, so the target is never a guess.

const DOUBLE_MS := 380
const PICK_MARGIN := 3.0

var room: RoomScreen
var _dragging: Item
var _hover_item: Item
var _hover_inter: Interactable
var _hover_zone: Zone
var _last_t := -100000
var _last_pos := Vector2.ZERO
var _last_target: Interactable


func _init(r: RoomScreen) -> void:
	room = r


## Left press in the room (not over the HUD, no dialog).
func pointer_down(w: Vector2) -> void:
	var c := room.ctx
	if c.hands_busy() or c.cinematic or _dragging:
		return
	var target := _pick_interact(w)
	var now := Time.get_ticks_msec()
	if target and target == _last_target and now - _last_t < DOUBLE_MS and w.distance_to(_last_pos) < 10.0:
		_last_t = -100000
		if c.blocked():
			c.notify_blocked()
			return
		_interact(target)
		return
	_last_t = now
	_last_pos = w
	_last_target = target
	var item := _pick_item(w)
	if item == null:
		if target:
			Sfx.play("ui_hover", 0.4)
		return
	if c.blocked():
		c.notify_blocked()
		return
	_start_drag(item, w)


func update() -> void:
	var c := room.ctx
	var p := room.pointer_world()
	if _dragging:
		_dragging.drag_to(p)
		var z := _find_zone(p, _dragging)
		if z != _hover_zone:
			if _hover_zone:
				_hover_zone.set_target_state("candidate")
			_hover_zone = z
			if z:
				z.set_target_state("hover")
				Sfx.play("ui_hover", 0.4)
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return
	if c.hands_busy() or c.cinematic or Modal.is_open() or not room.pointer_in_world():
		_set_hover(null, null)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		room.hud.hover_label(room.pointer_screen, "")
		return
	var item := _pick_item(p)
	var inter: Interactable = null if item else _pick_interact(p)
	_set_hover(item, inter)
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP if item else (Input.CURSOR_POINTING_HAND if inter else Input.CURSOR_ARROW))
	var text := ""
	if inter:
		text = "%s: klik 2x" % inter.label_text
	elif item:
		text = item.label_text
	room.hud.hover_label(room.pointer_screen, text)


func _set_hover(item: Item, inter: Interactable) -> void:
	if item != _hover_item:
		if is_instance_valid(_hover_item):
			_hover_item.set_hover(false)
		_hover_item = item
		if item:
			item.set_hover(true)
	if inter != _hover_inter:
		if is_instance_valid(_hover_inter):
			_hover_inter.set_hover(false)
		_hover_inter = inter
		if inter:
			inter.set_hover(true)


func _start_drag(item: Item, w: Vector2) -> void:
	_set_hover(null, null)
	_dragging = item
	room.ctx.dragging = true
	item.begin_drag(w)
	Sfx.play("pickup", 1.0, 120)
	for z: Zone in room.zones:
		if z.can_accept(item):
			z.set_target_state("candidate")


func drop() -> void:
	var item := _dragging
	if item == null:
		return
	_dragging = null
	room.ctx.dragging = false
	var p := room.pointer_world()
	# Released over a HUD panel: the room under it is hidden, so it is not a drop.
	var zone: Zone = _find_zone(p, item) if room.pointer_in_world() else null
	for z: Zone in room.zones:
		z.set_target_state("off")
	_hover_zone = null
	if zone:
		zone.receive(item)
		if item.trash:
			GameState.add_trash(1)
			Sfx.play("trash", 1.0, 80)
		else:
			Sfx.play("drip_bucket" if zone.accepts == "dish" else "drop", 1.0, 80)
		room.fx.puff_at(zone.center(), 5)
		room.ctx.tasks_changed.emit()
	else:
		item.return_home()
		Sfx.play("item_return", 0.6)


func _interact(target: Interactable) -> void:
	var finished := target.interact()
	Sfx.play("interact", 1.0, 80)
	if not finished:
		return
	room.fx.clean_burst(target.center())
	if target.trash:
		GameState.add_trash(1)
		Sfx.play("trash")
	room.ctx.tasks_changed.emit()


func _pick_item(p: Vector2) -> Item:
	var best: Item = null
	for it: Item in room.items:
		if it.done or not it.visible or not it.has_point(p, PICK_MARGIN):
			continue
		if best == null or it.z_index > best.z_index:
			best = it
	return best


func _pick_interact(p: Vector2) -> Interactable:
	var best: Interactable = null
	for it: Interactable in room.interacts:
		if it.done or not it.visible or not it.has_point(p, PICK_MARGIN):
			continue
		if best == null or it.z_index > best.z_index:
			best = it
	return best


func _find_zone(p: Vector2, item: Item) -> Zone:
	var best: Zone = null
	for z: Zone in room.zones:
		# A little forgiveness so drops near the edge still count.
		if not z.can_accept(item) or not z.has_point(p, 6.0):
			continue
		if best == null or z.z_index > best.z_index:
			best = z
	return best


## Cancel a drag (leaving, cutscene, dialog).
func cancel() -> void:
	if _dragging == null:
		return
	_dragging.return_home()
	_dragging = null
	room.ctx.dragging = false
	for z: Zone in room.zones:
		z.set_target_state("off")
