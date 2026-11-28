extends Node
## Read-only game data exported from the web build (tools/export_godot_data.mts):
## rooms, sprite manifest, story slides, tools, audio keys and tuning.

var rooms: Dictionary = {}
var room_order: Array = []
var sprites: Dictionary = {}
var named: Dictionary = {}
var story: Dictionary = {}
var game: Dictionary = {}
var _tex_cache: Dictionary = {}


func _ready() -> void:
	var r: Dictionary = _load("res://data/rooms.json")
	rooms = r.get("rooms", {})
	room_order = r.get("order", [])
	var s: Dictionary = _load("res://data/sprites.json")
	sprites = s.get("sprites", {})
	named = s.get("named", {})
	story = _load("res://data/story.json")
	game = _load("res://data/game.json")


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Story text with {mc} replaced by the main character's name (story.json "mcName").
func say(text: String) -> String:
	return text.replace("{mc}", String(story.get("mcName", "aku")))


func room(id: String) -> Dictionary:
	return rooms.get(id, {})


func next_room(id: String) -> String:
	var i := room_order.find(id)
	if i < 0 or i + 1 >= room_order.size():
		return ""
	return String(room_order[i + 1])


func sprite_info(key: String) -> Dictionary:
	return sprites.get(key, {})


## Texture for a sprite key from the manifest (assets/sprites/...), or any asset path.
func tex(key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path := ""
	if sprites.has(key):
		path = "res://assets/" + String(sprites[key]["file"])
	elif key.begins_with("res://"):
		path = key
	else:
		path = "res://assets/" + key
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null:
		push_warning("Missing texture %s" % path)
	_tex_cache[key] = t
	return t


## Visible-pixel box [x, y, w, h] inside a sprite.
func bbox(key: String) -> Rect2:
	var info := sprite_info(key)
	if info.is_empty():
		return Rect2()
	var b: Array = info["bbox"]
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))


func tool_info(id: String) -> Dictionary:
	for t: Dictionary in game.get("tools", []):
		if t["id"] == id:
			return t
	return {}


func star_par(room_id: String) -> float:
	var par: Dictionary = game.get("star_par", {})
	return float(par.get(room_id, 480))


static func stars_for(par: float, seconds: float) -> int:
	if seconds <= par:
		return 3
	if seconds <= par * 1.5:
		return 2
	return 1


static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
