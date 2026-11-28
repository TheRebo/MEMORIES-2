class_name PauseDialog
extends Modal
## Pause: lettered CONTINUE / SETTING / QUIT art plus a plank button for the tutorial.

const SCENE_PATH := "res://scenes/ui/dialogs/pause_dialog.tscn"

var room_name := ""
var percent := 0
var room_saved := false
var on_tutorial := Callable()
var on_main_menu := Callable()

@onready var _room_name: Label = %RoomName
@onready var _percent: Label = %Percent
@onready var _note: Label = %Note


static func make(name_text: String, pct: int, saved: bool, tutorial_fn: Callable, menu_fn: Callable) -> PauseDialog:
	var d: PauseDialog = (load(SCENE_PATH) as PackedScene).instantiate()
	d.room_name = name_text
	d.percent = pct
	d.room_saved = saved
	d.on_tutorial = tutorial_fn
	d.on_main_menu = menu_fn
	return d


func build() -> void:
	_room_name.text = room_name
	_percent.text = "%d%% bersih" % percent
	_note.visible = not room_saved
	(%Continue as BaseButton).pressed.connect(close)
	(%Settings as BaseButton).pressed.connect(func() -> void: get_parent().add_child(SettingsDialog.make(false)))
	(%Tutorial as BaseButton).pressed.connect(func() -> void:
		close()
		on_tutorial.call())
	(%Quit as BaseButton).pressed.connect(_leave)


func _leave() -> void:
	if room_saved:
		close()
		on_main_menu.call()
		return
	get_parent().add_child(ConfirmDialog.make("Kembali ke menu?",
		"Ruangan ini belum selesai, jadi progresnya akan diulang dari awal.", "Ke menu",
		func() -> void:
			close()
			on_main_menu.call()))
