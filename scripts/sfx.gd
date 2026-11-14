## Sound effects (autoload "Sfx"). A small pool of players; each sound name
## is a group of variants, one picked at random with a little pitch jitter so
## repeats do not sound mechanical. Sources: see CREDITS.md.
extends Node

const DIR := "res://assets/sfx/"
## name -> [files, volume dB, pitch jitter]
const GROUPS := {
	"coin": [["coin", "handleCoins", "handleCoins2"], -6.0, 0.08],
	"hit": [["hit", "impact", "chop"], -4.0, 0.12],
	"hurt": [["hurt"], -5.0, 0.06],
	"boom": [["boom", "slam"], -5.0, 0.08],
	"swing": [["fx_swing1", "fx_swing2", "fx_swing3"], -9.0, 0.12],
	"fire": [["fx_fire_launch1", "fx_fire_launch2", "fx_fire_launch3"], -6.0, 0.08],
	"fire_hit": [["fx_fire_hit1", "fx_fire_hit2", "fx_fire_hit3"], -5.0, 0.08],
	"ice": [["fx_ice_launch1", "fx_ice_launch2", "fx_ice_launch3"], -6.0, 0.08],
	"ice_hit": [["fx_ice_hit1", "fx_ice_hit2", "fx_ice_hit3"], -5.0, 0.08],
	"zap": [["fx_zap_launch1", "fx_zap_launch2", "fx_zap_launch3"], -6.0, 0.06],
	"zap_hit": [["fx_zap_hit1", "fx_zap_hit2", "fx_zap_hit3"], -6.0, 0.06],
	"heal": [["fx_heal1", "fx_heal2"], -5.0, 0.04],
	"shield": [["fx_shield1", "fx_shield2"], -6.0, 0.04],
	"summon": [["fx_summon"], -5.0, 0.04],
	"vanish": [["fx_vanish"], -6.0, 0.04],
	"charge": [["fx_charge"], -8.0, 0.04],
	"blade": [["fx_sword_hit1", "fx_sword_hit2", "fx_sword_hit3"], -6.0, 0.1],
	"jump": [["soft_pop2", "soft_pop3"], -9.0, 0.18],
	"land": [["land", "slam_light"], -10.0, 0.1],
	"step": [["footstep00", "footstep01", "footstep02", "footstep03", "footstep04"], -20.0, 0.1],
	"pop": [["soft_pop1", "soft_pop2", "soft_pop3"], -8.0, 0.12],
	"beam": [["chime_up"], -8.0, 0.05],
	"shatter": [["shatter", "wood_snap"], -6.0, 0.08],
	"quest": [["fanfare"], -6.0, 0.0],
	"good": [["good_pluck"], -7.0, 0.05],
	"bad": [["bad_pluck"], -7.0, 0.05],
	"open": [["paper_open", "bookFlip1"], -6.0, 0.06],
	"close": [["paper_close", "bookFlip2"], -7.0, 0.06],
	"click": [["ui_click-a", "ui_tap-a"], -8.0, 0.05],
	"tick": [["soft_tick", "ui_switch-a"], -12.0, 0.05],
	"door": [["doorOpen_1", "creak1"], -9.0, 0.06],
	"cloth": [["cloth1", "cloth2"], -12.0, 0.1],
	"rip": [["paper_open", "paper_whoosh", "bookFlip1"], 2.0, 0.3],
}
const VOICES := 12

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}


func _ready() -> void:
	for name in GROUPS:
		var list: Array[AudioStream] = []
		for f in GROUPS[name][0]:
			var s: AudioStream = load(DIR + f + ".ogg")
			if s != null:
				list.append(s)
		_streams[name] = list
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Where the player (the ears) is, in world units. Main keeps it current.
var listener := Vector3.ZERO
## Sounds from further than this are not played at all; closer ones fade.
const HEAR := 16.0


## A sound that happens somewhere in the world: silent when far, quieter when
## not near. Use this for anything an NPC or monster does.
func play_at(name: String, pos: Vector3, volume := 0.0, min_gap := 0.03) -> void:
	var d := Vector2(pos.x - listener.x, pos.z - listener.z).length()
	if d > HEAR:
		return
	play(name, volume - 14.0 * clampf(d / HEAR, 0.0, 1.0), min_gap)


## Plays a sound by group name. volume adds dB; min_gap (seconds) drops a
## repeat of the same sound that comes too soon (footsteps, rapid hits).
func play(name: String, volume := 0.0, min_gap := 0.03) -> void:
	var list: Array = _streams.get(name, [])
	if list.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -9.0)) < min_gap:
		return
	_last[name] = now
	var g: Array = GROUPS[name]
	var p := _free_player()
	p.stream = list[randi() % list.size()]
	p.volume_db = float(g[1]) + volume
	p.pitch_scale = 1.0 + randf_range(-g[2], g[2])
	p.play()


func _free_player() -> AudioStreamPlayer:
	for i in VOICES:
		var p := _players[(_next + i) % VOICES]
		if not p.playing:
			_next = (_next + i + 1) % VOICES
			return p
	# all busy: steal the oldest
	var p2 := _players[_next]
	_next = (_next + 1) % VOICES
	return p2
