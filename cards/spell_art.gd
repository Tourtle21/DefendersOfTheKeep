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
	return id in ["fireball", "frost_ring", "flare", "rejuvenation", "gold_magnet", "aegis", "charm", "sandstorm", "blizzard", "lava_pool", "poison_cloud", "crystal_spikes", "meteor_shower", "stasis", "mass_conversion", "frostfire", "solar_burst"]

static func draw_flight(s, t: float, col: Color) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			flight_fireball(s, t, col)
		"frost_ring":
			flight_frost_ring(s, t, col)
		"sandstorm":
			flight_sandstorm(s, t, col)
		"frostfire":
			flight_frostfire(s, t, col)
		"solar_burst":
			flight_solar_burst(s, t, col)

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
		"gold_magnet":
			draw_gold_magnet(s, since, col)
		"aegis":
			draw_aegis(s, since, col)
		"charm":
			draw_charm(s, since, col)
		"sandstorm":
			draw_sandstorm(s, since, col)
		"blizzard":
			draw_blizzard(s, since, col)
		"lava_pool":
			draw_lava_pool(s, since, col)
		"poison_cloud":
			draw_poison_cloud(s, since, col)
		"crystal_spikes":
			draw_crystal_spikes(s, since, col)
		"meteor_shower":
			draw_meteor_shower(s, since, col)
		"stasis":
			draw_stasis(s, since, col)
		"mass_conversion":
			draw_mass_conversion(s, since, col)
		"frostfire":
			draw_frostfire(s, since, col)
		"solar_burst":
			draw_solar_burst(s, since, col)

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

# ---------------------------------------------------------------- Gold Magnet

const GOLD := Color(1.0, 0.85, 0.25)
const MAGNET_RED := Color(0.85, 0.2, 0.2)
const STEEL := Color(0.8, 0.85, 0.95)

## A horseshoe magnet: a thick red arc with steel tips.
static func horseshoe(s, c: Vector2, rot: float, size: float, red: Color, alpha: float) -> void:
	var a0 := rot + deg_to_rad(-100.0) + PI / 2.0
	s.draw_arc(c, size, a0, a0 + deg_to_rad(200.0), 14, Color(red, alpha), size * 0.35)
	for e in [a0, a0 + deg_to_rad(200.0)]:
		s.draw_circle(c + Vector2.from_angle(e) * size, size * 0.32, Color(STEEL, alpha))

static func draw_gold_magnet(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 0.5, 0.0, 1.0) * clampf(since / 0.1 + 0.3, 0.0, 1.0)
	var spin := since * TAU
	if tier >= 5:                                                   # a golden whirlpool: three arms with coin sparks
		for k in 3:
			var pts := PackedVector2Array()
			for i in 8:
				var u := i / 7.0
				pts.append(Vector2.from_angle(since * 2.2 + k * TAU / 3.0 + u * 2.5) * lerpf(r * 0.1, r * 0.9, u))
			s.draw_polyline(pts, Color(GOLD, 0.5 * fade), 2.0)
			var spark := fposmod(since * 0.8 + k * 0.33, 1.0)
			s.draw_circle(pts[clampi(int(spark * 7.0), 0, 7)], 2.0, Color(1.0, 0.95, 0.6, fade))
	if tier >= 6:                                                   # a solar coin: engraved rings, turning rays, mini coins
		s.draw_circle(Vector2.ZERO, r * 0.6, Color(GOLD, 0.25 * fade))
		s.draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 32, Color(1.0, 0.95, 0.6, 0.6 * fade), 1.5)
		for i in 24:
			var a := i * TAU / 24.0
			s.draw_arc(Vector2.ZERO, r * 0.42, a, a + 0.09, 3, Color(1.0, 0.95, 0.6, 0.5 * fade), 1.0)
		for i in 12:
			var d := Vector2.from_angle(since * 0.8 + i * TAU / 12.0)
			s.draw_line(d * r * 0.62, d * r * 0.95, Color(1.0, 0.95, 0.6, 0.4 * fade), 2.0)
		for i in 8:
			s.draw_circle(Vector2.from_angle(-since * 1.2 + i * TAU / 8.0) * r * 0.8, 3.0, Color(GOLD, 0.9 * fade))
		for i in 8:
			var u2 := fposmod(since * 0.7 + jit(i), 1.0)
			s.draw_circle(Vector2((jit(i, 1.0) - 0.5) * 12.0, -u2 * r * 0.9), 1.5, Color(1.0, 0.95, 0.6, 0.8 * (1.0 - u2) * fade))
	# tier 2: the real reach is a dotted ring at 1.6 r, a horseshoe magnet spins in the middle, field lines slide inward
	var reach := r * 1.6
	for i in 40:
		var a2 := i * TAU / 40.0
		s.draw_arc(Vector2.ZERO, reach, a2, a2 + 0.07, 3, Color(GOLD, 0.5 * fade), 1.0)
	for i in 6:
		var a3 := i * TAU / 6.0
		var ph := fposmod(since * 1.5 + i / 6.0, 1.0)
		var rr := lerpf(r * 0.95, r * 0.2, ph)
		s.draw_arc(Vector2.ZERO, rr, a3, a3 + 0.25, 4, Color(GOLD, 0.6 * fade * (1.0 - ph * 0.5)), 1.5)
	var white := tier >= 6
	horseshoe(s, Vector2.ZERO, spin, 12.0, MAGNET_RED.lerp(Color(1, 0.95, 0.7), 0.7) if white else MAGNET_RED, fade)
	if tier >= 3:                                                   # a second magnet, opposed, and twinkling gold on the rim
		horseshoe(s, Vector2.ZERO, spin + PI, 12.0, MAGNET_RED.lerp(Color(1, 0.95, 0.7), 0.7) if white else MAGNET_RED, fade)
		for i in 4:
			var tw := 0.5 + 0.5 * sin(since * 6.0 + jit(i) * 6.0)
			s.draw_circle(Vector2.from_angle(jit(i, 7.0) * TAU) * r, 1.0 + 1.5 * tw, Color(1.0, 0.95, 0.6, tw * fade))
	if tier >= 4:                                                   # three coins orbit and a gold ring breathes
		for i in 3:
			var p := Vector2.from_angle(since * 2.4 + i * TAU / 3.0) * r * 0.35
			s.draw_circle(p, 3.0, Color(GOLD, fade))
			s.draw_circle(p + Vector2(-1, -1), 1.0, Color(1, 1, 0.8, fade))
		s.draw_arc(Vector2.ZERO, r * (0.9 + 0.05 * sin(since * 5.0)), 0, TAU, 40, Color(GOLD, 0.5 * fade), 1.5)

# ---------------------------------------------------------------- Aegis Ward

const WARD := Color(0.65, 0.75, 1.0)
const WARD_DEEP := Color(0.3, 0.35, 0.7)
const WARD_GOLD := Color(1.0, 0.88, 0.45)

static func draw_aegis(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.3, 0.0, 1.0)
	var pulse_lit := tier >= 4 and fposmod(since, 1.2) < 0.2
	# tier 2: a hex dome: a hexagon, six spokes, a second rim, and sparks sliding round the rim
	var hex := PackedVector2Array()
	for i in 7:
		hex.append(Vector2.from_angle(i * TAU / 6.0) * r * 0.55)
	s.draw_polyline(hex, Color(WARD, 0.6 * fade), 1.0)
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0)
		s.draw_line(d * r * 0.55, d * r, Color(WARD, 0.4 * fade), 1.0)
		s.draw_circle(Vector2.from_angle(since * 1.2 + i * TAU / 6.0) * r, 2.0, Color(0.95, 0.97, 1.0, 0.9 * fade))
	s.draw_arc(Vector2.ZERO, r * 0.92, 0, TAU, 40, Color(WARD, 0.4 * fade), 1.0)
	if pulse_lit:
		s.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 1, 1, fade), 3.0)
	# tier 5: mirror facets with a glint sweeping across
	if tier >= 5:
		for i in 8:
			var a := i * TAU / 8.0
			var n := Vector2.from_angle(a)
			var o := n.orthogonal()
			var kite := PackedVector2Array([n * r * 0.3, n * r * 0.6 + o * r * 0.2, n * r * 0.95, n * r * 0.6 - o * r * 0.2])
			s.draw_colored_polygon(kite, Color(1, 1, 1, 0.25 * fade))
			s.draw_polyline(PackedVector2Array([kite[0], kite[1], kite[2], kite[3], kite[0]]), Color(1, 1, 1, 0.6 * fade), 1.0)
		var gx := lerpf(-r, r, fposmod(since / 1.5, 1.0))
		s.draw_colored_polygon(PackedVector2Array([Vector2(gx - 3, -r * 0.6), Vector2(gx + 3, -r * 0.6 - 0.0), Vector2(gx - 3 + r * 0.3, r * 0.6), Vector2(gx - 9 + r * 0.3, r * 0.6)]), Color(1, 1, 1, 0.3 * fade))
	# tier 4: three rune glyphs circle the dome
	if tier >= 4:
		for i in 3:
			var p := Vector2.from_angle(since * 0.9 + i * TAU / 3.0) * r * 0.78
			s.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(4, 0), p + Vector2(0, 6), p + Vector2(-4, 0)]), Color(WARD, 0.85 * fade))
			s.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color(WARD_DEEP, fade), 1.0)
			s.draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), Color(WARD_DEEP, fade), 1.0)
			s.draw_circle(p, 1.2, Color(1, 1, 1, fade))
	# tier 6: a golden sanctuary: columns, an arch, a halo, a light column, wings
	if tier >= 6:
		s.draw_rect(Rect2(-1.5, -r * 0.9, 3.0, r * 0.9), Color(WARD_GOLD, 0.15 * fade))
		for i in 4:
			var cp := Vector2.from_angle(i * TAU / 4.0) * r
			s.draw_rect(Rect2(cp.x - 2.5, cp.y - 15.0, 5.0, 14.0), Color.BLACK)
			s.draw_rect(Rect2(cp.x - 1.5, cp.y - 14.0, 3.0, 12.0), Color(WARD_GOLD, fade))
		s.draw_arc(Vector2(0, -8), r * 0.85, deg_to_rad(200.0), deg_to_rad(340.0), 24, Color(WARD_GOLD, 0.8 * fade), 2.0)
		for i in 20:
			var a2 := since * 0.4 + i * TAU / 20.0
			s.draw_arc(Vector2.ZERO, r * 0.9, a2, a2 + 0.18, 3, Color(WARD_GOLD, 0.5 * fade), 1.5)
		for sd in [-1.0, 1.0]:
			var base := Vector2(sd * r * 0.2, -4)
			s.draw_colored_polygon(PackedVector2Array([base, base + Vector2(sd * r * 0.5, -r * 0.25), base + Vector2(sd * r * 0.45, -r * 0.05), base + Vector2(0, 6)]), Color(1, 1, 1, 0.25 * fade))
	# tier 3 and up: the emblem in the middle: a shield, a mirror at tier 5, nothing under the tier 6 sanctuary
	if tier >= 3 and tier < 6:
		var hov := -2.0 + 2.0 * sin(since * 2.0)
		var pts := PackedVector2Array([Vector2(-8, -9 + hov), Vector2(8, -9 + hov), Vector2(8, 1 + hov), Vector2(4, 6 + hov), Vector2(0, 9 + hov), Vector2(-4, 6 + hov), Vector2(-8, 1 + hov)])
		var body := Color(1, 1, 1, 0.9 * fade) if tier >= 5 else Color(WARD_DEEP, 0.95 * fade)
		s.draw_colored_polygon(pts, body)
		s.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[0]]), Color(WARD_DEEP, fade) if tier >= 5 else Color(1, 1, 1, fade), 1.5)
		if tier < 5:
			s.draw_line(Vector2(0, -7 + hov), Vector2(0, 5 + hov), Color(WARD_GOLD, fade), 2.0)
			s.draw_line(Vector2(-5, -2 + hov), Vector2(5, -2 + hov), Color(WARD_GOLD, fade), 2.0)

# ---------------------------------------------------------------- Charm

const PINK := Color(1.0, 0.5, 0.7)
const ROSE := Color(1.0, 0.75, 0.85)
const MINT := Color(0.5, 1.0, 0.7)
const CROWN_GOLD := Color(1.0, 0.85, 0.4)

## A heart: two round lobes and a point.
static func heart(canvas, p: Vector2, size: float, col: Color) -> void:
	canvas.draw_circle(p + Vector2(-size * 0.5, -size * 0.3), size * 0.55, col)
	canvas.draw_circle(p + Vector2(size * 0.5, -size * 0.3), size * 0.55, col)
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-size * 1.0, -size * 0.1), p + Vector2(size * 1.0, -size * 0.1), p + Vector2(0, size * 1.0)]), col)

static func heart_outline(canvas, p: Vector2, size: float, rot: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := i * TAU / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(p + Vector2(x, y).rotated(rot) * size / 16.0)
	canvas.draw_polyline(pts, col, width)

static func draw_charm(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 0.6, 0.0, 1.0)
	# tier 2: hearts round the rim, a faint heart in the middle, and a heart rising from each charmed enemy
	for i in 6:
		heart(s, Vector2.from_angle(i * TAU / 6.0) * r, 2.5, Color(PINK, 0.9 * fade))
	heart_outline(s, Vector2.ZERO, r * 0.4, 0.0, Color(PINK, 0.35 * fade), 1.0)
	if since < 1.0:
		for e in s.get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.get("charm_time") != null and e.charm_time > 0.0 and e.global_position.distance_to(s.global_position) <= r + 10.0:
				heart(s, e.global_position - s.global_position + Vector2(0, -14.0 - 14.0 * since), 3.0, Color(PINK, 1.0 - since))
	if tier >= 3:                                                   # a pulsing field, three dashed rings turning opposite ways, rising hearts
		s.draw_circle(Vector2.ZERO, r, Color(MINT.lerp(PINK, 0.5 + 0.3 * sin(since * 4.0)), 0.12 * fade))
		for k in 3:
			var rr := r * (0.9 - 0.2 * k)
			var dir := 1.0 if k % 2 == 0 else -1.0
			for i in 16:
				var a := dir * since * 0.8 + i * TAU / 16.0
				s.draw_arc(Vector2.ZERO, rr, a, a + 0.14, 3, Color(PINK, 0.5 * fade), 1.0)
		for i in 6:
			var u := fposmod(since * 0.4 + jit(i), 1.0)
			heart(s, Vector2.from_angle(jit(i, 2.0) * TAU) * r * 0.8 * jit(i, 3.0) + Vector2(0, -u * 20.0), 2.0, Color(PINK, 0.8 * (1.0 - u) * fade))
	if tier >= 4:                                                   # a big turning heart and eight spark hearts
		heart_outline(s, Vector2.ZERO, r * 0.5, sin(since) * 0.3, Color(PINK, 0.9 * fade), 2.0)
		heart_outline(s, Vector2.ZERO, r * 0.45, sin(since) * 0.3, Color(1, 1, 1, 0.4 * fade), 1.0)
		for i in 8:
			heart(s, Vector2.from_angle(since * 1.1 + i * TAU / 8.0) * r * 0.7, 1.8, Color(ROSE, 0.9 * fade))
	if tier >= 5:                                                   # pink vapour and petals on the rim
		for i in 10:
			var vp := Vector2(sin(since * 0.4 + jit(i) * 6.0), cos(since * 0.3 + jit(i, 1.0) * 6.0)) * r * 0.7 * jit(i, 2.0)
			s.draw_circle(vp, 5.0 + 4.0 * jit(i, 3.0), Color(PINK, 0.12 * fade))
		for i in 12:
			var d := Vector2.from_angle(i * TAU / 12.0)
			s.draw_colored_polygon(PackedVector2Array([d * r, d * (r + 7.0) + d.orthogonal() * 3.0, d * (r + 11.0), d * (r + 7.0) - d.orthogonal() * 3.0]), Color(ROSE, 0.6 * fade))
	if tier >= 6:                                                   # a gold field, falling hearts, and a crown over the Favourite
		s.draw_circle(Vector2.ZERO, r, Color(CROWN_GOLD, 0.1 * fade))
		for i in 24:
			var a2 := since * 0.5 + i * TAU / 24.0
			s.draw_arc(Vector2.ZERO, r * 1.02, a2, a2 + 0.14, 3, Color(CROWN_GOLD, 0.8 * fade), 1.5)
		for i in 16:
			var u2 := fposmod(since * 0.25 + jit(i, 4.0), 1.0)
			heart(s, Vector2((jit(i, 5.0) - 0.5) * r * 1.6, -r * 0.6 + u2 * r * 1.2), 2.0, Color(CROWN_GOLD, 0.8 * sin(u2 * PI) * fade))
		if s.favourite_on:
			var fp: Vector2 = s.favourite_pos - s.global_position + Vector2(0, -22.0)
			s.draw_colored_polygon(PackedVector2Array([fp + Vector2(-5, 4), fp + Vector2(-5, -3), fp + Vector2(-2.5, 0), fp + Vector2(0, -5), fp + Vector2(2.5, 0), fp + Vector2(5, -3), fp + Vector2(5, 4)]), CROWN_GOLD)
			s.draw_arc(fp + Vector2(0, 2), 12.0, 0, TAU, 20, Color(CROWN_GOLD, 0.8), 1.5)

# ---------------------------------------------------------------- Sandstorm

const SAND := Color(0.92, 0.75, 0.4)
const DUST := Color(0.75, 0.6, 0.35)
const SAND_BRIGHT := Color(1.0, 0.9, 0.6)
const SAND_DARK := Color(0.45, 0.32, 0.18)

## A stack of turning arcs that widens upward: a dust devil, a funnel, a tornado.
static func funnel(s, n: int, r0: float, r1: float, height: float, since: float, alpha: float) -> void:
	for i in n:
		var u := i / float(maxi(n - 1, 1))
		var y := -u * height
		var a0 := since * (1.5 + i * 0.35) * (1.0 if i % 2 == 0 else -1.0)
		s.draw_arc(Vector2(0, y), lerpf(r0, r1, u), a0, a0 + PI * 1.3, 12, Color(SAND_BRIGHT if i % 2 == 0 else SAND_DARK.lightened(0.2), alpha), 2.0)

static func flight_sandstorm(s, t: float, _col: Color) -> void:
	if int(s.data.get("tier", 1)) < 3:
		return
	var p: Vector2 = (s.origin - s.position).lerp(Vector2.ZERO, t)
	for k in 3:
		var a: float = s.age * 8.0 + k * 2.0
		s.draw_arc(p, 3.0 + k * 2.0, a, a + 2.5, 8, Color(SAND_BRIGHT, 0.8 - k * 0.2), 1.5)

static func draw_sandstorm(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var fade := clampf((s.effect_time - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	if tier >= 3:                                                   # ripples on the floor and streaks of wind
		for k in 3:
			for i in 12:
				var a := i * TAU / 12.0 + k
				s.draw_arc(Vector2.ZERO, r * (0.35 + 0.2 * k), a, a + 0.25, 4, Color(DUST, 0.3 * fade), 1.0)
		for i in 6:
			var a2 := since * (0.8 + 0.1 * i) + i * TAU / 6.0
			s.draw_arc(Vector2.ZERO, r * (0.5 + 0.09 * i), a2, a2 + deg_to_rad(40.0), 8, Color(SAND_BRIGHT, 0.4 * fade), 1.5)
	if tier >= 4:                                                   # dark clouds roll round, chevrons show the gust
		for i in 5:
			var cp := Vector2.from_angle(since * 0.5 + i * TAU / 5.0) * r * 0.5
			s.draw_circle(cp, 10.0 + 6.0 * jit(i), Color(SAND_DARK, 0.18 * fade))
		for i in 3:
			var ang := since * 0.9 + i * TAU / 3.0
			var p := Vector2.from_angle(ang) * r * 0.7
			var d := Vector2.from_angle(since * 0.9)
			s.draw_polyline(PackedVector2Array([p - d * 4.0 + d.orthogonal() * 4.0, p + d * 2.0, p - d * 4.0 - d.orthogonal() * 4.0]), Color(SAND_BRIGHT, 0.8 * fade), 2.0)
	if tier >= 5:                                                   # low dunes on the rim
		for i in 6:
			var b := Vector2.from_angle(i * TAU / 6.0 + 0.3) * r
			s.draw_colored_polygon(PackedVector2Array([b + Vector2(-9, 3), b + Vector2(-6, -3), b + Vector2(0, -5), b + Vector2(6, -3), b + Vector2(9, 3)]), Color(DUST, 0.9 * fade))
			s.draw_line(b + Vector2(-9, 3), b + Vector2(9, 3), Color(SAND_DARK, 0.9 * fade), 2.0)
	if tier >= 6:                                                   # twelve standing stones rise round the rim
		var up := minf(1.0, since * 2.0)
		for i in 12:
			var b2 := Vector2.from_angle(i * TAU / 12.0) * r * 1.05
			s.draw_rect(Rect2(b2.x - 2.0, b2.y - 7.0 * up, 4.0, 8.0 * up), Color.BLACK)
			s.draw_rect(Rect2(b2.x - 1.5, b2.y - 7.0 * up + 0.5, 3.0, 7.0 * up), Color(SAND_DARK, fade))
		if fposmod(since * 3.0, 1.0) < 0.1:
			var d2 := Vector2.from_angle(jit(int(since * 3.0), 2.0) * TAU) * r * 0.6
			s.draw_line(d2, d2 * 0.2, Color(1.0, 0.95, 0.7, 0.8 * fade), 1.5)
	# the whirlwind at the centre grows with the tier: a devil, a funnel, a tornado
	if tier >= 6:
		funnel(s, 8, 4.0, 24.0, 40.0, since, 0.85 * fade)
	elif tier >= 5:
		funnel(s, 5, 3.0, 17.0, 26.0, since, 0.85 * fade)
	else:
		funnel(s, 3, 4.0, 12.0, 14.0, since, 0.85 * fade)
	for i in 14:                                                    # grains orbit the zone
		var a3 := since * lerpf(1.0, 2.0, jit(i, 1.0)) + jit(i) * TAU
		s.draw_circle(Vector2.from_angle(a3) * r * lerpf(0.3, 0.95, jit(i, 2.0)), 1.5 if tier < 3 or i % 3 != 0 else 2.0, Color(DUST if i % 3 != 0 else SAND_BRIGHT, 0.9 * fade))

# ---------------------------------------------------------------- Blizzard

const SNOW := Color(0.9, 0.97, 1.0)
const BLIZ_ICE := Color(0.6, 0.85, 1.0)
const STORM := Color(0.35, 0.5, 0.75)

static func draw_blizzard(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	s.draw_arc(Vector2.ZERO, r * 0.94, 0, TAU, 40, Color(STORM, 0.6 * fade), 1.0)       # a second, icy rim
	if tier >= 3:                                                   # the sky darkens
		s.draw_circle(Vector2.ZERO, r * 0.85, Color(STORM, 0.1 * fade))
	if tier >= 4:                                                   # storm clouds, and a flicker when lightning falls
		var n_clouds := 8 if tier >= 5 else 4
		for i in n_clouds:
			var cp := Vector2(sin(since * 0.3 + i * 1.7) * r * 0.6, -r * 0.45 + cos(since * 0.2 + i) * r * 0.15)
			s.draw_circle(cp, 14.0 + 6.0 * jit(i), Color(STORM, 0.18 * fade))
		if fposmod(since, 1.5) < 0.1:
			s.draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.15 * fade))
	# tier 2: falling snow (more and wilder at tier 6)
	var flakes := 60 if tier >= 6 else 28
	var speed := 70.0 if tier >= 6 else 40.0
	for i in flakes:
		var y := fposmod(since * speed + jit(i) * r * 2.0, r * 2.0) - r
		var x := (jit(i, 1.0) - 0.5) * r * 1.9 + sin(since + i) * 4.0
		if Vector2(x, y).length() < r:
			var p := Vector2(x, y)
			s.draw_line(p, p + Vector2(-2.0, -4.0), Color(SNOW, 0.8 * fade), 1.5)
	if tier >= 3:                                                   # hail falls faster and bounces
		for i in 6:
			var u := fposmod(since * 1.5 + jit(i, 5.0), 1.0)
			var hp := Vector2((jit(i, 6.0) - 0.5) * r * 1.4, lerpf(-r * 0.7, r * 0.3, u) * 1.0)
			if Vector2(hp.x, 0).length() < r:
				s.draw_circle(hp, 2.0, Color(1, 1, 1, 0.9 * fade))
				s.draw_circle(hp + Vector2(-0.5, -0.5), 0.8, Color(0.7, 0.85, 1.0, fade))
				if u > 0.9:
					s.draw_arc(hp, 5.0, 0, TAU, 8, Color(SNOW, 0.6 * fade), 1.0)
	if tier >= 5 and s.drift != Vector2.ZERO:                       # chevrons show the drift; a cone of flakes trails behind
		for i in 3:
			var cp2: Vector2 = s.drift * (r * 0.3 + i * 10.0)
			var o: Vector2 = s.drift.orthogonal()
			s.draw_polyline(PackedVector2Array([cp2 - s.drift * 4.0 + o * 4.0, cp2 + s.drift * 3.0, cp2 - s.drift * 4.0 - o * 4.0]), Color(SNOW, 0.8 * fade), 2.0)
		for i in 10:
			var u2 := fposmod(since * 0.5 + i / 10.0, 1.0)
			s.draw_circle(-s.drift * (r * 0.9 + u2 * 30.0) + s.drift.orthogonal() * (jit(i, 3.0) - 0.5) * 24.0 * u2, 1.5, Color(SNOW, 0.7 * (1.0 - u2) * fade))
		s.draw_arc(Vector2.ZERO, r, since * 0.4, since * 0.4 + 1.6, 16, Color(0.4, 1.0, 1.0, 0.6 * fade), 2.0)
		s.draw_arc(Vector2.ZERO, r, since * 0.4 + 1.6, since * 0.4 + 2.6, 16, Color(0.6, 0.4, 1.0, 0.6 * fade), 2.0)
	if tier >= 6:                                                   # a turning eye, aurora, a pillar of light, and a crust of ice at the end
		for i in 10:
			var a := since * 2.0 + i * TAU / 10.0
			var p2 := Vector2.from_angle(a) * r * 0.25
			var d := Vector2.from_angle(a + PI / 2.0)
			s.draw_polyline(PackedVector2Array([p2 - d * 3.0 - Vector2.from_angle(a) * 2.0, p2 + Vector2.from_angle(a) * 2.0, p2 + d * 3.0 - Vector2.from_angle(a) * 2.0]), Color(SNOW, 0.8 * fade), 1.5)
		s.draw_rect(Rect2(-4, -r * 0.6, 8, r * 0.6), Color(BLIZ_ICE, 0.15 * fade))
		var left: float = life - since
		if left < 1.0 and left > 0.0:
			var t := 1.0 - left
			s.draw_arc(Vector2.ZERO, r * (1.0 - 0.25 * t), 0, TAU, 40, Color(BLIZ_ICE, 0.25), r * 0.5 * t)

# ---------------------------------------------------------------- Lava Pool

const LAVA := Color(1.0, 0.4, 0.1)
const LAVA_GLOW := Color(1.0, 0.75, 0.25)
const CRUST := Color(0.25, 0.1, 0.08)
const WHITE_HOT := Color(1.0, 0.95, 0.7)

static func draw_lava_pool(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	var left: float = life - since
	if tier >= 5:                                                   # a brighter inner pool and three vents that glow before they erupt
		s.draw_circle(Vector2.ZERO, r * 0.6, Color(LAVA_GLOW, 0.2 * fade))
		var soon := fposmod(since, 2.5) > 2.1
		for i in 3:
			var vp := Vector2.from_angle(SpellTiers.vent_angle(i)) * r * 0.5
			if soon:
				vp += Vector2(sin(since * 60.0 + i), cos(since * 50.0)) * 1.2
			s.draw_circle(vp, 4.5, Color(LAVA, 0.9 * fade) if !soon else Color(WHITE_HOT, fade))
			s.draw_circle(vp, 3.0, Color(CRUST, fade))
	# tier 2: a broken dark crust on the rim, bubbles that swell and pop
	for i in 5:
		var a := i * TAU / 5.0 + 0.2
		s.draw_arc(Vector2.ZERO, r * 0.95, a, a + 0.9, 8, Color(CRUST, 0.85 * fade), r * 0.1)
	for i in 5:
		var u := fposmod(since / 1.2 + jit(i), 1.0)
		var bp := Vector2.from_angle(jit(i, 1.0) * TAU) * r * 0.6 * jit(i, 2.0)
		s.draw_circle(bp, lerpf(0.5, 4.0, u), Color(LAVA_GLOW, 0.85 * fade))
		if u > 0.92:
			s.draw_arc(bp, 6.0, 0, TAU, 8, Color(LAVA_GLOW, 0.6 * fade), 1.0)
	if tier >= 3:                                                   # flowing streaks and heat shimmer
		for i in 5:
			var a2 := since * 0.4 + i * TAU / 5.0
			s.draw_arc(Vector2.ZERO, r * (0.35 + 0.1 * i), a2, a2 + 0.6, 6, Color(WHITE_HOT, 0.4 * fade), 1.5)
		for k in 3:
			var pts := PackedVector2Array()
			for j in 17:
				var ang := j * TAU / 16.0
				pts.append(Vector2.from_angle(ang) * (r * (1.05 + 0.04 * k) + sin(ang * 6.0 + since * 3.0 + k) * 2.0))
			s.draw_polyline(pts, Color(LAVA_GLOW, 0.25 * fade), 1.0)
	if tier >= 4:                                                   # a crater lip with jagged rocks, ash flecks rising
		s.draw_arc(Vector2.ZERO, r * 1.0, 0, TAU, 40, Color(CRUST, 0.9 * fade), 3.0)
		for i in 8:
			var n := Vector2.from_angle(i * TAU / 8.0)
			var b := n * r
			s.draw_colored_polygon(PackedVector2Array([b + n.orthogonal() * 4.0, b + n * 7.0, b - n.orthogonal() * 4.0]), Color(CRUST, fade))
		for i in 10:
			var u2 := fposmod(since * 0.4 + jit(i, 6.0), 1.0)
			s.draw_circle(Vector2.from_angle(jit(i, 7.0) * TAU) * r * 0.7 * jit(i, 8.0) + Vector2(0, -u2 * 22.0), 1.2, Color(CRUST.lightened(0.2), 0.8 * (1.0 - u2) * fade))
	if tier >= 6:                                                   # the pool bulges into a volcano, ringed with rocks, whitening at the end
		for i in 10:
			var rp := Vector2.from_angle(i * TAU / 10.0 + 0.15) * r * 1.08
			s.draw_circle(rp, 3.5, Color.BLACK)
			s.draw_circle(rp, 2.7, Color(CRUST.lightened(0.15), fade))
		var cone := PackedVector2Array([Vector2(-r * 0.4, 6), Vector2(-r * 0.12, -r * 0.35), Vector2(r * 0.12, -r * 0.35), Vector2(r * 0.4, 6)])
		s.draw_colored_polygon(cone, Color(CRUST, 0.95 * fade))
		for i in 6:
			var cx := lerpf(-r * 0.3, r * 0.3, i / 5.0)
			s.draw_line(Vector2(cx * 0.4, -r * 0.3), Vector2(cx, 4), Color(LAVA_GLOW, 0.7 * fade), 1.0)
		s.draw_circle(Vector2(0, -r * 0.35), r * 0.1, Color(WHITE_HOT, fade))
		for i in 6:
			var u3 := fposmod(since * 0.3 + i / 6.0, 1.0)
			s.draw_circle(Vector2(sin(since + i * 2.0) * 6.0, -r * 0.4 - u3 * 28.0), 3.0 + 2.0 * u3, Color(0.5, 0.5, 0.5, 0.35 * (1.0 - u3) * fade))
		if left < 1.0 and left > 0.0:
			s.draw_circle(Vector2.ZERO, r, Color(WHITE_HOT, 0.4 * (1.0 - left)))

# ---------------------------------------------------------------- Poison Cloud

const TOXIC := Color(0.5, 0.9, 0.3)
const TOXIC_DEEP := Color(0.2, 0.45, 0.15)
const SPORE := Color(0.8, 1.0, 0.5)
const ROT := Color(0.55, 0.3, 0.6)

static func draw_poison_cloud(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	if tier >= 5:                                                   # a green aura
		s.draw_circle(Vector2.ZERO, r * 1.05, Color(TOXIC, 0.08 * fade))
	if tier >= 3:                                                   # a dirty purple inner layer
		s.draw_circle(Vector2.ZERO, r * 0.65, Color(ROT, 0.12 * fade))
	if tier >= 4:                                                   # thicker: soft clouds rolling through, a darker rim
		for i in 7:
			var cp := Vector2(sin(since * 0.3 + i * 1.3), cos(since * 0.25 + i * 2.1)) * r * 0.55
			s.draw_circle(cp, 10.0 + 8.0 * jit(i, 2.0), Color(TOXIC_DEEP, 0.14 * fade))
		s.draw_arc(Vector2.ZERO, r * 0.95, 0, TAU, 40, Color(TOXIC_DEEP, 0.7 * fade), 2.0)
	if tier >= 6:                                                   # a plague cloud: a gradient, a dashed ring, flickering plague-lights
		s.draw_circle(Vector2.ZERO, r * 0.8, Color(ROT, 0.1 * fade))
		for i in 24:
			var a := since * 0.3 + i * TAU / 24.0
			s.draw_arc(Vector2.ZERO, r * 1.03, a, a + 0.12, 3, Color(ROT, 0.8 * fade), 1.5)
		for i in 6:
			var fl := 0.5 + 0.5 * sin(since * 6.0 + i * 2.0)
			s.draw_circle(Vector2.from_angle(jit(i, 9.0) * TAU) * r * 0.6 * jit(i, 10.0), 4.0, Color(ROT, 0.4 * fl * fade))
	# tier 2: drifting wisps, floating spores, a rotating trefoil
	for i in 6:
		var a2 := since * 0.3 + i * TAU / 6.0
		var rr := r * lerpf(0.3, 0.8, jit(i, 1.0))
		var p0 := Vector2.from_angle(a2) * rr
		var p1 := Vector2.from_angle(a2 + 0.5) * rr * 1.1 + Vector2(0, -4)
		var p2 := Vector2.from_angle(a2 + 1.0) * rr * 0.95
		s.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(SPORE, 0.25 * fade), 3.0)
	var spores := 32 if tier >= 6 else 16
	for i in spores:
		var u := fposmod(since * 0.3 + jit(i), 1.0)
		var dir := Vector2.from_angle(jit(i, 2.0) * TAU)
		s.draw_circle(dir * r * (0.2 + 0.7 * u) + Vector2(0, -u * 12.0), 1.5, Color(SPORE, 0.9 * (1.0 - u) * fade))
	if tier >= 6:
		for k in 3:
			var ang := since * 0.5 + k * TAU / 3.0
			s.draw_arc(Vector2.ZERO, 14.0, ang, ang + deg_to_rad(100.0), 8, Color(TOXIC_DEEP, 0.9 * fade), 4.0)
			s.draw_circle(Vector2.from_angle(ang + 0.9) * 14.0, 3.0, Color(ROT, fade))
	elif tier >= 3:
		for k in 3:
			var ang2 := since * 0.5 + k * TAU / 3.0
			s.draw_circle(Vector2.from_angle(ang2) * 7.0, 3.0, Color(TOXIC_DEEP, 0.9 * fade))
			s.draw_arc(Vector2.ZERO, 7.0, ang2, ang2 + 0.8, 5, Color(TOXIC, fade), 1.5)
	else:
		for k in 3:
			var ang3 := since * 0.4 + k * TAU / 3.0
			s.draw_arc(Vector2.ZERO, 7.0, ang3, ang3 + deg_to_rad(100.0), 8, Color(TOXIC_DEEP, 0.9 * fade), 2.0)
	if tier >= 5:                                                   # three spore pods grow, then burst
		for i in 3:
			var g: float = fposmod(since - i * SpellTiers.POISON_POD / 3.0, SpellTiers.POISON_POD) / SpellTiers.POISON_POD
			var pp := Vector2.from_angle(jit(i, 5.0) * TAU) * r * 0.35
			var h: float = 3.0 + 6.0 * g
			s.draw_rect(Rect2(pp.x - 1.0, pp.y - h, 2.0, h), Color(TOXIC_DEEP, fade))
			var cap: float = 2.5 + 4.0 * g
			s.draw_circle(pp + Vector2(0, -h), cap, Color(TOXIC_DEEP.lightened(0.1), 0.95 * fade))
			s.draw_circle(pp + Vector2(-1.5, -h - 1.0), 0.8, Color(SPORE, fade))
			s.draw_circle(pp + Vector2(1.5, -h), 0.8, Color(SPORE, fade))

# ---------------------------------------------------------------- Crystal Spikes

const AMETHYST := Color(0.8, 0.6, 1.0)
const AMETHYST_DEEP := Color(0.45, 0.25, 0.75)
const CRYSTAL_WHITE := Color(0.95, 0.9, 1.0)

## A crystal prism rising out of the ground: three facets (dark left, amethyst middle, white right) and a black outline.
static func crystal(s, base: Vector2, w: float, h: float, alpha: float, tint := Color(0, 0, 0, 0)) -> void:
	if h < 1.0:
		return
	var mid := AMETHYST if tint.a == 0.0 else tint
	var top := base + Vector2(0, -h)
	var l0 := base + Vector2(-w / 2.0, 0)
	var l1 := base + Vector2(-w / 2.0, -h * 0.7)
	var r1 := base + Vector2(w / 2.0, -h * 0.7)
	var r0 := base + Vector2(w / 2.0, 0)
	s.draw_polyline(PackedVector2Array([l0, l1, top, r1, r0, l0]), Color(0, 0, 0, alpha), 3.0)
	s.draw_colored_polygon(PackedVector2Array([l0, l1, top, base + Vector2(-w / 6.0, 0)]), Color(AMETHYST_DEEP, alpha))
	s.draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 6.0, 0), top, base + Vector2(w / 6.0, 0)]), Color(mid, alpha))
	s.draw_colored_polygon(PackedVector2Array([base + Vector2(w / 6.0, 0), top, r1, r0]), Color(CRYSTAL_WHITE, alpha))

static func draw_crystal_spikes(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var life: float = s.effect_time
	var fade := clampf((life - since) / 0.5, 0.0, 1.0)
	var spots := []
	for i in 3:
		spots.append(Vector2.from_angle(i * TAU / 3.0 - PI / 2.0) * 22.0)
	if tier >= 6:                                                   # a rainbow glow, and a flower of prisms at the centre
		var growth := clampf((since - 0.6) / 0.6, 0.0, 1.0)
		s.draw_circle(Vector2.ZERO, s.radius * 1.2, Color.from_hsv(fposmod(since * 0.2, 1.0), 0.3, 1.0, 0.18 * fade * growth))
		var hs := [34.0, 28.0, 28.0, 24.0, 24.0, 20.0, 20.0]
		var order := [0, 1, 2, 3, 4, 5, 6]
		for k in order:
			var ang := lerpf(-50.0, 50.0, k / 6.0)
			crystal(s, Vector2(sin(deg_to_rad(ang)) * 12.0, 4.0), 8.0, hs[k] * growth, fade, Color.from_hsv(fposmod(since * 0.3 + k * 0.1, 1.0), 0.35, 1.0))
		for i in 12:
			var tw := 0.5 + 0.5 * sin(since * 5.0 + i)
			s.draw_circle(Vector2.from_angle(jit(i, 4.0) * TAU) * s.radius * 1.1 * jit(i, 5.0), 1.5, Color(1, 1, 1, tw * fade * growth))
	if tier >= 4:                                                   # three fissures run outward, with smaller crystals along them
		for i in 3:
			var d: Vector2 = spots[i].normalized()
			var pts := PackedVector2Array([spots[i]])
			for k in range(1, 8):
				var u := k / 7.0
				pts.append(spots[i] + d * 70.0 * u + d.orthogonal() * (jit(k + i * 7, 2.0) - 0.5) * 8.0)
			var shown := clampf((since - SpellTiers.SPIKE_DELAYS[i]) / 0.45, 0.0, 1.0)
			var n := int(shown * 7.0) + 1
			s.draw_polyline(pts.slice(0, n), Color(AMETHYST_DEEP, 0.9 * fade), 3.0)
			s.draw_polyline(pts.slice(0, n), Color(1, 1, 1, 0.5 * fade), 1.0)
			var hs2 := [16.0, 12.0, 9.0]
			for k in 3:
				if shown > (k + 1) / 4.0:
					crystal(s, spots[i] + d * 26.0 * (k + 1), 6.0, hs2[k], fade)
	if tier >= 5:                                                   # three beams link the crystals, a prism floats above each
		for i in 3:
			var a: Vector2 = spots[i]
			var b: Vector2 = spots[(i + 1) % 3]
			var pulse := 0.6 + 0.4 * sin(since * 6.0 + i)
			s.draw_line(a + Vector2(0, -8), b + Vector2(0, -8), Color(CRYSTAL_WHITE, 0.25 * fade * pulse), 3.0)
			s.draw_line(a + Vector2(0, -8), b + Vector2(0, -8), Color(1, 1, 1, 0.9 * fade), 1.0)
	# tier 2: the three big crystals (and the small ones that grow between them from tier 3)
	for i in 3:
		var h := clampf((since - SpellTiers.SPIKE_DELAYS[i]) / 0.15, 0.0, 1.0) * (18.0 + 2.0 * i)
		var hum := 0.85 + 0.15 * sin(since * 3.0 + i) if tier >= 3 else 1.0
		var base: Vector2 = spots[i]
		var tint := Color.from_hsv(fposmod(since * 0.3 + i * 0.33, 1.0), 0.35, 1.0) if tier >= 5 else Color(0, 0, 0, 0)
		for k in 3:
			var a2 := i * 2.0 + k * 2.1
			s.draw_line(base, base + Vector2.from_angle(a2) * 7.0, Color(AMETHYST_DEEP, 0.7 * fade), 1.0)
		crystal(s, base, 8.0, h, hum * fade, tint)
		if tier >= 3 and h > 0.0:
			var gl := fposmod(since / 1.2 + i * 0.3, 1.0)
			if gl < 0.25:
				var gp := base + Vector2(0, -h * 0.6)
				for q in 4:
					var dd := Vector2.from_angle(q * PI / 4.0)
					s.draw_line(gp - dd * 3.0, gp + dd * 3.0, Color(0.85, 1.0, 1.0, fade), 1.0)
		if tier >= 5:
			var pp := base + Vector2(0, -h - 8.0)
			var col5 := Color.from_hsv(fposmod(since * 0.3 + i * 0.33, 1.0), 0.35, 1.0)
			var sq := absf(cos(since * 2.0 + i)) * 5.0 + 1.0
			s.draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -4), pp + Vector2(sq, 0), pp + Vector2(0, 4), pp + Vector2(-sq, 0)]), Color(col5, fade))
	if tier >= 3:
		for i in 4:
			var grow := clampf((since - 0.5) / 0.4, 0.0, 1.0)
			var a3 := (i + 0.5) * TAU / 4.0 - PI / 2.0 + 0.5
			crystal(s, Vector2.from_angle(a3) * 14.0, 5.0, (8.0 + 3.0 * jit(i, 3.0)) * grow, fade)

# ---------------------------------------------------------------- Meteor Shower

const METEOR_FIRE := Color(1.0, 0.5, 0.15)
const METEOR_HOT := Color(1.0, 0.85, 0.4)
const METEOR_SMOKE := Color(0.25, 0.18, 0.15)

static func draw_meteor_shower(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var dur: float = s.data.get("duration", 3.5)
	var fade := clampf((life - since) / 0.6, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	if tier >= 5:                                                   # a redder sky and a ring of heat flares
		s.draw_circle(Vector2.ZERO, r, Color(METEOR_FIRE, 0.12 * fade))
		for i in 12:
			var a := since * 0.3 + i * TAU / 12.0
			s.draw_circle(Vector2.from_angle(a) * r, 3.0 + 2.0 * sin(since * 4.0 + i), Color(METEOR_HOT, 0.6 * fade))
	if tier >= 6:                                                   # a firestorm: a dark vortex ring turns over the zone
		for i in 28:
			var a2 := since * 0.4 + i * TAU / 28.0
			s.draw_arc(Vector2.ZERO, r * 0.9, a2, a2 + 0.14, 3, Color(0.5, 0.1, 0.08, 0.7 * fade), 3.0)
	# tier 2: a smouldering sky and falling embers
	var layers := 2 if tier >= 6 else 1
	for l in layers:
		for i in 7:
			var cp := Vector2(sin(since * 0.3 + i * 1.7 + l), cos(since * 0.2 + i * 2.3 + l * 2.0)) * r * 0.6
			s.draw_circle(cp, 14.0 + 8.0 * jit(i + l * 7, 1.0), Color(0.5, 0.1, 0.08, 0.16 * fade))
	var embers := 40 if tier >= 6 else 18
	for i in embers:
		var u := fposmod(since * 0.6 + jit(i), 1.0)
		var p := Vector2((jit(i, 1.0) - 0.5) * r * 1.8, lerpf(-r * 0.8, r * 0.6, u))
		if p.length() < r:
			s.draw_circle(p, 1.4, Color(METEOR_HOT, 0.9 * sin(u * PI) * fade))
	# the craters each meteor leaves: a scorched patch with a glowing heart, fading over 2.5 s
	for i in s.spots.size():
		var landed_at: float = SpellTiers.meteor_launch(s, i) + SpellTiers.meteor_fall_time(tier, i)
		var age := since - landed_at
		if age < 0.0 or age > 2.5:
			continue
		var k := 1.0 - age / 2.5
		var cr := 24.0 if SpellTiers.is_boulder(tier, i) else 14.0
		var sp: Vector2 = s.spots[i] - s.position
		s.draw_set_transform(sp, 0.0, Vector2(1.0, 0.6))
		s.draw_circle(Vector2.ZERO, cr, Color(0.1, 0.05, 0.04, 0.35 * k))
		s.draw_circle(Vector2.ZERO, cr * 0.35, Color(METEOR_FIRE, 0.6 * k))
		s.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tier >= 6 and since > dur and since < dur + 2.0:              # a crosshair of three rings closes in on the centre
		var cl := clampf((since - dur) / 1.2, 0.0, 1.0)
		for k2 in 3:
			var rr := r * lerpf(0.3 + 0.25 * k2, 0.05 + 0.05 * k2, cl)
			s.draw_arc(Vector2.ZERO, rr, 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.8 * fade), 2.0)
		s.draw_line(Vector2(-r * 0.9, 0), Vector2(r * 0.9, 0), Color(1.0, 0.3, 0.2, 0.4 * fade), 1.0)
		s.draw_line(Vector2(0, -r * 0.9), Vector2(0, r * 0.9), Color(1.0, 0.3, 0.2, 0.4 * fade), 1.0)

# ---------------------------------------------------------------- Stasis Field

const TIME := Color(0.75, 0.9, 1.0)
const BRASS := Color(1.0, 0.85, 0.45)
const VIOLET := Color(0.4, 0.3, 0.7)
const STAR := Color(0.95, 0.97, 1.0)

## A gear: a ring of teeth.
static func cog(s, c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := rot + i * TAU / 20.0
		pts.append(c + Vector2.from_angle(a) * (r if (i / 1) % 2 == 0 else r * 0.75))
	pts.append(pts[0])
	s.draw_polyline(pts, col, 1.5)
	s.draw_arc(c, r * 0.35, 0, TAU, 10, col, 1.0)

static func draw_stasis(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.3, 0.0, 1.0)
	var left: float = life - since
	var rew := fposmod(since, SpellTiers.STASIS_REWIND_T)
	var fast := tier >= 5 and rew < 0.4
	var hand_spin := -since * 0.5 - (rew * 12.0 if fast else 0.0) - (floorf(since / SpellTiers.STASIS_REWIND_T) * 4.8 if tier >= 5 else 0.0)
	if tier >= 6:                                                   # an astrolabe: nested rings, planets, a violet starfield, a golden sun
		for k in 3:
			var rr: float = r * [0.35, 0.6, 0.95][k]
			s.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(BRASS, 0.6 * fade), 1.5)
			for i in 24:
				var a := i * TAU / 24.0 + (k * 0.2)
				s.draw_line(Vector2.from_angle(a) * rr, Vector2.from_angle(a) * (rr - (6.0 if i % 6 == 0 else 3.0)), Color(BRASS, 0.7 * fade), 1.0)
		for i in 3:
			s.draw_circle(Vector2.from_angle(since * (0.3 + 0.2 * i) + i * 2.0) * r * (0.35 + 0.25 * i), 3.0, Color(STAR, fade))
		for i in 22:
			var tw := 0.5 + 0.5 * sin(since * 3.0 + i * 1.3)
			s.draw_circle(Vector2.from_angle(jit(i, 2.0) * TAU) * r * 0.9 * sqrt(jit(i, 3.0)), 1.3, Color(VIOLET.lightened(0.4), 0.8 * tw * fade))
		s.draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.4, fade))
		s.draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.9, 0.4, 0.3 * fade))
		if left < 1.0 and left > 0.0:                               # the disc cracks at the end
			var g := 1.0 - left
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10.0 + jit(i, 5.0) * 0.3)
				s.draw_line(Vector2.ZERO, d * r * g, Color(1, 1, 1, 0.9), 1.5)
	if tier >= 5:                                                   # zodiac rings: glyph squares one way, moons the other
		for i in 12:
			var a2 := -since * 0.2 + i * TAU / 12.0
			var p := Vector2.from_angle(a2) * r * 0.92
			s.draw_rect(Rect2(p.x - 2.5, p.y - 2.5, 5.0, 5.0), Color(BRASS, 0.8 * fade))
		for i in 8:
			var a3 := since * 0.25 + i * TAU / 8.0
			var p2 := Vector2.from_angle(a3) * r * 0.75
			s.draw_arc(p2, 3.0, a3 + 0.5, a3 + 0.5 + PI * 1.4, 8, Color(STAR, 0.8 * fade), 1.5)
		for e in s.get_tree().get_nodes_in_group("enemy"):          # blue afterimages trail behind the frozen, back toward where they came from
			if is_instance_valid(e) and e.global_position.distance_to(s.global_position) <= r and !(e.is_in_group("boss") and false):
				var away: Vector2 = (e.global_position - Game.crystal_position()).normalized()
				for k in 3:
					s.draw_circle(e.global_position - s.global_position + away * (8.0 * (k + 1)), 6.0 - k, Color(0.5, 0.7, 1.0, 0.25 * fade))
	if tier >= 4:                                                   # a crystal hourglass, and a hex frame with cracks on each frozen enemy
		var flip: float = fposmod(since, 5.0) / 5.0
		var top := Vector2(0, -14)
		var bot := Vector2(0, 14)
		s.draw_colored_polygon(PackedVector2Array([top + Vector2(-9, 0), top + Vector2(9, 0), Vector2(0, 0)]), Color(TIME, 0.4 * fade))
		s.draw_colored_polygon(PackedVector2Array([bot + Vector2(-9, 0), bot + Vector2(9, 0), Vector2(0, 0)]), Color(TIME, 0.4 * fade))
		s.draw_line(top + Vector2(-11, 0), top + Vector2(11, 0), Color(BRASS, fade), 2.0)
		s.draw_line(bot + Vector2(-11, 0), bot + Vector2(11, 0), Color(BRASS, fade), 2.0)
		for i in 6:
			var u := fposmod(since * 1.2 + i / 6.0, 1.0)
			s.draw_circle(Vector2(0, lerpf(-12.0, 12.0, u)) * (1.0 if int(since / 5.0) % 2 == 0 else -1.0), 1.0, Color(BRASS, 0.9 * fade))
		var n := 0
		for e in s.get_tree().get_nodes_in_group("enemy"):
			if n >= 24:
				break
			if is_instance_valid(e) and e.global_position.distance_to(s.global_position) <= r:
				n += 1
				var ep: Vector2 = e.global_position - s.global_position
				var hex := PackedVector2Array()
				for k in 7:
					hex.append(ep + Vector2.from_angle(k * TAU / 6.0) * 8.0)
				s.draw_polyline(hex, Color(TIME, 0.8 * fade), 1.0)
				for k in 6:
					var dd := Vector2.from_angle(k * TAU / 6.0 + 0.3)
					s.draw_line(ep, ep + dd * 9.0, Color(1, 1, 1, 0.3 * fade), 1.0)
	if tier >= 3:                                                   # two cogs turn against each other, the floor cracks, sand rises
		cog(s, Vector2(r * 0.55, 0) * 0.707 + Vector2(0, r * 0.1), 12.0, since * 0.5, Color(BRASS, 0.8 * fade))
		cog(s, Vector2(-r * 0.55, 0) * 0.707 + Vector2(0, -r * 0.1), 16.0, -since * 0.5, Color(BRASS, 0.8 * fade))
		for i in 6:
			var d2 := Vector2.from_angle(i * TAU / 6.0 + 0.4)
			s.draw_line(d2 * r * 0.2, d2 * r * 0.85, Color(STAR, 0.3 * fade), 1.0)
		for i in 10:
			var u2 := fposmod(since * 0.3 + jit(i), 1.0)
			s.draw_circle(Vector2.from_angle(jit(i, 2.0) * TAU) * r * 0.8 * jit(i, 3.0) + Vector2(0, -u2 * 20.0), 1.2, Color(BRASS, 0.8 * (1.0 - u2) * fade))
	# tier 2: a clock face with hands that run backwards, and a ring round every shot held in the air
	for i in 12:
		var a4 := i * TAU / 12.0 - PI / 2.0
		var len := 10.0 if i % 3 == 0 else 5.0
		s.draw_line(Vector2.from_angle(a4) * r, Vector2.from_angle(a4) * (r - len), Color(BRASS, 0.9 * fade), 2.0 if i % 3 == 0 else 1.0)
	s.draw_line(Vector2.ZERO, Vector2.from_angle(hand_spin - PI / 2.0) * r * 0.7, Color(BRASS, 0.9 * fade), 2.0)
	s.draw_line(Vector2.ZERO, Vector2.from_angle(hand_spin * 0.08 - PI / 2.0) * r * 0.45, Color(BRASS, 0.9 * fade), 3.0)
	for sh in s.get_tree().get_nodes_in_group("enemy_shot"):
		if is_instance_valid(sh) and sh.global_position.distance_to(s.global_position) <= r and sh.has_meta("held_by"):
			s.draw_arc(sh.global_position - s.global_position, 8.0, 0, TAU, 12, Color(STAR, 0.8 * fade), 1.0)

# ---------------------------------------------------------------- Mass Conversion

const MIND := Color(0.55, 0.9, 1.0)
const MIND_VIOLET := Color(0.55, 0.4, 0.95)
const MC_GOLD := Color(1.0, 0.85, 0.4)

static func crown(canvas, p: Vector2, col: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 4), p + Vector2(-5, -3), p + Vector2(-2.5, 0), p + Vector2(0, -5), p + Vector2(2.5, 0), p + Vector2(5, -3), p + Vector2(5, 4)]), col)

## A banner on a pole: a waving flag with an eye, a gold finial.
static func banner(s, pole_h: float, fw: float, fh: float, since: float, alpha: float, flames: bool) -> void:
	s.draw_rect(Rect2(-1.0, -pole_h, 2.0, pole_h), Color(0.3, 0.25, 0.4, alpha))
	var wave := sin(since * 4.0) * 2.0
	var top := Vector2(1.0, -pole_h)
	var pts := PackedVector2Array([top, top + Vector2(fw * 0.5, wave), top + Vector2(fw, 0), top + Vector2(fw, fh), top + Vector2(fw * 0.5, fh + wave), top + Vector2(0, fh)])
	s.draw_colored_polygon(pts, Color(MIND, 0.9 * alpha))
	var ec := top + Vector2(fw * 0.5, fh * 0.5 + wave * 0.5)
	s.draw_arc(ec, fh * 0.28, 0, TAU, 12, Color(MIND_VIOLET, alpha), 1.5)
	s.draw_circle(ec, fh * 0.12, Color(MIND_VIOLET, alpha))
	s.draw_circle(top + Vector2(0, -2), 2.0, Color(MC_GOLD, alpha))
	if flames:
		for i in 8:
			var fx := top.x + fw * (i + 0.5) / 8.0
			var fl := 2.0 + 2.0 * sin(since * 9.0 + i)
			s.draw_colored_polygon(PackedVector2Array([Vector2(fx - 1.5, top.y + fh * 0.1), Vector2(fx, top.y - 3.0 - fl), Vector2(fx + 1.5, top.y + fh * 0.1)]), Color(MIND, 0.8 * alpha))

static func draw_mass_conversion(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var fade := clampf((life - since) / 1.0, 0.0, 1.0) * clampf(since / 0.2, 0.0, 1.0)
	if tier >= 6:                                                   # a dome of three rings with turning runes, a starfield, a column of mind light
		for k in 3:
			s.draw_arc(Vector2.ZERO, r * [0.4, 0.7, 1.0][k], 0, TAU, 40, Color(MIND_VIOLET, 0.35 * fade), 2.0)
		for i in 12:
			var a := since * 0.3 + i * TAU / 12.0
			var gp := Vector2.from_angle(a) * r * 0.85
			s.draw_rect(Rect2(gp.x - 2.0, gp.y - 2.0, 4.0, 4.0), Color(MIND, 0.8 * fade))
		for i in 20:
			s.draw_circle(Vector2.from_angle(jit(i, 2.0) * TAU) * r * 0.95 * sqrt(jit(i, 3.0)), 1.2, Color(1, 1, 1, (0.4 + 0.4 * sin(since * 3.0 + i)) * fade))
		s.draw_rect(Rect2(-6, -r * 0.9, 12, r * 0.9), Color(MIND, 0.12 * fade))
		for i in 8:
			var sa := since * 0.8 + i * TAU / 8.0
			var sp := Vector2.from_angle(sa) * 22.0 + Vector2(0, -20)
			var d := Vector2.from_angle(sa)
			s.draw_colored_polygon(PackedVector2Array([sp - d * 4.0 + d.orthogonal() * 1.5, sp + d * 5.0, sp - d * 4.0 - d.orthogonal() * 1.5]), Color(0.95, 0.98, 1.0, 0.9 * fade))
	if tier >= 3:                                                   # the banner, and a faint ring round it
		for i in 24:
			var a2 := i * TAU / 24.0
			s.draw_arc(Vector2.ZERO, r * 0.9, a2, a2 + 0.1, 3, Color(MIND, 0.25 * fade), 1.0)
		if tier >= 6:
			banner(s, 36.0, 28.0, 16.0, since, fade, true)
		elif tier >= 4:
			banner(s, 26.0, 20.0, 12.0, since, fade, true)
		else:
			banner(s, 26.0, 14.0, 9.0, since, fade, false)
		var glow := 0.5 + 0.5 * sin(since * PI)
		s.draw_circle(Vector2(0, -26), 8.0, Color(MIND, 0.15 * glow * fade))
	if tier >= 4 and fposmod(since, 5.0) < 1.0:                     # the war cry: runes expand from the banner
		var u := fposmod(since, 5.0)
		for i in 8:
			var p := Vector2.from_angle(i * TAU / 8.0) * r * u
			s.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)]), Color(MIND, 0.9 * (1.0 - u) * fade))
	# tier 2: a mind-eye at the centre for a moment after landing
	if since < 1.0 and tier < 3:
		var open := absf(cos(since * 6.0)) * 0.6 + 0.4
		for sd in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 9:
				var u2 := i / 8.0
				pts.append(Vector2(lerpf(-14.0, 14.0, u2), sd * sin(u2 * PI) * 7.0 * open))
			s.draw_polyline(pts, Color(MIND_VIOLET, fade), 1.5)
		s.draw_circle(Vector2.ZERO, 4.0 * open, Color(MIND_VIOLET, fade))
		s.draw_circle(Vector2.ZERO, 2.0, Color.BLACK)
	# the converts: a cyan ring under their feet (violet-gold for lieutenants), halos in a war cry, a crown on each lieutenant
	var n := 0
	var lts: Array = s.lieutenants
	for e in s.get_tree().get_nodes_in_group("enemy"):
		if n >= 40:
			break
		if !is_instance_valid(e) or e.get("charm_time") == null or e.charm_time <= 0.0 or e.global_position.distance_to(s.global_position) > r * 1.3 + 40.0:
			continue
		n += 1
		var ep: Vector2 = e.global_position - s.global_position
		var is_lt := false
		for l in lts:
			if (l - e.global_position).length() < 3.0:
				is_lt = true
		s.draw_arc(ep + Vector2(0, 6), 9.0, 0, TAU, 14, Color(MIND_VIOLET if is_lt else MIND, 0.8 * fade), 1.5)
		if is_lt:
			s.draw_arc(ep + Vector2(0, 6), 12.0, 0, TAU, 14, Color(MC_GOLD, 0.8 * fade), 1.5)
			crown(s, ep + Vector2(0, -22), MC_GOLD)
		if tier < 3 and since < 1.5:
			s.draw_colored_polygon(PackedVector2Array([ep + Vector2(-2, -12), ep + Vector2(0, -20 - 2.0 * sin(since * 10.0)), ep + Vector2(2, -12)]), Color(MIND, 0.9))
		if e.get("charm_power") != null and e.charm_power >= 2.0 and tier >= 4:
			s.draw_arc(ep, 14.0 + 2.0 * sin(since * 8.0), 0, TAU, 14, Color(MIND, 0.7 * fade), 1.5)
		if tier >= 3 and n <= 12:
			s.draw_line(Vector2.ZERO, ep, Color(MIND, 0.18 * fade), 1.0)

# ---------------------------------------------------------------- Frostfire

const FF_ICE := Color(0.7, 0.85, 1.0)
const FF_FIRE := Color(1.0, 0.5, 0.15)
const FF_STEAM := Color(0.9, 0.93, 1.0)
const FF_VIOLET := Color(0.75, 0.6, 1.0)

static func flight_frostfire(s, t: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var from_local: Vector2 = s.origin - s.position
	var p := from_local.lerp(Vector2.ZERO, t)
	var back := from_local.normalized() if from_local.length() > 1.0 else Vector2.UP
	var side := back.orthogonal()
	var n := 14 if tier >= 6 else (9 if tier >= 3 else 5)               # tails grow with the tier; the tier 6 comet is long and two-coloured
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var col := FF_ICE if k == 0 else FF_FIRE
		var ang: float = s.age * 8.0 + k * PI
		var head := p + side * sin(ang) * 3.0
		for i in n:
			var tt := i * (3.0 if tier < 3 else 4.0)
			s.draw_circle(p + back * tt + side * sin(ang - i * 0.5) * 3.0, maxf(0.6, 3.0 - i * 0.2), Color(col, 0.85 - i * 0.05))
		s.draw_circle(head, 3.5, col)
	if tier >= 6:
		s.draw_circle(p, 9.0, Color(FF_VIOLET, 0.3))

static func draw_frostfire(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var base_fade := clampf(1.0 - since / 0.4, 0.0, 1.0)
	var end_fade := clampf((life - since) / 0.4, 0.0, 1.0)
	# tier 2: left half blue, right half orange, a steam wisp at the wavy seam
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 17:
		var a := -PI / 2.0 + i * PI / 16.0
		right.append(Vector2.from_angle(a) * r)
		left.append(Vector2.from_angle(a + PI) * r)
	s.draw_colored_polygon(right, Color(FF_FIRE, 0.28 * base_fade))
	s.draw_colored_polygon(left, Color(FF_ICE, 0.28 * base_fade))
	var seam := PackedVector2Array()
	for i in 9:
		seam.append(Vector2(sin(since * 5.0 + i) * 3.0, lerpf(-r, r, i / 8.0)))
	s.draw_polyline(seam, Color(FF_STEAM, 0.7 * base_fade), 1.5)
	for k in 3:
		var u := fposmod(since * 1.0 + k / 3.0, 1.0)
		s.draw_arc(Vector2(0, -u * 12.0 - r * 0.2), 4.0 + k, PI * 0.2, PI * 1.6, 8, Color(1, 1, 1, 0.8 * (1.0 - u) * base_fade), 1.5)
	if tier >= 3:                                                   # eight glyphs, snowflakes and flames in turn, orbit the edge
		for i in 8:
			var gp := Vector2.from_angle(since * 1.0 + i * TAU / 8.0) * r
			if i % 2 == 0:
				for q in 3:
					var d := Vector2.from_angle(q * PI / 3.0)
					s.draw_line(gp - d * 3.0, gp + d * 3.0, Color(FF_ICE, 0.9 * end_fade * base_fade + 0.0), 1.0)
			else:
				s.draw_colored_polygon(PackedVector2Array([gp + Vector2(-2, 2), gp + Vector2(0, -4), gp + Vector2(2, 2)]), Color(FF_FIRE, 0.9 * base_fade))
	if tier >= 4 and since < 3.0:                                   # a steam cloud rolls over the disc
		var sf := clampf((3.0 - since) / 0.6, 0.0, 1.0)
		for i in 8:
			var cp := Vector2(sin(since * 0.6 + i * 1.7), cos(since * 0.5 + i * 2.3)) * r * 0.55
			s.draw_circle(cp, 8.0 + 6.0 * jit(i, 1.0), Color(1, 1, 1, 0.18 * sf))
		for i in 6:
			var u2 := fposmod(since * 0.7 + jit(i), 1.0)
			s.draw_circle(Vector2(-r * 0.5 + jit(i, 2.0) * r * 0.3, -u2 * 14.0 + r * 0.3), 1.2, Color(FF_ICE, 0.8 * (1.0 - u2) * sf))
			s.draw_circle(Vector2(r * 0.4 + jit(i, 3.0) * r * 0.3, -u2 * 14.0 + r * 0.3), 1.2, Color(FF_FIRE, 0.8 * (1.0 - u2) * sf))
	if tier >= 5 and since < 1.2:                                   # two spirals, one blue and one orange, wind round the disc
		var f5 := clampf((1.2 - since) / 0.3, 0.0, 1.0)
		s.draw_arc(Vector2.ZERO, r * 0.5, since * 3.0, since * 3.0 + deg_to_rad(270.0), 20, Color(FF_ICE, 0.9 * f5), 2.5)
		s.draw_arc(Vector2.ZERO, r * 0.8, -since * 3.0, -since * 3.0 + deg_to_rad(270.0), 20, Color(FF_FIRE, 0.9 * f5), 2.5)
		s.draw_arc(Vector2.ZERO, r * 0.2, since * 4.0, since * 4.0 + PI, 10, Color(FF_ICE, 0.9 * f5), 3.0)
		s.draw_arc(Vector2.ZERO, r * 0.2, since * 4.0 + PI, since * 4.0 + TAU, 10, Color(FF_FIRE, 0.9 * f5), 3.0)
	if tier >= 6 and since < 1.6:                                   # a binary star: a blue and an orange sun circle each other
		var f6 := clampf((1.6 - since) / 0.3, 0.0, 1.0)
		s.draw_circle(Vector2.ZERO, r * 0.5, Color(FF_VIOLET, 0.2 * f6))
		var a2 := since * 6.0
		for k in 2:
			var sp := Vector2.from_angle(a2 + k * PI) * 6.0
			s.draw_circle(sp, 7.0, Color(FF_ICE if k == 0 else FF_FIRE, f6))
		for i in 16:
			var d2 := Vector2.from_angle(-since * 0.8 + i * TAU / 16.0)
			s.draw_line(d2 * 10.0, d2 * r * 0.9, Color(FF_ICE if i % 2 == 0 else FF_FIRE, 0.5 * f6), 1.5)

# ---------------------------------------------------------------- Solar Burst

const SB_SUN := Color(1.0, 0.9, 0.5)
const SB_AMBER := Color(1.0, 0.65, 0.2)
const SB_EMBER := Color(1.0, 0.4, 0.1)

static func flight_solar_burst(s, t: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var p: Vector2 = (s.origin - s.position).lerp(Vector2.ZERO, t)
	s.draw_circle(p, 8.0, Color(SB_SUN, 0.3))
	for i in 6:
		var d := Vector2.from_angle(s.age * 4.0 + i * TAU / 6.0)
		s.draw_line(p + d * 3.0, p + d * 8.0, Color(SB_SUN, 0.9), 1.5)
	s.draw_circle(p, 3.0, Color(1, 1, 0.9))

static func draw_solar_burst(s, since: float, _col: Color) -> void:
	var tier := int(s.data.get("tier", 1))
	if tier < 2:
		return
	var r: float = s.radius
	var life: float = s.effect_time
	var base_fade := clampf(1.0 - since / 0.4, 0.0, 1.0)
	var glare := clampf(1.0 - since / 0.5, 0.0, 1.0)
	# tier 2: a white-gold glare, sharp rays to 1.2 r, a lens-flare star
	s.draw_circle(Vector2.ZERO, r, Color(1, 0.99, 0.9, 0.35 * glare))
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0 + 0.2)
		ray(s, Vector2.ZERO, d, r * 1.2, 8.0, 0.0, Color(SB_SUN, 0.4 * glare))
	for i in 2:
		var d2 := Vector2.from_angle(since + i * PI / 2.0)
		ray(s, Vector2.ZERO, d2, r * 0.5, 6.0, 0.0, Color(1, 1, 1, 0.6 * base_fade))
		ray(s, Vector2.ZERO, -d2, r * 0.5, 6.0, 0.0, Color(1, 1, 1, 0.6 * base_fade))
	if tier >= 3 and since < 0.4:                                   # six spark orbs circle the edge before they leave
		for i in 6:
			var sp := Vector2.from_angle(since * 6.0 + i * TAU / 6.0) * r
			s.draw_circle(sp, 4.0, Color(SB_AMBER, 0.5))
			s.draw_circle(sp, 2.5, Color(1, 1, 1, 0.9))
	if tier >= 4:                                                   # three rings of light, a layered glow
		s.draw_circle(Vector2.ZERO, r * 0.8, Color(SB_AMBER, 0.14 * base_fade))
		s.draw_circle(Vector2.ZERO, r * 0.5, Color(SB_SUN, 0.16 * base_fade))
		s.draw_circle(Vector2.ZERO, r * 0.25, Color(1, 1, 1, 0.2 * base_fade))
		for k in 3:
			var u := (since - 0.25 * k) / 0.7
			if u > 0.0 and u < 1.0:
				s.draw_arc(Vector2.ZERO, r * 1.3 * u, 0, TAU, 40, Color(SB_SUN, 0.9 * (1.0 - u)), 3.0)
	if tier >= 5 and since < 1.4:                                   # a spoked wheel of eight beams turns, with a bright hub
		var a := SpellTiers.wheel_angle(since)
		var f := clampf((1.4 - since) / 0.2, 0.0, 1.0)
		for i in 8:
			var d3 := Vector2.from_angle(a + i * TAU / 8.0)
			s.draw_line(Vector2.ZERO, d3 * r * 1.2, Color(SB_SUN, 0.6 * f), 3.0)
			s.draw_circle(d3 * r * 1.2, 2.5, Color(1, 1, 0.9, 0.8 * f))
		s.draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 0.95, f))
	if tier >= 6 and since < 1.6:                                   # a miniature sun: discs, long rays, prominences, a gold shock ring
		var f6 := clampf((1.6 - since) / 0.3, 0.0, 1.0)
		s.draw_circle(Vector2.ZERO, r * 0.9, Color(SB_EMBER, 0.25 * f6))
		s.draw_circle(Vector2.ZERO, r * 0.7, Color(SB_AMBER, 0.3 * f6))
		s.draw_circle(Vector2.ZERO, r * 0.5, Color(SB_SUN, 0.35 * f6))
		s.draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 0.95, 0.5 * f6))
		for i in 16:
			var d4 := Vector2.from_angle(-since * 0.6 + i * TAU / 16.0)
			s.draw_line(d4 * r * 0.4, d4 * r * 1.6, Color(SB_SUN, 0.4 * f6), 2.0)
		for i in 6:
			var pa := i * TAU / 6.0 + since * 0.3
			s.draw_arc(Vector2.from_angle(pa) * r * 0.9, r * 0.2, pa - 1.2, pa + 1.2, 10, Color(SB_AMBER, 0.8 * f6), 2.0)
		if since < 1.0:
			s.draw_arc(Vector2.ZERO, r * SpellTiers.SB_NOVA_R * since, 0, TAU, 48, Color(SB_SUN, 0.9 * (1.0 - since)), 3.0)
