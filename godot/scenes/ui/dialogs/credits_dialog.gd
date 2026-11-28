class_name CreditsDialog
extends Modal
## The team and a thank-you line (from data/story.json).

const SCENE_PATH := "res://scenes/ui/dialogs/credits_dialog.tscn"

@onready var _team: VBoxContainer = %Team
@onready var _thanks: Label = %Thanks


static func make() -> CreditsDialog:
	return (load(SCENE_PATH) as PackedScene).instantiate()


func build() -> void:
	var c: Dictionary = Db.story.get("credits", {})
	for n: String in c.get("team", []):
		var l := UI.label(n, "AmberLabel", 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_team.add_child(l)
	_thanks.text = String(c.get("thanks", ""))
	(%Back as Button).pressed.connect(close)
