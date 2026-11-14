## Cardboard UI. Paper panels with an ink border and a drop shadow.
## Always on: status card (health, ink, coins, pack), compass strip with the
## quest pin, clock, minimap, quest tracker, message log, edge pointer to
## the quest target. Panels: title card, shop counter, conversation, world
## map with fast travel, quest board and quest log, town ledger with the
## NEAR settlement status. Banners for discoveries, fades for travel.
class_name Hud
extends CanvasLayer

const INK := Color(0.17, 0.11, 0.07)
## Kraft board, the main panel colour.
const PAPER := Color(0.84, 0.66, 0.43)
const PAPER_LIGHT := Color(0.94, 0.84, 0.66)
const PAPER_DARK := Color(0.66, 0.48, 0.29)
## White paper, for notes, speech and anything to read.
const NOTE := Color(0.995, 0.98, 0.94)
const GOLD := Color(0.99, 0.78, 0.26)
const MINT := Color(0.60, 0.86, 0.68)
const ROSE := Color(0.96, 0.62, 0.64)
const SKY := Color(0.62, 0.80, 0.97)
## Seconds a log message stays up before its slip fades.
const LOG_SECS := 7.0
## Where the face sits inside the head piece of a front view (fractions of the cell).
const PORTRAIT_BOX := Rect2(0.12, 0.06, 0.76, 0.62)

var head_font: Font
static var head_font_static: Font
var body_font: Font
var _seed := 0
var log_times: Array = []
var keys_panel: Control
var clock_tag: PanelContainer
var prompt_panel: PanelContainer
var _keys_t := 30.0

var main: Node
var shop_id := ""
var root: Control
var coin_label: Label
var hp_g: Gauge
var st_g: Gauge
var ink_g: Gauge
var xp_g: Gauge
var lv_label: Label
var job_label: Label
var coin_delta: Label
var _delta_acc := 0
var _delta_t := 0.0
var _death: PanelContainer
var _death_open := false
var status_card: Control
var medal_face: PortraitFrame
var chain_chip: NearChip
var tutorial: Tutorial
var _tut_started := false
var _title_font: Font
var region_name := ""
var pack_row: HBoxContainer
var clock_label: Label
var log_label: Label
var log_panel: PanelContainer
var menus: HudMenus
var paused: bool:
	get:
		return menus != null and menus.is_paused()
var prompt_label: Label
var keys_label: Label
var tracker: PanelContainer
var tracker_title: Label
var tracker_text: Label
var minimap: RoundMap
var compass: Compass
var overlay: Overlay
var shop_panel: PanelContainer
var dialog_panel: PanelContainer
var map_panel: PanelContainer
var big_map: MapView
var quest_panel: PanelContainer
var ledger_panel: PanelContainer
var ledger_label: Label
var title_panel: Control
var banner_panel: PanelContainer
var banner_title: Label
var banner_sub: Label
var curtain_l: ColorRect
var curtain_r: ColorRect
var rip_fx: RipFx
var touch: TouchControls
var dragon_fx: DragonFx
var _rip_ready := 0
var log_lines: Array = []
var fog: Image
var fog_tex: ImageTexture
var map_tex: ImageTexture
var item_tex := {}
var _ledger_t := 0.0
var _fog_t := 0.0
var _dialog_text: Label
var _dialog_opts: VBoxContainer
var _dialog_name: Label
var _settle_status: Label
var _dialog_choices: Array = []
var _shown_coins := -1
var _pack_sig := ""


func _ready() -> void:
	layer = 5
	var th := Theme.new()
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	body_font = fv
	head_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	head_font_static = head_font
	th.default_font = body_font
	th.default_font_size = 19
	th.set_color("font_color", "Label", INK)
	root = Control.new()
	root.theme = th
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	map_tex = ImageTexture.create_from_image(main.world.map_image)
	fog = Image.create(World.TN.x, World.TN.y, false, Image.FORMAT_RGBA8)
	fog.fill(Color(0.90, 0.80, 0.60, 1.0))
	fog_tex = ImageTexture.create_from_image(fog)

	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	_build_status()
	_build_top()
	_build_log()
	menus = HudMenus.new(self)
	touch = TouchControls.new()
	touch.hud = self
	touch.main = main
	root.add_child(touch)
	_build_shop()
	_build_dialog()
	_build_map()
	_build_quests()
	_build_ledger()
	_build_banner()
	_build_title()
	_build_curtain()
	rip_fx = RipFx.new()
	root.add_child(rip_fx)
	dragon_fx = DragonFx.new()
	root.add_child(dragon_fx)
	Economy.changed.connect(_on_economy)
	Chain.status_changed.connect(_on_economy)


# ---------- styles ----------

## A cut-out card style; each call gets its own snip pattern.
func _style(bg: Color, border := 3, _radius := 6) -> CardBox:
	_seed += 1
	var s := CardBox.new(bg, _seed, 16.0)
	s.line = 2.0
	s.cut = 5.0
	s.shadow = Vector2(2, 3)
	if border < 3:
		s.line = 1.6
		s.cut = 3.0
		s.shadow = Vector2(1, 2)
		s.set_content_margin_all(9)
	return s


## Bar track and fill: plain straight strips without shadow or tape.
func _flat(bg: Color) -> CardBox:
	_seed += 1
	var s := CardBox.new(bg, _seed, 0.0)
	s.cut = 2.0
	s.wobble = 0.3
	s.line = 1.6
	s.torn = 0
	s.tape = 0
	s.shadow = Vector2.ZERO
	s.ply = false
	return s


func _panel(bg := PAPER, tape := -1) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(bg)
	s.tape = tape
	p.add_theme_stylebox_override("panel", s)
	return p


## Buttons are little cards on a hard shadow: hover lifts them, pressing
## sinks them onto the shadow.
func _button(text: String, bg := PAPER_LIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", head_font)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", INK.lightened(0.5))
	var n := _style(bg, 2)
	n.ply = false
	n.content_margin_left = 14
	n.content_margin_right = 14
	n.content_margin_top = 6
	n.content_margin_bottom = 9
	var h := n.tinted(bg.lightened(0.18))
	h.shift = Vector2(-1, -1)
	h.shadow = Vector2(4, 5)
	var pr := n.tinted(bg.darkened(0.1))
	pr.shift = Vector2(3, 4)
	pr.shadow = Vector2.ZERO
	pr.content_margin_top = 10
	pr.content_margin_bottom = 5
	pr.content_margin_left = 17
	pr.content_margin_right = 11
	var d := n.tinted(bg.lerp(PAPER_DARK, 0.5))
	d.ink = INK.lightened(0.4)
	d.shadow = Vector2.ZERO
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", d)
	b.mouse_entered.connect(func() -> void: Sfx.play("tick", -4.0, 0.06))
	b.pressed.connect(func() -> void: Sfx.play("click"))
	return b


## One answer in a conversation: a loose slip of paper with its key number
## written in front, a pen-drawn arrow when hovered. "Bye" slips sit plainer.
func _choice(n: int, text: String, bye := false) -> Button:
	var b := Button.new()
	b.text = "%d   %s" % [n, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 0)
	b.add_theme_font_override("font", head_font)
	b.add_theme_font_size_override("font_size", 18)
	if Game.touch:
		# fingers need a fat target (about 56 px tall at 1280x720)
		b.custom_minimum_size = Vector2(380, 56)
		b.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, INK)
	var base := PAPER_LIGHT if not bye else NOTE.darkened(0.04)
	var n_sb := _style(base, 2)
	n_sb.torn = CardBox.LEFT
	n_sb.rip = 4.0
	n_sb.tape = 0
	n_sb.shadow = Vector2(1, 2)
	n_sb.content_margin_left = 16
	n_sb.content_margin_right = 12
	n_sb.content_margin_top = 5
	n_sb.content_margin_bottom = 7
	var h := n_sb.tinted(GOLD.lightened(0.35))
	h.shift = Vector2(5, 0)
	h.shadow = Vector2(3, 3)
	var pr := n_sb.tinted(GOLD)
	pr.shift = Vector2(8, 2)
	pr.shadow = Vector2.ZERO
	b.add_theme_stylebox_override("normal", n_sb)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.mouse_entered.connect(func() -> void: Sfx.play("tick", -4.0, 0.06))
	b.pressed.connect(func() -> void: Sfx.play("click"))
	return b


## Text. Sizes from 26 up use the chunky heading face.
func _label(text: String, size := 20, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if size >= 26:
		l.add_theme_font_override("font", head_font)
	return l


## A small rounded tag of text on a card (clock, ledger status, key hints).
func _tag(text: String, bg := NOTE, size := 17) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(bg, 2)
	s.ply = false
	s.cut = 5.0
	s.shadow = Vector2(2, 3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, size)
	l.name = "L"
	p.add_child(l)
	return p


func _icon(icon_name: String, size := 24) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Cardboard.icon(icon_name)
	tr.modulate = INK
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func item_icon(good: String) -> Texture2D:
	if not item_tex.has(good):
		item_tex[good] = Bake.make(main.bake_root, "item", {"good": good}, Vector2i(96, 96))
	return item_tex[good]


func _item_rect(good: String, size := 40) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = item_icon(good)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func _bar(fill: Color, w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 18)
	b.show_percentage = false
	b.step = 0.0
	b.add_theme_stylebox_override("fill", _flat(fill))
	b.add_theme_stylebox_override("background", _flat(PAPER_DARK.darkened(0.25)))
	return b


## Keeps a popup panel centred on screen. Anchor-based centring drifted to
## the top-left corner when the panel's content changed while hidden, so the
## position is recomputed whenever the panel or the window changes size.
func _center(p: Control) -> void:
	var fit := func() -> void:
		if not p.is_inside_tree():
			return
		var vp := p.get_viewport_rect().size
		p.position = ((vp - p.size) * 0.5).floor()
	p.resized.connect(fit)
	p.visibility_changed.connect(func() -> void:
		if p.visible:
			p.reset_size()
			fit.call_deferred())
	get_viewport().size_changed.connect(fit)


# ---------- always-on pieces ----------

## A cardboard tear across the whole screen (see rip_fx.gd). Crits and blasts
## are rationed so it stays special; level-ups and knock-outs always play.
func rip(kind: String, text: String, sub := "", col := Color(1.0, 0.6, 0.2)) -> void:
	if kind == "crit" or kind == "blast":
		if Time.get_ticks_msec() < _rip_ready:
			return
		_rip_ready = Time.get_ticks_msec() + 4500
	rip_fx.play(kind, text, sub, col)


func _build_status() -> void:
	status_card = _panel(PAPER, 1)
	var sc: CardBox = status_card.get_theme_stylebox("panel")
	sc.torn = CardBox.RIGHT
	sc.rip = 9.0
	sc.cut = 6.0
	sc.content_margin_left = 22
	sc.content_margin_right = 26
	sc.content_margin_top = 16
	sc.content_margin_bottom = 16
	status_card.position = Vector2(14, 12)
	status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	status_card.add_child(row)
	medal_face = PortraitFrame.new()
	row.add_child(medal_face)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	row.add_child(vb)
	hp_g = Gauge.new(Color(0.88, 0.30, 0.30), "heart", 262.0, 26.0)
	vb.add_child(hp_g)
	st_g = Gauge.new(Color(0.95, 0.58, 0.18), "bolt", 262.0, 22.0)
	vb.add_child(st_g)
	ink_g = Gauge.new(Color(0.36, 0.56, 0.90), "magic_wand", 262.0, 22.0)
	vb.add_child(ink_g)
	# level and XP, a slim gold bar under the others
	var xr := HBoxContainer.new()
	xr.add_theme_constant_override("separation", 6)
	vb.add_child(xr)
	lv_label = _label("Lv 1", 18)
	lv_label.custom_minimum_size = Vector2(46, 0)
	xr.add_child(lv_label)
	xp_g = Gauge.new(Color(0.95, 0.74, 0.22), "star", 208.0, 14.0)
	xr.add_child(xp_g)
	job_label = _label("", 15, INK.lightened(0.25))
	vb.add_child(job_label)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 8)
	vb.add_child(r3)
	var coin := _icon("coins_stacks_of_dollars", 26)
	coin.modulate = INK
	r3.add_child(coin)
	coin_label = _label("0", 28)
	r3.add_child(coin_label)
	coin_delta = _label("", 20, Color(0.2, 0.5, 0.2))
	coin_delta.modulate.a = 0.0
	r3.add_child(coin_delta)
	pack_row = HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 2)
	pack_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_row.alignment = BoxContainer.ALIGNMENT_END
	r3.add_child(pack_row)


func _build_top() -> void:
	compass = Compass.new()
	compass.hud = self
	compass.custom_minimum_size = Vector2(460, 40)
	compass.size = Vector2(460, 40)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(compass)
	clock_tag = _tag("", PAPER_LIGHT, 18)
	clock_label = clock_tag.get_node("L")
	root.add_child(clock_tag)
	minimap = RoundMap.new()
	minimap.hud = self
	minimap.custom_minimum_size = Vector2(212, 238)
	minimap.size = Vector2(212, 238)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	tracker = _panel(NOTE, 1)
	tracker.custom_minimum_size = Vector2(230, 0)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tracker)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tracker.add_child(tv)
	tracker_title = _label("", 21)
	tracker_title.add_theme_font_override("font", head_font)
	tracker_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	tracker_title.custom_minimum_size = Vector2(200, 0)
	tv.add_child(tracker_title)
	tracker_text = _label("", 16, INK.lightened(0.2))
	tracker_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	tracker_text.custom_minimum_size = Vector2(200, 0)
	tv.add_child(tracker_text)
	chain_chip = NearChip.new()
	chain_chip.hud = self
	root.add_child(chain_chip)


func _build_log() -> void:
	log_panel = _panel(NOTE)
	log_panel.custom_minimum_size = Vector2(380, 0)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_panel)
	log_label = _label("", 16)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_label.custom_minimum_size = Vector2(350, 0)
	log_panel.add_child(log_label)
	prompt_panel = _tag("", GOLD, 22)
	prompt_label = prompt_panel.get_node("L")
	prompt_label.add_theme_font_override("font", head_font)
	root.add_child(prompt_panel)
	# key hints as little keycaps; they tuck away after a while (F1 brings them back)
	var keys := HFlowContainer.new()
	keys.add_theme_constant_override("h_separation", 10)
	keys.add_theme_constant_override("v_separation", 6)
	keys.custom_minimum_size = Vector2(560, 0)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.alignment = FlowContainer.ALIGNMENT_END
	var hints := [["WASD", "move"], ["Shift", "run"], ["Space", "jump"], ["Click", "strike x3"], ["X", "dodge"], ["K", "beam"], ["V", "dragon"], ["E", "use"],
			["F", "eat"], ["M", "map"], ["L", "quests"], ["Tab", "ledger"], ["Q C", "turn"], ["F2", "art style"], ["F1", "hide keys"]]
	if Game.touch:
		hints = [["Stick", "move (push out to run)"], ["Sword", "strike x3"], ["Arrows", "jump"], ["Bubble", "use / talk"], ["Swirl", "dodge"],
				["Bolt", "beam"], ["Flame", "dragon"], ["Bread", "eat"], ["Drag", "turn camera"], ["Pinch", "zoom"], ["?", "hide this"]]
	for k in hints:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1, 0.0)
		cs.set_border_width_all(0)
		cs.border_width_bottom = 2
		cs.border_color = INK
		cs.content_margin_left = 3
		cs.content_margin_right = 3
		cs.content_margin_top = 0
		cs.content_margin_bottom = 0
		cap.add_theme_stylebox_override("panel", cs)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := _label(k[0], 15)
		cl.add_theme_font_override("font", head_font)
		cap.add_child(cl)
		row.add_child(cap)
		var t := _label(k[1], 15, INK.lightened(0.15))
		row.add_child(t)
		keys.add_child(row)
	var kp := _panel(NOTE, 0)
	var ks := kp.get_theme_stylebox("panel") as CardBox
	ks.torn = 0
	ks.set_content_margin_all(9)
	ks.shadow = Vector2(1, 2)
	kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kp.add_child(keys)
	keys_panel = kp
	root.add_child(kp)


func add_log(text: String) -> void:
	log_lines.append(text)
	log_times.append(Time.get_ticks_msec() / 1000.0)
	if log_lines.size() > 60:
		log_lines.pop_front()
		log_times.pop_front()
	if log_panel != null and Game.started:
		log_panel.pivot_offset = Vector2(0, log_panel.size.y)
		log_panel.scale = Vector2(1.04, 1.04)
		log_panel.create_tween().tween_property(log_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func toggle_keys() -> void:
	_keys_t = 0.0 if _keys_t > 0.0 else 9999.0


# ---------- banner and fades ----------

func _build_banner() -> void:
	banner_panel = _panel(NOTE)
	banner_panel.visible = false
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_panel)
	var vb := VBoxContainer.new()
	banner_panel.add_child(vb)
	banner_title = _label("", 40)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(banner_title)
	banner_sub = _label("", 20)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(banner_sub)


func banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_panel.visible = true
	banner_panel.reset_size()
	banner_panel.pivot_offset = banner_panel.size * 0.5
	banner_panel.scale = Vector2(0.2, 0.2)
	banner_panel.modulate.a = 1.0
	var tw := banner_panel.create_tween()
	tw.tween_property(banner_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(banner_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): banner_panel.visible = false)


func _build_curtain() -> void:
	curtain_l = ColorRect.new()
	curtain_r = ColorRect.new()
	var sh := preload("res://shaders/curtain.gdshader")
	for c in [curtain_l, curtain_r]:
		c.color = Color(1, 1, 1)
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("side", 1.0 if c == curtain_l else -1.0)
		c.material = m
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.visible = false
		root.add_child(c)


## Two cardboard flaps close over the screen, the callback runs, they open.
func fade_through(cb: Callable) -> void:
	var vs := root.get_viewport_rect().size
	for c in [curtain_l, curtain_r]:
		c.size = Vector2(vs.x * 0.5 + 40, vs.y)
		(c.material as ShaderMaterial).set_shader_parameter("px", c.size)
		c.visible = true
	curtain_l.position = Vector2(-vs.x * 0.5, 0)
	curtain_r.position = Vector2(vs.x, 0)
	var tw := create_tween()
	tw.tween_property(curtain_l, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(curtain_r, "position:x", vs.x * 0.5 - 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(cb)
	tw.tween_interval(0.25)
	tw.tween_property(curtain_l, "position:x", -vs.x * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(curtain_r, "position:x", vs.x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_hide_curtains)


func _hide_curtains() -> void:
	curtain_l.visible = false
	curtain_r.visible = false


# ---------- title ----------

func _build_title() -> void:
	_title_font = load("res://assets/fonts/stampcraft.ttf")
	table = TableArt.new()
	table.visible = false
	root.add_child(table)
	title_panel = Control.new()
	title_panel.z_index = 41
	title_panel.visible = false
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_panel)
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TitleArt.new()
	art.hud = self
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(art)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(col)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(360, 0)
	box.add_child(vb)
	var play := _button("Play", GOLD)
	play.add_theme_font_size_override("font_size", 34)
	play.pressed.connect(_on_play)
	vb.add_child(play)
	_build_wallet_row(vb)
	var how := _label("Stick move   Sword strike   Bubble use   Drag turn   Pinch zoom" if Game.touch else "WASD move   Click strike   X dodge   E use   Tab ledger", 17, NOTE)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.add_theme_color_override("font_outline_color", INK)
	how.add_theme_constant_override("outline_size", 7)
	col.add_child(how)
	var near := _label("Every coin is real: shops, townsfolk and you settle on NEAR testnet.", 16, NOTE)
	near.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	near.add_theme_color_override("font_outline_color", INK)
	near.add_theme_constant_override("outline_size", 6)
	col.add_child(near)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 26)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pad)


## Optional NEAR wallet: Play is always "as a guest". On the web "Connect NEAR
## wallet" goes through the page's login; on desktop (and in a browser with no
## wallet page) a name.testnet field is checked by the relayer. Nothing here can
## stop the game from starting.
var _wallet_note: Label
var _wallet_edit: LineEdit
var _wallet_row: HBoxContainer


func _build_wallet_row(vb: VBoxContainer) -> void:
	_wallet_row = HBoxContainer.new()
	_wallet_row.add_theme_constant_override("separation", 8)
	vb.add_child(_wallet_row)
	_wallet_note = _label("", 15, NOTE)
	_wallet_note.add_theme_color_override("font_outline_color", INK)
	_wallet_note.add_theme_constant_override("outline_size", 6)
	_wallet_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_wallet_note.custom_minimum_size = Vector2(360, 0)
	vb.add_child(_wallet_note)
	Game.account_changed.connect(_refresh_wallet)
	Chain.status_changed.connect(_refresh_wallet)
	_refresh_wallet()


func _refresh_wallet() -> void:
	if _wallet_row == null:
		return
	for c in _wallet_row.get_children():
		c.queue_free()
	_wallet_edit = null
	if Game.account != "":
		var who := _label(Game.account, 18, INK)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wallet_row.add_child(who)
		var out := _button("Unlink", PAPER_LIGHT)
		out.add_theme_font_size_override("font_size", 16)
		out.pressed.connect(func():
			Chain.link("")
			Game.set_account(""))
		_wallet_row.add_child(out)
	elif OS.has_feature("web"):
		var conn := _button("Connect NEAR wallet", PAPER_LIGHT)
		conn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conn.add_theme_font_size_override("font_size", 20)
		conn.pressed.connect(func(): JavaScriptBridge.eval("window.pennyfold && window.pennyfold.login()"))
		_wallet_row.add_child(conn)
	else:
		_wallet_edit = LineEdit.new()
		_wallet_edit.placeholder_text = "yourname.testnet (optional)"
		_wallet_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wallet_edit.add_theme_font_override("font", head_font)
		_wallet_edit.add_theme_font_size_override("font_size", 18)
		_wallet_edit.add_theme_color_override("font_color", INK)
		_wallet_edit.add_theme_color_override("font_placeholder_color", INK.lightened(0.45))
		var fs := _style(PAPER_LIGHT, 1)
		fs.set_content_margin_all(8)
		_wallet_edit.add_theme_stylebox_override("normal", fs)
		_wallet_edit.add_theme_stylebox_override("focus", fs)
		_wallet_edit.text_submitted.connect(func(_t): _on_link_pressed())
		_wallet_row.add_child(_wallet_edit)
		var link := _button("Link", PAPER_LIGHT)
		link.add_theme_font_size_override("font_size", 18)
		link.pressed.connect(_on_link_pressed)
		_wallet_row.add_child(link)
	_wallet_note.text = Chain.link_note if Chain.link_note != "" else ("Optional: link a NEAR testnet wallet to be paid, or just play as a guest." if Game.account == "" else "")


func _on_link_pressed() -> void:
	if _wallet_edit == null:
		return
	var a := _wallet_edit.text.strip_edges().to_lower()
	if not Game.valid_account(a):
		Chain.link_note = "That does not look like a testnet account (name.testnet)."
		_refresh_wallet()
		return
	Game.set_account(a)
	Chain.link(a)


var table: TableArt


func show_title() -> void:
	table.visible = true
	title_panel.visible = true


func _on_play() -> void:
	if not bool(Game.hero["made"]):
		title_panel.visible = false
		menus.show_creator(func() -> void:
			main.apply_hero()
			_begin_play())
		return
	_begin_play()


func _begin_play() -> void:
	Game.started = true
	Game.via_title = true
	title_panel.visible = false
	fade_through(func() -> void: table.visible = false)


func _noop() -> void:
	pass


func _on_style() -> void:
	Game.style = "real" if Game.cute() else "cute"
	get_tree().reload_current_scene()


# ---------- shop ----------

func _build_shop() -> void:
	shop_panel = _panel()
	_vis(shop_panel, false)
	root.add_child(shop_panel)
	_center(shop_panel)


var prices_panel: PanelContainer
var bestiary_panel: PanelContainer


## The exchange's price board: every good's cheapest ask in each city, so a
## trader can see where to buy and where to sell. Cheapest is green, dearest red.
func open_prices(exchange_id: String) -> void:
	close_all()
	if prices_panel != null:
		prices_panel.queue_free()
	prices_panel = _panel(PAPER_LIGHT)
	prices_panel.visible = false
	root.add_child(prices_panel)
	_center(prices_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	prices_panel.add_child(vb)
	vb.add_child(_label("Price board", 34))
	var cities: Array = main.towns
	var grid := GridContainer.new()
	grid.columns = cities.size() + 1
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 2)
	vb.add_child(grid)
	grid.add_child(_label("Good", 18, INK.lightened(0.3)))
	for tn in cities:
		grid.add_child(_label(tn["name"], 18, INK.lightened(0.3)))
	for g in Economy.GOODS:
		var row: Array = []
		var lo := 9999
		var hi := 0
		for tn in cities:
			var best := 0
			for sid in Economy.shops:
				var sh: Dictionary = Economy.shops[sid]
				if sh["city"] != tn["id"] or sh["kind"] == "" or int(sh["stock"].get(g, 0)) <= 0:
					continue
				var pr := Economy.buy_price(sid, g)
				if best == 0 or pr < best:
					best = pr
			row.append(best)
			if best > 0:
				lo = mini(lo, best)
				hi = maxi(hi, best)
		grid.add_child(_label(Economy.GOODS[g]["name"], 18))
		for b in row:
			var col := INK
			if b > 0 and lo != hi:
				col = Color(0.15, 0.5, 0.2) if b == lo else (Color(0.75, 0.2, 0.15) if b == hi else INK)
			grid.add_child(_label(str(b) if b > 0 else "-", 18, col))
	var news := _label(main.event_summary() if main.event_summary() != "" else "No events today.", 17, INK.lightened(0.2))
	vb.add_child(news)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var trade := _button("Trade here", GOLD)
	trade.pressed.connect(func(): open_shop(exchange_id))
	hb.add_child(trade)
	var cl := _button("Close (Esc)")
	cl.pressed.connect(close_all)
	hb.add_child(cl)
	_vis(prices_panel, true)
	Sfx.play("open")


## The bestiary: every beast met so far, with art, what it drops and where it
## lives. Beasts not met yet show as a "?".
func toggle_bestiary() -> void:
	var show := bestiary_panel == null or not bestiary_panel.visible
	close_all()
	if not show:
		Sfx.play("close")
		return
	if bestiary_panel != null:
		bestiary_panel.queue_free()
	bestiary_panel = _panel(PAPER_LIGHT)
	bestiary_panel.visible = false
	root.add_child(bestiary_panel)
	_center(bestiary_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(760, 0)
	bestiary_panel.add_child(vb)
	var met := 0
	for k in Monster.TYPES:
		if main.bestiary.has(k):
			met += 1
	vb.add_child(_label("Bestiary   %d / %d met" % [met, Monster.TYPES.size()], 32))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	for k in Monster.TYPES:
		grid.add_child(_beast_card(k))
	var cl := _button("Close (Esc)")
	cl.pressed.connect(close_all)
	vb.add_child(cl)
	_vis(bestiary_panel, true)
	Sfx.play("open")


func _beast_card(k: String) -> Control:
	var t: Dictionary = Monster.TYPES[k]
	var e: Dictionary = main.bestiary.get(k, {})
	var known := not e.is_empty()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(NOTE, 2, 4))
	card.custom_minimum_size = Vector2(364, 96)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(80, 80)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if t.has("sprite"):
		art.texture = load("res://assets/beasts/" + String(t["sprite"]))
		if not known:
			art.modulate = Color(0.1, 0.07, 0.04, 0.85)
	row.add_child(art)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label(Monster.name_of(k, Game.cute()) if known else "???", 22))
	if known:
		var drops: PackedStringArray = []
		for g in t["drops"]:
			drops.append("%d %s" % [int(t["drops"][g]), String(Economy.GOODS[g]["name"]).to_lower()])
		var info := _label("HP %d, bite %d.  Met %s, beaten %d.
Drops: %s%s" % [int(t["hp"]), int(t["dmg"]), "often" if int(e["seen"]) > 20 else "now and then", int(e["kills"]), ", ".join(drops), ("
Dire form seen!" if int(e["best_tier"]) >= 2 else "")], 15, INK.lightened(0.15))
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.custom_minimum_size = Vector2(250, 0)
		col.add_child(info)
	else:
		col.add_child(_label("Not met yet.", 15, INK.lightened(0.4)))
	return card


func open_shop(id: String) -> void:
	if id == "" or not Economy.shops.has(id):
		return
	if prices_panel != null:
		_vis(prices_panel, false)
	shop_id = id
	_rebuild_shop()
	Sfx.play("door")


func close_shop() -> void:
	if shop_id != "":
		Sfx.play("close")
	shop_id = ""
	_vis(shop_panel, false)


func _rebuild_shop() -> void:
	for c in shop_panel.get_children():
		c.queue_free()
	if shop_id == "" or main == null:
		_vis(shop_panel, false)
		return
	_vis(shop_panel, true)
	var s: Dictionary = Economy.shops[shop_id]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	shop_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := _label(s["name"], 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_icon("money_bag", 28))
	head.add_child(_label("Till %d" % int(Economy.wallets[shop_id]["coins"]), 22))
	head.add_child(_icon("coins_stacks_of_dollars", 28))
	head.add_child(_label("You %d" % int(Economy.wallets["player"]["coins"]), 22))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	vb.add_child(cols)
	var shelf := _shop_column("On the shelf", cols)
	var pack := _shop_column("Your pack", cols)
	for good in Economy.GOODS:
		var stock := int(s["stock"].get(good, 0))
		if stock > 0:
			shelf.add_child(_trade_card(good, stock, true, true))
	var mine: Dictionary = Economy.wallets["player"]["items"]
	var any := false
	for good in mine:
		any = true
		pack.add_child(_trade_card(good, int(mine[good]), false, good in s["buys"]))
	if not any:
		pack.add_child(_label("Nothing to sell. Gather wheat, ore and herbs in the wild,\nor loot monsters.", 16))
	if shelf.get_child_count() == 0:
		shelf.add_child(_label("Sold out. Come back after the next batch.", 16))
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	var tip := _label("Prices follow stock: cheap when shelves are full, dear when they are empty.", 16)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(tip)
	var close := _button("Close (Esc)")
	close.pressed.connect(close_shop)
	foot.add_child(close)


func _shop_column(title: String, parent: Control) -> VBoxContainer:
	var p := _panel(PAPER_LIGHT)
	p.custom_minimum_size = Vector2(390, 300)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label(title, 24))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(370, 270)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list


func _trade_card(good: String, qty: int, buying: bool, allowed: bool) -> Control:
	var card := PanelContainer.new()
	var st := _style(NOTE, 2, 5)
	st.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	row.add_child(_item_rect(good, 40))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label("%s  x%d" % [Economy.GOODS[good]["name"], qty], 19))
	var base := int(Economy.GOODS[good]["base"])
	if not allowed:
		info.add_child(_label("They do not buy this here", 15, INK.lightened(0.35)))
		return card
	var price := Economy.buy_price(shop_id, good) if buying else Economy.sell_price(shop_id, good)
	var trend := "fair"
	var tcol := INK.lightened(0.2)
	var ref := base * (1.25 if buying else 0.8)
	if price > ref * 1.15:
		trend = "dear" if buying else "pays well"
		tcol = Color(0.70, 0.20, 0.15) if buying else Color(0.15, 0.50, 0.20)
	elif price < ref * 0.87:
		trend = "cheap" if buying else "pays little"
		tcol = Color(0.15, 0.50, 0.20) if buying else Color(0.70, 0.20, 0.15)
	info.add_child(_label("%d coins each   (%s)" % [price, trend], 16, tcol))
	for n in [1, 5]:
		if n > qty:
			continue
		var b := _button(("Buy %d" if buying else "Sell %d") % n, GOLD if buying else Color(0.70, 0.86, 0.62))
		b.pressed.connect(_trade.bind(good, buying, n))
		if buying and int(Economy.wallets["player"]["coins"]) < price:
			b.disabled = true
		row.add_child(b)
	return card


func _trade(good: String, buying: bool, n: int) -> void:
	var done: int = main.player_trade(shop_id, good, buying, n)
	if done > 0:
		var l := _label(("+%d %s" if buying else "-%d %s") % [done, Economy.GOODS[good]["name"]], 30, Color(0.15, 0.45, 0.15) if buying else Color(0.55, 0.30, 0.10))
		l.add_theme_color_override("font_outline_color", NOTE)
		l.add_theme_constant_override("outline_size", 10)
		root.add_child(l)
		l.position = root.get_local_mouse_position() + Vector2(-30, -40)
		var tw := l.create_tween()
		tw.tween_property(l, "position:y", l.position.y - 60, 0.7)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
		tw.tween_callback(l.queue_free)


func _on_economy() -> void:
	if shop_panel.visible:
		_rebuild_shop.call_deferred()


# ---------- conversation ----------

func _build_dialog() -> void:
	dialog_panel = _panel(NOTE)
	_vis(dialog_panel, false)
	root.add_child(dialog_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	dialog_panel.add_child(row)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(240, 0)
	row.add_child(mid)
	_dialog_name = _label("", 28)
	mid.add_child(_dialog_name)
	_dialog_text = _label("", 20)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialog_text.custom_minimum_size = Vector2(430, 0)
	mid.add_child(_dialog_text)
	_dialog_opts = VBoxContainer.new()
	_dialog_opts.custom_minimum_size = Vector2(300, 0)
	row.add_child(_dialog_opts)


func open_dialog(n: Npc, text: String, opts: Array) -> void:
	_vis(dialog_panel, true)
	_dialog_name.text = "%s, %s" % [n.display_name, n.job_title.to_lower() if n.job_id != "" else "townsperson"]
	set_dialog_text(text, opts)


## Crops the head from the figure's front view (cute) or the upper body (real).
func _portrait(v: Standee) -> Texture2D:
	var vw := "front" if v.views.has("front") else v.view
	var vd: Dictionary = v.views[vw]
	var joints: Dictionary = vd["joints"]
	var sprites: Array = vd["sprites"]
	var piece := "head" if joints.has("head") else "body"
	var idx := joints.keys().find(piece)
	if idx < 0 or idx >= sprites.size():
		return null
	var spr: Sprite3D = sprites[idx]
	var at := AtlasTexture.new()
	at.atlas = spr.texture
	var r := spr.region_rect
	if piece == "head":
		at.region = Rect2(r.position.x + r.size.x * PORTRAIT_BOX.position.x, r.position.y + r.size.y * PORTRAIT_BOX.position.y,
			r.size.x * PORTRAIT_BOX.size.x, r.size.y * PORTRAIT_BOX.size.y)
	else:
		at.region = Rect2(r.position.x + r.size.x * 0.25, r.position.y + r.size.y * 0.02, r.size.x * 0.5, r.size.y * 0.45)
	return at


func set_dialog_text(text: String, opts: Array) -> void:
	_dialog_text.text = text
	# the words appear in a pink cut-paper bubble over the speaker's head; the
	# panel only keeps the portrait and the choices
	var npc = main.dialog_npc
	_dialog_text.visible = npc == null
	if npc != null:
		var tint := Color(0.995, 0.99, 0.965)
		if npc.job_kind == "guard":
			tint = Color(0.90, 0.95, 1.0)
		elif npc.job_id == "":
			tint = Color(1.0, 0.98, 0.90)
		npc.view.bubble.set_line(text, 3, tint, 520.0)
	else:
		_dialog_text.visible_ratio = 0.0
		var tw := _dialog_text.create_tween()
		tw.tween_property(_dialog_text, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.3, 2.0))
	for c in _dialog_opts.get_children():
		c.queue_free()
	_dialog_choices = opts.duplicate()
	var i := 0
	for o in opts:
		i += 1
		var b := _choice(i, o["text"], bool(o.get("bye", false)))
		b.pressed.connect(main.dialog_choice.bind(o))
		_dialog_opts.add_child(b)


## Presses choice number `n` (1-based) while a conversation is open.
func pick_choice(n: int) -> void:
	if not dialog_panel.visible or n < 1 or n > _dialog_choices.size():
		return
	main.dialog_choice(_dialog_choices[n - 1])


## Panels pop in (a little scale, tilt and fade) and drop away when closed, as
## if a card were slapped on the table and then pulled off it.
func _vis(p: Control, on: bool) -> void:
	if p == null:
		return
	var closing: bool = p.get_meta("closing") if p.has_meta("closing") else false
	# a second close while the first is still animating must not kill its tween
	# (that left the panel visible forever and froze the player)
	if not on and closing:
		return
	if p.has_meta("tw"):
		var old: Tween = p.get_meta("tw")
		if old != null and old.is_valid():
			old.kill()
	if on:
		if p.visible and not closing:
			return
		p.set_meta("closing", false)
		p.visible = true
		if DisplayServer.get_name() == "headless" or not p.is_inside_tree():
			return
		p.modulate.a = 0.0
		_pop_in.call_deferred(p)
	else:
		if not p.visible or closing:
			return
		if DisplayServer.get_name() == "headless" or not p.is_inside_tree():
			p.visible = false
			return
		p.set_meta("closing", true)
		p.pivot_offset = p.size * 0.5
		var base: Vector2 = p.position
		var tw := p.create_tween()
		p.set_meta("tw", tw)
		tw.set_parallel(true)
		tw.tween_property(p, "rotation", 0.05, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "position:y", base.y + 60.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale", Vector2(0.92, 0.92), 0.2)
		tw.tween_property(p, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(func() -> void:
			p.visible = false
			p.set_meta("closing", false)
			p.rotation = 0.0
			p.scale = Vector2.ONE
			p.modulate.a = 1.0
			p.position = base)


func _pop_in(p: Control) -> void:
	if not is_instance_valid(p) or not p.visible:
		return
	p.pivot_offset = p.size * 0.5
	p.rotation = -0.035
	p.scale = Vector2(0.88, 0.88)
	var tw := p.create_tween()
	p.set_meta("tw", tw)
	tw.set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.14)


func close_dialog() -> void:
	_vis(dialog_panel, false)
	_dialog_choices = []


# ---------- map ----------

func _build_map() -> void:
	map_panel = _panel(PAPER_LIGHT)
	_vis(map_panel, false)
	root.add_child(map_panel)
	_center(map_panel)
	var vb := VBoxContainer.new()
	map_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := _label("Map of the Folded Vale", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Click a discovered place to fast travel.   M to close", 17))
	big_map = MapView.new()
	big_map.hud = self
	big_map.custom_minimum_size = Vector2(620, 600)
	vb.add_child(big_map)


func toggle_map() -> void:
	var show := not map_panel.visible
	close_all()
	_vis(map_panel, show)
	Sfx.play("open" if show else "close")


# ---------- quests ----------

func _build_quests() -> void:
	quest_panel = _panel(PAPER_LIGHT)
	_vis(quest_panel, false)
	root.add_child(quest_panel)
	_center(quest_panel)


func open_board() -> void:
	close_all()
	_fill_quests(true)
	Sfx.play("open")


func toggle_quests() -> void:
	var show := not quest_panel.visible
	close_all()
	if show:
		_fill_quests(false)
	Sfx.play("open" if show else "close")


func _fill_quests(board: bool) -> void:
	for c in quest_panel.get_children():
		c.queue_free()
	_vis(quest_panel, true)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(720, 0)
	quest_panel.add_child(vb)
	if not board:
		var st: Story = main.story
		vb.add_child(_label("Story: %s" % st.data.get("title", ""), 30))
		var cur: Dictionary = st.current()
		for ln in st.journal(main):
			vb.add_child(_label(ln, 17))
		if st.finished:
			var pl := _label("The Crown is whole. New Game Plus %d: beasts are tougher." % st.plus, 17, Color(0.2, 0.4, 0.2))
			vb.add_child(pl)
		elif not cur.is_empty():
			var cl := _label(("Now: " + st.goal_text(main)) if st.state == "active" else "Find the captain of %s to begin." % String(Economy.city_def(cur["city"]).get("name", "")), 17, Color(0.2, 0.4, 0.2))
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD
			cl.custom_minimum_size = Vector2(700, 0)
			vb.add_child(cl)
	vb.add_child(_label("Quest board" if board else "Your quests", 34))
	vb.add_child(_label("Rewards are held in escrow by the board: the giver pays in when you accept.", 16))
	var q: Quests = main.quests
	if board:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		vb.add_child(grid)
		for o in q.offers:
			grid.add_child(_quest_card(o, true))
		if q.offers.is_empty():
			vb.add_child(_label("No notes pinned up today.", 18))
	vb.add_child(_label("Taken (%d / %d)" % [q.active.size(), Quests.MAX_ACTIVE], 24))
	for a in q.active:
		vb.add_child(_quest_card(a, false))
	if q.active.is_empty():
		vb.add_child(_label("None yet.", 18))
	var close := _button("Close (Esc)")
	close.pressed.connect(close_all)
	vb.add_child(close)


func _quest_card(qd: Dictionary, offer: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(NOTE, 2, 4))
	card.custom_minimum_size = Vector2(350, 0)
	var v := VBoxContainer.new()
	card.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := _label(qd["title"], 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_icon("coins_stacks_of_dollars", 22))
	top.add_child(_label(str(int(qd["reward"])), 22))
	var d := _label("%s  (from the %s)" % [qd["desc"], qd["giver_name"]], 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(330, 0)
	v.add_child(d)
	var q: Quests = main.quests
	var row := HBoxContainer.new()
	v.add_child(row)
	if offer:
		var b := _button("Accept", GOLD)
		b.disabled = q.active.size() >= Quests.MAX_ACTIVE
		b.pressed.connect(_q_accept.bind(qd))
		row.add_child(b)
	else:
		row.add_child(_label(q.progress_text(qd), 17, Color(0.2, 0.4, 0.2)))
		var tr := _button("Track")
		tr.pressed.connect(_q_track.bind(qd))
		row.add_child(tr)
		var dr := _button("Drop", Color(0.92, 0.70, 0.62))
		dr.pressed.connect(_q_drop.bind(qd))
		row.add_child(dr)
	return card


func _q_accept(qd: Dictionary) -> void:
	main.quests.accept(main, qd)
	_fill_quests(true)


func _q_track(qd: Dictionary) -> void:
	main.quests.tracked = main.quests.active.find(qd)
	close_all()


func _q_drop(qd: Dictionary) -> void:
	main.quests.abandon(qd)
	_fill_quests(false)


# ---------- ledger ----------

func _build_ledger() -> void:
	ledger_panel = _panel()
	_vis(ledger_panel, false)
	root.add_child(ledger_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	ledger_panel.add_child(lv)
	var what := _label("SETTLING THE DAY: every purchase, sale and wage so far is netted into one transfer per pair of wallets and sent to NEAR.", 16)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD
	what.custom_minimum_size = Vector2(560, 0)
	lv.add_child(what)
	_settle_status = _label("", 17, Color(0.55, 0.30, 0.05))
	lv.add_child(_settle_status)
	ledger_label = _label("", 16)
	lv.add_child(ledger_label)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 10)
	lv.add_child(lr)
	var b1 := _button("Settle day: send coins to NEAR", GOLD)
	b1.pressed.connect(func() -> void: Chain.settle_now(main))
	lr.add_child(b1)
	var b2 := _button("Last transaction")
	b2.pressed.connect(func() -> void: Chain.open_last_tx())
	lr.add_child(b2)
	var b3 := _button("Open NearBlocks")
	b3.pressed.connect(func() -> void: Chain.open_explorer())
	lr.add_child(b3)


## One plain line saying where the day's settlement stands.
func _settle_line() -> String:
	if Chain.mode == "offline":
		return "No relayer found, so coins stay in the local ledger. Start one with: node server/relayer.mjs"
	for e in Chain.day_log:
		if e["status"] == "sending":
			return "Sending to NEAR..."
	var waiting := Chain.pending.size()
	var last := ""
	for i in range(Chain.day_log.size() - 1, -1, -1):
		var e: Dictionary = Chain.day_log[i]
		if e["status"] == "settled":
			last = "   Last settled: day %d, %d transfers." % [int(e["day"]), int(e["flows"])]
			break
		if e["status"] == "failed":
			last = "   Last attempt failed. Press the button to retry."
			break
	if waiting == 0:
		return "Nothing waiting to settle: trade something first." + last
	return "%d coin moves waiting to be settled.%s" % [waiting, last]


func toggle_ledger() -> void:
	var show := not ledger_panel.visible
	close_all()
	_vis(ledger_panel, show)
	_ledger_t = 0.0
	Sfx.play("open" if show else "close")


func _ledger_text(world) -> String:
	var lines: Array = ["TOWN LEDGER   (all coins: %d, never created or destroyed)" % Economy.total_coins(), ""]
	for id in Economy.shops:
		var s: Dictionary = Economy.shops[id]
		var stock: Array = []
		for g in s["stock"]:
			if int(s["stock"][g]) > 0:
				stock.append("%s %d" % [Economy.GOODS[g]["name"], int(s["stock"][g])])
		lines.append("%s: %d coins | %s" % [s["name"], int(Economy.wallets[id]["coins"]), ", ".join(PackedStringArray(stock))])
	var tre: String = world._guard_post_id()
	if Economy.wallets.has(tre):
		lines.append("Town treasury (guard post): %d coins" % int(Economy.wallets[tre]["coins"]))
	lines.append("Quest escrow: %d coins" % int(Economy.wallets.get(Quests.ESCROW, {"coins": 0})["coins"]))
	lines.append("You: %d coins" % int(Economy.wallets["player"]["coins"]))
	lines.append("")
	for n in world.npcs:
		var mood := "fed"
		if n.hunger > 90.0:
			mood = "starving"
		elif n.hunger > 60.0:
			mood = "hungry"
		elif n.hunger > 30.0:
			mood = "peckish"
		lines.append("%s, %s: %d coins, %s, %s" % [n.display_name, n.job_title, int(Economy.wallets[n.id]["coins"]), mood, n.state])
	lines.append("")
	lines.append(Chain.summary())
	for e in Chain.day_log.slice(maxi(0, Chain.day_log.size() - 3)):
		var tx := ""
		var txs: Array = e.get("txs", [])
		if txs.size() > 0 and typeof(txs[0]) == TYPE_DICTIONARY:
			tx = "  first tx %s" % String(txs[0].get("hash", "")).left(12)
		lines.append("  day %d: %d coin moves netted to %d transfers, %s%s" % [int(e["day"]), int(e["raw"]), int(e["flows"]), e["status"], tx])
	return "\n".join(PackedStringArray(lines))


# ---------- shared ----------

func toggle_skills() -> void:
	menus.toggle_skills()


func toggle_pause() -> void:
	menus.toggle_pause()


func close_all() -> void:
	close_shop()
	if menus != null and menus.skills_panel != null:
		_vis(menus.skills_panel, false)
	if bestiary_panel != null:
		_vis(bestiary_panel, false)
	if prices_panel != null:
		_vis(prices_panel, false)
	_vis(map_panel, false)
	_vis(quest_panel, false)
	_vis(ledger_panel, false)


## Big popups hide the tutorial card so they never overlap.
func blocking_overlay() -> bool:
	return (menus != null and menus.any_open()) or _death_open or (bestiary_panel != null and bestiary_panel.visible) or (prices_panel != null and prices_panel.visible) or shop_panel.visible or map_panel.visible or quest_panel.visible or dialog_panel.visible


func blocking() -> bool:
	return (menus != null and menus.any_open()) or _death_open or (bestiary_panel != null and bestiary_panel.visible) or (prices_panel != null and prices_panel.visible) or shop_panel.visible or dialog_panel.visible or map_panel.visible or quest_panel.visible or title_panel.visible


func refresh(world, delta: float) -> void:
	var vs := root.get_viewport_rect().size
	var started := Game.started
	for c in [compass, clock_tag, minimap, tracker, log_panel, prompt_panel, keys_panel, chain_chip]:
		c.visible = started
	status_card.visible = started
	keys_panel.visible = started and not dialog_panel.visible
	if started and not _tut_started and Game.wants_tutorial():
		_tut_started = true
		tutorial = Tutorial.new(self)
		root.add_child(tutorial)
	if tutorial != null:
		tutorial.visible = not blocking_overlay()
		tutorial.update(world, delta)
		tutorial.position = Vector2(14.0, 200.0)
	overlay.queue_redraw()
	if not started:
		return
	hp_g.set_value(world.player["hp"], world.player["max_hp"])
	st_g.set_value(world.player["stamina"], world.player["max_stamina"])
	st_g.tired = world.player["tired"]
	ink_g.set_value(world.player["ink"], world.player["max_ink"])
	xp_g.set_value(world.career.xp, world.career.needed())
	lv_label.text = "Lv %d" % world.career.level
	var jt: String = world.career.status_text(world)
	job_label.text = jt
	job_label.visible = jt != ""
	if medal_face.texture == null and world.player_view != null:
		medal_face.texture = _portrait(world.player_view)
	var coins := int(Economy.wallets["player"]["coins"])
	if coins != _shown_coins:
		if _shown_coins >= 0 and coins > _shown_coins:
			_coin_fly(mini(8, coins - _shown_coins))
		if _shown_coins >= 0:
			# a running "+12" / "-8" beside the purse for each change
			_delta_acc = (_delta_acc if _delta_t > 0.0 else 0) + (coins - _shown_coins)
			_delta_t = 1.6
			coin_delta.text = ("%+d" % _delta_acc)
			coin_delta.add_theme_color_override("font_color", Color(0.18, 0.5, 0.2) if _delta_acc >= 0 else Color(0.75, 0.2, 0.15))
		_shown_coins = coins
		coin_label.text = str(coins)
		coin_label.pivot_offset = coin_label.size * 0.5
		var tw := coin_label.create_tween()
		tw.tween_property(coin_label, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(coin_label, "scale", Vector2.ONE, 0.15)
	_delta_t = maxf(0.0, _delta_t - delta)
	coin_delta.modulate.a = clampf(_delta_t / 0.5, 0.0, 1.0)
	var items: Dictionary = Economy.wallets["player"]["items"]
	var sig := str(items)
	if sig != _pack_sig:
		_pack_sig = sig
		for c in pack_row.get_children():
			c.queue_free()
		var shown := 0
		for g in items:
			if shown >= 5:
				break
			shown += 1
			pack_row.add_child(_item_rect(g, 26))
			pack_row.add_child(_label("%d " % int(items[g]), 17))

	compass.position = Vector2(vs.x * 0.5 - compass.size.x * 0.5, 12)
	compass.queue_redraw()
	clock_label.text = "Day %d   %02d:%02d" % [world.day_number(), int(world.hour), int(fmod(world.hour, 1.0) * 60.0)]
	var ev: String = world.event_summary()
	if ev != "":
		clock_label.text += "   " + ev
	clock_tag.reset_size()
	clock_tag.position = Vector2(vs.x * 0.5 - clock_tag.size.x * 0.5, 54)
	minimap.position = Vector2(vs.x - minimap.size.x - 14, 10)
	minimap.queue_redraw()
	chain_chip.refresh()
	menus.update(world, vs)
	chain_chip.position = Vector2(vs.x - chain_chip.size.x - 18, minimap.position.y + minimap.size.y + 2)

	var q: Dictionary = world.quests.current()
	var sc: Dictionary = world.story.current()
	tracker.visible = not q.is_empty() or (not sc.is_empty() and world.story.state == "active")
	if not q.is_empty():
		tracker_title.text = q["title"]
		tracker_text.text = "%s\n%d coins on completion" % [world.quests.progress_text(q), int(q["reward"])]
	elif tracker.visible:
		tracker_title.text = "Story: %s" % sc["title"]
		tracker_text.text = world.story.goal_text(world) + ("\nReturn to the captain!" if world.story.goal_met(world) else "")
	tracker.position = Vector2(vs.x - tracker.size.x - 18, chain_chip.position.y + chain_chip.size.y + 12)

	# only fresh messages show, as one paper slip that fades away
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array = []
	for i in range(maxi(0, log_lines.size() - 3), log_lines.size()):
		if now - float(log_times[i]) < LOG_SECS:
			recent.append(log_lines[i])
	log_panel.visible = not recent.is_empty()
	if not recent.is_empty():
		log_label.text = "\n".join(PackedStringArray(recent))
		var age := now - float(log_times[log_times.size() - 1])
		log_panel.modulate.a = clampf((LOG_SECS - age) / 1.0, 0.0, 1.0)
		log_panel.reset_size()
	log_panel.position = Vector2(16, vs.y - log_panel.size.y - (360.0 if Game.touch else 18.0))
	_keys_t -= delta
	keys_panel.modulate.a = clampf(_keys_t, 0.0, 1.0)
	keys_panel.visible = _keys_t > 0.0
	keys_panel.reset_size()
	keys_panel.position = Vector2(vs.x - keys_panel.size.x - 18, vs.y - keys_panel.size.y - 16)
	if Game.touch:
		keys_panel.position = Vector2(vs.x * 0.5 - keys_panel.size.x * 0.5, 96)
	prompt_label.text = world.prompt
	prompt_panel.visible = world.prompt != ""
	prompt_panel.reset_size()
	prompt_panel.position = Vector2(vs.x * 0.5 - prompt_panel.size.x * 0.5, vs.y - (190 if keys_panel.visible else 120) - (80.0 if menus.hotbar.visible else 0.0) - (60.0 if Game.touch else 0.0))
	dialog_panel.position = Vector2(vs.x * 0.5 - dialog_panel.size.x * 0.5, vs.y - dialog_panel.size.y - 40)
	banner_panel.position = Vector2(vs.x * 0.5 - banner_panel.size.x * 0.5, 215)

	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_t = 0.4
		_reveal(world.player["pos"])
	if ledger_panel.visible:
		_ledger_t -= delta
		if _ledger_t <= 0.0:
			_ledger_t = 0.5
			ledger_label.text = _ledger_text(world)
			_settle_status.text = _settle_line()
		ledger_panel.position = Vector2(vs.x * 0.5 - ledger_panel.size.x * 0.5, 80)


## The knock-out card: what hit you, what it cost, where you wake up. Shown
## after the tear effect; "Get up" runs `on_ok` (respawn).
func show_death(info: Dictionary, on_ok: Callable) -> void:
	if _death != null:
		_death.queue_free()
	_death_open = true
	_death = _panel(NOTE, 1)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_death.add_child(vb)
	var t := _label("Knocked out", 40, Color(0.7, 0.18, 0.12))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var lines := ["%s got the better of you." % str(info["by"]),
		"The guards kept %d coins as a fee." % int(info["lost"]) if int(info["lost"]) > 0 else "You had nothing to lose, so the guards kept nothing.",
		"You will wake up in %s." % str(info["town"])]
	for l in lines:
		var lb := _label(l, 20)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lb)
	var ok := _button("Get up", GOLD)
	ok.add_theme_font_size_override("font_size", 28)
	ok.pressed.connect(func() -> void:
		_death_open = false
		_death.queue_free()
		_death = null
		on_ok.call())
	vb.add_child(ok)
	root.add_child(_death)
	_death.modulate.a = 0.0
	_death.reset_size()
	var vs := root.get_viewport_rect().size
	_death.position = ((vs - _death.size) * 0.5).floor()
	_death.pivot_offset = _death.size * 0.5
	_death.scale = Vector2(0.8, 0.8)
	var tw := _death.create_tween()
	tw.tween_interval(1.1 if DisplayServer.get_name() != "headless" else 0.0)
	tw.tween_property(_death, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_death, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Little coins fly from the hero to the purse when money comes in.
func _coin_fly(n: int) -> void:
	var vs := root.get_viewport_rect().size
	var to := coin_label.global_position + Vector2(10, 10)
	for i in n:
		var tr := _icon("coins_stacks_of_dollars", 26)
		tr.modulate = GOLD
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		var from := vs * 0.5 + Vector2(randf_range(-30, 30), randf_range(-60, 0))
		tr.position = from
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -120)
		var tw := tr.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(tr, "position", mid, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "position", to, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(tr.queue_free)


func reveal_town(tn: Dictionary) -> void:
	_reveal((tn["rect"] as Rect2).get_center(), 18)


func _reveal(p: Vector2, r := 16) -> void:
	var c := Vector2i(int(p.x / World.TILE) - World.T0.x, int(p.y / World.TILE) - World.T0.y)
	var changed := false
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if i * i + j * j > r * r:
				continue
			var x := c.x + i
			var y := c.y + j
			if x < 0 or y < 0 or x >= World.TN.x or y >= World.TN.y:
				continue
			if fog.get_pixel(x, y).a > 0.0:
				fog.set_pixel(x, y, Color(0, 0, 0, 0))
				changed = true
	if changed:
		fog_tex.update(fog)


# ---------- drawn widgets ----------

## The map: the world picture, fog over unexplored land, the town, places,
## the hero arrow and the quest pin. mini = true follows the player.
class MapView:
	extends Control
	var hud: Hud
	var mini := false
	const SPAN := 46.0

	func _to_map(px: Vector2) -> Vector2:
		return px / World.TILE - Vector2(World.T0)

	func _view() -> Rect2:
		if mini:
			var c := _to_map(hud.main.player["pos"])
			return Rect2(c - Vector2(SPAN, SPAN), Vector2(SPAN, SPAN) * 2.0)
		return Rect2(Vector2.ZERO, Vector2(World.TN))

	func _pt(px: Vector2) -> Vector2:
		var v := _view()
		return (_to_map(px) - v.position) / v.size * size

	var _frame: CardBox

	func _draw() -> void:
		var v := _view()
		var rect := Rect2(Vector2.ZERO, size)
		if mini:
			if _frame == null:
				_frame = CardBox.new(Hud.PAPER, 41, 0.0)
				_frame.tape = 2
			_frame.draw(get_canvas_item(), rect.grow(9))
		draw_rect(rect.grow(2), Hud.INK)
		draw_texture_rect_region(hud.map_tex, rect, v)
		draw_texture_rect_region(hud.fog_tex, rect, v)
		var main = hud.main
		# roads between the cities, then each city's walls
		for road in main.world.roads:
			var pts := PackedVector2Array()
			for q in road:
				pts.append(_pt(Vector2(q) * World.TILE))
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.55, 0.40, 0.25, 0.8), 3.0 if not mini else 2.0, true)
		var font0 := get_theme_default_font()
		for tn in main.towns:
			var tr: Rect2 = tn["rect"]
			var a0 := _pt(tr.position)
			var e0 := _pt(tr.end)
			draw_rect(Rect2(a0, e0 - a0), Color(0.86, 0.76, 0.60, 0.6))
			draw_rect(Rect2(a0, e0 - a0), Color(0.20, 0.13, 0.08, 0.6), false, 1.5)
			if not mini:
				var nm: String = tn["name"]
				var cx := (a0.x + e0.x) * 0.5 - 70.0
				draw_string_outline(font0, Vector2(cx, a0.y - 6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 18, 6, Hud.NOTE)
				draw_string(font0, Vector2(cx, a0.y - 6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 18, Hud.INK)
		for b in main.buildings:
			var r: Rect2 = b["rect"]
			var a := _pt(r.position)
			var e := _pt(r.end)
			draw_rect(Rect2(a, e - a), Color(0.75, 0.40, 0.30) if b["shop"] else Color(0.60, 0.50, 0.40))
		var font := get_theme_default_font()
		for l in main.world.landmarks:
			var p := _pt(l["pos"])
			if not rect.grow(-4).has_point(p):
				continue
			var known: bool = main.discovered.get(l["id"], false)
			draw_circle(p, 9.0 if not mini else 6.0, Hud.NOTE if known else Color(0.8, 0.7, 0.5))
			draw_arc(p, 9.0 if not mini else 6.0, 0, TAU, 16, Hud.INK, 2.0)
			if known:
				var ic := Cardboard.icon(l["icon"])
				if ic != null:
					var s := 12.0 if not mini else 8.0
					draw_texture_rect(ic, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Hud.INK)
				if not mini:
					draw_string_outline(font, p + Vector2(-60, 26), l["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 5, Hud.NOTE)
					draw_string(font, p + Vector2(-60, 26), l["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Hud.INK)
			elif not mini:
				draw_string(font, p + Vector2(-10, 6), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Hud.INK)
		for n in main.npcs:
			if n is Merchant:
				var np := _pt(n.pos)
				if rect.has_point(np):
					draw_rect(Rect2(np - Vector2(3, 3), Vector2(6, 6)), Hud.GOLD)
					draw_rect(Rect2(np - Vector2(3, 3), Vector2(6, 6)), Hud.INK, false, 1.2)
		if mini:
			for m in main.monsters:
				var mp := _pt(m.pos)
				if rect.has_point(mp):
					draw_circle(mp, 3.0 if m.kind != "boss" else 6.0, Color(0.85, 0.2, 0.2))
		var q: Dictionary = main.quests.current()
		if not q.is_empty():
			var tp := _pt(main.quests.target_of(main, q))
			tp = tp.clamp(Vector2(8, 8), size - Vector2(8, 8))
			draw_colored_polygon(PackedVector2Array([tp, tp + Vector2(-7, -14), tp + Vector2(7, -14)]), Hud.GOLD)
			draw_circle(tp + Vector2(0, -16), 7.0, Hud.GOLD)
			draw_arc(tp + Vector2(0, -16), 7.0, 0, TAU, 14, Hud.INK, 2.0)
		var pp := _pt(main.player["pos"])
		var hd: Vector2 = main.player["heading"]
		var ang := hd.angle()
		var tri := PackedVector2Array([pp + Vector2(10, 0).rotated(ang), pp + Vector2(-6, 6).rotated(ang), pp + Vector2(-6, -6).rotated(ang)])
		draw_colored_polygon(tri, Color(0.9, 0.25, 0.25))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Hud.INK, 2.0)
		draw_rect(rect, Hud.INK, false, 2.5)
		if mini:
			draw_string_outline(font, Vector2(size.x * 0.5 - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Hud.NOTE)
			draw_string(font, Vector2(size.x * 0.5 - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Hud.INK)

	static func TILE_PX() -> float:
		return 1.0 * World.TILE

	func _gui_input(ev: InputEvent) -> void:
		if mini or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
			return
		for l in hud.main.world.landmarks:
			if _pt(l["pos"]).distance_to(ev.position) < 16.0 and hud.main.discovered.get(l["id"], false):
				hud.main.fast_travel(l["id"])
				return


## A rounded gauge: icon badge, an inset fill, a pale trail that drains behind
## it, a gloss line and the number. Pulses when low.
class Gauge:
	extends Control
	var value := 100.0
	var maxv := 100.0
	var col := Color.RED
	var glyph := "heart"
	var tired := false
	var _shown := 1.0
	var _trail := 1.0
	var _seed := 0.0

	func _init(c: Color, g: String, w := 190.0, h := 18.0) -> void:
		col = c
		glyph = g
		_seed = float(hash(g) % 997)
		custom_minimum_size = Vector2(w, h)
		size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, m: float) -> void:
		value = v
		maxv = maxf(m, 1.0)

	func _process(delta: float) -> void:
		var f := clampf(value / maxv, 0.0, 1.0)
		_shown = lerpf(_shown, f, 1.0 - exp(-delta * 14.0))
		_trail = f if f > _trail else move_toward(_trail, f, delta * 0.35)
		queue_redraw()

	## Cheap repeatable "random" in [-1, 1] for hand-drawn jitter.
	func _j(i: float, k := 0.0) -> float:
		return sin((i + _seed) * 12.9898 + k * 78.233) * 0.5 + sin((i + _seed) * 4.1 + k * 1.7) * 0.5

	## Marker hatching: many separate, slightly different slanted strokes laid
	## side by side, overshooting the edges, so it reads as colouring-in.
	func _hatch(x0: float, x1: float, y0: float, y1: float, c: Color, w: float, step: float, slant: float, ph: float) -> void:
		var x := x0
		var i := 0
		while x < x1:
			var j1 := _j(i, ph)
			var j2 := _j(i, ph + 3.0)
			var j3 := _j(i, ph + 6.0)
			var xa := x + j1 * 1.2
			var xb := xa + slant * (1.0 + j2 * 0.35)
			var ya := y1 + 1.0 + (j2 * 0.5 + 0.5) * 1.8
			var yb := y0 - 1.0 - (j3 * 0.5 + 0.5) * 1.8
			xb = minf(xb, x1 + 1.5)
			draw_line(Vector2(xa, ya), Vector2(xb, yb), c, w * (0.85 + 0.3 * (j3 * 0.5 + 0.5)), true)
			draw_circle(Vector2(xa, ya), w * 0.45, c)
			draw_circle(Vector2(xb, yb), w * 0.45, c)
			x += step * (0.75 + 0.5 * (j1 * 0.5 + 0.5))
			i += 1

	## A loose pencil underline for the empty part of the bar.
	func _underline(x0: float, x1: float, y: float, c: Color) -> void:
		for pass_i in 2:
			var pts := PackedVector2Array()
			var n := maxi(3, int((x1 - x0) / 18.0))
			for k in n + 1:
				var f := float(k) / float(n)
				pts.append(Vector2(lerpf(x0, x1, f) + (pass_i * 2.0), y + _j(k, pass_i * 2.0) * 0.9 + pass_i * 1.2))
			draw_polyline(pts, Color(c.r, c.g, c.b, c.a * (1.0 if pass_i == 0 else 0.5)), 1.6, true)

	func _draw() -> void:
		var h := size.y
		var ink_c := Color(0.20, 0.13, 0.08, 0.92)
		var c := col
		if tired:
			c = Color(0.58, 0.55, 0.50)
		elif _shown < 0.3:
			c = col.lerp(Color(1, 1, 1), 0.2 + 0.18 * sin(Time.get_ticks_msec() * 0.012))
		# the icon: a pen-drawn ring with the sign inside
		var r := h * 0.5 + 1.0
		var cc := Vector2(r, h * 0.5)
		var ring := PackedVector2Array()
		for k in 15:
			var a := TAU * float(k) / 14.0
			ring.append(cc + Vector2(cos(a), sin(a)) * (r - 1.0 + _j(k, 1.0) * 0.5))
		draw_polyline(ring, ink_c, 2.0, true)
		if glyph == "bolt":
			var bolt := PackedVector2Array([cc + Vector2(1.5, -r * 0.5), cc + Vector2(-r * 0.38, 1), cc + Vector2(-0.5, 1), cc + Vector2(-1.5, r * 0.5), cc + Vector2(r * 0.38, -1.5), cc + Vector2(0.5, -1.5)])
			draw_colored_polygon(bolt, c.darkened(0.1))
			draw_polyline(PackedVector2Array([bolt[0], bolt[1], bolt[2], bolt[3], bolt[4], bolt[5], bolt[0]]), ink_c, 1.2, true)
		else:
			var ic := Cardboard.icon(glyph)
			if ic != null:
				var s := r * 1.15
				draw_texture_rect(ic, Rect2(cc - Vector2(s, s) * 0.5, Vector2(s, s)), false, c.darkened(0.25))
		# the track is a pencil underline; the colour is hatched over it like a marker
		var left := r * 2.0 + 6.0
		var bar := Rect2(left, 1.5, size.x - left - 40.0, h - 3.0)
		var slant := bar.size.y * 0.55
		_underline(bar.position.x, bar.end.x, bar.end.y + 0.5, Color(0.38, 0.26, 0.15, 0.7))
		# empty part: faint pencil ticks so the length reads
		var xe := bar.position.x + bar.size.x * _shown
		_hatch(xe + 3.0, bar.end.x, bar.position.y + 3.0, bar.end.y - 2.0, Color(0.45, 0.33, 0.2, 0.22), 1.1, 10.0, slant * 0.7, 9.0)
		if _trail > _shown + 0.004:
			_hatch(xe, bar.position.x + bar.size.x * _trail, bar.position.y + 1.0, bar.end.y, Color(0.55, 0.45, 0.35, 0.55), 2.4, 4.0, slant, 4.0)
		if _shown > 0.004:
			var x1 := bar.position.x + maxf(6.0, bar.size.x * _shown)
			_hatch(bar.position.x, x1, bar.position.y, bar.end.y, Color(c.r, c.g, c.b, 0.96), 3.4, 3.6, slant, 0.0)
			_hatch(bar.position.x + 2.0, x1, bar.position.y + 1.0, bar.end.y - 1.0, Color(c.r * 0.82, c.g * 0.82, c.b * 0.82, 0.55), 2.2, 6.5, -slant, 2.0)
		# the number, in plain ink beside the bar
		var font := Hud.head_font_static
		var txt := "%d" % int(ceil(value))
		var fs := 17 if h >= 22.0 else 15
		draw_string(font, Vector2(bar.end.x + 7.0, h * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, 40, fs, Color(0.17, 0.11, 0.07))


## The player's portrait: a front-view photo card with a taped corner,
## slightly crooked, as if pinned to the board.
class PortraitFrame:
	extends Control
	var texture: Texture2D:
		set(v):
			texture = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(98, 112)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_set_transform(c, -0.05, Vector2.ONE)
		var card := Rect2(-size * 0.5 + Vector2(5, 4), size - Vector2(10, 8))
		draw_rect(Rect2(card.position + Vector2(2, 3), card.size), Color(0.14, 0.08, 0.04, 0.2))
		draw_rect(card, Color(0.99, 0.96, 0.88))
		draw_rect(card, Color(0.20, 0.13, 0.08, 0.9), false, 1.8)
		var pic := Rect2(card.position + Vector2(6, 6), Vector2(card.size.x - 12, card.size.y - 24))
		draw_rect(pic, Color(0.72, 0.86, 0.95))
		# a little cut-paper hill and sun behind the head
		draw_circle(pic.position + Vector2(pic.size.x * 0.78, pic.size.y * 0.24), 9.0, Color(1.0, 0.88, 0.45))
		draw_colored_polygon(PackedVector2Array([Vector2(pic.position.x, pic.end.y), Vector2(pic.position.x, pic.end.y - 22), Vector2(pic.position.x + pic.size.x * 0.5, pic.end.y - 32), Vector2(pic.end.x, pic.end.y - 16), Vector2(pic.end.x, pic.end.y)]), Color(0.56, 0.78, 0.46))
		if texture != null:
			var ts := texture.get_size()
			var k := minf(pic.size.x / ts.x, pic.size.y / ts.y) * 1.02
			var ds := ts * k
			draw_texture_rect(texture, Rect2(Vector2(pic.get_center().x - ds.x * 0.5, pic.end.y - ds.y), ds), false)
		draw_rect(pic, Color(0.20, 0.13, 0.08, 0.85), false, 1.6)
		# a handwritten strip along the bottom
		draw_line(Vector2(card.position.x + 14, card.end.y - 9), Vector2(card.end.x - 14, card.end.y - 9), Color(0.20, 0.13, 0.08, 0.35), 1.6)
		# tape across the top
		var tape := PackedVector2Array([Vector2(-26, card.position.y - 7), Vector2(24, card.position.y - 10), Vector2(26, card.position.y + 8), Vector2(-24, card.position.y + 11)])
		draw_colored_polygon(tape, Color(0.98, 0.93, 0.74, 0.8))
		draw_polyline(PackedVector2Array([tape[0], tape[1], tape[2], tape[3], tape[0]]), Color(0.62, 0.52, 0.30, 0.5), 1.0)


## A round minimap that turns with the camera (what is ahead of you is up),
## ringed in cardboard with a gold N that always points north.
class RoundMap:
	extends Control
	var hud: Hud
	const SPAN := 34.0
	const RAD := 88.0
	var _rot := 0.0
	var _c := Vector2.ZERO
	var _ctr := Vector2.ZERO
	var _tag := StyleBoxFlat.new()

	func _init() -> void:
		_tag.bg_color = Hud.NOTE
		_tag.set_corner_radius_all(11)
		_tag.set_border_width_all(2)
		_tag.border_color = Hud.INK
		_tag.anti_aliasing = true

	func _pt(px: Vector2) -> Vector2:
		var v := (px / World.TILE - Vector2(World.T0) - _c) / SPAN
		return _ctr + v.rotated(_rot) * RAD

	func _inside(p: Vector2) -> bool:
		return p.distance_to(_ctr) < RAD - 5.0

	func _disc(tex: Texture2D, tint: Color) -> void:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var n := 64
		for i in n:
			var a := TAU * i / n
			var dir := Vector2(cos(a), sin(a))
			pts.append(_ctr + dir * RAD)
			uvs.append((_c + dir.rotated(-_rot) * SPAN) / Vector2(World.TN))
			cols.append(tint)
		draw_polygon(pts, cols, uvs, tex)

	func _draw() -> void:
		var main = hud.main
		_ctr = Vector2(size.x * 0.5, RAD + 14.0)
		_c = main.player["pos"] / World.TILE - Vector2(World.T0)
		var f: Vector2 = main._cam_forward()
		_rot = -PI * 0.5 - f.angle()
		# frame: a cardboard ring with a soft shadow
		draw_circle(_ctr + Vector2(3, 5), RAD + 11.0, Color(0.17, 0.11, 0.07, 0.3))
		draw_circle(_ctr, RAD + 11.0, Hud.INK)
		draw_circle(_ctr, RAD + 8.0, Hud.PAPER)
		draw_circle(_ctr, RAD + 1.5, Hud.INK)
		draw_circle(_ctr, RAD, Color(0.9, 0.82, 0.62))
		_disc(hud.map_tex, Color.WHITE)
		_disc(hud.fog_tex, Color.WHITE)
		# town and buildings
		for b in main.buildings:
			var r: Rect2 = b["rect"]
			var q := _pt(r.get_center())
			if _inside(q):
				draw_circle(q, 3.0, Color(0.78, 0.40, 0.30) if b["shop"] else Color(0.55, 0.45, 0.36))
		var font := get_theme_default_font()
		var here := ""
		for l in main.world.landmarks:
			var lp := _pt(l["pos"])
			if main.discovered.get(l["id"], false) and (l["pos"] as Vector2).distance_to(main.player["pos"]) < (float(l["r"]) + 5.0) * World.TILE:
				here = l["name"]
			if not _inside(lp):
				continue
			var known: bool = main.discovered.get(l["id"], false)
			draw_circle(lp, 8.0, Hud.NOTE if known else Color(0.8, 0.7, 0.5))
			draw_arc(lp, 8.0, 0, TAU, 16, Hud.INK, 2.0, true)
			var ic := Cardboard.icon(l["icon"]) if known else null
			if ic != null:
				draw_texture_rect(ic, Rect2(lp - Vector2(5, 5), Vector2(10, 10)), false, Hud.INK)
		for m in main.monsters:
			var mp := _pt(m.pos)
			if _inside(mp):
				var big: bool = m.kind == "boss"
				var cc := Color(0.85, 0.15, 0.15) if m.tier < 2 else Color(1.0, 0.1, 0.45)
				draw_circle(mp, 6.5 if big else 3.6, Hud.INK)
				draw_circle(mp, 5.0 if big else 2.6, cc)
		var q: Dictionary = main.quests.current()
		if not q.is_empty():
			var tp := _pt(main.quests.target_of(main, q))
			var rel := tp - _ctr
			if rel.length() > RAD - 10.0:
				tp = _ctr + rel.normalized() * (RAD - 10.0)
			draw_circle(tp, 8.0, Hud.INK)
			draw_circle(tp, 6.0, Hud.GOLD)
			draw_circle(tp, 2.2, Hud.INK)
		# me, always pointing up the way the camera looks relative to heading
		var hd: Vector2 = main.player["heading"]
		var ang := hd.rotated(_rot).angle()
		var tri := PackedVector2Array([_ctr + Vector2(11, 0).rotated(ang), _ctr + Vector2(-7, 7).rotated(ang), _ctr + Vector2(-3.5, 0).rotated(ang), _ctr + Vector2(-7, -7).rotated(ang)])
		draw_colored_polygon(tri, Color(0.95, 0.3, 0.3))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Hud.INK, 2.0, true)
		# bezel ticks and compass letters turn with the world
		for i in 24:
			var a := TAU * i / 24.0 + _rot
			var d := Vector2(cos(a), sin(a))
			var long := i % 6 == 0
			draw_line(_ctr + d * (RAD + 2.0), _ctr + d * (RAD + (7.0 if long else 4.5)), Hud.INK, 2.0 if long else 1.2, true)
		var letters := {"E": Vector2(1, 0), "S": Vector2(0, 1), "W": Vector2(-1, 0)}
		for k in letters:
			var p: Vector2 = _ctr + (letters[k] as Vector2).rotated(_rot) * (RAD - 11.0)
			draw_string(font, p + Vector2(-5, 5), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Hud.INK.lightened(0.15))
		var np := _ctr + Vector2(0, -1).rotated(_rot) * (RAD + 4.0)
		draw_circle(np, 13.0, Hud.INK)
		draw_circle(np, 11.0, Hud.GOLD)
		draw_string(font, np + Vector2(-6, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Hud.INK)
		# place name
		var name := here if here != "" else ("Sunny Town" if main.player_in_town() else "The Wilds")
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x + 22.0
		var tr := Rect2(_ctr.x - tw * 0.5, _ctr.y + RAD + 12.0, tw, 24.0)
		draw_style_box(_tag, tr)
		draw_string(font, Vector2(tr.position.x, tr.position.y + 17.0), name, HORIZONTAL_ALIGNMENT_CENTER, tw, 16, Hud.INK)


## A little pill showing the NEAR link: a coloured dot (live / dry run /
## offline), a short status, and a click opens the ledger with transaction
## links. The dot pulses while a day is being settled.
class NearChip:
	extends Control
	var hud: Hud
	var _card: CardBox
	var _text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_card = CardBox.new(Hud.NOTE, 77, 0.0)
		_card.torn = CardBox.LEFT
		_card.rip = 5.0
		_card.cut = 4.0
		_card.line = 1.8
		_card.tape = 0
		_card.shadow = Vector2(1, 2)
		tooltip_text = "NEAR settlement status - click for the ledger"

	func refresh() -> void:
		_text = Chain.chip_text()
		var font: Font = Hud.head_font_static
		var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 52.0
		custom_minimum_size = Vector2(w, 28)
		size = Vector2(w, 28)
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hud.toggle_ledger()

	func _draw() -> void:
		draw_style_box(_card, Rect2(Vector2.ZERO, size))
		var col := Color(0.55, 0.52, 0.48)
		match Chain.mode:
			"testnet":
				col = Color(0.26, 0.62, 0.30)
			"dry-run":
				col = Color(0.88, 0.52, 0.12)
		var busy := false
		for e in Chain.day_log:
			if e["status"] == "sending":
				busy = true
		var r := 7.0 + (1.5 * sin(Time.get_ticks_msec() * 0.012) if busy else 0.0)
		var c := Vector2(20, 14)
		# a marker blot with a loose pen ring, like a stamp pad dab
		for k in 7:
			var f := float(k) / 6.0
			draw_line(c + Vector2(-r * 0.7 + f * r * 1.4, r * 0.8), c + Vector2(-r * 0.3 + f * r * 1.4, -r * 0.8), Color(col.r, col.g, col.b, 0.95), 3.0, true)
		var ring := PackedVector2Array()
		for k in 16:
			var a := TAU * float(k) / 15.0 * 0.97
			ring.append(c + Vector2(cos(a), sin(a)) * (r + 1.5 + sin(k * 2.3) * 0.5))
		draw_polyline(ring, Color(0.20, 0.13, 0.08, 0.85), 1.6, true)
		draw_string(Hud.head_font_static, Vector2(34, 19), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Hud.INK)


## The title lettering: stamped paper letters that each sit a little crooked,
## on a torn-paper plaque, with a ribbon for the tagline.
class TitleArt:
	extends Control
	var hud: Hud

	func _stamp(font: Font, text: String, centre: Vector2, size: int, seed_off: float, fill: Color) -> void:
		var widths: Array[float] = []
		var total := 0.0
		for ch in text:
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			widths.append(w)
			total += w
		var x := centre.x - total * 0.5
		for i in text.length():
			var ch := text[i]
			if ch != " ":
				var ang := sin(i * 1.9 + seed_off) * 0.055
				var dy := cos(i * 2.3 + seed_off) * size * 0.04
				var at := Vector2(x + widths[i] * 0.5, centre.y + dy)
				draw_set_transform(at, ang, Vector2.ONE)
				var base := Vector2(-widths[i] * 0.5, size * 0.34)
				draw_string_outline(font, base + Vector2(7, 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 22, Color(0.17, 0.11, 0.07, 0.45))
				draw_string_outline(font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 20, Hud.INK)
				draw_string(font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)
				draw_string(font, base + Vector2(0, -3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill.lightened(0.25) * Color(1, 1, 1, 0.0))
			x += widths[i]
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw() -> void:
		var vs := size
		var font: Font = hud._title_font
		var s1 := int(clampf(vs.y * 0.17, 70.0, 150.0))
		var cy := vs.y * 0.26
		# dim the world a little so the lettering reads
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.07, 0.04, 0.22))
		# rough torn cardboard plaque behind the lettering
		var w := minf(vs.x * 0.64, 820.0)
		var h := s1 * 2.0
		var c := Vector2(vs.x * 0.5, cy + s1 * 0.12)
		var plaque := CardBox.new(Hud.PAPER, 41, 0.0)
		plaque.cut = 10.0
		plaque.rip = 12.0
		plaque.torn = CardBox.BOTTOM | CardBox.RIGHT
		plaque.line = 3.0
		plaque.shadow = Vector2(8, 11)
		plaque.tape = 2
		draw_style_box(plaque, Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)))
		# the name, two words stacked
		var words := Game.TITLE.to_upper().split(" ")
		if words.size() == 1:
			var fs := int(minf(s1 * 1.35, w * 0.92 / (float(words[0].length()) * 0.6)))
			_stamp(font, words[0], Vector2(vs.x * 0.5, cy + s1 * 0.12 - fs * 0.05), fs, -1.5, Hud.GOLD)
		else:
			_stamp(font, words[0], Vector2(vs.x * 0.5, cy - s1 * 0.42), s1, 0.0, Hud.GOLD)
		if words.size() > 1:
			_stamp(font, words[1], Vector2(vs.x * 0.5, cy + s1 * 0.62), int(s1 * 0.92), 2.0, Color(0.99, 0.97, 0.90))
		# ribbon with the tagline
		var rf: Font = hud.head_font
		var rs := 24
		var tw := rf.get_string_size(Game.TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x + 70.0
		var ry := c.y + h * 0.5 + 12.0
		var rb := Rect2(vs.x * 0.5 - tw * 0.5, ry, tw, 40.0)
		var tail_l := PackedVector2Array([rb.position + Vector2(0, 6), rb.position + Vector2(-26, 6), rb.position + Vector2(-12, 26), rb.position + Vector2(-26, 46), rb.position + Vector2(0, 40)])
		var tail_r := PackedVector2Array([rb.end + Vector2(0, -34), rb.end + Vector2(26, -34), rb.end + Vector2(12, -14), rb.end + Vector2(26, 6), rb.end + Vector2(0, 0)])
		for poly in [tail_l, tail_r]:
			draw_colored_polygon(poly, Color(0.80, 0.34, 0.30))
			var pr: PackedVector2Array = poly.duplicate()
			pr.append(poly[0])
			draw_polyline(pr, Hud.INK, 3.0, true)
		var ribbon_box := CardBox.new(Color(0.93, 0.45, 0.40), 77, 0.0)
		ribbon_box.cut = 5.0
		ribbon_box.rip = 6.0
		ribbon_box.torn = CardBox.LEFT | CardBox.RIGHT
		ribbon_box.tape = 0
		ribbon_box.shadow = Vector2(4, 6)
		draw_style_box(ribbon_box, rb)
		draw_string(rf, Vector2(rb.position.x, rb.position.y + 29), Game.TAGLINE, HORIZONTAL_ALIGNMENT_CENTER, rb.size.x, rs, Color(1, 0.97, 0.9))


## A strip at the top: bearings relative to the camera, places, quest pin.
class Compass:
	extends Control
	var hud: Hud

	func _x_for(dir: Vector2) -> float:
		var f: Vector2 = hud.main._cam_forward()
		var a := atan2(f.cross(dir), f.dot(dir))
		return size.x * 0.5 + a / (PI * 0.5) * size.x * 0.5

	var _box: CardBox

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if _box == null:
			_box = CardBox.new(Hud.NOTE, 77, 0.0)
			_box.shadow = Vector2(2, 3)
			_box.ply = false
			_box.radius = 18.0
			_box.line = 2.5
		_box.draw(get_canvas_item(), rect)
		var font := get_theme_default_font()
		var dirs := {"N": Vector2(0, -1), "E": Vector2(1, 0), "S": Vector2(0, 1), "W": Vector2(-1, 0)}
		for k in dirs:
			var x := _x_for(dirs[k])
			if x > 8 and x < size.x - 8:
				draw_string(font, Vector2(x - 6, 27), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Hud.INK)
		for i in 16:
			var a := TAU * i / 16.0
			var x2 := _x_for(Vector2(cos(a), sin(a)))
			if x2 > 4 and x2 < size.x - 4:
				draw_line(Vector2(x2, 32), Vector2(x2, 38), Hud.INK, 1.5)
		var main = hud.main
		var p: Vector2 = main.player["pos"]
		for l in main.world.landmarks:
			if not main.discovered.get(l["id"], false):
				continue
			var x3 := _x_for((l["pos"] - p).normalized())
			if x3 > 10 and x3 < size.x - 10:
				var ic := Cardboard.icon(l["icon"])
				if ic != null:
					draw_texture_rect(ic, Rect2(x3 - 8, 4, 16, 16), false, Hud.INK.lightened(0.3))
		var q: Dictionary = main.quests.current()
		if not q.is_empty():
			var tp: Vector2 = main.quests.target_of(main, q)
			var x4 := clampf(_x_for((tp - p).normalized()), 10, size.x - 10)
			draw_colored_polygon(PackedVector2Array([Vector2(x4, 36), Vector2(x4 - 8, 20), Vector2(x4 + 8, 20)]), Hud.GOLD)
			draw_circle(Vector2(x4, 16), 8.0, Hud.GOLD)
			draw_arc(Vector2(x4, 16), 8.0, 0, TAU, 14, Hud.INK, 2.0)
			draw_string(font, Vector2(x4 + 12, 18), "%dm" % int(p.distance_to(tp) * World.K), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Hud.INK)


## Screen overlay: an arrow at the screen edge pointing to an off-screen
## quest target, or a distance tag under the 3D marker when it is visible.
class Overlay:
	extends Control
	var hud: Hud

	func _draw() -> void:
		var main = hud.main
		if not Game.started or main.camera == null:
			return
		var hpf: float = float(main.player["hp"]) / float(main.player["max_hp"])
		if hpf < 0.35:
			var a := (0.35 - hpf) * 1.6 * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008))
			for i in 6:
				var w := 6.0 + i * 7.0
				var c := Color(0.75, 0.05, 0.05, a * (1.0 - i / 6.0) * 0.5)
				draw_rect(Rect2(0, 0, size.x, w), c)
				draw_rect(Rect2(0, size.y - w, size.x, w), c)
				draw_rect(Rect2(0, 0, w, size.y), c)
				draw_rect(Rect2(size.x - w, 0, w, size.y), c)
		var hits := int(main.player["combo_hits"])
		if hits >= 2 and float(main.player["combo_show"]) > 0.0:
			var fnt := Hud.head_font_static
			var txt := "%d HIT" % hits
			var sz := 54 + mini(hits, 8) * 5
			var at := Vector2(size.x - 250, size.y * 0.42)
			var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02)
			draw_set_transform(at, -0.08, Vector2(pulse, pulse))
			draw_string_outline(fnt, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 12, Hud.INK)
			draw_string(fnt, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Hud.GOLD.lerp(Color(1, 0.45, 0.25), minf(hits / 10.0, 1.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var q: Dictionary = main.quests.current()
		if q.is_empty():
			return
		var tp: Vector2 = main.quests.target_of(main, q)
		var w3: Vector3 = main._to3(tp) + Vector3(0, 2.0, 0)
		var cam: Camera3D = main.camera
		var dist := int(Vector2(main.player["pos"]).distance_to(tp) * World.K)
		var font := get_theme_default_font()
		var vs := size
		var behind := cam.is_position_behind(w3)
		var sp := cam.unproject_position(w3)
		var inner := Rect2(Vector2(60, 90), vs - Vector2(120, 200))
		if not behind and inner.has_point(sp):
			if dist > 3:
				draw_string_outline(font, sp + Vector2(-30, 40), "%dm" % dist, HORIZONTAL_ALIGNMENT_CENTER, 60, 20, 6, Hud.NOTE)
				draw_string(font, sp + Vector2(-30, 40), "%dm" % dist, HORIZONTAL_ALIGNMENT_CENTER, 60, 20, Hud.INK)
			return
		var c := vs * 0.5
		var d := sp - c
		if behind:
			d = -d
		if d.length() < 1.0:
			d = Vector2(0, -1)
		var k := minf(inner.size.x * 0.5 / maxf(absf(d.x), 0.001), inner.size.y * 0.5 / maxf(absf(d.y), 0.001))
		var at := c + d * k
		var ang := d.angle()
		var tri := PackedVector2Array([at + Vector2(22, 0).rotated(ang), at + Vector2(-10, 14).rotated(ang), at + Vector2(-10, -14).rotated(ang)])
		draw_colored_polygon(tri, Hud.GOLD)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Hud.INK, 3.0)
		var lab := "%s  %dm" % [q["title"], dist]
		draw_string_outline(font, at - Vector2(80, 26), lab, HORIZONTAL_ALIGNMENT_CENTER, 160, 18, 6, Hud.NOTE)
		draw_string(font, at - Vector2(80, 26), lab, HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Hud.INK)
