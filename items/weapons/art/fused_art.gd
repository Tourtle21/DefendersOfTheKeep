extends RefCounted
## Per-tier art of the FUSED weapons (see weapon_tier_art.gd). Each weapon is its own picture drawn from scratch with the Paint kit,
## `func draw_<id>(p: Paint, t: int) -> void` (t = 1..6); it never composes its parents' icons: every fusion is ONE new weapon with one
## silhouette that only borrows ideas from its parents.
## A fusion's tier starts at its recipe tier (Fusion.tier_of) and goes up with the copy's bonus, so only tiers tier_of..6 ever occur.
## `_s(id, t)` is the STAGE: 1 at the weapon's first possible tier, +1 per tier. Parts are added by stage (stage 2 keeps everything of
## stage 1, and so on); the lowest tiers below the recipe tier draw as stage 1.
const Paint = preload("res://items/weapons/art/weapon_paint.gd")

# ------------------------------------------------------------------------------------------------------------------ shared bits

func _s(id: String, t: int) -> int:
	return maxi(1, t - Fusion.tier_of(id) + 1)

## One symmetric row around the centre columns 15|16: `n` pixels each side, light left, dark right.
func _row(p: Paint, y: int, n: int, light: Color, dark: Color) -> void:
	for i in n:
		p.px(15 - i, y, light)
		p.px(16 + i, y, dark)

## A grip: two wooden columns from y0 to y1.
func _grip(p: Paint, y0: int, y1: int, light := Paint.WOOD_L, dark := Paint.WOOD) -> void:
	p.rect(15, y0, 16, y1, dark)
	p.rect(15, y0, 15, y1, light)

func _wrap(p: Paint, y0: int, y1: int, c: Color, step := 2) -> void:
	var y := y0
	while y <= y1:
		p.px(15, y, c)
		p.px(16, y + 1, c)
		y += step

## A straight blade/lance tip from a (base) to b (tip) of half width w at the base: left half light, right half dark.
func _tri(p: Paint, a: Vector2, b: Vector2, w: float, light: Color, dark: Color) -> void:
	var n := (b - a).normalized().orthogonal() * w
	p.poly(PackedVector2Array([a + n, a - n, b]), dark)
	p.poly(PackedVector2Array([a + n, a, b]), light)

## A thick curve through the points (a poly-line), drawn with a round pen of `th` pixels.
func _curve(p: Paint, pts: Array, c: Color, th := 1) -> void:
	for i in pts.size() - 1:
		p.line(pts[i], pts[i + 1], c, th)

## A tapering curved horn/claw: a quadratic curve from a to b bent toward c, half width w0 at the base down to a point.
func _swoop(p: Paint, a: Vector2, c: Vector2, b: Vector2, w0: float, light: Color, dark: Color) -> void:
	var steps := 28
	for pass_i in 2:
		for i in steps + 1:
			var u := float(i) / steps
			var q := a.lerp(c, u).lerp(c.lerp(b, u), u)
			var w := maxf(0.5, w0 * (1.0 - u))
			if pass_i == 0:
				p.disc(q.x, q.y, w, dark)
			elif w >= 1.0:
				p.disc(q.x - 0.5, q.y - 0.4, w * 0.62, light)

## Pommel / collar: a gold band of width 2*n across the shaft at row y with a dark base line.
func _band(p: Paint, y: int, n: int, c := Paint.GOLD, d := Paint.GOLD_D) -> void:
	p.rect(16 - n, y, 15 + n, y, c)
	p.rect(16 - n, y + 1, 15 + n, y + 1, d)

# ---------------------------------------------------------------------------------------------------------------------------------
# CHAIN FANGS (daggers + whip): a hilt, a swaying iron chain and a head of curved fangs at the end of it.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_chainfangs(p: Paint, t: int) -> void:
	var s := _s("chainfangs", t)
	var link := Paint.IRON if s < 5 else Paint.GOLD
	var link_l := Paint.STEEL_L if s < 5 else Paint.GOLD_L
	var link_d := Paint.IRON_D if s < 5 else Paint.GOLD_D
	# the hilt with a ring pommel and a guard
	_grip(p, 25, 29)
	_wrap(p, 26, 29, Paint.WOOD_D)
	p.ring(15.5, 30.0, 2.2, 1.2, Paint.GOLD)
	p.rect(13, 23, 18, 24, Paint.IRON_D)
	p.rect(13, 23, 18, 23, Paint.STEEL)
	if s >= 3:
		p.rect(12, 23, 19, 23, Paint.GOLD)
		p.px(12, 24, Paint.GOLD_D)
		p.px(19, 24, Paint.GOLD_D)
	# the chain: links sway from the hilt up to the head
	var top := 12
	var y := 22
	var i := 0
	while y >= top:
		var x := 15 + int(roundf(sin(float(i) * 1.1) * 2.0))
		if i % 2 == 0:                          # a flat link (hollow) then an edge-on one
			p.rect(x - 1, y - 1, x + 2, y + 1, link)
			p.rect(x, y, x + 1, y, Paint.IRON_D)
			p.px(x - 1, y - 1, link_l)
			p.px(x + 2, y + 1, link_d)
		else:
			p.rect(x, y - 2, x + 1, y + 1, link)
			p.px(x, y - 2, link_l)
			p.px(x + 1, y + 1, link_d)
		if s >= 4 and i % 2 == 1:              # barbs on the links
			p.px(x - 1, y - 1, Paint.STEEL_L)
			p.px(x + 2, y, Paint.STEEL_L)
		y -= 3
		i += 1
	# the fangs: curved claws like horns
	var tip_y := 2.0 if s < 4 else 0.0
	var w := 2.6 if s < 4 else 3.2
	if s == 1:
		_swoop(p, Vector2(16, 11), Vector2(10, 4), Vector2(19, tip_y), w, Paint.STEEL, Paint.STEEL_D)
	else:
		_swoop(p, Vector2(17, 11), Vector2(25, 7), Vector2(23, tip_y), w, Paint.STEEL, Paint.STEEL_D)
		_swoop(p, Vector2(15, 11), Vector2(7, 7), Vector2(9, tip_y), w, Paint.STEEL, Paint.STEEL_D)
	if s >= 3:
		p.rect(13, 10, 18, 11, Paint.GOLD)
		p.rect(13, 11, 18, 11, Paint.GOLD_D)
		_tri(p, Vector2(16, 10), Vector2(16, 2), 2.0, Paint.STEEL_L, Paint.STEEL)
	if s >= 4:
		p.gem(15.5, 9.5, 1.5, Color("e03050"))
		for yy in [4, 7]:
			p.px(7, yy + 1, Paint.CLEAR)
			p.px(24, yy + 1, Paint.CLEAR)
	if s >= 5:
		for a in 5:
			var q := Vector2(16, 11) + Vector2.from_angle(PI + a * PI / 4.0) * 5.5
			p.px(int(q.x), int(q.y), Paint.GOLD_L)
		p.px(16, 0, Paint.WHITE)

# ---------------------------------------------------------------------------------------------------------------------------------
# RAPIER (daggers + spear): a long needle blade, a swept guard that grows into a full cup-hilt.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_rapier(p: Paint, t: int) -> void:
	var s := _s("rapier", t)
	var bell := s >= 3
	var gy := 26 if bell else 24       # the guard's row
	# grip and pommel
	_grip(p, gy + 2, 29, Paint.WOOD_L, Paint.WOOD)
	_wrap(p, gy + 2, 29, Paint.WOOD_D)
	p.disc(16.0, 30.0, 2.0, Paint.GOLD if s < 4 else Paint.GOLD_L)
	if s >= 4:
		p.gem(15.5, 30.0, 1.4, Color("e03050"))
	# guard
	if s == 1:
		p.rect(10, gy, 21, gy + 1, Paint.GOLD)
		p.rect(10, gy + 1, 21, gy + 1, Paint.GOLD_D)
	else:
		# swept quillons curving down at the ends
		for side in [-1, 1]:
			for k in 7:
				var x: int = (16 + k) if side > 0 else (15 - k)
				var y := gy + (k * k) / 14
				p.px(x, y, Paint.GOLD)
				p.px(x, y + 1, Paint.GOLD_D)
		p.rect(13, gy, 18, gy + 1, Paint.GOLD)
	if bell:                                         # a bell (cup) guard: it widens downward round the hand
		var widths := [3, 5, 6, 7, 7, 6]
		for k in widths.size():
			var n: int = widths[k]
			_row(p, gy - 3 + k, n, Paint.GOLD, Paint.GOLD_D)
			p.px(16 - n, gy - 3 + k, Paint.GOLD_L)
		p.rect(14, gy - 2, 17, gy + 1, Paint.IRON_D)
		p.rect(9, gy + 2, 22, gy + 2, Paint.GOLD_D)
	if s >= 4:                                       # knuckle bow
		_curve(p, [Vector2(21, gy + 1), Vector2(24, gy + 3), Vector2(22, 29), Vector2(18, 29)], Paint.GOLD, 1)
	if s >= 5:
		for sx in [7, 24]:
			p.px(sx, gy - 2, Paint.GOLD_L)
			p.px(sx, gy - 1, Paint.GOLD)
		p.line(Vector2(9, gy + 3), Vector2(12, gy + 5), Paint.RED, 1)
		p.px(12, 29, Paint.RED)
	# the blade: a needle, wider and fluted with the tier
	var wide := 1 if s == 1 else 2
	for y in range(0, gy - 1):
		var n := 1
		if y > gy - 8 and wide == 2:
			n = 2
		_row(p, y, n, Paint.STEEL if y > 1 else Paint.STEEL_L, Paint.STEEL_D)
	if s >= 2:
		for y in range(4, gy - 2):
			p.px(15, y, Paint.STEEL_L)
	if s >= 4:
		for y in range(6, gy - 2, 3):
			p.px(16, y, Paint.GOLD)
	if s >= 5:
		p.px(15, 0, Paint.WHITE)
		p.px(16, 1, Paint.GOLD_L)

# ---------------------------------------------------------------------------------------------------------------------------------
# SIEGE LANCE (hammer + spear): a long shaft, an iron cone head with hammer flanges, a vamplate hand guard.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_lance(p: Paint, t: int) -> void:
	var s := _s("lance", t)
	_grip(p, 16, 30)
	_wrap(p, 24, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON)
	p.rect(14, 29, 17, 29, Paint.STEEL_L)
	# the long cone head, longer and wider with the tier
	var top := 2 if s < 4 else 0
	var wmax := 3.0 if s < 4 else 4.0
	for y in range(top, 15):
		var u := float(y - top) / float(14 - top)
		var n := 1 + int(u * wmax)
		_row(p, y, n, Paint.STEEL if y > top else Paint.STEEL_L, Paint.STEEL_D)
		if y > top + 2:
			p.px(15, y, Paint.STEEL_L)
	# hammer flanges at the base of the head
	p.rect(10, 15, 21, 16, Paint.IRON_D)
	p.rect(10, 15, 21, 15, Paint.IRON)
	if s >= 2:                                    # a round vamplate hand guard
		p.disc(15.5, 22.0, 6.0, Paint.IRON)
		p.disc(15.5, 22.0, 4.6, Paint.IRON_D)
		p.disc(15.0, 21.5, 3.0, Paint.IRON)
		p.disc(15.5, 22.0, 1.2, Paint.GOLD)
	if s >= 3:                                    # studs on the flanges, a red pennant
		for x in [11, 14, 17, 20]:
			p.px(x, 16, Paint.STEEL_L)
		for k in 7:
			var fy := 9 + int(sin(k * 0.9) * 1.2) + k / 3
			p.px(18 + k, fy, Paint.RED)
			p.px(18 + k, fy + 1, Paint.RED.darkened(0.25))
		for k in 8:
			var a := k * TAU / 8.0
			var q := Vector2(15.5, 22.0) + Vector2.from_angle(a) * 5.4
			p.px(int(q.x), int(q.y), Paint.STEEL_L)
	if s >= 4:                                    # a gold-rimmed guard, a gem, fins either side of the head
		p.ring(15.5, 22.0, 6.0, 1.2, Paint.GOLD)
		p.gem(15.5, 22.0, 1.8, Color("e03050"))
		_band(p, 17, 2)
		p.rect(9, 11, 9, 15, Paint.STEEL)
		p.rect(22, 11, 22, 15, Paint.STEEL_D)
		p.px(9, 10, Paint.STEEL_L)
		p.px(22, 10, Paint.STEEL)
	if s >= 5:                                    # bigger gold guard with spikes, winged flanges, a golden spiral on the shaft
		p.ring(15.5, 22.0, 7.0, 1.4, Paint.GOLD_L)
		for k in 8:
			var a := k * TAU / 8.0 + TAU / 16.0
			var q := Vector2(15.5, 22.0) + Vector2.from_angle(a) * 8.0
			p.px(int(q.x), int(q.y), Paint.GOLD)
		for k in 5:
			p.px(8 - k / 2, 14 - k, Paint.STEEL if k % 2 == 0 else Paint.STEEL_L)
			p.px(23 + k / 2, 14 - k, Paint.STEEL_D)
		_wrap(p, 27, 28, Paint.GOLD, 2)

# ---------------------------------------------------------------------------------------------------------------------------------
# QUAKE PICK (hammer + pickaxe): a crescent pick head with a hammer block; cracks, crystals and spikes as it grows.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_quakepick(p: Paint, t: int) -> void:
	var s := _s("quakepick", t)
	var rock := Color("8a7a66")
	var rock_d := Color("5c5043")
	_grip(p, 9, 30)
	_wrap(p, 17, 28, Paint.WOOD_D)
	# the crescent head, thicker with the tier
	var th := 3 if s < 3 else 4
	for x in range(2, 30):
		var u := (x - 15.5) / 13.5
		var y := 3 + int(u * u * 8.0)
		for k in th:
			p.px(x, y + k, Paint.IRON if k == 0 else (Paint.IRON_D if k == th - 1 else Paint.IRON))
		p.px(x, y, Paint.STEEL_L if x < 16 else Paint.STEEL)
	# the socket
	p.rect(13, 6, 18, 9, Paint.IRON_D)
	p.rect(13, 6, 18, 6, Paint.IRON)
	if s >= 2:                                    # the hammer block that makes it a quake pick
		p.rect(11, 1, 20, 8, rock)
		p.rect(11, 1, 20, 1, Paint.STEEL_L)
		p.rect(11, 7, 20, 8, rock_d)
		p.rect(11, 1, 11, 8, Paint.IRON)
		p.rect(20, 1, 20, 8, Paint.IRON_D)
	if s >= 3:                                    # the tips are cut into hooked claws, rivets in the block
		for side in [-1, 1]:
			var x := 2 if side < 0 else 29
			p.px(x, 11, Paint.STEEL_L)
			p.px(x, 12, Paint.STEEL)
			p.px(x + (1 if side < 0 else -1), 13, Paint.IRON_D)
		p.px(12, 2, Paint.STEEL_L)
		p.px(19, 2, Paint.STEEL_L)
	if s >= 4:                                    # glowing fissures run through the block and head
		var lava := Color("ff8a2a")
		var lava_l := Color("ffd23a")
		p.line(Vector2(15, 2), Vector2(14, 5), lava, 1)
		p.line(Vector2(17, 3), Vector2(18, 7), lava, 1)
		p.px(15, 6, lava_l)
		for x in [6, 25]:
			p.px(x, 7, lava)
		_band(p, 10, 2)
		_band(p, 26, 2)
	if s >= 5:                                    # amber crystals at both tips and spikes on the butt
		for side in [-1, 1]:
			var cx := 4.0 if side < 0 else 27.0
			p.gem(cx, 8.0, 2.0, Color("ffb02a"))
			p.px(int(cx), 5, Paint.STEEL_L)
		p.gem(15.5, 4.5, 1.6, Color("ffb02a"))
		p.px(14, 31, Paint.STEEL_L)
		p.px(17, 31, Paint.STEEL_L)
		p.rect(14, 29, 17, 30, Paint.IRON)

# ---------------------------------------------------------------------------------------------------------------------------------
# BULWARK MAUL (hammer + shield): a heater-shield slab for a maul head, spikes and flanges as it grows.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_bulwark(p: Paint, t: int) -> void:
	var s := _s("bulwark", t)
	var blue := Color("3b6fd0")
	var blue_l := Color("5b8ae8")
	_grip(p, 15, 30)
	_wrap(p, 22, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON)
	var rim := Paint.STEEL if s < 5 else Paint.GOLD
	var rim_d := Paint.STEEL_D if s < 5 else Paint.GOLD_D
	var top := 2 if s < 4 else 1
	var bot := 16 if s < 4 else 18
	var half := 6 if s < 4 else 7
	# the shield-shaped head
	for y in range(top, bot + 1):
		var n := half
		if y > bot - half:
			n = maxi(1, half - (y - (bot - half)))
		_row(p, y, n + 1, rim, rim_d)
		if y > top and y < bot:
			_row(p, y, n, blue_l, blue)
	p.rect(10 if half == 6 else 9, top, 21 if half == 6 else 22, top, Paint.STEEL_L)
	# the boss
	p.disc(15.5, 8.0 if s < 4 else 9.0, 2.2 if s < 2 else 2.8, Paint.GOLD if s >= 2 else Paint.IRON)
	if s >= 2:
		p.disc(15.0, 7.5, 1.0, Paint.GOLD_L)
		for k in 5:                                # rivets down the rim
			p.px(10 if half == 6 else 9, top + 2 + k * 2, Paint.STEEL_L)
			p.px(21 if half == 6 else 22, top + 2 + k * 2, Paint.STEEL_L)
	if s >= 3:                                      # hammer flanges and spikes
		p.rect(4, 6, 8, 11, Paint.IRON_D)
		p.rect(4, 6, 8, 6, Paint.IRON)
		p.rect(23, 6, 27, 11, Paint.IRON_D)
		p.rect(23, 6, 27, 6, Paint.IRON)
		for x in [9, 22]:
			p.px(x, 1, Paint.STEEL_L)
			p.px(x, 0, Paint.STEEL)
		p.px(3, 8, Paint.STEEL_L)
		p.px(28, 8, Paint.STEEL)
	if s >= 4:                                      # a gold cross, a gem boss, banded shaft
		p.rect(15, 3, 16, 15, Paint.GOLD)
		p.rect(8, 11, 23, 12, Paint.GOLD)
		p.gem(15.5, 11.0, 2.6, Color("e03050"))
		_band(p, 20, 2)
	if s >= 5:                                      # a crown of spikes, side blades, a gold wrapped shaft
		for x in range(9, 23, 3):
			p.px(x, 0, Paint.GOLD_L)
		p.px(15, 0, Paint.WHITE)
		p.px(16, 0, Paint.WHITE)
		for k in 4:
			p.px(3 - k / 2, 5 - k, Paint.STEEL_L)
			p.px(28 + k / 2, 5 - k, Paint.STEEL)
		_wrap(p, 24, 28, Paint.GOLD, 2)

# ---------------------------------------------------------------------------------------------------------------------------------
# KNIGHT'S BLADE (shield + sword): a broadsword whose guard is a small heater shield.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_knightblade(p: Paint, t: int) -> void:
	var s := _s("knightblade", t)
	var blue := Color("3b6fd0")
	var blue_l := Color("5b8ae8")
	_grip(p, 27, 29)
	p.disc(16.0, 30.5, 1.8, Paint.GOLD if s < 4 else Paint.GOLD_L)
	# the blade
	var nb := 2 if s < 2 else 3
	for y in range(0, 22):
		var n := nb
		if y < 4:
			n = maxi(1, nb - (4 - y) / 2)
		_row(p, y, n, Paint.STEEL, Paint.STEEL_D)
		if s >= 2 and y > 2:
			p.px(15, y, Paint.STEEL_L)
	p.px(15, 0, Paint.STEEL_L)
	if s >= 5:                                      # golden edge inlay
		for y in range(3, 20, 2):
			p.px(16 - nb, y, Paint.GOLD)
			p.px(15 + nb, y, Paint.GOLD_D)
	if s >= 4:                                      # a serrated top edge
		for y in range(5, 18, 4):
			p.px(16 + nb, y, Paint.CLEAR)
	# crossguard and the shield guard
	var gw := 5 if s < 3 else 7
	p.rect(16 - gw, 21, 15 + gw, 22, Paint.IRON)
	p.rect(16 - gw, 21, 15 + gw, 21, Paint.STEEL_L)
	if s >= 3:                                      # upturned wings
		p.px(16 - gw, 20, Paint.STEEL)
		p.px(15 + gw, 20, Paint.STEEL_D)
		p.px(16 - gw - 1, 19, Paint.STEEL_L)
		p.px(16 + gw, 19, Paint.STEEL)
	var sw := 3 if s < 2 else 4
	for k in 7:
		var y := 22 + k
		var n := sw if k < 4 else maxi(1, sw - (k - 3))
		_row(p, y, n, Paint.GOLD if s >= 2 else Paint.STEEL, Paint.GOLD_D if s >= 2 else Paint.STEEL_D)
		if k > 0 and k < 6:
			_row(p, y, n - 1, blue_l, blue)
	p.px(15, 24, Paint.GOLD)
	p.px(16, 24, Paint.GOLD)
	if s >= 3:
		p.gem(15.5, 24.0, 1.4, Paint.GOLD_L)
	if s >= 4:                                      # a red plume off the pommel
		for k in 4:
			p.px(18 + k, 30 + k / 2 - 1, Paint.RED)
			p.px(18 + k, 31, Paint.RED.darkened(0.25))
		p.gem(15.5, 12.0, 1.0, Color("e03050"))
	if s >= 5:                                      # a crown over the shield, filigree on the guard
		for x in [13, 15, 17, 19]:
			p.px(x - 2, 19, Paint.GOLD_L)
		p.px(15, 18, Paint.GOLD_L)
		p.px(16, 18, Paint.GOLD_L)
		p.px(7, 22, Paint.GOLD)
		p.px(24, 22, Paint.GOLD)

# ---------------------------------------------------------------------------------------------------------------------------------
# RIMELANCE (frostglaive + spear): a long icy lance, a broad glaive-ice head, crystal growth.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_rimelance(p: Paint, t: int) -> void:
	var s := _s("rimelance", t)
	var ice := Color("cfeaff")
	var ice_d := Color("8fc4ee")
	var deep := Color("5a8cc8")
	var shaft := Color("5a7a9a")
	var shaft_l := Color("8ab0d0")
	_grip(p, 14, 30, shaft_l, shaft)
	p.rect(14, 29, 17, 31, deep)
	p.rect(14, 29, 17, 29, ice)
	# the glaive head: a broad leaf, longer with the tier
	var top := 1 if s < 4 else 0
	var wmax := 4.0 if s < 3 else 5.0
	for y in range(top, 15):
		var u := float(y - top) / float(14 - top)
		var n := 1 + int(sin(minf(u * 1.15, 1.0) * PI * 0.5 + 0.0) * wmax)
		if u > 0.8:
			n = maxi(2, n - int((u - 0.8) * 10.0))
		_row(p, y, n, ice, ice_d)
		if y > top + 1:
			p.px(15, y, Color.WHITE)
			p.px(16, y, ice)
	p.rect(13, 14, 18, 15, deep)
	p.rect(13, 14, 18, 14, ice)
	if s >= 2:                                      # a ridge of frost and a collar, wraps on the shaft
		p.rect(12, 15, 19, 15, ice_d)
		for y in range(17, 28, 3):
			p.px(15, y, ice)
			p.px(16, y + 1, ice)
	if s >= 3:                                      # ice shards growing off the head
		for side in [-1, 1]:
			for k in 5:
				var x: int = (16 + 5 + k / 2) if side > 0 else (15 - 5 - k / 2)
				p.px(x, 13 - k, ice if side < 0 else ice_d)
				p.px(x - side, 13 - k, ice if side < 0 else ice_d)
	if s >= 4:                                      # a sapphire in the collar, frost bands, hanging icicles
		p.gem(15.5, 16.5, 1.6, Color("3aa0ff"))
		_band(p, 20, 2, ice, deep)
		_band(p, 25, 2, ice, deep)
		for x in [12, 14, 17, 19]:
			p.px(x, 16, ice_d)
			p.px(x, 17, ice)
	if s >= 5:                                      # big crystal wings, a snowflake at the tip
		for side in [-1, 1]:
			for k in 7:
				var x: int = (16 + 7 + k / 3) if side > 0 else (15 - 7 - k / 3)
				p.px(x, 16 - k, Color.WHITE if side < 0 else ice)
				p.px(x - side, 16 - k, ice if side < 0 else ice_d)
		p.px(15, 0, Color.WHITE)
		p.px(16, 0, Color.WHITE)
		p.px(14, 2, Color.WHITE)
		p.px(17, 2, Color.WHITE)

# ---------------------------------------------------------------------------------------------------------------------------------
# SULTAN'S GUARD (scimitar + shield): a curved blade rising out of a round buckler guard.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_sultanguard(p: Paint, t: int) -> void:
	var s := _s("sultanguard", t)
	var blue := Color("3b6fd0")
	var blue_l := Color("5b8ae8")
	_grip(p, 28, 31)
	# the blade sweeps up and to the right
	var w := 2.8 if s < 2 else (3.4 if s < 4 else 4.0)
	_swoop(p, Vector2(15, 20), Vector2(12, 8), Vector2(24, 1), w, Paint.STEEL, Paint.STEEL_D)
	for i in 20:
		var u := i / 19.0
		var q := Vector2(15, 20).lerp(Vector2(12, 8), u).lerp(Vector2(12, 8).lerp(Vector2(24, 1), u), u)
		if u > 0.1 and u < 0.85:
			p.px(int(q.x) - 1, int(q.y), Paint.STEEL_L)
	# the buckler guard
	var r := 4.4 if s < 2 else 5.4
	p.disc(15.5, 23.0, r, Paint.GOLD)
	p.disc(15.5, 23.0, r - 1.0, Paint.GOLD_D if s < 2 else blue)
	p.disc(15.0, 22.5, r - 2.0, Paint.GOLD if s < 2 else blue_l)
	p.disc(15.5, 23.0, 1.3, Paint.GOLD_L)
	if s >= 2:
		p.gem(15.5, 23.0, 1.6, Color("e03050"))
	if s >= 3:                                      # a crescent behind the guard, tassels
		p.ring(15.5, 23.0, 7.2, 1.2, Paint.GOLD)
		p.rect(5, 23, 26, 31, Paint.CLEAR)
		p.rect(9, 28, 22, 31, Paint.CLEAR)
		p.disc(15.5, 23.0, r, Paint.GOLD)
		p.disc(15.5, 23.0, r - 1.0, blue)
		p.disc(15.0, 22.5, r - 2.0, blue_l)
		p.gem(15.5, 23.0, 1.6, Color("e03050"))
		_grip(p, 28, 31)
		for k in 4:
			p.px(7, 24 + k, Paint.RED)
			p.px(24, 24 + k, Paint.RED.darkened(0.2))
	if s >= 4:                                      # a serrated back edge and a gold scalloped rim
		for k in 5:
			var q := Vector2(15, 20).lerp(Vector2(12, 8), k / 5.0 + 0.1).lerp(Vector2(12, 8).lerp(Vector2(24, 1), k / 5.0 + 0.1), k / 5.0 + 0.1)
			p.px(int(q.x) - 3, int(q.y), Paint.CLEAR)
		for k in 10:
			var a := k * TAU / 10.0
			var q := Vector2(15.5, 23.0) + Vector2.from_angle(a) * 5.6
			p.px(int(q.x), int(q.y), Paint.GOLD_L)
	if s >= 5:                                      # a plume, a gold edge on the blade, a big ruby
		for k in 5:
			p.px(22 + k, 12 + k / 2, Paint.RED)
			p.px(22 + k, 13 + k / 2, Paint.RED.darkened(0.25))
		p.gem(15.5, 23.0, 2.2, Color("ff4060"))
		p.px(24, 0, Paint.WHITE)
		p.px(23, 1, Paint.GOLD_L)

# ---------------------------------------------------------------------------------------------------------------------------------
# DRAGOON PIKE (lance + rapier): a long slim piercing head over a dragon-wing guard; horns, a flame plume at the top.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_dragoonpike(p: Paint, t: int) -> void:
	var s := _s("dragoonpike", t)
	var crim := Color("b02a20")
	var crim_d := Color("701810")
	_grip(p, 16, 30, Color("a0402c"), Color("6a2a1c"))
	_wrap(p, 18, 29, Paint.GOLD_D, 3)
	p.rect(14, 29, 17, 31, Paint.IRON)
	p.rect(14, 29, 17, 29, Paint.STEEL_L)
	# dragon wings, bigger with the tier
	var ws := 4.0 + minf(float(s), 4.0)
	for side in [-1, 1]:
		var bx := 16.0 if side > 0 else 15.0
		_swoop(p, Vector2(bx, 17), Vector2(bx + side * (ws + 3.0), 17), Vector2(bx + side * (ws + 2.0), 17.0 - ws - 2.0), 2.4 + 0.2 * s, crim, crim_d)
		if s >= 2:
			p.line(Vector2(bx + side * 1.0, 16), Vector2(bx + side * (ws + 1.0), 16.0 - ws * 0.4), Paint.GOLD, 1)
		if s >= 4:                                  # a second smaller pair above
			_swoop(p, Vector2(bx, 13), Vector2(bx + side * 6.0, 12), Vector2(bx + side * 5.0, 6), 1.6, crim, crim_d)
	# the blade: slim, a needle tip
	var top := 0
	for y in range(top, 17):
		var n := 1 if y < 12 else 2
		_row(p, y, n, Paint.STEEL, Paint.STEEL_D)
		if y > 2:
			p.px(15, y, Paint.STEEL_L)
	p.rect(13, 16, 18, 17, Paint.GOLD)
	p.rect(13, 17, 18, 17, Paint.GOLD_D)
	if s >= 3:                                      # a dragon-head collar: gold horns and an eye
		p.px(12, 15, Paint.GOLD_L)
		p.px(11, 14, Paint.GOLD)
		p.px(19, 15, Paint.GOLD_L)
		p.px(20, 14, Paint.GOLD)
		p.gem(15.5, 17.0, 1.4, Color("ffb02a"))
		for k in 4:                                 # pennant of flame
			p.px(18 + k, 21 + k / 2, Color("ff7a1a"))
			p.px(18 + k, 22 + k / 2, Color("ffd23a"))
	if s >= 4:
		for y in range(4, 12, 3):                   # barbs on the head
			p.px(14, y, Paint.STEEL_L)
			p.px(17, y, Paint.STEEL)
		p.px(15, 0, Paint.WHITE)

# ---------------------------------------------------------------------------------------------------------------------------------
# MAGMA MAUL (emberflail + hammer): a basalt maul head split by glowing lava, spikes and flames as it grows.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_magmamaul(p: Paint, t: int) -> void:
	var s := _s("magmamaul", t)
	var rock := Color("4a3434")
	var rock_l := Color("6a4a42")
	var lava := Color("ff6a1a")
	var lava_l := Color("ffd23a")
	_grip(p, 13, 30, Color("7a4a2a"), Color("4a2a18"))
	_wrap(p, 18, 29, Color("2a1810"), 2)
	p.rect(14, 29, 17, 31, Paint.IRON_D)
	var hy := 2 if s < 4 else 0
	var hx0 := 6 if s < 4 else 4
	var hx1 := 25 if s < 4 else 27
	# the head: a block with iron end caps
	p.rect(hx0, hy + 1, hx1, hy + 11, rock)
	p.rect(hx0, hy + 1, hx1, hy + 2, rock_l)
	p.rect(hx0, hy + 9, hx1, hy + 11, Color("2a1c1c"))
	p.rect(hx0, hy + 1, hx0 + 1, hy + 11, Paint.IRON_D)
	p.rect(hx1 - 1, hy + 1, hx1, hy + 11, Paint.IRON_D)
	p.rect(hx0, hy + 1, hx0, hy + 11, Paint.IRON)
	# lava cracks
	p.line(Vector2(11, hy + 2), Vector2(13, hy + 6), lava, 1)
	p.line(Vector2(13, hy + 6), Vector2(11, hy + 10), lava, 1)
	p.line(Vector2(20, hy + 2), Vector2(19, hy + 5), lava, 1)
	p.line(Vector2(19, hy + 5), Vector2(21, hy + 10), lava, 1)
	p.px(13, hy + 6, lava_l)
	p.px(19, hy + 5, lava_l)
	if s >= 2:                                      # more fissures and iron bands round the head
		p.line(Vector2(15, hy + 3), Vector2(16, hy + 8), lava, 1)
		p.px(16, hy + 6, lava_l)
		p.rect(hx0 + 2, hy + 1, hx0 + 2, hy + 11, Paint.IRON_D)
		p.rect(hx1 - 2, hy + 1, hx1 - 2, hy + 11, Paint.IRON_D)
	if s >= 3:                                      # spikes on top, molten drips under the head
		for x in [9, 13, 18, 22]:
			p.px(x, hy, rock_l)
			p.px(x, hy - 1, Paint.IRON)
		for x in [11, 17, 21]:
			p.px(x, hy + 12, lava)
			p.px(x, hy + 13, lava_l if x == 17 else lava)
	if s >= 4:                                      # horns at the sides, a gold collar, a bigger crack pattern
		p.px(hx0 - 1, hy + 4, Paint.IRON)
		p.px(hx0 - 2, hy + 3, Paint.STEEL_L)
		p.px(hx1 + 1, hy + 4, Paint.IRON)
		p.px(hx1 + 2, hy + 3, Paint.STEEL_L)
		_band(p, 14, 2)
		p.px(8, hy + 5, lava)
		p.px(24, hy + 6, lava)
	if s >= 5:                                      # a molten heart, flames licking off the top
		p.gem(15.5, hy + 6.0, 2.4, lava_l)
		p.px(15, hy + 6, Color.WHITE)
		for x in [11, 15, 20]:
			p.px(x, hy - 2, lava)
			p.px(x, hy - 3, lava_l)
		_band(p, 22, 2)

# ---------------------------------------------------------------------------------------------------------------------------------
# SPELLBLADE (staff + sword): a sword with a staff's crescent and orb for a guard; runes, floating orbs.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_spellblade(p: Paint, t: int) -> void:
	var s := _s("spellblade", t)
	var vio := Color("7f5bff")
	var vio_l := Color("cbb8ff")
	var blade := Color("c8c4f0")
	var blade_d := Color("8a86c0")
	_grip(p, 27, 29)
	p.disc(16.0, 30.5, 1.8, Paint.GOLD)
	var nb := 2 if s < 3 else 3
	for y in range(0, 22):
		var n := nb if y > 3 else (2 if y > 1 else 1)
		n = mini(n, nb)
		_row(p, y, n, blade, blade_d)
		if y > 2:
			p.px(15, y, Color.WHITE)
	# the staff-style guard: crescent prongs cradling an orb
	p.rect(14, 24, 17, 28, Paint.WOOD)
	p.rect(14, 24, 14, 28, Paint.WOOD_L)
	var pr := 6 if s < 4 else 7
	for side in [-1, 1]:
		for k in pr:
			var x: int = (16 + 1 + k) if side > 0 else (14 - k)
			var y := 23 - (k * k) / 6
			p.px(x, y, Paint.GOLD if s >= 2 else Paint.WOOD)
			p.px(x, y + 1, Paint.GOLD_D if s >= 2 else Paint.WOOD)
	p.disc(15.5, 22.0, 3.0, vio)
	p.disc(15.0, 21.0, 1.3, vio_l)
	if s >= 2:                                      # cyan runes down the blade
		for y in range(5, 19, 3):
			p.px(16, y, Color("5be0ff"))
	if s >= 3:                                      # two small orbits of power
		for sx in [7, 24]:
			p.gem(sx, 12.0, 1.6, vio)
	if s >= 4:                                      # a halo round the orb, gold wings
		p.ring(15.5, 22.0, 5.0, 1.0, vio_l)
		p.px(15, 17, Color.WHITE)
		for k in 3:
			p.px(8 - k, 20 - k, Paint.GOLD_L)
			p.px(23 + k, 20 - k, Paint.GOLD_L)
	if s >= 5:                                      # spectral swords hang either side of the blade
		for sx in [8, 23]:
			_tri(p, Vector2(sx + 0.5, 17), Vector2(sx + 0.5, 6), 1.2, vio_l, vio)
		p.px(15, 0, Color.WHITE)
		p.px(16, 1, vio_l)

# ---------------------------------------------------------------------------------------------------------------------------------
# TEMPEST LASH (staff + whip): a handle whose lash is a living bolt of lightning, crowned with a storm orb.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_tempest(p: Paint, t: int) -> void:
	var s := _s("tempest", t)
	var cord := Color("4a6aa0")
	var cord_l := Color("8ab4ff")
	var zap := Color("ffe45a")
	_grip(p, 21, 30)
	_wrap(p, 22, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.GOLD if s >= 2 else Paint.IRON)
	p.rect(14, 20, 17, 21, Paint.IRON_D)
	# the lash: a zig-zag bolt from the handle to the top
	var pts: Array = [Vector2(16, 20), Vector2(11, 16), Vector2(20, 12), Vector2(11, 8), Vector2(19, 4), Vector2(15, 0)]
	var th := 2 if s < 4 else 3
	_curve(p, pts, cord, th)
	_curve(p, pts, cord_l, 1)
	if s >= 2:
		_curve(p, pts, zap, 1)
		p.px(15, 0, Color.WHITE)
	if s >= 3:                                      # forks off the bolt
		p.line(Vector2(20, 12), Vector2(26, 10), zap, 1)
		p.line(Vector2(26, 10), Vector2(24, 6), zap, 1)
		p.line(Vector2(11, 8), Vector2(6, 6), zap, 1)
		p.px(5, 5, Color.WHITE)
		p.px(24, 5, Color.WHITE)
	if s >= 4:                                      # a storm orb where the lash leaves the handle
		p.disc(15.5, 19.0, 3.2, Color("2a4a9a"))
		p.disc(15.5, 19.0, 2.2, Color("5be0ff"))
		p.disc(15.0, 18.4, 0.9, Color.WHITE)
		p.line(Vector2(11, 8), Vector2(8, 11), zap, 1)
	if s >= 5:                                      # a second bolt, sparks, a gold collar
		_curve(p, [Vector2(20, 12), Vector2(25, 15), Vector2(21, 19)], cord_l, 1)
		p.px(21, 19, Color.WHITE)
		for q in [Vector2(3, 10), Vector2(27, 4), Vector2(8, 2), Vector2(23, 14)]:
			p.px(int(q.x), int(q.y), zap)
		_band(p, 22, 2)

# ---------------------------------------------------------------------------------------------------------------------------------
# WARP BOW (bow + staff): a bow with a staff for a stock: an orb at the riser, limbs that recurve into arcane wings.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_warpbow(p: Paint, t: int) -> void:
	var s := _s("warpbow", t)
	var vio := Color("7f5bff")
	var vio_l := Color("cbb8ff")
	var limb := Color("6a4a9a")
	var limb_l := Color("9a7ad0")
	_grip(p, 20, 30)
	_wrap(p, 22, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON)
	# the limbs: an arch whose tips recurve outward
	var span := 13.0 if s < 4 else 14.0
	for i in 61:
		var u := i / 60.0
		var x := 15.5 - span + 2.0 * span * u
		var y := 17.0 - 11.0 * sin(PI * u)
		if s >= 2:                                   # recurved tips
			y += 3.0 * pow(absf(2.0 * u - 1.0), 6.0) * -1.0
		p.px(int(x), int(y), limb)
		p.px(int(x), int(y) + 1, limb_l)
		if s >= 3:
			p.px(int(x), int(y) - 1 + (1 if absf(2.0 * u - 1.0) < 0.8 else 0), limb)
	# the string and the arrow with a vio head
	p.line(Vector2(15.5 - span, 17), Vector2(15.5 + span, 17), Color("e8e8e8"), 1)
	p.rect(15, 3, 16, 19, Paint.STEEL_D)
	p.rect(15, 3, 15, 19, Paint.STEEL)
	_tri(p, Vector2(15.5, 6), Vector2(15.5, 0), 2.2, vio_l, vio)
	p.rect(14, 17, 17, 19, Paint.GOLD_D)
	# the orb at the riser
	p.disc(15.5, 20.0, 2.8, vio)
	p.disc(15.0, 19.4, 1.2, vio_l)
	if s >= 3:                                       # crescent prongs of the staff either side of the orb
		for side in [-1, 1]:
			for k in 4:
				var x: int = (16 + 3 + k / 2) if side > 0 else (15 - 3 - k / 2)
				p.px(x, 20 - k, Paint.GOLD)
	if s >= 4:                                       # gold limb caps and rune gems
		for sx in [3, 28]:
			p.rect(sx, 14, sx + 1, 16, Paint.GOLD)
		p.gem(8.0, 10.0, 1.4, Color("5be0ff"))
		p.gem(23.0, 10.0, 1.4, Color("5be0ff"))
	if s >= 5:                                       # arcane wings: a second arch of light, fletching, sparkles
		for i in 41:
			var u := i / 40.0
			var x := 15.5 - 9.0 + 18.0 * u
			var y := 15.0 - 8.0 * sin(PI * u)
			p.px(int(x), int(y), vio_l)
		for k in 3:
			p.px(13 - k, 17 + k, vio_l)
			p.px(18 + k, 17 + k, vio_l)
		p.px(15, 0, Color.WHITE)

# ---------------------------------------------------------------------------------------------------------------------------------
# JUGGERNAUT (bulwark + knightblade): a huge slab of a sword, armour plates for a guard, spikes and trim as it grows.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_juggernaut(p: Paint, t: int) -> void:
	var s := _s("juggernaut", t)
	var blue := Color("3b6fd0")
	_grip(p, 25, 29, Paint.WOOD_L, Paint.WOOD)
	_wrap(p, 25, 29, Paint.WOOD_D)
	p.disc(16.0, 30.5, 2.2, Paint.IRON_D)
	p.px(15, 30, Paint.STEEL_L)
	# the slab blade, chamfered at the top
	for y in range(1, 22):
		var n := 5 if y > 3 else (3 if y == 1 else 4)
		_row(p, y, n, Paint.STEEL, Paint.STEEL_D)
		p.px(16 - n, y, Paint.STEEL_L)
		p.px(15 + n, y, Paint.IRON_D)
	p.rect(11, 1, 14, 1, Paint.STEEL_L)
	for y in range(5, 20, 4):                       # rivets
		p.px(12, y, Paint.STEEL_L)
		p.px(19, y, Paint.STEEL_L)
	# the guard: a heavy block
	p.rect(6, 22, 25, 24, Paint.IRON)
	p.rect(6, 22, 25, 22, Paint.STEEL_L)
	p.rect(6, 24, 25, 24, Paint.IRON_D)
	if s >= 2:                                      # a fuller down the blade, a spiked spine, shoulder plates on the guard
		for y in range(4, 20):
			p.px(15, y, Paint.IRON_D)
			p.px(16, y, Paint.IRON_D)
		for y in range(4, 20, 5):
			p.px(21, y, Paint.STEEL_L)
			p.px(22, y + 1, Paint.STEEL)
		p.disc(8.0, 22.0, 3.2, Paint.IRON)
		p.disc(23.0, 22.0, 3.2, Paint.IRON_D)
		p.disc(7.5, 21.5, 1.4, Paint.STEEL_L)
		p.disc(22.5, 21.5, 1.4, Paint.STEEL)
	if s >= 3:                                      # blue and gold trim, a gem, bigger plates
		p.rect(7, 24, 24, 24, Paint.GOLD)
		for y in range(2, 22):
			p.px(11, y, Paint.GOLD_D)
			p.px(20, y, Paint.GOLD_D)
		p.gem(15.5, 11.0, 2.0, Color("e03050"))
		p.rect(14, 19, 17, 21, blue)
		p.px(15, 20, Paint.GOLD)
		p.px(16, 20, Paint.GOLD)
		for side in [-1, 1]:
			var x := 4 if side < 0 else 27
			p.px(x, 21, Paint.STEEL_L)
			p.px(x, 20, Paint.STEEL)
	if s >= 4:                                      # crest spikes, gold edge, a red banner
		for x in [11, 13, 18, 20]:
			p.px(x, 0, Paint.STEEL_L)
		for y in range(2, 22, 2):
			p.px(10, y, Paint.GOLD)
			p.px(21, y, Paint.GOLD_D)
		for k in 5:
			p.px(18 + k, 26 + k / 2, Paint.RED)
			p.px(18 + k, 27 + k / 2, Paint.RED.darkened(0.25))
		p.px(3, 19, Paint.STEEL_L)
		p.px(28, 19, Paint.STEEL)

# ---------------------------------------------------------------------------------------------------------------------------------
# EARTHSHAKER (bulwark + quake pick): a stone maul with a pick spike, crystals bursting out of the head.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_earthshaker(p: Paint, t: int) -> void:
	var s := _s("earthshaker", t)
	var rock := Color("8a7a66")
	var rock_l := Color("b0a08a")
	var rock_d := Color("5c5043")
	var amber := Color("ffb02a")
	_grip(p, 13, 30)
	_wrap(p, 18, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON_D)
	var x0 := 5 if s < 4 else 3
	var x1 := 26 if s < 4 else 28
	var y0 := 5 if s < 3 else 6
	# the stone head
	p.rect(x0, y0, x1, y0 + 8, rock)
	p.rect(x0, y0, x1, y0 + 1, rock_l)
	p.rect(x0, y0 + 7, x1, y0 + 8, rock_d)
	p.rect(x0, y0, x0 + 1, y0 + 8, Paint.IRON)
	p.rect(x1 - 1, y0, x1, y0 + 8, Paint.IRON_D)
	p.rect(14, y0 + 8, 17, y0 + 9, Paint.IRON)
	# a pick spike on top
	_tri(p, Vector2(16, y0), Vector2(16, 0), 3.0, Paint.STEEL, Paint.STEEL_D)
	if s >= 2:                                      # a spike at each end, iron rings round the head, cracks
		for side in [-1, 1]:
			var x := x0 - 1 if side < 0 else x1 + 1
			_tri(p, Vector2(x, y0 + 4), Vector2(x + side * 3, y0 + 4), 2.2, Paint.STEEL, Paint.STEEL_D)
		p.rect(x0 + 3, y0, x0 + 3, y0 + 8, Paint.IRON_D)
		p.rect(x1 - 3, y0, x1 - 3, y0 + 8, Paint.IRON_D)
		p.line(Vector2(11, y0 + 2), Vector2(13, y0 + 5), rock_d, 1)
		p.line(Vector2(19, y0 + 3), Vector2(18, y0 + 6), rock_d, 1)
	if s >= 3:                                      # amber crystals pushing out of the top, glowing cracks
		for q in [[10, 3], [22, 3], [13, 2], [19, 2]]:
			_tri(p, Vector2(q[0], y0), Vector2(q[0], q[1]), 1.6, amber, amber.darkened(0.3))
		p.line(Vector2(11, y0 + 2), Vector2(13, y0 + 5), amber, 1)
		p.line(Vector2(19, y0 + 3), Vector2(18, y0 + 6), amber, 1)
		_band(p, 17, 2)
	if s >= 4:                                      # a big gem in the face, gold bands, shards round the head, a spiked butt
		p.gem(15.5, y0 + 4.0, 2.6, amber)
		for x in [x0 + 2, x1 - 2]:
			p.px(x, y0 + 9, rock_d)
			p.px(x, y0 + 10, rock_d)
		_band(p, 23, 2)
		p.px(14, 31, Paint.STEEL_L)
		p.px(17, 31, Paint.STEEL_L)
		for k in 4:
			p.px(x0 + k, y0 + 10 + k / 2, rock_d)
			p.px(x1 - k, y0 + 10 + k / 2, rock_d)

# ---------------------------------------------------------------------------------------------------------------------------------
# SOULREAPER (chain fangs + spellblade): a scythe whose spirit chain carries captured souls.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_soulreaper(p: Paint, t: int) -> void:
	var s := _s("soulreaper", t)
	var soul := Color("5af0b0")
	var soul_d := Color("2a9a78")
	var dark := Color("3a3a4a")
	_grip(p, 4, 30, Color("5a4a6a"), Color("322a40"))
	_wrap(p, 18, 29, soul_d, 3)
	p.rect(14, 29, 17, 31, Paint.IRON_D)
	# the great curved blade
	var w := 3.6 if s < 3 else 4.4
	_swoop(p, Vector2(15, 4), Vector2(31, 0), Vector2(28 if s < 3 else 29, 15 if s < 3 else 17), w, Color("a8b4c8"), Color("5a6478"))
	for i in 18:                                    # bright edge on the inside of the curve
		var u := i / 17.0
		var q := Vector2(15, 4).lerp(Vector2(31, 0), u).lerp(Vector2(31, 0).lerp(Vector2(28, 15), u), u)
		if u > 0.15 and u < 0.9:
			p.px(int(q.x), int(q.y) + 2, Paint.STEEL_L)
	p.rect(13, 3, 18, 5, Paint.IRON_D)
	p.rect(13, 3, 18, 3, Paint.IRON)
	# the spirit chain: hangs off the shaft with a soul orb at its end
	var pts: Array = [Vector2(15, 14), Vector2(10, 16), Vector2(8, 20), Vector2(10, 24)]
	_curve(p, pts, Paint.IRON, 1)
	for q in pts:
		p.px(int(q.x), int(q.y), Paint.STEEL_L)
	p.gem(10.0, 25.0, 2.0, soul)
	if s >= 2:                                      # spirit light on the edge, a second chain on the other side
		for i in 10:
			var u := 0.2 + i / 14.0
			var q := Vector2(15, 4).lerp(Vector2(31, 0), u).lerp(Vector2(31, 0).lerp(Vector2(28, 15), u), u)
			p.px(int(q.x), int(q.y) + 3, soul)
		_curve(p, [Vector2(16, 18), Vector2(21, 20), Vector2(23, 24)], Paint.IRON, 1)
		p.gem(23.0, 25.0, 1.6, soul)
	if s >= 3:                                      # a back spike, a skull at the blade's root, gold collar
		_tri(p, Vector2(14, 5), Vector2(6, 2), 1.8, Paint.STEEL, Paint.STEEL_D)
		p.disc(15.5, 7.0, 2.2, Color("e8e8e0"))
		p.px(14, 7, dark)
		p.px(17, 7, dark)
		p.px(15, 9, dark)
		_band(p, 12, 2)
	if s >= 4:                                      # souls rising off the blade, a gem eye, a spiky butt
		for q in [Vector2(24, 8), Vector2(27, 5), Vector2(21, 3), Vector2(29, 11)]:
			p.px(int(q.x), int(q.y), soul)
			p.px(int(q.x), int(q.y) - 1, Color.WHITE)
		p.px(14, 7, soul)
		p.px(17, 7, soul)
		p.px(14, 31, Paint.STEEL_L)
		p.px(17, 31, Paint.STEEL_L)
		_band(p, 20, 2)

# ---------------------------------------------------------------------------------------------------------------------------------
# STORMCALLER BOW (tempest + warp bow): a wide bow with a lightning string and a thunderbolt for an arrow.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_stormbow(p: Paint, t: int) -> void:
	var s := _s("stormbow", t)
	var zap := Color("ffe45a")
	var cyan := Color("5be0ff")
	var limb := Color("3a5aa0")
	var limb_l := Color("7aa4ff")
	_grip(p, 19, 30)
	_wrap(p, 21, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.GOLD_D)
	var span := 14.0
	for i in 61:
		var u := i / 60.0
		var x := 15.5 - span + 2.0 * span * u
		var y := 17.0 - 12.0 * sin(PI * u) + 3.0 * pow(absf(2.0 * u - 1.0), 5.0) * -1.0
		p.px(int(x), int(y), limb)
		p.px(int(x), int(y) + 1, limb_l)
		if s >= 2:
			p.px(int(x), int(y) - 1, limb)
	# the lightning string
	var sp: Array = [Vector2(1.5, 17), Vector2(5, 19), Vector2(9, 16), Vector2(13, 19), Vector2(16, 17), Vector2(19, 19), Vector2(22, 16), Vector2(26, 19), Vector2(29.5, 17)]
	_curve(p, sp, zap, 1)
	# the thunderbolt arrow
	_curve(p, [Vector2(16, 20), Vector2(14, 13), Vector2(17, 8), Vector2(15, 1)], Color("c8d8ff"), 2)
	p.px(15, 0, Color.WHITE)
	_tri(p, Vector2(15.5, 5), Vector2(15.5, 0), 2.0, Color.WHITE, zap)
	if s >= 2:                                      # a storm orb on the grip, forked limb tips
		p.gem(15.5, 21.0, 2.4, cyan)
		for sx in [1, 28]:
			p.px(sx, 13, zap)
			p.px(sx + (1 if sx < 10 else -1), 12, Color.WHITE)
	if s >= 3:                                      # cloud puffs and bolts off the limbs
		p.disc(8.0, 7.0, 2.2, Color("8a98b8"))
		p.disc(11.0, 5.5, 2.4, Color("a8b4d0"))
		p.disc(21.0, 5.5, 2.4, Color("a8b4d0"))
		p.disc(24.0, 7.0, 2.2, Color("8a98b8"))
		p.line(Vector2(10, 8), Vector2(9, 11), zap, 1)
		p.line(Vector2(22, 8), Vector2(23, 11), zap, 1)
	if s >= 4:                                      # gold caps, a second string of sparks, crackle
		for sx in [1, 28]:
			p.rect(sx, 15, sx + 1, 17, Paint.GOLD)
		for q in [Vector2(5, 3), Vector2(26, 3), Vector2(3, 8), Vector2(28, 9), Vector2(12, 1), Vector2(20, 1)]:
			p.px(int(q.x), int(q.y), zap)
		p.line(Vector2(4, 12), Vector2(7, 9), cyan, 1)
		p.line(Vector2(27, 12), Vector2(24, 9), cyan, 1)

# ---------------------------------------------------------------------------------------------------------------------------------
# STARFALL (spellblade + tempest): a night-blue blade with a comet's tail, a crescent guard with a star.
# ---------------------------------------------------------------------------------------------------------------------------------
func _star(p: Paint, cx: float, cy: float, r: float, c: Color) -> void:
	p.diamond(cx, cy, r * 0.45, r, c)
	p.diamond(cx, cy, r, r * 0.45, c)

func draw_starfall(p: Paint, t: int) -> void:
	var s := _s("starfall", t)
	var night := Color("3a3a9a")
	var night_l := Color("7a7ae0")
	var star := Color("fff0a0")
	_grip(p, 26, 29, Color("2a2a5a"), Color("1a1a3a"))
	p.disc(16.0, 30.5, 1.8, Paint.GOLD)
	var nb := 2 if s < 3 else 3
	for y in range(1, 23):
		var n := nb if y > 3 else 1
		_row(p, y, n, night_l, night)
		if y > 2:
			p.px(15, y, Color("c8c8ff"))
	p.px(15, 0, Color.WHITE)
	# the crescent guard with a star in it
	for side in [-1, 1]:
		for k in 7:
			var x: int = (16 + k) if side > 0 else (15 - k)
			var y := 24 - (k * k) / 12
			p.px(x, y, Paint.GOLD)
			p.px(x, y + 1, Paint.GOLD_D)
	p.rect(14, 24, 17, 26, Paint.GOLD_D)
	_star(p, 15.5, 22.0, 3.2, star)
	p.px(15, 22, Color.WHITE)
	# stars sprinkled on the blade
	for q in [Vector2(14, 8), Vector2(17, 13), Vector2(14, 18)]:
		p.px(int(q.x), int(q.y), star)
	if s >= 2:                                      # a comet tail trailing beside the blade
		for k in 12:
			var x := 23 - k / 3
			var y := 1 + k
			if k % 2 == 0:
				p.px(x, y, Color("c8c8ff") if k < 8 else night_l)
		_star(p, 23.0, 2.0, 2.6, star)
	if s >= 3:                                      # a second tail on the other side, a larger star gem
		for k in 9:
			if k % 2 == 0:
				p.px(8 + k / 3, 5 + k, night_l)
		_star(p, 8.0, 4.0, 2.2, star)
		p.disc(15.5, 22.0, 1.4, Color.WHITE)
	if s >= 4:                                      # a great star crowning the tip, orbiting sparks, gold wings
		_star(p, 15.5, 3.0, 4.0, star)
		p.px(15, 3, Color.WHITE)
		p.px(16, 3, Color.WHITE)
		for q in [Vector2(5, 12), Vector2(26, 12), Vector2(4, 20), Vector2(27, 19)]:
			_star(p, q.x, q.y, 1.8, star)
		for k in 3:
			p.px(7 - k, 19 - k, Paint.GOLD_L)
			p.px(24 + k, 19 - k, Paint.GOLD_L)

# ---------------------------------------------------------------------------------------------------------------------------------
# WORLDBREAKER (earthshaker + juggernaut): a colossal plated hammer with a world-cracking core; it only exists from tier 4.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_worldbreaker(p: Paint, t: int) -> void:
	var s := _s("worldbreaker", t)
	var rock := Color("6a5a4a")
	var rock_l := Color("9a8a74")
	var lava := Color("ff6a1a")
	var lava_l := Color("ffd23a")
	_grip(p, 14, 30, Color("5a4a6a"), Color("322a40"))
	_wrap(p, 16, 29, Paint.GOLD_D, 2)
	p.rect(13, 29, 18, 31, Paint.IRON_D)
	p.rect(13, 29, 18, 29, Paint.IRON)
	# the colossal head: a plated block with a spike on top
	p.rect(2, 4, 29, 13, rock)
	p.rect(2, 4, 29, 5, rock_l)
	p.rect(2, 12, 29, 13, Color("3a3030"))
	p.rect(2, 4, 4, 13, Paint.IRON_D)
	p.rect(27, 4, 29, 13, Paint.IRON_D)
	p.rect(2, 4, 2, 13, Paint.IRON)
	p.rect(8, 4, 8, 13, Paint.IRON_D)
	p.rect(23, 4, 23, 13, Paint.IRON_D)
	_tri(p, Vector2(16, 4), Vector2(16, 0), 3.4, Paint.STEEL, Paint.STEEL_D)
	# the core and the cracks that run from it
	p.disc(15.5, 8.5, 3.0, lava)
	p.disc(15.0, 8.0, 1.5, lava_l)
	for a in [[Vector2(13, 8), Vector2(10, 6)], [Vector2(18, 9), Vector2(21, 11)], [Vector2(15, 11), Vector2(14, 13)]]:
		p.line(a[0], a[1], lava, 1)
	if s >= 2:                                      # side spikes, gold trim, cracks glow down the haft, shoulder plates
		for side in [-1, 1]:
			var x := 1 if side < 0 else 30
			_tri(p, Vector2(x, 8), Vector2(x + side * 1.0 - (1 if side < 0 else 0), 8), 3.0, Paint.STEEL, Paint.STEEL_D)
		p.rect(5, 4, 7, 4, Paint.GOLD)
		p.rect(24, 4, 26, 4, Paint.GOLD)
		p.rect(5, 13, 7, 13, Paint.GOLD_D)
		p.rect(24, 13, 26, 13, Paint.GOLD_D)
		for x in [3, 28]:
			p.px(x, 7, lava)
			p.px(x, 10, lava)
		p.line(Vector2(14, 14), Vector2(15, 18), lava, 1)
		_band(p, 21, 3)
		_band(p, 26, 3)
		for x in [11, 20]:
			p.px(x, 14, rock)
			p.px(x, 15, lava)
	if s >= 3:                                      # a crown of spikes, a ringed core, wings, a spiked pommel, bright sparks
		for x in range(5, 28, 3):
			p.px(x, 3, Paint.STEEL_L)
			p.px(x, 2, Paint.STEEL)
		p.ring(15.5, 8.5, 4.6, 1.0, lava_l)
		p.px(15, 8, Color.WHITE)
		p.px(16, 8, Color.WHITE)
		for k in 4:
			p.px(1 - k / 2, 3 - k, Paint.STEEL_L)
			p.px(30 + k / 2, 3 - k, Paint.STEEL)
		p.px(13, 31, Paint.STEEL_L)
		p.px(18, 31, Paint.STEEL_L)
		for q in [Vector2(10, 1), Vector2(21, 1), Vector2(5, 15), Vector2(26, 15)]:
			p.px(int(q.x), int(q.y), lava_l)

# ---------------------------------------------------------------------------------------------------------------------------------
# WITCH STAFF (bog staff + staff): a gnarled staff whose branches claw an orb; charms and a skull as it grows.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_witchstaff(p: Paint, t: int) -> void:
	var s := _s("witchstaff", t)
	var bark := Color("5a4a2a")
	var bark_l := Color("8a7040")
	var green := Color("7fe03a")
	var vio := Color("a050e0")
	_curve(p, [Vector2(16, 31), Vector2(14, 24), Vector2(17, 18), Vector2(15, 13)], bark, 2)
	_curve(p, [Vector2(16, 30), Vector2(14, 24), Vector2(17, 18), Vector2(15, 13)], bark_l, 1)
	# claws of branches holding the orb
	_curve(p, [Vector2(15, 14), Vector2(10, 11), Vector2(9, 5), Vector2(12, 2)], bark, 2)
	_curve(p, [Vector2(16, 14), Vector2(21, 11), Vector2(22, 5), Vector2(19, 2)], bark, 2)
	p.disc(15.5, 8.0, 3.8, Color("2a7a1a"))
	p.disc(15.5, 8.0, 2.8, green)
	p.disc(14.8, 7.2, 1.1, Color("d8ffa8"))
	if s >= 2:                                      # a third claw, a purple eye, runes on the staff
		_curve(p, [Vector2(15, 14), Vector2(15, 8)], Color.TRANSPARENT, 1)
		_curve(p, [Vector2(15, 4), Vector2(15, 1), Vector2(17, 0)], bark, 2)
		p.px(16, 9, vio)
		p.px(17, 9, vio)
		p.px(16, 8, Color.BLACK)
		for y in [20, 24, 27]:
			p.px(16, y, green)
	if s >= 3:                                      # charms hang from the claws: beads, a feather, a bone
		for q in [[9, 9, green], [9, 12, vio], [22, 9, vio], [22, 12, green]]:
			p.px(q[0], q[1], q[2])
			p.px(q[0], q[1] + 1, q[2])
		p.rect(12, 20, 13, 24, Color("e8e0c8"))
		p.px(12, 25, Color("e8e0c8"))
		p.px(13, 26, Color("e8e0c8"))
		p.px(19, 21, Color("c04060"))
		p.px(20, 22, Color("c04060"))
		p.px(20, 23, Color("c04060"))
	if s >= 4:                                      # a skull under the orb, bigger claws
		p.disc(15.5, 16.0, 2.2, Color("e8e8e0"))
		p.px(14, 16, Color.BLACK)
		p.px(17, 16, Color.BLACK)
		p.px(15, 18, Color.BLACK)
		_curve(p, [Vector2(9, 5), Vector2(6, 3), Vector2(6, 0)], bark, 1)
		_curve(p, [Vector2(22, 5), Vector2(25, 3), Vector2(25, 0)], bark, 1)
	if s >= 5:                                      # wisps and floating orbs, gold bands
		for q in [Vector2(5, 8), Vector2(26, 7), Vector2(4, 15), Vector2(27, 14)]:
			p.gem(q.x, q.y, 1.5, vio if int(q.x) % 2 == 0 else green)
		_band(p, 26, 2)
		p.px(15, 0, Color.WHITE)

# ---------------------------------------------------------------------------------------------------------------------------------
# PRISMATIC STAFF (crystal wand + staff): a staff holding a faceted prism that splits light into the six hues.
# ---------------------------------------------------------------------------------------------------------------------------------
func draw_prismstaff(p: Paint, t: int) -> void:
	var s := _s("prismstaff", t)
	var hues := [Color("ff5a5a"), Color("ff9a3a"), Color("ffe45a"), Color("5ae07a"), Color("5ac8ff"), Color("b070ff")]
	_grip(p, 15, 30)
	_wrap(p, 18, 29, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON)
	# the cradle and the prism
	for side in [-1, 1]:
		for k in 5:
			var x: int = (16 + 3 + k / 2) if side > 0 else (15 - 3 - k / 2)
			p.px(x, 15 - k, Paint.GOLD if s >= 2 else Paint.WOOD)
			p.px(x, 14 - k, Paint.GOLD_D if s >= 2 else Paint.WOOD_D)
	p.rect(13, 14, 18, 15, Paint.GOLD if s >= 2 else Paint.WOOD)
	var top := 1 if s < 4 else 0
	for y in range(top, 14):
		var u := float(y - top) / float(13 - top)
		var n := 1 + int(sin(u * PI * 0.9) * 4.0)
		_row(p, y, n, Color("e8f4ff"), Color("9ac0e8"))
		p.px(15, y, Color.WHITE)
	if s >= 2:                                      # the light splits into bands across the prism
		for k in 6:
			var y := top + 3 + k
			if y < 14:
				var n := 1 + int(sin(float(y - top) / float(13 - top) * PI * 0.9) * 4.0)
				p.px(16 + n - 1, y, hues[k])
				p.px(16 + n - 2, y, hues[k])
	if s >= 3:                                      # two smaller prisms
		for sx in [7, 24]:
			_tri(p, Vector2(sx + 0.5, 15), Vector2(sx + 0.5, 6), 2.0, Color("e8f4ff"), Color("9ac0e8"))
		p.px(7, 15, hues[4])
		p.px(24, 15, hues[5])
	if s >= 4:                                      # a rainbow fanned across the top, bigger prism
		for k in 6:
			p.line(Vector2(15.5, 6), Vector2(2.0 + k * 5.0, 0), hues[k], 1)
		p.gem(15.5, 8.0, 1.6, Color.WHITE)
	if s >= 5:                                      # a spiralling gem band, floating shards
		for k in 6:
			p.px(15 + (k % 2), 17 + k, hues[k])
		for q in [Vector2(4, 10), Vector2(27, 10), Vector2(9, 3), Vector2(22, 3)]:
			p.diamond(q.x, q.y, 1.0, 1.6, hues[int(q.x) % 6])
		_band(p, 26, 2)
