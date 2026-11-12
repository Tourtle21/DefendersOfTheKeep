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
		"storm_spire":
			draw_storm_spire(st, col)
			return true
		"magma_wall":
			draw_magma_wall(st, col)
			return true
		"venom_tower":
			draw_venom_tower(st, col)
			return true
		"prism_tower":
			draw_prism_tower(st, col)
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

## A short zig-zag of `n` segments from `a` to `b`, kinked by `kink` px (deterministic from `seed`).
static func zig(st, a: Vector2, b: Vector2, n: int, kink: float, seed: float, col: Color, width := 1.0) -> void:
	var pts := PackedVector2Array([a])
	var side := (b - a).orthogonal().normalized()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + side * (SpellArt.jit(i, seed) - 0.5) * 2.0 * kink)
	pts.append(b)
	st.draw_polyline(pts, col, width)

## A dashed circle.
static func dashed(st, c: Vector2, r: float, col: Color, dashes: int, phase := 0.0) -> void:
	for i in dashes:
		var a0 := phase + i * TAU / dashes
		st.draw_arc(c, r, a0, a0 + TAU / dashes * 0.5, 4, col, 1.0)

# ================================================================ Storm Spire
const SP_IRON := Color(0.45, 0.5, 0.6)
const SP_STORM := Color(0.35, 0.45, 0.75)
const SP_BOLT := Color(0.95, 0.97, 1.0)
const SP_SPARK := Color(1.0, 0.95, 0.6)
const SP_COPPER := Color(0.85, 0.55, 0.3)

static func draw_storm_spire(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var flash: float = clampf(1.0 - st.fx_pulse / 0.3, 0.0, 1.0)
	# 6: a faint dashed range ring
	if t >= 6:
		dashed(st, Vector2.ZERO, float(st.data.range), Color(SP_BOLT, 0.18), 40, age * 0.1)
	# 5: cables to four rods in the ground that crackle
	if t >= 5:
		for i in 4:
			var d := Vector2(1.0 if i % 2 == 0 else -1.0, 0.55 if i < 2 else -0.45) * 1.0
			var p: Vector2 = d * st.radius * 1.5
			st.draw_line(Vector2(0, 2), p, SP_IRON.darkened(0.3), 1.0)
			st.draw_line(p, p + Vector2(0, -5), Color.BLACK, 2.0)
			st.draw_line(p, p + Vector2(0, -5), SP_IRON, 1.0)
			st.draw_circle(p + Vector2(0, -6), 1.6, SP_COPPER)
			if SpellArt.jit(int(age * 6.0) + i, 3.0) > 0.8 or flash > 0.0:
				zig(st, p + Vector2(0, -7), p + Vector2(d.x * 3.0, -13), 3, 2.0, age + i, Color(SP_BOLT, 0.9))
	# the body: a stone box and an iron spire
	StructureArt.box(st, Rect2(-7, -3, 14, 10), col.darkened(0.35))
	if t >= 4:
		for i in 4:
			st.draw_circle(Vector2(-5.5 + i * 3.7, 5.0), 1.1, Color(0.9, 0.9, 1.0))
	StructureArt.poly(st, PackedVector2Array([Vector2(-3.5, -3), Vector2(0, -20), Vector2(3.5, -3)]), SP_IRON)
	st.draw_line(Vector2(0.4, -4), Vector2(0.4, -18), SP_IRON.lightened(0.5), 1.0)
	if t >= 3:
		st.draw_arc(Vector2(0, -9), 5.0, PI * 1.1, PI * 1.9, 8, SP_COPPER, 1.5)
		st.draw_arc(Vector2(0, -13), 3.5, PI * 1.1, PI * 1.9, 8, SP_COPPER, 1.5)
		StructureArt.poly(st, PackedVector2Array([Vector2(3, -6), Vector2(8, -8), Vector2(3, -11)]), SP_COPPER)
	# static crawling up the spire
	for i in 3:
		if SpellArt.jit(int(age * 2.0) + i, 1.0) > 0.35:
			var u := fposmod(age * 0.9 + SpellArt.jit(i), 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var a := Vector2(side * 3.0 * (1.0 - u), -3.0 - u * 15.0)
			zig(st, a, a + Vector2(side * 4.0, -3.0), 3, 1.5, age * 7.0 + i, Color(SP_SPARK, 0.9))
	# the ball: it pulses faster the more enemies carry a charge
	var charge: float = st.charge
	var pulse := 0.5 + 0.5 * sin(age * (4.0 + 12.0 * charge))
	var ball := Vector2(0, -21)
	var hot := t >= 6
	st.draw_circle(ball, 4.5 + 2.0 * pulse * (0.3 + charge) + (3.0 if flash > 0.0 else 0.0), Color(SP_BOLT, 0.25))
	st.draw_circle(ball, 3.0 + (1.0 if t >= 4 else 0.0) + (1.0 if hot else 0.0), Color(0.75, 0.88, 1.0).lerp(Color.WHITE, 0.35 * pulse + (0.5 if hot else 0.0)))
	# 6: electric arcs flicker round a white-hot orb
	if hot:
		for i in 6:
			if SpellArt.jit(int(age * 12.0) + i * 3, 5.0) > 0.4:
				var a := i * TAU / 6.0 + age
				zig(st, ball + Vector2.from_angle(a) * 4.0, ball + Vector2.from_angle(a) * 10.0, 3, 2.0, age * 9.0 + i, Color(SP_BOLT, 0.95))
	# the charged enemies wear a spark above them
	for p in st.vis.get("charged", []):
		var q: Vector2 = p - st.global_position + Vector2(0, -12)
		glint(st, q, 3.0 + sin(age * 14.0), Color(SP_SPARK, 0.95))
	# 4: a storm cloud over the spire (6: it becomes a swirling ring); 5: it flickers white at each skybolt
	if t >= 4:
		var cc := Color(0.2, 0.24, 0.4, 0.35).lerp(Color(1, 1, 1, 0.5), flash)
		if t >= 6:
			for i in 8:
				var a := age * 0.8 + i * TAU / 8.0
				st.draw_circle(Vector2(0, -30) + Vector2(cos(a) * 22.0, sin(a) * 7.0), 5.0, Color(cc, 0.3))
		else:
			var big := 1.25 if t >= 5 else 1.0
			for i in 3:
				st.draw_circle(Vector2(sin(age * 0.5 + i * 2.1) * 6.0 + (i - 1) * 6.0, -42.0 + (i % 2) * 3.0), (8.0 + i * 2.0) * big, cc)
	# 6: rain
	if t >= 6:
		for i in 14:
			var u := fposmod(age * 1.6 + SpellArt.jit(i), 1.0)
			var x := (SpellArt.jit(i, 2.0) - 0.5) * 70.0
			var y := -30.0 + u * 44.0
			st.draw_line(Vector2(x, y), Vector2(x - 1.0, y + 4.0), Color(0.7, 0.85, 1.0, 0.6 * (1.0 - u * 0.5)), 1.0)

# ================================================================ Magma Wall
const MW_CRUST := Color(0.25, 0.12, 0.1)
const MW_LAVA := Color(1.0, 0.55, 0.15)
const MW_HOT := Color(1.0, 0.95, 0.7)
const MW_ASH := Color(0.4, 0.35, 0.35)

## A zig-zag crack across the face, from (x, y0) down to (x2, y1).
static func crack(st, x: float, y0: float, y1: float, seed: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var n := 5
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(x + (SpellArt.jit(i, seed) - 0.5) * 7.0, lerpf(y0, y1, u)))
	st.draw_polyline(pts, col, width)

static func draw_magma_wall(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var r: float = st.radius
	var f: float = clampf(st.hp / st.max_hp, 0.0, 1.0)
	var rage: bool = t >= 6 and f < 0.3
	var glow := 0.55 + 0.25 * sin(age * 2.5)
	if f < 0.66:
		glow += 0.2
	if rage:
		glow = 1.0
	var top := -r * 0.8
	var bot := r * 0.8
	# 4: a halo behind the wall and a shimmer above it; 6: a glow on the floor
	if t >= 4:
		st.draw_circle(Vector2.ZERO, r * 1.8, Color(MW_LAVA, 0.12))
		for k in 2:
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(Vector2(-r + i * r * 0.25, top - 5.0 - k * 4.0 + sin(age * 4.0 + i * 0.9 + k * 2.0) * 1.5))
			st.draw_polyline(pts, Color(1.0, 0.8, 0.5, 0.25), 1.0)
	if t >= 6:
		st.draw_circle(Vector2(0, bot + 2.0), r * 1.3, Color(MW_LAVA, 0.14 + 0.08 * glow))
		if rage:
			st.draw_circle(Vector2.ZERO, r * 1.5, Color(MW_HOT, 0.18 + 0.1 * sin(age * 8.0)))
	# 6: a crater rim of black rocks
	if t >= 6:
		for i in 5:
			var x := -r + 2.0 + i * (r * 2.0 - 4.0) / 4.0
			StructureArt.poly(st, PackedVector2Array([Vector2(x - 4, bot + 3), Vector2(x - 2, bot - 1.5 - (i % 2) * 2.0), Vector2(x + 3, bot - 1), Vector2(x + 4, bot + 3)]), MW_CRUST.lightened(0.15))
	# the body: crust with a thicker rim
	StructureArt.box(st, Rect2(-r, top, r * 2.0, bot - top), MW_CRUST)
	if t >= 3:
		st.draw_rect(Rect2(-r + 1, top + 1, 3, bot - top - 2), MW_CRUST.lightened(0.12))
		st.draw_rect(Rect2(r - 4, top + 1, 3, bot - top - 2), MW_CRUST.lightened(0.12))
	# 5: the lower half is molten when it is hurt
	if t >= 5 and f < 0.66:
		for i in 6:
			var u := float(i) / 5.0
			st.draw_rect(Rect2(-r + 1, bot - (bot - top) * 0.4 + u * (bot - top) * 0.4 - 1.0, r * 2.0 - 2, (bot - top) * 0.4 / 6.0 + 0.5), Color(MW_LAVA.lerp(MW_HOT, u), (0.25 + 0.5 * u) * (1.0 - f)))
	# 6: a white-hot core shines through
	if t >= 6:
		st.draw_rect(Rect2(-r * 0.45, top + 4.0, r * 0.9, bot - top - 8.0), Color(MW_HOT, (0.25 + 0.2 * sin(age * 3.0)) * (2.5 if rage else 1.0)))
	# the cracks
	var cw := 2.2 if t >= 4 else 1.5
	for i in 4:
		crack(st, -r * 0.65 + i * r * 0.43, top + 2.0, bot - 2.0, float(i) * 3.0 + 1.0, Color(MW_HOT if rage else MW_LAVA, clampf(glow, 0.0, 1.0)), cw)
	# 3: two lava channels run down to a dripping spout
	if t >= 3:
		for x in [-r * 0.32, r * 0.32]:
			st.draw_polyline(PackedVector2Array([Vector2(x, top + 2.0), Vector2(x, bot - 5.0), Vector2(x * 0.2, bot - 1.0)]), Color(MW_LAVA, 0.85), 1.5)
		st.draw_colored_polygon(PackedVector2Array([Vector2(-3, bot - 1), Vector2(3, bot - 1), Vector2(1.5, bot + 3), Vector2(-1.5, bot + 3)]), MW_LAVA)
		for i in 2:
			var u := fposmod(age * 1.2 + i * 0.5, 1.0)
			if u < 0.75:
				st.draw_circle(Vector2(0, bot + 3.0 + u * 10.0), 1.3, MW_LAVA)
			else:
				st.draw_circle(Vector2(0, bot + 13.0), 1.0 + (u - 0.75) * 8.0, Color(MW_LAVA, 1.0 - (u - 0.75) * 3.5))
	# the spikes: black obsidian with orange tips
	for i in 5:
		var x := -r + 3.0 + i * (r * 2.0 - 6.0) / 4.0
		st.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.2, top), Vector2(x, top - 6.0), Vector2(x + 2.2, top)]), Color(0.08, 0.06, 0.08))
		st.draw_colored_polygon(PackedVector2Array([Vector2(x - 0.9, top - 3.6), Vector2(x, top - 6.0), Vector2(x + 0.9, top - 3.6)]), MW_LAVA)
	# 5: two vents spout flames; 6: five flame tongues crown the wall
	if t >= 6:
		for i in 5:
			var x := -r + 4.0 + i * (r * 2.0 - 8.0) / 4.0
			SpellArt.flame(st, Vector2(x, top - 4.0), 5.0, 9.0 + 3.0 * sin(age * 7.0 + i * 1.3), Color(MW_LAVA, 0.85), sin(age * 5.0 + i) * 1.5)
			SpellArt.flame(st, Vector2(x, top - 4.0), 2.5, 5.0 + 2.0 * sin(age * 9.0 + i), Color(MW_HOT, 0.9), sin(age * 5.0 + i) * 1.0)
	elif t >= 5:
		for x in [-r * 0.5, r * 0.5]:
			st.draw_rect(Rect2(x - 2.5, top - 1.0, 5.0, 3.0), Color.BLACK)
			SpellArt.flame(st, Vector2(x, top - 1.0), 4.0, 8.0 + 3.0 * sin(age * 8.0 + x), Color(MW_LAVA, 0.9), sin(age * 6.0 + x))
			SpellArt.flame(st, Vector2(x, top - 1.0), 2.0, 4.0 + 2.0 * sin(age * 8.0 + x), Color(MW_HOT, 0.95), 0.0)
	# embers rise off it
	for i in 4:
		var u := fposmod(age * 0.7 + SpellArt.jit(i), 1.0)
		st.draw_circle(Vector2((SpellArt.jit(i, 4.0) - 0.5) * r * 1.6 + sin(age * 3.0 + i) * 2.0, top - u * 22.0), 1.1, Color(MW_LAVA, 1.0 - u))
	# 5: a thin lava drip trail on the ground
	if t >= 5:
		for i in 4:
			st.draw_circle(Vector2(-6.0 + i * 5.0, bot + 8.0 + (i % 2) * 3.0), 0.9, Color(MW_LAVA, 0.5))
	if st.flash > 0.0:
		st.draw_rect(Rect2(-r, top, r * 2.0, bot - top), Color(1, 1, 1, 0.4))
	StructureArt.hp_bar(st, bot + 15.0 if t >= 3 else bot + 3.0, r, t >= 6)

# ================================================================ Venom Tower
const VN_VENOM := Color(0.55, 0.9, 0.25)
const VN_DEEP := Color(0.2, 0.45, 0.15)
const VN_SPORE := Color(0.8, 1.0, 0.5)
const VN_ROT := Color(0.55, 0.3, 0.6)
const VN_BONE := Color(0.9, 0.88, 0.75)

static func draw_venom_tower(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var aim: Vector2 = st.aim if st.aim != Vector2.ZERO else Vector2.UP
	# 6: a mist over the ground
	if t >= 6:
		st.draw_circle(Vector2(0, 2), 26.0, Color(VN_SPORE, 0.1))
	# 4: acid drips on the ground round the base
	if t >= 4:
		for i in 4:
			var a := i * TAU / 4.0 + 0.6
			st.draw_circle(Vector2(cos(a) * 11.0, 5.0 + sin(a) * 4.0), 2.2 + (i % 2), Color(VN_VENOM, 0.3))
	# 3: mushroom pods sprout round the base
	if t >= 3:
		for i in 3:
			var x := -11.0 + i * 11.0
			var y := 5.0 + (i % 2) * 2.0
			st.draw_line(Vector2(x, y + 2), Vector2(x, y - 2), VN_BONE, 1.5)
			st.draw_circle(Vector2(x, y - 3), 3.0, Color.BLACK)
			st.draw_circle(Vector2(x, y - 3), 2.2, VN_ROT.lerp(VN_VENOM, 0.3 * i))
			st.draw_circle(Vector2(x - 0.8, y - 3.5), 0.6, VN_BONE)
	StructureArt.box(st, Rect2(-7, -3, 14, 10), col.darkened(0.45))
	# the tank: bigger from tier 3, swollen and rotten at tier 6
	var tank_r := 5.0 if t < 3 else (6.0 if t < 6 else 8.0)
	var lean := 2.0 if t >= 6 else 0.0
	var tc := Vector2(lean, -8.0 - tank_r * 0.5)
	var sick := 0.5 + 0.5 * sin(age * 2.5)
	var glow := VN_VENOM
	if t >= 5:
		glow = VN_VENOM.lerp(VN_ROT, 0.45 + 0.25 * sick)
	if t >= 6:
		glow = VN_ROT.lerp(VN_VENOM, 0.25 * sick)
		tank_r += 0.8 * sick
	st.draw_circle(tc, tank_r + 1.0, Color.BLACK)
	st.draw_circle(tc, tank_r, VN_DEEP)
	st.draw_circle(tc + Vector2(0, tank_r * 0.25), tank_r * 0.8, glow)
	st.draw_circle(tc + Vector2(-tank_r * 0.35, -tank_r * 0.3), tank_r * 0.22, Color(1, 1, 1, 0.45))
	if t >= 3:
		st.draw_arc(tc, tank_r * 0.6, age * 2.0, age * 2.0 + 2.2, 8, Color(VN_ROT, 0.8), 1.0)
	# bubbles in the tank
	for i in 2:
		var u := fposmod(age * 0.8 + i * 0.5, 1.0)
		st.draw_circle(tc + Vector2((i - 0.5) * tank_r * 0.8, tank_r * 0.5 - u * tank_r), 0.9, Color(VN_SPORE, 0.8 * (1.0 - u)))
	# the fang-shaped nozzle (two of them from tier 4) and the hose from the tank
	var nz := tc + aim * (tank_r + 1.5)
	var side := aim.orthogonal()
	var offs := [-2.2, 2.2] if t >= 4 else [0.0]
	for o in offs:
		var b: Vector2 = nz + side * o
		StructureArt.poly(st, PackedVector2Array([b + side * 1.8, b - side * 1.8, b + aim * 6.0]), VN_BONE)
		st.draw_line(tc + side * o * 0.4, b, VN_DEEP.lightened(0.15), 1.5)
	if t >= 4:
		for k in 3:
			var q: Vector2 = tc.lerp(nz, 0.3 + 0.2 * k)
			st.draw_line(q + side * 2.2, q - side * 2.2, VN_DEEP.darkened(0.3), 1.0)
		var u2 := fposmod(age * 1.5, 1.0)
		st.draw_circle(nz + aim * (6.0 + u2 * 6.0), 1.0 + 0.5 * (1.0 - u2), Color(VN_VENOM, 1.0 - u2))
	# 5: a ring of bone fangs round the top
	if t >= 5:
		for i in 7:
			var a := PI + 0.35 + i * (PI - 0.7) / 6.0
			var d := Vector2.from_angle(a)
			st.draw_colored_polygon(PackedVector2Array([tc + d * (tank_r + 0.5) + d.orthogonal() * 1.3, tc + d * (tank_r + 0.5) - d.orthogonal() * 1.3, tc + d * (tank_r + 4.0)]), VN_BONE)
	# 6: cracks leaking spores, hanging pods, a halo of twelve spores
	if t >= 6:
		st.draw_line(tc + Vector2(-2, -tank_r * 0.8), tc + Vector2(1, 0), Color.BLACK, 1.0)
		st.draw_line(tc + Vector2(2, tank_r * 0.2), tc + Vector2(4, tank_r * 0.8), Color.BLACK, 1.0)
		for i in 3:
			var x := -5.0 + i * 5.0
			st.draw_line(Vector2(x, 7), Vector2(x, 11 + (i % 2) * 2), VN_BONE, 1.0)
			st.draw_circle(Vector2(x, 12.5 + (i % 2) * 2), 2.2, VN_ROT)
		for i in 12:
			var a := age * 0.7 + i * TAU / 12.0
			st.draw_circle(Vector2(cos(a) * 22.0, sin(a) * 9.0 - 6.0), 1.2, Color(VN_SPORE, 0.7))
	# spore dots float up (from tier 3)
	if t >= 3:
		for i in 4:
			var u := fposmod(age * 0.5 + SpellArt.jit(i), 1.0)
			st.draw_circle(Vector2(sin(age + i * 2.0) * 9.0, 0.0 - u * 26.0), 0.9, Color(VN_SPORE, 0.7 * (1.0 - u)))
	shot_line(st, nz + aim * 6.0, VN_VENOM)
	# the stacks: green pips over every poisoned enemy; 5: threads between the ones with two or more
	var marks: Array = st.vis.get("stack_pos", [])
	for m in marks:
		var q: Vector2 = m[0] - st.global_position
		for k in int(m[1]):
			st.draw_circle(q + Vector2((k - (int(m[1]) - 1) * 0.5) * 3.5, -13.0), 1.4, VN_VENOM)
		if t >= 5 and int(m[1]) >= 2:
			for m2 in marks:
				var q2: Vector2 = m2[0] - st.global_position
				if q2 != q and q.distance_to(q2) <= 45.0:
					st.draw_line(q, q2, Color(VN_VENOM, 0.3), 1.0)

# ================================================================ Prism Tower
const PR_RED := Color(1.0, 0.35, 0.3)
const PR_BLUE := Color(0.4, 0.6, 1.0)
const PR_YELLOW := Color(1.0, 0.9, 0.4)
const PR_GLASS := Color(0.86, 0.92, 1.0)

static func pr_colour(i: int) -> Color:
	return [PR_RED, PR_BLUE, PR_YELLOW][i % 3]

## A glass triangular prism: translucent, white edges, black outline.
static func glass(st, c: Vector2, w: float, h: float, tint: Color, glow: Color, glow_a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-w * 0.5, h * 0.5), c + Vector2(w * 0.5, h * 0.5), c + Vector2(0, -h * 0.5)])
	st.draw_colored_polygon(pts, Color(tint.lerp(Color(0.8, 0.88, 1.0), 0.5), 0.88))
	st.draw_circle(c + Vector2(0, h * 0.1), w * 0.22, Color(glow, glow_a))
	st.draw_line(pts[0], pts[2], Color(1, 1, 1, 0.9), 1.0)
	st.draw_line(pts[1], pts[2], Color(0.8, 0.85, 0.95, 0.9), 1.0)
	st.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.9), 1.0)
	var closed := pts.duplicate()
	closed.append(pts[0])
	st.draw_polyline(closed, Color(0, 0, 0, 0.8), 1.0)

static func draw_prism_tower(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var aim: Vector2 = st.aim if st.aim != Vector2.ZERO else Vector2.UP
	var next_i := int(round(st.charge * 3.0)) % 3                      # the colour the next shot will have
	var cur_i := (next_i + 2) % 3                                       # the one just fired
	var c := Vector2(0, -12)
	# 6: floor caustics and a beam of white light straight up
	if t >= 6:
		for i in 6:
			var a := age * 0.6 + i * TAU / 6.0
			st.draw_circle(Vector2(cos(a) * 16.0, 6.0 + sin(a * 1.3) * 5.0), 2.2, Color(Color.from_hsv(i / 6.0, 0.6, 1.0), 0.35))
		st.draw_colored_polygon(PackedVector2Array([Vector2(-3, c.y), Vector2(3, c.y), Vector2(6, c.y - 55), Vector2(-6, c.y - 55)]), Color(1, 1, 1, 0.16 + 0.05 * sin(age * 3.0)))
	# 4: the base has a lit rainbow ring
	if t >= 4:
		for i in 6:
			var a0 := i * TAU / 6.0 + age * 0.3
			st.draw_arc(Vector2(0, 3), 11.0, a0, a0 + TAU / 6.0 - 0.15, 5, Color(Color.from_hsv(i / 6.0, 0.7, 1.0), 0.8), 1.5)
	StructureArt.box(st, Rect2(-7, -3, 14, 10), col.darkened(0.4))
	# 4: six small crystals in a hexagon round the prism
	if t >= 4:
		for i in 6:
			var a := i * TAU / 6.0 + age * 0.4
			var p := c + Vector2(cos(a) * 11.0, sin(a) * 4.0 - 1.0)
			var hc := Color.from_hsv(fposmod(age * 0.25 + i / 6.0, 1.0), 0.7, 1.0)
			StructureArt.poly(st, PackedVector2Array([p + Vector2(0, -2.6), p + Vector2(1.6, 0), p + Vector2(0, 2.6), p + Vector2(-1.6, 0)]), hc)
	# 6: a rotating rainbow halo
	if t >= 6:
		for i in 6:
			var a0 := -age * 1.2 + i * TAU / 6.0
			st.draw_arc(c, 14.0, a0, a0 + TAU / 6.0 - 0.12, 5, Color(Color.from_hsv(i / 6.0, 0.7, 1.0), 0.85), 1.5)
	# the glass: one prism, three stacked at tier 6
	var glow: Color = pr_colour(next_i)
	if t >= 6:
		glass(st, Vector2(0, -7), 13.0, 8.0, PR_GLASS, glow, 0.9)
		glass(st, Vector2(0, -14), 10.0, 8.0, PR_GLASS, glow, 0.9)
		glass(st, Vector2(0, -20), 7.0, 7.0, PR_GLASS, glow, 0.9)
		var core := float(st.vis.get("lance", 0.0))
		st.draw_arc(Vector2(0, -14), 6.0, -PI / 2.0, -PI / 2.0 + TAU * core, 18, Color(1, 1, 1, 0.9), 1.5)
	else:
		glass(st, c, 12.0, 12.0, PR_GLASS, glow, 0.9 if t < 4 else 1.0)
		if t >= 4:
			st.draw_circle(c, 9.0, Color(glow, 0.15 + 0.1 * sin(age * 4.0)))
	# 5: mirror shards drift round the prism and bend a faint copy of the beam
	if t >= 5:
		for i in 3:
			var a := age * 0.9 + i * TAU / 3.0
			var p := c + Vector2(cos(a) * 15.0, sin(a) * 6.0 - 2.0)
			StructureArt.poly(st, PackedVector2Array([p + Vector2(-2.5, 2), p + Vector2(0, -3), p + Vector2(2.5, 1.5)]), Color(0.8, 0.85, 0.9))
			if st.shot_t > 0.0 and i == 0:
				var to: Vector2 = st.shot_to - st.global_position
				st.draw_polyline(PackedVector2Array([c, p, to]), Color(pr_colour(cur_i), 0.3), 1.0)
		for k in 3:
			st.draw_line(c + Vector2(-5 + k * 5, 4), c + Vector2(-5 + k * 5, -5), Color(Color.from_hsv(fposmod(age * 0.2 + k * 0.3, 1.0), 0.5, 1.0), 0.7), 1.0)
	# 3: a lens ring in front of the prism turns to the target, with a dotted guide line
	if t >= 3:
		var lc := c + aim * 8.0
		st.draw_arc(lc, 5.0, 0, TAU, 14, Color(PR_GLASS, 0.9), 1.5)
		st.draw_circle(lc, 4.0, Color(PR_GLASS, 0.15))
		var ga := aim.angle() + age * 3.0
		st.draw_circle(lc + Vector2.from_angle(ga) * 2.6, 0.9, Color.WHITE)
		for i in 6:
			st.draw_circle(c + aim * (15.0 + i * 5.0), 0.6, Color(1, 1, 1, 0.4 - i * 0.05))
		if bool(st.vis.get("focus", false)) and st.shot_t > 0.0:
			st.draw_circle(lc, 7.0, Color(1, 1, 1, 0.4))
	# the shot, in the colour it had
	var shot_col: Color = pr_colour(cur_i)
	if st.shot_t > 0.0 and !bool(st.vis.get("focus", false)):
		shot_line(st, c, shot_col, 2.0)
