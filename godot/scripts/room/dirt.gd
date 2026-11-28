class_name Dirt
extends Thing
## A dirty spot cleaned by scrubbing with the matching tool.

const PALETTE := {
	"broom": [Color("8d8170"), Color("a59a88"), Color("6f6455")],
	"mop": [Color("5b4a36"), Color("6d5940"), Color("4a3b2b")],
	"cloth": [Color("7a6f60"), Color("948a79"), Color("5f5649"), Color("b0a691")],
	"duster": [Color("bfb8ad"), Color("d8d2c8"), Color("9d968b")],
}

var tool := ""
var effort := 1.0
var remaining := 1.0
var group := ""
var reward: Dictionary = {}
var parent_thing: Thing
var done := false
var _wobble: Tween


func setup_dirt(spec: Dictionary, on: Thing) -> Dirt:
	var s := spec.duplicate()
	s["originAtBase"] = false
	s["layer"] = on.layer_name if on else "ground"
	s["z"] = on.z_level if on else 1
	setup(s)
	tool = String(spec["tool"])
	effort = maxf(1.0, float(spec.get("effort", 120)))
	remaining = effort
	group = String(spec.get("group", ""))
	var rw: Variant = spec.get("reward")
	if rw is Dictionary:
		reward = rw
	parent_thing = on
	if tex_key == "":
		texture = _grime(id, tool, int(round(w)), int(round(h)))
	apply_depth()
	return self


func apply_depth(extra: int = 0) -> void:
	if parent_thing:
		z_index = parent_thing.z_index + 1
		return
	if layer_name == "ground":
		z_index = Z_FLOOR_DIRT
		return
	super(extra)


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
