extends Node
## Sound effects (a small player pool, per-key rate limit) and crossfading music.

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_key := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	Settings.changed.connect(_apply_music_volume)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


## Play an effect. volume 0..1, detune in cents (random +/-), min_gap ms between repeats of a key.
func play(key: String, volume: float = 1.0, detune: float = 0.0, min_gap: int = 0) -> void:
	var now := Time.get_ticks_msec()
	if min_gap > 0 and now - int(_last_played.get(key, -100000)) < min_gap:
		return
	_last_played[key] = now
	var s := _stream("res://assets/audio/sfx/%s.wav" % key)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for c in _players:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _players[0]
	p.stream = s
	p.volume_db = linear_to_db(maxf(0.0001, volume * Settings.sfx * Settings.master))
	p.pitch_scale = pow(2.0, randf_range(-detune, detune) / 1200.0) if detune > 0.0 else 1.0
	p.play()


func ui_click() -> void:
	play("ui_click", 0.7, 60.0, 40)


func ui_hover() -> void:
	play("ui_hover", 0.35, 80.0, 60)


func _music_db() -> float:
	return linear_to_db(maxf(0.0001, Settings.music * Settings.master * 0.8))


## Crossfade to a music track (menu, present, flashback, ending). Same key keeps playing.
func play_music(key: String, fade: float = 1.2) -> void:
	if key == _music_key:
		return
	_music_key = key
	var s := _stream("res://assets/audio/music/%s.ogg" % key)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = s
	_music_a.volume_db = -60.0
	_music_a.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(_music_a, "volume_db", _music_db(), fade)
	_music_tween.tween_property(_music_b, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(_music_b.stop)


func stop_music(fade: float = 1.0) -> void:
	_music_key = ""
	var t := create_tween()
	t.tween_property(_music_a, "volume_db", -60.0, fade)
	t.tween_callback(_music_a.stop)


func _apply_music_volume() -> void:
	if _music_a.playing:
		_music_a.volume_db = _music_db()


## Looping ambience (rain, wind). Fades in; stop it with stop_loop().
func loop(key: String, volume: float = 1.0, fade: float = 1.0) -> AudioStreamPlayer:
	var s := _stream("res://assets/audio/sfx/%s.wav" % key)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = -60.0
	# Replaying on finish loops any import setting, so no per-file loop points are needed.
	p.finished.connect(p.play)
	add_child(p)
	p.play()
	p.set_meta("loop", true)
	create_tween().tween_property(p, "volume_db", linear_to_db(maxf(0.0001, volume * Settings.sfx * Settings.master)), fade)
	return p


func stop_loop(p: AudioStreamPlayer, fade: float = 0.5) -> void:
	if p == null or not is_instance_valid(p) or p.is_queued_for_deletion():
		return
	if p.finished.is_connected(p.play):
		p.finished.disconnect(p.play)
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, maxf(0.01, fade))
	t.tween_callback(p.queue_free)


func stop_all_loops() -> void:
	for c in get_children():
		if c is AudioStreamPlayer and c.has_meta("loop"):
			stop_loop(c as AudioStreamPlayer, 0.2)
