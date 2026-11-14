## Cute-mode cut-outs: chibi townsfolk (big round heads, stubby limbs, dot
## eyes) and the bestiary (fluffox, pebblet, gloop, puffcap, zapwing,
## Bramble King). The slime, mushroom, bat and boss shapes are shared with
## realistic mode, which paints them in darker colours with small mean eyes.
## Item icons for the shop are painted here too.
class_name PaintCute
extends RefCounted

const INK := Paint.INK
const WOOD := Paint.WOOD
const METAL := Paint.METAL
const BLUSH := Color(0.98, 0.52, 0.52, 0.55)


static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func E(cx: float, cy: float, rx: float, ry: float, n: int = 22) -> PackedVector2Array:
	return Paint._e(cx, cy, rx, ry, n)


static func R(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return Paint._r(x, y, w, h)


## A rounded capsule from a to b (limbs).
static func pill(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var base := (b - a).angle()
	var pts := PackedVector2Array()
	for i in 9:
		var t := base - PI * 0.5 + PI * float(i) / 8.0
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	for i in 9:
		var t := base + PI * 0.5 + PI * float(i) / 8.0
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	return pts


## Points along an ellipse arc (angles in radians, y down).
static func arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


# <<<CHIBI-A-BEGIN
## Chibi head outline modeled on the reference chibi character:
## broad rounded cranium, plump baby-cheeks, and a wide, soft flat-rounded
## bowl chin (smooth squircle jawline, never a sharp point or narrow cone).
static func head(cx: float, cy: float, rx: float, ry: float, chin: float, lean: float = 0.0, n: int = 56) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p_exp := 2.6 - chin * 0.4
	for i in n:
		var a := TAU * float(i) / float(n)
		var cos_a := cos(a)
		var sin_a := sin(a)
		var x: float
		var y: float
		if sin_a <= 0.0:
			# Upper cranium dome
			x = cos_a * rx
			y = sin_a * ry * 0.98
		else:
			# Chubby cheek swell and broad flat-rounded bowl chin (smooth squircle)
			var s := sin_a
			var c := cos_a
			var swell := pow(sin(s * PI), 0.75)
			var w := 1.0 + (0.12 if (lean > 0.0 and c > 0.0) else 0.08) * swell
			var sgn_c := 1.0 if c >= 0.0 else -1.0
			var x_val := rx * w * sgn_c * pow(absf(c), 2.0 / p_exp)
			var y_val := ry * (1.0 + chin * 0.06) * pow(s, 2.0 / p_exp)
			var x_shift := 0.0
			if lean != 0.0:
				if c > 0.0:
					x_shift = lean * pow(s, 1.2)
				else:
					x_shift = lean * 0.25 * pow(s, 1.5)
			x = x_val + x_shift
			y = y_val
		pts.append(Vector2(cx + x, cy + y))
	return pts


const OLD_HAIR := Color(0.92, 0.89, 0.80)
const CHEEK := Color(0.95, 0.52, 0.50, 0.24)


## Applies the look's "face" preset on top of the individual face traits:
## normal (nothing changes), grumpy (small eyes, bushy angry brows, big nose),
## kind (happy arcs, arched brows), sly (narrow eyes, raised dash brows),
## old (white hair, bushy white brows, moustache, crow's feet), child (huge
## round eyes, head_scale 1.16). Returns a modified copy.
static func _fx(p: Dictionary) -> Dictionary:
	var q := p.duplicate()
	match String(p.get("face", "normal")):
		"grumpy":
			q["eyes"] = "small"
			q["brows"] = "bushy"
			q["cheeks"] = "none"
			if not q.has("nose"):
				q["nose"] = "big"
		"kind":
			q["eyes"] = "happy"
			q["brows"] = "arch"
			q["cheeks"] = "blush"
		"sly":
			q["eyes"] = "narrow"
			q["brows"] = "dash"
			q["cheeks"] = "none"
		"old":
			q["eyes"] = "small"
			q["brows"] = "bushy"
			q["cheeks"] = "none"
			q["wrinkles"] = true
			q["hair"] = p.get("old_hair", OLD_HAIR)
			if not q.has("mustache"):
				q["mustache"] = true
		"child":
			q["eyes"] = "round"
			q["brows"] = "none"
			q["cheeks"] = "blush"
			if not q.has("head_scale"):
				q["head_scale"] = 1.16
	return q


## Cute face, no mouth. Traits come from the look (all optional):
## eyes: dot, tall, lash, happy, sleepy, small, round, narrow.
## brows: none, dash, arch, bold, bushy. cheeks: blush, freckles, both, none.
## glasses: bool. wrinkles: bool. face: a preset (see _fx).
## a is the left eye, b the right one; side = the three-quarter view.
static func face(c: CanvasItem, a: Vector2, b: Vector2, r: float, p0: Dictionary, side: bool) -> void:
	var p := _fx(p0)
	var eyes: String = p.get("eyes", "oval")
	var brows: String = p.get("brows", "none")
	var cheeks: String = p.get("cheeks", "blush")
	var skin: Color = p.get("skin", Color(0.98, 0.84, 0.70))
	var hair: Color = p.get("hair", Color(0.35, 0.22, 0.14))
	var dirs := [-1.0, 1.0]
	var spread := [1.25, 0.6] if side else [1.7, 1.7]
	for i in 2:
		var e: Vector2 = [a, b][i]
		var ch := e + Vector2(dirs[i] * r * spread[i], r * 1.95)
		var big := 1.0 if (not side or i == 0) else 0.82
		if cheeks in ["blush", "both"]:
			c.draw_colored_polygon(E(ch.x, ch.y, r * 1.15 * big, r * 0.62, 14), CHEEK)
		if cheeks in ["freckles", "both"]:
			for f in [Vector2(-0.55, -0.15), Vector2(0.0, 0.25), Vector2(0.55, -0.1)]:
				c.draw_circle(ch + f * r * big, r * 0.15, skin.darkened(0.38), true, -1.0, true)
	for i in 2:
		_eye(c, [a, b][i], r, eyes, dirs[i])
	if p.get("wrinkles", false):
		var wc := skin.darkened(0.3)
		for i in 2:
			var e: Vector2 = [a, b][i]
			var o: float = dirs[i]
			c.draw_line(e + Vector2(o * r * 1.5, -r * 0.5), e + Vector2(o * r * 2.2, -r * 0.9), wc, 0.8, true)
			c.draw_line(e + Vector2(o * r * 1.5, r * 0.1), e + Vector2(o * r * 2.3, r * 0.2), wc, 0.8, true)
	if brows != "none":
		var bc := hair.darkened(0.2)
		var up := r * (2.15 if eyes in ["tall", "lash"] else 1.8)
		for i in 2:
			var e: Vector2 = [a, b][i]
			var o: float = dirs[i]
			match brows:
				"dash":
					var lift := r * 0.4 * o if eyes == "narrow" else 0.0
					c.draw_colored_polygon(pill(e + Vector2(-r * 0.75, -up + lift), e + Vector2(r * 0.75, -up - lift), r * 0.26), bc)
				"bold":
					c.draw_colored_polygon(pill(e + Vector2(-r * 0.8, -up), e + Vector2(r * 0.8, -up - r * 0.1 * o), r * 0.42), bc)
				"arch":
					c.draw_polyline(arc(e.x, e.y - up + r * 0.55, r * 0.95, r * 0.6, PI * 1.12, PI * 1.88, 10), bc, r * 0.42, true)
				"bushy":
					# thick angled brow, inner end low (angry), with tufts on top
					var bb := hair.darkened(0.05) if p.get("face", "") != "old" else hair.darkened(0.12)
					var outer := e + Vector2(o * r * 1.5, -up - r * 0.45)
					var inner := e + Vector2(-o * r * 1.1, -up + r * 0.55)
					c.draw_colored_polygon(pill(outer, inner, r * 0.5), bb)
					for t in [0.2, 0.5, 0.8]:
						var q := outer.lerp(inner, t) + Vector2(0, -r * 0.5)
						c.draw_circle(q, r * (0.42 + 0.1 * sin(t * 9.0)), bb, true, -1.0, true)
	if p.get("glasses", false):
		var rim := r * 1.42
		for e in [a, b]:
			c.draw_arc(e, rim, 0.0, TAU, 28, INK, r * 0.3, true)
			c.draw_arc(e, rim * 0.72, PI * 1.15, PI * 1.45, 6, Color(1, 1, 1, 0.75), r * 0.22, true)
		c.draw_line(a + Vector2(rim, -r * 0.2), b + Vector2(-rim, -r * 0.2), INK, r * 0.3, true)
		if side:
			c.draw_line(a + Vector2(-rim, -r * 0.2), a + Vector2(-rim - r * 2.6, -r * 0.6), INK, r * 0.28, true)


## One eye in the given style. out is -1 for the left eye, +1 for the right.
## Styles: oval (default bean), dot (small round), tall (tall bean), round
## (big round), small (tiny), lash, happy (arc), sleepy (half lid), narrow
## (sly slit), line (dash). Solid dark, no shine.
static func _eye(c: CanvasItem, e: Vector2, r: float, style: String, out: float) -> void:
	match style:
		"happy":
			var pts := arc(e.x, e.y + r * 0.45, r * 1.05, r * 0.95, PI * 1.08, PI * 1.92, 12)
			c.draw_polyline(pts, INK, r * 0.65, true)
		"sleepy":
			var lid := arc(e.x, e.y - r * 0.15, r * 1.05, r * 0.95, 0.0, PI, 14)
			c.draw_colored_polygon(lid, INK)
			c.draw_line(e + Vector2(-r * 1.15, -r * 0.15), e + Vector2(r * 1.15, -r * 0.15), INK, r * 0.45, true)
		"narrow":
			c.draw_colored_polygon(E(e.x, e.y + r * 0.25, r * 1.15, r * 0.5, 14), INK)
			c.draw_line(e + Vector2(-out * r * 1.4, -r * 0.1), e + Vector2(out * r * 1.4, -r * 0.7), INK, r * 0.42, true)
		"line":
			c.draw_line(e + Vector2(-r * 1.0, r * 0.2), e + Vector2(r * 1.0, r * 0.2), INK, r * 0.5, true)
		_:
			var rx := 0.85
			var ry := 1.42
			match style:
				"dot":
					rx = 0.78
					ry = 0.86
				"tall":
					rx = 0.66
					ry = 1.75
				"round":
					rx = 1.08
					ry = 1.2
				"small":
					rx = 0.56
					ry = 0.78
			var o := E(e.x, e.y + (r * 0.1 if style in ["round", "small", "dot"] else 0.0), r * rx, r * ry, 22)
			c.draw_colored_polygon(o, INK)
			c.draw_polyline(Paint._closed(o), INK, 1.0, true)
			if style == "lash":
				c.draw_line(e + Vector2(out * r * 0.7, -r * 1.0), e + Vector2(out * r * 1.7, -r * 1.55), INK, r * 0.3, true)
				c.draw_line(e + Vector2(out * r * 0.85, -r * 0.5), e + Vector2(out * r * 1.85, -r * 0.7), INK, r * 0.28, true)


# <<<CHIBI-A-END
static func _eyes(c: CanvasItem, a: Vector2, b: Vector2, r: float, blush: bool = true) -> void:
	for e in [a, b]:
		c.draw_circle(e, r, INK)
		c.draw_circle(e + Vector2(-r * 0.3, -r * 0.35), r * 0.36, Color.WHITE)
	if blush:
		c.draw_colored_polygon(E(a.x - r * 1.2, a.y + r * 2.4, r * 1.3, r * 0.8, 12), BLUSH)
		c.draw_colored_polygon(E(b.x + r * 0.6, b.y + r * 2.4, r * 1.1, r * 0.75, 12), BLUSH)


static func _mean_eyes(c: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	for e in [a, b]:
		c.draw_circle(e, r, col)
		c.draw_circle(e, r * 0.45, INK)
	c.draw_line(a + Vector2(-r * 1.4, -r * 1.8), b + Vector2(r * 1.2, -r * 1.2), INK, 1.4, true)


# <<<CHIBI-B-BEGIN
# ---------- chibi people ----------
#
# One painter (_chibi) builds all three views. Everything is described as
# shapes tagged with the rig piece they belong to (back, back_arm, back_leg,
# front_leg, body, head, front_arm), plus "decals": thin ink/highlight details
# drawn on top of a piece without their own cardboard outline.
#
# Look params (all optional):
#   skin, cloth, pants, hair, hat (hair style: short long bob pony bun spiky
#   twin bald monk; legacy gear: toque helmet cap hood), hat_col, weapon, apron,
#   cape, beard, dress, ribbon, eyes, brows, cheeks, glasses, chin, face_w,
#   armor: none leather chain plate gold      armor_col: Color
#   tabard: Color or {"a": Color, "b": Color}  (striped surcoat)
#   helm: none kettle visor plume viking winged crown wizard witch turban straw
#         fur beanie hood tricorn hardhat sailor tophat bowler coif toque helmet cap
#   plume: Color (feather colour of the plume helm)    goggles: bool
#   shield: none round kite     shield_col, emblem (cross star chevron stripe), emblem_col
#   pack: none backpack bedroll sack tower basket      pack_col, pack2
#   cloak: Color     robe: Color     trim: Color     scarf: Color
#   frill: bool (scalloped dress hem)   stripes: Color (sailor shirt)
#   shirt: Color, tie: Color (office wear)  belt: Color   boots: Color   vest: Color
#   weapon: axe double_axe spear hammer pin mug sword broadsword mace bow dagger
#           staff crook lute pickaxe scythe fishing_rod torch wand shovel sack
#           briefcase pitchfork book wrench lantern       (orb: Color for staff)
#   offhand: any weapon name (held in the back hand) or lantern/book
#   beard: bool | short long goatee      mustache: bool    nose: none small big
#   face: normal grumpy kind sly old child     head_scale: float (default 1.06)
#   wrinkles: bool

const STEEL := Color(0.74, 0.76, 0.81)
const GOLD := Color(0.96, 0.80, 0.34)
const LEATHER := Color(0.60, 0.40, 0.25)
const MAIL := Color(0.60, 0.63, 0.69)
const CREAM := Color(0.97, 0.93, 0.82)
const HIDE_HAIR := ["kettle", "visor", "plume", "viking", "winged", "turban", "fur", "beanie", "hardhat", "sailor", "coif", "helmet", "cap", "tophat", "bowler", "hood"]
const HIDE_EARS := ["visor", "plume", "coif", "hood", "turban", "fur"]
const NO_BROW := ["kettle", "straw", "wizard", "witch", "tricorn", "hardhat", "fur", "beanie", "sailor", "turban", "tophat", "bowler", "cap", "helmet"]
const HELM_COLS := {
	"kettle": STEEL, "visor": STEEL, "plume": STEEL, "viking": GOLD, "winged": GOLD, "crown": GOLD,
	"wizard": Color(0.36, 0.30, 0.62), "witch": Color(0.20, 0.15, 0.26), "turban": Color(0.95, 0.93, 0.88),
	"straw": Color(0.93, 0.80, 0.45), "fur": Color(0.66, 0.50, 0.36), "beanie": Color(0.80, 0.30, 0.30),
	"hood": Color(0.30, 0.48, 0.28), "tricorn": Color(0.26, 0.20, 0.20), "hardhat": Color(0.98, 0.80, 0.20),
	"sailor": Color(0.96, 0.96, 0.94), "tophat": Color(0.15, 0.14, 0.16), "bowler": Color(0.24, 0.21, 0.23),
	"coif": MAIL,
}


# ----- small shape helpers -----

## Adds a cardboard shape. piece = rig piece, hatch > 0 adds crayon strokes
## (>= 2 gives a chain-mail pattern).
static func _sh(sh: Array, pts: PackedVector2Array, col: Color, piece: String = "body", hatch: float = 0.0) -> void:
	sh.append([pts, col, piece, hatch])


static func _dp(dec: Array, pts: PackedVector2Array, col: Color, piece: String) -> void:
	dec.append(["p", pts, col, 0.0, piece])


static func _dl(dec: Array, a: Vector2, b: Vector2, col: Color, w: float, piece: String) -> void:
	dec.append(["l", PackedVector2Array([a, b]), col, w, piece])


static func _dpl(dec: Array, pts: PackedVector2Array, col: Color, w: float, piece: String) -> void:
	dec.append(["l", pts, col, w, piece])


static func _dc(dec: Array, ctr: Vector2, r: float, col: Color, piece: String) -> void:
	dec.append(["c", PackedVector2Array([ctr]), col, r, piece])


## Rounded rectangle.
static func _rr(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append_array(arc(x + w - r, y + r, r, r, -PI * 0.5, 0.0, 4))
	pts.append_array(arc(x + w - r, y + h - r, r, r, 0.0, PI * 0.5, 4))
	pts.append_array(arc(x + r, y + h - r, r, r, PI * 0.5, PI, 4))
	pts.append_array(arc(x + r, y + r, r, r, PI, PI * 1.5, 4))
	return pts


## Quadratic bezier points from a to b via q.
static func _curve(a: Vector2, q: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(a * (1.0 - t) * (1.0 - t) + q * 2.0 * t * (1.0 - t) + b * t * t)
	return pts


## A polyline thickened into a polygon; width tapers from w to w * taper.
static func _stroke(pts: PackedVector2Array, w: float, taper: float = 1.0) -> PackedVector2Array:
	var n := pts.size()
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var d: Vector2 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nv := Vector2(-d.y, d.x) * w * 0.5 * lerpf(1.0, taper, float(i) / float(maxi(n - 1, 1)))
		l.append(pts[i] + nv)
		r.append(pts[i] - nv)
	r.reverse()
	l.append_array(r)
	return l


## A blunt, curved lock of hair or fur from a to b (bent towards q): width
## goes from w0 to w1 and the end is a round cap, never a needle point.
static func _lock(a: Vector2, q: Vector2, b: Vector2, w0: float, w1: float) -> PackedVector2Array:
	var cp := _curve(a, q, b, 10)
	var n := cp.size()
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var d: Vector2 = (cp[mini(i + 1, n - 1)] - cp[maxi(i - 1, 0)]).normalized()
		var nv := Vector2(-d.y, d.x) * lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		l.append(cp[i] + nv)
		r.append(cp[i] - nv)
	var ang: float = (cp[n - 1] - cp[n - 2]).angle()
	var rad := w1 * 0.5
	for i in range(1, 6):
		var t := ang + PI * 0.5 - PI * float(i) / 6.0
		l.append(b + Vector2(cos(t), sin(t)) * rad)
	r.reverse()
	l.append_array(r)
	return l


## One curved leaf-shaped strand of hair or beard (pointed but soft, bent
## towards q) with a vein line down the middle, like layered cut paper.
## Veins are decals, so they are only added when `vein` is true.
static func _strand(sh: Array, dec: Array, a: Vector2, q: Vector2, b: Vector2, w: float, col: Color, vein: bool = true, piece: String = "head") -> void:
	_sh(sh, _leaf(a, q, b, w), col, piece, 0.0)
	if vein:
		var vc := col.darkened(0.28)
		vc.a = 0.55
		_dpl(dec, _curve(a.lerp(b, 0.14), a.lerp(b, 0.5).lerp(q, 0.55), b.lerp(a, 0.12), 6), vc, 0.8, piece)


## Strands flicking outwards round the crown: the silhouette of a hairdo.
static func _flicks(sh: Array, dec: Array, hair: Color, cx: float, n: int, ln: float, vein: bool) -> void:
	for i in n:
		var u := float(i) / float(maxi(n - 1, 1))
		var ang := lerpf(-1.22, 1.22, u) + sin(float(i) * 2.7) * 0.08
		var dirv := Vector2(sin(ang), -cos(ang))
		var base := V(cx, -73) + Vector2(dirv.x * 19.5, dirv.y * 18.0)
		var l := ln * (0.8 + 0.35 * absf(sin(float(i) * 1.9)))
		var tip := base + dirv * l + dirv.orthogonal() * 3.2
		var col := hair.darkened(0.05) if i % 2 == 0 else hair.lightened(0.04)
		_strand(sh, dec, base - dirv * 4.0, base + dirv * l * 0.55 + dirv.orthogonal() * 4.0, tip, 11.0, col, vein)



## A feather/leaf from a to b, bent towards q, widest in the middle.
static func _leaf(a: Vector2, q: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var cp := _curve(a, q, b, 8)
	var n := cp.size()
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var d: Vector2 = (cp[mini(i + 1, n - 1)] - cp[maxi(i - 1, 0)]).normalized()
		var t := float(i) / float(n - 1)
		var nv := Vector2(-d.y, d.x) * w * 0.5 * pow(sin(PI * t), 0.7)
		l.append(cp[i] + nv)
		r.append(cp[i] - nv)
	r.reverse()
	l.append_array(r)
	return l


static func _star(ctr: Vector2, r_out: float, r_in: float, n: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := TAU * float(i) / float(n * 2) - PI * 0.5
		var rr := r_out if i % 2 == 0 else r_in
		pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts


static func _xf(pts: PackedVector2Array, g: Vector2, rot: float, spin: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(g + (q.rotated(rot) if spin else q))
	return out


## Light version of a colour for highlights.
static func _hi(col: Color, amt: float = 0.3, a: float = 0.55) -> Color:
	var h := col.lightened(amt)
	h.a = a
	return h


# ----- painting -----

## Replacement for Paint._cut: the same cardboard outline, then crayon
## hatching on shapes that ask for it, then decals on top.
static var debug_tri := false


static func _paint(c: CanvasItem, sh: Array) -> void:
	var shapes: Array = []
	for s0 in sh:
		if Paint._on(s0[2] if s0.size() > 2 else "body"):
			var q: Array = s0.duplicate()
			q[0] = Paint.soften(s0[0], 2.6)
			if Geometry2D.triangulate_polygon(q[0]).is_empty():
				continue  # a degenerate sliver: nothing to cut out
			shapes.append(q)
	if debug_tri:
		for s in shapes:
			if Geometry2D.triangulate_polygon(s[0]).is_empty():
				print("BAD POLY piece=", s[2], " n=", s[0].size(), " first=", s[0][0], " col=", s[1])
	for s in shapes:
		Paint._outline(c, s[0], Paint.RIM, Paint.BORDER + 0.9)
	for s in shapes:
		Paint._outline(c, s[0], Paint.EDGE, Paint.BORDER)
	for s in shapes:
		Paint._fill(c, s[0], s[1])
		if s.size() > 3 and float(s[3]) > 0.0:
			_hatch(c, s[0], s[1], float(s[3]))
		c.draw_polyline(Paint._closed(s[0]), INK, 0.9, true)


static func _decals(c: CanvasItem, dec: Array) -> void:
	for d in dec:
		if not Paint._on(d[4]):
			continue
		match d[0]:
			"p":
				if debug_tri and Geometry2D.triangulate_polygon(d[1]).is_empty():
					print("BAD DECAL piece=", d[4], " first=", d[1][0], " n=", d[1].size())
				c.draw_colored_polygon(Paint.soften(d[1], 1.4), d[2])
			"l":
				c.draw_polyline(d[1], d[2], d[3], true)
			"c":
				c.draw_circle(d[1][0], d[3], d[2], true, -1.0, true)


## Short diagonal crayon strokes (or little mail rings) inside a polygon.
static func _hatch(c: CanvasItem, pts: PackedVector2Array, col: Color, k: float) -> void:
	var bb := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		bb = bb.expand(q)
	if bb.size.x < 6.0 or bb.size.y < 5.0:
		return
	var ink := col.darkened(0.22)
	ink.a = 0.5
	var count := 0
	if k >= 2.0:
		var y := bb.position.y + 3.0
		var row := 0
		while y < bb.end.y - 1.5 and count < 150:
			var x := bb.position.x + 2.5 + (1.9 if row % 2 == 1 else 0.0)
			while x < bb.end.x - 2.5 and count < 150:
				var a := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(a, pts) and Geometry2D.is_point_in_polygon(a + Vector2(2.2, 1.2), pts):
					c.draw_polyline(PackedVector2Array([a + Vector2(-1.1, -0.7), a + Vector2(0, 0.7), a + Vector2(1.1, -0.7)]), ink, 0.7, true)
					count += 1
				x += 3.8
			y += 3.4
			row += 1
		return
	var yy := bb.position.y + 3.0
	var rr := 0
	while yy < bb.end.y - 1.5 and count < 36:
		var xx := bb.position.x + 2.0 + float(rr % 3) * 1.7
		while xx < bb.end.x - 3.0 and count < 36:
			var jit := sin(xx * 12.9 + yy * 7.3) * 1.1
			var a2 := Vector2(xx, yy + jit)
			var b2 := a2 + Vector2(3.2, -3.6)
			if Geometry2D.is_point_in_polygon(a2, pts) and Geometry2D.is_point_in_polygon(b2, pts):
				c.draw_line(a2, b2, ink, 0.85, true)
				count += 1
			xx += 6.3
		yy += 4.6
		rr += 1


# ----- look resolving -----

static func _armor_cols(armor: String, p: Dictionary) -> Array:
	var m: Color
	match armor:
		"gold":
			m = GOLD
		"chain":
			m = MAIL
		"leather":
			m = LEATHER
		_:
			m = STEEL
	if p.has("armor_col"):
		m = p["armor_col"]
	return [m, m.darkened(0.24), m.lightened(0.3)]


static func _resolve(p: Dictionary) -> Dictionary:
	var k := {}
	var hair: Color = p.get("hair", Color(0.35, 0.22, 0.14))
	var hat: String = p.get("hat", "short")
	var gear: String = p.get("helm", "none")
	var style := hat
	if hat in ["toque", "helmet", "cap", "hood"]:
		if gear == "none":
			gear = hat
		style = "short" if hat == "toque" else "bald"
	k["style"] = style
	k["gear"] = gear
	k["skin"] = p.get("skin", Color(0.98, 0.84, 0.70))
	k["cloth"] = p.get("cloth", Color(0.45, 0.6, 0.9))
	k["pants"] = p.get("pants", Color(0.35, 0.3, 0.3))
	k["hair"] = hair
	k["shoe"] = p.get("boots", Color(0.36, 0.22, 0.14))
	k["armor"] = String(p.get("armor", "none"))
	var ac := _armor_cols(k["armor"], p)
	k["m"] = ac[0]
	k["md"] = ac[1]
	k["ml"] = ac[2]
	var hc: Color = p["hat_col"] if p.has("hat_col") else HELM_COLS.get(gear, hair)
	if p.has("helm_col"):
		hc = p["helm_col"]
	k["helm_col"] = hc
	k["plume"] = p.get("plume", Color(0.84, 0.22, 0.22))
	k["sleeve"] = p["robe"] if p.has("robe") else k["cloth"]
	k["pack_col"] = p.get("pack_col", Color(0.62, 0.46, 0.28))
	k["pack2"] = p.get("pack2", Color(0.78, 0.30, 0.28))
	k["belt"] = p.get("belt", Color(0.42, 0.26, 0.14))
	k["trim"] = p.get("trim", (k["sleeve"] as Color).lightened(0.4))
	k["metal"] = METAL
	return k


# ----- limbs -----

static func _leg(sh: Array, dec: Array, piece: String, x0: float, w: float, fcx: float, k: Dictionary, back: bool) -> void:
	var pants: Color = k["pants"]
	var shoe: Color = k["shoe"]
	var armor: String = k["armor"]
	if back:
		pants = pants.darkened(0.12)
		shoe = shoe.darkened(0.12)
	var xc := x0 + w * 0.5
	_sh(sh, R(x0, -22, w, 17), pants, piece, 0.7)
	if armor == "plate" or armor == "gold":
		var m: Color = k["m"]
		if back:
			m = m.darkened(0.1)
		_sh(sh, R(x0 - 0.4, -17.5, w + 0.8, 13), m, piece)
		_sh(sh, E(xc, -17.5, w * 0.62, 3.2, 12), m.lightened(0.1), piece)
		_sh(sh, E(fcx, -3.6, 6.9, 4.3), m.darkened(0.14), piece)
		_dl(dec, V(x0 + 0.6, -10.5), V(x0 + w - 0.6, -10.5), k["md"], 0.8, piece)
		_dl(dec, V(x0 + 1.0, -14.5), V(x0 + 1.0, -6), _hi(m, 0.35, 0.6), 1.0, piece)
	elif armor == "leather" or armor == "chain":
		var lc := LEATHER.darkened(0.12 if not back else 0.25)
		_sh(sh, R(x0 - 0.5, -15.5, w + 1.0, 11), lc, piece, 0.8)
		_sh(sh, R(x0 - 0.9, -16.5, w + 1.8, 2.8), lc.lightened(0.1), piece)
		_sh(sh, E(fcx, -3.6, 6.9, 4.2), lc.darkened(0.1), piece)
		_dl(dec, V(x0 + 0.2, -10.5), V(x0 + w - 0.2, -10.5), lc.darkened(0.35), 0.7, piece)
	else:
		_sh(sh, R(x0 - 0.7, -13, w + 1.4, 3.2), shoe.darkened(0.12), piece)
		_sh(sh, E(fcx, -3.6, 6.9, 4.2), shoe, piece)


static func _arm(sh: Array, dec: Array, piece: String, top: Vector2, hand: Vector2, k: Dictionary, back: bool, sgn: float, has_robe: bool) -> void:
	var cl: Color = k["sleeve"]
	var skin: Color = k["skin"]
	var armor: String = k["armor"]
	if back:
		cl = cl.darkened(0.08)
		skin = skin.darkened(0.08)
	var bottom := hand + V(0, -3)
	var hatch := 1.0
	if armor == "chain":
		cl = k["m"]
		hatch = 2.0
	var r := 4.0
	if has_robe:
		r = 4.7
	_sh(sh, pill(top, bottom, r), cl, piece, hatch)
	var mid := top.lerp(bottom, 0.5)
	match armor:
		"plate", "gold":
			var m: Color = k["m"]
			var md: Color = k["md"]
			_sh(sh, pill(mid, bottom, 4.3), m, piece)
			_sh(sh, E(hand.x, hand.y, 5.3, 5.0), m.lightened(0.05), piece)
			_dl(dec, V(hand.x - 4, hand.y - 4.6), V(hand.x + 4, hand.y - 4.6), md, 0.9, piece)
			_dl(dec, V(hand.x - 2.5, hand.y - 0.5), V(hand.x + 2.5, hand.y - 0.5), md, 0.7, piece)
			# pauldron: layered plates on the shoulder
			_sh(sh, E(top.x + sgn * 0.8, top.y + 4.3, 6.2, 3.4, 14), m.darkened(0.08), piece)
			_sh(sh, E(top.x + sgn * 0.8, top.y + 0.6, 7.0, 5.6, 16), m, piece)
			_dp(dec, arc(top.x + sgn * 0.8 - 1.2, top.y + 0.2, 4.4, 3.4, PI * 1.05, PI * 1.6, 6), _hi(m, 0.4, 0.6), piece)
			_dc(dec, V(top.x + sgn * 0.8 + sgn * 2.4, top.y + 1.8), 0.9, md, piece)
			_dc(dec, V(top.x + sgn * 0.8 - sgn * 2.0, top.y - 1.2), 0.9, md, piece)
		"leather":
			var lc := LEATHER.darkened(0.1)
			_sh(sh, pill(mid, bottom, 4.2), lc, piece, 0.8)
			_sh(sh, E(top.x + sgn * 0.5, top.y + 1.0, 5.4, 4.2, 12), lc.lightened(0.05), piece)
			_sh(sh, E(hand.x, hand.y, 4.6, 4.6), skin, piece)
			_dl(dec, V(hand.x - 3.6, hand.y - 4.2), V(hand.x + 3.6, hand.y - 4.2), lc.darkened(0.4), 0.8, piece)
		"chain":
			_sh(sh, E(hand.x, hand.y, 4.9, 4.8), k["m"].darkened(0.1), piece, 2.0)
		_:
			_sh(sh, E(hand.x, hand.y, 4.6, 4.6), skin, piece)
	if has_robe:
		var tc: Color = k["trim"]
		_dp(dec, E(hand.x, hand.y - 3.6, 5.2, 1.9, 12), tc, piece)


# ----- weapons -----

static func _wp(parts: Array, pts: PackedVector2Array, col: Color, hatch: float = 0.0) -> void:
	parts.append([pts, col, hatch])


## Decal inside a weapon. kind: p/l/c are rotated with the weapon, P/L/C stay
## upright (hanging lines, glows).
static func _wd(decs: Array, kind: String, pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	decs.append([kind, pts, col, w])


## Draws a weapon held in the hand at g (hand centre), shapes relative to the
## hand, up is -y. flip = -1 mirrors the lean (left hand in the front view).
static func _weapon(sh: Array, dec: Array, wname: String, g: Vector2, flip: float, piece: String, k: Dictionary, p: Dictionary) -> void:
	var parts: Array = []
	var decs: Array = []
	var tilt := 0.0
	var steel: Color = METAL
	var gold := Color(0.85, 0.68, 0.30)
	var dark := Color(0.30, 0.22, 0.16)
	match wname:
		"axe":
			tilt = 0.15
			_wp(parts, R(-1.6, -28, 3.2, 34), WOOD)
			_wp(parts, PackedVector2Array([V(-0.5, -28), V(6.5, -35), V(15.5, -31), V(12.5, -19), V(6.5, -21), V(-0.5, -19)]), steel)
			_wd(decs, "c", PackedVector2Array([V(6.5, -26)]), Color(0.35, 0.35, 0.4), 2.1)
		"double_axe":
			tilt = 0.42
			_wp(parts, R(-1.6, -42, 3.2, 58), WOOD)
			_wp(parts, PackedVector2Array([V(-2.2, -42), V(0, -51), V(2.2, -42)]), steel)
			_wp(parts, PackedVector2Array([V(1.4, -33), V(5.5, -37), V(15, -39), V(11.5, -26), V(15, -13), V(5.5, -15), V(1.4, -19)]), steel)
			_wp(parts, PackedVector2Array([V(-1.4, -33), V(-5.5, -37), V(-15, -39), V(-11.5, -26), V(-15, -13), V(-5.5, -15), V(-1.4, -19)]), steel.darkened(0.08))
			_wd(decs, "c", PackedVector2Array([V(5, -26)]), Color(0.35, 0.35, 0.4), 1.5)
			_wd(decs, "c", PackedVector2Array([V(-5, -26)]), Color(0.35, 0.35, 0.4), 1.5)
			_wd(decs, "l", PackedVector2Array([V(6.5, -35), V(13, -37)]), _hi(steel, 0.25, 0.8), 1.1)
			_wd(decs, "l", PackedVector2Array([V(6.5, -17), V(13, -15)]), steel.darkened(0.25), 1.0)
			_wd(decs, "l", PackedVector2Array([V(-2, -26), V(2, -26)]), gold, 3.0)
		"spear":
			tilt = 0.28
			_wp(parts, R(-1.4, -54, 2.8, 76), WOOD)
			_wp(parts, PackedVector2Array([V(-3, -54), V(0, -68), V(3, -54)]), steel)
			_wd(decs, "p", PackedVector2Array([V(-2.2, -51), V(2.2, -51), V(0, -42)]), Color(0.78, 0.22, 0.20))
		"hammer":
			tilt = 0.18
			_wp(parts, R(-1.5, -20, 3, 24), WOOD)
			_wp(parts, R(-8.5, -28, 17, 9.5), Color(0.46, 0.46, 0.52))
			_wd(decs, "l", PackedVector2Array([V(-6.5, -25), V(6.5, -25)]), _hi(steel, 0.1, 0.5), 1.0)
		"pin":
			_wp(parts, R(-9, -2, 19, 4), WOOD.lightened(0.25))
			_wp(parts, E(-9.5, 0, 2.4, 3.0, 8), WOOD.lightened(0.1))
			_wp(parts, E(10.5, 0, 2.4, 3.0, 8), WOOD.lightened(0.1))
		"mug":
			_wp(parts, R(-3.5, -7.5, 8, 9), WOOD)
			_wp(parts, E(0.5, -7.5, 4.6, 2.2, 12), Color(0.99, 0.96, 0.86))
			_wd(decs, "l", PackedVector2Array([V(5.2, -5), V(8, -4), V(5.2, -0.5)]), WOOD.darkened(0.3), 1.2)
		"sword":
			tilt = 0.3
			_wp(parts, PackedVector2Array([V(-1.8, -2), V(1.8, -2), V(1.8, -31), V(0, -37), V(-1.8, -31)]), steel)
			_wp(parts, R(-4.5, -4, 9, 2.8), Color(0.55, 0.38, 0.16))
			_wp(parts, R(-1, -1.5, 2, 7), dark)
			_wd(decs, "l", PackedVector2Array([V(0, -5), V(0, -29)]), _hi(steel, 0.3, 0.9), 0.9)
		"broadsword":
			tilt = 0.32
			_wp(parts, PackedVector2Array([V(-3.2, -4), V(3.2, -4), V(3.2, -46), V(0, -55), V(-3.2, -46)]), steel)
			_wp(parts, R(-8.5, -6.5, 17, 3.4), gold)
			_wp(parts, R(-1.3, -3, 2.6, 9), dark)
			_wp(parts, E(0, 8, 2.5, 2.5, 8), gold)
			_wd(decs, "l", PackedVector2Array([V(0, -8), V(0, -46)]), _hi(steel, 0.3, 0.9), 1.0)
			_wd(decs, "l", PackedVector2Array([V(1.8, -8), V(1.8, -44)]), steel.darkened(0.2), 0.8)
		"mace":
			tilt = 0.25
			_wp(parts, R(-1.4, -24, 2.8, 32), WOOD)
			_wp(parts, _star(V(0, -30), 8.5, 5.4, 8), Color(0.52, 0.52, 0.58))
			_wd(decs, "c", PackedVector2Array([V(0, -30)]), _hi(steel, 0.2, 0.7), 2.0)
		"bow":
			tilt = 0.08
			var bp := PackedVector2Array()
			for i in 11:
				var t := float(i) / 5.0 - 1.0
				bp.append(V(-1.0 + 9.0 * (1.0 - t * t), -12.0 + 24.0 * t))
			_wp(parts, _stroke(bp, 2.8, 0.6), WOOD.lightened(0.05))
			_wd(decs, "l", PackedVector2Array([V(-1, -36), V(-1, 12)]), Color(0.95, 0.92, 0.82), 0.7)
			_wd(decs, "l", PackedVector2Array([V(-2, -4), V(3, -4)]), dark, 3.0)
		"dagger":
			tilt = 0.3
			_wp(parts, PackedVector2Array([V(-1.7, -2), V(1.7, -2), V(1.7, -14), V(0, -19), V(-1.7, -14)]), steel)
			_wp(parts, R(-3.6, -3.6, 7.2, 2), gold)
			_wp(parts, R(-1, -1.5, 2, 6), dark)
		"staff":
			tilt = 0.34
			var orb: Color = p.get("orb", Color(0.45, 0.85, 0.95))
			_wp(parts, R(-1.4, -56, 2.8, 80), WOOD)
			_wp(parts, _stroke(arc(0, -62, 7.5, 7.5, PI * 0.55, PI * 1.35, 8), 2.4), WOOD.darkened(0.05))
			_wp(parts, _stroke(arc(0, -62, 7.5, 7.5, PI * 0.45, -PI * 0.35, 8), 2.4), WOOD.darkened(0.05))
			_wp(parts, E(0, -62, 5.4, 5.4, 14), orb)
			_wd(decs, "c", PackedVector2Array([V(0, -62)]), Color(orb.r, orb.g, orb.b, 0.22), 10.0)
			_wd(decs, "c", PackedVector2Array([V(-1.6, -64)]), Color(1, 1, 1, 0.8), 1.5)
		"crook":
			tilt = 0.1
			_wp(parts, R(-1.4, -48, 2.8, 72), WOOD)
			_wp(parts, _stroke(arc(5.5, -48, 6.9, 6.9, PI, TAU + 0.7, 10), 2.8), WOOD)
		"lute":
			tilt = 0.7
			_wp(parts, R(-1.5, -27, 3, 28), WOOD.darkened(0.25))
			_wp(parts, PackedVector2Array([V(-3, -27), V(3, -27), V(3.5, -33), V(-3.5, -33)]), WOOD.darkened(0.45))
			_wp(parts, E(0, 7, 9.5, 8.2, 18), Color(0.86, 0.58, 0.30), 1.0)
			_wd(decs, "c", PackedVector2Array([V(0, 6)]), Color(0.28, 0.17, 0.10), 2.8)
			_wd(decs, "l", PackedVector2Array([V(-0.6, -26), V(-0.6, 8)]), Color(0.95, 0.9, 0.75), 0.5)
			_wd(decs, "l", PackedVector2Array([V(0.6, -26), V(0.6, 8)]), Color(0.95, 0.9, 0.75), 0.5)
		"pickaxe":
			tilt = 0.2
			_wp(parts, R(-1.4, -40, 2.8, 54), WOOD)
			_wp(parts, PackedVector2Array([V(-17, -32), V(-9, -41), V(0, -43), V(9, -41), V(17, -32), V(12, -34), V(0, -37), V(-12, -34)]), Color(0.60, 0.62, 0.68))
		"scythe":
			tilt = 0.05
			_wp(parts, R(-1.3, -56, 2.6, 80), WOOD)
			_wp(parts, PackedVector2Array([V(-0.8, -56), V(8, -63), V(19, -62), V(26, -52), V(21, -55.5), V(10, -56), V(1.2, -50)]), steel)
			_wd(decs, "l", PackedVector2Array([V(4, -59), V(14, -59.5), V(21, -55)]), _hi(steel, 0.3, 0.8), 0.9)
		"fishing_rod":
			tilt = 0.62
			_wp(parts, R(-0.9, -58, 1.8, 66), WOOD.lightened(0.1))
			_wd(decs, "c", PackedVector2Array([V(0, -2)]), Color(0.55, 0.55, 0.6), 2.4)
		"torch":
			tilt = 0.25
			_wp(parts, R(-1.5, -26, 3, 34), WOOD)
			_wp(parts, PackedVector2Array([V(0, -50), V(5.5, -38), V(4.2, -28), V(-4.2, -28), V(-5.5, -38)]), Color(0.99, 0.58, 0.16))
			_wd(decs, "p", PackedVector2Array([V(0, -44), V(2.8, -36.5), V(0, -31), V(-2.8, -36.5)]), Color(1.0, 0.88, 0.35))
			_wd(decs, "c", PackedVector2Array([V(0, -39)]), Color(1.0, 0.7, 0.2, 0.2), 12.0)
		"wand":
			tilt = 0.65
			_wp(parts, R(-0.9, -20, 1.8, 26), Color(0.25, 0.18, 0.14))
			_wp(parts, _star(V(0, -24), 5.8, 2.6), Color(1.0, 0.84, 0.30))
			_wd(decs, "c", PackedVector2Array([V(0, -24)]), Color(1.0, 0.9, 0.4, 0.22), 9.0)
		"shovel":
			tilt = 0.25
			_wp(parts, R(-1.3, -46, 2.6, 58), WOOD)
			_wp(parts, PackedVector2Array([V(-6, -46), V(6, -46), V(7.5, -58), V(0, -67), V(-7.5, -58)]), Color(0.60, 0.62, 0.68))
			_wd(decs, "l", PackedVector2Array([V(0, -48), V(0, -62)]), _hi(steel, 0.2, 0.7), 0.9)
		"sack":
			_wp(parts, E(0, 11, 10.5, 11.5, 16), Color(0.80, 0.66, 0.42), 1.0)
			_wp(parts, PackedVector2Array([V(-3.5, 1), V(3.5, 1), V(5, -4), V(0, -7), V(-5, -4)]), Color(0.74, 0.60, 0.38), 1.0)
			_wd(decs, "l", PackedVector2Array([V(-4, 0.5), V(4, 0.5)]), dark, 1.4)
			_wd(decs, "p", PackedVector2Array([V(-5, 10), V(1, 9), V(2, 15), V(-4, 16)]), Color(0.70, 0.45, 0.35, 0.8))
		"briefcase":
			_wp(parts, _rr(-9.5, 2, 19, 13, 2.5), Color(0.34, 0.23, 0.16), 0.7)
			_wp(parts, _stroke(arc(0, 2.5, 5.5, 4.5, PI, TAU, 8), 1.8), Color(0.26, 0.17, 0.12))
			_wd(decs, "l", PackedVector2Array([V(-8, 7), V(8, 7)]), Color(0.2, 0.13, 0.09), 0.8)
			_wd(decs, "p", PackedVector2Array([V(-5, 5.5), V(-3, 5.5), V(-3, 8.5), V(-5, 8.5)]), Color(0.86, 0.72, 0.34))
			_wd(decs, "p", PackedVector2Array([V(3, 5.5), V(5, 5.5), V(5, 8.5), V(3, 8.5)]), Color(0.86, 0.72, 0.34))
		"pitchfork":
			tilt = 0.28
			_wp(parts, R(-1.3, -60, 2.6, 84), WOOD)
			_wp(parts, R(-7.5, -64, 15, 3), steel)
			for tx in [-6.0, 0.0, 6.0]:
				_wp(parts, PackedVector2Array([V(tx - 1.5, -62), V(tx + 1.5, -62), V(tx, -80)]), steel)
		"book":
			_wp(parts, _rr(-6.5, -15, 13, 16, 1.5), Color(0.55, 0.20, 0.24))
			_wd(decs, "p", PackedVector2Array([V(4.2, -14), V(6, -14), V(6, 0), V(4.2, 0)]), CREAM)
			_wd(decs, "l", PackedVector2Array([V(-4, -11), V(2.5, -11)]), Color(0.9, 0.74, 0.34), 1.2)
			_wd(decs, "l", PackedVector2Array([V(-4, -7.5), V(2.5, -7.5)]), Color(0.9, 0.74, 0.34), 1.2)
		"wrench":
			tilt = 0.35
			_wp(parts, R(-1.6, -24, 3.2, 36), Color(0.44, 0.46, 0.52))
			_wp(parts, PackedVector2Array([V(-6.5, -24), V(-6.5, -37), V(-2.6, -37), V(-2.6, -31), V(2.6, -31), V(2.6, -37), V(6.5, -37), V(6.5, -24), V(3.5, -19.5), V(-3.5, -19.5)]), Color(0.60, 0.62, 0.68))
		"broom":
			tilt = 0.12
			_wp(parts, R(-1.3, -48, 2.6, 66), WOOD)
			_wp(parts, PackedVector2Array([V(-5, 14), V(5, 14), V(9, 28), V(4, 24), V(0, 29), V(-4, 24), V(-9, 28)]), Color(0.86, 0.70, 0.38), 1.0)
			_wd(decs, "l", PackedVector2Array([V(-5, 16.5), V(5, 16.5)]), dark, 1.6)
		"lantern":
			_wp(parts, PackedVector2Array([V(-5.5, 4), V(5.5, 4), V(4.5, 7.5), V(-4.5, 7.5)]), dark)
			_wp(parts, R(-4.6, 7.5, 9.2, 11), Color(1.0, 0.88, 0.45))
			_wp(parts, R(-5.4, 18.5, 10.8, 2.6), dark)
			_wd(decs, "c", PackedVector2Array([V(0, 13)]), Color(1.0, 0.85, 0.35, 0.25), 15.0)
			_wd(decs, "l", PackedVector2Array([V(-4.5, 4), V(-2, -3), V(2, -3), V(4.5, 4)]), dark, 1.3)
			_wd(decs, "l", PackedVector2Array([V(0, 8), V(0, 18)]), Color(0.8, 0.55, 0.2), 0.8)
	var rot := tilt * flip
	for q in parts:
		sh.append([_xf(q[0], g, rot, true), q[1], piece, q[2]])
	for d in decs:
		dec.append([d[0], _xf(d[1], g, rot, true), d[2], d[3], piece])
	if wname == "fishing_rod":
		var tip := g + V(0, -58).rotated(rot)
		_dl(dec, tip, tip + V(1.5, 24), Color(0.95, 0.95, 0.9), 0.6, piece)
		_dc(dec, tip + V(1.5, 26), 2.4, Color(0.88, 0.25, 0.22), piece)


# ----- shields -----

static func _emblem(dec: Array, kind: String, ctr: Vector2, s: float, col: Color, piece: String) -> void:
	match kind:
		"cross":
			_dp(dec, R(ctr.x - s * 0.14, ctr.y - s * 0.62, s * 0.28, s * 1.2), col, piece)
			_dp(dec, R(ctr.x - s * 0.55, ctr.y - s * 0.28, s * 1.1, s * 0.26), col, piece)
		"star":
			_dp(dec, _star(ctr, s * 0.62, s * 0.28), col, piece)
		"chevron":
			_dpl(dec, PackedVector2Array([ctr + V(-s * 0.5, -s * 0.1), ctr + V(0, -s * 0.5), ctr + V(s * 0.5, -s * 0.1)]), col, s * 0.22, piece)
			_dpl(dec, PackedVector2Array([ctr + V(-s * 0.5, s * 0.35), ctr + V(0, -s * 0.05), ctr + V(s * 0.5, s * 0.35)]), col, s * 0.22, piece)
		"stripe":
			_dp(dec, R(ctr.x - s * 0.7, ctr.y - s * 0.16, s * 1.4, s * 0.32), col, piece)


static func _shield(sh: Array, dec: Array, p: Dictionary, k: Dictionary, view: String) -> void:
	var kind: String = p["shield"]
	var side := view == "side"
	var back := view == "back"
	var col: Color = p.get("shield_col", Color(0.74, 0.24, 0.22))
	var emb_col: Color = p.get("emblem_col", Color(0.96, 0.90, 0.72))
	var emb: String = p.get("emblem", "cross")
	var ctr := V(11, -33) if side else V(-17.5, -32)
	var piece := "back_arm"
	if back:
		col = Color(0.56, 0.40, 0.24)
	if kind == "kite":
		var pts := PackedVector2Array([V(ctr.x - 11, ctr.y - 15), V(ctr.x + 11, ctr.y - 15), V(ctr.x + 10, ctr.y - 1), V(ctr.x, ctr.y + 20), V(ctr.x - 10, ctr.y - 1)])
		_sh(sh, pts, col, piece, 1.0)
		_dpl(dec, PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]).duplicate(), Color(0.86, 0.74, 0.38) if not back else Color(0.4, 0.28, 0.16), 1.6, piece)
		if not back:
			_emblem(dec, emb, ctr + V(0, -1.5), 14.0, emb_col, piece)
			_dc(dec, ctr + V(0, -1.5), 1.6, Color(0.86, 0.74, 0.38), piece)
	else:
		_sh(sh, E(ctr.x, ctr.y, 13.2, 13.6, 24), col, piece, 1.0)
		_dpl(dec, arc(ctr.x, ctr.y, 11.4, 11.8, 0.0, TAU, 24), Color(0.86, 0.74, 0.38) if not back else Color(0.4, 0.28, 0.16), 1.5, piece)
		if not back:
			_emblem(dec, emb, ctr, 14.0, emb_col, piece)
			_dc(dec, ctr, 3.4, Color(0.78, 0.78, 0.82), piece)
			_dc(dec, ctr, 1.4, Color(0.4, 0.4, 0.46), piece)
	if back:
		_dl(dec, ctr + V(-8, -3), ctr + V(8, -3), Color(0.33, 0.22, 0.13), 2.4, piece)
		_dl(dec, ctr + V(-8, 6), ctr + V(8, 6), Color(0.33, 0.22, 0.13), 2.4, piece)


# ----- packs and capes (the "back" piece) -----

static func _back_piece(sh: Array, dec: Array, p: Dictionary, k: Dictionary, view: String) -> void:
	var side := view == "side"
	var back := view == "back"
	var piece := "back"
	var pc: Color = k["pack_col"]
	var p2: Color = k["pack2"]
	if p.has("cape"):
		var cape: Color = p["cape"]
		if side:
			_sh(sh, PackedVector2Array([V(-10, -47), V(10, -47), V(17, -10), V(-17, -10)]), cape, piece, 1.0)
		else:
			_sh(sh, PackedVector2Array([V(-13, -47), V(13, -47), V(19, -9), V(-19, -9)]), cape if back else cape.darkened(0.2), piece, 1.0)
	if p.has("cloak"):
		var cl: Color = p["cloak"]
		var pts: PackedVector2Array
		if side:
			pts = PackedVector2Array([V(-6, -47), V(5, -47), V(4, -9), V(-10, -6), V(-27, -9), V(-23, -28)])
		else:
			pts = PackedVector2Array([V(-13, -48), V(13, -48), V(22, -7), V(14, -5), V(7, -8), V(0, -5), V(-7, -8), V(-14, -5), V(-22, -7)])
		_sh(sh, pts, cl if back or side else cl.darkened(0.18), piece, 1.0)
		if back:
			_dl(dec, V(0, -46), V(0, -8), cl.darkened(0.25), 0.9, piece)
		if side:
			_dl(dec, V(-12, -12), V(-18, -40), cl.darkened(0.25), 0.8, piece)
	if p.has("scarf") and side:
		var sc: Color = p["scarf"]
		_sh(sh, PackedVector2Array([V(-6, -47), V(-4, -42), V(-22, -36), V(-30, -42), V(-24, -50)]), sc, piece, 1.0)
	var pack: String = p.get("pack", "none")
	if p.get("weapon", "") == "bow" and pack == "none":
		var qc := Color(0.50, 0.34, 0.20)
		if side:
			_sh(sh, PackedVector2Array([V(-13, -50), V(-7, -51), V(-14, -22), V(-21, -24)]), qc, piece, 1.0)
			_dl(dec, V(-10.5, -50), V(-12, -58), CREAM, 1.2, piece)
			_dl(dec, V(-8.5, -50), V(-8, -57), p2, 1.2, piece)
		else:
			_sh(sh, PackedVector2Array([V(5, -53), V(11, -52), V(4, -24), V(-2, -26)]), qc, piece, 1.0)
			_dl(dec, V(6.5, -53), V(5, -61), CREAM, 1.2, piece)
			_dl(dec, V(9, -52), V(10, -60), p2, 1.2, piece)
	match pack:
		"backpack":
			if side:
				_sh(sh, _rr(-27, -50, 21, 36, 5), pc, piece, 1.0)
				_sh(sh, _rr(-27, -50, 21, 14, 5), pc.darkened(0.14), piece, 1.0)
				_sh(sh, _rr(-31, -30, 8, 15, 3), pc.lightened(0.08), piece, 1.0)
				_sh(sh, pill(V(-28, -55), V(-6, -55), 5.0), Color(0.55, 0.62, 0.76), piece, 1.0)
				_dl(dec, V(-22, -50), V(-22, -60), Color(0.3, 0.2, 0.12), 1.4, piece)
				_dl(dec, V(-12, -50), V(-12, -60), Color(0.3, 0.2, 0.12), 1.4, piece)
				_dc(dec, V(-16, -35), 1.5, GOLD, piece)
			else:
				_sh(sh, _rr(-17, -53 if not back else -49, 34, 38 if not back else 34, 6), pc, piece, 1.0)
				_sh(sh, _rr(-17, -53 if not back else -49, 34, 15, 6), pc.darkened(0.14), piece, 1.0)
				_sh(sh, _rr(-23, -34, 8, 16, 3), pc.lightened(0.08), piece, 1.0)
				_sh(sh, _rr(15, -34, 8, 16, 3), pc.lightened(0.08), piece, 1.0)
				_sh(sh, pill(V(-24, -54 if not back else -49), V(24, -54 if not back else -49), 5.4), Color(0.55, 0.62, 0.76), piece, 1.0)
				_dl(dec, V(-9, -49), V(-9, -60), Color(0.3, 0.2, 0.12), 1.4, piece)
				_dl(dec, V(9, -49), V(9, -60), Color(0.3, 0.2, 0.12), 1.4, piece)
				_dc(dec, V(-5, -36), 1.6, GOLD, piece)
				_dc(dec, V(5, -36), 1.6, GOLD, piece)
		"bedroll":
			if side:
				_sh(sh, pill(V(-30, -46), V(-8, -50), 6.0), Color(0.56, 0.64, 0.78), piece, 1.0)
				_dl(dec, V(-24, -52), V(-23, -41), Color(0.3, 0.2, 0.12), 1.5, piece)
				_dl(dec, V(-14, -54), V(-13, -44), Color(0.3, 0.2, 0.12), 1.5, piece)
			else:
				_sh(sh, pill(V(-24, -47 if not back else -45), V(24, -47 if not back else -45), 6.0), Color(0.56, 0.64, 0.78), piece, 1.0)
				_dl(dec, V(-14, -53), V(-14, -41), Color(0.3, 0.2, 0.12), 1.5, piece)
				_dl(dec, V(14, -53), V(14, -41), Color(0.3, 0.2, 0.12), 1.5, piece)
		"sack":
			if side:
				_sh(sh, E(-19, -33, 14.5, 17, 18), Color(0.80, 0.66, 0.42), piece, 1.0)
				_sh(sh, PackedVector2Array([V(-25, -47), V(-13, -47), V(-11, -56), V(-19, -61), V(-27, -56)]), Color(0.74, 0.60, 0.38), piece, 1.0)
				_dl(dec, V(-25, -47), V(-13, -47), Color(0.3, 0.2, 0.12), 1.6, piece)
			else:
				_sh(sh, E(-6, -37, 19, 17, 18), Color(0.80, 0.66, 0.42), piece, 1.0)
				_sh(sh, PackedVector2Array([V(-14, -49), V(2, -49), V(5, -58), V(-6, -64), V(-17, -58)]), Color(0.74, 0.60, 0.38), piece, 1.0)
				_dl(dec, V(-14, -49), V(2, -49), Color(0.3, 0.2, 0.12), 1.6, piece)
		"tower":
			# a merchant's stack of bundles, crates and a hanging pot
			if side:
				_sh(sh, _rr(-31, -47, 24, 34, 4), pc, piece, 1.0)
				_sh(sh, _rr(-29, -62, 18, 16, 4), p2, piece, 1.0)
				_sh(sh, pill(V(-32, -66), V(-12, -66), 4.6), Color(0.60, 0.74, 0.62), piece, 1.0)
				_dl(dec, V(-19, -47), V(-19, -13), Color(0.3, 0.2, 0.12), 1.5, piece)
				_dl(dec, V(-31, -30), V(-7, -30), Color(0.3, 0.2, 0.12), 1.5, piece)
				_sh(sh, E(-34, -26, 5.4, 6.0, 12), Color(0.42, 0.42, 0.48), piece)
			else:
				var top := -49.0 if back else -60.0
				_sh(sh, _rr(-19, -50 if not back else -49, 38, 38, 4), pc, piece, 1.0)
				if back:
					_sh(sh, _rr(-13, -46, 26, 12, 3), p2, piece, 1.0)
				else:
					_sh(sh, _rr(-13, top, 26, 13, 4), p2, piece, 1.0)
					_sh(sh, pill(V(-22, top - 4), V(22, top - 4), 4.6), Color(0.60, 0.74, 0.62), piece, 1.0)
				_dl(dec, V(0, -50 if not back else -49), V(0, -12), Color(0.3, 0.2, 0.12), 1.5, piece)
				_dl(dec, V(-19, -32), V(19, -32), Color(0.3, 0.2, 0.12), 1.5, piece)
				_sh(sh, E(-24, -22, 5.4, 6.0, 12), Color(0.42, 0.42, 0.48), piece)
		"basket":
			if side:
				_sh(sh, PackedVector2Array([V(-12, -50), V(-8, -50), V(-12, -18), V(-30, -20), V(-33, -50)]), Color(0.78, 0.58, 0.30), piece, 1.0)
				_sh(sh, E(-22, -52, 8, 5, 10), Color(0.60, 0.78, 0.38), piece)
			else:
				_sh(sh, PackedVector2Array([V(-16, -52), V(16, -52), V(18, -20), V(-18, -20)]), Color(0.78, 0.58, 0.30), piece, 1.0)
				_sh(sh, E(0, -54, 12, 5.5, 10), Color(0.60, 0.78, 0.38), piece)


# ----- head: hair, face features, headgear -----

static func _dome(cx: float, base_y: float, rx: float, ry: float, n: int = 18) -> PackedVector2Array:
	return arc(cx, base_y, rx, ry, PI, TAU, n)


## Hair styles (look key "hat"): short bowl sweep slick messy curly spiky ahoge
## long wavy bob pony twin bun twinbun braid bald monk. The fringe can be
## overridden with "fringe": wavy bowl sweep slick spiky.
const HAIR_FRINGE := {
	"short": "wavy", "bowl": "bowl", "sweep": "sweep", "slick": "slick", "messy": "wavy", "curly": "wavy", "spiky": "wavy",
	"ahoge": "wavy", "long": "bowl", "wavy": "sweep", "bob": "bowl", "pony": "sweep", "twin": "bowl", "bun": "wavy", "twinbun": "wavy",
	"braid": "sweep", "monk": "wavy",
}
const HAIR_STYLES := ["short", "bowl", "sweep", "slick", "messy", "curly", "spiky", "ahoge", "long", "wavy", "bob", "pony", "twin", "bun", "twinbun", "braid", "bald", "monk"]


## The lower edge of the hair on the forehead, right to left (x offsets from
## the head centre). It stays above the eyes so the face is never covered.
static func _edge(name: String, cx: float) -> PackedVector2Array:
	var e: Array
	match name:
		"bowl":
			e = [V(23.8, -70), V(22, -74), V(12, -75.5), V(0, -76), V(-12, -75.5), V(-22, -74), V(-23.8, -70)]
		"sweep":
			e = [V(24, -67), V(21, -71), V(15, -75), V(7, -77.5), V(-2, -76.5), V(-11, -74.5), V(-18, -72), V(-24, -69)]
		"slick":
			e = [V(24, -69), V(20, -75), V(8, -78.5), V(-6, -77), V(-18, -74), V(-24, -69)]
		"spiky":
			e = [V(25, -67), V(22, -73), V(18.5, -69.5), V(14.5, -75), V(8.5, -71), V(3.5, -76), V(-1.5, -71.5), V(-6.5, -76), V(-11.5, -72), V(-16.5, -75.5), V(-21, -70), V(-24.5, -67)]
		_:
			e = [V(24, -69.5), V(20.5, -72.5), V(15.5, -71), V(10, -73.8), V(4.5, -72), V(-1, -74.5), V(-7, -72.5), V(-13, -74), V(-19, -72.5), V(-24, -68.5)]
	var out := PackedVector2Array()
	for q in e:
		out.append(V(cx + q.x, q.y))
	return out


## Hair cap over the skull plus its fringe edge. bump > 0 makes it curly.
static func _cap(cx: float, edge: String, bump: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 20 if bump <= 0.0 else 40
	for i in n + 1:
		var a := lerpf(PI * 0.93, PI * 2.07, float(i) / float(n))
		var f := 1.0
		if bump > 0.0:
			f = 1.0 + bump * absf(sin(float(i) * PI / 4.0))
		pts.append(V(cx + cos(a) * 24.6 * f, -73.0 + sin(a) * 22.4 * f))
	pts.append_array(_edge(edge, cx))
	return pts


## Hair, ears, face shape, nose/beard and headgear for the "head" piece.
## Sets k["hide_face"] when the headgear covers the face (visor helms).
static func _head(sh: Array, dec: Array, p: Dictionary, k: Dictionary, view: String) -> void:
	var side := view == "side"
	var back := view == "back"
	var piece := "head"
	var cx := 2.0 if side else 0.0
	var lean := 5.0 if side else 0.0
	var skin: Color = k["skin"]
	var hair: Color = k["hair"]
	var style: String = k["style"]
	var gear: String = k["gear"]
	var hc: Color = k["helm_col"]
	var covers: bool = gear in HIDE_HAIR
	var hair_dk := hair.darkened(0.12)
	hair_dk.a = 0.35
	var ribbon: Color = p.get("ribbon", Color(0.86, 0.3, 0.36))
	k["hide_face"] = false
	# --- hair behind the head, or a hood
	if gear == "hood":
		_sh(sh, E(0, -71, 28.5 if side else 29.0, 28.0 if side else 28.5), hc, piece, 1.0)
	else:
		match style:
			"long", "wavy":
				var hx := -4.0 if side else 0.0
				_sh(sh, E(hx, -66, 22.0 if side else 24.0, 25.0), hair, piece, 1.0)
				for i in 7:
					var u := float(i) / 6.0
					var x0 := lerpf(-21.0, 21.0, u) + hx
					var top := V(x0 * 0.75 + hx * 0.25, -90.0 + absf(u - 0.5) * 12.0)
					var ty := -34.0 + float(i % 2) * 5.0 - (1.0 - absf(u - 0.5) * 2.0) * 3.0
					var bot := V(x0 * 1.12 - hx * 0.1, ty)
					var ctrl := top.lerp(bot, 0.5) + V((u - 0.5) * 9.0, 0.0)
					_strand(sh, dec, top, ctrl, bot, 12.5, hair.darkened(0.05) if i % 2 == 0 else hair.lightened(0.04), false)
			"bob":
				_sh(sh, E(-3, -70, 26, 24) if side else E(0, -69, 27, 25), hair, piece, 1.0)
			"pony":
				if side:
					_sh(sh, _lock(V(-12, -88), V(-38, -86), V(-30, -52), 13.0, 8.0), hair, piece, 1.0)
					_sh(sh, E(-14, -86, 4.5, 5.5, 10), ribbon, piece)
				elif not back:
					_sh(sh, _lock(V(-16, -86), V(-38, -82), V(-30, -52), 12.0, 8.0), hair, piece, 1.0)
					_sh(sh, E(-17, -85, 4.5, 5.0, 10), ribbon, piece)
			"twin":
				if side:
					_sh(sh, _lock(V(-17, -82), V(-38, -78), V(-30, -46), 12.0, 8.0), hair, piece, 1.0)
					_sh(sh, E(-19, -81, 4.5, 5.0, 10), ribbon, piece)
				else:
					for sg in [-1.0, 1.0]:
						_sh(sh, _lock(V(sg * 18, -82), V(sg * 40, -78), V(sg * 31, -46), 12.0, 8.0), hair, piece, 1.0)
						_sh(sh, E(sg * 19.5, -81, 4.5, 5.0, 10), ribbon, piece)
			"bun":
				_sh(sh, E(-8, -97, 10, 9.5) if side else E(0, -98, 10, 9.5), hair, piece, 1.0)
			"twinbun":
				if side:
					_sh(sh, E(-9, -95, 8.5, 8.0), hair, piece, 1.0)
					_sh(sh, E(12, -95, 8.5, 8.0), hair, piece, 1.0)
				else:
					for sg in [-1.0, 1.0]:
						_sh(sh, E(sg * 15, -94, 8.5, 8.0), hair, piece, 1.0)
	# --- ears: small and round, mostly hidden by the head
	var ear_ok: bool = gear not in HIDE_EARS
	if ear_ok and not side:
		for sg in [-1.0, 1.0]:
			_sh(sh, E(sg * 23.4, -66, 4.8, 6.0, 12), skin.darkened(0.05), piece)
	if gear == "coif":
		_sh(sh, head(cx, -71, 27.0, 24.5, 0.22, lean), hc, piece, 2.0)
	_sh(sh, head(cx, -71, float(p.get("face_w", 23.0)), 21.5, float(p.get("chin", 0.22)), lean), skin, piece)
	if ear_ok:
		if side:
			_sh(sh, E(-8, -64.5, 4.2, 5.6, 12), skin.darkened(0.05), piece)
			_dp(dec, E(-8.3, -64.5, 1.5, 2.8, 8), skin.darkened(0.14), piece)
		elif not back:
			for sg in [-1.0, 1.0]:
				_dp(dec, E(sg * 24.4, -66, 1.8, 3.2, 8), skin.darkened(0.14), piece)
	# --- nose, moustache, beard
	var beard = p.get("beard", false)
	var nose: String = p.get("nose", "none")
	if not back:
		if nose == "big":
			if side:
				_sh(sh, E(28.5, -62.5, 6.8, 5.8, 14), skin.darkened(0.04), piece)
				_dp(dec, E(27, -64, 2.4, 1.6, 8), _hi(skin, 0.15, 0.7), piece)
			else:
				_sh(sh, E(0, -61, 6.0, 5.2, 14), skin.darkened(0.05), piece)
				_dp(dec, E(-1.4, -62.5, 2.2, 1.5, 8), _hi(skin, 0.15, 0.7), piece)
		elif nose == "small":
			if side:
				_sh(sh, E(27.5, -62.5, 3.0, 2.8, 10), skin.darkened(0.05), piece)
			else:
				_dp(dec, E(0, -61.5, 2.3, 1.8, 10), skin.darkened(0.12), piece)
		var bs := ""
		if beard is bool:
			bs = "short" if beard else ""
		elif beard is String:
			bs = beard
		var bmass := hair.darkened(0.04)
		if bs == "short" or bs == "long":
			var lng := bs == "long"
			var nb := 7 if lng else 5
			if side:
				_sh(sh, E(14.0, -58.0, 11.0, 7.0 if not lng else 10.0, 14), bmass, piece)
			else:
				_sh(sh, E(0.0, -58.0, 15.5, 7.0 if not lng else 10.0, 16), bmass, piece)
			for i in nb:
				var u := float(i) / float(nb - 1)
				var mid := 1.0 - absf(u - 0.5) * 2.0
				var depth := (30.0 if lng else 12.0) * (0.55 + 0.45 * mid)
				var col := hair if i % 2 == 0 else hair.darkened(0.08)
				if side:
					var bx := lerpf(3.0, 24.0, u)
					_strand(sh, dec, V(bx, -60.0), V(bx - 4.0 + sin(float(i)) * 2.0, -58.0 + depth * 0.5), V(bx - 1.0 + sin(float(i) * 2.0) * 2.0, -58.0 + depth), 8.0, col, true)
				else:
					var bx2 := lerpf(-14.0, 14.0, u)
					var sway := (u - 0.5) * 5.0
					_strand(sh, dec, V(bx2 * 0.95, -60.0), V(bx2 + sway * 0.6, -58.0 + depth * 0.5), V(bx2 * 0.8 + sway + sin(float(i) * 2.3) * 1.5, -58.0 + depth), 8.5, col, true)
		elif bs == "goatee":
			for i in 3:
				var gx := -4.0 + float(i) * 4.0 + (14.0 if side else 0.0)
				_strand(sh, dec, V(gx, -54.0), V(gx + (i - 1) * 1.5, -49.0), V(gx + (i - 1) * 2.0, -43.0 - (1 - absi(i - 1)) * 2.0), 6.0, hair if i != 1 else hair.darkened(0.08), true)
		if p.get("mustache", false):
			var mc := hair.darkened(0.03)
			if side:
				_strand(sh, dec, V(17, -59.5), V(27, -56.0), V(34, -61.0), 6.5, mc, true)
			else:
				for sg in [-1.0, 1.0]:
					_strand(sh, dec, V(0.0, -59.0), V(sg * 8.5, -55.0), V(sg * 17.5, -60.5), 6.5, mc, true)
	# --- hair on the head
	if back:
		if gear not in ["visor", "plume", "coif", "hood", "turban"] and style != "bald":
			_hair_back(sh, dec, p, k)
	elif not covers and style != "bald":
		_hair_front(sh, dec, p, k, side)
	# --- headgear
	_helm(sh, dec, p, k, view)
	if p.get("goggles", false) and not back:
		var gc := Color(0.82, 0.66, 0.30)
		if side:
			_sh(sh, E(14, -83, 6.4, 6.0, 14), gc, piece)
			_dp(dec, E(14, -83, 4.4, 4.0, 12), Color(0.55, 0.82, 0.92), piece)
			_dl(dec, V(8, -83), V(-18, -80), Color(0.30, 0.22, 0.16), 2.4, piece)
		else:
			for sg in [-1.0, 1.0]:
				_sh(sh, E(sg * 8.4, -83, 6.8, 6.2, 14), gc, piece)
				_dp(dec, E(sg * 8.4, -83, 4.8, 4.3, 12), Color(0.55, 0.82, 0.92), piece)
			_dl(dec, V(-24, -81), V(-15, -83), Color(0.30, 0.22, 0.16), 2.4, piece)
			_dl(dec, V(15, -83), V(24, -81), Color(0.30, 0.22, 0.16), 2.4, piece)
			_dl(dec, V(-2, -83), V(2, -83), Color(0.30, 0.22, 0.16), 2.4, piece)
	# braid and side locks hang in front of the ear
	if style == "braid" and gear != "hood":
		var bx := -20.0 if side else -22.0
		var rib := ribbon
		for i in 4:
			_sh(sh, E(bx - float(i) * 1.5, -66.0 + float(i) * 8.0, 4.6, 5.2, 10), hair if i % 2 == 0 else hair.darkened(0.08), piece, 1.0)
		_sh(sh, E(bx - 5.0, -34, 3.6, 3.2, 10), rib, piece)
	if style in ["long", "wavy"] and gear != "hood" and not back:
		var lc := hair.lightened(0.05)
		if side:
			_strand(sh, dec, V(-2, -84), V(-14, -62), V(-8, -36), 11.0, lc, true)
			_strand(sh, dec, V(-8, -80), V(-17, -60), V(-13, -40), 8.0, hair.darkened(0.06), true)
		else:
			for sg in [-1.0, 1.0]:
				_strand(sh, dec, V(sg * 19.0, -84), V(sg * 29.0, -62), V(sg * 23.5, -35), 11.0, lc, true)
				_strand(sh, dec, V(sg * 22.0, -78), V(sg * 28.0, -60), V(sg * 25.0, -42), 7.0, hair.darkened(0.06), true)


## Front/side hair above the face: outer strands flicking from the crown, a
## cap, a swept fringe of overlapping leaf strands that stays above the eyes,
## and a little style-specific detail. Strands only appear on bare heads (a
## hat or crown hides them), and layer in alternating shades like cut paper.
static func _hair_front(sh: Array, dec: Array, p: Dictionary, k: Dictionary, side: bool) -> void:
	var piece := "head"
	var hair: Color = k["hair"]
	var style: String = k["style"]
	var cx := 2.0 if side else 0.0
	var fringe: String = p.get("fringe", HAIR_FRINGE.get(style, "wavy"))
	var hi := _hi(hair, 0.3, 0.42)
	var dk := hair.darkened(0.22)
	dk.a = 0.5
	var bare: bool = k["gear"] == "none"
	var open: bool = k["gear"] in ["none", "crown"]
	if bare and style in ["spiky", "messy", "short", "curly", "sweep", "ahoge", "wavy", "long", "pony", "twin", "bun", "twinbun", "braid"]:
		var n := 7 if style in ["spiky", "messy"] else 5
		var ln := 15.0 if style == "spiky" else (13.0 if style == "messy" else 8.5)
		_flicks(sh, dec, hair, cx, n, ln, true)
	_sh(sh, _cap(cx, fringe, 0.065 if style == "curly" else 0.0), hair, piece, 1.0)
	if open and style not in ["monk", "slick", "bowl", "bob"]:
		# swept fringe: leaf strands from the parting across the forehead
		var nl := 5
		for j in nl:
			var u := float(j) / float(nl - 1)
			var top := V(cx - 5.0 + u * 11.0, -96.0 + absf(u - 0.5) * 3.0)
			var bot := V(cx + lerpf(-21.0, 20.0, u), -73.5 + sin(u * PI) * -1.5)
			var ctrl := top.lerp(bot, 0.5) + V(4.5 - u * 2.0, -2.5)
			var col := hair.lightened(0.05) if j % 2 == 0 else hair.darkened(0.06)
			_strand(sh, dec, top, ctrl, bot, 13.5, col, true)
	match style:
		"ahoge":
			_sh(sh, _stroke(_curve(V(cx + 1, -94), V(cx - 8, -110), V(cx + 8, -111), 8), 3.6, 0.25), hair, piece, 1.0)
		"bun":
			_dp(dec, E(cx - (8.0 if side else 0.0), -91, 5.5, 1.6, 10), p.get("ribbon", Color(0.86, 0.3, 0.36)), piece)
		"monk":
			_dp(dec, E(cx, -86, 15.5, 8.5, 20), k["skin"], piece)
			_dpl(dec, Paint._closed(E(cx, -86, 15.5, 8.5, 20)), k["skin"].darkened(0.25), 0.9, piece)
		"slick":
			_dl(dec, V(cx + 5, -93), V(cx + 8, -78), dk, 0.9, piece)
	if open and style in ["slick", "bowl", "bob"]:
		_dpl(dec, arc(cx, -73, 19.0, 17.0, PI * 1.16, PI * 1.58, 10), hi, 3.2, piece)


## Hair seen from behind: a full cap plus the style's tails and buns, with
## leaf strands sweeping down from a crown swirl.
static func _hair_back(sh: Array, dec: Array, p: Dictionary, k: Dictionary) -> void:
	var piece := "head"
	var hair: Color = k["hair"]
	var style: String = k["style"]
	var hi := _hi(hair, 0.3, 0.42)
	var ribbon: Color = p.get("ribbon", Color(0.86, 0.3, 0.36))
	var bare: bool = k["gear"] == "none"
	var open: bool = k["gear"] in ["none", "crown"]
	if bare and style in ["spiky", "messy", "short", "curly", "sweep", "ahoge", "wavy", "long", "pony", "twin", "bun", "twinbun", "braid"]:
		var n := 7 if style in ["spiky", "messy"] else 5
		var ln := 15.0 if style == "spiky" else (13.0 if style == "messy" else 8.5)
		_flicks(sh, dec, hair, 0.0, n, ln, false)
	match style:
		"bob":
			_sh(sh, E(0, -70, 26.5, 24.5), hair, piece, 1.0)
		"monk":
			_sh(sh, E(0, -68, 24.5, 20), hair, piece, 1.0)
			_dp(dec, E(0, -86, 13, 8), k["skin"], piece)
		"curly":
			_sh(sh, _cap(0.0, "bowl", 0.065), hair, piece, 1.0)
			_sh(sh, E(0, -70, 24.5, 21), hair, piece, 1.0)
		_:
			_sh(sh, E(0, -72, 24.5, 23), hair, piece, 1.0)
	match style:
		"pony":
			_strand(sh, dec, V(0, -84), V(3, -64), V(0, -40), 14.0, hair.darkened(0.06), open)
			_sh(sh, E(0, -84, 5.5, 4.5, 12), ribbon, piece)
		"bun":
			_sh(sh, E(0, -98, 10, 9.5), hair, piece, 1.0)
			_dp(dec, E(0, -91, 5.5, 1.6, 10), ribbon, piece)
		"twinbun":
			for sg in [-1.0, 1.0]:
				_sh(sh, E(sg * 15, -94, 8.5, 8.0), hair, piece, 1.0)
		"ahoge":
			_sh(sh, _stroke(_curve(V(1, -94), V(-8, -110), V(8, -111), 8), 3.6, 0.25), hair, piece, 1.0)
		"braid":
			for i in 4:
				_sh(sh, E(-22.0 - float(i) * 1.5, -66.0 + float(i) * 8.0, 4.6, 5.2, 10), hair if i % 2 == 0 else hair.darkened(0.08), piece, 1.0)
	if open and style not in ["monk", "bald"]:
		# strands sweeping down from a crown swirl
		for j in 7:
			var u := float(j) / 6.0
			var x0 := lerpf(-19.0, 19.0, u)
			var top := V(x0 * 0.25, -92.0 + absf(x0) * 0.1)
			var bot := V(x0 * 1.02, -55.0 - float(j % 2) * 4.0 + (1.0 - absf(u - 0.5) * 2.0) * 3.0)
			var ctrl := top.lerp(bot, 0.5) + V((u - 0.5) * -9.0 + (3.5 if j % 2 == 0 else -3.5), 0.0)
			_strand(sh, dec, top, ctrl, bot, 12.5, hair.lightened(0.05) if j % 2 == 0 else hair.darkened(0.06), true)
	if open and style in ["bob", "monk"]:
		_dpl(dec, arc(0, -73, 19.0, 17.0, PI * 1.16, PI * 1.58, 10), hi, 3.2, piece)


## A feather crest on top of a helm; top_y is the helm's top.
static func _plume(sh: Array, k: Dictionary, cx: float, side: bool, top_y: float) -> void:
	var piece := "head"
	var pc: Color = k["plume"]
	_sh(sh, E(cx, top_y, 4.0, 3.0, 10), (k["helm_col"] as Color).darkened(0.2), piece)
	if side:
		_sh(sh, _leaf(V(cx - 2, top_y), V(cx - 14, top_y - 16), V(cx - 32, top_y - 8), 8.0), pc.darkened(0.1), piece, 1.0)
		_sh(sh, _leaf(V(cx - 2, top_y), V(cx - 20, top_y - 10), V(cx - 35, top_y + 4), 7.0), pc, piece, 1.0)
		_sh(sh, _leaf(V(cx - 2, top_y), V(cx - 12, top_y - 4), V(cx - 28, top_y + 14), 6.0), pc.lightened(0.1), piece, 1.0)
	else:
		_sh(sh, _leaf(V(cx, top_y), V(cx - 12, top_y - 8), V(cx - 20, top_y - 2), 6.0), pc.darkened(0.1), piece, 1.0)
		_sh(sh, _leaf(V(cx, top_y), V(cx + 12, top_y - 8), V(cx + 20, top_y - 2), 6.0), pc.darkened(0.1), piece, 1.0)
		_sh(sh, _leaf(V(cx, top_y), V(cx - 3, top_y - 10), V(cx - 2, top_y - 16), 8.0), pc, piece, 1.0)
		_sh(sh, _leaf(V(cx, top_y), V(cx + 4, top_y - 10), V(cx + 3, top_y - 14), 6.0), pc.lightened(0.12), piece, 1.0)


## Headgear. See the helm list at the top of the chibi section.
static func _helm(sh: Array, dec: Array, p: Dictionary, k: Dictionary, view: String) -> void:
	var side := view == "side"
	var back := view == "back"
	var piece := "head"
	var cx := 2.0 if side else 0.0
	var lean := 5.0 if side else 0.0
	var gear: String = k["gear"]
	var hc: Color = k["helm_col"]
	var hd := hc.darkened(0.2)
	var hl := _hi(hc, 0.35, 0.6)
	match gear:
		"kettle":
			_sh(sh, E(cx, -77.5, 31.5, 5.0, 24), hc.darkened(0.08), piece, 0.0)
			_sh(sh, _dome(cx, -77, 25.0, 23.0), hc, piece)
			_sh(sh, E(cx, -100, 3.0, 3.0, 10), hd, piece)
			_dpl(dec, arc(cx, -77, 24.0, 5.0, 0.15, PI - 0.15, 10), hd, 1.0, piece)
			_dp(dec, PackedVector2Array([V(cx - 15, -92), V(cx - 8, -97), V(cx - 12, -86)]), hl, piece)
			for rx in [-17.0, 17.0]:
				_dc(dec, V(cx + rx, -82.5), 1.1, hd, piece)
			if p.has("plume"):
				_plume(sh, k, cx, side, -99.0)
		"visor", "plume":
			_sh(sh, head(cx, -71.5, 27.5, 24.4, 0.22, lean), hc, piece)
			_dpl(dec, arc(cx, -71.5, 25.5, 23.5, PI * 1.08, PI * 1.92, 14), hd, 1.2, piece)
			_dp(dec, PackedVector2Array([V(cx - 17, -88), V(cx - 8, -93), V(cx - 13, -76)]), hl, piece)
			if gear == "plume":
				_plume(sh, k, cx, side, -96.0)
			if not back:
				k["hide_face"] = true
				var slit := PackedVector2Array()
				if side:
					slit = PackedVector2Array([V(7, -72.5), V(29, -72.5), V(30.5, -66.5), V(7, -66.5)])
				else:
					slit = R(-17, -72.5, 34, 6)
				_sh(sh, slit, INK, piece)
				# brow band, chin band and rivets make it read as plate
				if side:
					_dpl(dec, _curve(V(-22, -77), V(8, -83), V(29, -76.5), 8), hd, 1.3, piece)
					_dpl(dec, _curve(V(-12, -55), V(8, -53), V(28, -59), 8), hd, 1.3, piece)
					_sh(sh, PackedVector2Array([V(20, -80), V(24.5, -80), V(26.5, -66), V(29.5, -58), V(24, -56), V(20, -62)]), hc.lightened(0.1), piece)
					_dc(dec, V(13, -69.5), 1.0, Color(0.95, 0.95, 0.85), piece)
					_dc(dec, V(24.5, -69.5), 1.0, Color(0.95, 0.95, 0.85), piece)
					for q in [V(-8, -57.5), V(0, -56.5), V(9, -56.5), V(18, -58)]:
						_dc(dec, q, 0.9, hd, piece)
				else:
					_dpl(dec, _curve(V(-25, -76), V(0, -82), V(25, -76), 8), hd, 1.3, piece)
					_dpl(dec, _curve(V(-21, -56), V(0, -52), V(21, -56), 8), hd, 1.3, piece)
					_dl(dec, V(0, -95), V(0, -81), hd, 1.1, piece)
					_dl(dec, V(1.4, -95), V(1.4, -81), hl, 1.0, piece)
					_sh(sh, R(-2.6, -80, 5.2, 26), hc.lightened(0.1), piece)
					_dc(dec, V(-9.3, -69.5), 1.0, Color(0.95, 0.95, 0.85), piece)
					_dc(dec, V(9.3, -69.5), 1.0, Color(0.95, 0.95, 0.85), piece)
					for q in [V(-13, -62), V(-10.5, -59.5), V(-13, -57), V(13, -62), V(10.5, -59.5), V(13, -57)]:
						_dc(dec, q, 0.8, hd, piece)
					for sx in [-1.0, 1.0]:
						_dc(dec, V(sx * 22, -80), 1.0, hd, piece)
						_dc(dec, V(sx * 22.5, -64), 1.0, hd, piece)
		"viking", "winged":
			_sh(sh, _dome(cx, -77, 24.5, 21.5), hc, piece)
			_sh(sh, R(cx - 25.2, -82, 50.4, 6.5), hc.darkened(0.12), piece)
			_dl(dec, V(cx - 24, -79), V(cx + 24, -79), _hi(hc, 0.3, 0.6), 1.0, piece)
			for rx in [-18.0, -9.0, 0.0, 9.0, 18.0]:
				_dc(dec, V(cx + rx, -78.8), 1.0, hd, piece)
			if gear == "viking":
				var horn := CREAM
				if side:
					_sh(sh, _stroke(_curve(V(cx + 1, -86), V(cx - 12, -94), V(cx - 12, -109), 8), 8.0, 0.15), horn, piece, 1.0)
				else:
					for sg in [-1.0, 1.0]:
						_sh(sh, _stroke(_curve(V(cx + sg * 22, -85), V(cx + sg * 36, -90), V(cx + sg * 37, -107), 8), 8.0, 0.15), horn, piece, 1.0)
			else:
				var wc := Color(0.97, 0.96, 0.93)
				if side:
					_sh(sh, _leaf(V(cx - 1, -86), V(cx - 18, -98), V(cx - 24, -86), 9.0), wc.darkened(0.06), piece, 1.0)
					_sh(sh, _leaf(V(cx - 1, -88), V(cx - 12, -104), V(cx - 20, -102), 9.0), wc, piece, 1.0)
					_sh(sh, _leaf(V(cx - 1, -85), V(cx - 14, -92), V(cx - 28, -94), 8.0), wc.darkened(0.03), piece, 1.0)
				else:
					for sg in [-1.0, 1.0]:
						_sh(sh, _leaf(V(cx + sg * 22, -85), V(cx + sg * 32, -92), V(cx + sg * 41, -80), 9.0), wc.darkened(0.06), piece, 1.0)
						_sh(sh, _leaf(V(cx + sg * 22, -86), V(cx + sg * 30, -98), V(cx + sg * 40, -100), 9.0), wc, piece, 1.0)
						_sh(sh, _leaf(V(cx + sg * 22, -85), V(cx + sg * 35, -90), V(cx + sg * 43, -91), 8.0), wc.darkened(0.03), piece, 1.0)
			if not back:
				if side:
					_sh(sh, PackedVector2Array([V(24, -82), V(28.5, -82), V(31, -66), V(27.5, -60), V(24, -64)]), hc.lightened(0.05), piece)
				else:
					_sh(sh, PackedVector2Array([V(-2.4, -82), V(2.4, -82), V(2.4, -62), V(0, -58.5), V(-2.4, -62)]), hc.lightened(0.05), piece)
		"crown":
			var cc: Color = hc
			var pts := PackedVector2Array()
			var w := 17.0 if not side else 16.0
			pts.append(V(cx - w, -85))
			for i in 5:
				var px := cx - w + 2.0 + float(i) * (2.0 * w - 4.0) / 4.0
				pts.append(V(px - 3.5 if i > 0 else px - 1.0, -93))
				pts.append(V(px, -101.5 if i % 2 == 0 else -98.5))
				if i == 4:
					pts.append(V(px + 1.0, -93))
			pts.append(V(cx + w, -85))
			_sh(sh, pts, cc, piece)
			_sh(sh, R(cx - w - 0.5, -88, 2.0 * w + 1.0, 4.5), cc.darkened(0.08), piece)
			var jew := [Color(0.88, 0.22, 0.30), Color(0.30, 0.55, 0.92), Color(0.30, 0.72, 0.45)]
			for i in 5:
				var px := cx - w + 2.0 + float(i) * (2.0 * w - 4.0) / 4.0
				_dc(dec, V(px, -101.0 if i % 2 == 0 else -98.0), 1.3, Color(0.98, 0.95, 0.85), piece)
				if i % 2 == 1:
					_dc(dec, V(px, -85.8), 1.4, jew[(i / 2) % 3], piece)
			_dc(dec, V(cx, -85.8), 1.5, Color(0.98, 0.95, 0.85), piece)
		"wizard", "witch":
			var tall := gear == "witch"
			_sh(sh, E(cx, -80.5, 33.0 if not tall else 34.0, 6.2, 26), hc.darkened(0.06), piece, 1.0)
			var tip := V(cx + (22 if tall else 17), -103 if tall else -106)
			var left := _curve(V(cx - 19, -81), V(cx - 14, -101), V(cx + 8, -112 if not tall else -111), 8)
			var right := _curve(tip, V(cx + 9, -96), V(cx + 19, -81), 8)
			var cone := PackedVector2Array(left)
			cone.append_array(right)
			_sh(sh, cone, hc, piece, 1.0)
			var band: Color = p.get("band", Color(0.92, 0.76, 0.30) if not tall else Color(0.86, 0.50, 0.20))
			_dp(dec, PackedVector2Array([V(cx - 18.8, -81), V(cx + 18.8, -81), V(cx + 17.4, -87.5), V(cx - 17.4, -87.5)]), band, piece)
			if tall:
				_dpl(dec, PackedVector2Array([V(cx - 4.5, -88), V(cx + 4.5, -88), V(cx + 4.5, -81), V(cx - 4.5, -81), V(cx - 4.5, -88)]), Color(0.95, 0.85, 0.5), 1.2, piece)
			else:
				_dp(dec, _star(V(cx - 4, -98), 3.8, 1.7), Color(1.0, 0.88, 0.40), piece)
				_dp(dec, _star(V(cx + 5, -92), 2.4, 1.1), Color(1.0, 0.88, 0.40), piece)
				_dp(dec, E(cx + 7, -102, 1.6, 1.6, 8), Color(1.0, 0.95, 0.7), piece)
		"turban":
			if side:
				_sh(sh, PackedVector2Array([V(-20, -82), V(-30, -70), V(-26, -58), V(-17, -70)]), hc.darkened(0.12), piece, 1.0)
			else:
				_sh(sh, PackedVector2Array([V(-22, -82), V(-31, -70), V(-27, -58), V(-18, -70)]), hc.darkened(0.12), piece, 1.0)
			_sh(sh, E(cx, -86, 27.5, 16.0, 24), hc, piece, 1.0)
			for i in 3:
				var off := float(i) * 6.0 - 6.0
				_dpl(dec, _curve(V(cx - 26, -80 + off * 0.2), V(cx - 2, -97 + off), V(cx + 25, -84 + off * 0.2), 8), hc.darkened(0.2), 1.1, piece)
			var gx := cx + (13.0 if side else 0.0)
			_dc(dec, V(gx, -80), 3.0, Color(0.88, 0.70, 0.30), piece)
			_dc(dec, V(gx, -80), 1.7, Color(0.85, 0.22, 0.30), piece)
		"straw":
			_sh(sh, E(cx, -81.5, 36.0, 6.8, 26), hc.darkened(0.04), piece, 1.0)
			_sh(sh, _dome(cx, -81, 19.5, 16.0), hc, piece, 1.0)
			_dp(dec, PackedVector2Array([V(cx - 19.6, -85), V(cx + 19.6, -85), V(cx + 20.2, -80.5), V(cx - 20.2, -80.5)]), p.get("band", Color(0.78, 0.26, 0.24)), piece)
		"fur":
			var fp := PackedVector2Array()
			for i in 29:
				var a := PI + PI * float(i) / 28.0
				var rr := 1.0 + (0.07 if i % 2 == 0 else -0.03)
				fp.append(V(cx + cos(a) * 28.0 * rr, -77 + sin(a) * 21.0 * rr))
			_sh(sh, E(cx - 23.5, -67, 7.0, 11.0, 12), hc.darkened(0.05), piece, 1.0)
			_sh(sh, E(cx + 23.5, -67, 7.0, 11.0, 12), hc.darkened(0.05), piece, 1.0)
			_sh(sh, fp, hc, piece, 1.0)
			_sh(sh, E(cx, -77.5, 28.5, 5.5, 22), hc.lightened(0.12), piece, 1.0)
		"beanie":
			_sh(sh, _dome(cx, -74, 24.5, 22.0), hc, piece, 1.0)
			_sh(sh, PackedVector2Array([V(cx - 25.2, -76), V(cx + 25.2, -76), V(cx + 25.6, -85), V(cx - 25.6, -85)]), hc.lightened(0.1), piece, 1.0)
			_sh(sh, E(cx, -98.5, 5.6, 5.4, 12), hc.lightened(0.28), piece, 1.0)
			for rx in [-20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0]:
				_dl(dec, V(cx + rx, -76.5), V(cx + rx, -84.5), hc.darkened(0.15), 0.8, piece)
		"tricorn":
			var tc := hc
			if side:
				_sh(sh, PackedVector2Array([V(cx - 31, -79), V(cx - 20, -94), V(cx + 4, -99), V(cx + 33, -83), V(cx + 12, -84), V(cx - 10, -81)]), tc, piece, 1.0)
				_dpl(dec, PackedVector2Array([V(cx - 31, -79), V(cx - 20, -94), V(cx + 4, -99), V(cx + 33, -83)]), Color(0.86, 0.72, 0.34), 1.3, piece)
				_sh(sh, _leaf(V(cx - 6, -97), V(cx - 20, -106), V(cx - 32, -98), 7.0), Color(0.95, 0.94, 0.88), piece, 1.0)
			else:
				_sh(sh, PackedVector2Array([V(cx - 34, -79), V(cx - 23, -95), V(cx - 4, -99), V(cx + 4, -99), V(cx + 23, -95), V(cx + 34, -79), V(cx + 14, -84), V(cx, -78), V(cx - 14, -84)]), tc, piece, 1.0)
				_dpl(dec, PackedVector2Array([V(cx - 34, -79), V(cx - 23, -95), V(cx - 4, -99), V(cx + 4, -99), V(cx + 23, -95), V(cx + 34, -79)]), Color(0.86, 0.72, 0.34), 1.3, piece)
				_sh(sh, _leaf(V(cx + 20, -94), V(cx + 30, -106), V(cx + 40, -98), 7.0), Color(0.95, 0.94, 0.88), piece, 1.0)
		"hardhat":
			_sh(sh, _dome(cx, -76, 24.5, 21.5), hc, piece, 1.0)
			if side:
				_sh(sh, PackedVector2Array([V(cx - 26, -79), V(cx + 36, -79), V(cx + 36, -74.5), V(cx - 26, -74.5)]), hc.darkened(0.1), piece)
			else:
				_sh(sh, R(cx - 26.5, -79, 53, 5), hc.darkened(0.1), piece)
			_dp(dec, R(cx - 3, -97.5, 6, 20), hc.darkened(0.12), piece)
			_dp(dec, PackedVector2Array([V(cx - 16, -90), V(cx - 8, -95), V(cx - 12, -84)]), _hi(hc, 0.3, 0.6), piece)
			if not back:
				var lp := V(cx + 17, -86) if side else V(cx, -90)
				_sh(sh, E(lp.x, lp.y, 5.2, 5.2, 12), Color(0.99, 0.95, 0.70), piece)
				_dc(dec, lp, 2.6, Color(1.0, 1.0, 0.9), piece)
				_dc(dec, lp, 9.5, Color(1.0, 0.95, 0.5, 0.18), piece)
		"sailor":
			_sh(sh, E(cx, -85, 25.0, 12.0, 22), hc, piece, 1.0)
			_dp(dec, PackedVector2Array([V(cx - 24.5, -82), V(cx + 24.5, -82), V(cx + 25, -78), V(cx - 25, -78)]), Color(0.24, 0.32, 0.55), piece)
			_dl(dec, V(cx - 24, -86.5), V(cx + 24, -86.5), Color(0.24, 0.32, 0.55), 1.2, piece)
			if side or back:
				_sh(sh, PackedVector2Array([V(cx - 24, -80), V(cx - 32, -72), V(cx - 28, -68), V(cx - 22, -76)]), Color(0.24, 0.32, 0.55), piece)
		"tophat":
			_sh(sh, E(cx, -79.5, 27.5, 5.2, 24), hc, piece, 1.0)
			_sh(sh, R(cx - 15, -105, 30, 26), hc, piece, 1.0)
			_sh(sh, E(cx, -105, 15, 3.4, 16), hc.lightened(0.1), piece)
			_dp(dec, R(cx - 15, -86.5, 30, 6), p.get("band_col", Color(0.74, 0.22, 0.26)), piece)
			_dp(dec, PackedVector2Array([V(cx - 11, -103), V(cx - 7, -103), V(cx - 7, -89), V(cx - 11, -89)]), _hi(hc, 0.4, 0.35), piece)
		"bowler":
			_sh(sh, E(cx, -79.5, 26.0, 4.8, 22), hc, piece, 1.0)
			_sh(sh, _dome(cx, -79, 19.5, 17.0), hc, piece, 1.0)
			_dp(dec, PackedVector2Array([V(cx - 19.4, -84), V(cx + 19.4, -84), V(cx + 19.8, -80), V(cx - 19.8, -80)]), hc.lightened(0.18), piece)
			_dp(dec, PackedVector2Array([V(cx - 11, -92), V(cx - 4, -94), V(cx - 8, -86)]), _hi(hc, 0.4, 0.4), piece)
		"toque":
			if side:
				_sh(sh, arc(2, -73, 24, 21, PI * 0.95, TAU, 12), k["hair"], piece)
				_sh(sh, R(-12, -95, 27, 9), hc, piece, 1.0)
				_sh(sh, E(1, -101, 17, 11), hc, piece, 1.0)
			else:
				_sh(sh, arc(0, -73, 24.5, 22.5, PI, TAU, 18), k["hair"], piece)
				_sh(sh, R(-14, -96, 28, 9), hc, piece, 1.0)
				_sh(sh, E(0, -102, 18, 11), hc, piece, 1.0)
		"helmet":
			_sh(sh, _dome(cx, -75, 25.5 if side else 26.0, 24.0 if side else 24.5, 16), hc, piece, 1.0)
			_sh(sh, R(cx - 26, -78, 52, 6), hc.darkened(0.15), piece)
			_sh(sh, E(cx, -101.5 if side else -102, 5, 5, 12), Color(0.86, 0.26, 0.24), piece)
			if not side and not back:
				_sh(sh, R(-1.5, -79, 3, 9), hc.darkened(0.15), piece)
		"cap":
			if side:
				_sh(sh, _dome(2, -76, 23.5, 19.0, 14), hc, piece, 1.0)
				_sh(sh, PackedVector2Array([V(12, -79), V(36, -77), V(34, -72), V(12, -74)]), hc.darkened(0.2), piece)
			else:
				_sh(sh, _dome(0, -76, 24.0, 19.0, 16), hc, piece, 1.0)
				if not back:
					_sh(sh, E(0, -76, 25, 5, 16), hc.darkened(0.2), piece)
		"hood":
			if not back:
				if side:
					_sh(sh, arc(2, -73, 26.5, 26.0, PI * 1.02, TAU * 0.99, 14), hc.lightened(0.06), piece, 1.0)
				else:
					_sh(sh, arc(0, -73, 27.0, 26.0, PI * 1.02, TAU * 0.99, 16), hc.lightened(0.06), piece, 1.0)


# ----- the figure -----

## Scalloped frill under a dress hem.
static func _frill(w: float, y: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := 2.0 * w / float(n)
	var r := step * 0.5
	for i in n:
		var cxs := w - r - step * float(i)
		var a := arc(cxs, y - 2.0, r, r * 1.15, 0.0, PI, 5)
		for j in a.size():
			if i > 0 and j == 0:
				continue
			pts.append(a[j])
	return pts


## About 2.3 heads tall. Feet at y=0, top of the head near y=-96.
## See the parameter list above. view: "side" (facing right), "front", "back".
static func _chibi(c: CanvasItem, p0: Dictionary, size: Vector2, view: String) -> void:
	Paint._begin(c, size, 80.0, 118.0)
	var p := _fx(p0)
	var side := view == "side"
	var back := view == "back"
	var k := _resolve(p)
	var sh: Array = []
	var dec: Array = []
	var armor: String = k["armor"]
	var plate := armor == "plate" or armor == "gold"
	var m: Color = k["m"]
	var md: Color = k["md"]
	var ml: Color = k["ml"]
	var cloth: Color = k["cloth"]
	var robe := p.has("robe")
	var dress: bool = p.get("dress", false)
	var weapon: String = p.get("weapon", "none")
	var belt_col: Color = k["belt"]
	# the head grows a little around the neck
	var hs := float(p.get("head_scale", 1.06))
	if Paint._part == "head" and hs != 1.0:
		var s := minf((size.y - 14.0) / 118.0, (size.x - 14.0) / 80.0)
		var o := Vector2(size.x * 0.5 + Paint._ox, size.y - 7.0)
		var pv := V(1.0 if side else 0.0, -48.0)
		c.draw_set_transform(o + pv * s * (1.0 - hs), 0.0, Vector2(s * hs, s * hs))

	_back_piece(sh, dec, p, k, view)

	var bt := V(-9, -44) if side else V(-11, -44)
	var bh := V(-12, -28) if side else V(-15.5, -27)
	var ft := V(9, -44) if side else V(11, -44)
	var fh := V(12, -28) if side else V(15.5, -27)

	# --- back arm: shield or off-hand item
	var off: String = String(p.get("offhand", ""))
	if off == "" and p.get("lantern", false):
		off = "lantern"
	if off == "" and weapon in ["axe", "double_axe"] and not p.has("shield"):
		off = weapon
	if off == "none":
		off = ""
	var lflip := 1.0 if side else -1.0
	if p.has("shield") and String(p["shield"]) != "none":
		_shield(sh, dec, p, k, view)
	elif off != "":
		_weapon(sh, dec, off, bh, lflip, "back_arm", k, p)
	_arm(sh, dec, "back_arm", bt, bh, k, true, -1.0, robe)

	# --- legs
	if side:
		_leg(sh, dec, "back_leg", -9.5, 8.0, -5.0, k, true)
		_leg(sh, dec, "front_leg", 1.5, 8.0, 7.0, k, false)
	else:
		_leg(sh, dec, "back_leg", -9.5, 8.5, -5.5, k, true)
		_leg(sh, dec, "front_leg", 1.0, 8.5, 5.5, k, false)

	# --- body
	var torso := PackedVector2Array([V(-12.5, -19), V(12.5, -19), V(12, -38), V(8, -47), V(-8, -47), V(-12, -38)])
	var chest := PackedVector2Array([V(-12.4, -25), V(12.4, -25), V(12.2, -38), V(8.2, -47), V(-8.2, -47), V(-12.2, -38)])
	if robe:
		var rc: Color = p["robe"]
		var tc: Color = k["trim"]
		_sh(sh, PackedVector2Array([V(-10, -46), V(10, -46), V(18, -7), V(-18, -7)]), rc, "body", 1.0)
		_dp(dec, PackedVector2Array([V(-17.2, -11.5), V(17.2, -11.5), V(18, -7), V(-18, -7)]), tc, "body")
		if not back:
			_dp(dec, PackedVector2Array([V(-4.5, -47), V(4.5, -47), V(0, -38)]), tc, "body")
		_dl(dec, V(-6, -30), V(-9, -12), rc.darkened(0.2), 0.8, "body")
		_dl(dec, V(6, -30), V(9, -12), rc.darkened(0.2), 0.8, "body")
		_sh(sh, R(-11.5, -28, 23, 3.4), belt_col, "body")
	elif dress:
		_sh(sh, PackedVector2Array([V(-10, -45), V(10, -45), V(17, -12), V(-17, -12)]), cloth, "body", 1.0)
		if p.get("frill", false):
			var fc: Color = p.get("frill_col", cloth.lightened(0.38))
			_sh(sh, _frill(18.5, -9.5, 7), fc, "body", 1.0)
			_dl(dec, V(-17, -13.5), V(17, -13.5), fc.darkened(0.2), 0.8, "body")
		if p.has("sash"):
			_sh(sh, R(-11.2, -35, 22.4, 4.2), p["sash"], "body")
		_sh(sh, R(-7, -47, 14, 3.2), cloth.darkened(0.25), "body")
	else:
		_sh(sh, torso, cloth, "body", 1.0)
		_sh(sh, R(-7, -47, 14, 3.2), cloth.darkened(0.25), "body")
	# vest / armour over the torso
	if not robe and not dress:
		if p.has("vest") and not plate:
			var vc: Color = p["vest"]
			if side or back:
				_sh(sh, chest, vc, "body", 1.0)
			else:
				_sh(sh, PackedVector2Array([V(-12.4, -24), V(12.4, -24), V(12.2, -38), V(8.2, -47), V(4.5, -47), V(0, -34), V(-4.5, -47), V(-8.2, -47), V(-12.2, -38)]), vc, "body", 1.0)
				_dc(dec, V(0, -29), 1.0, GOLD, "body")
		match armor:
			"plate", "gold":
				_sh(sh, chest, m, "body")
				_dp(dec, PackedVector2Array([V(-9, -44), V(-3.5, -45), V(-6, -29), V(-10, -32)]), _hi(m, 0.4, 0.55), "body")
				_dl(dec, V(-12, -33.5), V(12, -33.5), md, 0.8, "body")
				if not p.has("tabard"):
					for q in [V(-9.5, -28), V(9.5, -28), V(-10.2, -40), V(10.2, -40)]:
						_dc(dec, q, 1.0, md, "body")
					if view == "front":
						_dl(dec, V(0, -46), V(0, -26), md, 0.9, "body")
					if back:
						_dl(dec, V(0, -46), V(0, -26), md, 0.9, "body")
				_sh(sh, PackedVector2Array([V(-13.4, -22), V(13.4, -22), V(14.6, -14), V(-14.6, -14)]), m.darkened(0.05), "body")
				_dl(dec, V(-5, -22), V(-5.5, -14), md, 0.8, "body")
				_dl(dec, V(5, -22), V(5.5, -14), md, 0.8, "body")
			"chain":
				_sh(sh, PackedVector2Array([V(-12.6, -17), V(12.6, -17), V(12.2, -38), V(8.2, -47), V(-8.2, -47), V(-12.2, -38)]), m, "body", 2.0)
				_sh(sh, PackedVector2Array([V(-12.8, -23), V(12.8, -23), V(13.4, -15), V(10, -17), V(6, -14.5), V(2, -17), V(-2, -14.5), V(-6, -17), V(-10, -14.5), V(-13.4, -16)]), m.darkened(0.06), "body", 2.0)
			"leather":
				if not p.has("vest"):
					if side or back:
						_sh(sh, chest, LEATHER, "body", 1.0)
					else:
						_sh(sh, PackedVector2Array([V(-12.4, -24), V(12.4, -24), V(12.2, -38), V(8.2, -47), V(4.5, -47), V(0, -35), V(-4.5, -47), V(-8.2, -47), V(-12.2, -38)]), LEATHER, "body", 1.0)
				_dpl(dec, PackedVector2Array([V(-11, -27), V(-11, -39)]), LEATHER.darkened(0.4), 0.8, "body")
				_dpl(dec, PackedVector2Array([V(11, -27), V(11, -39)]), LEATHER.darkened(0.4), 0.8, "body")
	# striped surcoat
	if p.has("tabard"):
		var ta: Color
		var tb: Color
		var tab = p["tabard"]
		if tab is Dictionary:
			ta = tab.get("a", Color(0.78, 0.2, 0.2))
			tb = tab.get("b", Color(0.96, 0.94, 0.88))
		else:
			ta = tab
			tb = ta
		var tw := 8.0 if not side else 8.5
		var bw := 11.0 if not side else 10.0
		var tab_pts := PackedVector2Array([V(-tw, -47), V(tw, -47), V(bw, -13), V(-bw, -13)])
		if back:
			tab_pts = PackedVector2Array([V(-tw, -47), V(tw, -47), V(bw, -13), V(-bw, -13)])
		_sh(sh, tab_pts, tb, "body", 1.0 if ta == tb else 0.0)
		if ta != tb:
			for i in 5:
				if i % 2 == 0:
					var t0 := float(i) / 5.0
					var t1 := float(i + 1) / 5.0
					_dp(dec, PackedVector2Array([V(lerpf(-tw, tw, t0), -46.6), V(lerpf(-tw, tw, t1), -46.6), V(lerpf(-bw, bw, t1), -13.4), V(lerpf(-bw, bw, t0), -13.4)]), ta, "body")
		_dl(dec, V(-bw, -14), V(bw, -14), (ta if ta != tb else ta.darkened(0.3)).darkened(0.35), 1.4, "body")
		if p.has("cross") and not back:
			_emblem(dec, "cross", V(0, -32), 14.0, p["cross"], "body")
	if p.has("stripes") and not armored_body(armor):
		var stc: Color = p["stripes"]
		for yy in [-42.0, -36.0, -30.0]:
			var hw := 11.2 if yy < -38.0 and false else 11.4
			if yy < -38.0:
				hw = lerpf(9.0, 11.4, clampf((yy + 47.0) / 9.0, 0.0, 1.0))
			_dp(dec, R(-hw, yy, hw * 2.0, 2.6), stc, "body")
	if p.has("shirt") and not back:
		var shc: Color = p["shirt"]
		if side:
			_dp(dec, PackedVector2Array([V(4.5, -47), V(9, -47), V(11.5, -38), V(11.5, -31), V(8, -35)]), shc, "body")
			if p.has("tie"):
				_dp(dec, PackedVector2Array([V(7.2, -44), V(9.6, -44), V(10.4, -34), V(8.6, -31.5), V(7, -34)]), p["tie"], "body")
		else:
			_dp(dec, PackedVector2Array([V(-5, -47), V(5, -47), V(0, -33)]), shc, "body")
			_dl(dec, V(-5, -47), V(-9, -36), cloth.darkened(0.35), 0.9, "body")
			_dl(dec, V(5, -47), V(9, -36), cloth.darkened(0.35), 0.9, "body")
			if p.has("tie"):
				var tie: Color = p["tie"]
				_dp(dec, PackedVector2Array([V(-1.4, -45.5), V(1.4, -45.5), V(2.0, -35), V(0, -31), V(-2.0, -35)]), tie, "body")
	# belt
	if not robe and not dress:
		_sh(sh, R(-12.8, -24, 25.6, 3.4), belt_col, "body")
		if not back:
			if side:
				_dp(dec, R(8.2, -24.6, 4.2, 4.6), GOLD, "body")
			else:
				_dp(dec, R(-2.6, -24.6, 5.2, 4.6), GOLD, "body")
				_dp(dec, R(-1.2, -23.4, 2.4, 2.2), belt_col, "body")
	if p.has("apron"):
		var ap: Color = p["apron"]
		if back:
			_dl(dec, V(-9, -44), V(-1, -26), ap, 1.6, "body")
			_dl(dec, V(9, -44), V(1, -26), ap, 1.6, "body")
			_sh(sh, R(-1.8, -27, 3.6, 5), ap, "body")
		elif side:
			_sh(sh, PackedVector2Array([V(-6, -16), V(10, -16), V(9, -41), V(-4, -41)]), ap, "body", 1.0)
		else:
			_sh(sh, PackedVector2Array([V(-8, -17), V(8, -17), V(7, -40), V(-7, -40)]), ap, "body", 1.0)
			_dl(dec, V(-4, -26), V(4, -26), ap.darkened(0.2), 0.8, "body")
	# cloak mantle, scarf
	if p.has("cloak") and not back:
		var cl: Color = p["cloak"]
		if side:
			_sh(sh, PackedVector2Array([V(-11, -37), V(11, -37), V(8, -48), V(-8, -48)]), cl.lightened(0.05), "body", 1.0)
		else:
			_sh(sh, PackedVector2Array([V(-14, -35), V(14, -35), V(9, -48), V(-9, -48)]), cl.lightened(0.05), "body", 1.0)
		_dc(dec, V(1 if side else 0, -44.5), 1.9, GOLD, "body")
		_dl(dec, V(-6, -43), V(6, -43), GOLD, 0.7, "body")
	if p.has("scarf"):
		var sc: Color = p["scarf"]
		_sh(sh, PackedVector2Array([V(-10.5, -50), V(10.5, -50), V(11.5, -43.5), V(-11.5, -43.5)]), sc, "body", 1.0)
		if not side:
			_sh(sh, PackedVector2Array([V(2, -45), V(9, -45), V(10, -29), V(4, -30)]), sc.darkened(0.06), "body", 1.0)
			_dl(dec, V(3.5, -37), V(9.2, -36), sc.lightened(0.4), 1.3, "body")
			_dl(dec, V(3.8, -33), V(9.6, -32), sc.lightened(0.4), 1.3, "body")
		else:
			_sh(sh, PackedVector2Array([V(3, -45), V(9, -45), V(9, -33), V(4, -34)]), sc.darkened(0.06), "body", 1.0)
		_dl(dec, V(-9, -47), V(9, -47), sc.lightened(0.4), 1.2, "body")
	if not back and not armored_body(armor):
		pass
	if back or side:
		_dl(dec, V(0 if back else 0, -45), V(0 if back else 1, -24), INK.lightened(0.25), 0.6, "body")

	# --- head
	_head(sh, dec, p, k, view)

	# --- front arm and its weapon
	if weapon != "none":
		_weapon(sh, dec, weapon, fh, 1.0, "front_arm", k, p)
	_arm(sh, dec, "front_arm", ft, fh, k, false, 1.0, robe)

	_paint(c, sh)
	if Paint._on("head") and not back and not k["hide_face"]:
		var q := p.duplicate()
		if k["gear"] in NO_BROW and q.get("brows", "none") != "bushy":
			q["brows"] = "none"
		if side:
			face(c, V(12, -67), V(21.5, -66.5), 3.5, q, true)
		else:
			face(c, V(-9.3, -66.8), V(9.3, -66.8), 3.8, q, false)
	_decals(c, dec)


static func armored_body(armor: String) -> bool:
	return armor in ["plate", "gold", "chain"]


## The chibi seen from the side (facing right). Params: see the list above.
static func chibi(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	_chibi(c, p, size, "side")


## The same chibi seen from the front (facing the camera) or from the back.
## Pieces match the side view so the rig animates them the same way:
## back_arm = left arm, front_arm = right arm, legs side by side.
static func chibi_front(c: CanvasItem, p: Dictionary, size: Vector2, back: bool) -> void:
	_chibi(c, p, size, "back" if back else "front")


# <<<CHIBI-B-END
# ---------- cute bestiary ----------

## Fluffox: a round orange fox (cute stand-in for the wolf).
static func fluffox(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 110.0, 80.0)
	var fur := Color(0.96, 0.62, 0.30)
	var dark := fur.darkened(0.16)
	var cream := Color(0.99, 0.93, 0.80)
	var sh: Array = []
	sh.append([E(-42, -44, 16, 11), fur, "tail"])
	sh.append([E(-53, -50, 7, 6, 12), cream, "tail"])
	sh.append([pill(V(-18, -24), V(-18, -6), 4.6), dark, "far_back"])
	sh.append([pill(V(17, -24), V(17, -6), 4.6), dark, "far_front"])
	sh.append([E(-4, -32, 28, 18), fur])
	sh.append([E(-2, -25, 17, 8), cream])
	sh.append([pill(V(-13, -24), V(-13, -4), 5.0), fur, "near_back"])
	sh.append([pill(V(21, -24), V(21, -4), 5.0), fur, "near_front"])
	sh.append([PackedVector2Array([V(14, -58), V(17, -78), V(28, -63)]), fur])
	sh.append([PackedVector2Array([V(30, -63), V(38, -78), V(42, -58)]), fur])
	sh.append([E(28, -48, 20, 17), fur])
	sh.append([E(42, -42, 10, 7, 14), cream])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	c.draw_colored_polygon(PackedVector2Array([V(18, -62), V(19, -72), V(25, -63)]), Color(0.98, 0.70, 0.70))
	c.draw_colored_polygon(PackedVector2Array([V(33, -62), V(37, -72), V(39, -60)]), Color(0.98, 0.70, 0.70))
	_eyes(c, V(29, -51), V(40, -50), 3.2)
	c.draw_circle(V(51, -44), 2.4, INK)


## Pebblet: a mossy boulder with rock fists (cute stand-in for the troll).
static func pebblet(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 100.0, 110.0)
	var stone := Color(0.70, 0.70, 0.76)
	var dark := stone.darkened(0.18)
	var moss := Color(0.52, 0.76, 0.42)
	var sh: Array = []
	sh.append([pill(V(-26, -62), V(-30, -44), 8.0), dark, "back_arm"])
	sh.append([E(-31, -36, 10, 9), dark, "back_arm"])
	sh.append([R(-19, -22, 13, 20), dark, "back_leg"])
	sh.append([E(-12, -3, 10, 4.5), dark, "back_leg"])
	sh.append([R(5, -22, 13, 20), stone.darkened(0.08), "front_leg"])
	sh.append([E(12, -3, 10, 4.5), stone.darkened(0.08), "front_leg"])
	sh.append([E(0, -52, 33, 32), stone])
	sh.append([E(-4, -82, 18, 7, 16), moss])
	sh.append([E(10, -86, 5, 4, 10), moss.lightened(0.15)])
	sh.append([pill(V(24, -62), V(29, -44), 8.5), stone.lightened(0.04), "front_arm"])
	sh.append([E(31, -34, 12, 11), stone.lightened(0.04), "front_arm"])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	c.draw_line(V(-18, -40), V(-10, -34), dark, 1.4, true)
	c.draw_line(V(-10, -34), V(-12, -26), dark, 1.4, true)
	_eyes(c, V(8, -58), V(20, -57), 3.6)


## Slime. Cute: mint "gloop" with a leaf sprout. Real: murky bog ooze.
static func slime(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 74.0, 66.0)
	var cute: bool = p.get("cute", true)
	var col := Color(0.55, 0.88, 0.62) if cute else Color(0.34, 0.42, 0.24)
	var pts := E(0, -26, 31, 26, 28)
	for i in pts.size():
		var q := pts[i]
		if q.y > -10.0:
			q.y = -2.0 + (q.y + 10.0) * 0.15
			q.x *= 1.06
		pts[i] = q
	var sh: Array = []
	if cute:
		sh.append([PackedVector2Array([V(-1, -50), V(1, -50), V(1.5, -60), V(-0.5, -60)]), Color(0.36, 0.56, 0.26)])
		sh.append([E(-7, -62, 7, 3.6, 12), Color(0.46, 0.74, 0.32)])
		sh.append([E(7, -63, 7, 3.4, 12), Color(0.50, 0.78, 0.34)])
	sh.append([pts, col])
	Paint._cut(c, sh)
	if cute:
		c.draw_colored_polygon(E(-13, -36, 6, 4, 12), Color(1, 1, 1, 0.75))
		_eyes(c, V(4, -28), V(16, -28), 3.4)
	else:
		for b in [V(-14, -20), V(-4, -40), V(12, -14)]:
			c.draw_arc(b, 3.0, 0.0, TAU, 12, col.lightened(0.3), 1.2, true)
		_mean_eyes(c, V(4, -30), V(15, -30), 2.6, Color(0.95, 0.85, 0.3))


## Mushroom walker. Cute: red-capped puffcap. Real: grey creeper cap.
static func shroom(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 74.0, 92.0)
	var cute: bool = p.get("cute", true)
	var cap := Color(0.92, 0.32, 0.30) if cute else Color(0.50, 0.44, 0.38)
	var stem := Color(0.99, 0.93, 0.82) if cute else Color(0.78, 0.74, 0.64)
	var sh: Array = []
	sh.append([R(-10, -17, 8, 15), stem.darkened(0.15), "back_leg"])
	sh.append([E(-6, -2.5, 7, 3.5, 12), INK.lightened(0.3), "back_leg"])
	sh.append([R(2, -17, 8, 15), stem.darkened(0.06), "front_leg"])
	sh.append([E(7, -2.5, 7, 3.5, 12), INK.lightened(0.35), "front_leg"])
	sh.append([E(0, -32, 17, 18), stem])
	var cap_pts := arc(0, -50, 34, 30, PI, TAU, 18)
	cap_pts.append(V(30, -48))
	cap_pts.append(V(-30, -48))
	sh.append([cap_pts, cap])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	var spot := Color(1, 0.98, 0.94) if cute else cap.lightened(0.18)
	for s in [V(-16, -64),V(2, -72), V(18, -60), V(-2, -58)]:
		c.draw_colored_polygon(E(s.x, s.y, 5.5, 4.2, 12), spot)
	if cute:
		_eyes(c, V(3, -34), V(12, -33.5), 2.8)
	else:
		_mean_eyes(c, V(3, -40), V(12, -40), 2.0, Color(0.7, 0.95, 0.4))


## Bat, seen from the front with both wings out. Cute: zapwing (shoots
## sparks). Real: cave bat.
static func bat(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 124.0, 84.0)
	var cute: bool = p.get("cute", true)
	var fur := Color(0.62, 0.48, 0.86) if cute else Color(0.30, 0.24, 0.24)
	var wing := fur.darkened(0.25)
	var sh: Array = []
	sh.append([PackedVector2Array([V(-10, -46), V(-36, -66), V(-60, -58), V(-52, -46), V(-44, -48), V(-36, -36), V(-26, -42), V(-12, -32)]), wing, "far_wing"])
	sh.append([PackedVector2Array([V(10, -46), V(36, -66), V(60, -58), V(52, -46), V(44, -48), V(36, -36), V(26, -42), V(12, -32)]), wing, "near_wing"])
	sh.append([PackedVector2Array([V(-14, -52), V(-10, -70), V(-3, -56)]), fur])
	sh.append([PackedVector2Array([V(3, -56), V(10, -70), V(14, -52)]), fur])
	sh.append([E(0, -40, 18, 17), fur])
	if cute:
		sh.append([PackedVector2Array([V(-3, -58), V(4, -66), V(1, -60), V(7, -62)]), Color(0.99, 0.86, 0.3)])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	if cute:
		_eyes(c, V(-6, -42), V(6, -42), 3.4)
		c.draw_colored_polygon(PackedVector2Array([V(2, -32), V(5, -32), V(3.5, -28)]), Color.WHITE)
	else:
		_mean_eyes(c, V(-6, -43), V(6, -43), 2.5, Color(0.95, 0.2, 0.15))
		c.draw_colored_polygon(PackedVector2Array([V(-5, -31), V(-2, -31), V(-3.5, -26)]), Color.WHITE)
		c.draw_colored_polygon(PackedVector2Array([V(2, -31), V(5, -31), V(3.5, -26)]), Color.WHITE)


## The boss of the ruins. Cute: Bramble King, a crowned bulb with vine arms
## and a flower club. Real: Thorn Warden.
static func boss(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 170.0, 196.0)
	var cute: bool = p.get("cute", true)
	var body := Color(0.46, 0.74, 0.40) if cute else Color(0.24, 0.34, 0.20)
	var vine := body.darkened(0.2)
	var bloom := Color(0.98, 0.56, 0.72) if cute else Color(0.55, 0.12, 0.12)
	var sh: Array = []
	sh.append([pill(V(-36, -112), V(-66, -60), 9.0), vine, "back_arm"])
	sh.append([E(-68, -52, 13, 12), vine.darkened(0.1), "back_arm"])
	for i in 7:
		var a := lerpf(-2.6, -0.5, float(i) / 6.0)
		var base := V(cos(a) * 50.0, -30 + sin(a) * 10.0)
		sh.append([PackedVector2Array([base + V(-12, 0), base + V(cos(a) * 30, 26), base + V(12, 0)]), body.darkened(0.12)])
	sh.append([E(0, -86, 54, 64, 30), body])
	sh.append([E(-14, -120, 16, 10, 14), body.lightened(0.1)])
	if cute:
		var crown := PackedVector2Array([V(-26, -146), V(-30, -172), V(-14, -158), V(0, -180), V(14, -158), V(30, -172), V(26, -146)])
		sh.append([crown, Color(0.99, 0.80, 0.26)])
	else:
		for i in 5:
			var x := -32.0 + i * 16.0
			sh.append([PackedVector2Array([V(x - 5, -142), V(x, -166), V(x + 5, -142)]), vine.darkened(0.2)])
	sh.append([pill(V(36, -112), V(66, -58), 9.5), vine.lightened(0.05), "front_arm"])
	sh.append([E(70, -48, 20, 18), bloom, "front_arm"])
	sh.append([E(70, -48, 8, 7, 12), Color(0.99, 0.88, 0.40) if cute else Color(0.2, 0.05, 0.05), "front_arm"])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	if cute:
		_eyes(c, V(-2, -98), V(24, -97), 6.0)
		c.draw_circle(V(-20, -164), 3.0, Color(0.4, 0.7, 0.98))
		c.draw_circle(V(0, -166), 3.4, Color(0.95, 0.3, 0.35))
	else:
		_mean_eyes(c, V(-2, -100), V(22, -100), 5.0, Color(0.98, 0.3, 0.2))
	for t in [V(-30, -60), V(28, -52), V(-6, -40)]:
		c.draw_colored_polygon(PackedVector2Array([t, t + V(4, -8), t + V(8, 0)]), vine.darkened(0.3))


# ---------- item icons ----------

static func item(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 64.0, 64.0)
	var sh: Array = []
	match String(p.get("good", "bread")):
		"bread":
			sh.append([E(0, -26, 27, 17), Color(0.90, 0.66, 0.34)])
		"ale":
			sh.append([E(15, -28, 8, 11, 14), WOOD.darkened(0.1)])
			sh.append([R(-16, -50, 28, 46), WOOD])
			sh.append([E(-2, -50, 17, 7, 16), Color(0.99, 0.97, 0.88)])
		"meat":
			sh.append([R(-28, -22, 20, 7), Color(0.98, 0.95, 0.88)])
			sh.append([E(-28, -24, 5, 5, 10), Color(0.98, 0.95, 0.88)])
			sh.append([E(-28, -16, 5, 5, 10), Color(0.98, 0.95, 0.88)])
			sh.append([E(6, -26, 20, 16), Color(0.78, 0.36, 0.26)])
		"hide":
			sh.append([PackedVector2Array([V(-24, -52), V(-8, -46), V(10, -52), V(26, -44), V(20, -24), V(26, -6), V(4, -10), V(-14, -4), V(-26, -14), V(-20, -32)]), Color(0.66, 0.50, 0.34)])
		"ore":
			sh.append([PackedVector2Array([V(-26, -6), V(-22, -32), V(-6, -48), V(14, -44), V(26, -24), V(22, -6)]), Color(0.52, 0.52, 0.58)])
		"blade":
			sh.append([PackedVector2Array([V(-22, -6), V(-17, -11), V(18, -48), V(24, -54), V(20, -44), V(-13, -2)]), METAL])
			sh.append([PackedVector2Array([V(-26, -20), V(-22, -24), V(-6, -6), V(-10, -2)]), Color(0.55, 0.38, 0.16)])
		"gel":
			sh.append([PackedVector2Array([V(0, -54), V(18, -26), V(14, -8), V(0, -2), V(-14, -8), V(-18, -26)]), Color(0.55, 0.88, 0.62)])
		"herb":
			sh.append([R(-1.5, -40, 3, 38), Color(0.36, 0.56, 0.26)])
			sh.append([E(-12, -40, 12, 6, 14), Color(0.44, 0.74, 0.36)])
			sh.append([E(12, -30, 12, 6, 14), Color(0.48, 0.78, 0.38)])
			sh.append([E(0, -52, 7, 10, 14), Color(0.52, 0.82, 0.40)])
		"wheat":
			sh.append([R(-1.5, -30, 3, 28), Color(0.80, 0.66, 0.30)])
			for i in 5:
				sh.append([E(-5, -34 - i * 6.0, 4.5, 3, 10), Color(0.95, 0.80, 0.36)])
				sh.append([E(5, -36 - i * 6.0, 4.5, 3, 10), Color(0.95, 0.80, 0.36)])
		"wood":
			for lg in [[-12.0, -14.0], [12.0, -14.0], [0.0, -36.0]]:
				sh.append([R(lg[0] - 22, lg[1] - 10, 44, 20), WOOD.lightened(0.05)])
				sh.append([E(lg[0] + 22, lg[1], 6, 10, 14), Color(0.90, 0.76, 0.52)])
		"fish":
			sh.append([PackedVector2Array([V(-30, -30), V(-18, -42), V(6, -44), V(22, -32), V(30, -44), V(30, -16), V(22, -28), V(6, -16), V(-18, -18)]), Color(0.52, 0.72, 0.86)])
			sh.append([E(-18, -30, 3.2, 3.2, 10), Color(1, 1, 1)])
		"salt":
			sh.append([PackedVector2Array([V(-24, -6), V(-18, -34), V(-6, -52), V(6, -52), V(18, -34), V(24, -6)]), Color(0.96, 0.96, 0.98)])
			sh.append([R(-9, -52, 18, 8), Color(0.78, 0.55, 0.36)])
		"ingot":
			sh.append([PackedVector2Array([V(-28, -8), V(-20, -34), V(20, -34), V(28, -8)]), Color(0.60, 0.62, 0.70)])
			sh.append([PackedVector2Array([V(-20, -34), V(-14, -44), V(14, -44), V(20, -34)]), Color(0.80, 0.82, 0.88)])
		"gem":
			sh.append([PackedVector2Array([V(-26, -34), V(-14, -52), V(14, -52), V(26, -34), V(0, -4)]), Color(0.48, 0.80, 0.92)])
			sh.append([PackedVector2Array([V(-14, -52), V(0, -34), V(14, -52)]), Color(0.78, 0.95, 1.0)])
		"cloth":
			sh.append([PackedVector2Array([V(-26, -8), V(-26, -44), V(-8, -48), V(10, -44), V(26, -48), V(26, -12), V(8, -8), V(-8, -12)]), Color(0.86, 0.46, 0.62)])
			sh.append([R(-26, -30, 52, 5), Color(0.99, 0.86, 0.90)])
		"spice":
			sh.append([PackedVector2Array([V(-20, -6), V(-22, -34), V(22, -34), V(20, -6)]), Color(0.80, 0.52, 0.28)])
			sh.append([R(-24, -46, 48, 12), Color(0.68, 0.34, 0.24)])
			sh.append([E(0, -24, 7, 7, 12), Color(0.99, 0.86, 0.50)])
		"coin":
			sh.append([E(0, -28, 24, 24, 20), Color(0.98, 0.80, 0.30)])
			sh.append([E(0, -28, 14, 14, 16), Color(0.92, 0.66, 0.20)])
	Paint._cut(c, sh)
	match String(p.get("good", "")):
		"bread":
			for x in [-12.0, 0.0, 12.0]:
				c.draw_line(V(x - 4, -36), V(x + 4, -20), INK, 1.4, true)
		"ore":
			for s in [V(-8, -30), V(6, -22), V(10, -38)]:
				c.draw_circle(s, 2.6, Color(0.95, 0.80, 0.40))
		"gel":
			c.draw_colored_polygon(E(-6, -24, 3, 5, 10), Color(1, 1, 1, 0.8))

