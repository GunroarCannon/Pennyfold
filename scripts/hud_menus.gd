## The menus that came with the skill tree: the character creator, the skill
## tree, the hotbar and the pause menu. They are built from the Hud's own
## cardboard helpers so they look like the rest of the UI.
class_name HudMenus
extends RefCounted

const HERO_SKINS := [Color(0.98, 0.85, 0.72), Color(0.90, 0.70, 0.54), Color(0.74, 0.54, 0.38), Color(0.54, 0.38, 0.26), Color(0.42, 0.29, 0.20), Color(1.0, 0.90, 0.80)]
const HERO_HAIRS := [Color(0.25, 0.16, 0.10), Color(0.10, 0.08, 0.07), Color(0.86, 0.68, 0.36), Color(0.64, 0.30, 0.14), Color(0.66, 0.66, 0.66), Color(0.55, 0.30, 0.55),
	Color(0.78, 0.24, 0.20), Color(0.95, 0.90, 0.78), Color(0.90, 0.55, 0.68), Color(0.30, 0.50, 0.78), Color(0.30, 0.62, 0.42), Color(0.97, 0.80, 0.30)]
const HERO_CLOTHS := [Color(0.38, 0.40, 0.46), Color(0.70, 0.30, 0.28), Color(0.30, 0.52, 0.40), Color(0.84, 0.66, 0.25), Color(0.45, 0.35, 0.62), Color(0.28, 0.46, 0.66)]
const STAT_INFO := {
	"might": ["Might", "Hits land harder."],
	"vigor": ["Vigor", "More health."],
	"spirit": ["Spirit", "More ink, and it comes back faster."],
	"swift": ["Swift", "Faster feet, more stamina."],
	"luck": ["Luck", "More critical hits."],
}
const STAT_ORDER := ["might", "vigor", "spirit", "swift", "luck"]
const BASE_POINTS := 8

var hud: Hud
var creator: PanelContainer
var skills_panel: PanelContainer
var pause_panel: PanelContainer
var day_panel: PanelContainer
var hotbar: HBoxContainer
var _hot_sig := ""
var _slots: Array = []
var _draft := {}
var _rolls := 3
var _bonus := 0
var _name_edit: LineEdit
var _wallet_edit: LineEdit
var _stat_labels := {}
var _left_label: Label
var _dice_note: Label


func _init(h: Hud) -> void:
	hud = h
	_build_hotbar()


func any_open() -> bool:
	return (creator != null and creator.visible) or (skills_panel != null and skills_panel.visible) or (pause_panel != null and pause_panel.visible) or (day_panel != null and day_panel.visible)


# ---------------- hotbar ----------------

func _build_hotbar() -> void:
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 6)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar.visible = false
	hud.root.add_child(hotbar)


func update(world, vs: Vector2) -> void:
	var act: Array = world.skills.actives()
	var sig := ",".join(PackedStringArray(act))
	if sig != _hot_sig:
		_hot_sig = sig
		for c in hotbar.get_children():
			c.queue_free()
		_slots.clear()
		for i in act.size():
			_slots.append(_make_slot(world, String(act[i]), i))
	hotbar.visible = Game.started and not act.is_empty() and not any_open()
	var ink := float(world.player["ink"])
	var stam := float(world.player["stamina"])
	for sl in _slots:
		var sk: Dictionary = world.skills.def(sl["id"])
		var cd: float = world.skills.cool_frac(sl["id"])
		var cover: ColorRect = sl["cover"]
		cover.size.y = 56.0 * cd
		var short: bool = (sk.has("ink") and ink < float(sk["ink"])) or (sk.has("stamina") and stam < float(sk["stamina"]))
		(sl["node"] as Control).modulate = Color(1, 1, 1, 0.55 if short else 1.0)
	hotbar.reset_size()
	hotbar.position = Vector2(16, vs.y - 96.0 - (300.0 if Game.touch else 0.0) - (0.0))
	if hud.log_panel != null and hud.log_panel.visible:
		hotbar.position.y = hud.log_panel.position.y - 76.0


func _make_slot(world, id: String, idx: int) -> Dictionary:
	var sk: Dictionary = world.skills.def(id)
	var p := hud._panel(Hud.NOTE)
	p.custom_minimum_size = Vector2(62, 62)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(56, 56)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	var ic := hud._icon(String(sk["icon"]), 40)
	ic.position = Vector2(8, 6)
	ic.size = Vector2(40, 40)
	ic.modulate = _branch_col(world, String(sk["branch"])).darkened(0.35)
	holder.add_child(ic)
	var cover := ColorRect.new()
	cover.color = Color(0.17, 0.11, 0.07, 0.45)
	cover.size = Vector2(56, 0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cover)
	var key := hud._label(str(idx + 1), 16)
	key.position = Vector2(3, 0)
	holder.add_child(key)
	p.tooltip_text = "%s (key %d)" % [sk["name"], idx + 1]
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			world.cast(id))
	hotbar.add_child(p)
	return {"id": id, "node": p, "cover": cover}


func _branch_col(world, branch: String) -> Color:
	for b in world.skills.data.get("branches", []):
		if b["id"] == branch:
			var c: Array = b["col"]
			return Color(c[0], c[1], c[2])
	return Hud.INK


# ---------------- skill tree ----------------

func toggle_skills() -> void:
	if skills_panel != null and skills_panel.visible:
		hud._vis(skills_panel, false)
		Sfx.play("close")
		return
	hud.close_all()
	_show_skills()


const SK_CELL := Vector2(96, 116)
const SK_NODE := 70.0

var _sk_sel := ""
var _sk_graph: Control
var _sk_detail: VBoxContainer
var _sk_pts: Label


class SkillLines:
	extends Control
	var edges: Array = []

	func _draw() -> void:
		for e in edges:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var col: Color = e[2]
			var mid := (a + b) * 0.5
			var pts := PackedVector2Array([a, Vector2(a.x, mid.y), Vector2(b.x, mid.y), b]) if absf(a.x - b.x) > 1.0 else PackedVector2Array([a, b])
			draw_polyline(pts, Color(0.12, 0.07, 0.04, 0.35), 9.0)
			draw_polyline(pts, col, 6.0)


func _sk_pos(world, s: Dictionary, slots: Dictionary) -> Vector2:
	var bi := 0
	for b in world.skills.data["branches"]:
		if b["id"] == s["branch"]:
			break
		bi += 1
	var x := float(bi * 2 + int(slots[String(s["id"])]))
	return Vector2(x, float(int(s["tier"]))) * SK_CELL + Vector2(SK_CELL.x * 0.5, 54.0 + SK_NODE * 0.5)


func _show_skills() -> void:
	var world = hud.main
	if skills_panel != null:
		skills_panel.queue_free()
	skills_panel = hud._panel(Hud.PAPER_LIGHT)
	skills_panel.visible = false
	hud.root.add_child(skills_panel)
	hud._center(skills_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	skills_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := hud._label("Skill tree", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_sk_pts = hud._label("", 24)
	head.add_child(_sk_pts)
	vb.add_child(hud._label("Tap a node. You earn a point each level. Keys 1 to 6 cast what you learn.", 16, Hud.INK.lightened(0.25)))
	_sk_graph = Control.new()
	_sk_graph.custom_minimum_size = Vector2(SK_CELL.x * 8.0, 54.0 + SK_CELL.y * 3.0 + 6.0)
	vb.add_child(_sk_graph)
	vb.add_child(HSeparator.new())
	_sk_detail = VBoxContainer.new()
	_sk_detail.custom_minimum_size = Vector2(0, 118)
	vb.add_child(_sk_detail)
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var cl := hud._button("Close (T)")
	cl.pressed.connect(func() -> void: toggle_skills())
	foot.add_child(cl)
	_sk_sel = ""
	_refresh_skills()
	hud._vis(skills_panel, true)
	Sfx.play("open")
	_fit.call_deferred(skills_panel)


func _sk_col(sk: Skills, id: String) -> Color:
	for b in sk.data["branches"]:
		if b["id"] == id:
			return Color(b["col"][0], b["col"][1], b["col"][2])
	return Color(0.5, 0.4, 0.3)


## The tree drawn as a graph: a column pair per branch, a row per tier, lines
## from each skill to what it needs. Rebuilt whenever something is learned.
func _refresh_skills() -> void:
	var world = hud.main
	var sk: Skills = world.skills
	_sk_pts.text = "%d point%s" % [sk.points, "" if sk.points == 1 else "s"]
	_sk_pts.add_theme_color_override("font_color", Hud.INK if sk.points > 0 else Hud.INK.lightened(0.4))
	for c in _sk_graph.get_children():
		c.queue_free()
	var slots := {}
	var used := {}
	for s in sk.data["skills"]:
		var key := "%s/%d" % [s["branch"], int(s["tier"])]
		slots[String(s["id"])] = int(used.get(key, 0))
		used[key] = int(used.get(key, 0)) + 1
	var bi := 0
	for b in sk.data["branches"]:
		var bc := Color(b["col"][0], b["col"][1], b["col"][2])
		var tag := hud._panel(bc.lightened(0.25))
		tag.position = Vector2(bi * 2 * SK_CELL.x + 6, 0)
		tag.custom_minimum_size = Vector2(SK_CELL.x * 2 - 12, 40)
		var tl := hud._label(String(b["name"]), 22)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_child(tl)
		_sk_graph.add_child(tag)
		bi += 1
	var lines := SkillLines.new()
	_sk_graph.add_child(lines)
	var centre := {}
	for s in sk.data["skills"]:
		centre[String(s["id"])] = _sk_pos(world, s, slots)
	for s in sk.data["skills"]:
		var id := String(s["id"])
		var bcol := _sk_col(sk, String(s["branch"]))
		var parents: Array = s["needs"].duplicate()
		if parents.is_empty() and int(s["tier"]) > 0:
			for o in sk.data["skills"]:
				if o["branch"] == s["branch"] and int(o["tier"]) == int(s["tier"]) - 1 and int(slots[String(o["id"])]) == 0:
					parents.append(String(o["id"]))
					break
		for p in parents:
			var met: bool = sk.has(String(p))
			lines.edges.append([centre[String(p)] + Vector2(0, SK_NODE * 0.5), centre[id] - Vector2(0, SK_NODE * 0.5), bcol.darkened(0.15) if met else Color(0.62, 0.55, 0.45)])
	lines.size = _sk_graph.custom_minimum_size
	lines.queue_redraw()
	for s in sk.data["skills"]:
		_sk_node(world, s, centre[String(s["id"])])
	_fill_detail()


func _sk_node(world, s: Dictionary, c: Vector2) -> void:
	var sk: Skills = world.skills
	var id := String(s["id"])
	var known := sk.has(id)
	var why := sk.why_not(id, world.career.level)
	var bcol := _sk_col(sk, String(s["branch"]))
	var fill := bcol.lightened(0.3) if known else (Hud.NOTE if why == "" else Hud.PAPER.darkened(0.08))
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = c - Vector2(SK_NODE, SK_NODE) * 0.5
	btn.custom_minimum_size = Vector2(SK_NODE, SK_NODE)
	btn.size = Vector2(SK_NODE, SK_NODE)
	var sb := hud._style(fill, 3 if id == _sk_sel else 2)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.tinted(fill.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", sb.tinted(fill.darkened(0.12)))
	btn.pressed.connect(func() -> void:
		_sk_sel = id
		Sfx.play("click")
		_refresh_skills())
	_sk_graph.add_child(btn)
	var ic := hud._icon(String(s["icon"]), 40)
	ic.position = Vector2(15, 14)
	ic.modulate = bcol.darkened(0.45) if (known or why == "") else Hud.INK.lightened(0.55)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ic)
	var label := String(s["name"]) if s["kind"] == "active" else "%s %d/%d" % [s["name"], sk.rank(id), sk.max_rank(id)]
	var nm := hud._label(label, 12)
	nm.position = Vector2((SK_NODE - SK_CELL.x) * 0.5, SK_NODE + 1)
	nm.size = Vector2(SK_CELL.x, 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(nm)
	if why == "" and not known:
		var dot := hud._label("!", 20, Hud.GOLD.darkened(0.2))
		dot.position = Vector2(SK_NODE - 16, -6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(dot)


func _fill_detail() -> void:
	var world = hud.main
	var sk: Skills = world.skills
	for c in _sk_detail.get_children():
		c.queue_free()
	if _sk_sel == "":
		_sk_detail.add_child(hud._label("Pick a skill to read about it.", 18, Hud.INK.lightened(0.3)))
		return
	var s := sk.def(_sk_sel)
	var id := _sk_sel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_sk_detail.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(hud._label(String(s["name"]), 24))
	var tx := hud._label(String(s["text"]), 16, Hud.INK.lightened(0.15))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD
	tx.custom_minimum_size = Vector2(520, 0)
	col.add_child(tx)
	var cost := ""
	if s.has("ink"):
		cost = "Costs %d ink.  " % int(s["ink"])
	elif s.has("stamina"):
		cost = "Costs %d stamina.  " % int(s["stamina"])
	var why := sk.why_not(id, world.career.level)
	var state := "Fully learned." if sk.rank(id) >= sk.max_rank(id) else ("Ready to learn." if why == "" else why)
	col.add_child(hud._label(cost + state, 15, Hud.INK.lightened(0.25)))
	if why == "":
		var b := hud._button("Learn (%d)" % int(s["cost"]), Hud.MINT)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void:
			if sk.learn(id, world.career.level):
				Sfx.play("good")
				world.career.apply_stats(world, false)
				_refresh_skills())
		row.add_child(b)


## Shrink a wide panel to fit the window and keep it centred.
func _fit(p: Control) -> void:
	if not is_instance_valid(p):
		return
	var vs := p.get_viewport_rect().size
	p.reset_size()
	var s := minf(1.0, minf((vs.x - 30.0) / maxf(p.size.x, 1.0), (vs.y - 30.0) / maxf(p.size.y, 1.0)))
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(s, s)
	p.position = (vs - p.size) * 0.5



# ---------------- character creator ----------------

func show_creator(on_done: Callable) -> void:
	if creator != null:
		creator.queue_free()
	if true:
		_draft = {"name": "", "skin": 0, "hair": 0, "cloth": 0, "style": 0, "owned": [], "equip": {}, "stats": {"might": 1, "vigor": 1, "spirit": 1, "swift": 1, "luck": 1}}
	_rolls = int(_draft.get("_r", 3))
	_bonus = int(_draft.get("_b", 0))
	creator = hud._panel(Hud.PAPER_LIGHT)
	creator.visible = false
	creator.z_index = 50
	hud.root.add_child(creator)
	hud._center(creator)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(640, 0)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	creator.add_child(split)
	var pv := VBoxContainer.new()
	pv.custom_minimum_size = Vector2(210, 0)
	split.add_child(pv)
	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = Vector2(210, 262)
	vpc.stretch = true
	pv.add_child(vpc)
	_pv_vp = SubViewport.new()
	_pv_vp.size = Vector2i(210, 262)
	_pv_vp.transparent_bg = true
	_pv_vp.own_world_3d = true
	_pv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_pv_vp)
	_pv_root = Node3D.new()
	_pv_vp.add_child(_pv_root)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	_pv_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 20, 0)
	sun.light_energy = 0.6
	_pv_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 28.0
	_pv_vp.add_child(cam)
	cam.position = Vector3(0, 1.0, 5.2)
	cam.current = true
	_pv_figure = null
	pv.add_child(hud._label("That is you.", 16, Hud.INK.lightened(0.3)))
	split.add_child(vb)
	vb.add_child(hud._label("Who are you?", 36))
	vb.add_child(hud._label("Pick a name and a look, then spend your points. Fate may add a few more.", 16, Hud.INK.lightened(0.25)))
	_pv_cute = Game.cute()
	var style := hud._button("", Hud.PAPER_LIGHT)
	style.add_theme_font_size_override("font_size", 16)
	var set_label := func() -> void:
		style.text = "Art style: %s  (tap to switch; applies when you begin)" % ("Cute" if _pv_cute else "Classic")
	set_label.call()
	style.pressed.connect(func() -> void:
		_pv_cute = not _pv_cute
		set_label.call()
		Sfx.play("click")
		_update_preview())
	vb.add_child(style)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 14
	_name_edit.add_theme_font_override("font", hud.head_font)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", Hud.INK)
	var fs := hud._style(Hud.NOTE, 1)
	fs.set_content_margin_all(8)
	_name_edit.add_theme_stylebox_override("normal", fs)
	_name_edit.add_theme_stylebox_override("focus", fs)
	vb.add_child(_name_edit)
	_name_edit.text = String(_draft.get("name", ""))
	vb.add_child(_swatch_row("Skin", "skin", HERO_SKINS.size(), func(i: int) -> Color: return HERO_SKINS[i]))
	vb.add_child(_swatch_row("Hair", "hair", HERO_HAIRS.size(), func(i: int) -> Color: return HERO_HAIRS[i]))
	vb.add_child(_swatch_row("Outfit", "cloth", HERO_CLOTHS.size(), func(i: int) -> Color: return HERO_CLOTHS[i]))
	# hairstyles: boys', girls' and everyone's. Hats are bought in shops instead.
	var styles := HFlowContainer.new()
	styles.add_theme_constant_override("h_separation", 5)
	styles.add_theme_constant_override("v_separation", 4)
	styles.custom_minimum_size = Vector2(500, 0)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	srow.add_child(_row_label("Style"))
	srow.add_child(styles)
	for i in Gear.HAIR.size():
		var b := hud._button(str(Gear.HAIR[i][0]), Hud.PAPER_LIGHT)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void:
			_draft["style"] = i
			Sfx.play("click")
			_update_preview())
		styles.add_child(b)
	vb.add_child(srow)
	vb.add_child(HSeparator.new())
	var sh := HBoxContainer.new()
	vb.add_child(sh)
	_left_label = hud._label("", 22)
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_left_label)
	var dice := hud._button("Roll the dice (%d)" % _rolls, Hud.GOLD)
	dice.add_theme_font_size_override("font_size", 18)
	sh.add_child(dice)
	_dice_note = hud._label("", 15, Hud.INK.lightened(0.2))
	vb.add_child(_dice_note)
	dice.pressed.connect(func() -> void:
		if _rolls <= 0:
			return
		_rolls -= 1
		# same number of points every time; fate only decides where they go
		_bonus = 0
		for k in STAT_ORDER:
			_draft["stats"][k] = 1
		var pool := BASE_POINTS
		while pool > 0:
			var k2: String = STAT_ORDER[randi() % STAT_ORDER.size()]
			if int(_draft["stats"][k2]) < 7:
				_draft["stats"][k2] = int(_draft["stats"][k2]) + 1
				pool -= 1
		_dice_note.text = "Fate dealt your %d points across your stats." % BASE_POINTS
		dice.text = "Roll the dice (%d)" % _rolls
		Sfx.play("coin")
		_refresh_stats())
	for k in STAT_ORDER:
		vb.add_child(_stat_row(k))
	var go := hud._button("Begin", Hud.MINT)
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(func() -> void:
		var nm := _name_edit.text.strip_edges()
		_draft["name"] = nm if nm != "" else "Traveller"
		var spare := BASE_POINTS + _bonus - _spent()
		# unspent points are not wasted: they go into Vigor
		_draft["stats"]["vigor"] = int(_draft["stats"]["vigor"]) + maxi(0, spare)
		for k in STAT_ORDER:
			_draft["stats"][k] = int(_draft["stats"][k]) + 1
		_draft["made"] = true
		var keep_owned: Variant = Game.hero.get("owned", [])
		var keep_equip: Variant = Game.hero.get("equip", {})
		Game.hero = _draft.duplicate(true)
		Game.hero["owned"] = keep_owned
		Game.hero["equip"] = keep_equip
		hud._vis(creator, false)
		var want := "cute" if _pv_cute else "real"
		if want != Game.style:
			# the world is built once per style, so a different look is one reload
			Game.style = want
			Game.started = true
			Game.via_title = true
			hud.get_tree().reload_current_scene()
			return
		on_done.call())
	vb.add_child(go)
	_refresh_stats()
	_update_preview()
	hud._vis(creator, true)
	_fit.call_deferred(creator)
	Sfx.play("open")


var _pv_cute := true
var _pv_vp: SubViewport
var _pv_root: Node3D
var _pv_figure: Node3D


func _update_preview() -> void:
	if _pv_root == null or not is_instance_valid(_pv_root):
		return
	if _pv_figure != null and is_instance_valid(_pv_figure):
		_pv_figure.queue_free()
	_pv_figure = hud.main.preview_standee(_draft, _pv_root, _pv_cute)


func _spent() -> int:
	var t := 0
	for k in STAT_ORDER:
		t += int(_draft["stats"][k]) - 1
	return t


func _row_label(t: String) -> Label:
	var l := hud._label(t, 18)
	l.custom_minimum_size = Vector2(70, 0)
	return l


func _swatch_row(title: String, key: String, n: int, color_of: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_row_label(title))
	for i in n:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(38, 30)
		var c: Color = color_of.call(i)
		var sb := hud._style(c, 2)
		sb.ply = false
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb.tinted(c.lightened(0.2)))
		b.add_theme_stylebox_override("pressed", sb.tinted(c.darkened(0.15)))
		b.pressed.connect(func() -> void:
			_draft[key] = i
			Sfx.play("click")
			_update_preview())
		row.add_child(b)
	return row


func _stat_row(k: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var info: Array = STAT_INFO[k]
	var nm := hud._label(String(info[0]), 20)
	nm.custom_minimum_size = Vector2(90, 0)
	row.add_child(nm)
	var minus := hud._button("-", Hud.PAPER_LIGHT)
	row.add_child(minus)
	var val := hud._label("1", 22)
	val.custom_minimum_size = Vector2(30, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	var plus := hud._button("+", Hud.PAPER_LIGHT)
	row.add_child(plus)
	var tx := hud._label(String(info[1]), 15, Hud.INK.lightened(0.25))
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tx)
	_stat_labels[k] = val
	minus.pressed.connect(func() -> void:
		if int(_draft["stats"][k]) > 1:
			_draft["stats"][k] = int(_draft["stats"][k]) - 1
			_refresh_stats())
	plus.pressed.connect(func() -> void:
		if BASE_POINTS + _bonus - _spent() > 0 and int(_draft["stats"][k]) < 7:
			_draft["stats"][k] = int(_draft["stats"][k]) + 1
			_refresh_stats())
	return row


func _refresh_stats() -> void:
	for k in STAT_ORDER:
		(_stat_labels[k] as Label).text = str(int(_draft["stats"][k]))
	var left := BASE_POINTS + _bonus - _spent()
	_left_label.text = "Points left: %d" % left


# ---------------- pause menu ----------------

func is_paused() -> bool:
	return pause_panel != null and pause_panel.visible


func toggle_pause() -> void:
	if is_paused():
		hud._vis(pause_panel, false)
		Sfx.play("close")
		return
	hud.close_all()
	_show_pause()


func _show_pause() -> void:
	var world = hud.main
	if pause_panel != null:
		pause_panel.queue_free()
	pause_panel = hud._panel(Hud.PAPER_LIGHT)
	pause_panel.visible = false
	hud.root.add_child(pause_panel)
	hud._center(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(520, 0)
	pause_panel.add_child(vb)
	vb.add_child(hud._label("Paused", 38))
	var c: Career = world.career
	var coins := int(Economy.wallets["player"]["coins"])
	var stats := "%s, level %d   |   %d coins   |   day %d\\n" % [Game.hero["name"], c.level, coins, world.day_number()]
	stats += "Might %d  Vigor %d  Spirit %d  Swift %d  Luck %d" % [Game.stat("might"), Game.stat("vigor"), Game.stat("spirit"), Game.stat("swift"), Game.stat("luck")]
	var sl := hud._label(stats.replace("\\n", "\n"), 18)
	vb.add_child(sl)
	vb.add_child(HSeparator.new())
	vb.add_child(hud._label("Account", 24))
	vb.add_child(_account_block())
	var chain_l := hud._label(Chain.summary() + ". " + _settle_line(), 15, Hud.INK.lightened(0.2))
	chain_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	chain_l.custom_minimum_size = Vector2(480, 0)
	vb.add_child(chain_l)
	var vrow := HBoxContainer.new()
	vrow.add_child(hud._label("Volume", 20))
	var sld := HSlider.new()
	sld.min_value = 0.0
	sld.max_value = 1.0
	sld.step = 0.05
	sld.custom_minimum_size = Vector2(240, 24)
	sld.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	sld.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))
	vrow.add_child(sld)
	vb.add_child(vrow)
	vb.add_child(hud._label("Camera", 24))
	vb.add_child(_cam_slider("Distance", 6.0, 24.0, world.cam_dist, func(v: float) -> void: world.cam_dist = v))
	vb.add_child(_cam_slider("Tilt", 0.18, 1.15, world.cam_pitch, func(v: float) -> void: world.cam_pitch = v))
	vb.add_child(_cam_slider("Field of view", 35.0, 75.0, world.cam_fov, func(v: float) -> void: world.cam_fov = v))
	vb.add_child(_cam_slider("Screen shake", 0.0, 1.5, world.cam_shake, func(v: float) -> void: world.cam_shake = v))
	var b1 := HBoxContainer.new()
	b1.add_theme_constant_override("separation", 8)
	vb.add_child(b1)
	var resume := hud._button("Resume", Hud.MINT)
	resume.add_theme_font_size_override("font_size", 24)
	resume.pressed.connect(func() -> void: toggle_pause())
	b1.add_child(resume)
	var tree := hud._button("Skill tree (T)", Hud.PAPER_LIGHT)
	tree.pressed.connect(func() -> void:
		hud._vis(pause_panel, false)
		_show_skills())
	b1.add_child(tree)
	var sett := hud._button("Settle day now", Hud.PAPER_LIGHT)
	sett.pressed.connect(func() -> void:
		Chain.settle_now(world)
		toggle_pause())
	b1.add_child(sett)
	var b2 := HBoxContainer.new()
	b2.add_theme_constant_override("separation", 8)
	vb.add_child(b2)
	var style := hud._button("Art style: " + ("Cute" if Game.cute() else "Classic"), Hud.PAPER_LIGHT)
	style.pressed.connect(func() -> void: hud._on_style())
	b2.add_child(style)
	var quit := hud._button("Quit to title", Hud.ROSE)
	quit.pressed.connect(func() -> void:
		Game.started = false
		world.get_tree().reload_current_scene())
	b2.add_child(quit)
	hud._vis(pause_panel, true)
	_fit.call_deferred(pause_panel)
	Sfx.play("open")


func _cam_slider(title: String, lo: float, hi: float, cur: float, set_fn: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := hud._label(title, 18)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var sld := HSlider.new()
	sld.min_value = lo
	sld.max_value = hi
	sld.step = (hi - lo) / 40.0
	sld.custom_minimum_size = Vector2(300, 24)
	sld.value = cur
	sld.value_changed.connect(func(v: float) -> void: set_fn.call(v))
	row.add_child(sld)
	return row


## End of a day: a card with what moved, and a button that settles it on NEAR.
func show_day_end(world, day: int) -> void:
	if day_panel != null:
		day_panel.queue_free()
	var moves: int = Chain.pending.size()
	day_panel = hud._panel(Hud.PAPER_LIGHT)
	day_panel.visible = false
	hud.root.add_child(day_panel)
	hud._center(day_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(480, 0)
	day_panel.add_child(vb)
	vb.add_child(hud._label("Day %d is done" % day, 36))
	var coins := int(Economy.wallets["player"]["coins"])
	var info := "Every coin that changed hands today is waiting in the ledger: %d move%s.
You hold %d coins." % [moves, "" if moves == 1 else "s", coins]
	var il := hud._label(info.replace("\n", "
"), 18)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD
	il.custom_minimum_size = Vector2(460, 0)
	vb.add_child(il)
	var why := hud._label("Settling nets those moves into a few transfers and sends them to NEAR testnet. Skip it and they roll into tomorrow.", 15, Hud.INK.lightened(0.2))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD
	why.custom_minimum_size = Vector2(460, 0)
	vb.add_child(why)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var go := hud._button("Settle on NEAR", Hud.GOLD)
	go.add_theme_font_size_override("font_size", 24)
	go.pressed.connect(func() -> void:
		Chain.end_of_day(day)
		hud._vis(day_panel, false))
	row.add_child(go)
	var later := hud._button("Later", Hud.PAPER_LIGHT)
	later.pressed.connect(func() -> void: hud._vis(day_panel, false))
	row.add_child(later)
	hud._vis(day_panel, true)
	_fit.call_deferred(day_panel)
	Sfx.play("open")


func _settle_line() -> String:
	var pend: int = Chain.pending.size()
	var last := -1
	for e in Chain.day_log:
		if e["status"] == "settled":
			last = int(e["day"])
	if Chain.mode == "offline":
		return "Start the relayer to settle on NEAR."
	if last >= 0:
		return "Last settled: day %d. %d moves wait for midnight." % [last, pend]
	return "Nothing settled yet. %d moves wait for midnight." % pend


func _account_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	if Game.account != "":
		var row := HBoxContainer.new()
		box.add_child(row)
		var who := hud._label(Game.account + ("   (verified)" if Chain.linked_ok else "   (not verified yet)"), 18)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		var out := hud._button("Switch / unlink", Hud.PAPER_LIGHT)
		out.add_theme_font_size_override("font_size", 16)
		out.pressed.connect(func() -> void:
			Chain.link("")
			Game.set_account("")
			_show_pause_again())
		row.add_child(out)
	elif OS.has_feature("web"):
		var conn := hud._button("Connect NEAR wallet", Hud.PAPER_LIGHT)
		conn.pressed.connect(func() -> void: JavaScriptBridge.eval("window.pennyfold && window.pennyfold.login()"))
		box.add_child(conn)
		box.add_child(hud._label("Playing as a guest. Winnings stay in the town ledger.", 15, Hud.INK.lightened(0.25)))
	else:
		var row2 := HBoxContainer.new()
		box.add_child(row2)
		_wallet_edit = LineEdit.new()
		_wallet_edit.placeholder_text = "yourname.testnet"
		_wallet_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wallet_edit.add_theme_font_override("font", hud.head_font)
		_wallet_edit.add_theme_font_size_override("font_size", 18)
		_wallet_edit.add_theme_color_override("font_color", Hud.INK)
		var fs := hud._style(Hud.NOTE, 1)
		fs.set_content_margin_all(6)
		_wallet_edit.add_theme_stylebox_override("normal", fs)
		_wallet_edit.add_theme_stylebox_override("focus", fs)
		row2.add_child(_wallet_edit)
		var ln := hud._button("Link", Hud.PAPER_LIGHT)
		ln.pressed.connect(func() -> void:
			var a := _wallet_edit.text.strip_edges().to_lower()
			if Game.valid_account(a):
				Game.set_account(a)
				Chain.link(a)
				_show_pause_again()
			else:
				Economy.message.emit("That does not look like a testnet account (name.testnet)."))
		row2.add_child(ln)
		box.add_child(hud._label("Playing as a guest. Winnings stay in the town ledger.", 15, Hud.INK.lightened(0.25)))
	return box


func _show_pause_again() -> void:
	if pause_panel != null:
		hud._vis(pause_panel, false)
	hud.get_tree().create_timer(0.25).timeout.connect(_show_pause)
