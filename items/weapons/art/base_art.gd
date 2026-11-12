extends RefCounted
## Per-tier art of the base weapons (see weapon_tier_art.gd): `draw_<id>(p, t)` draws tier t (1..6) on a 32x32 canvas, tip up, grip at the
## bottom centre. Tier 1 reproduces tools/make_weapon_art.gd's icon; every higher tier keeps all the parts of the tier below and adds more.
const Paint = preload("res://items/weapons/art/weapon_paint.gd")

# ---------------------------------------------------------------------------------------------------------------- shared bits

## A two-tone shaft (light left column) from y0 to y1 at columns 15-16.
func _shaft(p: Paint, y0: int, y1: int, light := Paint.WOOD_L, dark := Paint.WOOD) -> void:
	p.rect(15, y0, 16, y1, dark)
	p.rect(15, y0, 15, y1, light)

## Spiral / banded wrap on a 2 px shaft.
func _wrap(p: Paint, y0: int, y1: int, c: Color, step := 2) -> void:
	var y := y0
	while y <= y1:
		p.px(15, y, c)
		p.px(16, y + 1, c)
		y += step

# ---------------------------------------------------------------------------------------------------------------------- spear

func draw_spear(p: Paint, t: int) -> void:
	var shaft_hi := Paint.WOOD_L
	_shaft(p, 11, 30)
	if t == 1:
		for y in range(2, 11):
			var half := (y - 2) * 0.55
			for x in range(int(15.5 - half), int(16.5 + half) + 1):
				p.px(x, y, Paint.STEEL if x <= 15 else Paint.STEEL_D)
		p.rect(13, 11, 18, 12, Paint.RED)
		return
	# --- tier 2: a longer leaf-shaped head with a ridge, a gold socket collar, leather grip wraps, an iron butt cap
	var top := 0 if t < 4 else 0
	var maxhalf := 3.4 if t < 4 else 4.2
	for y in range(top, 12):
		var u := float(y - top) / 11.0
		var half := minf(0.5 + u * (maxhalf + 1.0) * 1.1, maxhalf)
		if y > 8:
			half = maxhalf - (y - 8) * 0.25
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			p.px(x, y, Paint.STEEL if x <= 15 else Paint.STEEL_D)
		if y >= 3:
			p.px(15, y, Paint.STEEL_L)       # ridge
			p.px(16, y, Paint.STEEL_D.darkened(0.15))
	p.rect(13, 12, 18, 13, Paint.GOLD)
	p.rect(13, 13, 18, 13, Paint.GOLD_D)
	p.rect(14, 14, 17, 14, Paint.GOLD)
	p.rect(14, 29, 17, 31, Paint.IRON)
	p.rect(14, 29, 17, 29, Paint.STEEL_L)
	_wrap(p, 21, 27, Paint.WOOD_D, 2)
	p.rect(15, 20, 16, 20, Paint.WOOD_D)
	# --- tier 3: winged guard blades, hanging red tassels
	if t >= 3:
		for side in [-1, 1]:
			var cx: float = 15.5 + side * 3.0
			for i in 6:
				var x: int = int(cx + side * (i * 0.5 + 0.5))
				p.px(x, 13 - i, Paint.STEEL if side < 0 else Paint.STEEL_D)
				p.px(x - side, 13 - i, Paint.STEEL if side < 0 else Paint.STEEL_D)
		for y in range(15, 20):
			p.px(13, y, Paint.RED)
			p.px(18, y, Paint.RED.darkened(0.2))
		p.px(13, 20, Paint.GOLD)
		p.px(18, 20, Paint.GOLD)
	# --- tier 4: a serrated, broader blade, a ruby in the collar, gold bands on the shaft
	if t >= 4:
		for y in range(3, 11, 3):
			var half := minf(0.5 + float(y) / 11.0 * 5.0 * 1.1, maxhalf)
			p.px(int(15.5 - half) - 0, y, Paint.CLEAR)
			p.px(int(16.5 + half), y, Paint.CLEAR)
		p.gem(15.5, 13.5, 1.5, Color("e04060"))
		p.rect(15, 23, 16, 23, Paint.GOLD)
		p.rect(15, 26, 16, 26, Paint.GOLD)
	# --- tier 5: side prongs that reach up beside the head, a flowing red pennant, a gold inlay down the blade
	if t >= 5:
		for side in [-1, 1]:
			for y in range(5, 12):
				var x: int = 15 + (7 if side > 0 else -6) + (0 if y > 8 else side)
				p.px(x, y, Paint.STEEL if side < 0 else Paint.STEEL_D)
		for y in range(3, 11):
			p.px(15, y, Paint.GOLD_L)
		for i in 7:
			var fy := 14 + i / 2
			p.rect(19 + i, fy, 19 + i, fy + 3 - (i / 3), Paint.RED if i % 2 == 0 else Color("e05040"))
	# --- tier 6: the whole head edged in gold, a jewelled star at the tip, a golden shaft with a spiral wrap
	if t >= 6:
		for y in range(0, 12):
			for x in range(3, 29):
				var c := p.get_px(x, y)
				if c.a > 0.5 and (c == Paint.STEEL or c == Paint.STEEL_D):
					var edge := p.get_px(x - 1, y).a < 0.5 or p.get_px(x + 1, y).a < 0.5
					if edge:
						p.px(x, y, Paint.GOLD)
		p.diamond(15.5, 0.5, 1.5, 1.6, Paint.GOLD_L)
		p.px(15, 1, Color("fff8d0"))
		_shaft(p, 15, 28, Paint.GOLD_L, Paint.GOLD)
		_wrap(p, 15, 28, Paint.GOLD_D, 2)
		p.gem(15.5, 13.5, 1.5, Color("5be0ff"))

# ---------------------------------------------------------------------------------------------------------------------- hammer

func draw_hammer(p: Paint, t: int) -> void:
	_shaft(p, 13, 30)
	if t == 1:
		p.rect(7, 3, 24, 13, Paint.IRON)
		p.rect(7, 3, 24, 4, Color("c8d0d8"))
		p.rect(7, 7, 24, 8, Paint.IRON_D)
		p.rect(7, 3, 8, 13, Color("707a85"))
		p.rect(23, 3, 24, 13, Color("707a85"))
		return
	# head box grows with the tier
	var x0: int = [0, 7, 6, 6, 5, 4, 4][t]
	var x1: int = [0, 24, 25, 25, 26, 27, 27][t]
	var y0: int = [0, 3, 2, 2, 1, 1, 0][t]
	var y1: int = [0, 13, 14, 14, 14, 14, 14][t]
	var face := Paint.IRON if t < 6 else Color("b7c0cb")
	var cap := Color("707a85")
	var cap_hi := Color("9aa6b3")
	# tier 2: a taller head with riveted end caps, a bevel, leather-wrapped handle, an iron pommel cap and a collar under the head
	p.rect(x0, y0, x1, y1, face)
	p.rect(x0, y0, x1, y0 + 1, Color("c8d0d8"))
	p.rect(x0, y0 + 4, x1, y0 + 5, Paint.IRON_D)
	p.rect(x0, y1 - 1, x1, y1, Paint.IRON_D)
	var cw := 3 if t < 4 else 4
	p.rect(x0, y0, x0 + cw - 1, y1, cap)
	p.rect(x1 - cw + 1, y0, x1, y1, cap)
	p.rect(x0, y0, x0 + cw - 1, y0, cap_hi)
	p.rect(x1 - cw + 1, y0, x1, y0, cap_hi)
	for rv in [y0 + 2, y1 - 2]:
		p.px(x0 + 1, rv, Paint.STEEL_L)
		p.px(x1 - 1, rv, Paint.STEEL_L)
	p.rect(13, y1 + 1, 18, y1 + 2, Paint.IRON_D)
	p.rect(14, y1 + 1, 17, y1 + 1, Paint.IRON)
	p.rect(14, 29, 17, 31, Paint.IRON)
	p.rect(14, 29, 17, 29, Paint.STEEL_L)
	_wrap(p, 20, 27, Paint.WOOD_D, 2)
	# tier 3: studs along the face, a spike on the back end, gold ring bands on the handle
	if t >= 3:
		for sx in range(x0 + cw + 1, x1 - cw, 3):
			p.px(sx, y0 + 7, Paint.STEEL_L)
			p.px(sx, y0 + 8, Paint.IRON_D.darkened(0.2))
		for i in 4:
			p.rect(x0 - 1 - i, y0 + 5 + i / 2 + 0, x0 - 1 - i, y1 - 5 - i / 2 + 1, cap if i % 2 == 0 else cap_hi)
		p.rect(14, 17, 17, 17, Paint.GOLD)
		p.rect(14, 24, 17, 24, Paint.GOLD)
	# tier 4: a gem set in the middle of the head, spikes on both ends, a gold collar
	if t >= 4:
		for i in 4:
			p.rect(x1 + 1 + i, y0 + 5 + i / 2, x1 + 1 + i, y1 - 5 - i / 2 + 1, cap if i % 2 == 0 else cap_hi)
		p.rect(13, y1 + 1, 18, y1 + 1, Paint.GOLD)
		p.rect(13, y1 + 2, 18, y1 + 2, Paint.GOLD_D)
		p.gem(15.5, y0 + 7.5, 2.4, Color("e04060"))
		p.rect(x0 + cw, y0 + 2, x1 - cw, y0 + 2, Paint.STEEL_L)
	# tier 5: gold trim along the head, cyan runes in the groove, gold handle bands everywhere
	if t >= 5:
		p.rect(x0 + cw, y0, x1 - cw, y0, Paint.GOLD)
		p.rect(x0 + cw, y1, x1 - cw, y1, Paint.GOLD_D)
		for rx in [x0 + cw + 1, x0 + cw + 3, x1 - cw - 3, x1 - cw - 1]:
			p.px(rx, y0 + 4, Color("5be0ff"))
			p.px(rx, y0 + 5, Color("5be0ff"))
		p.rect(14, 20, 17, 20, Paint.GOLD)
		p.rect(14, 27, 17, 27, Paint.GOLD)
	# tier 6: gold end caps with wing flares, a white-gold gem, a golden jewelled handle
	if t >= 6:
		for xs in [x0, x1 - cw + 1]:
			p.rect(xs, y0 + 1, xs + cw - 1, y1 - 1, Paint.GOLD)
			p.rect(xs, y0 + 1, xs + cw - 1, y0 + 1, Paint.GOLD_L)
			p.px(xs + 1, y0 + 6, Paint.GOLD_D)
			p.px(xs + 1, y0 + 8, Paint.GOLD_D)
		p.line(Vector2(x0, y0), Vector2(x0 - 1, y0 - 1), Paint.GOLD_L)
		p.gem(15.5, y0 + 7.5, 3.0, Color("5be0ff"))
		_shaft(p, 19, 28, Paint.GOLD_L, Paint.GOLD)
		_wrap(p, 19, 28, Paint.GOLD_D, 2)
		p.gem(15.5, 30.0, 1.4, Color("e04060"))

# ---------------------------------------------------------------------------------------------------------------------- torch

## A flame, tip up, base at (cx, by): outer / mid / core colours, height h, half-width w, with `tongues` extra licks beside it.
func _flame(p: Paint, cx: float, by: float, h: float, w: float, outer: Color, mid: Color, core: Color, tongues := 0) -> void:
	for y in range(int(by - h), int(by) + 1):
		var u := (by - y) / h                                  # 0 at the base, 1 at the tip
		var half := w * pow(maxf(0.0, 1.0 - u), 0.75) * minf(1.0, 0.55 + u * 2.5)
		half += 0.6 * sin(u * 9.0) * (1.0 - u)                 # a lick
		for x in range(int(cx - half), int(cx + half) + 1):
			var d := absf(x + 0.5 - cx) / maxf(half, 0.5)
			var c := outer
			if d < 0.62 and u < 0.8:
				c = mid
			if d < 0.3 and u > 0.05 and u < 0.6:
				c = core
			p.px(x, y, c)
	for i in tongues:
		var side := -1.0 if i % 2 == 0 else 1.0
		var sx := cx + side * w * (0.75 + 0.2 * (i / 2))
		var tt := by - h * (0.62 - 0.1 * (i / 2))
		p.line(Vector2(sx, by - h * 0.15), Vector2(sx - side * 0.5, tt), outer, 2 if i < 2 else 1)

func draw_torch(p: Paint, t: int) -> void:
	var orange := Color("ff7a1a")
	var amber := Color("ffb52e")
	var pale := Color("fff0a0")
	if t == 1:
		p.rect(14, 14, 17, 30, Paint.WOOD)
		p.rect(14, 14, 15, 30, Paint.WOOD_L)
		p.rect(12, 12, 19, 15, Paint.WOOD_D)
		p.disc(16.0, 9.0, 6.0, orange)
		p.disc(16.0, 7.0, 4.2, amber)
		p.disc(16.0, 6.0, 2.4, pale)
		p.px(16, 1, orange)
		p.px(16, 2, orange)
		p.px(15, 3, orange)
		p.px(17, 3, orange)
		return
	# tier 2: an iron-bound head: a wider bracket with a rim, nails, rope lashing on the handle and an iron foot; a bigger flame
	var fl_outer := orange if t < 5 else Color("ff5a20")
	_flame(p, 15.5, 12.0, 11.0, 6.5, orange, amber, pale, 0)
	p.rect(14, 14, 17, 30, Paint.WOOD)
	p.rect(14, 14, 15, 30, Paint.WOOD_L)
	p.rect(11, 12, 20, 13, Paint.IRON)
	p.rect(11, 12, 20, 12, Paint.STEEL_L)
	p.rect(12, 14, 19, 15, Paint.IRON_D)
	p.px(12, 14, Paint.STEEL)
	p.px(19, 14, Paint.STEEL_D)
	for y in range(18, 27, 2):
		p.rect(14, y, 17, y, Color("c9a86a"))
		p.rect(14, y + 1, 17, y + 1, Paint.WOOD_D)
	p.rect(13, 29, 18, 31, Paint.IRON)
	p.rect(13, 29, 18, 29, Paint.STEEL_L)
	# tier 3: the head becomes a flared brazier cup on a stem with coals, a flame with side licks, an iron band lower down
	if t >= 3:
		p.rect(9, 12, 22, 13, Paint.IRON)
		p.rect(9, 12, 22, 12, Paint.STEEL_L)
		p.rect(10, 14, 21, 15, Paint.IRON_D)
		p.rect(12, 16, 19, 16, Paint.IRON_D)
		p.rect(9, 12, 9, 13, Paint.STEEL_D)
		p.rect(22, 12, 22, 13, Paint.STEEL_D)
		for cxs in [11, 14, 17, 20]:
			p.px(cxs, 11, Color("c03010"))
			p.px(cxs + 1, 11, Color("ff6a1a"))
		p.rect(13, 22, 18, 22, Paint.IRON)
		p.rect(13, 23, 18, 23, Paint.IRON_D)
		_flame(p, 15.5, 11.0, 11.0, 6.5, orange, amber, pale, 2)
	# tier 4: a tall flame with a white-hot core, golden rim and handle bands, embers floating up
	if t >= 4:
		p.rect(9, 12, 22, 12, Paint.GOLD)
		p.rect(9, 13, 22, 13, Paint.GOLD_D)
		p.rect(13, 22, 18, 22, Paint.GOLD)
		p.rect(13, 26, 18, 26, Paint.GOLD)
		_flame(p, 15.5, 11.0, 12.0, 7.0, orange, amber, Color(1, 1, 0.9), 3)
		p.px(7, 6, amber)
		p.px(24, 5, amber)
		p.px(9, 2, orange)
	# tier 5: the flame burns blue-white at the heart inside a hot orange mantle; a jewelled collar and gold side arms
	if t >= 5:
		_flame(p, 15.5, 11.0, 12.0, 7.0, Color("ff8a2a"), Color("ffd24a"), Color("bff4ff"), 3)
		p.rect(15, 5, 16, 10, Color("7fe0ff"))
		p.rect(15, 3, 16, 4, Color("e8fbff"))
		p.gem(15.5, 14.5, 1.5, Color("e04060"))
		p.rect(6, 9, 7, 12, Paint.GOLD)
		p.rect(24, 9, 25, 12, Paint.GOLD)
		p.px(6, 8, Paint.GOLD_L)
		p.px(25, 8, Paint.GOLD_L)
	# tier 6: a golden crowned brazier with winged arms, a blue-white flame and a jewelled golden handle
	if t >= 6:
		p.rect(8, 12, 23, 13, Paint.GOLD)
		p.rect(8, 12, 23, 12, Paint.GOLD_L)
		p.rect(11, 14, 20, 15, Paint.GOLD_D)
		p.rect(12, 14, 19, 14, Paint.GOLD)
		p.gem(15.5, 14.8, 1.6, Color("5be0ff"))
		for cxs in [4, 27]:
			p.line(Vector2(cxs + (4 if cxs < 15 else -4), 12), Vector2(cxs, 6), Paint.GOLD, 2)
			p.px(cxs, 5, Paint.GOLD_L)
		p.rect(14, 17, 17, 21, Paint.GOLD_D)
		p.rect(14, 17, 14, 21, Paint.GOLD)
		for y in range(24, 30, 2):
			p.rect(14, y, 17, y, Paint.GOLD)
		p.gem(15.5, 30.0, 1.5, Color("e04060"))

# ---------------------------------------------------------------------------------------------------------------------- sword

func _if_on(p: Paint, x: int, y: int, c: Color) -> void:
	if p.get_px(x, y).a > 0.5:
		p.px(x, y, c)

func _sword_blade(p: Paint, top: int, bot: int, half: int, tip: int, light: Color, dark: Color) -> void:
	# half = half-width in px either side of the centre line (columns 15 | 16), tip = rows of narrowing at the top
	for y in range(top, bot + 1):
		var h := half
		var k := y - top
		if k < tip:
			h = int(round(float(half) * pow(float(k) / float(tip), 0.85)))
		for x in range(15 - h, 17 + h):
			p.px(x, y, light if x <= 15 else dark)

func draw_sword(p: Paint, t: int) -> void:
	var path := "res://items/tools/sword/excalibur_.png"
	if t == 1:
		p.blit_texture(path, Rect2i(0, 0, 32, 32))
		return
	p.outline_color = Color("353540")
	var blade_l := Color("bfb8b4")
	var blade_d := Color("98929c")
	var gold := Color("eeb551")
	var wood := Color("735b42")
	var top: int = [0, 7, 4, 3, 2, 1, 0][t]
	var half: int = [0, 2, 2, 3, 3, 3, 4][t]
	# tier 2: a longer, wider blade with a pointed tip and a fuller groove, a broader steel crossguard, a leather grip and round pommel
	_sword_blade(p, top, 18, half, [0, 3, 3, 3, 6, 7, 9][t], blade_l, blade_d)
	for y in range(top + 3, 18):
		p.px(15, y, Color("ede4da"))
	for y in range(top + 4, 17):
		p.px(16, y, Color("7f7a86"))
	p.rect(15 - half - 3, 19, 16 + half + 3, 20, gold)
	p.rect(15 - half - 3, 19, 16 + half + 3, 19, Color("ffe08a"))
	p.rect(15 - half - 3, 20, 16 + half + 3, 20, Color("b8842a"))
	p.rect(15, 21, 16, 25, wood)
	for y in [22, 24]:
		p.rect(15, y, 16, y, Color("4a3a2a"))
	p.rect(14, 26, 17, 27, gold)
	p.rect(14, 26, 17, 26, Color("ffe08a"))
	# tier 3: edge bevels, down-curved quillon tips and a ruby in the pommel, cord wrap
	if t >= 3:
		for y in range(top + 3, 18):
			_if_on(p, 16 - half, y, Color("ede4da"))
		p.rect(15 - half - 3, 21, 15 - half - 3, 21, gold)
		p.rect(16 + half + 3, 21, 16 + half + 3, 21, gold)
		p.gem(15.5, 26.5, 1.2, Color("e04060"))
	# tier 4: a broad blade with serrated back edge, swept-up quillons with a centre jewel, runes in the groove
	if t >= 4:
		for y in range(top + 7, 17, 3):
			if p.get_px(16 + half, y).a > 0.5:
				p.px(16 + half, y, Color(0, 0, 0, 0))
		for gx in [15 - half - 3, 16 + half + 3]:
			p.px(gx, 18, gold)
			p.px(gx, 17, Color("ffe08a"))
		p.gem(15.5, 19.5, 1.2, Color("5be0ff"))
		for y in range(top + 6, 17, 3):
			p.px(15, y, Color("5be0ff"))
	# tier 5: gold-edged blade (a second edge line), filigree curls on the guard, a larger pommel gem
	if t >= 5:
		for y in range(top + 2, 18):
			_if_on(p, 15 - half, y, Color("fff0a0"))
			_if_on(p, 16 + half, y, Color("c89a30"))
		for gx in [15 - half - 4, 17 + half + 3]:
			p.rect(gx, 18, gx, 20, gold)
		p.rect(15 - half - 4, 17, 15 - half - 4, 17, Color("ffe08a"))
		p.rect(17 + half + 3, 17, 17 + half + 3, 17, Color("ffe08a"))
		p.gem(15.5, 26.8, 1.8, Color("e04060"))
	# tier 6: wings of gold at the guard, a golden grip, a jewelled pommel star and a bright tip
	if t >= 6:
		for side in [-1, 1]:
			var bx: int = 15 - half - 4 if side < 0 else 17 + half + 3
			p.line(Vector2(bx, 17), Vector2(bx + side * 2, 14), gold)
			p.px(bx + side * 2, 13, Color("ffe08a"))
			p.line(Vector2(bx, 21), Vector2(bx + side, 23), gold)
		p.rect(15, 21, 16, 25, Color("b8842a"))
		for y in [22, 24]:
			p.rect(15, y, 16, y, gold)
		p.gem(15.5, 28.0, 1.5, Color("5be0ff"))
		p.px(15, 0, Color(1, 1, 1))
		p.px(16, 1, Color("ffe08a"))

# ------------------------------------------------------------------------------------------------------------------- pickaxe
# Drawn on a 45 degree frame: u runs along the handle (up and to the right), v across it (down and to the right).

const PK_O := Vector2(7.6, 31.0)

func _uv(x: int, y: int) -> Vector2:
	var d := Vector2(x + 0.5, y + 0.5) - PK_O
	return Vector2((d.x - d.y) * 0.7071, (d.x + d.y) * 0.7071)

## Fills every pixel whose (u, v) satisfies `test`, with the colour `col` returns for it.
func _pk_fill(p: Paint, u0: float, u1: float, v0: float, v1: float, c: Color) -> void:
	for y in 32:
		for x in 32:
			var q := _uv(x, y)
			if q.x >= u0 and q.x <= u1 and q.y >= v0 and q.y <= v1:
				p.px(x, y, c)

## A curved pick head crossing the handle at u = L, from v = -hl to +hl, `thick` half-thickness at the middle, bending back toward the handle by `curve`.
func _pk_head(p: Paint, L: float, hl: float, thick: float, curve: float, light: Color, dark: Color, tip_taper := 0.7) -> void:
	for y in 32:
		for x in 32:
			var q := _uv(x, y)
			if absf(q.y) > hl:
				continue
			var ht := thick * pow(1.0 - absf(q.y) / hl, tip_taper) + 0.55
			var uc := L - curve * q.y * q.y
			if absf(q.x - uc) <= ht:
				p.px(x, y, light if q.x >= uc - 0.2 else dark)

func draw_pickaxe(p: Paint, t: int) -> void:
	if t == 1:
		p.blit_texture("res://items/tools/pickaxe/pickaxe.png", Rect2i(0, 0, 32, 32))
		return
	p.outline_color = Color.BLACK
	var wood := Color("80591e")
	var wood_d := Color("644313")
	var iron := Color("c2c1bf")
	var iron_d := Color("8a8f99")
	var gold := Color("eeb551")
	var L := 19.0
	var hl: float = [0.0, 0.0, 10.0, 12.0, 12.5, 13.0, 13.5][t]
	var thick: float = [0.0, 0.0, 1.5, 2.3, 2.7, 2.9, 3.1][t]
	# tier 2: a handle with leather grip wraps and an iron-shod butt, an iron pick head (curved, tapering to points) in a riveted iron collar
	_pk_fill(p, 0.0, L, -1.3, 1.3, wood)
	_pk_fill(p, 0.0, L, -1.3, -0.4, Color("a8742a"))
	_pk_fill(p, 0.0, L, 0.5, 1.3, wood_d)
	_pk_fill(p, 0.0, 2.0, -1.5, 1.5, iron_d)
	for u in [5.0, 7.5, 10.0]:
		_pk_fill(p, u, u + 0.9, -1.3, 1.3, Color("4a3a2a"))
	var head_l := iron if t >= 2 else wood
	var head_d := iron_d
	_pk_head(p, L, hl, thick, 0.012, head_l, head_d)
	_pk_fill(p, L - 1.6, L + 1.6, -2.0, 2.0, Color("707a85"))
	_pk_fill(p, L - 1.6, L + 1.6, -2.0, -1.1, Color("b9c3cf"))
	# tier 3: a longer, deeper head, a gold ring on the handle, a second iron band under the collar, rivets
	if t >= 3:
		_pk_fill(p, L - 6.0, L - 4.4, -1.6, 1.6, gold)
		_pk_fill(p, 0.0, 2.8, -1.6, 1.6, iron_d)
		_pk_fill(p, L - 8.0, L - 7.2, -1.4, 1.4, iron)
		for vv in [-6.0, 6.0]:
			_pk_fill(p, L - 0.6, L + 0.6, vv - 0.5, vv + 0.5, Color("f2f6fb"))
	# tier 4: the back of the head becomes a broad flat adze blade, the pick side stays pointed; gold collar; spiky tip
	if t >= 4:
		for y in 32:
			for x in 32:
				var q := _uv(x, y)
				if q.y > 3.0 and q.y < hl + 0.5 and absf(q.x - (L - 0.012 * q.y * q.y)) <= 3.4 - (q.y - 3.0) * 0.12 and absf(q.x - (L - 0.012 * q.y * q.y)) > 1.4:
					p.px(x, y, iron if q.x > L else iron_d)
		_pk_fill(p, L - 1.8, L + 1.8, -2.2, 2.2, gold)
		_pk_fill(p, L - 1.8, L - 1.0, -2.2, 2.2, Color("ffe08a"))
		_pk_fill(p, L - 11.0, L - 10.2, -1.4, 1.4, gold)
	# tier 5: a cyan crystal in the collar, gold edge along the pick, a grip of gold wire
	if t >= 5:
		for y in 32:
			for x in 32:
				var q := _uv(x, y)
				if q.y < -3.0 and absf(q.x - (L - 0.012 * q.y * q.y)) >= thick * pow(1.0 - absf(q.y) / hl, 0.7) - 0.3 and p.get_px(x, y).a > 0.5:
					p.px(x, y, gold)
		for u in [5.0, 7.5, 10.0]:
			_pk_fill(p, u, u + 0.9, -1.3, 1.3, gold)
	# tier 6: a glowing crystal set in the collar, crystal pick tips, a golden handle and a jewelled butt
	if t >= 6:
		_pk_fill(p, 2.0, L - 1.8, -1.3, 1.3, gold)
		_pk_fill(p, 2.0, L - 1.8, -1.3, -0.4, Color("ffe08a"))
		for u in [5.0, 7.5, 10.0, 12.5]:
			_pk_fill(p, u, u + 0.7, -1.3, 1.3, Color("b8842a"))
	if t >= 5:
		var cen := Vector2(PK_O.x + L * 0.7071, PK_O.y - L * 0.7071)
		p.gem(cen.x, cen.y, 2.0 if t < 6 else 2.6, Color("5be0ff"))
	if t >= 6:
		for sgn in [-1.0, 1.0]:
			var q := Vector2(L - 0.012 * hl * hl, sgn * (hl - 1.0))
			var pt := PK_O + Vector2((q.x + q.y) * 0.7071, (-q.x + q.y) * 0.7071)
			p.gem(pt.x, pt.y, 1.3, Color("5be0ff"))
		p.gem(PK_O.x + 0.8, PK_O.y - 1.0, 1.4, Color("e04060"))

# ------------------------------------------------------------------------------------------------------------------------ bow

func draw_bow(p: Paint, t: int) -> void:
	var x0: int = [0, 3, 2, 2, 1, 1, 1][t]
	var x1: int = [0, 29, 30, 30, 31, 31, 31][t]
	var b: float = [0.0, 10.0, 10.5, 11.0, 12.0, 12.5, 12.5][t]
	var wood := Paint.WOOD
	var wood_l := Paint.WOOD_L
	if t >= 4:
		wood = Color("6a3a1c")
		wood_l = Color("c98a4a")
	if t >= 6:
		wood = Paint.GOLD_D
		wood_l = Paint.GOLD_L
	var thick := 2 if t < 3 else 3
	var cn := 40 if t == 1 else 40 + (x1 - x0) * 2
	for i in cn + 1:
		var u := i / float(cn)
		var x := x0 + (x1 - x0) * u
		var y := 16.0 - b * sin(PI * u) + 0.0001          # (the tier 1 icon was drawn in float32, which rounds the last point up)
		for k in thick:
			p.px(int(x), int(y) + k, wood if k < thick - 1 or thick == 2 and k == 0 else wood_l)
		p.px(int(x), int(y) + thick - 1, wood_l)
		if thick == 3:
			p.px(int(x), int(y), wood)
	var sy := 17
	if t >= 2:
		# tier 2: recurved tips (they curl back toward the string) with metal nocks, a leather grip wrap, a brighter two-ply string
		for sgn in [0, 1]:
			var tx: int = x0 if sgn == 0 else x1
			var dir := -1 if sgn == 0 else 1
			p.px(tx, 17, wood)
			p.px(tx + dir * 0, 18, wood)
			p.px(tx + dir, 18, wood_l)
			p.px(tx + dir, 19, wood)
			sy = 17
			p.rect(tx - 1 if sgn == 0 else tx, 16, tx + 1 if sgn == 1 else tx, 16, Paint.STEEL_L)
			p.px(tx, 15, Paint.STEEL)
		p.rect(13, int(16.0 - b) - 1, 18, int(16.0 - b) + thick, Color("5a3a1c"))
		p.rect(13, int(16.0 - b), 18, int(16.0 - b), Color("a07840"))
		p.rect(13, int(16.0 - b) + 2, 18, int(16.0 - b) + 2, Color("a07840"))
	var string_c := Color("e8e8e8") if t < 5 else Color("bff4ff")
	p.line(Vector2(x0, sy), Vector2(x1, sy), string_c)
	if t >= 2:
		p.line(Vector2(x0 + 1, sy + 1), Vector2(x1 - 1, sy + 1), Color("b8b8c0") if t < 5 else Color("7fd0f0"))
	# the arrow: shaft, head, fletching (grows more elaborate)
	p.line(Vector2(16, 6), Vector2(16, 25), Color("a07840") if t < 6 else Paint.GOLD_L)
	var head_top := 2
	var head_col := Paint.STEEL if t < 4 else Paint.STEEL_L
	for y in range(head_top, 7):
		var half := (y - head_top) * 0.5
		if t >= 2:
			half = (y - head_top) * 0.6
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			p.px(x, y, head_col if t < 6 else Paint.GOLD_L)
	if t >= 4:
		for off in [-2, 3]:                     # barbs
			p.px(16 + off, 6, head_col if t < 6 else Paint.GOLD)
			p.px(16 + off, 5, head_col if t < 6 else Paint.GOLD)
	p.rect(14, 24, 18, 26, Color("d85a4a"))
	if t >= 3:
		p.rect(14, 24, 18, 24, Color("f2e8d8"))
		p.rect(13, 25, 13, 26, Color("d85a4a"))
		p.rect(19, 25, 19, 26, Color("d85a4a"))
		p.rect(14, 27, 18, 27, Color("c8d0d8") if t < 5 else Paint.GOLD)
	# tier 3: a gem set in the grip and gold caps on the limb tips
	if t >= 3:
		p.gem(15.5, 16.0 - b + 1.5, 1.7, Color("e04060"))
		for tx in [x0, x1]:
			p.px(tx, 15, Paint.GOLD)
			p.px(tx, 14, Paint.GOLD_L)
	# tier 4: the bigger, deeper-curved limbs and the laminated stripe along them are drawn above; add rune notches on the limbs
	if t >= 4:
		for i in range(3, cn - 2, 6):
			var u := i / float(cn)
			var x := x0 + (x1 - x0) * u
			var y := 16.0 - b * sin(PI * u)
			p.px(int(x), int(y) + 1, Paint.GOLD_D)
	# tier 5: feather plumes hanging from the limb tips, gold inlay along the limbs, glowing string
	if t >= 5:
		for i in range(2, cn - 1, 3):
			var u := i / float(cn)
			var x := x0 + (x1 - x0) * u
			var y := 16.0 - b * sin(PI * u)
			p.px(int(x), int(y) + 1, Paint.GOLD)
		for sgn in [0, 1]:
			var fx: int = x0 - 1 if sgn == 0 else x1 + 1
			for k in 4:
				p.px(fx, 18 + k, Color("f2e8d8") if k % 2 == 0 else Color("d85a4a"))
	# tier 6: golden limbs, a crystal in the grip, a diamond arrow head and a long plume on each tip
	if t >= 6:
		p.gem(15.5, 16.0 - b + 1.5, 2.1, Color("5be0ff"))
		for sgn in [0, 1]:
			var fx: int = x0 - 1 if sgn == 0 else x1 + 1
			for k in 3:
				p.px(fx, 22 + k, Color("bff4ff"))
		p.diamond(15.5, 3.5, 1.6, 2.2, Paint.WHITE)

# --------------------------------------------------------------------------------------------------------------------- daggers

func _dagger(p: Paint, cx: int, t: int, mirror: int) -> void:
	var top: int = [0, 3, 1, 1, 0, 0, 0][t]
	var hw: float = [0.0, 1.6, 1.8, 2.2, 2.4, 2.7, 3.0][t]
	for y in range(top, 20):
		var half := hw
		if y < top + 5:
			half = (y - top) * (hw / 5.0) if t >= 2 else (hw if y >= 7 else (y - 3) * 0.4)
		# tier 5-6: a wavy (kris) blade
		for x in range(int(cx - half), int(cx + half) + 1):
			p.px(x, y, Paint.STEEL if x <= cx else Paint.STEEL_D)
		if t >= 2 and y > top + 3 and y < 19:
			p.px(cx, y, Paint.STEEL_L)               # fuller
		if t >= 5 and y > top + 2 and y < 19:
			_if_on(p, int(cx - half), y, Paint.GOLD_L)           # gold along the edges
			_if_on(p, int(cx + half), y, Paint.GOLD)
			if t >= 6:
				p.px(cx + 1, y, Color("7fd0f0") if y % 2 == 0 else Paint.STEEL_D)
	# guard
	var gw := 3 if t < 3 else (4 if t < 5 else 5)
	p.rect(cx - gw, 20, cx + gw, 21, Paint.GOLD)
	if t >= 2:
		p.rect(cx - gw, 20, cx + gw, 20, Paint.GOLD_L)
		p.rect(cx - gw, 21, cx + gw, 21, Paint.GOLD_D)
		p.px(cx - gw, 19, Paint.GOLD)
		p.px(cx + gw, 19, Paint.GOLD)
	p.rect(cx - 1, 22, cx, 27, Paint.WOOD)
	if t >= 2:
		for y in [23, 25, 27]:
			p.rect(cx - 1, y, cx, y, Paint.WOOD_D)
		p.rect(cx - 1, 22, cx - 1, 27, Paint.WOOD_L if t < 4 else Color("c9a86a"))
	# tier 3: a ruby in the guard and a ball pommel
	p.rect(cx - 2, 28, cx + 1, 29, Paint.GOLD)
	if t >= 3:
		p.gem(cx + 0.0, 20.8, 1.1, Color("e04060"))
		p.px(cx - 1, 30, Paint.GOLD)
		p.px(cx, 30, Paint.GOLD_D)
	# tier 4: a hooked parrying prong on the outer side of the guard, serrations along the outer edge
	if t >= 4:
		var side := mirror
		p.rect(cx + side * (gw + 1), 17, cx + side * (gw + 1), 20, Paint.STEEL)
		p.px(cx + side * (gw + 1), 16, Paint.STEEL_L)
		for y in range(7, 19, 3):
			p.px(cx + side * 2, y, Paint.CLEAR)
	# tier 5: gold along the edges, a bigger pommel gem
	if t >= 5:
		p.gem(cx - 0.0, 29.0, 1.5, Color("5be0ff"))
	# tier 6: gold wings on the guard and a rune light down the blade
	if t >= 6:
		for sgn in [-1, 1]:
			p.line(Vector2(cx + sgn * gw, 20), Vector2(cx + sgn * (gw + 2), 17), Paint.GOLD, 1)
		for y in range(6, 18, 3):
			p.px(cx, y, Color("bff4ff"))
		p.px(cx, 0, Paint.WHITE)

func draw_daggers(p: Paint, t: int) -> void:
	_dagger(p, 9, t, -1)
	_dagger(p, 22, t, 1)

# -------------------------------------------------------------------------------------------------------------------- scimitar

func draw_scimitar(p: Paint, t: int) -> void:
	var n := 40 if t == 1 else 60
	var amp: float = [0.0, 7.0, 7.5, 8.0, 8.5, 9.0, 9.0][t]
	var w0: float = [0.0, 2.6, 2.8, 3.2, 3.6, 3.6, 3.9][t]
	var y_top: float = [0.0, 2.0, 1.5, 1.0, 1.0, 0.5, 0.0][t]
	var y_bot := 27.0 if t == 1 else 26.0
	for i in n:
		var u := i / float(n - 1)
		var pt := Vector2(14.0 + amp * sin(u * 1.9), y_bot - (y_bot - y_top) * u)
		var w := w0 * (1.0 - 0.7 * u)
		if t >= 2:
			w = w0 * (1.0 - 0.55 * pow(u, 1.5)) if u < 0.85 else w0 * (1.0 - 0.55 * pow(u, 1.5)) * (1.0 - (u - 0.85) * 5.0)
		for dx in range(-int(w), int(w) + 1):
			var col := Paint.STEEL if dx <= 0 else Paint.STEEL_D
			if t >= 2 and dx == 0 and u > 0.05 and u < 0.9:
				col = Paint.STEEL_L              # fuller
			p.px(int(pt.x) + dx, int(pt.y), col)
		if t >= 3 and u > 0.08 and u < 0.9 and i % 3 == 0:
			p.px(int(pt.x) - int(w), int(pt.y), Paint.STEEL_L)
		if t >= 4 and u > 0.1 and u < 0.9:
			p.px(int(pt.x) + int(w), int(pt.y), Paint.STEEL_D.darkened(0.15) if i % 4 else Paint.CLEAR)       # a serrated back edge
		if t >= 5 and u > 0.1 and u < 0.9 and i % 2 == 0:
			p.px(int(pt.x), int(pt.y), Color("5be0ff"))                          # runes along the fuller
		if t >= 6 and u > 0.05 and u < 0.95:
			p.px(int(pt.x) - int(w) - 0, int(pt.y), Paint.GOLD_L)
	# guard, grip, pommel
	if t == 1:
		p.rect(11, 25, 17, 26, Paint.GOLD)
		p.rect(13, 27, 15, 30, Paint.WOOD)
		return
	p.rect(10, 26, 18, 27, Paint.GOLD)
	p.rect(10, 26, 18, 26, Paint.GOLD_L)
	p.rect(10, 27, 18, 27, Paint.GOLD_D)
	p.rect(13, 28, 15, 30, Paint.WOOD)
	p.rect(13, 28, 13, 30, Paint.WOOD_L)
	p.rect(13, 29, 15, 29, Paint.WOOD_D)
	p.rect(12, 31, 16, 31, Paint.GOLD)
	if t >= 3:
		p.px(9, 25, Paint.GOLD)              # curled quillons
		p.px(19, 25, Paint.GOLD)
		p.px(9, 24, Paint.GOLD_L)
		p.px(19, 24, Paint.GOLD_L)
		p.gem(14.5, 28.5, 1.0, Color("e04060"))
	if t >= 4:
		p.disc(14.0, 26.5, 4.0, Paint.GOLD)           # a disc hand-guard
		p.disc(14.0, 26.5, 2.6, Paint.GOLD_D)
		p.gem(14.0, 26.5, 1.8, Color("e04060"))
		p.rect(13, 28, 15, 30, Paint.WOOD)
		p.rect(13, 29, 15, 29, Paint.WOOD_D)
	if t >= 5:
		for k in 3:                                   # a tassel
			p.px(18 + k, 29 + k % 2, Color("c0392b"))
		p.px(17, 29, Paint.GOLD)
	if t >= 6:
		p.ring(14.0, 26.5, 4.0, 1.0, Paint.GOLD_L)
		p.gem(14.0, 26.5, 2.0, Color("5be0ff"))
		p.line(Vector2(10, 24), Vector2(8, 21), Paint.GOLD)
		p.line(Vector2(18, 24), Vector2(20, 21), Paint.GOLD)

# ---------------------------------------------------------------------------------------------------------------------- whip

func draw_whip(p: Paint, t: int) -> void:
	var lash := Color("a0522d")
	if t == 1:
		p.rect(14, 23, 17, 30, Paint.WOOD)
		p.rect(14, 23, 14, 30, Paint.WOOD_L)
		var prev := Vector2(15.5, 23.0)
		for y in range(22, 2, -1):
			var pt := Vector2(16.0 + 6.0 * sin((22 - y) * 0.55), y)
			p.line(prev, pt, lash, 2)
			prev = pt
		p.px(int(prev.x), 2, Color("e0b040"))
		p.px(int(prev.x) + 1, 2, Color("e0b040"))
		return
	# the lash path: more segments (more turns) as the tier grows
	var freq: float = [0.0, 0.55, 0.57, 0.6, 0.6, 0.62, 0.62][t]
	var amp: float = [0.0, 6.0, 6.0, 6.5, 6.5, 6.5, 6.5][t]
	var thick := 2
	var pts := []
	for y in range(22, 1, -1):
		pts.append(Vector2(15.5 + amp * sin((22 - y) * freq) * (1.0 if y > 3 else 0.6), y))
	# tier 2: thicker braided lash (two-tone plait), a leather-wrapped handle with a knotted pommel, a metal tip cap
	for i in pts.size():
		var pt: Vector2 = pts[i]
		var braid := Color("a0522d") if i % 3 != 0 else Color("6a3418")
		if t >= 4:
			braid = Color("e0e8f0") if i % 4 < 2 else Color("6c7680")           # tier 4: a plated lash of metal segments
		if t >= 6:
			braid = Paint.GOLD if i % 4 < 2 else Paint.GOLD_D
		if i == 0:
			p.line(Vector2(15.5, 23), pt, braid, thick)
		else:
			p.line(pts[i - 1], pt, braid, thick)
	p.rect(14, 23, 17, 30, Paint.WOOD)
	p.rect(14, 23, 14, 30, Paint.WOOD_L)
	for y in [25, 27, 29]:
		p.rect(14, y, 17, y, Paint.WOOD_D)
	p.rect(13, 31, 18, 31, Paint.IRON)
	p.rect(14, 22, 17, 22, Paint.IRON_D)
	var tip: Vector2 = pts[pts.size() - 1]
	p.rect(int(tip.x), 1, int(tip.x) + 1, 2, Paint.STEEL)
	# tier 3: barbs along the lash, a gold ring on the handle, a steel blade for a tip
	if t >= 3:
		for i in range(4, pts.size() - 2, 3):
			var pt: Vector2 = pts[i]
			var dir := 1 if sin((22 - pt.y) * freq + 0.5) > 0 else -1
			p.px(int(pt.x) + dir * (thick + 1), int(pt.y), Paint.STEEL_L)
			p.px(int(pt.x) + dir * (thick + 2), int(pt.y) - 1, Paint.STEEL)
		p.rect(14, 24, 17, 24, Paint.GOLD)
		p.px(int(tip.x), 0, Paint.STEEL_L)
		p.px(int(tip.x) + 1, 1, Paint.STEEL_L)
	# tier 4: a guard disc between handle and lash and a heavy spiked head at the end (the metal links are drawn above)
	if t >= 4:
		p.rect(12, 22, 19, 22, Paint.IRON)
		p.rect(12, 21, 19, 21, Paint.IRON_D)
		p.disc(tip.x + 0.5, 2.5, 2.2, Paint.IRON)
		p.px(int(tip.x) - 2, 1, Paint.STEEL_L)
		p.px(int(tip.x) + 3, 1, Paint.STEEL_L)
		p.px(int(tip.x) + 0, 0, Paint.STEEL_L)
	# tier 5: a forked tail, gold on the handle, a gem pommel
	if t >= 5:
		for k in 4:
			p.px(int(tip.x) + 3 + k, 3 + k, Paint.STEEL if k % 2 == 0 else Paint.STEEL_D)
		p.rect(13, 21, 18, 21, Paint.GOLD)
		p.rect(14, 28, 17, 28, Paint.GOLD)
		p.gem(15.5, 31.0, 1.4, Color("5be0ff"))
	# tier 6: a golden chain whip tipped with a crystal flame and a jewelled golden grip
	if t >= 6:
		p.rect(14, 23, 17, 30, Paint.GOLD_D)
		p.rect(14, 23, 14, 30, Paint.GOLD)
		for y in [25, 27, 29]:
			p.rect(14, y, 17, y, Paint.GOLD_L)
		p.gem(tip.x + 0.5, 2.5, 2.2, Color("e04060"))
		p.px(int(tip.x) + 1, 0, Color("ff9a2a"))
		p.px(int(tip.x), 0, Color("ffd45a"))
