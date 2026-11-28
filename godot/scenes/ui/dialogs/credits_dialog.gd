class_name CreditsDialog
extends Modal
## The team, third-party assets and thanks (from data/story.json).

const SCENE_PATH := "res://scenes/ui/dialogs/credits_dialog.tscn"

@onready var _roles: GridContainer = %Roles
@onready var _third_party: VBoxContainer = %ThirdParty
@onready var _thanks: Label = %Thanks


static func make() -> CreditsDialog:
	return (load(SCENE_PATH) as PackedScene).instantiate()


func build() -> void:
	var c: Dictionary = Db.story.get("credits", {})
	for r: Dictionary in c.get("roles", []):
		_roles.add_child(UI.label(String(r["role"]), "DimLabel"))
		_roles.add_child(UI.label(String(r["name"]), "AmberLabel"))
	for t: String in c.get("thirdParty", []):
		_third_party.add_child(UI.label("- " + t, "DimLabel", 18))
	_thanks.text = String(c.get("thanks", ""))
	(%Back as Button).pressed.connect(close)
