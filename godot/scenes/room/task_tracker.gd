class_name TaskTracker
extends RefCounted
## Counts tasks by group. Events add tasks (new puddles) or undo them (scattered items),
## so progress is recomputed from the live list rather than incremented.

var tasks: Array = []
var _finished: Dictionary = {}


func add(t: Object) -> void:
	if String(t.get("group")) != "" and not tasks.has(t):
		tasks.append(t)


## [{name, done, total}] in first-seen order.
func groups() -> Array:
	var order: Array = []
	var map: Dictionary = {}
	for t: Object in tasks:
		var g := String(t.get("group"))
		if not map.has(g):
			map[g] = {"name": g, "done": 0, "total": 0}
			order.append(g)
		map[g]["total"] += 1
		if bool(t.get("done")):
			map[g]["done"] += 1
	var out: Array = []
	for g: String in order:
		out.append(map[g])
	return out


func percent() -> float:
	if tasks.is_empty():
		return 100.0
	var done := 0
	for t: Object in tasks:
		if bool(t.get("done")):
			done += 1
	return 100.0 * done / tasks.size()


func all_done() -> bool:
	for t: Object in tasks:
		if not bool(t.get("done")):
			return false
	return not tasks.is_empty()


## Groups that went from unfinished to finished since the last call.
func newly_finished() -> Array:
	var out: Array = []
	var nxt: Dictionary = {}
	for g: Dictionary in groups():
		var fin: bool = g["done"] >= g["total"]
		if fin and _finished.get(g["name"], true) == false:
			out.append(g["name"])
		nxt[g["name"]] = fin
	_finished = nxt
	return out
