## Autoload "Boot": the loading card. A sheet of kraft board with the game's
## name stamped on a taped plaque, a scribbled progress bar and a one-line
## tip. The splash scene shows it, main.gd feeds it progress while the world
## builds (it yields a frame between stages so this card keeps drawing), and
## it peels away when the game is ready.
extends CanvasLayer

const INK := Color(0.12, 0.08, 0.05)
const TIPS := [
	"Every coin you spend is somebody's wage.",
	"Wolves hate bread. Wolves are wrong.",
	"Prices follow the shelves: empty means dear.",
	"Merchants walk the roads. So do wolves. Pick a side.",
	"Guards are paid from the treasury. Be nice to the treasury.",
	"Cardboard is waterproof until it is not.",
	"Press M for the map. Press L when you forget why.",
	"A dodge a day keeps the knockout away.",
	"The Penny Crown has four corners. Someone has been collecting them.",
	"Check the price board at Highmarket before you haul ore.",
]

var active := false
var _target := 0.0
var _shown := 0.0
var _text := "Unfolding the kingdom"
var _tip := ""
var _t := 0.0
var _card: Control
var _fade := 0.0
var _closing := false
var _kraft: Texture2D
var _head: Font
var _body: Font


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.draw.connect(_draw_card)
	add_child(_card)
	_card.visible = false
	_kraft = load("res://assets/splash/kraft.png")
	_head = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_body = load("res://assets/fonts/PatrickHand-Regular.ttf")


## Shows the card. `text` is the line under the plaque.
func begin(text := "Unfolding the kingdom") -> void:
	_text = text
	_tip = TIPS[randi() % TIPS.size()]
	_target = 0.0
	_shown = 0.0
	_closing = false
	_fade = 0.0
	active = true
	_card.modulate.a = 1.0
	_card.visible = true
	set_process(true)


func progress(f: float, text := "") -> void:
	_target = clampf(f, 0.0, 1.0)
	if text != "":
		_text = text


## The world is ready: fill the bar, hold a beat, then peel the card away.
func finish() -> void:
	if not active:
		return
	_target = 1.0
	_text = "Ready"
	_closing = true


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 7.0))
	if _closing and _shown > 0.985:
		_fade += delta / 0.45
		_card.modulate.a = clampf(1.0 - _fade, 0.0, 1.0)
		_card.position = Vector2(0.0, -_fade * _fade * 90.0)
		if _fade >= 1.0:
			active = false
			_card.visible = false
			_card.position = Vector2.ZERO
			_closing = false
	_card.queue_redraw()


func _jitter(i: float, k := 0.0) -> float:
	return sin(i * 12.9898 + k * 78.233) * 0.5 + sin(i * 4.1 + k * 1.7) * 0.5


func _draw_card() -> void:
	var vs := _card.size
	var c := _card
	# the board, covering the screen
	if _kraft != null:
		c.draw_texture_rect(_kraft, Rect2(Vector2.ZERO, vs), false)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.74, 0.55, 0.34))
	var head: Font = _head if _head != null else ThemeDB.fallback_font
	# the plaque
	var w := minf(vs.x * 0.7, 720.0)
	var h := minf(vs.y * 0.3, 210.0)
	var pc := Vector2(vs.x * 0.5, vs.y * 0.40)
	var plaque := CardBox.new(Color(0.88, 0.70, 0.46), 9, 0.0)
	plaque.torn = CardBox.BOTTOM | CardBox.LEFT
	plaque.rip = 10.0
	plaque.cut = 8.0
	plaque.line = 3.0
	plaque.tape = 2
	plaque.shadow = Vector2(6, 9)
	c.draw_style_box(plaque, Rect2(pc - Vector2(w, h) * 0.5, Vector2(w, h)))
	var title := "PENNYFOLD"
	var fs := int(minf(h * 0.62, w * 0.9 / 5.6))
	var tw := head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_set_transform(pc + Vector2(0, fs * 0.2), -0.025, Vector2.ONE)
	c.draw_string(head, Vector2(-tw * 0.5 + 3, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.35))
	c.draw_string(head, Vector2(-tw * 0.5, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the scribbled bar
	var bw := minf(vs.x * 0.6, 560.0)
	var bh := 30.0
	var bar := Rect2(Vector2(vs.x * 0.5 - bw * 0.5, vs.y * 0.64), Vector2(bw, bh))
	# a pencil underline for the track, marker hatching for the progress
	for pass_i in 2:
		var ul := PackedVector2Array()
		for k in 18:
			var f := float(k) / 17.0
			ul.append(Vector2(lerpf(bar.position.x, bar.end.x, f), bar.end.y + 3.0 + pass_i * 1.5 + _jitter(k, pass_i) * 1.0))
		c.draw_polyline(ul, Color(0.2, 0.12, 0.06, 0.75 - pass_i * 0.3), 2.0, true)
	var x1 := bar.position.x + maxf(12.0, bar.size.x * _shown)
	var xx := bar.position.x
	var i := 0
	while xx < x1:
		var j1 := _jitter(i)
		var j2 := _jitter(i, 3.0)
		var a := Vector2(xx + j1, bar.end.y + 1.0 + (j2 * 0.5 + 0.5) * 2.0)
		var b := Vector2(minf(xx + bar.size.y * 0.55 * (1.0 + j2 * 0.3), x1 + 2.0), bar.position.y - 1.0 - (j1 * 0.5 + 0.5) * 2.0)
		c.draw_line(a, b, Color(0.12, 0.08, 0.05, 0.93), 4.6, true)
		c.draw_circle(a, 2.2, Color(0.12, 0.08, 0.05, 0.93))
		c.draw_circle(b, 2.2, Color(0.12, 0.08, 0.05, 0.93))
		xx += 4.2 * (0.75 + 0.5 * (j1 * 0.5 + 0.5))
		i += 1
	# status and tip, in ink on the board
	var body: Font = _body if _body != null else ThemeDB.fallback_font
	var dots := ".".repeat(int(_t * 2.5) % 4)
	var status := _text + (dots if not _closing else "")
	var sw := head.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(head, Vector2(vs.x * 0.5 - sw * 0.5, bar.end.y + 40.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	var tipw := body.get_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	c.draw_string(body, Vector2(vs.x * 0.5 - tipw * 0.5, bar.end.y + 78.0), _tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.12, 0.08, 0.05, 0.75))
	# the studio mark
	var mark := "CRITBOX"
	var mw := head.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	c.draw_string(head, Vector2(vs.x * 0.5 - mw * 0.5, vs.y - 26.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.12, 0.08, 0.05, 0.6))


## A loose pen outline round the bar.
func _pill(c: Control, r: Rect2) -> void:
	var rad := r.size.y * 0.5
	for pass_i in 2:
		var pts := PackedVector2Array()
		var n := 34
		for k in n + 1:
			var f := float(k) / float(n)
			var ang := TAU * f * 0.97 - PI * 0.5 + float(pass_i) * 0.04
			var dir := Vector2(cos(ang), sin(ang))
			var side := signf(dir.x) if absf(dir.x) > 0.001 else 1.0
			var p := r.get_center() + Vector2(side * (r.size.x * 0.5 - rad), 0) + dir * rad
			pts.append(p + Vector2(_jitter(k, pass_i), _jitter(k + 3.0, pass_i + 2.0)) * 0.8)
		c.draw_polyline(pts, Color(0.2, 0.12, 0.06, 0.8 if pass_i == 0 else 0.4), 2.2, true)
