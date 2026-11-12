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
		"healing_grove":
			draw_healing_grove(st, col)
			return true
		"sunspire":
			draw_sunspire(st, col)
			return true
		"phoenix_shrine":
			draw_phoenix_shrine(st, col)
			return true
		"healing_lantern":
			draw_healing_lantern(st, col)
			return true
		"beacon_turret":
			draw_beacon_turret(st, col)
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

# ================================================================ Healing Grove
const GR_BARK := Color(0.45, 0.3, 0.18)
const GR_LEAF := Color(0.3, 0.75, 0.35)
const GR_BLOSSOM := Color(1.0, 0.75, 0.85)
const GR_FRUIT := Color(1.0, 0.55, 0.2)
const GR_GOLD := Color(1.0, 0.9, 0.5)

static func flower(st, p: Vector2, r: float, col: Color) -> void:
	for k in 5:
		st.draw_circle(p + Vector2.from_angle(k * TAU / 5.0 + 0.3) * r * 0.9, r * 0.6, col)
	st.draw_circle(p, r * 0.5, Color(1.0, 0.9, 0.4))

static func draw_healing_grove(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var r: float = st.radius
	var pulse := 0.5 + 0.5 * sin(age * 3.0)
	var bloom := clampf(1.0 - st.fx_pulse, 0.0, 1.0)                  # a blossom pulse has just gone out
	# the field (as the plain healer draws it), softer under the new art; 5: a pink-green aura
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.06 + 0.04 * pulse))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(col, 0.35), 1.0)
	if t >= 5:
		st.draw_circle(Vector2.ZERO, r * 0.75, Color(GR_BLOSSOM.lerp(GR_LEAF, 0.5), 0.07))
		# a ring of eight small flowers on the edge, opening at each pulse
		for i in 8:
			var a := i * TAU / 8.0 + 0.2
			flower(st, Vector2.from_angle(a) * (r - 2.0), 1.6 + 2.2 * bloom, GR_BLOSSOM.lerp(Color.WHITE, 0.3 * bloom))
	if t >= 6:
		st.draw_circle(Vector2.ZERO, r * 0.9, Color(GR_GOLD, 0.06 + 0.03 * pulse))
	# 2: flowers scattered in the field
	for i in 6:
		var a := SpellArt.jit(i, 7.0) * TAU
		var d := (0.25 + 0.65 * SpellArt.jit(i, 8.0)) * r
		var fc: Color = [Color(1, 0.5, 0.5), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0)][i % 3]
		flower(st, Vector2.from_angle(a) * d, 1.5, fc)
	# 4: roots break the ground, fanning from the trunk
	if t >= 4:
		for i in 6:
			var tip: Vector2 = Vector2.from_angle(i * TAU / 6.0 + 0.4) * r * 0.85
			var mid: Vector2 = tip * 0.5 + tip.orthogonal().normalized() * 4.0 * (1.0 if i % 2 == 0 else -1.0)
			st.draw_polyline(PackedVector2Array([Vector2(0, 7), mid, tip]), Color(GR_BARK.darkened(0.2), 0.85), 2.4 if i % 2 == 0 else 1.6)
			if i % 2 == 0:
				st.draw_circle(mid, 1.6, GR_BARK.darkened(0.1))
		for i in 4:
			st.draw_circle(Vector2.from_angle(i * TAU / 4.0 + 1.0) * r * 0.4 + Vector2(0, 4), 1.6, GR_BARK)
	# 3: fruit lying in the field
	for f in st.vis.get("fruit_pos", []):
		st.draw_circle(f, 3.5, Color.BLACK)
		st.draw_circle(f, 2.7, GR_FRUIT)
		st.draw_colored_polygon(PackedVector2Array([f + Vector2(0, -2.5), f + Vector2(3.5, -4), f + Vector2(1.5, -1)]), GR_LEAF)
	# the tree
	var big := t >= 6
	var trunk_w := 8.0 if big else 3.0
	var trunk_h := 24.0 if big else 10.0
	var ty := 7.0
	if big:
		for k in [-1.0, 1.0]:
			st.draw_colored_polygon(PackedVector2Array([Vector2(k * 3.0, ty - 5.0), Vector2(k * 12.0, ty + 3.0), Vector2(k * 6.0, ty + 3.0), Vector2(k * 1.0, ty - 2.0)]), GR_BARK.darkened(0.15))
	st.draw_rect(Rect2(-trunk_w * 0.5 - 1.0, ty - trunk_h - 1.0, trunk_w + 2.0, trunk_h + 2.0), Color.BLACK)
	st.draw_rect(Rect2(-trunk_w * 0.5, ty - trunk_h, trunk_w, trunk_h), GR_BARK)
	st.draw_rect(Rect2(trunk_w * 0.1, ty - trunk_h, trunk_w * 0.35, trunk_h), GR_BARK.darkened(0.2))
	var cy := ty - trunk_h - (6.0 if big else 2.0)
	# 6: shafts of light from the crown to the ground
	if big:
		for k in 3:
			var x := -14.0 + k * 14.0
			st.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, cy), Vector2(x + 3, cy), Vector2(x + 10 + k * 3.0 - 6.0, ty + 4.0), Vector2(x - 8 + k * 3.0, ty + 4.0)]), Color(GR_GOLD, 0.1 + 0.05 * sin(age * 1.5 + k)))
	# 4: a knot with a face, its eyes lit while enemies are in the field
	if t >= 4 and !big:
		var eyes := bool(st.vis.get("roots", false))
		st.draw_circle(Vector2(0, ty - 5.0), 1.6, GR_BARK.darkened(0.45))
		if eyes:
			st.draw_circle(Vector2(-0.9, ty - 5.5), 0.5, Color(0.5, 1.0, 0.4))
			st.draw_circle(Vector2(0.9, ty - 5.5), 0.5, Color(0.5, 1.0, 0.4))
	elif t >= 4 and big:
		st.draw_circle(Vector2(0, ty - 12.0), 2.6, GR_BARK.darkened(0.45))
		if bool(st.vis.get("roots", false)):
			st.draw_circle(Vector2(-1.4, ty - 12.6), 0.8, Color(0.5, 1.0, 0.4))
			st.draw_circle(Vector2(1.4, ty - 12.6), 0.8, Color(0.5, 1.0, 0.4))
	# the crown: 3 circles, 5 from tier 3, nine in three greens at tier 6
	var greens := [GR_LEAF.darkened(0.25), GR_LEAF, GR_LEAF.lightened(0.25)]
	if big:
		for i in 9:
			var a := i * TAU / 9.0
			var cp := Vector2(cos(a) * 9.0, cy + sin(a) * 5.0 - (3.0 if i % 2 == 0 else 0.0))
			var cr := 8.0 + 4.0 * SpellArt.jit(i, 3.0)
			st.draw_circle(cp, cr + 1.0, Color.BLACK)
			st.draw_circle(cp, cr, greens[i % 3])
		st.draw_circle(Vector2(0, cy - 2.0), 9.0, greens[1])
		for i in 6:
			var a := age * 0.4 + i * TAU / 6.0
			st.draw_circle(Vector2(cos(a) * 14.0, cy - 2.0 + sin(a) * 8.0), 1.6 + 0.6 * sin(age * 4.0 + i), GR_GOLD)
	else:
		var spots := [Vector2(0, cy - 2.0), Vector2(-5, cy + 2.0), Vector2(5, cy + 2.0)]
		var sizes := [5.0, 4.0, 4.0]
		if t >= 3:
			spots += [Vector2(-3, cy - 6.0), Vector2(3, cy - 6.0)]
			sizes += [3.6, 3.6]
		for i in spots.size():
			st.draw_circle(spots[i], sizes[i] + 1.0, Color.BLACK)
		for i in spots.size():
			st.draw_circle(spots[i], sizes[i], greens[i % 3])
		if t >= 3:
			for i in 4:
				var q: Vector2 = spots[i] + Vector2(1.5 * (1.0 if i % 2 == 0 else -1.0), 1.5)
				st.draw_circle(q, 1.1, GR_FRUIT)
		if t >= 5:
			for i in 12:
				st.draw_circle(Vector2(cos(i * 2.4) * (3.0 + (i % 4)), cy - 3.0 + sin(i * 1.7) * 5.0), 1.1, GR_BLOSSOM)
	# falling petals (5) and drifting leaves
	if t >= 5:
		for i in 10:
			var u := fposmod(age * 0.35 + SpellArt.jit(i), 1.0)
			st.draw_circle(Vector2((SpellArt.jit(i, 2.0) - 0.5) * r * 1.1 + sin(age * 2.0 + i) * 3.0, cy + u * (ty - cy + 6.0)), 0.9, Color(GR_BLOSSOM, 1.0 - u * 0.6))
	for i in 3:
		var u := fposmod(age * 0.3 + i * 0.33, 1.0)
		st.draw_circle(Vector2(sin(age + i * 2.0) * 8.0, cy - u * 20.0), 0.9, Color(GR_LEAF.lightened(0.3), 0.8 * (1.0 - u)))
	# 6: spirit lights rise
	if big:
		for i in 6:
			var u := fposmod(age * 0.25 + i / 6.0, 1.0)
			var x := Vector2.from_angle(i * 1.1 + age * 0.2).x * 20.0
			st.draw_circle(Vector2(x, ty - u * 50.0), 1.8, Color(GR_GOLD, 0.8 * (1.0 - u)))
			st.draw_circle(Vector2(x, ty - u * 50.0), 3.2, Color(GR_GOLD, 0.2 * (1.0 - u)))

# ================================================================ Sunspire
const SU_SUN := Color(1.0, 0.92, 0.5)
const SU_GOLD := Color(1.0, 0.8, 0.3)
const SU_WHITE := Color(1.0, 0.99, 0.9)
const SU_AMBER := Color(1.0, 0.6, 0.2)
const SU_STONE := Color(0.85, 0.8, 0.7)

## A sun disc with `n` rays of length `len` turning at `spin`.
static func sun_disc(st, c: Vector2, r: float, n: int, len: float, spin: float, col: Color) -> void:
	for i in n:
		var d := Vector2.from_angle(spin + i * TAU / n)
		st.draw_line(c + d * (r + 1.0), c + d * (r + len), Color(col, 0.9), 1.5 if len < 10.0 else 1.2)
	st.draw_circle(c, r + 1.0, Color.BLACK)
	st.draw_circle(c, r, col)
	st.draw_circle(c, r * 0.6, SU_WHITE)

## A flat ellipse (a step), drawn with a squashed transform.
static func flat_ellipse(st, c: Vector2, rx: float, ry: float, col: Color) -> void:
	st.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	st.draw_circle(Vector2.ZERO, rx, col)
	st.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_sunspire(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var noon: bool = bool(st.vis.get("noon", false))
	var lance: float = float(st.vis.get("lance", 0.0))
	var breathe := 0.5 + 0.5 * sin(age * 1.6)
	var stone := SU_STONE.lerp(SU_GOLD, 0.45) if t >= 6 else SU_STONE
	var disc_y := -34.0 if t >= 6 else -19.0
	# 4: glowing golden steps at the base
	if t >= 4:
		for i in 3:
			flat_ellipse(st, Vector2(0, 6.0 - i * 1.5), 14.0 - i * 2.0, 4.0, Color(SU_GOLD, 0.35 + 0.1 * breathe))
	# 6: the halo breathes, a column of light falls to the ground
	if t >= 6:
		st.draw_circle(Vector2(0, disc_y), 26.0 + 4.0 * breathe, Color(SU_SUN, 0.1))
		st.draw_colored_polygon(PackedVector2Array([Vector2(-5, disc_y), Vector2(5, disc_y), Vector2(9, 4), Vector2(-9, 4)]), Color(SU_WHITE, 0.14 + 0.06 * breathe))
		for i in 6:
			var u := fposmod(age * 0.7 + i / 6.0, 1.0)
			st.draw_circle(Vector2(sin(age * 2.0 + i * 2.0) * 3.0, disc_y + u * (4.0 - disc_y)), 0.9, Color(SU_GOLD, 1.0 - u))
	# the stone column: a tapered pillar with a gold band
	StructureArt.box(st, Rect2(-7, -3, 14, 10), stone.darkened(0.35))
	StructureArt.poly(st, PackedVector2Array([Vector2(-4.5, -2), Vector2(-3, -16 if t < 6 else -14), Vector2(3, -16 if t < 6 else -14), Vector2(4.5, -2)]), stone)
	st.draw_rect(Rect2(-4, -8, 8, 2), SU_GOLD)
	if t >= 3:
		# gold filigree on the base
		st.draw_arc(Vector2(-3, 3), 2.0, PI, TAU * 0.9, 8, SU_GOLD, 1.0)
		st.draw_arc(Vector2(3, 3), 2.0, PI * 0.1, PI * 1.9, 8, SU_GOLD, 1.0)
		st.draw_line(Vector2(-6, 5), Vector2(6, 5), SU_GOLD, 1.0)
	if t >= 6:
		# the stone is gold-plated; a slim pillar carries the sun
		st.draw_line(Vector2(0, -14), Vector2(0, disc_y + 10.0), Color.BLACK, 3.0)
		st.draw_line(Vector2(0, -14), Vector2(0, disc_y + 10.0), SU_GOLD, 1.5)
	var c := Vector2(0, disc_y)
	# 4: a wide corona round the disc, longer rays turning the other way
	if t >= 4:
		var cr := (14.0 if t >= 6 else 9.0) + breathe
		st.draw_circle(c, cr, Color(SU_SUN, 0.25))
		for i in 12:
			var d := Vector2.from_angle(-age * 0.5 + i * TAU / 12.0)
			st.draw_line(c + d * (cr * 0.8), c + d * (cr * 0.8 + 14.0), Color(SU_GOLD, 0.55), 1.0)
	# 3: a lens ring round the disc, a focusing crystal, a charge ball at the tip
	if t >= 3 and t < 6:
		st.draw_arc(c, 7.5, PI * 0.15, PI * 1.85, 14, Color(SU_WHITE, 0.9), 1.5)
		st.draw_circle(c + Vector2(0, -9.0 - 3.0), 1.0 + 3.0 * lance, Color(SU_WHITE, 0.5 + 0.5 * lance))
	if t >= 6:
		sun_disc(st, c, 12.0, 16, 18.0, age * 0.4, SU_SUN)
		st.draw_arc(c, 17.0, 0, TAU, 28, Color(SU_WHITE, 0.4), 1.0)
		st.draw_circle(c + Vector2(0, -20.0), 1.0 + 3.0 * float(st.charge), Color(SU_WHITE, 0.4 + 0.5 * float(st.charge)))
		if noon:
			st.draw_circle(c, 20.0, Color(SU_WHITE, 0.25 + 0.15 * sin(age * 10.0)))
	else:
		sun_disc(st, c, 5.0, 8, 4.0, age * 0.5, SU_SUN)
	# the lens-flare star flickers at the disc
	if SpellArt.jit(int(age * 8.0), 2.0) > 0.4:
		glint(st, c + Vector2(1, -1), 7.0 if t < 6 else 12.0, Color(SU_WHITE, 0.8))
	# 5: four mirror dishes circle the spire, tilted at the target, with light bouncing to each
	if t >= 5:
		var aim: Vector2 = st.aim if st.aim != Vector2.ZERO else Vector2.UP
		for i in 4:
			var mp: Vector2 = TC.orb_pos(st, i) - st.global_position
			st.draw_line(c, mp, Color(SU_GOLD, 0.3), 1.0)
			var ang := aim.angle()
			st.draw_arc(mp, 3.6, ang - PI * 0.6, ang + PI * 0.6, 8, Color.BLACK, 3.0)
			st.draw_arc(mp, 3.6, ang - PI * 0.6, ang + PI * 0.6, 8, Color(0.85, 0.87, 0.92), 1.5)
			st.draw_circle(mp - aim * 1.5, 1.0, SU_GOLD)
	shot_line(st, c, SU_GOLD, 3.0)

# ================================================================ Phoenix Shrine
const PX_FLAME := Color(1.0, 0.55, 0.2)
const PX_GOLD := Color(1.0, 0.82, 0.35)
const PX_RED := Color(0.9, 0.25, 0.15)
const PX_WHITE := Color(1.0, 0.96, 0.8)
const PX_ASH := Color(0.35, 0.3, 0.3)

## A layered flame: red outside, flame, then gold, then white-hot inside.
static func flame3(st, base: Vector2, w: float, h: float, age: float, seed: float, edge := PX_RED) -> void:
	var sway := sin(age * 6.0 + seed) * w * 0.25
	SpellArt.flame(st, base, w, h, Color(edge, 0.9), sway)
	SpellArt.flame(st, base, w * 0.72, h * 0.8, Color(PX_FLAME, 0.95), sway * 0.9)
	SpellArt.flame(st, base, w * 0.4, h * 0.55, Color(PX_GOLD, 1.0), sway * 0.7)
	if h > 12.0:
		SpellArt.flame(st, base, w * 0.2, h * 0.3, Color(PX_WHITE, 1.0), sway * 0.5)

## A bird of fire seen from the side, flying toward `dir`, wings beating with `flap`.
static func bird(st, c: Vector2, dir: Vector2, size: float, flap: float, alpha: float) -> void:
	var back := -dir
	var side := dir.orthogonal()
	var wing := sin(flap) * 0.5 + 0.5
	# long tail: three flame dots
	for i in 3:
		st.draw_circle(c + back * (size * (1.2 + i * 0.9)), size * (0.45 - 0.1 * i), Color(PX_FLAME, alpha * (0.8 - 0.2 * i)))
	# two wings
	for k in [-1.0, 1.0]:
		var tip: Vector2 = c + side * k * size * (1.5 + 0.9 * wing) + back * size * 0.2 + Vector2(0, -size * 0.9 * wing)
		st.draw_colored_polygon(PackedVector2Array([c + side * k * size * 0.3, tip, c + back * size * 0.9 + side * k * size * 0.6]), Color(PX_FLAME.lerp(PX_GOLD, 0.4), alpha))
	# body and head
	st.draw_circle(c, size * 0.9, Color(PX_RED.lerp(PX_FLAME, 0.5), alpha))
	st.draw_circle(c + dir * size * 0.9, size * 0.5, Color(PX_GOLD, alpha))

static func draw_phoenix_shrine(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var r: float = st.radius
	var pulse := 0.5 + 0.5 * sin(age * 3.0)
	var last_breath: float = clampf((float(st.charge) - 0.9) / 0.1, 0.0, 1.0)      # the last tenth of its healing: it burns brighter
	var glow := 1.0 + 0.5 * last_breath
	# the field, as the plain healer draws it
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.06 + 0.04 * pulse))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(col, 0.35), 1.0)
	# 6: the edge is a ring of fire; 2: a wreath of small flames, alternating
	if t >= 6:
		st.draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(PX_FLAME, 0.5), 2.0)
		for i in 18:
			var a := i * TAU / 18.0
			flame3(st, Vector2.from_angle(a) * r, 3.0, 6.0 + 2.0 * sin(age * 5.0 + i), age, i * 1.7)
	else:
		for i in 8:
			if i % 2 == t % 2 or t >= 3:
				var a := i * TAU / 8.0 + 0.2
				flame3(st, Vector2.from_angle(a) * r * 0.97, 3.0, 6.0 + 1.5 * sin(age * 6.0 + i), age, i * 2.3)
	# 3: a gold ash ring on the ground, fine ash drifting down
	if t >= 3:
		st.draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 40, Color(PX_GOLD, 0.35 + 0.15 * pulse), 2.0)
		for i in 12:
			var u := fposmod(age * 0.3 + SpellArt.jit(i), 1.0)
			st.draw_circle(Vector2((SpellArt.jit(i, 3.0) - 0.5) * r * 1.6, -40.0 + u * 55.0), 0.9, Color(PX_ASH.lightened(0.3), 0.6 * (1.0 - u * 0.5)))
	# 6: heat haze above the ground
	if t >= 6:
		for k in 2:
			var pts := PackedVector2Array()
			for i in 10:
				pts.append(Vector2(-r * 0.5 + i * r * 0.11, -4.0 - k * 7.0 + sin(age * 3.0 + i * 0.8 + k) * 1.6))
			st.draw_polyline(pts, Color(1.0, 0.85, 0.6, 0.18), 1.0)
	# 5: big wings of flame spread behind the shrine
	if t >= 5:
		var flap := 0.5 + 0.5 * sin(age * 1.5)
		for k in [-1.0, 1.0]:
			for f in 4:
				var u := float(f) / 3.0
				var tip := Vector2(k * (20.0 + 14.0 * (1.0 - u * 0.3) + 4.0 * flap), -10.0 - 22.0 * (1.0 - u) - 2.0 * flap)
				var base := Vector2(k * 3.0, -6.0 - f * 1.5)
				var width := 4.5
				var n := (tip - base).orthogonal().normalized() * width
				st.draw_colored_polygon(PackedVector2Array([base - n * 0.3, tip, base + n * 1.2]), Color(PX_RED.lerp(PX_GOLD, u), 0.55 * glow))
	# the stone bowl pillar
	StructureArt.poly(st, PackedVector2Array([Vector2(-7, 7), Vector2(-4.5, -5), Vector2(4.5, -5), Vector2(7, 7)]), Color(0.55, 0.5, 0.48))
	StructureArt.poly(st, PackedVector2Array([Vector2(-7, -5), Vector2(-5, -9), Vector2(5, -9), Vector2(7, -5)]), Color(0.65, 0.6, 0.56))
	st.draw_rect(Rect2(-4, 0, 8, 2), PX_GOLD)
	# the flame: three layers, twice as tall from tier 5
	var fh := (32.0 if t >= 5 else 16.0) * glow
	flame3(st, Vector2(0, -8), 12.0 if t >= 5 else 9.0, fh + 2.0 * sin(age * 7.0), age, 0.0)
	if t >= 5:
		st.draw_arc(Vector2(0, -9), 9.0, 0, TAU, 20, Color(PX_GOLD, 0.8), 1.5)          # a gold ring floats round the bowl
	# 3: ember arcs rise in pairs; 2: embers float
	for i in 6:
		var u := fposmod(age * 0.6 + SpellArt.jit(i), 1.0)
		var x := (SpellArt.jit(i, 5.0) - 0.5) * 18.0 + sin(age * 3.0 + i) * 3.0
		st.draw_circle(Vector2(x, -12.0 - u * (30.0 if t >= 5 else 20.0)), 1.0, Color(PX_GOLD if i % 2 == 0 else PX_FLAME, 1.0 - u))
	# 6: the full phoenix perches on the shrine
	if t >= 6:
		var top := Vector2(0, -24.0 - 2.0 * sin(age * 2.0))
		for i in 5:
			st.draw_line(Vector2(0, top.y + 4.0), Vector2((i - 2.0) * 4.0, top.y + 15.0 + 2.0 * sin(age * 4.0 + i)), Color(PX_FLAME.lerp(PX_GOLD, i / 5.0), 0.9), 2.2)
		for k in [-1.0, 1.0]:
			var wing := PackedVector2Array([top + Vector2(k * 2.0, 3.0), top + Vector2(k * 13.0, -4.0 + 2.0 * sin(age * 2.5)), top + Vector2(k * 10.0, 7.0), top + Vector2(k * 3.0, 8.0)])
			st.draw_colored_polygon(wing, Color(PX_FLAME, 0.95))
			st.draw_line(wing[1], wing[2], PX_GOLD, 1.0)
		st.draw_circle(top + Vector2(0, 3.0), 4.5, Color.BLACK)
		st.draw_circle(top + Vector2(0, 3.0), 3.7, PX_RED.lerp(PX_FLAME, 0.4))
		st.draw_circle(top + Vector2(0, -2.0), 2.4, PX_GOLD)
		st.draw_line(top + Vector2(0, -3.5), top + Vector2(-2.0, -7.0), PX_FLAME, 1.2)
		st.draw_line(top + Vector2(0, -3.5), top + Vector2(2.0, -7.0), PX_GOLD, 1.2)
		st.draw_circle(top + Vector2(0.8, -2.2), 0.5, Color.BLACK)
		st.draw_arc(top + Vector2(0, 1.0), 14.0, 0, TAU, 24, Color(PX_GOLD, 0.7 + 0.2 * pulse), 1.5)
	# 4: the phoenix spirit circles the shrine (it dives on a hurt player: dive_to / dive_t); at tier 6 it appears only to dive
	var dive_t: float = float(st.vis.get("dive_t", 9.0))
	var diving := t >= 4 and dive_t < 0.5
	if t >= 4 and (t < 6 or diving):
		var orbit := Vector2.from_angle(age * 1.2) * r * 0.5
		orbit.y *= 0.5
		var bpos := orbit
		var bdir := Vector2.from_angle(age * 1.2 + PI * 0.5)
		if diving:
			var to: Vector2 = st.vis.get("dive_to", Vector2.ZERO)
			bpos = orbit.lerp(to, clampf(dive_t / 0.3, 0.0, 1.0))
			bdir = (to - orbit).normalized()
			st.draw_line(Vector2(0, -10), bpos, Color(PX_GOLD, 0.5 * (1.0 - dive_t / 0.5)), 3.0)
		bird(st, bpos + Vector2(0, -10), bdir, 4.0, age * 9.0, 0.7)
		for i in 3:
			st.draw_circle(bpos + Vector2(0, -10) - bdir * (8.0 + i * 5.0) + Vector2(0, sin(age * 6.0 + i) * 2.0), 1.0, Color(PX_GOLD, 0.6 - 0.15 * i))

# ================================================================ Healing Lantern
const LN_GOLD := Color(1.0, 0.85, 0.5)
const LN_WHITE := Color(1.0, 0.97, 0.85)
const LN_GREEN := Color(0.6, 1.0, 0.7)
const LN_IRON := Color(0.3, 0.3, 0.34)
const LN_GLASS := Color(0.9, 0.95, 1.0)

## A hanging glass lantern of `w` x `h` with a warm flame inside; its top centre is `top`.
static func lantern(st, top: Vector2, w: float, h: float, age: float, flame: float, seed: float) -> void:
	st.draw_rect(Rect2(top.x - w * 0.5, top.y, w, h), Color.BLACK)
	st.draw_rect(Rect2(top.x - w * 0.5 + 1.0, top.y + 1.0, w - 2.0, h - 2.0), Color(LN_GLASS, 0.4))
	SpellArt.flame(st, top + Vector2(0, h - 1.5), w * 0.5, h * 0.7 * flame, Color(1.0, 0.7, 0.25, 0.95), sin(age * 5.0 + seed) * 0.8)
	SpellArt.flame(st, top + Vector2(0, h - 1.5), w * 0.25, h * 0.4 * flame, LN_WHITE, 0.0)
	st.draw_rect(Rect2(top.x - w * 0.5 - 1.0, top.y - 2.0, w + 2.0, 2.5), LN_IRON)
	st.draw_rect(Rect2(top.x - w * 0.5 - 1.0, top.y + h - 0.5, w + 2.0, 2.5), LN_IRON)

static func orb(st, p: Vector2, r: float, tail_dir: Vector2, age: float, col: Color) -> void:
	for i in 4:
		st.draw_circle(p + tail_dir * (r * (1.5 + i * 1.2)) + Vector2(0, sin(age * 6.0 + i) * 1.2), r * (0.6 - 0.12 * i), Color(col, 0.7 - 0.15 * i))
	st.draw_circle(p, r + 1.0, Color(col, 0.3))
	st.draw_circle(p, r, col)
	st.draw_circle(p, r * 0.5, Color.WHITE)

static func draw_healing_lantern(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var r: float = st.radius
	var pulse := 0.5 + 0.5 * sin(age * 3.0)
	var flame := 1.0 + (0.25 if t >= 3 else 0.0) + (0.5 if t >= 6 else 0.0)
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.06 + 0.04 * pulse))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(col, 0.35), 1.0)
	# 6: a dawn-coloured glow over the field
	if t >= 6:
		st.draw_circle(Vector2.ZERO, r, Color(1.0, 0.75, 0.7, 0.07 + 0.03 * pulse))
		st.draw_circle(Vector2.ZERO, r * 0.55, Color(LN_GOLD, 0.07))
	# 3: a lit ring on the floor and six soft windows of light
	if t >= 3:
		st.draw_arc(Vector2.ZERO, r * 0.8, 0, TAU, 36, Color(LN_GOLD, 0.25), 1.0)
		for i in 6:
			var a := i * TAU / 6.0 + 0.3
			var wp := Vector2.from_angle(a) * r * 0.55
			st.draw_set_transform(wp, 0.0, Vector2(1.0, 0.5))
			st.draw_circle(Vector2.ZERO, 5.0, Color(LN_GOLD, 0.12 + 0.1 * SpellArt.jit(int(age * 3.0) + i, 1.0)))
			st.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for q in st.vis.get("lit", []):
			st.draw_arc(q, 4.5, 0, TAU, 10, Color(LN_WHITE, 0.6), 1.0)
	# 5: a ring of six tiny lamps on a chain
	if t >= 5:
		for i in 6:
			var a := i * TAU / 6.0 + age * 0.3
			var lp := Vector2(cos(a) * 11.0, -17.0 + sin(a) * 3.0)
			st.draw_circle(lp, 1.5, Color(LN_GOLD, 0.95))
		st.draw_arc(Vector2(0, -17), 11.0, 0, TAU, 20, Color(0.7, 0.55, 0.25, 0.7), 1.0)
	# the post: iron pole with a curled hook arm (brass and taller at tier 5, gold and ornate at tier 6)
	var post_col := LN_IRON
	var top_y := -18.0
	if t >= 5:
		post_col = Color(0.55, 0.42, 0.2)
		top_y = -24.0
	if t >= 6:
		post_col = Color(0.8, 0.65, 0.25)
	st.draw_rect(Rect2(-2, top_y, 4, 6.0 - top_y), Color.BLACK)
	st.draw_rect(Rect2(-1, top_y + 1.0, 2, 4.0 - top_y), post_col)
	st.draw_rect(Rect2(-5, 3, 10, 4), Color.BLACK)
	st.draw_rect(Rect2(-4, 4, 8, 2), post_col)
	if t >= 5:
		st.draw_arc(Vector2(-4, -8), 3.0, PI * 0.5, PI * 1.5, 8, post_col, 1.2)
		st.draw_arc(Vector2(4, -8), 3.0, -PI * 0.5, PI * 0.5, 8, post_col, 1.2)
	# the lantern hangs from the hook arm
	var hook := Vector2(0, top_y)
	st.draw_arc(hook + Vector2(4, 0), 4.0, PI, TAU * 0.95, 8, post_col, 1.5)
	var lt := hook + Vector2(8, 3.0)
	if t >= 6:
		# a great ornate lantern: gold frame, an openwork dome, a sun-flower flame inside, columns of light at the sides
		lt = Vector2(0, top_y - 12.0)
		st.draw_colored_polygon(PackedVector2Array([Vector2(-5, lt.y - 5), Vector2(-3, lt.y + 6), Vector2(3, lt.y + 6), Vector2(5, lt.y - 5)]), Color(LN_GLASS, 0.3))
		for k in [-8.0, 8.0]:
			st.draw_colored_polygon(PackedVector2Array([Vector2(k - 2, lt.y + 5), Vector2(k + 2, lt.y + 5), Vector2(k + 3, lt.y - 40), Vector2(k - 3, lt.y - 40)]), Color(LN_GOLD, 0.1))
		st.draw_arc(Vector2(0, lt.y - 5), 6.0, PI, TAU, 10, post_col, 1.5)
		st.draw_line(Vector2(0, lt.y - 11), Vector2(0, lt.y - 5), post_col, 1.0)
		for i in 10:
			var a := age * 0.5 + i * TAU / 10.0
			st.draw_line(Vector2(0, lt.y), Vector2.from_angle(a) * 6.0 + Vector2(0, lt.y), Color(LN_WHITE if i % 2 == 0 else LN_GOLD, 0.9), 1.5)
		st.draw_circle(Vector2(0, lt.y), 3.0, Color.WHITE)
		st.draw_arc(Vector2(0, lt.y), 11.0, 0, TAU, 24, Color(LN_GOLD, 0.5), 1.0)
		for i in 12:
			var a2 := i * TAU / 12.0 + age * 0.2
			st.draw_line(Vector2(0, lt.y) + Vector2.from_angle(a2) * 12.0, Vector2(0, lt.y) + Vector2.from_angle(a2) * 16.0, Color(LN_GOLD, 0.6), 1.0)
		st.draw_line(Vector2(0, lt.y + 6), Vector2(0, top_y), post_col, 1.5)
	else:
		if t >= 3:
			st.draw_circle(lt + Vector2(0, 5), 14.0, Color(LN_GOLD, 0.2))
		lantern(st, lt, 8.0, 10.0, age, flame, 0.0)
	# 4: a smaller lantern on a chain below, and a halo ring turning round the first
	if t >= 4 and t < 6:
		st.draw_line(lt + Vector2(0, 10), lt + Vector2(0, 14), Color(0.6, 0.6, 0.65), 1.0)
		lantern(st, lt + Vector2(0, 14), 5.0, 6.0, age, 0.8, 1.0)
		for k in 6:
			var a := age * 0.6 + k * TAU / 6.0
			st.draw_arc(lt + Vector2(0, 5), 12.0, a, a + 0.5, 4, Color(LN_GOLD, 0.7), 1.5)
	var rib: Variant = st.vis.get("ribbon", null)
	if rib != null:
		var tip: Vector2 = rib
		var mid: Vector2 = (lt + tip) * 0.5 + Vector2(0, -10.0 + sin(age * 6.0) * 4.0)
		st.draw_polyline(PackedVector2Array([lt + Vector2(0, 5), mid, tip + Vector2(0, -6)]), Color(LN_WHITE, 0.7), 1.5)
	# 5: three lantern spirits circle
	if t >= 5:
		for i in 3:
			var sp: Vector2 = TC.spirit_pos(st, i) - st.global_position
			orb(st, sp, 3.0, Vector2.from_angle(age * 1.2 + i * TAU / 3.0 - PI * 0.5), age, LN_GOLD)
	# 2: the wisp, and the thread to whom it tends
	var wisp: Vector2 = st.vis.get("wisp", Vector2(10, -16))
	orb(st, wisp, 2.6, Vector2(-1, 0.4).normalized(), age, LN_WHITE)
	if bool(st.vis.get("wisp_to", false)):
		st.draw_circle(wisp + Vector2(0, 5), 1.0, Color(LN_GREEN, 0.7))

# ================================================================ Beacon Turret
const BC_FLAME := Color(1.0, 0.7, 0.25)
const BC_BRASS := Color(0.9, 0.75, 0.35)
const BC_WHITE := Color(1.0, 0.97, 0.85)
const BC_STONE := Color(0.7, 0.68, 0.65)
const BC_RED := Color(0.85, 0.25, 0.2)

## A wedge of light from `c` toward `ang`, `half` wide each side, `len` long.
static func wedge(st, c: Vector2, ang: float, half: float, len: float, col: Color) -> void:
	st.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(ang - half) * len, c + Vector2.from_angle(ang + half) * len]), col)
	st.draw_line(c, c + Vector2.from_angle(ang) * len, Color(BC_WHITE, col.a + 0.3), 1.0)

static func draw_beacon_turret(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var beam_a: float = TC.beam_angle(st)
	var lamp := Vector2(0, -16.0 if t < 6 else -34.0)
	var flame := 1.0 + (0.4 if t >= 5 else 0.0) + (0.6 if t >= 6 else 0.0)
	var alert: bool = bool(st.vis.get("alert", false))
	# 3: the sweeping beam turns under the flame (6: long and bright with a halo, and a counter-beam)
	if t >= 3:
		var len: float = st.light_radius
		var a := 0.45 if t >= 6 else 0.35
		wedge(st, lamp, beam_a, 0.11, len, Color(BC_WHITE.lerp(BC_FLAME, 0.3), a))
		if t >= 6:
			wedge(st, lamp, beam_a + PI, 0.11, len, Color(BC_WHITE.lerp(BC_FLAME, 0.3), a))
			st.draw_circle(lamp, 12.0 + sin(age * 4.0), Color(BC_WHITE, 0.2))
	# 5: the horn sounds: arcs radiate from it
	var horn := Vector2(11, -8)
	var blow: float = st.fx_pulse
	# the housing
	if t >= 6:
		# a tapered stone tower with red and white bands, a gold-roofed lantern room and a gallery
		for i in 4:
			var y0 := 7.0 - i * 6.5
			var wb0 := 8.0 - i * 1.0
			var wb1 := 8.0 - (i + 1) * 1.0
			StructureArt.poly(st, PackedVector2Array([Vector2(-wb0, y0), Vector2(-wb1, y0 - 6.5), Vector2(wb1, y0 - 6.5), Vector2(wb0, y0)]), BC_RED if i % 2 == 0 else BC_WHITE)
		st.draw_rect(Rect2(-8, -20, 16, 2), Color.BLACK)
		st.draw_rect(Rect2(-7, -21, 14, 1), BC_BRASS)
		for i in 5:
			st.draw_line(Vector2(-7 + i * 3.5, -21), Vector2(-7 + i * 3.5, -24), BC_BRASS, 1.0)
		StructureArt.box(st, Rect2(-4.5, -33, 9, 9), Color(0.9, 0.95, 1.0, 0.5))
		StructureArt.poly(st, PackedVector2Array([Vector2(-6, -33), Vector2(0, -39), Vector2(6, -33)]), Color(0.85, 0.7, 0.2))
	else:
		StructureArt.box(st, Rect2(-7, -3, 14, 10), col.darkened(0.3))
		if t >= 4:
			StructureArt.box(st, Rect2(-5, -8, 10, 6), col.darkened(0.15))
			# a flare rack: three tubes with red caps; a gauge of the shots until the next flare
			for k in 3:
				st.draw_rect(Rect2(-12 + k * 3, -6, 2.5, 8), Color.BLACK)
				st.draw_rect(Rect2(-11.5 + k * 3, -5, 1.5, 6), Color(0.4, 0.4, 0.45))
				st.draw_rect(Rect2(-12 + k * 3, -7, 2.5, 2), BC_RED)
			st.draw_rect(Rect2(-12, 4, 9, 2), Color(0, 0, 0, 0.7))
			st.draw_rect(Rect2(-12, 4, 9.0 * st.charge, 2), BC_FLAME)
		# a brass band
		st.draw_rect(Rect2(-7, 2, 14, 2), BC_BRASS)
		if t >= 3:
			# the lighthouse lens: a glass drum with three glints
			var dy := -9.0 if t >= 4 else -8.0
			st.draw_rect(Rect2(-5, dy - 8.0, 10, 9), Color.BLACK)
			st.draw_rect(Rect2(-4, dy - 7.0, 8, 7), Color(0.85, 0.92, 1.0, 0.45))
			for k in 3:
				st.draw_line(Vector2(-2.5 + k * 2.5, dy - 6.0), Vector2(-2.5 + k * 2.5, dy - 1.0), Color(1, 1, 1, 0.8), 1.0)
	# 2: an iron cage round the signal flame, sparks rising (hidden by the room at tier 6, where the flame is huge)
	var base_y := (-17.0 if t >= 6 else (-18.0 if t >= 3 else -3.0))
	var fh := 10.0 * flame
	if t >= 6:
		base_y = -24.0
	SpellArt.flame(st, Vector2(0, base_y), 7.0 * flame, fh + 1.5 * sin(age * 7.0), Color(BC_FLAME, 0.95), sin(age * 5.0) * 1.0)
	SpellArt.flame(st, Vector2(0, base_y), 3.5 * flame, fh * 0.6, Color(BC_WHITE, 1.0), 0.0)
	if t < 6:
		for k in 3:
			st.draw_line(Vector2(-4.0 + k * 4.0, base_y + 1.0), Vector2(-4.0 + k * 4.0, base_y - 11.0 * flame), Color(0.2, 0.2, 0.22), 1.5)
		st.draw_line(Vector2(-5, base_y - 11.0 * flame), Vector2(5, base_y - 11.0 * flame), BC_BRASS, 1.5)
	for i in 4:
		var u := fposmod(age * 0.8 + SpellArt.jit(i), 1.0)
		st.draw_circle(Vector2((SpellArt.jit(i, 2.0) - 0.5) * 8.0, base_y - 8.0 - u * 18.0), 0.9, Color(BC_FLAME, 1.0 - u))
	# 5: the big brass horn with a red banner, a blinking red warning light
	if t >= 5:
		var hx := 11.0 if t < 6 else 10.0
		var hy := -6.0 if t < 6 else -12.0
		StructureArt.poly(st, PackedVector2Array([Vector2(hx - 3, hy - 1.5), Vector2(hx + 9, hy - 6.0), Vector2(hx + 9, hy + 6.0), Vector2(hx - 3, hy + 1.5)]), BC_BRASS)
		st.draw_line(Vector2(hx + 1, hy + 5), Vector2(hx + 1, hy + 12), Color(0.4, 0.3, 0.2), 1.5)
		StructureArt.poly(st, PackedVector2Array([Vector2(hx - 1, hy + 4), Vector2(hx + 4, hy + 4), Vector2(hx + 4, hy + 11), Vector2(hx + 1.5, hy + 9), Vector2(hx - 1, hy + 11)]), BC_RED)
		if blow < 0.6:
			for k in 3:
				st.draw_arc(Vector2(hx + 9, hy), 4.0 + k * 4.0 + blow * 14.0, -0.6, 0.6, 6, Color(BC_BRASS, 0.8 * (1.0 - blow / 0.6)), 1.5)
		if alert and sin(age * 10.0) > 0.0:
			st.draw_circle(Vector2(-9, -22 if t < 6 else -34), 3.0, Color(BC_RED, 0.95))
			st.draw_circle(Vector2(-9, -22 if t < 6 else -34), 6.0, Color(BC_RED, 0.25))
	# 6: the searchlight locked on one enemy: a thick white beam with a lens flare
	if t >= 6 and bool(st.vis.get("lock_on", false)):
		var to: Vector2 = st.vis.get("lock", Vector2.ZERO)
		st.draw_line(lamp, to, Color(BC_WHITE, 0.35), 8.0)
		st.draw_line(lamp, to, Color(BC_WHITE, 0.8), 3.0)
		glint(st, lamp, 8.0 + 2.0 * sin(age * 12.0), Color(BC_WHITE, 0.9))
		st.draw_circle(to, 6.0, Color(BC_WHITE, 0.4))
	if st.shot_t > 0.0:
		var to2: Vector2 = st.shot_to - st.global_position
		st.draw_line(lamp, to2, Color(BC_FLAME.lightened(0.4), 0.95), 2.0)
