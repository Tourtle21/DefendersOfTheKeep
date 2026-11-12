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
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine":
			return AC.draw(st, col)
		"barricade":
			draw_barricade(st, col)
			return true
		"spike_trap":
			draw_spike_trap(st, col)
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
