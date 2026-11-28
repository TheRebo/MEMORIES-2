@tool
class_name Dirt
extends Thing
## A dirty spot cleaned by scrubbing with the matching tool. On furniture it is a child of that
## Thing (it moves with it in the editor); on the floor it lies in the layout's FloorDirt.

const PALETTE := {
	"broom": [Color("8d8170"), Color("a59a88"), Color("6f6455")],
	"mop": [Color("5b4a36"), Color("6d5940"), Color("4a3b2b")],
	"cloth": [Color("7a6f60"), Color("948a79"), Color("5f5649"), Color("b0a691")],
	"duster": [Color("bfb8ad"), Color("d8d2c8"), Color("9d968b")],
}

@export_enum("broom", "mop", "cloth", "duster") var tool := "broom":
	set(v):
		tool = v
		if is_inside_tree():
			_regrime()
## How much scrubbing it takes.
@export var effort := 120.0
## Task group on the note ("Lap jendela").
@export var group := ""
## Found while cleaning (a candle in a drawer): item id, amount and message.
@export var reward_item := ""
@export var reward_amount := 1
@export var reward_message := ""

var remaining := 1.0
var parent_thing: Thing
var done := false
var reward: Dictionary = {}
var _wobble: Tween
var _grimy := false


func _ready() -> void:
	origin_at_base = false
	parent_thing = get_parent() as Thing
	if parent_thing:
		layer_name = parent_thing.layer_name
		z_level = parent_thing.z_level
	else:
		layer_name = "ground"
	if texture == null:
		_regrime()
	super()
	remaining = maxf(1.0, effort)
	if reward_item != "":
		reward = {"item": reward_item, "amount": reward_amount, "message": reward_message}


## Dirt made at runtime (events, dust settling again). `on`: furniture it sits on, or null.
static func spawn(scene: PackedScene, spec: Dictionary, on: Thing, floor_node: Node) -> Dirt:
	var d: Dirt = scene.instantiate()
	d.object_id = String(spec.get("id", ""))
	d.tool = String(spec.get("tool", "broom"))
	d.effort = float(spec.get("effort", 120))
	d.group = String(spec.get("group", ""))
	d.area_size = Vector2(float(spec.get("w", 16)), float(spec.get("h", 10)))
	d.rotation = float(spec.get("rotation", 0.0))
	var tex := String(spec.get("tex", ""))
	if tex != "":
		d.texture = Db.tex(tex)
	var world := Vector2(float(spec["x"]), float(spec["y"]))
	if on:
		# Cancel the furniture's scale: grime keeps its own pixel size.
		d.scale = Vector2.ONE / on.scale
		on.add_child(d)
		d.global_position = world
	else:
		floor_node.add_child(d)
		d.global_position = world
	return d


func _regrime() -> void:
	if texture != null and not _grimy:
		return
	_grimy = true
	texture = _grime(object_id, tool, int(round(area_size.x)), int(round(area_size.y)))


func apply_depth(_extra: int = 0) -> void:
	if parent_thing:
		# Just above the furniture it is on.
		z_as_relative = true
		z_index = 1
		return
	z_as_relative = false
	z_index = Z_FLOOR_DIRT


## Scrub with `t` for `amount`. Returns "cleaned", "progress", "wrong-tool" or "none".
func scrub(t: String, amount: float) -> String:
	if done:
		return "none"
	if t != tool:
		return "wrong-tool"
	remaining = maxf(0.0, remaining - amount)
	modulate.a = 0.18 + 0.82 * (remaining / effort)
	if _wobble == null or not _wobble.is_running():
		_wobble = create_tween()
		_wobble.tween_property(self, "scale:x", base_scale.x * 1.06, 0.06)
		_wobble.tween_property(self, "scale:x", base_scale.x, 0.06)
	if remaining <= 0.0:
		done = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.22)
		tw.tween_property(self, "scale", base_scale * 1.25, 0.22)
		tw.chain().tween_callback(hide)
		return "cleaned"
	return "progress"


## Wrong tool: the grime spreads back by `amount`. True if it got worse.
func smear(amount: float) -> bool:
	if done or remaining >= effort:
		return false
	remaining = minf(effort, remaining + amount)
	modulate.a = 0.18 + 0.82 * (remaining / effort)
	return true


## Undo a cleaned spot (wind blew dust back): `amount` of the effort comes back.
func dirty_again(amount: float) -> void:
	if not done:
		remaining = minf(effort, remaining + effort * amount)
		modulate.a = 0.18 + 0.82 * (remaining / effort)
		return
	done = false
	remaining = effort * clampf(amount, 0.1, 1.0)
	scale = base_scale * 0.4
	modulate.a = 0.0
	show()
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", base_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.18 + 0.82 * (remaining / effort), 0.3)


func restore_done() -> void:
	done = true
	remaining = 0.0
	hide()


func nudge() -> void:
	var x0 := position.x
	var t := create_tween().set_loops(2)
	t.tween_property(self, "position:x", x0 + 1.5, 0.04)
	t.tween_property(self, "position:x", x0, 0.04)


static func _hash(s: String) -> int:
	var hv := 2166136261
	for i in s.length():
		hv = (hv ^ s.unicode_at(i)) * 16777619 & 0xffffffff
	return hv


## Pixel grime for spots without drawn art; deterministic per spot id.
static func _grime(spot: String, t: String, gw: int, gh: int) -> Texture2D:
	var img_w := maxi(4, gw)
	var img_h := maxi(3, gh)
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(spot)
	var pal: Array = PALETTE.get(t, PALETTE["cloth"])
	if t == "duster":
		for x in img_w:
			var depth := 1 + rng.randi_range(0, mini(3, img_h) - 1)
			for y in depth:
				img.set_pixel(x, y, pal[rng.randi_range(0, pal.size() - 1)])
			if rng.randf() < 0.12:
				for y in range(depth, mini(img_h, depth + rng.randi_range(1, 4))):
					img.set_pixel(x, y, pal[2])
	else:
		var cx := img_w / 2.0
		var cy := img_h / 2.0
		for y in img_h:
			for x in img_w:
				var dx := (x - cx) / cx
				var dy := (y - cy) / cy
				var d := dx * dx + dy * dy
				var density := 0.55 if t == "cloth" else 0.7
				if d < 1.0 and rng.randf() < density * (1.0 - d * 0.6):
					var c: Color = pal[rng.randi_range(0, pal.size() - 1)]
					c.a = 0.85
					img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
