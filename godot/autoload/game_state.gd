extends Node
## Persistent progress (user://save.json). Rooms save when completed; an unfinished room
## starts over on the next visit, exactly like the web build.

signal inventory_changed
signal trash_changed(total: int)
signal tool_level_changed(tool: String, level: int, leveled_up: bool)
signal room_completed(room: String)

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func _blank() -> Dictionary:
	return {"version": 3, "progress": {}, "inventory": {}, "toolCounts": {}, "trashTotal": 0,
		"tutorialSeen": false, "seenTutorials": [], "bestTimes": {}}


## Reload from disk, dropping anything earned in a room that was left unfinished.
func load_save() -> void:
	data = _blank()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if not raw is Dictionary:
		return
	var d: Dictionary = raw
	for key: String in ["progress", "inventory", "toolCounts", "bestTimes"]:
		if d.get(key) is Dictionary:
			data[key] = d[key]
	data["trashTotal"] = maxi(0, int(d.get("trashTotal", 0)))
	data["tutorialSeen"] = bool(d.get("tutorialSeen", false))
	if d.get("seenTutorials") is Array:
		data["seenTutorials"] = d["seenTutorials"]


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func new_game() -> void:
	data = _blank()
	save()


# ---------- Rooms ----------
func progress(room: String) -> float:
	return float((data["progress"] as Dictionary).get(room, 0))


## Live progress while playing, capped below 100 until the room is formally completed.
func set_progress(room: String, pct: float) -> void:
	if is_completed(room):
		return
	data["progress"][room] = clampf(pct, 0.0, 99.0)


func is_completed(room: String) -> bool:
	return progress(room) >= 100.0


func complete_room(room: String) -> void:
	data["progress"][room] = 100
	save()
	room_completed.emit(room)


func has_progress() -> bool:
	for r: String in Db.room_order:
		if is_completed(r):
			return true
	return false


func all_completed() -> bool:
	for r: String in Db.room_order:
		if not is_completed(r):
			return false
	return true


func first_incomplete() -> String:
	for r: String in Db.room_order:
		if not is_completed(r):
			return r
	return ""


func best_time(room: String) -> float:
	return float((data["bestTimes"] as Dictionary).get(room, -1.0))


## Records a finish time; true if it beats the previous best.
func record_time(room: String, seconds: float) -> bool:
	var prev := best_time(room)
	if prev >= 0.0 and prev <= seconds:
		return false
	data["bestTimes"][room] = roundi(seconds)
	save()
	return true


# ---------- Inventory ----------
func count(item: String) -> int:
	return int((data["inventory"] as Dictionary).get(item, 0))


func add_item(item: String, amount: int = 1) -> void:
	data["inventory"][item] = count(item) + amount
	inventory_changed.emit()


func take_item(item: String, amount: int = 1) -> bool:
	if count(item) < amount:
		return false
	data["inventory"][item] = count(item) - amount
	inventory_changed.emit()
	return true


# ---------- Trash ----------
func trash_total() -> int:
	return int(data["trashTotal"])


func add_trash(delta: int) -> void:
	data["trashTotal"] = maxi(0, trash_total() + delta)
	trash_changed.emit(trash_total())


# ---------- Tools ----------
func level_for_count(n: int) -> int:
	var lv: Dictionary = Db.game.get("tool_levels", {})
	var per := int(lv.get("cleansPerLevel", 9))
	var max_level := int(lv.get("maxLevel", 5))
	var level := 1
	var remaining := n
	while level < max_level and remaining >= per * level:
		remaining -= per * level
		level += 1
	return level


func tool_level(tool: String) -> int:
	return level_for_count(int((data["toolCounts"] as Dictionary).get(tool, 0)))


func add_tool_clean(tool: String) -> void:
	var before := tool_level(tool)
	data["toolCounts"][tool] = int((data["toolCounts"] as Dictionary).get(tool, 0)) + 1
	var after := tool_level(tool)
	tool_level_changed.emit(tool, after, after > before)


# ---------- Tutorials ----------
func tutorial_seen() -> bool:
	return bool(data["tutorialSeen"])


func mark_tutorial_seen() -> void:
	data["tutorialSeen"] = true


func has_seen(id: String) -> bool:
	return (data["seenTutorials"] as Array).has(id)


func mark_seen(id: String) -> void:
	if not has_seen(id):
		(data["seenTutorials"] as Array).append(id)
