extends RefCounted
class_name StructureArt
## How each building card is drawn, per tier. `draw` returns false for an id without its own drawing, so Structure's old
## per-kind drawing runs (a card gets its art one at a time). All motion comes from the structure's own clock (`_age`, which also
## ticks on a LAN client) and from SpellArt.jit, so every machine draws the same picture. Designs: docs/card_tiers/<card id>.md

## The towers, walls and healers of cards/structure_art_c.gd (Crystal Pylon ... Phoenix Shrine) are drawn there.
const AC = preload("res://cards/structure_art_c.gd")
const GOLD := Color(1.0, 0.85, 0.4)

## True when the card has its own drawing (and has drawn it).
static func draw(st, col: Color) -> bool:
	match String(st.data.get("id", "")):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret":
			return AC.draw(st, col)
		"barricade":
			draw_barricade(st, col)
			return true
		"spike_trap":
			draw_spike_trap(st, col)
			return true
		"torch":
			draw_torch(st, col)
			return true
		"sentry":
			draw_sentry(st, col)
			return true
		"mender":
			draw_mender(st, col)
			return true
		"iron_wall":
			draw_iron_wall(st, col)
			return true
		"frost_totem":
			draw_frost_totem(st, col)
			return true
		"ember_turret":
			draw_ember_turret(st, col)
			return true
		_:
			return false

# ---------------------------------------------------------------- small shared shapes

## A solid rectangle with the black 1px outline every building has.
static func box(st, rect: Rect2, fill: Color) -> void:
	st.draw_rect(rect, Color.BLACK)
	st.draw_rect(rect.grow(-1.0), fill)

## A solid polygon with a black outline.
static func poly(st, pts: PackedVector2Array, fill: Color) -> void:
	st.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	st.draw_polyline(closed, Color.BLACK, 1.0)

## A rivet.
static func rivet(st, p: Vector2, col: Color, r := 1.0) -> void:
	st.draw_circle(p, r + 0.5, Color.BLACK)
	st.draw_circle(p, r, col)

## A kite-shaped shield emblem.
static func kite(st, c: Vector2, w: float, h: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-w * 0.5, -h * 0.4), c + Vector2(w * 0.5, -h * 0.4), c + Vector2(w * 0.4, h * 0.1), c + Vector2(0, h * 0.5), c + Vector2(-w * 0.4, h * 0.1)])
	st.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	st.draw_polyline(closed, edge, 1.0)

## A steady bar for the hp of a building (the card art keeps the old one).
static func hp_bar(st, y: float, half_w: float, gold_ends := false) -> void:
	if st.hp >= st.max_hp:
		return
	var f: float = clampf(st.hp / st.max_hp, 0.0, 1.0)
	st.draw_rect(Rect2(-half_w, y, half_w * 2.0, 3), Color(0.2, 0, 0))
	st.draw_rect(Rect2(-half_w, y, half_w * 2.0 * f, 3), Color(0.3, 0.9, 0.3))
	if gold_ends:
		st.draw_rect(Rect2(-half_w - 1, y - 1, 2, 5), GOLD)
		st.draw_rect(Rect2(half_w - 1, y - 1, 2, 5), GOLD)

# ---------------------------------------------------------------- Barricade
const DARK_WOOD := Color(0.4, 0.27, 0.15)
const IRON := Color(0.55, 0.58, 0.65)
const STONE := Color(0.62, 0.62, 0.66)

static func merlons(st, x0: float, x1: float, y: float, n: int, w: float, fill: Color) -> void:
	for i in n:
		var x := lerpf(x0, x1 - w, i / float(maxi(n - 1, 1)))
		box(st, Rect2(x, y - 5.0, w, 5.0), fill)

static func draw_barricade(st, col: Color) -> void:
	var r: float = st.radius
	var t: int = st.tier
	var age: float = st._age
	var top := -r * 0.8 - (3.0 if t >= 3 else 0.0)
	var bot := r * 0.8
	var h := bot - top
	var thorns: float = float(st.data.get("thorns", 0.0))
	box(st, Rect2(-r, top, r * 2.0, h), col)
	for i in 3:
		var y := top + h * (0.25 + 0.25 * i)
		st.draw_line(Vector2(-r + 2, y), Vector2(r - 2, y), col.darkened(0.4), 1.5)
	if t >= 5:                                                  # the lower half is grey stone blocks
		var mid := top + h * 0.5
		st.draw_rect(Rect2(-r + 1, mid, r * 2.0 - 2, bot - mid - 1), STONE)
		for row in 3:
			var y2 := mid + (bot - mid) * row / 3.0
			st.draw_line(Vector2(-r + 1, y2), Vector2(r - 1, y2), STONE.darkened(0.45), 1.0)
			for k in 4:
				var x := -r + 1.0 + (float(k) + (0.5 if row % 2 == 1 else 0.0)) * (r * 2.0 - 2.0) / 4.0
				if x > -r + 2 and x < r - 2:
					st.draw_line(Vector2(x, y2), Vector2(x, y2 + (bot - mid) / 3.0), STONE.darkened(0.45), 1.0)
	if t >= 2:
		for sx in [-0.5, 0.5]:                                   # iron straps with rivets, and a cross brace
			var x2: float = sx * r
			box(st, Rect2(x2 - 1.5, top, 3.0, h), IRON)
			rivet(st, Vector2(x2, top + 3.0), STONE.lightened(0.3))
			rivet(st, Vector2(x2, bot - 3.0), STONE.lightened(0.3))
		st.draw_line(Vector2(-r * 0.5, bot - 1.0), Vector2(r * 0.5, top + 1.0), DARK_WOOD, 1.5)
	# the top edge: thorn spikes, then stakes, then crenellations
	if t < 3 and thorns > 0.0:
		for i in 5:
			var x3 := -r + 3.0 + i * (r * 2.0 - 6.0) / 4.0
			st.draw_colored_polygon(PackedVector2Array([Vector2(x3 - 2, top), Vector2(x3, top - 5), Vector2(x3 + 2, top)]), Color(0.75, 0.9, 0.4))
	elif t in [3, 4]:
		for i in 6:
			var x4 := -r + 3.0 + i * (r * 2.0 - 6.0) / 5.0
			st.draw_colored_polygon(PackedVector2Array([Vector2(x4 - 2.5, top), Vector2(x4, top - 7), Vector2(x4 + 2.5, top)]), DARK_WOOD)
			st.draw_colored_polygon(PackedVector2Array([Vector2(x4 - 0.9, top - 4.5), Vector2(x4, top - 7), Vector2(x4 + 0.9, top - 4.5)]), Color(0.92, 0.85, 0.65))
		for i in 3:                                              # rooted in the ground
			var gx := -r + 5.0 + i * r * 0.9
			st.draw_line(Vector2(gx, bot), Vector2(gx - 1.5, bot + 4), Color(0.35, 0.7, 0.3), 1.0)
			st.draw_line(Vector2(gx, bot), Vector2(gx + 1.5, bot + 4), Color(0.35, 0.7, 0.3), 1.0)
	elif t >= 5:
		merlons(st, -r, r, top, 4, 5.0, STONE)
	if t >= 4:                                                   # arrow slits, a bolt head, a pennant
		for sx2 in [-0.25, 0.25]:
			var cx: float = sx2 * r
			st.draw_rect(Rect2(cx - 1, top + 4.0, 2, 6), Color.BLACK)
			st.draw_rect(Rect2(cx - 0.4, top + 5.0, 0.8, 2), Color(1.0, 0.85, 0.5, 0.7 + 0.3 * sin(age * 3.0)))
		st.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.25 + 1, top + 6), Vector2(r * 0.25 + 5, top + 7), Vector2(r * 0.25 + 1, top + 8)]), Color(0.9, 0.9, 0.95))
	if t in [4, 5]:
		var px := r - 2.0
		var wave := sin(age * 3.0)
		st.draw_line(Vector2(px, top), Vector2(px, top - 15), Color.BLACK, 2.0)
		st.draw_colored_polygon(PackedVector2Array([Vector2(px, top - 15), Vector2(px + 8 + wave * 1.5, top - 12 + wave), Vector2(px, top - 8)]), Color(0.85, 0.2, 0.2))
	if t >= 5:
		kite(st, Vector2(0, top + h * 0.5), 8.0, 11.0, GOLD, Color.BLACK)
	if t >= 6:
		for sx3 in [-1.0, 1.0]:                                  # corner towers
			var tx: float = sx3 * (r - 3.0) - 3.0
			box(st, Rect2(tx, top - 8.0, 6.0, h + 8.0), STONE)
			merlons(st, tx - 1, tx + 7, top - 8.0, 2, 3.0, STONE)
			st.draw_line(Vector2(tx, top - 8.0), Vector2(tx + 6, top - 8.0), GOLD, 1.0)
		var wv := sin(age * 2.5)
		st.draw_line(Vector2(0, top), Vector2(0, top - 17), Color.BLACK, 2.0)
		st.draw_colored_polygon(PackedVector2Array([Vector2(1, top - 17), Vector2(9 + wv, top - 16), Vector2(8 + wv, top - 8 + wv * 0.5), Vector2(1, top - 9)]), GOLD)
		st.draw_circle(Vector2(5 + wv * 0.5, top - 12.5), 1.4, Color(0.7, 0.2, 0.2))
		st.draw_line(Vector2(-r + 1, top + 1), Vector2(r - 1, top + 1), GOLD, 1.0)
		st.draw_line(Vector2(-r + 1, bot - 1), Vector2(r - 1, bot - 1), GOLD, 1.0)
		for sx4 in [-1.0, 1.0]:
			SpellArt.diamond(st, Vector2(sx4 * r * 0.55, top + h * 0.7), 2.5, Color(0.6, 0.9, 1.0, 0.5 + 0.4 * sin(age * 3.0 + sx4)))
	if st.charge > 0.05 and t >= 2:                              # the shove is about to buck
		st.draw_line(Vector2(-r, top), Vector2(r, top), Color(1.0, 0.85, 0.4, 0.85 * st.charge), 2.0)
	if st.invuln_view:                                           # second wind: a golden dome
		st.draw_circle(Vector2.ZERO, r * 1.2, Color(1.0, 0.85, 0.4, 0.25))
		st.draw_arc(Vector2.ZERO, r * 1.2, 0, TAU, 32, Color(1.0, 0.9, 0.5, 0.8), 1.5)
	hp_bar(st, bot + 3.0 + (3.0 if t in [3, 4] else 0.0), r, t >= 4)

# ---------------------------------------------------------------- Spike Trap
const DARK_IRON := Color(0.35, 0.37, 0.42)
const RUST := Color(0.55, 0.3, 0.2)

static func draw_spike_trap(st, col: Color) -> void:
	var r: float = st.radius
	var t: int = st.tier
	var age: float = st._age
	var hit: bool = st.flash > 0.0
	var spike_h := 5.0 if t == 1 else (6.0 if t == 2 else 9.0)
	if t >= 4:                                                      # caltrops lie scattered in a wider ring
		st.draw_circle(Vector2.ZERO, r * 1.35, Color(col, 0.1))
		for i in 10:
			var c := Vector2.from_angle(SpellArt.jit(i, 1.0) * TAU) * r * (1.0 + 0.35 * SpellArt.jit(i, 2.0))
			var a := SpellArt.jit(i, 3.0) * TAU
			st.draw_line(c + Vector2.from_angle(a) * 3.0, c - Vector2.from_angle(a) * 3.0, DARK_IRON, 1.5)
			st.draw_line(c + Vector2.from_angle(a + 1.9) * 3.0, c - Vector2.from_angle(a + 1.9) * 3.0, DARK_IRON, 1.5)
			if i % 3 == 0:
				st.draw_circle(c + Vector2(0.5, -0.5), 0.8, Color(1, 1, 1, 0.5 + 0.4 * sin(age * 3.0 + i)))
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.18))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(col, 0.6), 1.0)
	if t >= 2:                                                      # a zig-zag wire loop, a rivet at each peak
		var pts := PackedVector2Array()
		for i in 25:
			var rr := r * 0.85 + (2.4 if i % 2 == 0 else -2.4)
			pts.append(Vector2.from_angle(i * TAU / 24.0) * rr)
		st.draw_polyline(pts, Color.WHITE if hit else DARK_IRON, 1.5)
		for i in 6:
			rivet(st, Vector2.from_angle(i * TAU / 6.0) * (r * 0.85 + 2.4), col.lightened(0.2), 0.8)
	if t >= 5:                                                      # a barbed chain round it
		for i in 20:
			var a2 := i * TAU / 20.0
			var lp := Vector2.from_angle(a2) * r * 1.1
			st.draw_circle(lp, 1.2, DARK_IRON)
			if i % 4 == 0:
				var d := Vector2.from_angle(a2)
				st.draw_line(lp, lp + d * 3.0 + d.orthogonal() * 1.5, col, 1.0)
				st.draw_line(lp, lp + d * 3.0 - d.orthogonal() * 1.5, col, 1.0)
		st.draw_arc(Vector2(0, -r * 1.1 - 3.0), 2.5, PI * 0.2, PI * 1.9, 8, col.lightened(0.2), 1.5)     # the hook at the north point
	# the spikes
	var ring := 0.8 if t >= 6 else 0.55
	for i in 7:
		var c2 := Vector2.from_angle(i * TAU / 7.0) * r * ring
		var tip := Color(1.0, 0.85, 0.4) if t >= 6 else col
		if t >= 3:
			st.draw_polyline(PackedVector2Array([c2 + Vector2(-2, 3), c2 + Vector2(2, 2.2), c2 + Vector2(-2, 1.4), c2 + Vector2(2, 0.6)]), DARK_IRON, 1.0)    # the spring
		st.draw_colored_polygon(PackedVector2Array([c2 + Vector2(-2.5, 0), c2 + Vector2(0, -spike_h), c2 + Vector2(2.5, 0)]), col if t < 6 else col.darkened(0.1))
		st.draw_colored_polygon(PackedVector2Array([c2 + Vector2(-0.8, -spike_h * 0.6), c2 + Vector2(0, -spike_h), c2 + Vector2(0.8, -spike_h * 0.6)]), tip.lightened(0.2))
		if t >= 3:
			st.draw_line(c2 + Vector2(-0.6, -1.0), c2 + Vector2(-0.2, -spike_h * 0.7), Color(1, 1, 1, 0.6), 1.0)
		if t >= 5:
			st.draw_line(c2 + Vector2(0, -spike_h * 0.7), c2 + Vector2(2.2, -spike_h * 0.5), col, 1.0)
	if t >= 6:                                                      # four tall inner spikes, a rune ring, the plate a hexagon sigil
		for i in 4:
			var c3 := Vector2.from_angle(i * TAU / 4.0 + 0.4) * r * 0.32
			st.draw_colored_polygon(PackedVector2Array([c3 + Vector2(-3, 0), c3 + Vector2(0, -14), c3 + Vector2(3, 0)]), col)
			st.draw_colored_polygon(PackedVector2Array([c3 + Vector2(-1, -11), c3 + Vector2(0, -14), c3 + Vector2(1, -11)]), GOLD)
		for i in 8:
			var rp := Vector2.from_angle(i * TAU / 8.0 + age * 0.3) * r * 0.7
			SpellArt.diamond(st, rp, 1.6, Color(1.0, 0.85, 0.4, 0.4 + 0.5 * sin(age * 3.0 + i)))
		var hx := PackedVector2Array()
		for i in 7:
			hx.append(Vector2.from_angle(i * TAU / 6.0) * 6.0)
		st.draw_polyline(hx, GOLD, 1.5)
		for i in mini(st.uses, 12):                                 # one pip per use left
			st.draw_circle(Vector2.from_angle(-PI / 2.0 + i * TAU / 12.0) * (r + 3.0), 1.3, GOLD)
	elif t >= 3:                                                    # the pressure plate sinks when it is stepped on
		var pr := 4.2 if hit else 5.0
		st.draw_circle(Vector2.ZERO, pr + 0.7, col.lightened(0.3))
		st.draw_circle(Vector2.ZERO, pr, DARK_IRON)

# ---------------------------------------------------------------- Torch
const TORCH_WOOD := Color(0.55, 0.38, 0.2)
const TORCH_IRON := Color(0.3, 0.3, 0.34)
const EMBER := Color(1.0, 0.45, 0.1)

## One three-layer flame (the old torch flame, scaled) at `p`.
static func torch_flame(st, p: Vector2, k: float, flick: float, tint := 0.0) -> void:
	st.draw_circle(p, 5.0 * flick * k, Color(1.0, 0.45, 0.1, 0.9).lerp(Color(1.0, 0.8, 0.4, 0.9), tint))
	st.draw_circle(p + Vector2(0, -1.0 * k), 3.2 * flick * k, Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.95, 0.6), tint))
	st.draw_circle(p + Vector2(0, -1.5 * k), 1.6 * flick * k, Color(1.0, 0.98, 0.8))

static func draw_torch(st, _col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var flick := 0.8 + 0.2 * sin(age * 11.0) + 0.1 * sin(age * 17.0)
	var lr: float = st.light_radius
	var k := 1.0 if t == 1 else 1.3
	if t >= 6:
		k *= 1.0 + 0.25 * clampf((st.charge - 0.875) * 8.0, 0.0, 1.0)
	var top := -2.0 - (6.0 if t >= 3 else 0.0)                  # the pole top (negative is up)
	var fp := Vector2(0, -5.0 - (6.0 if t >= 3 else 0.0) - (1.0 if t >= 2 else 0.0))
	if t >= 4:                                                    # a warm glow on the ground and a ring of stones
		st.draw_circle(Vector2(0, 4), lr * 0.5, Color(1.0, 0.5, 0.1, 0.08))
		for i in 6:
			var a := i * TAU / 6.0
			var sp := Vector2(cos(a) * 10.0, 4.0 + sin(a) * 4.5)
			st.draw_rect(Rect2(sp.x - 2.5, sp.y - 1.5, 5, 3), Color.BLACK)
			st.draw_rect(Rect2(sp.x - 2.0, sp.y - 1.0, 4, 2), Color(0.55, 0.55, 0.58))
	if t >= 6:                                                    # a gold sun-disc behind the flame
		var c := fp + Vector2(0, -1.0)
		st.draw_circle(c, 9.0, Color(1.0, 0.85, 0.4, 0.3))
		for i in 12:
			var a2 := age * 0.4 + i * TAU / 12.0
			var d := Vector2.from_angle(a2)
			st.draw_colored_polygon(PackedVector2Array([c + d * 9.0 + d.orthogonal() * 2.0, c + d * 18.0, c + d * 9.0 - d.orthogonal() * 2.0]), Color(1.0, 0.85, 0.4, 0.6))
		st.draw_arc(c, 20.0 + 1.5 * sin(age * 3.0), 0, TAU, 28, Color(1.0, 0.9, 0.5, 0.5), 1.0)
	# pole
	st.draw_rect(Rect2(-1.5, top, 3, 11.0 - top - 2.0 + 0.0), Color.BLACK)
	st.draw_rect(Rect2(-0.5, top + 1.0, 1, 9.0 - top - 2.0), TORCH_WOOD)
	if t >= 6:
		for y in [top + 4.0, top + 8.0]:
			st.draw_rect(Rect2(-1.0, y, 2, 1.2), Color(1.0, 0.85, 0.4))
	if t >= 3:                                                    # a side arm with a small flame (and from tier 4 a lantern)
		st.draw_line(Vector2(0, top + 4.0), Vector2(7, top + 1.0), Color.BLACK, 2.0)
		st.draw_line(Vector2(0, top + 4.0), Vector2(7, top + 1.0), TORCH_WOOD, 1.0)
		torch_flame(st, Vector2(7, top - 2.0), 0.45, 0.9 + 0.1 * sin(age * 13.0 + 1.0))
		if t >= 4:
			st.draw_line(Vector2(-6, top + 1.0), Vector2(0, top + 4.0), TORCH_WOOD, 1.0)
			st.draw_rect(Rect2(-8, top + 1.0, 4, 5), Color.BLACK)
			st.draw_rect(Rect2(-7.3, top + 1.8, 2.6, 3.4), Color(1.0, 0.85, 0.4, 0.8 + 0.2 * sin(age * 9.0)))
	if t >= 2:                                                    # the iron bowl, heaped with embers
		var by := 6.0
		var bowl := PackedVector2Array([Vector2(-6, by), Vector2(6, by), Vector2(4, by + 5), Vector2(-4, by + 5)])
		st.draw_colored_polygon(bowl, TORCH_IRON)
		st.draw_polyline(PackedVector2Array([bowl[0], bowl[1], bowl[2], bowl[3], bowl[0]]), Color.BLACK, 1.0)
		st.draw_line(Vector2(-6, by), Vector2(6, by), TORCH_IRON.lightened(0.4), 1.5)
		for i in 3:
			st.draw_circle(Vector2(-3 + i * 3.0, by - 0.5), 1.0, EMBER)
		if t >= 3:
			st.draw_polyline(PackedVector2Array([Vector2(-2, by + 1), Vector2(0, by + 3), Vector2(2, by + 2)]), Color(1.0, 0.6, 0.2, 0.8), 1.0)
		if t >= 5:                                                # a second bowl below
			st.draw_colored_polygon(PackedVector2Array([Vector2(-5, by + 5), Vector2(5, by + 5), Vector2(3, by + 9), Vector2(-3, by + 9)]), TORCH_IRON.darkened(0.2))
			st.draw_line(Vector2(-5, by + 5), Vector2(5, by + 5), TORCH_IRON.lightened(0.3), 1.0)
		if t >= 6:
			st.draw_line(Vector2(-6, by - 0.5), Vector2(6, by - 0.5), Color(1.0, 0.85, 0.4), 1.5)
	torch_flame(st, fp, k, flick, 0.5 if t >= 6 else 0.0)
	if t >= 2:                                                    # sparks (and from tier 3 ember flecks) rise from the flame
		var n := 3 if t == 2 else 6
		for i in n:
			var ph := fposmod(age * (0.7 + 0.3 * SpellArt.jit(i, 4.0)) + SpellArt.jit(i), 1.0)
			var out := (SpellArt.jit(i, 5.0) - 0.5) * (7.0 if t == 2 else 16.0) * ph
			st.draw_circle(fp + Vector2(out, -5.0 - ph * (14.0 if t == 2 else 18.0)), 0.9, Color(1.0, 0.7, 0.3, 1.0 - ph))
	if t >= 4:                                                    # a heat shimmer over the flame
		for j in 2:
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(fp + Vector2(-3.0 + j * 6.0 + 1.2 * sin(age * 4.0 + i + j * 2.0), -9.0 - i * 1.6))
			st.draw_polyline(pts, Color(1.0, 0.8, 0.5, 0.25), 1.0)
	if t >= 5:                                                    # three fire orbs circle it
		st.draw_arc(Vector2.ZERO, lr * 0.45, 0, TAU, 40, Color(1.0, 0.6, 0.2, 0.12), 1.0)
		for i in 3:
			var a3: float = age * StructureTiers.TORCH_ORB_SPEED + i * TAU / 3.0
			var op := Vector2.from_angle(a3) * lr * 0.45
			for k2 in 3:
				var tp := op - Vector2.from_angle(a3).orthogonal() * (k2 + 1) * 3.0
				st.draw_circle(tp, 2.4 - k2 * 0.6, Color(1.0, 0.6, 0.2, 0.5 - k2 * 0.14))
			torch_flame(st, op, 0.8, 0.85 + 0.15 * sin(age * 12.0 + i))
	if Game.is_dark():
		st.draw_arc(Vector2.ZERO, lr, 0, TAU, 40, Color(1.0, 0.8, 0.4, 0.15), 1.0)
	if st.fx_pulse < 0.3:
		st.draw_arc(Vector2.ZERO, TORCH_ARC_R, 0, TAU, 24, Color(1.0, 0.7, 0.3, 0.8 * (1.0 - st.fx_pulse / 0.3)), 1.5)
const TORCH_ARC_R := 20.0

# ---------------------------------------------------------------- Sentry
const SENTRY_PIPS := 6
const BOLT := Color(1.0, 0.95, 0.7)
const STEEL := Color(0.65, 0.68, 0.75)

## A ring of `n` dashes round the structure.
static func dashed_ring(st, r: float, col: Color, n: int, spin := 0.0) -> void:
	for i in n:
		var a := spin + i * TAU / float(n)
		st.draw_arc(Vector2.ZERO, r, a, a + TAU / float(n) * 0.5, 4, col, 1.0)

const DARK_STEEL := Color(0.3, 0.32, 0.38)

## Which way a turret faces: where it last shot, drifting a little when idle.
static func facing(st) -> Vector2:
	var base: Vector2 = st.aim if st.aim != Vector2.ZERO else Vector2.from_angle(-PI / 2.0)
	if st.shot_t > 0.0:
		return base
	return base.rotated(0.35 * sin(st._age * 0.8))

static func draw_sentry(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var dir := facing(st)
	var perp := dir.orthogonal()
	var head := Vector2(0, -5.0)
	var recoil: float = 2.0 * clampf(st.shot_t / 0.12, 0.0, 1.0) if t >= 4 else 0.0
	var top := -3.0 - (6.0 if t >= 6 else 0.0)
	if t >= 2:                                                    # a stone footing
		st.draw_colored_polygon(PackedVector2Array([Vector2(-10, 7), Vector2(-7, 10), Vector2(7, 10), Vector2(10, 7), Vector2(7, 5), Vector2(-7, 5)]), Color(0.55, 0.55, 0.58))
	if t >= 4:                                                    # tripod legs
		for sx in [-1.0, 1.0]:
			st.draw_line(Vector2(sx * 5, 6), Vector2(sx * 9, 11), Color.BLACK, 2.0)
			st.draw_line(Vector2(sx * 5, 6), Vector2(sx * 9, 11), DARK_STEEL, 1.0)
	if t >= 6:                                                    # laurel wings and a faint range ring
		for sx in [-1.0, 1.0]:
			st.draw_colored_polygon(PackedVector2Array([Vector2(sx * 7, -1), Vector2(sx * 15, -9), Vector2(sx * 12, -2), Vector2(sx * 15, 3), Vector2(sx * 8, 4)]), Color(1.0, 0.85, 0.4, 0.85))
			st.draw_polyline(PackedVector2Array([Vector2(sx * 7, -1), Vector2(sx * 15, -9), Vector2(sx * 12, -2), Vector2(sx * 15, 3), Vector2(sx * 8, 4)]), Color.BLACK, 1.0)
		dashed_ring(st, float(st.data.get("range", 110.0)), Color(1.0, 0.9, 0.6, 0.15), 40)
	# the post
	box(st, Rect2(-7, top, 14, 10.0 - top - 3.0 + 0.0), col.darkened(0.3))
	if t >= 3:                                                    # brass bands
		for y in [top + 2.0, 4.0]:
			st.draw_line(Vector2(-6, y), Vector2(6, y), col, 1.0)
	if t >= 5:                                                    # bolted steel plates, a black and gold stripe
		for sx in [-1.0, 1.0]:
			st.draw_rect(Rect2(sx * 3.5 - 2.0, top + 1.0, 4, 7.0 - top - 3.0 + 3.0), STEEL.darkened(0.15))
			st.draw_line(Vector2(sx * 3.5 - 2.0, top + 1.0), Vector2(sx * 3.5 + 2.0, top + 1.0), Color.WHITE, 1.0)
			rivet(st, Vector2(sx * 3.5, top + 3.0), STEEL.lightened(0.4), 0.7)
		st.draw_line(Vector2(-7, 2), Vector2(7, 2), Color.BLACK, 1.5)
		st.draw_line(Vector2(-7, 3.2), Vector2(7, 3.2), GOLD, 1.0)
	if t >= 6:                                                    # a roof, a banner and glowing runes
		st.draw_colored_polygon(PackedVector2Array([Vector2(-9, top), Vector2(0, top - 9), Vector2(9, top)]), Color(0.45, 0.3, 0.25))
		st.draw_polyline(PackedVector2Array([Vector2(-9, top), Vector2(0, top - 9), Vector2(9, top), Vector2(-9, top)]), GOLD, 1.0)
		st.draw_line(Vector2(0, top - 9), Vector2(0, top - 15), Color.BLACK, 1.5)
		var wv := sin(age * 3.0)
		st.draw_colored_polygon(PackedVector2Array([Vector2(0, top - 15), Vector2(6 + wv, top - 14), Vector2(0, top - 11)]), Color(0.4, 0.7, 1.0))
		for i in 3:
			st.draw_line(Vector2(-5 + i * 5, top + 3.0), Vector2(-5 + i * 5, top + 7.0), Color(0.7, 0.9, 1.0, 0.5 + 0.4 * sin(age * 3.0 + i)), 1.0)
	# the head: a crossbow from tier 2
	var hc := head - dir * recoil
	st.draw_circle(hc, 5.5, Color.BLACK)
	st.draw_circle(hc, 4.5, col)
	if t >= 2:
		var front := hc + dir * 7.0
		var limb := [front + perp * 7.0 - dir * 3.0, front + perp * 3.5 - dir * 0.6, front, front - perp * 3.5 - dir * 0.6, front - perp * 7.0 - dir * 3.0]
		st.draw_polyline(PackedVector2Array(limb), Color.BLACK, 3.0)
		st.draw_polyline(PackedVector2Array(limb), STEEL, 1.6)
		st.draw_line(limb[0], limb[4], Color(0.95, 0.95, 0.9, 0.7), 1.0)
		st.draw_line(hc, front + dir * 3.0, Color.BLACK, 3.0)
		st.draw_line(hc, front + dir * 3.0, BOLT if st.shot_t <= 0.0 else Color(0.5, 0.45, 0.3), 1.4)
		if t >= 3:                                                # a scope with a glinting lens
			var s0 := hc + perp * 3.0 + dir * 1.0
			st.draw_line(s0, s0 + dir * 6.0, Color.BLACK, 3.0)
			st.draw_line(s0, s0 + dir * 6.0, STEEL.darkened(0.2), 1.8)
			st.draw_circle(s0 + dir * 6.0, 1.3, Color(0.6, 0.9, 1.0, 0.6 + 0.4 * sin(age * 4.0)))
		if t >= 5:                                                # a red eye that burns when something can be executed
			st.draw_circle(hc, 2.0, Color(1.0, 0.3, 0.25, 1.0 if st.alert else 0.4))
	if t >= 4:                                                    # a quiver of five arrows
		for i in 5:
			var x := 9.0 + i * 1.3
			st.draw_line(Vector2(x, -4), Vector2(x + 1.0, 5), Color(0.8, 0.7, 0.5), 1.0)
			st.draw_line(Vector2(x, -4), Vector2(x - 1.0, -6), Color(0.9, 0.3, 0.3), 1.0)
	if t >= 3:                                                    # focus pips
		for i in SENTRY_PIPS:
			var lit: bool = i < int(round(st.charge * SENTRY_PIPS))
			st.draw_circle(Vector2((i - 2.5) * 3.6, -16.0 - (6.0 if t >= 6 else 0.0)), 1.3, Color(1.0, 0.85, 0.4) if lit else Color(0.2, 0.2, 0.25, 0.8))
	if st.shot_t > 0.0:                                           # the shot
		var to: Vector2 = st.shot_to - st.global_position
		st.draw_line(hc + dir * 7.0, to, Color(col.lightened(0.5), 0.9) if t == 1 else Color(1.0, 0.95, 0.7, 0.9), 2.0)
	if t >= 6 and st.mark_on:                                     # the mark on its prey
		var mp: Vector2 = st.mark_pos - st.global_position
		var pulse := 1.0 + 0.15 * sin(age * 8.0)
		st.draw_arc(mp, 7.0 * pulse, 0, TAU, 16, Color(1.0, 0.3, 0.25, 0.9), 1.5)
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0)
			st.draw_line(mp + d * 5.0 * pulse, mp + d * 10.0 * pulse, Color(1.0, 0.3, 0.25, 0.9), 1.5)
		var dist := mp.length()
		if dist > 14.0:
			for i in int(dist / 8.0):
				st.draw_circle(mp.normalized() * (8.0 + i * 8.0) + Vector2(0, -5), 0.7, Color(1.0, 0.4, 0.3, 0.45))

# ---------------------------------------------------------------- Mender Totem
const TOTEM_WOOD := Color(0.6, 0.42, 0.25)
const TOTEM_DARK := Color(0.35, 0.22, 0.12)
const BONE := Color(0.92, 0.9, 0.78)
const LEAF := Color(0.45, 0.8, 0.35)

static func feather(st, base: Vector2, dir: Vector2, len: float, w: float, fill: Color) -> void:
	var n := dir.orthogonal()
	st.draw_colored_polygon(PackedVector2Array([base + n * w, base + dir * len, base - n * w]), fill)

static func draw_mender(st, col: Color) -> void:
	var r: float = st.radius
	var t: int = st.tier
	var age: float = st._age
	var pulse := 0.5 + 0.5 * sin(age * 3.0)
	var glow: bool = !st.healed_pos.is_empty() or st.fx_pulse < 0.5
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.07 + 0.05 * pulse))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col, 0.35), 1.0)
	if t >= 6:
		st.draw_circle(Vector2.ZERO, r, Color(1.0, 0.85, 0.4, 0.06))
	if t >= 5:                                                    # the link reaches further
		dashed_ring(st, r * StructureTiers.MENDER_LINK, Color(col, 0.18), 36, age * 0.2)
		for hp in st.healed_pos:
			var d: Vector2 = hp - st.global_position
			st.draw_line(Vector2(0, -8), d, Color(col, 0.35), 1.5)
	if t >= 4:                                                    # a ring of runes turns in the field
		for i in 8:
			var a := age * 0.5 + i * TAU / 8.0
			var rp := Vector2.from_angle(a) * r * 0.7
			st.draw_line(rp - Vector2.from_angle(a).orthogonal() * 1.5, rp + Vector2.from_angle(a).orthogonal() * 1.5, Color(col, 0.7), 1.5)
			st.draw_circle(rp, 0.9, Color(col, 0.9))
	var top := -9.0 - (6.0 if t >= 6 else 0.0)
	var hy := -11.0 - (6.0 if t >= 6 else 0.0)
	if t >= 4:                                                    # wooden wings
		for sx in [-1.0, 1.0]:
			var wing := PackedVector2Array([Vector2(sx * 3, hy), Vector2(sx * 9, hy - 7), Vector2(sx * 15, hy - 5), Vector2(sx * 13, hy + 1), Vector2(sx * 9, hy + 2), Vector2(sx * 4, hy + 3)]) if t < 6 else PackedVector2Array([Vector2(sx * 3, hy), Vector2(sx * 10, hy - 13 + 2.0 * sin(age * 1.5)), Vector2(sx * 20, hy - 10 + 3.0 * sin(age * 1.5)), Vector2(sx * 22, hy + 2), Vector2(sx * 14, hy + 5), Vector2(sx * 5, hy + 3)])
			st.draw_colored_polygon(wing, BONE if t < 6 else Color(1.0, 0.97, 0.8, 0.55))
			st.draw_polyline(PackedVector2Array([wing[1], wing[2], wing[3]]), col if t < 6 else Color(1.0, 0.85, 0.4, 0.9), 1.5)
	# the pole
	st.draw_rect(Rect2(-3, top, 6, 7.0 - top), Color.BLACK)
	st.draw_rect(Rect2(-2, top + 1.0, 4, 5.0 - top), TOTEM_WOOD)
	if t >= 2:                                                    # painted bands
		for y in [top + 5.0, top + 10.0]:
			st.draw_rect(Rect2(-2, y, 4, 1.5), col)
	if t >= 6:
		for y in [top + 8.0]:
			st.draw_line(Vector2(-2, y), Vector2(2, y), Color(1.0, 0.85, 0.4), 1.0)
	if t >= 3:                                                    # vines wind round the pole
		var vp := PackedVector2Array()
		for i in 9:
			var y2 := top + 1.0 + i * (5.0 - top) / 8.0
			vp.append(Vector2(2.6 * sin(i * 1.2 + age * 0.4), y2))
		st.draw_polyline(vp, LEAF, 1.2)
		for i in 4:
			var lp: Vector2 = vp[1 + i * 2]
			st.draw_circle(lp + Vector2(1.8 if i % 2 == 0 else -1.8, 0), 1.2, LEAF.lightened(0.2))
	if t >= 4:                                                    # hanging charms
		for i in 3:
			var cx := -2.0 + i * 2.0
			var sw := sin(age * 2.0 + i) * 1.5
			st.draw_line(Vector2(cx, top + 8.0), Vector2(cx + sw, top + 13.0), Color.BLACK, 1.0)
			st.draw_circle(Vector2(cx + sw, top + 13.5), 1.1, BONE if i != 1 else col)
	# the head
	st.draw_circle(Vector2(0, hy), 5.0, Color.BLACK)
	st.draw_circle(Vector2(0, hy), 4.0, col if t < 2 else TOTEM_WOOD.lightened(0.15))
	if t >= 2:                                                    # a carved face with glowing eyes
		var eye := Color(col.lightened(0.4), 1.0) if glow else Color(0.1, 0.07, 0.04)
		var bright := 1.3 if t >= 3 else 1.0
		st.draw_rect(Rect2(-3, hy - 1.5, 2, 1.2 * bright), eye)
		st.draw_rect(Rect2(1, hy - 1.5, 2, 1.2 * bright), eye)
		st.draw_line(Vector2(-1.5, hy + 1.8), Vector2(1.5, hy + 1.8), Color(0.1, 0.07, 0.04), 1.0)
		var crest := Color(0.5, 0.85, 0.4) if t < 5 else Color(1.0, 0.9, 0.4)       # the feather crest
		for i in 3:
			feather(st, Vector2((i - 1) * 2.5, hy - 3.5), Vector2((i - 1) * 0.4, -1.0).normalized(), 5.0 + (2.0 if i == 1 else 0.0), 1.2, BONE if i != 1 else crest)
	if t >= 3:                                                    # a second, smaller head stacked on the first
		var h2 := hy - 8.0 - (2.0 if t >= 2 else 0.0)
		st.draw_circle(Vector2(0, h2), 3.6, Color.BLACK)
		st.draw_circle(Vector2(0, h2), 2.8, TOTEM_WOOD.lightened(0.25))
		st.draw_rect(Rect2(-1.8, h2 - 0.8, 1.4, 1.0), Color(col.lightened(0.4)) if glow else Color(0.1, 0.07, 0.04))
		st.draw_rect(Rect2(0.4, h2 - 0.8, 1.4, 1.0), Color(col.lightened(0.4)) if glow else Color(0.1, 0.07, 0.04))
	if t >= 5:                                                    # three wisps circle it
		for i in 3:
			var a2 := age * 1.6 + i * TAU / 3.0
			var wp := Vector2.from_angle(a2) * r * 0.55
			st.draw_circle(wp, 5.0, Color(0.8, 1.0, 0.85, 0.18))
			for k in 4:
				var tp := Vector2.from_angle(a2 - (k + 1) * 0.18) * r * 0.55
				st.draw_circle(tp, 2.2 - k * 0.4, Color(0.8, 1.0, 0.85, 0.5 - k * 0.1))
			st.draw_circle(wp, 3.0, Color(0.9, 1.0, 0.92))
	if t >= 6:                                                    # a gold halo and a crown of leaves
		var hc := Vector2(0, hy - 13.0)
		dashed_ring_at(st, hc, 8.0, Color(1.0, 0.85, 0.4, 0.9), 10, age * 0.8)
		st.draw_arc(hc, 8.0, 0, TAU, 20, Color(1.0, 0.85, 0.4, 0.4), 1.0)
		for i in 5:
			var ax := (i - 2) * 2.2
			st.draw_colored_polygon(PackedVector2Array([Vector2(ax - 1.0, hy - 5.0), Vector2(ax, hy - 9.5 + abs(i - 2) * 1.5), Vector2(ax + 1.0, hy - 5.0)]), Color(1.0, 0.85, 0.4))

static func dashed_ring_at(st, c: Vector2, r: float, col: Color, n: int, spin := 0.0) -> void:
	for i in n:
		var a := spin + i * TAU / float(n)
		st.draw_arc(c, r, a, a + TAU / float(n) * 0.55, 4, col, 1.5)

# ---------------------------------------------------------------- Iron Bulwark
const BRASS_DARK := Color(0.9, 0.75, 0.35)
const HAZARD := Color(0.95, 0.8, 0.15)

static func draw_iron_wall(st, col: Color) -> void:
	var r: float = st.radius
	var t: int = st.tier
	var age: float = st._age
	var top := -r * 0.8
	var bot := r * 0.8
	var h := bot - top
	var thorns: float = float(st.data.get("thorns", 0.0))
	var dark := Color(0.35, 0.38, 0.45)
	if t >= 4:                                                    # the aura: a faint ring, links to the buildings it covers
		dashed_ring(st, StructureTiers.IRON_AURA_R, Color(0.9, 0.75, 0.35, 0.1), 30, age * 0.1)
		for o in st.get_tree().get_nodes_in_group("structure"):
			if o != st and is_instance_valid(o) and o.global_position.distance_to(st.global_position) <= StructureTiers.IRON_AURA_R:
				var d: Vector2 = o.global_position - st.global_position
				for i in int(d.length() / 6.0):
					st.draw_circle(d.normalized() * (4.0 + i * 6.0), 0.6, Color(0.9, 0.75, 0.35, 0.3))
				st.draw_arc(d, o.radius + 3.0, 0, TAU, 20, Color(0.9, 0.75, 0.35, 0.5), 1.0)
	if t >= 3:                                                    # pistons on each side
		var out := 3.0 if st.fx_pulse < 0.2 else 0.0
		for sx in [-1.0, 1.0]:
			box(st, Rect2(sx * (r + 1.0 + out) - 2.0, -5.0, 4, 10), dark)
			st.draw_rect(Rect2(sx * (r + 1.0 + out) - 1.0, -4.0, 2, 8), col.lightened(0.2))
	box(st, Rect2(-r, top, r * 2.0, h), col)
	if t == 1:
		for i in 3:
			var y := top + h * (0.25 + 0.25 * i)
			st.draw_line(Vector2(-r + 2, y), Vector2(r - 2, y), col.darkened(0.4), 1.5)
	if t >= 2:                                                    # a grid of riveted plates
		st.draw_line(Vector2(0, top + 1), Vector2(0, bot - 1), dark, 1.0)
		for k in [1.0 / 3.0, 2.0 / 3.0]:
			st.draw_line(Vector2(-r + 1, top + h * k), Vector2(r - 1, top + h * k), dark, 1.0)
		for cx in [-r + 2.5, -2.5, 2.5, r - 2.5]:
			for ry in [0.0, 1.0, 2.0]:
				st.draw_circle(Vector2(cx, top + 2.5 + ry * h / 3.0), 0.8, Color(0.9, 0.92, 0.98))
				st.draw_circle(Vector2(cx, top + h * (ry + 1.0) / 3.0 - 2.5), 0.8, Color(0.9, 0.92, 0.98))
		st.draw_line(Vector2(-r + 1, top + 1), Vector2(r - 1, top + 1), Color(1, 1, 1, 0.5), 1.0)
	if t >= 3:                                                    # hazard chevrons along the bottom and a blunt ram plate
		for i in 9:
			var x0 := -r + 1.0 + i * (r * 2.0 - 2.0) / 9.0
			var wd := (r * 2.0 - 2.0) / 9.0
			st.draw_colored_polygon(PackedVector2Array([Vector2(x0, bot - 1), Vector2(x0 + wd * 0.6, bot - 1), Vector2(x0 + wd, bot - 4), Vector2(x0 + wd * 0.4, bot - 4)]), HAZARD if i % 2 == 0 else Color.BLACK)
		box(st, Rect2(-5, bot - 7, 10, 3), dark.lightened(0.15))
	if t >= 4:                                                    # an embossed shield with a brass boss
		kite(st, Vector2(0, top + h * 0.4), 10.0, 12.0, col.darkened(0.15), dark)
		st.draw_circle(Vector2(0, top + h * 0.4), 2.2, Color.BLACK)
		st.draw_circle(Vector2(0, top + h * 0.4), 1.7, BRASS_DARK)
	if t >= 5:                                                    # polished plates: a gleam sweeps across
		var u := fposmod(age / 2.0, 1.0)
		var gx := lerpf(-r - 6.0, r + 6.0, u)
		var q := PackedVector2Array([Vector2(gx - 3, top), Vector2(gx + 2, top), Vector2(gx - 2, bot), Vector2(gx - 7, bot)])
		var clipped := Geometry2D.intersect_polygons(q, PackedVector2Array([Vector2(-r, top), Vector2(r, top), Vector2(r, bot), Vector2(-r, bot)]))
		for poly_pts in clipped:
			st.draw_colored_polygon(poly_pts, Color(1, 1, 1, 0.5))
		for sx in [-1.0, 1.0]:                                    # chamfered corners
			st.draw_colored_polygon(PackedVector2Array([Vector2(sx * r, top), Vector2(sx * (r - 3), top), Vector2(sx * r, top + 3)]), Color(1, 1, 1, 0.35))
	# thorns: spikes, then curved blades
	if thorns > 0.0 and t >= 2:
		for i in 5:
			var x3 := -r + 3.0 + i * (r * 2.0 - 6.0) / 4.0
			if t >= 5:
				st.draw_colored_polygon(PackedVector2Array([Vector2(x3 - 2, top), Vector2(x3 - 1, top - 4), Vector2(x3 + 2, top - 7), Vector2(x3 + 1, top - 3), Vector2(x3 + 2, top)]), Color(0.85, 0.9, 0.97))
			else:
				st.draw_colored_polygon(PackedVector2Array([Vector2(x3 - 2, top), Vector2(x3, top - 5), Vector2(x3 + 2, top)]), Color(0.75, 0.9, 0.4))
	if t >= 6:                                                    # gold trim, runes, and the bell
		st.draw_rect(Rect2(-r, top, r * 2.0, h), Color(1.0, 0.85, 0.4, 0.9), false, 1.0)
		for cx in [-r + 2.5, r - 2.5]:
			st.draw_circle(Vector2(cx, top + 2.5), 1.0, Color(1.0, 0.85, 0.4))
		for i in 3:
			SpellArt.diamond(st, Vector2((i - 1) * 7.0, top + h * 0.78), 1.8, Color(0.7, 0.9, 1.0, 0.4 + 0.5 * sin(age * 3.0 + i)))
		var glow: float = clampf((st.charge - 0.9) * 10.0, 0.0, 1.0)
		var rot := sin(age * 2.0) * 0.1
		var o := Vector2(0, top - 15.0)
		var pts := PackedVector2Array()
		for p in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(3, 1.5), Vector2(4, 4), Vector2(5, 8), Vector2(7, 12), Vector2(-7, 12), Vector2(-5, 8), Vector2(-4, 4), Vector2(-3, 1.5)]:
			pts.append(o + p.rotated(rot))
		var bell_col := BRASS_DARK.lerp(Color.WHITE, glow)
		st.draw_colored_polygon(pts, bell_col)
		var closed := pts.duplicate()
		closed.append(pts[0])
		st.draw_polyline(closed, Color.BLACK, 1.0)
		st.draw_line(o + Vector2(-5.5, 9.0).rotated(rot), o + Vector2(5.5, 9.0).rotated(rot), Color(0.6, 0.45, 0.15), 1.5)
		st.draw_circle(o + Vector2(0, 13.5 + 1.0 * sin(age * 4.0)).rotated(rot), 1.6, Color.BLACK)
		st.draw_line(o + Vector2(0, 0), o + Vector2(0, 12.5).rotated(rot), Color(0.3, 0.3, 0.3, 0.5), 1.0)
		if glow > 0.0:
			st.draw_circle(o + Vector2(0, 6.0), 9.0 + 3.0 * glow, Color(1.0, 0.95, 0.7, 0.25 * glow))
	hp_bar(st, bot + 3.0, r, t >= 6)

# ---------------------------------------------------------------- Frost Totem
const DEEP := Color(0.25, 0.45, 0.8)
const SNOW := Color(0.95, 0.98, 1.0)
const AURORA := Color(0.5, 1.0, 0.8)
const VIOLET := Color(0.6, 0.5, 1.0)

## An ice crystal: a tall six-sided prism with a white highlight.
static func ice_prism(st, p: Vector2, h: float, w: float, col: Color) -> void:
	st.draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(-w, -h * 0.7), p + Vector2(0, -h), p + Vector2(w, -h * 0.7), p + Vector2(w, 0)]), col)
	st.draw_polyline(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(-w, -h * 0.7), p + Vector2(0, -h), p + Vector2(w, -h * 0.7), p + Vector2(w, 0)]), Color(0.2, 0.3, 0.5, 0.9), 1.0)
	st.draw_line(p + Vector2(-w * 0.3, -1), p + Vector2(-w * 0.3, -h * 0.7), Color(1, 1, 1, 0.8), 1.0)

static func draw_frost_totem(st, col: Color) -> void:
	var r: float = st.radius
	var t: int = st.tier
	var age: float = st._age
	var pulse := 0.5 + 0.5 * sin(age * 3.0)
	if t >= 6:                                                    # an aurora curtain behind
		for k in 2:
			var pts := PackedVector2Array()
			for i in 13:
				var x := -r * 0.8 + i * r * 1.6 / 12.0
				pts.append(Vector2(x, -22.0 - k * 6.0 + 4.0 * sin(age * 0.8 + i * 0.7 + k * 2.0)))
			st.draw_polyline(pts, Color(AURORA if k == 0 else VIOLET, 0.3), 5.0)
	elif t >= 5:                                                  # thin aurora arcs above
		for k in 2:
			st.draw_arc(Vector2(0, -6), 22.0 + k * 6.0, PI * 1.15, PI * 1.85, 16, Color(AURORA if k == 0 else VIOLET, 0.3), 2.0)
	st.draw_circle(Vector2.ZERO, r, Color(col, 0.07 + 0.05 * pulse))
	st.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col, 0.35), 1.0)
	if t >= 4:                                                    # a second ring with glowing runes
		st.draw_arc(Vector2.ZERO, r * 0.75, 0, TAU, 32, Color(col, 0.25), 1.0)
		for i in 6:
			var a := age * 0.3 + i * TAU / 6.0
			st.draw_circle(Vector2.from_angle(a) * r * 0.75, 1.3, Color(0.8, 0.95, 1.0, 0.5 + 0.4 * sin(age * 3.0 + i)))
		var shown := 0
		for e in st.get_tree().get_nodes_in_group("enemy"):         # a pale ring on whoever is chilled
			if shown < 20 and is_instance_valid(e) and e.global_position.distance_to(st.global_position) <= r:
				st.draw_arc(e.global_position - st.global_position, 7.0, 0, TAU, 12, Color(0.8, 0.95, 1.0, 0.6), 1.0)
				shown += 1
	if t >= 2:                                                    # falling snow
		for i in 8:
			var p := fposmod(age * 0.25 + SpellArt.jit(i, 7.0), 1.0)
			var a2 := SpellArt.jit(i, 8.0) * TAU
			var rr := r * 0.85 * sqrt(SpellArt.jit(i, 9.0))
			st.draw_circle(Vector2(cos(a2) * rr, sin(a2) * rr * 0.6 - 14.0 + p * 18.0), 0.9, Color(1, 1, 1, 0.8 * (1.0 - p)))
	if t >= 5:                                                    # a small storm: spiral arms and swirling snow
		for k in 3:
			var a3 := age * 0.9 + k * TAU / 3.0
			st.draw_arc(Vector2.ZERO, r * 0.42, a3, a3 + 1.4, 10, Color(SNOW, 0.4), 1.5)
			st.draw_arc(Vector2.ZERO, r * 0.28, a3 + 0.8, a3 + 2.0, 8, Color(SNOW, 0.3), 1.0)
		for i in 14:
			var a4 := age * (0.8 + 0.4 * SpellArt.jit(i, 2.0)) + i * 0.9
			var rr2 := r * (0.15 + 0.3 * SpellArt.jit(i, 3.0))
			st.draw_circle(Vector2.from_angle(a4) * rr2 * Vector2(1.0, 0.7), 0.9, Color(1, 1, 1, 0.7))
		st.draw_arc(Vector2.ZERO, r + 4.0, 0, TAU, 40, Color(0.5, 0.9, 1.0, 0.5 + 0.2 * sin(age * 3.0)), 1.5)
	if t >= 6:                                                    # piled ice blocks at the base
		for i in 3:
			var bx := -6.0 + i * 6.0
			st.draw_rect(Rect2(bx - 3.0, 4.0 + (1.0 if i == 1 else 0.0), 6, 5), Color.BLACK)
			st.draw_rect(Rect2(bx - 2.2, 4.8 + (1.0 if i == 1 else 0.0), 4.4, 3.6), Color(0.7, 0.9, 1.0))
	if t >= 2:                                                    # six ice crystals round the base
		for i in 6:
			var ca := SpellArt.jit(i, 11.0) * TAU
			var cp := Vector2(cos(ca) * 9.0, 5.0 + sin(ca) * 3.5)
			ice_prism(st, cp, 6.0 + 3.0 * SpellArt.jit(i, 12.0), 1.8, Color(0.7, 0.9, 1.0))
	if t >= 3:                                                    # three ice spears stand behind the head
		for i in 3:
			var ang := -PI / 2.0 + (i - 1) * 0.5
			var grow := 1.0 if i != 1 else clampf(st.fx_pulse, 0.0, 1.0)
			if grow < 0.05:
				continue
			var d := Vector2.from_angle(ang)
			var base := Vector2(0, -12) + d * 4.0
			var tip := base + d * 16.0 * grow
			var n2 := d.orthogonal() * 1.8
			st.draw_colored_polygon(PackedVector2Array([base, base + d * 5.0 * grow + n2, tip, base + d * 5.0 * grow - n2]), Color(0.75, 0.93, 1.0))
			st.draw_line(base, tip, Color(1, 1, 1, 0.8), 1.0)
	# the pole
	st.draw_rect(Rect2(-3, -9, 6, 16), Color.BLACK)
	st.draw_rect(Rect2(-2, -8, 4, 14), col.darkened(0.2))
	if t >= 2:
		for i in 4:
			st.draw_line(Vector2(-2, -6 + i * 3.0), Vector2(-0.5, -5 + i * 3.0), Color(1, 1, 1, 0.8), 1.0)
	# the head: round, then a faceted gem, then glowing deep blue
	var hy := -11.0
	if t == 1:
		st.draw_circle(Vector2(0, hy), 4.0, col)
	else:
		var gem := PackedVector2Array()
		for i in 6:
			gem.append(Vector2(0, hy) + Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * 5.0)
		st.draw_colored_polygon(gem, DEEP.lerp(col, 0.4) if t >= 5 else col)
		gem.append(gem[0])
		st.draw_polyline(gem, Color.BLACK, 1.0)
		st.draw_line(Vector2(-2, hy - 1), Vector2(0, hy - 3), Color(1, 1, 1, 0.8), 1.0)
		st.draw_line(Vector2(0, hy - 3), Vector2(2, hy - 1), Color(1, 1, 1, 0.5), 1.0)
		if t >= 4:
			SpellArt.snowflake(st, Vector2(0, hy), 3.5, 0.0, 6, 1, Color(0.2, 0.35, 0.6, 0.9), 1.0)
		if t >= 5:
			st.draw_circle(Vector2(0, hy), 6.5 + pulse, Color(0.5, 0.8, 1.0, 0.25))
			st.draw_circle(Vector2(0, hy), 1.5, Color.WHITE)
		st.draw_arc(Vector2(0, hy - 1.0), 5.6, PI * 1.15, PI * 1.85, 8, SNOW, 2.0)        # a snowcap
	if t >= 4:                                                    # frozen breath
		for i in 3:
			var p2 := fposmod(age * 0.5 + i / 3.0, 1.0)
			st.draw_circle(Vector2(sin(p2 * 6.0 + i) * 2.0, hy - 6.0 - p2 * 14.0), 1.5 + p2 * 3.0, Color(1, 1, 1, 0.5 * (1.0 - p2)))
	if t >= 6:                                                    # a crown of icicles and a turning snowflake halo
		for i in 7:
			var a5 := -PI + (i + 0.5) * PI / 7.0
			var d2 := Vector2.from_angle(a5)
			var b := Vector2(0, hy) + d2 * 4.5
			st.draw_colored_polygon(PackedVector2Array([b + d2.orthogonal() * 1.4, b + d2 * 8.0, b - d2.orthogonal() * 1.4]), Color(0.8, 0.95, 1.0))
		SpellArt.snowflake(st, Vector2(0, hy - 6.0), 12.0, age * 0.5, 6, 2, Color(0.85, 0.97, 1.0, 0.8), 1.0)
	if st.charge > 0.9 and t >= 6:                                # absolute zero is about to fall
		st.draw_arc(Vector2.ZERO, r * (1.0 - (st.charge - 0.9) * 2.0), 0, TAU, 36, Color(1, 1, 1, 0.6), 1.5)

# ---------------------------------------------------------------- Ember Turret
const EM_IRON := Color(0.3, 0.3, 0.34)
const EM_GLOW := Color(1.0, 0.75, 0.3)
const WHITE_HOT := Color(1.0, 0.96, 0.8)
const ASH := Color(0.2, 0.12, 0.1)

## A tube from `a` along `dir` with a black edge.
static func tube(st, a: Vector2, dir: Vector2, len: float, w: float, fill: Color) -> void:
	var n := dir.orthogonal() * w * 0.5
	poly(st, PackedVector2Array([a + n, a + dir * len + n * 1.15, a + dir * len - n * 1.15, a - n]), fill)

static func draw_ember_turret(st, col: Color) -> void:
	var t: int = st.tier
	var age: float = st._age
	var dir := facing(st)
	var perp := dir.orthogonal()
	var od: bool = st.overdrive
	var head := Vector2(0, -5.0)
	var kick: float = (3.0 if t >= 3 else 0.0) * clampf(st.shot_t / 0.12, 0.0, 1.0)
	var flick := 0.8 + 0.2 * sin(age * 11.0)
	if t >= 2:                                                    # an orange glow on the base
		st.draw_circle(Vector2(0, 3), 11.0, Color(1.0, 0.5, 0.1, 0.16 + (0.15 if od else 0.0)))
	if t >= 6:                                                    # wings of heat
		for sx in [-1.0, 1.0]:
			var fan := PackedVector2Array([Vector2(sx * 6, -2), Vector2(sx * 17, -12 + 2.0 * sin(age * 3.0)), Vector2(sx * 20, -4), Vector2(sx * 17, 4), Vector2(sx * 6, 3)])
			st.draw_colored_polygon(fan, Color(1.0, 0.5, 0.15, 0.3))
			st.draw_polyline(fan, Color(1.0, 0.7, 0.3, 0.5), 1.0)
	box(st, Rect2(-7, -3, 14, 10), col.darkened(0.45) if t < 2 else EM_IRON.lightened(0.1))
	if t >= 4:                                                    # soot streaks
		for i in 3:
			st.draw_line(Vector2(-5 + i * 4.0, -2), Vector2(-5 + i * 4.0 + 1.0, 4.0 + i), Color(ASH, 0.6), 1.0)
	if t >= 2:                                                    # flame vents on the sides
		for sx in [-1.0, 1.0]:
			var vb := Vector2(sx * 6.5, 0.0)
			SpellArt.flame(st, vb, 4.0, (5.0 + (4.0 if od else 0.0)) * flick, Color(1.0, 0.45, 0.1, 0.9), sx * sin(age * 7.0))
			SpellArt.flame(st, vb, 2.4, (3.0 + (3.0 if od else 0.0)) * flick, Color(1.0, 0.85, 0.4), sx * sin(age * 8.0))
			if t >= 6 and od:
				SpellArt.flame(st, vb + Vector2(sx * 1.5, 0), 3.0, 8.0 * flick, Color(1.0, 0.6, 0.2, 0.8), sx * sin(age * 9.0 + 1.0))
	var hc := head - dir * kick
	if t == 1:
		st.draw_circle(head, 5.5, Color.BLACK)
		st.draw_circle(head, 4.5, col)
	elif t >= 6:                                                  # a dragon head with jaws, horns and fiery eyes
		var open: float = 0.5 if st.shot_t > 0.0 or od else 0.15
		st.draw_circle(hc, 6.0, Color.BLACK)
		st.draw_circle(hc, 5.0, EM_IRON.lightened(0.15))
		for sd: float in [-1.0, 1.0]:
			var jaw_dir := dir.rotated(sd * open)
			poly(st, PackedVector2Array([hc + perp * sd * 2.0, hc + jaw_dir * 10.0 + perp * sd * 0.5, hc + jaw_dir * 6.0 - perp * sd * 1.0]), EM_IRON.lightened(0.05) if !od else Color(1.0, 0.75, 0.5))
			var horn_b: Vector2 = hc + perp * sd * 3.5 - dir * 2.0
			st.draw_colored_polygon(PackedVector2Array([horn_b + perp * sd * 1.0, horn_b - dir * 6.0 + perp * sd * 4.0, horn_b - dir * 1.5 - perp * sd * 1.0]), Color(0.75, 0.72, 0.65))
			st.draw_circle(hc + dir * 2.0 + perp * sd * 2.0, 1.1, WHITE_HOT)
		if od or st.shot_t > 0.0:
			st.draw_circle(hc + dir * 9.0, 3.0 + 2.0 * flick, Color(1.0, 0.6, 0.2, 0.7))
	else:
		# a squat iron mortar (from tier 3 a thick tube angled up, with a brass band)
		var barrel_len := 9.0 if t == 2 else 11.0
		var barrel_w := 5.0 if t == 2 else 6.0
		st.draw_circle(hc, 4.5, Color.BLACK)
		st.draw_circle(hc, 3.7, EM_IRON.lightened(0.1))
		if t >= 5:                                                # a cluster pack: three narrow tubes in a fan
			for k in [-1, 0, 1]:
				var d2 := dir.rotated(k * 0.35)
				tube(st, hc, d2, 10.0, 3.0, EM_IRON)
				st.draw_circle(hc + d2 * 10.0, 1.8, Color(1.0, 0.5, 0.15, 0.9))
		else:
			tube(st, hc, dir, barrel_len, barrel_w, EM_IRON if !od else WHITE_HOT)
			if t >= 3:
				st.draw_line(hc + dir * 4.0 + perp * 3.0, hc + dir * 4.0 - perp * 3.0, Color(0.85, 0.7, 0.3), 1.6)
			st.draw_circle(hc + dir * barrel_len, 3.5 + (0.6 if t >= 2 else 0.0), Color(1.0, 0.55, 0.15, (0.55 + 0.35 * sin(age * 6.0)) if st.shot_t <= 0.0 else 1.0))
			st.draw_circle(hc + dir * barrel_len, 1.8, EM_GLOW)
		if t >= 5:                                                # the glow ring is doubled
			st.draw_arc(hc + dir * 10.0, 5.5, 0, TAU, 14, Color(1.0, 0.55, 0.15, 0.5), 1.0)
	if t >= 3 and t < 6:                                          # a rack of shells beside it
		for k in 3 if t == 3 else 2:
			var sp := Vector2(-11.0, -2.0 + k * 3.5)
			st.draw_line(sp, sp + Vector2(4, 0), Color.BLACK, 3.0)
			st.draw_line(sp, sp + Vector2(3, 0), Color(0.45, 0.4, 0.35), 1.8)
			st.draw_circle(sp + Vector2(3.5, 0), 1.2, Color(1.0, 0.5, 0.15))
		if t >= 4:                                                # ... and a bigger golden shell, and the heat gauge
			st.draw_line(Vector2(-11, 5.5), Vector2(-5, 5.5), Color.BLACK, 3.6)
			st.draw_line(Vector2(-11, 5.5), Vector2(-6, 5.5), Color(0.9, 0.75, 0.3), 2.4)
			var gc := Vector2(11.0, 1.5)
			st.draw_circle(gc, 3.6, Color.BLACK)
			st.draw_circle(gc, 2.9, Color(0.85, 0.85, 0.8))
			st.draw_arc(gc, 2.4, PI * 0.8, PI * 2.2, 8, Color(1.0, 0.3, 0.1, 0.7), 1.0)
			var na: float = PI * 0.8 + st.charge * PI * 1.4
			st.draw_line(gc, gc + Vector2.from_angle(na) * 2.5, Color.BLACK, 1.0)
	if t >= 5:                                                    # heat shimmer over the barrel
		for j in 2:
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(head + dir * (8.0 + i * 2.0) + perp * (-2.0 + j * 4.0 + 1.0 * sin(age * 5.0 + i + j)) + Vector2(0, -3.0 - i * 1.0))
			st.draw_polyline(pts, Color(1.0, 0.8, 0.5, 0.22), 1.0)
	if t >= 6:
		st.draw_arc(Vector2(0, -4), 14.0 + 1.5 * sin(age * 4.0), 0, TAU, 20, Color(1.0, 0.6, 0.2, 0.25), 1.0)
	if st.shot_t > 0.0:                                           # the shot
		var to: Vector2 = st.shot_to - st.global_position
		st.draw_line(hc + dir * 9.0, to, Color(1.0, 0.7, 0.3, 0.9), 2.0 if t == 1 else 3.0)
		st.draw_line(hc + dir * 9.0, to, Color(1.0, 0.95, 0.8, 0.9), 1.0)
