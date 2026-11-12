extends RefCounted
## The drawing of the sentry towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower, Sunspire, the Magma Wall and the menders
## Healing Grove and Phoenix Shrine, per tier (designs: docs/card_tiers/<card id>.md). StructureArt.draw delegates here for the
## ids in StructureTiersC.OWN. Motion comes from the structure's `_age` and SpellArt.jit only, so a LAN client draws the same.
## Tier 1 of every card keeps the plain look (draw returns false), the art starts at tier 2.

const TC = preload("res://cards/structure_tiers_c.gd")

static func draw(st, col: Color) -> bool:
	if st.tier < 2:
		return false
	match String(st.data.get("id", "")):
		"crystal_pylon":
			draw_crystal_pylon(st, col)
			return true
	return false

# ---------------------------------------------------------------- shared shapes

static func hue(i: float, age: float, speed := 0.2, spread := 0.15) -> Color:
	return Color.from_hsv(fposmod(age * speed + i * spread, 1.0), 0.4, 1.0)

## The plain sentry body (box on the ground) in `col`, as the old art had it.
static func sentry_base(st, col: Color) -> void:
	StructureArt.box(st, Rect2(-7, -3, 14, 10), col.darkened(0.3))

## The line of the last shot, from the muzzle `from` (local) to where it hit.
static func shot_line(st, from: Vector2, col: Color, width := 2.0) -> void:
	if st.shot_t > 0.0:
		var to: Vector2 = st.shot_to - st.global_position
		st.draw_line(from, to, Color(col, 0.35), width + 2.0)
		st.draw_line(from, to, Color(col.lightened(0.5), 0.95), width)

## A hexagonal prism seen turning: `w` half width, `h` height, centred on `c`; three facets shaded by their angle.
static func prism(st, c: Vector2, w: float, h: float, rot: float, tint: Color, edge_hue := -1.0, outline := true) -> void:
	var cap := h * 0.22
	var top := c.y - h * 0.5
	var bot := c.y + h * 0.5
	var xs := []
	var cs := []
	for k in 6:
		var a := rot + k * TAU / 6.0
		xs.append(c.x + sin(a) * w)
		cs.append(cos(a))
	for k in 6:
		var k2 := (k + 1) % 6
		if cs[k] + cs[k2] <= 0.0 or absf(xs[k] - xs[k2]) < 0.3:
			continue
		var mid := rot + (k + 0.5) * TAU / 6.0
		var shade := 0.25 + 0.75 * maxf(0.0, cos(mid - 0.7))
		var fill := tint.darkened(0.4).lerp(tint.lightened(0.7), shade)
		var pts := PackedVector2Array([Vector2(c.x, top), Vector2(xs[k], top + cap), Vector2(xs[k], bot - cap), Vector2(c.x, bot), Vector2(xs[k2], bot - cap), Vector2(xs[k2], top + cap)])
		if outline:
			StructureArt.poly(st, pts, fill)
		else:
			st.draw_colored_polygon(pts, fill)
	if edge_hue >= 0.0:
		for k in 6:
			if cs[k] > 0.1:
				st.draw_line(Vector2(xs[k], top + cap), Vector2(xs[k], bot - cap), hue(k, edge_hue), 1.0)

## A little four-ray glint.
static func glint(st, p: Vector2, r: float, col: Color) -> void:
	st.draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), col, 1.0)
	st.draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, 1.0)
	st.draw_line(p + Vector2(-r, -r) * 0.5, p + Vector2(r, r) * 0.5, Color(col, col.a * 0.6), 1.0)
	st.draw_line(p + Vector2(-r, r) * 0.5, p + Vector2(r, -r) * 0.5, Color(col, col.a * 0.6), 1.0)

# ================================================================ Crystal Pylon
const PY_DEEP := Color(0.45, 0.25, 0.75)
const PY_AMETHYST := Color(0.8, 0.6, 1.0)
const PY_WHITE := Color(0.95, 0.92, 1.0)
const PY_GLINT := Color(0.85, 1.0, 1.0)

static func draw_crystal_pylon(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var supercharged: bool = bool(st.vis.get("super", false))
	# 6: runes glow on the ground round it
	if t >= 6:
		for i in 8:
			var a := i * TAU / 8.0 + age * 0.15
			var d := Vector2.from_angle(a)
			st.draw_line(d * 17.0, d * 23.0, Color(PY_AMETHYST, 0.45 + 0.35 * sin(age * 2.0 + i)), 1.5)
		st.draw_arc(Vector2.ZERO, 20.0, 0, TAU, 28, Color(PY_DEEP, 0.4), 1.0)
	# 3: beams to the pylons it resonates with
	if t >= 3:
		for o in TC.linked(st):
			var to: Vector2 = o.global_position - st.global_position
			st.draw_line(Vector2(0, -12), to + Vector2(0, -12), Color(PY_AMETHYST.lerp(PY_WHITE, 0.5), 0.4 + 0.15 * sin(age * 6.0)), 1.5)
	# the body: stone box; 3 inlaid violet lines; 4 a second layer
	sentry_base(st, col)
	if t >= 3:
		st.draw_line(Vector2(-5, 0), Vector2(5, 0), Color(PY_AMETHYST, 0.8), 1.0)
		st.draw_line(Vector2(-5, 3), Vector2(5, 3), Color(PY_AMETHYST, 0.6), 1.0)
	if t >= 4:
		StructureArt.box(st, Rect2(-5, -7, 10, 4), col.darkened(0.15))
		st.draw_line(Vector2(-3, -5), Vector2(3, -5), Color(PY_AMETHYST, 0.9), 1.0)
	# the shards embedded in the last target, shown on the box face (a lance counter takes over from tier 4)
	if t < 4:
		for i in int(round(st.charge * 4.0)):
			st.draw_circle(Vector2(-4.5 + i * 3.0, 5.0), 1.1, PY_WHITE)
	# the crystal floats above the box
	var h := 14.0 if t >= 4 else 10.0
	var w := 4.2 if t >= 4 else 3.4
	var cy := (-9.0 if t >= 4 else -5.0) - h * 0.5 + sin(age * 2.0) * 1.2
	var rot := age * 0.9
	if t >= 5:
		var halo := 12.0 + 1.5 * sin(age * 3.0)
		st.draw_circle(Vector2(0, cy), halo, Color(PY_AMETHYST, 0.25))
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0 + age * 0.5)
			st.draw_line(Vector2(0, cy) + d * (halo - 2.0), Vector2(0, cy) + d * (halo + 5.0), Color(PY_WHITE, 0.6), 1.0)
	if t >= 6:
		st.draw_colored_polygon(PackedVector2Array([Vector2(-3, cy), Vector2(3, cy), Vector2(9, cy - 52.0), Vector2(-9, cy - 52.0)]), Color(PY_AMETHYST, 0.1 + 0.05 * sin(age * 3.0)))
		for i in 6:
			var a := i * TAU / 6.0 + age * 0.7
			var p := Vector2(cos(a) * 15.0, cy + sin(a) * 4.0 + sin(age * 2.0 + i * 1.7) * 3.0)
			var tint := PY_AMETHYST.lerp(Color.from_hsv(fposmod(age * 0.1 + i / 6.0, 1.0), 0.5, 1.0), 0.45)
			prism(st, p, 1.8, 5.0 + (i % 3), a * 1.3, tint, -1.0, false)
	elif t >= 3:
		for i in 2:
			var a := age * 2.0 + i * PI
			var p := Vector2(cos(a) * 9.0, cy + sin(a) * 3.0)
			prism(st, p, 1.6, 5.0, rot * 1.5 + i, PY_AMETHYST, -1.0, false)
	prism(st, Vector2(0, cy), w, h, rot, PY_AMETHYST.lerp(PY_DEEP, 0.25), age if t >= 5 else -1.0)
	if supercharged:
		st.draw_circle(Vector2(0, cy), 9.0, Color(PY_WHITE, 0.3 + 0.2 * sin(age * 20.0)))
	# a glint star every two seconds
	var g := fposmod(age, 2.0)
	if g < 0.4:
		glint(st, Vector2(2, cy - h * 0.2), 5.0 * sin(g / 0.4 * PI), Color(PY_GLINT, 0.9))
	# 4: the lance lens at the tip charges with the shots
	var tip := Vector2(0, cy - h * 0.5)
	if t >= 4:
		st.draw_circle(tip, 1.0 + 3.0 * st.charge, Color(1, 1, 1, 0.6 + 0.4 * st.charge))
	shot_line(st, tip, PY_AMETHYST.lerp(PY_WHITE, 0.4))
