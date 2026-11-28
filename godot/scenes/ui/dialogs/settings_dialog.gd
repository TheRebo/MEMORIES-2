class_name SettingsDialog
extends Modal
## Volumes, motion, text speed, fullscreen, and (from the menu) deleting the save.

const SCENE_PATH := "res://scenes/ui/dialogs/settings_dialog.tscn"

@export var allow_delete := true

@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _sfx: HSlider = %Sfx
@onready var _motion: CheckBox = %Motion
@onready var _fullscreen: CheckBox = %Fullscreen
@onready var _status: Label = %Status
@onready var _delete: Button = %Delete
@onready var _done: Button = %Done


static func make(delete_allowed: bool) -> SettingsDialog:
	var d: SettingsDialog = (load(SCENE_PATH) as PackedScene).instantiate()
	d.allow_delete = delete_allowed
	return d


func build() -> void:
	_bind_slider(_master, "master")
	_bind_slider(_music, "music")
	_bind_slider(_sfx, "sfx")
	_motion.button_pressed = Settings.screen_shake
	_motion.toggled.connect(func(on: bool) -> void:
		Sfx.ui_click()
		Settings.set_value("screenShake", on))
	for pair: Array in [[%Slow, "slow"], [%Normal, "normal"], [%Fast, "fast"]]:
		var b: Button = pair[0]
		var v := String(pair[1])
		b.button_pressed = Settings.text_speed == v
		b.pressed.connect(func() -> void:
			Settings.set_value("textSpeed", v)
			_mark_speed())
	_mark_speed()
	_fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Sfx.ui_click()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_delete.visible = allow_delete
	_delete.pressed.connect(_ask_delete)
	_done.pressed.connect(close)


## The chosen text speed reads as the primary (amber) plank.
func _mark_speed() -> void:
	for b: Button in [%Slow, %Normal, %Fast]:
		b.theme_type_variation = &"PrimarySmallButton" if b.button_pressed else &"SmallButton"


func _bind_slider(s: HSlider, key: String) -> void:
	var out: Label = s.get_parent().get_node("Value")
	s.value = roundf(float(Settings.get(key)) * 100.0)
	out.text = str(int(s.value))
	s.value_changed.connect(func(v: float) -> void:
		out.text = str(int(v))
		Settings.set_value(key, v / 100.0)
		if key != "music":
			Sfx.play("ui_hover", 0.6, 0.0, 120))


func _ask_delete() -> void:
	get_parent().add_child(ConfirmDialog.make("Hapus data simpanan?",
		"Semua progres ruangan dan level alat akan hilang. Pengaturanmu tetap tersimpan.", "Hapus",
		func() -> void:
			GameState.new_game()
			_status.text = "Data simpanan sudah dihapus."))
