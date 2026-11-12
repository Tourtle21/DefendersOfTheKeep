extends RefCounted
class_name SpellArt
## How each spell card is drawn, per tier: `draw_flight` is the shot on its way (called after the plain shot),
## `draw` is the landed art (called after the plain fill). All motion comes from the spell's own clock and from
## `jit`, so a LAN client draws exactly what the host does. Designs: docs/card_tiers/<card id>.md

const HOT := Color(1.0, 0.8, 0.3)
const CORE := Color(1.0, 0.97, 0.85)

## A steady "random" number from 0 to 1 for particle `i` (the same on every machine).
static func jit(i: int, salt := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

## Cards that have their own body art here: the plain fill and rings are drawn softer under it.
static func has_body(id: String) -> bool:
	return id in ["fireball", "frost_ring", "flare", "rejuvenation"]

static func draw_flight(s, t: float, col: Color) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			flight_fireball(s, t, col)
		"frost_ring":
			flight_frost_ring(s, t, col)

static func draw(s, since: float, col: Color) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			draw_fireball(s, since, col)
		"frost_ring":
			draw_frost_ring(s, since, col)
		"flare":
			draw_flare(s, since, col)
		"rejuvenation":
			draw_rejuvenation(s, since, col)

## A flame as one polygon: a wide base, a belly, and a tip that leans with `sway`.
static func flame(s, base: Vector2, w: float, h: float, col: Color, sway := 0.0) -> void:
	var tip := base + Vector2(sway, -h)
	s.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, 0), base + Vector2(-w * 0.35 + sway * 0.3, -h * 0.5), tip, base + Vector2(w * 0.35 + sway * 0.3, -h * 0.5), base + Vector2(w * 0.5, 0)]), col)

## A snowflake: `spokes` arms, each with `pairs` V-shaped branches along it.
static func snowflake(s, c: Vector2, r: float, rot: float, spokes: int, pairs: int, col: Color, width := 1.0) -> void:
	for i in spokes:
		var d := Vector2.from_angle(rot + i * TAU / float(spokes))
		s.draw_line(c, c + d * r, col, width)
		for k in pairs:
			var f := lerpf(0.35, 0.75, k / float(pairs - 1)) if pairs > 1 else 0.5
			var m := c + d * r * f
			var len := r * 0.22 * (1.0 - 0.3 * f)
			s.draw_line(m, m + Vector2.from_angle(rot + i * TAU / float(spokes) + 0.7) * len, col, width)
			s.draw_line(m, m + Vector2.from_angle(rot + i * TAU / float(spokes) - 0.7) * len, col, width)

static func diamond(s, p: Vector2, size: float, col: Color) -> void:
	s.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -size), p + Vector2(size * 0.6, 0), p + Vector2(0, size), p + Vector2(-size * 0.6, 0)]), col)

# ---------------------------------------------------------------- Fireball

static func flight_fireball(s, t: float, col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var from_local: Vector2 = s.origin - s.position
	var p := from_local.lerp(Vector2.ZERO, t)
	var back := from_local.normalized() if from_local.length() > 1.0 else Vector2.UP
	if tier >= 6:                                                          # a comet: halo, white core, a long sparking tail
		draw_halo(s, p, 9.0, Color(col, 0.35))
		for i in 12:
			var f := float(i)
			var q := p + back * (3.0 + f * 3.4) + back.orthogonal() * (jit(i, s.age * 6.0) - 0.5) * (1.0 + f * 0.5)
			s.draw_circle(q, maxf(0.6, 3.0 - f * 0.22), Color(HOT if i % 2 == 0 else col, 0.85 - f * 0.06))
		s.draw_circle(p, 4.0, CORE)
		return
	for i in 8:                                                            # a longer trail alternating hot and base
		s.draw_circle(p + back * (3.0 + i * 2.6), maxf(0.6, 3.4 - i * 0.35), Color(HOT if i % 2 == 0 else col, 0.85 - i * 0.09))
	s.draw_circle(p, 4.0, col)
	s.draw_circle(p, 2.0, CORE)
	if tier >= 3:                                                          # two embers circle the shot, and the target shows its bullseye
		for k in 2:
			var a: float = s.age * 9.0 + k * PI
			s.draw_circle(p + Vector2.from_angle(a) * 6.0, 1.5, HOT)
		for k in 12:
			var a0 := k * TAU / 12.0
			s.draw_arc(Vector2.ZERO, s.radius * 0.4, a0, a0 + 0.3, 4, Color(1, 1, 1, 0.7), 1.0)
	if tier >= 4:                                                          # a teardrop flame tail
		var side := back.orthogonal()
		s.draw_colored_polygon(PackedVector2Array([p + side * 3.0, p + back * 8.0 + side * 3.5, p + back * 14.0, p + back * 8.0 - side * 3.5, p - side * 3.0]), Color(col, 0.7))

static func draw_halo(s, p: Vector2, r: float, col: Color) -> void:
	s.draw_circle(p, r, col)

static func draw_fireball(s, since: float, col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	var r: float = s.radius
	if tier < 2:
		return
	var base_fade := clampf(1.0 - since / 0.4, 0.0, 1.0)
	var life: float = s.effect_time
	var end_fade := clampf((life - since) / 0.3, 0.0, 1.0)                  # the longer art fades in its last 0.3 s
	# tier 2: a white-hot centre and embers rising off the blast
	s.draw_circle(Vector2.ZERO, r * 0.45, Color(CORE, 0.8 * minf(since / 0.2, 1.0) * base_fade))
	var up := clampf(since / 0.4, 0.0, 1.0)
	for i in 4:
		var q := Vector2.from_angle(jit(i) * TAU) * r * 0.7 * jit(i, 2.0) + Vector2(0, -14.0 * up)
		s.draw_circle(q, 1.6, Color(HOT, 0.9 * base_fade))
	# tier 4: a corona of flame tongues turning round the disc
	if tier >= 4:
		for i in 8:
			var a: float = i * TAU / 8.0 + since * 0.9
			var h := 10.0 + 6.0 * jit(i, 3.0)
			var b := Vector2.from_angle(a) * r
			var n := Vector2.from_angle(a)
			var o := n.orthogonal()
			s.draw_colored_polygon(PackedVector2Array([b + o * 3.0, b + n * h, b - o * 3.0]), Color(col.lerp(HOT, 0.5), 0.5 * end_fade))
	# tier 5: a pillar of fire stays on the spot, with heat rings
	if tier >= 5:
		for i in 5:
			var f := float(i)
			var w: float = lerpf(r * 0.5, r * 0.2, f / 4.0)
			var sway := sin(since * 7.0 + f) * (1.0 + f)
			flame(s, Vector2(0, r * 0.1 - f * r * 0.2), w, r * 0.38, Color(CORE if i < 2 else col.lerp(HOT, 0.4), 0.45 * end_fade), sway * r * 0.05)
		var pulse := 0.5 + 0.5 * sin(since * 8.0)
		s.draw_arc(Vector2.ZERO, r * 0.55, 0, TAU, 32, Color(HOT, (0.3 + 0.3 * pulse) * end_fade), 1.0)
		s.draw_arc(Vector2.ZERO, r * 0.8, 0, TAU, 32, Color(HOT, (0.6 - 0.3 * pulse) * end_fade), 1.0)
	# tier 6: a miniature sun with turning rays
	if tier >= 6:
		s.draw_circle(Vector2.ZERO, r, Color(0.9, 0.2, 0.1, 0.22 * end_fade))
		s.draw_circle(Vector2.ZERO, r * 0.75, Color(1.0, 0.5, 0.1, 0.3 * end_fade))
		s.draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.85, 0.3, 0.35 * end_fade))
		for i in 12:
			var d := Vector2.from_angle(i * TAU / 12.0 + since * 0.8)
			s.draw_line(d * r * 0.5, d * r * 1.3, Color(HOT, 0.5 * end_fade), 2.0)

# ---------------------------------------------------------------- Frost Ring

const ICE := Color(0.55, 0.85, 1.0)
const FROST := Color(0.9, 0.97, 1.0)
const DEEP := Color(0.25, 0.5, 0.85)

static func flight_frost_ring(s, t: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 3:
		return
	var from_local: Vector2 = s.origin - s.position
	var p := from_local.lerp(Vector2.ZERO, t)
	var back := from_local.normalized() if from_local.length() > 1.0 else Vector2.UP
	for i in 6:
		s.draw_circle(p + back * (4.0 + i * 3.0) + back.orthogonal() * (jit(i, s.age) - 0.5) * 3.0, maxf(0.6, 2.0 - i * 0.25), Color(FROST, 0.8 - i * 0.1))
	snowflake(s, p, 5.0, s.age * 3.0, 6, 1, FROST, 1.0)

static func draw_frost_ring(s, since: float, col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0)
	var in_fade := clampf(since / 0.3, 0.0, 1.0) * fade
	# tier 2: a snowflake lies in the ring and crystals sit on the rim
	snowflake(s, Vector2.ZERO, r * 0.8, since * 0.15, 6, 3 if tier >= 5 else 2, Color(FROST, 0.5 * in_fade), 1.0)
	for i in 8:
		diamond(s, Vector2.from_angle(i * TAU / 8.0) * r, 4.0, Color(FROST, 0.8 * in_fade))
	# tier 3: the rim is a fence of crystals, and the floor cracks
	if tier >= 3:
		for i in 24:
			var a := i * TAU / 24.0
			var n := Vector2.from_angle(a)
			var o := n.orthogonal()
			var b := n * r
			s.draw_colored_polygon(PackedVector2Array([b + o * 2.5, b - n * 6.0, b - o * 2.5]), Color(ICE if i % 2 == 0 else FROST, 0.7 * in_fade))
		for i in 5:
			var a2 := jit(i, 5.0) * TAU
			var d := Vector2.from_angle(a2)
			s.draw_line(d * r * 0.25, d * r * 0.75, Color(FROST, 0.35 * in_fade), 1.0)
	# tier 4: a sheet of ice, a crystal spire at the centre, icicles circling it
	if tier >= 4:
		s.draw_circle(Vector2.ZERO, r * 0.6, Color(FROST, 0.18 * in_fade))
		for k in 3:
			var h := 16.0 if k == 0 else 10.0
			var x := 0.0 if k == 0 else (-5.0 if k == 1 else 5.0)
			s.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 3), Vector2(x - 2, -h * 0.6), Vector2(x, -h), Vector2(x + 2, -h * 0.6), Vector2(x + 3, 3)]), Color(ICE.lerp(Color.WHITE, 0.3 * k), 0.9 * in_fade))
		for i in 4:
			var a3 := since * 0.6 + i * TAU / 4.0
			var q := Vector2.from_angle(a3) * r * 0.45
			s.draw_colored_polygon(PackedVector2Array([q + Vector2(-2, -4), q + Vector2(2, -4), q + Vector2(0, 3)]), Color(FROST, 0.9 * in_fade))
	# tier 5: a halo of crystals round the ring, and snow falling inside
	if tier >= 5:
		for i in 12:
			diamond(s, Vector2.from_angle(since * 0.5 + i * TAU / 12.0) * r * 1.08, 5.0, Color(ICE, 0.8 * in_fade))
		for i in 16:
			var u := fposmod(since * 0.25 + jit(i), 1.0)
			var q2 := Vector2(jit(i, 1.0) - 0.5, jit(i, 2.0) - 0.5) * r * 1.6 + Vector2(0, -9.0 + 18.0 * u)
			if q2.length() < r:
				s.draw_circle(q2, 1.3, Color(Color.WHITE, 0.8 * in_fade * sin(u * PI)))
	# tier 6: a giant faint snowflake, aurora arcs, and a white circle that closes in during the last second
	if tier >= 6:
		snowflake(s, Vector2.ZERO, r * 0.95, -since * 0.1, 8, 3, Color(FROST, 0.25 * in_fade), 1.5)
		s.draw_arc(Vector2.ZERO, r * 0.55, since * 0.7, since * 0.7 + 1.22, 14, Color(0.4, 1.0, 1.0, 0.6 * in_fade), 2.0)
		s.draw_arc(Vector2.ZERO, r * 0.75, -since * 0.5 + 2.0, -since * 0.5 + 3.22, 14, Color(1, 1, 1, 0.6 * in_fade), 2.0)
		s.draw_arc(Vector2.ZERO, r * 0.95, since * 0.3 + 4.0, since * 0.3 + 5.22, 14, Color(0.5, 0.4, 1.0, 0.6 * in_fade), 2.0)
		var left: float = life - since
		if left < 1.0 and left > 0.0:
			s.draw_arc(Vector2.ZERO, lerpf(0.2, 1.0, left) * r, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.0)

# ---------------------------------------------------------------- Flare

## A tapered ray: wide at the start, a point at the end.
static func ray(s, from: Vector2, dir: Vector2, len: float, w0: float, w1: float, col: Color) -> void:
	var o := dir.orthogonal()
	s.draw_colored_polygon(PackedVector2Array([from + o * w0 * 0.5, from + dir * len + o * w1 * 0.5, from + dir * len - o * w1 * 0.5, from - o * w0 * 0.5]), col)

static func draw_flare(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	var sun := Color(1.0, 0.9, 0.5)
	var amber := Color(1.0, 0.65, 0.2)
	if tier >= 4:                                                   # a corona of flame tongues, a two-layer glow
		s.draw_circle(Vector2.ZERO, r, Color(sun, 0.12 * fade))
		s.draw_circle(Vector2.ZERO, r * 0.6, Color(amber, 0.12 * fade))
		for i in 12:
			var a := i * TAU / 12.0
			var n := Vector2.from_angle(a)
			var h := (8.0 + 6.0 * jit(i, 4.0)) * (0.8 + 0.2 * sin(since * 8.0 + i))
			s.draw_colored_polygon(PackedVector2Array([n * r + n.orthogonal() * 3.0, n * (r + h), n * r - n.orthogonal() * 3.0]), Color(amber, 0.6 * fade))
	if tier >= 3:                                                   # two opposite rays sweep round like a lighthouse
		var a2 := SpellTiers.ray_angle(since)
		for k in 2:
			var d := Vector2.from_angle(a2 + k * PI)
			ray(s, Vector2.ZERO, d, r, 9.0, 2.0, Color(sun, 0.45 * fade))
			s.draw_line(Vector2.ZERO, d * r, Color(1, 0.98, 0.9, 0.8 * fade), 1.0)
	# tier 2: a lens-flare star (eight rays at tier 6), a white core and a halo
	var rays := 4 if tier >= 6 else 2
	for i in rays:
		var d2 := Vector2.from_angle(since * 0.6 + i * PI / float(rays))
		ray(s, Vector2.ZERO, d2, r * 0.4, 5.0, 0.0, Color(sun, 0.8 * fade))
		ray(s, Vector2.ZERO, -d2, r * 0.4, 5.0, 0.0, Color(sun, 0.8 * fade))
	s.draw_circle(Vector2.ZERO, r * 0.25, Color(sun, 0.3 * fade))
	s.draw_circle(Vector2.ZERO, 3.0, Color(1, 0.98, 0.9, fade))
	if tier >= 5:                                                   # two small suns orbit and shoot
		s.draw_arc(Vector2.ZERO, r * 0.6, 0, TAU, 32, Color(sun, 0.15 * fade), 1.0)
		for i in 2:
			var ang: float = s.age * SpellTiers.FLARE_SUN_SPEED + i * PI
			var p := Vector2.from_angle(ang) * r * 0.6
			for k in 3:
				s.draw_circle(Vector2.from_angle(ang - 0.16 * (k + 1)) * r * 0.6, 2.0 - k * 0.5, Color(amber, 0.6 * fade))
			s.draw_circle(p, 7.0, Color(amber, 0.5 * fade))
			s.draw_circle(p, 4.0, Color(1, 0.98, 0.9, fade))
	if tier >= 6:                                                   # a sunrise, a double halo, a crown
		var pulse := 0.25 + 0.1 * sin(since * 2.0)
		for i in 10:
			var d3 := Vector2.from_angle(deg_to_rad(lerpf(-160.0, -20.0, i / 9.0)))
			s.draw_line(d3 * r * 0.2, d3 * r * 1.1, Color(1.0, 0.85, 0.3, pulse * fade), 2.0)
		s.draw_circle(Vector2.ZERO, r * 0.4, Color(1.0, 0.85, 0.3, 0.15 * fade))
		s.draw_arc(Vector2.ZERO, r * 1.04, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.8 * fade), 1.5)
		for i in 16:
			var n2 := Vector2.from_angle(i * TAU / 16.0)
			s.draw_line(n2 * r * 1.04, n2 * r * 1.12, Color(1.0, 0.85, 0.3, 0.8 * fade), 2.0)

# ---------------------------------------------------------------- Rejuvenation

const LEAF := Color(0.4, 1.0, 0.5)
const PETAL := Color(1.0, 0.75, 0.85)
const BARK := Color(0.45, 0.3, 0.18)

static func draw_rejuvenation(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.3, 0.0, 1.0)
	var sway := sin(since * 1.5) * 1.5
	if tier >= 6:                                                   # a gold glow and a ring pulse with each heal wave
		s.draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.85, 0.3, 0.15 * fade))
		var wv := fposmod(since, 2.0) / 2.0
		s.draw_arc(Vector2.ZERO, r * wv, 0, TAU, 40, Color(1.0, 0.85, 0.3, 0.6 * (1.0 - wv) * fade), 1.5)
	if tier >= 3:                                                   # roots fan out under everything, with sprouts
		for i in 6:
			var a := i * TAU / 6.0 + 0.2
			var d := Vector2.from_angle(a)
			var o := d.orthogonal()
			var mid := d * r * 0.45 + o * r * 0.12 * (1.0 if i % 2 == 0 else -1.0)
			var tip := d * r * 0.9
			s.draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip]), Color(BARK, 0.5 * fade), 2.0)
			s.draw_line(mid, mid + Vector2(0, -4), Color(LEAF, 0.8 * fade), 1.0)
			s.draw_line(tip * 0.8, tip * 0.8 + Vector2(0, -3), Color(LEAF, 0.8 * fade), 1.0)
	if tier >= 5:                                                   # vines climb in from the rim
		var grow := minf(1.0, since * 1.5)
		for i in 8:
			var a2 := i * TAU / 8.0
			var pts := PackedVector2Array()
			for k in 6:
				var u := k / 5.0 * grow
				var rad := lerpf(r, r * 0.25, u)
				pts.append(Vector2.from_angle(a2 + u * 1.2) * rad)
			s.draw_polyline(pts, Color(LEAF, 0.7 * fade), 1.5)
			if pts.size() > 2:
				var q := pts[2]
				s.draw_colored_polygon(PackedVector2Array([q, q + Vector2(2.5, -2), q + Vector2(0.5, 2.5)]), Color(0.3, 0.7, 0.3, 0.8 * fade))
	if tier <= 3:                                                   # a six-petal flower that breathes
		var k := 1.0 + 0.08 * sin(since * 2.0)
		for i in 6:
			var d2 := Vector2.from_angle(i * TAU / 6.0)
			var pt := d2 * r * 0.14 * k
			var o2 := d2.orthogonal() * r * 0.06 * k
			s.draw_colored_polygon(PackedVector2Array([pt - d2 * r * 0.14 * k, pt + o2, pt + d2 * r * 0.14 * k, pt - o2]), Color(PETAL, 0.9 * fade))
		s.draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.3, fade))
	else:                                                           # a sapling, a young tree, then a full tree
		var trunk_w := 3.0 if tier == 4 else (4.0 if tier == 5 else 6.0)
		var trunk_h := 12.0 if tier == 4 else (16.0 if tier == 5 else 22.0)
		s.draw_rect(Rect2(-trunk_w / 2.0, -trunk_h, trunk_w, trunk_h), Color(BARK, fade))
		var top := Vector2(sway, -trunk_h)
		if tier == 4:
			s.draw_circle(top, 6.0, Color(LEAF, fade))
			s.draw_circle(top + Vector2(-5, 3), 5.0, Color(LEAF.darkened(0.15), fade))
			s.draw_circle(top + Vector2(5, 3), 5.0, Color(LEAF.darkened(0.15), fade))
			s.draw_circle(top + Vector2(-1.5, -2), 2.0, Color(0.7, 1.0, 0.7, 0.8 * fade))
		elif tier == 5:
			for k2 in 3:
				s.draw_circle(top + Vector2((k2 - 1) * 7.0, 2.0 - (1 if k2 == 1 else 0) * 5.0), 8.0, Color(LEAF.darkened(0.1 * k2), fade))
		else:
			s.draw_line(Vector2(0, -trunk_h * 0.6), Vector2(-8, -trunk_h * 0.9), Color(BARK, fade), 2.0)
			s.draw_line(Vector2(0, -trunk_h * 0.5), Vector2(8, -trunk_h * 0.85), Color(BARK, fade), 2.0)
			for k3 in 7:
				var off := Vector2(cos(k3 * 1.9) * 9.0, sin(k3 * 2.3) * 6.0)
				s.draw_circle(top + off + Vector2(0, -6), 7.0 + (k3 % 4), Color(Color(0.25, 0.75, 0.3).lerp(LEAF, (k3 % 3) / 2.0), 0.9 * fade))
			for k4 in 5:
				s.draw_circle(top + Vector2(cos(k4 * 2.7) * 11.0, -6.0 + sin(k4 * 1.3) * 8.0), 1.6, Color(PETAL, fade))
			for k5 in 12:
				var u2 := fposmod(since * 0.35 + jit(k5), 1.0)
				s.draw_circle(Vector2((jit(k5, 1.0) - 0.5) * r * 1.4 + sin(u2 * 6.0) * 4.0, -trunk_h - 6.0 + u2 * (trunk_h + 12.0)), 1.2, Color(PETAL, 0.8 * fade * (1.0 - u2)))
	for i in 6:                                                     # leaf motes rise from the disc
		var u3 := fposmod(since * 0.4 + jit(i), 1.0)
		var q2 := Vector2.from_angle(jit(i, 2.0) * TAU) * r * 0.8 * jit(i, 3.0) + Vector2(0, -u3 * 18.0)
		s.draw_circle(q2, 1.6, Color(LEAF, 0.9 * (1.0 - u3) * fade))
