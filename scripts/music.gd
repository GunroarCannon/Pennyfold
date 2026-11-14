## Background music (autoload "Music"). One track plays at a time: it fades in,
## plays, fades out near its end, rests for a few seconds of quiet, then the
## next track fades in. Sources: see CREDITS.md.
extends Node

const TRACKS := [
	"res://assets/music/woodland_fantasy.ogg",
	"res://assets/music/happy_flutes.ogg",
]
const FADE_IN := 4.0
const FADE_OUT := 4.0
const GAP := 6.0
## Loudness while a track is in full swing (dB). Effects stay louder than music.
const LEVEL_DB := -14.0

var _player: AudioStreamPlayer
var _streams: Array = []
var _next := 0
var _tween: Tween
var _gap_timer: Timer
var enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in TRACKS:
		var s: AudioStream = load(p)
		if s != null:
			_streams.append(s)
	if _streams.is_empty() or DisplayServer.get_name() == "headless":
		return
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	add_child(_player)
	_gap_timer = Timer.new()
	_gap_timer.one_shot = true
	_gap_timer.timeout.connect(_play_next)
	add_child(_gap_timer)
	_gap_timer.start(1.5)


func set_enabled(on: bool) -> void:
	enabled = on
	if _player == null:
		return
	if on:
		if not _player.playing and _gap_timer.is_stopped():
			_play_next()
	else:
		if _tween != null:
			_tween.kill()
		_gap_timer.stop()
		_player.stop()


func _play_next() -> void:
	if not enabled or _streams.is_empty():
		return
	var s: AudioStream = _streams[_next % _streams.size()]
	_next += 1
	_player.stream = s
	_player.volume_db = -60.0
	_player.play()
	var len := s.get_length()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", LEVEL_DB, FADE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(maxf(0.0, len - FADE_IN - FADE_OUT))
	_tween.tween_property(_player, "volume_db", -60.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		_player.stop()
		_gap_timer.start(GAP))
