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

# ------------------------------------------------------------------------------------------------------------------- shield

func _studs(p: Paint, cx: float, cy: float, r: float, n: int, c: Color, off := 0.0) -> void:
	for a in n:
		var q := Vector2(cx, cy) + Vector2.from_angle(off + a * TAU / float(n)) * r
		p.px(int(q.x), int(q.y), c)

func draw_shield(p: Paint, t: int) -> void:
	var blue := Color("3b6fd0")
	var blue_l := Color("5b8ae8")
	if t == 1:
		p.disc(16.0, 16.0, 13.0, Paint.IRON)
		p.disc(16.0, 16.0, 10.0, blue)
		p.disc(15.0, 15.0, 6.0, blue_l)
		p.disc(16.0, 16.0, 3.0, Paint.GOLD)
		_studs(p, 16, 16, 11.5, 8, Color("c8d0d8"), 0.0)
		return
	# tier 2: a thick steel rim with a bevel and 12 rivets, a quartered field with a gold cross band, a domed steel boss
	var rim := Paint.IRON if t < 5 else Color("c8d0d8")
	var reach := 13.0 if t < 4 else 13.5
	if t >= 4:
		# tier 4: four steel spikes at the compass points
		for a in 4:
			var d := Vector2.from_angle(a * TAU / 4.0)
			for k in 3:
				var q := Vector2(16, 16) + d * (13.0 + k)
				p.px(int(q.x), int(q.y), Paint.STEEL if k < 2 else Paint.STEEL_L)
				var q2 := Vector2(16, 16) + d * (13.0 + k) + d.orthogonal() * 1.0
				if k == 0:
					p.px(int(q2.x), int(q2.y), Paint.STEEL_D)
					var q3 := Vector2(16, 16) + d * (13.0 + k) - d.orthogonal() * 1.0
					p.px(int(q3.x), int(q3.y), Paint.STEEL_D)
	p.disc(16.0, 16.0, reach, rim)
	p.ring(16.0, 16.0, reach, 1.5, Paint.STEEL_L if t < 6 else Paint.GOLD_L)
	p.ring(16.0, 16.0, reach - 2.5, 1.2, Paint.IRON_D if t < 6 else Paint.GOLD_D)
	p.disc(16.0, 16.0, 10.0, blue)
	p.disc(15.0, 15.0, 6.5, blue_l)
	# a cross band
	p.rect(15, 6, 16, 26, Paint.GOLD)
	p.rect(6, 15, 26, 16, Paint.GOLD)
	p.rect(15, 6, 15, 26, Paint.GOLD_L)
	p.rect(6, 15, 26, 15, Paint.GOLD_L)
	p.disc(16.0, 16.0, 4.0, Paint.STEEL)
	p.disc(15.5, 15.5, 2.6, Paint.STEEL_L)
	p.disc(16.0, 16.0, 1.0, Paint.IRON_D)
	_studs(p, 16, 16, 11.5, 12, Paint.STEEL_L, 0.2)
	# tier 3: a heraldic red quarter, gold rivets on the cross, a spike in the boss
	if t >= 3:
		for y in range(7, 16):
			for x in range(7, 16):
				if Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() < 9.5 and Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() > 4.2:
					p.px(x, y, Color("b03030") if (x + y) % 5 != 0 else Color("d04848"))
		for y in range(17, 26):
			for x in range(17, 26):
				if Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() < 9.5 and Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() > 4.2:
					p.px(x, y, Color("b03030") if (x + y) % 5 != 0 else Color("d04848"))
		p.rect(15, 6, 16, 26, Paint.GOLD)
		p.rect(6, 15, 26, 16, Paint.GOLD)
		p.rect(15, 6, 15, 26, Paint.GOLD_L)
		p.rect(6, 15, 26, 15, Paint.GOLD_L)
		p.disc(16.0, 16.0, 4.0, Paint.STEEL)
		p.disc(15.5, 15.5, 2.6, Paint.STEEL_L)
		p.px(15, 15, Paint.WHITE)
		_studs(p, 16, 16, 7.5, 4, Paint.WHITE, 0.785)
	# tier 4: a gold rim, bigger rivets, rim notches
	if t >= 4:
		p.ring(16.0, 16.0, reach, 1.3, Paint.GOLD)
		p.ring(16.0, 16.0, reach - 1.3, 1.0, Paint.GOLD_L)
		_studs(p, 16, 16, 11.0, 8, Paint.GOLD_L, 0.39)
	# tier 5: gems at the compass points of the rim and gold flames on the quarters
	if t >= 5:
		for a in 4:
			var q := Vector2(16, 16) + Vector2.from_angle(a * TAU / 4.0 + 0.0) * 10.8
			p.gem(q.x, q.y, 1.5, Color("5be0ff") if a % 2 == 0 else Color("e04060"))
		p.disc(16.0, 16.0, 3.0, Paint.GOLD)
		p.disc(15.5, 15.5, 1.6, Paint.GOLD_L)
	# tier 6: a golden rim, radiant spikes between the compass spikes, a crowned jewel at the boss
	if t >= 6:
		p.ring(16.0, 16.0, reach, 2.0, Paint.GOLD)
		p.ring(16.0, 16.0, reach, 1.0, Paint.GOLD_L)
		for a in 4:
			var d := Vector2.from_angle(a * TAU / 4.0 + 0.785)
			for k in 2:
				var q := Vector2(16, 16) + d * (13.5 + k)
				p.px(int(q.x), int(q.y), Paint.GOLD if k == 0 else Paint.GOLD_L)
		p.gem(16.0, 16.0, 2.4, Color("5be0ff"))
		p.px(15, 15, Paint.WHITE)

# ----------------------------------------------------------------------------------------------------------------- frostglaive

func _glaive_blade(p: Paint, y0: int, y1: int, bulge: float, base: float, light: Color, dark: Color) -> void:
	# a pointed leaf: needle tip at y0, widest about 60% down, narrowing into the collar at y1
	for y in range(y0, y1 + 1):
		var u := float(y - y0) / float(y1 - y0)
		var half: float = 0.3 + (bulge - 0.3) * sin(pow(u, 1.35) * PI * 0.98)
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			p.px(x, y, light if x <= 15 else dark)

func draw_frostglaive(p: Paint, t: int) -> void:
	var shaft := Color("5a7a9a")
	var ice_l := Color("cfeaff")
	var ice_d := Color("8fc4ee")
	if t == 1:
		p.rect(15, 12, 16, 30, shaft)
		for y in range(2, 14):
			var half: float = 2.0 + sin((y - 2) / 11.0 * PI) * 4.0
			for x in range(int(15.5 - half), int(16.5 + half) + 1):
				p.px(x, y, ice_l if x <= 15 else ice_d)
		return
	var top: int = [0, 2, 1, 0, 0, 0, 0][t]
	var bulge: float = [0.0, 4.0, 3.6, 4.2, 4.6, 5.0, 5.4][t]
	# tier 2: a longer, deeper blade with a central ridge, a frosted shaft with ice-blue wraps, a spiked butt
	p.rect(15, 12, 16, 30, shaft)
	p.rect(15, 12, 15, 30, Color("7a9aba"))
	_glaive_blade(p, top, 14, bulge, 2.0, ice_l, ice_d)
	for y in range(top + 3, 14):
		p.px(15, y, Color("ffffff"))
		p.px(16, y, Color("6aa8dc"))
	p.rect(13, 14, 18, 15, Color("3a5a7a"))
	p.rect(13, 14, 18, 14, Color("7a9aba"))
	for y in [19, 22, 25]:
		p.rect(15, y, 16, y, Color("cfeaff"))
	p.rect(14, 29, 17, 31, Color("8fc4ee"))
	p.px(15, 31, Color("ffffff"))
	# tier 3: jagged ice teeth along the blade edge and a collar of frosted crystals
	if t >= 3:
		for y in range(top + 4, 12, 3):
			var half: float = 2.0 + sin(float(y - top) / float(14 - top) * PI) * bulge
			p.px(int(15.5 - half) - 1, y, ice_l)
			p.px(int(16.5 + half) + 1, y + 1, ice_d)
		for sx in [11, 20]:
			p.line(Vector2(sx, 16), Vector2(sx + (2 if sx < 15 else -2), 13), Color("cfeaff"), 1)
		p.rect(13, 16, 18, 16, Color("6aa8dc"))
	# tier 4: a hooked back-blade spur and frost crystals growing from the collar
	if t >= 4:
		for k in 5:
			p.px(21 + k, 8 + k, ice_d)
			p.px(21 + k, 9 + k, ice_l if k < 3 else ice_d)
		p.px(26, 13, Color("ffffff"))
		for k in 3:
			p.px(11 - k, 15 + k, Color("8fc4ee"))
		p.rect(13, 14, 18, 14, Color("e8f4ff"))
	# tier 5: icicles hang from the blade edge, a crystal in the collar, silver wraps on the shaft
	if t >= 5:
		for sx in [8, 10, 22, 24]:
			p.line(Vector2(sx, 11), Vector2(sx, 14 + (sx % 3)), Color("8fc4ee"), 1)
		p.gem(15.5, 16.5, 1.8, Color("5be0ff"))
		for y in [20, 23, 26]:
			p.rect(15, y, 16, y, Color("e8f4ff"))
	# tier 6: a huge crystal blade tipped with a snowflake star, floating ice shards and silver-gold trim
	if t >= 6:
		for sx in [4, 27]:
			p.diamond(sx + 0.0, 9.0, 1.2, 2.2, Color("e8f4ff"))
		p.diamond(5.5, 20.0, 1.0, 1.8, Color("8fc4ee"))
		p.diamond(26.0, 21.0, 1.0, 1.8, Color("8fc4ee"))
		p.px(15, 0, Color.WHITE)
		p.px(16, 0, Color.WHITE)
		p.rect(13, 14, 18, 14, Paint.GOLD_L)
		p.rect(14, 28, 17, 28, Paint.GOLD_L)

# -------------------------------------------------------------------------------------------------------------------- staff

func draw_staff(p: Paint, t: int) -> void:
	var violet := Color("7f5bff")
	var violet_l := Color("cbb8ff")
	if t == 1:
		p.rect(15, 11, 16, 30, Paint.WOOD)
		p.rect(15, 11, 15, 30, Paint.WOOD_L)
		p.line(Vector2(11, 3), Vector2(11, 8), Paint.WOOD, 2)
		p.line(Vector2(20, 3), Vector2(20, 8), Paint.WOOD, 2)
		p.rect(11, 9, 20, 10, Paint.WOOD)
		p.disc(16.0, 6.0, 5.0, violet)
		p.disc(14.5, 4.5, 1.6, violet_l)
		return
	var orb_r: float = [0.0, 5.0, 5.2, 5.6, 5.6, 6.0, 6.3][t]
	var cy := 6.0 if t < 5 else 7.0
	# tier 2: a wrapped shaft with a gold cradle holding the bigger orb, silver butt cap
	p.rect(15, 11, 16, 30, Paint.WOOD)
	p.rect(15, 11, 15, 30, Paint.WOOD_L)
	for y in range(14, 28, 3):
		p.rect(15, y, 16, y, Paint.WOOD_D)
	p.rect(14, 29, 17, 31, Paint.IRON)
	p.rect(14, 29, 17, 29, Paint.STEEL_L)
	p.line(Vector2(10, 3), Vector2(10, 9), Paint.GOLD, 2)
	p.line(Vector2(21, 3), Vector2(21, 9), Paint.GOLD_D, 2)
	p.rect(10, 10, 21, 11, Paint.GOLD)
	p.rect(10, 10, 21, 10, Paint.GOLD_L)
	p.disc(16.0, cy, orb_r, violet)
	p.disc(14.5, cy - 1.5, 1.6, violet_l)
	p.disc(17.5, cy + 1.5, 1.2, Color("5a3ad0"))
	# tier 3: prongs rise into curved horns with sharp tips, the orb shows an inner swirl, a gold collar and a ruby
	if t >= 3:
		p.line(Vector2(10, 3), Vector2(8, 0), Paint.GOLD_L, 1)
		p.line(Vector2(21, 3), Vector2(23, 0), Paint.GOLD_L, 1)
		p.px(9, 1, Paint.GOLD)
		p.px(22, 1, Paint.GOLD)
		p.line(Vector2(15, cy - 2), Vector2(17, cy + 1), Color("e0d0ff"), 1)
		p.rect(14, 13, 17, 14, Paint.GOLD)
		p.gem(15.5, 15.5, 1.3, Color("e04060"))
	# tier 4: two crystals float beside the orb, gold bands on the shaft
	if t >= 4:
		p.diamond(5.0, 11.0, 1.4, 2.4, Color("b090ff"))
		p.diamond(26.5, 8.0, 1.4, 2.4, Color("b090ff"))
		p.px(5, 10, Paint.WHITE)
		p.px(26, 7, Paint.WHITE)
		for y in [19, 24]:
			p.rect(15, y, 16, y, Paint.GOLD)
	# tier 5: a crown of three prongs each side around a bigger orb, runes glowing on the shaft
	if t >= 5:
		p.line(Vector2(7, 3), Vector2(7, 10), Paint.GOLD, 1)
		p.line(Vector2(24, 3), Vector2(24, 10), Paint.GOLD_D, 1)
		p.px(7, 2, Paint.GOLD_L)
		p.px(24, 2, Paint.GOLD_L)
		for y in [17, 22, 27]:
			p.px(15, y, Color("cbb8ff"))
		p.gem(15.5, 16.2, 1.5, Color("5be0ff"))
	# tier 6: a golden shaft, a halo of shards round a radiant orb, a jewelled butt
	if t >= 6:
		p.rect(15, 15, 16, 28, Paint.GOLD_D)
		p.rect(15, 15, 15, 28, Paint.GOLD)
		for y in range(16, 28, 3):
			p.rect(15, y, 16, y, Paint.GOLD_L)
		p.disc(16.0, cy, 3.0, Color("e8d8ff"))
		p.disc(15.0, cy - 1.0, 1.4, Paint.WHITE)
		for a in 6:
			var q := Vector2(16, cy) + Vector2.from_angle(a * TAU / 6.0 + 0.3) * 9.5
			p.px(int(q.x), int(q.y), Color("e8d8ff"))
			p.px(int(q.x) + 1, int(q.y), Color("b090ff"))
		p.gem(15.5, 30.0, 1.4, Color("e04060"))

# ----------------------------------------------------------------------------------------------------------------- emberflail

func draw_emberflail(p: Paint, t: int) -> void:
	var chain := Color("8f9db0")
	if t == 1:
		p.rect(15, 15, 16, 30, Paint.WOOD)
		p.line(Vector2(15.5, 15), Vector2(10, 9), chain, 1)
		p.line(Vector2(10, 9), Vector2(14, 5), chain, 1)
		p.disc(16.0, 6.0, 5.0, Color("b02a10"))
		p.disc(16.0, 6.0, 3.6, Color("ff6a1a"))
		p.disc(15.0, 5.0, 1.6, Color("ffd23a"))
		for a in 6:
			var q := Vector2(16, 6) + Vector2.from_angle(a * TAU / 6.0) * 5.5
			p.px(int(q.x), int(q.y), Color("ff9a2a"))
		return
	var cx := 18.0
	var cy := 7.0 if t >= 3 else 6.0
	var br: float = [0.0, 5.0, 5.2, 6.0, 6.0, 6.3, 6.8][t]
	# tier 2: a spiked iron-banded ball: eight iron spikes round the molten ball, a heavier two-link chain, a wrapped handle with a guard and cap
	p.rect(15, 15, 16, 30, Paint.WOOD)
	p.rect(15, 15, 15, 30, Paint.WOOD_L)
	for y in range(19, 29, 3):
		p.rect(15, y, 16, y, Paint.WOOD_D)
	p.rect(13, 15, 18, 16, Paint.IRON_D)
	p.rect(13, 15, 18, 15, Paint.IRON)
	p.rect(14, 29, 17, 31, Paint.IRON)
	for pt in [Vector2(15.5, 15), Vector2(12.0, 12.0), Vector2(10.0, 9.0), Vector2(11.5, 6.5), Vector2(14.0, 5.0)]:
		p.rect(int(pt.x), int(pt.y), int(pt.x) + 1, int(pt.y) + 1, chain if int(pt.x + pt.y) % 2 == 0 else Paint.STEEL_L)
	p.line(Vector2(15.5, 15), Vector2(10, 9), chain, 1)
	p.line(Vector2(10, 9), Vector2(14, 5), chain, 1)
	for a in 8:
		var d := Vector2.from_angle(a * TAU / 8.0 + 0.2)
		for k in range(int(br), int(br) + 3):
			var q := Vector2(cx, cy) + d * float(k)
			p.px(int(q.x), int(q.y), Paint.STEEL if k < int(br) + 2 else Paint.STEEL_L)
	p.disc(cx, cy, br, Color("b02a10"))
	p.disc(cx, cy, br - 1.4, Color("ff6a1a"))
	p.disc(cx - 1.0, cy - 1.0, br - 3.2, Color("ffd23a"))
	# tier 3: lava cracks across the ball and a molten glow ring
	if t >= 3:
		p.line(Vector2(cx - 4, cy + 1), Vector2(cx + 1, cy - 2), Color("ffee88"), 1)
		p.line(Vector2(cx + 1, cy - 2), Vector2(cx + 4, cy + 3), Color("ffee88"), 1)
		p.ring(cx, cy, br, 1.0, Color("7a1a08"))
		p.rect(13, 17, 18, 17, Paint.IRON)
		p.rect(15, 18, 16, 18, Paint.IRON_D)
	# tier 4: a second chain, flames licking from the ball, gold bands on the handle
	if t >= 4:
		p.ring(cx, cy, br, 1.6, Color("7a1a08"))
		p.disc(cx, cy, br - 2.4, Color("ff6a1a"))
		p.disc(cx - 1.0, cy - 1.0, br - 3.6, Color("ffd23a"))
		for a in 8:
			var d := Vector2.from_angle(a * TAU / 8.0 + 0.6)
			var q := Vector2(cx, cy) + d * (br + 1.0)
			p.px(int(q.x), int(q.y), Paint.STEEL)
			q = Vector2(cx, cy) + d * (br + 2.0)
			p.px(int(q.x), int(q.y), Paint.STEEL_L)
		for pt in [Vector2(16.5, 16.0), Vector2(19.0, 15.0), Vector2(21.5, 13.0), Vector2(23.0, 11.0), Vector2(23.5, 9.0)]:
			p.rect(int(pt.x), int(pt.y), int(pt.x) + 1, int(pt.y) + 1, chain if int(pt.x + pt.y) % 2 == 0 else Paint.STEEL_L)
		p.rect(15, 21, 16, 21, Paint.GOLD)
		p.rect(15, 26, 16, 26, Paint.GOLD)
	# tier 5: obsidian horns in the ball and a gold-capped handle with an ember gem
	if t >= 5:
		for a in [1.0, 2.1, 4.2, 5.3]:
			var d := Vector2.from_angle(a)
			p.px(int(cx + d.x * (br - 2.0)), int(cy + d.y * (br - 2.0)), Color("2a1a1a"))
			p.px(int(cx + d.x * (br - 1.0)), int(cy + d.y * (br - 1.0)), Color("2a1a1a"))
		p.rect(13, 15, 18, 15, Paint.GOLD)
		p.gem(15.5, 24.0, 1.4, Color("ff6a1a"))
	# tier 6: a white-hot heart in the ball, a corona of flame, a golden handle
	if t >= 6:
		p.disc(cx - 1.0, cy - 1.0, 2.2, Color("fffbe0"))
		for k in 5:
			var q := Vector2(cx, cy) + Vector2.from_angle(-PI / 2.0 + (k - 2) * 0.55) * (br + 3.0)
			p.px(int(q.x), int(q.y), Color("ff9a2a"))
			p.px(int(q.x), int(q.y) - 1, Color("ffd23a"))
		p.rect(15, 16, 16, 28, Paint.GOLD_D)
		p.rect(15, 16, 15, 28, Paint.GOLD)
		for y in range(18, 28, 3):
			p.rect(15, y, 16, y, Paint.GOLD_L)

# ----------------------------------------------------------------------------------------------------------------- bogstaff

func draw_bogstaff(p: Paint, t: int) -> void:
	var bark := Color("5a4a2a")
	var bark_l := Color("7a6a3a")
	var green := Color("3f7a2a")
	var lime := Color("b8f070")
	if t == 1:
		p.line(Vector2(15, 30), Vector2(17, 12), bark, 2)
		p.line(Vector2(17, 12), Vector2(13, 8), bark, 2)
		p.line(Vector2(17, 12), Vector2(21, 8), bark, 2)
		p.disc(16.0, 6.0, 4.5, green)
		p.disc(14.8, 4.8, 1.6, lime)
		return
	var orb_r: float = [0.0, 4.5, 5.0, 5.2, 5.4, 5.6, 6.2][t]
	var oy := 6.0
	# tier 2: a knotted gnarled shaft with lighter bark, a bigger twig claw cradling the orb, a green vine winding up the shaft and a root-foot
	p.line(Vector2(15, 30), Vector2(17, 12), bark, 2)
	p.line(Vector2(17, 12), Vector2(12, 8), bark, 2)
	p.line(Vector2(17, 12), Vector2(22, 8), bark, 2)
	p.line(Vector2(12, 8), Vector2(11, 4), bark, 2)
	p.line(Vector2(22, 8), Vector2(23, 4), bark, 2)
	for y in range(14, 30, 4):
		p.px(15 + (30 - y) / 9, y, bark_l)
	for y in [17, 22, 26]:
		p.px(14 + (30 - y) / 9, y, Color("2a2010"))
	p.line(Vector2(14, 30), Vector2(12, 31), bark, 1)
	p.line(Vector2(16, 30), Vector2(19, 31), bark, 1)
	p.disc(16.0, oy, orb_r, green)
	p.disc(14.6, oy - 1.4, 1.7, lime)
	p.disc(17.5, oy + 1.5, 1.4, Color("2a5a1c"))
	for k in 7:
		var y := 28 - k * 2
		p.px(int(15.5 + (30 - y) / 9.0 + sin(k * 1.4) * 1.5), y, Color("5aa83a"))
	# tier 3: hanging moss strands off the claws, two red mushrooms on the shaft, swirls in the orb
	if t >= 3:
		for sx in [11, 12, 22, 23]:
			p.line(Vector2(sx, 8), Vector2(sx - 1 + (sx % 2) * 2, 12 + (sx % 3)), Color("6a9a3a"), 1)
		p.rect(12, 19, 14, 19, Color("c03030"))
		p.px(13, 20, Color("f2e8d8"))
		p.rect(18, 24, 20, 24, Color("c03030"))
		p.px(19, 25, Color("f2e8d8"))
		p.px(13, 19, Color("f2e8d8"))
		p.line(Vector2(14, 7), Vector2(18, 4), Color("8ed050"), 1)
	# tier 4: a third claw rises in the middle (three-pronged crown), the orb gets glowing eyes, spores rise
	if t >= 4:
		p.line(Vector2(17, 12), Vector2(16, 1), bark, 1)
		p.px(15, 6, Color("ffe84a"))
		p.px(18, 6, Color("ffe84a"))
		p.px(15, 7, Color("2a2010"))
		for q in [Vector2(6, 6), Vector2(27, 4), Vector2(8, 13), Vector2(26, 12)]:
			p.disc(q.x, q.y, 1.0, Color("b8f070"))
	# tier 5: lily blossoms on the claw tips, toxic drips beneath the orb, thorned vines
	if t >= 5:
		for q in [Vector2(11, 3), Vector2(23, 3)]:
			p.disc(q.x, q.y, 1.6, Color("f08ac0"))
			p.px(int(q.x), int(q.y), Color("ffe84a"))
		for q in [Vector2(14, 12), Vector2(19, 13)]:
			p.px(int(q.x), int(q.y), Color("b8f070"))
			p.px(int(q.x), int(q.y) + 1, Color("6ac030"))
		for y in range(15, 29, 5):
			p.px(18, y, Color("2a5a1c"))
			p.px(12, y + 2, Color("2a5a1c"))
	# tier 6: a giant bog-heart orb with glowing veins, a ring of spores, a root-wrapped golden collar
	if t >= 6:
		for a in 6:
			var d := Vector2.from_angle(a * TAU / 6.0 + 0.4)
			p.line(Vector2(16, oy) + d * 1.5, Vector2(16, oy) + d * 5.0, Color("d8ff90"), 1)
		p.disc(16.0, oy, 1.5, Color("fffbe0"))
		for a in 8:
			var q := Vector2(16, oy) + Vector2.from_angle(a * TAU / 8.0) * 9.0
			p.px(int(q.x), int(q.y), Color("d8ff90") if a % 2 == 0 else Color("b8f070"))
		p.rect(14, 13, 18, 14, Paint.GOLD)
		p.px(16, 13, Paint.GOLD_L)

# ------------------------------------------------------------------------------------------------------------------ crystalwand

func _crystal(p: Paint, cx: float, y0: int, y1: int, half_max: float, light: Color, dark: Color) -> void:
	# a pointed lens-shaped crystal, tip up, from y0 to y1
	for y in range(y0, y1 + 1):
		var u := float(y - y0) / float(y1 - y0)
		var half := half_max * minf(1.0, u / 0.45) * (1.0 - maxf(0.0, u - 0.85) * 3.0) + 0.3
		for x in range(int(cx - half + 0.5), int(cx + half + 0.5) + 1):
			p.px(x, y, light if x <= int(cx) else dark)
	p.px(int(cx), y0 + 1, Color(1, 1, 1))

func draw_crystalwand(p: Paint, t: int) -> void:
	var light := Color("d9bfff")
	var dark := Color("9a6fe0")
	if t == 1:
		p.rect(15, 14, 16, 30, Color("6a5a8a"))
		for y in range(2, 15):
			var half: float = 1.0 + (7 - abs(y - 8)) * 0.6
			for x in range(int(15.5 - half), int(16.5 + half) + 1):
				p.px(x, y, light if x <= 15 else dark)
		return
	# tier 2: a taller, sharper crystal in a gold collar, a wrapped shaft, a pommel jewel
	p.rect(15, 14, 16, 30, Color("6a5a8a"))
	p.rect(15, 14, 15, 30, Color("8a7aaa"))
	for y in range(18, 28, 3):
		p.rect(15, y, 16, y, Color("3a2a5a"))
	p.rect(14, 12, 17, 14, Paint.GOLD)
	p.rect(14, 12, 17, 12, Paint.GOLD_L)
	p.rect(14, 14, 17, 14, Paint.GOLD_D)
	_crystal(p, 15.5, 0, 12, 3.0, light, dark)
	p.line(Vector2(14, 8), Vector2(15, 4), Color("f2e8ff"), 1)
	p.rect(14, 29, 17, 31, Paint.GOLD)
	p.gem(15.5, 30.0, 1.1, Color("e04060"))
	# tier 3: two small crystals sprout from the collar on either side and the hilt gets a guard
	if t >= 3:
		_crystal(p, 10.0, 4, 13, 2.0, Color("e8d8ff"), Color("b88aff"))
		_crystal(p, 21.5, 5, 13, 2.0, Color("e8d8ff"), Color("b88aff"))
		p.rect(11, 14, 20, 14, Paint.GOLD_D)
		p.rect(12, 15, 19, 15, Paint.GOLD)
		p.rect(15, 18, 16, 18, Paint.GOLD)
	# tier 4: a second ring of crystals at the base and a glowing core in the main one
	if t >= 4:
		_crystal(p, 6.0, 8, 14, 1.5, Color("d9bfff"), Color("9a6fe0"))
		_crystal(p, 26.0, 9, 14, 1.5, Color("d9bfff"), Color("9a6fe0"))
		p.rect(15, 5, 16, 9, Color("fff0ff"))
		p.rect(15, 24, 16, 24, Paint.GOLD)
	# tier 5: a crown of crystals, gold inlay on the shaft, a brighter core
	if t >= 5:
		_crystal(p, 12.5, 0, 11, 1.6, Color("f4e8ff"), Color("c8a0ff"))
		_crystal(p, 19.0, 1, 11, 1.6, Color("f4e8ff"), Color("c8a0ff"))
		p.rect(15, 20, 16, 20, Paint.GOLD)
		p.rect(15, 27, 16, 27, Paint.GOLD)
		p.gem(15.5, 12.8, 1.2, Color("5be0ff"))
	# tier 6: floating shards orbit the cluster, a white-gold core and a golden shaft
	if t >= 6:
		for q in [Vector2(3.5, 3.0), Vector2(28.0, 2.5), Vector2(3.0, 19.0), Vector2(28.5, 18.0)]:
			p.diamond(q.x, q.y, 1.0, 1.8, Color("e8d8ff"))
		p.rect(15, 15, 16, 28, Paint.GOLD_D)
		p.rect(15, 15, 15, 28, Paint.GOLD)
		for y in range(17, 28, 3):
			p.rect(15, y, 16, y, Paint.GOLD_L)
		p.rect(15, 4, 16, 8, Color.WHITE)

# ------------------------------------------------------------------------------------------------------------------ legendaries

func draw_dawnbringer(p: Paint, t: int) -> void:
	var lt := Color("fff0a0")
	var dk := Color("e8c040")
	if t == 1:
		for i in 24:
			var w := 2.4 * (1.0 - 0.45 * i / 23.0)
			for dx in range(-int(w), int(w) + 1):
				p.px(16 + dx, 24 - i, lt if dx <= 0 else dk)
		p.px(16, 0, Color("fff8d0"))
		p.rect(9, 24, 23, 25, Paint.GOLD)
		p.disc(16.0, 25.0, 3.0, Color("ffd45a"))
		p.disc(16.0, 25.0, 1.5, Color("fffbe0"))
		p.rect(15, 26, 17, 30, Paint.WOOD)
		return
	var wmax: float = [0.0, 2.4, 2.9, 3.2, 3.5, 3.8, 4.2][t]
	var n := 24
	# tier 2: a broader blade with a bright fuller, an edge of deeper gold, a stronger sun at the guard and a wrapped grip with a pommel
	for i in n:
		var w := wmax * (1.0 - 0.45 * i / 23.0)
		if i > 20:
			w = wmax * 0.55 * (1.0 - float(i - 20) * 0.22)
		for dx in range(-int(w), int(w) + 1):
			var c := lt if dx <= 0 else dk
			if absi(dx) == int(w) and int(w) >= 2:
				c = Color("d8a820")
			p.px(16 + dx, 24 - i, c)
		if i > 2 and i < 22:
			p.px(16, 24 - i, Color("fffbe0"))
	p.px(16, 0, Color("fff8d0"))
	p.rect(8, 24, 24, 25, Paint.GOLD)
	p.rect(8, 24, 24, 24, Paint.GOLD_L)
	p.rect(8, 25, 24, 25, Paint.GOLD_D)
	p.disc(16.0, 25.0, 3.4, Color("ffd45a"))
	p.disc(16.0, 25.0, 1.8, Color("fffbe0"))
	p.rect(15, 26, 17, 30, Paint.WOOD)
	for y in [27, 29]:
		p.rect(15, y, 17, y, Paint.WOOD_D)
	p.rect(14, 31, 18, 31, Paint.GOLD)
	# tier 3: a sun with short rays round the guard disc, the guard tips curl up
	if t >= 3:
		for a in 8:
			var d := Vector2.from_angle(a * TAU / 8.0)
			for k in range(4, 6):
				var q := Vector2(16, 25) + d * float(k)
				p.px(int(q.x), int(q.y), Paint.GOLD_L if k == 4 else Paint.GOLD)
		for sx in [8, 24]:
			p.px(sx, 23, Paint.GOLD)
			p.px(sx + (1 if sx < 15 else -1), 22, Paint.GOLD_L)
		p.gem(16.0, 31.0, 1.0, Color("e04060"))
	# tier 4: longer sun rays and a ruby at the heart, rays of light along the blade edge
	if t >= 4:
		for a in 8:
			var d := Vector2.from_angle(a * TAU / 8.0 + 0.39)
			for k in range(5, 8):
				var q := Vector2(16, 25) + d * float(k)
				p.px(int(q.x), int(q.y), Paint.GOLD_L if k < 7 else Paint.WHITE)
		for y in range(4, 20, 4):
			p.px(16 - int(wmax * (1.0 - 0.45 * (24 - y) / 23.0)) - 1, y, Paint.WHITE)
			p.px(16 + int(wmax * (1.0 - 0.45 * (24 - y) / 23.0)) + 1, y, Paint.GOLD_L)
		p.gem(16.0, 25.0, 1.4, Color("e04060"))
	# tier 5: feathered wings sweep up from the guard and a flaming edge
	if t >= 5:
		for side in [-1, 1]:
			for k in 4:
				var x0: int = 16 + side * (6 + k * 2)
				p.line(Vector2(x0, 24 - k * 2), Vector2(x0 + side * 1, 20 - k * 3), Paint.WHITE if k % 2 == 0 else Paint.GOLD_L, 1)
		for y in range(2, 22, 3):
			var hw := int(wmax * (1.0 - 0.45 * (24 - y) / 23.0))
			p.px(16 - hw, y, Color("ff9a2a"))
			p.px(16 + hw, y + 1, Color("ffd45a"))
	# tier 6: a halo ring round the blade tip, a golden crown pommel, a white-hot core
	if t >= 6:
		p.ring(16.0, 4.0, 5.6, 1.0, Color("fff0a0"))
		p.disc(16.0, 25.0, 1.0, Color.WHITE)
		for k in 3:
			p.px(14 + k * 2, 31 - (k % 2), Paint.GOLD_L)
			p.px(14 + k * 2, 30 - (k % 2), Paint.GOLD)
		p.rect(15, 5, 17, 20, Color("fffbe0"))
		p.px(16, 0, Color.WHITE)

func draw_voidreaver(p: Paint, t: int) -> void:
	var shaft := Color("3a2a4a")
	var shaft_l := Color("5a4470")
	var bl := Color("b080ff")
	var bd := Color("6a3ac8")
	if t == 1:
		p.rect(15, 8, 16, 31, shaft)
		p.rect(15, 8, 15, 31, shaft_l)
		for i in 30:
			var u := i / 29.0
			var q := Vector2(16.0 + 14.0 * u, 8.0 - 6.0 * sin(u * PI * 0.9))
			var w := 2.6 * (1.0 - 0.8 * u)
			for dy in range(-int(w), int(w) + 1):
				p.px(int(q.x), int(q.y) + dy + 3, bl if dy <= 0 else bd)
		p.disc(16.0, 8.0, 2.4, Color("9a5aff"))
		return
	var reach: float = [0.0, 14.0, 14.5, 15.0, 15.5, 15.5, 15.5][t]
	var wmax: float = [0.0, 2.6, 3.2, 3.6, 3.9, 4.2, 4.5][t]
	var lift: float = [0.0, 6.0, 6.5, 7.0, 7.0, 7.5, 7.5][t]
	# tier 2: a deeper scythe blade with a jagged inner edge, rune bands down a darker shaft, a spiked butt
	p.rect(15, 9, 16, 31, shaft)
	p.rect(15, 9, 15, 31, shaft_l)
	for y in [14, 19, 24, 29]:
		p.rect(15, y, 16, y, Color("8a5ae0"))
	p.rect(14, 29, 17, 31, Color("2a1a3a"))
	p.px(15, 31, Color("b080ff"))
	for i in 34:
		var u := i / 33.0
		var q := Vector2(16.0 + reach * u, 9.0 - lift * sin(u * PI * 0.9))
		var w := wmax * (1.0 - 0.8 * u)
		for dy in range(-int(w), int(w) + 1):
			p.px(int(q.x), int(q.y) + dy + 3, bl if dy <= 0 else bd)
		if i % 4 == 2 and u > 0.1 and u < 0.9:
			p.px(int(q.x), int(q.y) + int(w) + 4, bd.darkened(0.2))        # a jagged inner edge
	p.disc(16.0, 9.0, 2.6, Color("9a5aff"))
	p.disc(15.2, 8.2, 1.0, Color("e0c8ff"))
	# tier 3: a bone skull at the join, and a smaller second blade curling the other way
	if t >= 3:
		p.disc(16.0, 12.5, 2.2, Color("e8e0d0"))
		p.px(15, 12, Color("2a1a3a"))
		p.px(17, 12, Color("2a1a3a"))
		p.px(16, 14, Color("2a1a3a"))
		for i in 12:
			var u := i / 11.0
			var q := Vector2(15.0 - 8.0 * u, 9.0 - 4.0 * sin(u * PI * 0.9))
			var w := 1.8 * (1.0 - 0.8 * u)
			for dy in range(-int(w), int(w) + 1):
				p.px(int(q.x), int(q.y) + dy + 2, bl if dy <= 0 else bd)
	# tier 4: glowing runes along the blade and violet flames licking the spine
	if t >= 4:
		for i in range(4, 30, 4):
			var u := i / 33.0
			var q := Vector2(16.0 + reach * u, 9.0 - lift * sin(u * PI * 0.9))
			p.px(int(q.x), int(q.y) + 3, Color("f0e0ff"))
		for i in range(2, 30, 5):
			var u := i / 33.0
			var q := Vector2(16.0 + reach * u, 9.0 - lift * sin(u * PI * 0.9))
			p.px(int(q.x), int(q.y) + 3 - int(wmax * (1.0 - 0.8 * u)) - 1, Color("c060ff"))
			p.px(int(q.x), int(q.y) + 3 - int(wmax * (1.0 - 0.8 * u)) - 2, Color("8a3ae0"))
	# tier 5: chains hang from the shaft with a soul flame, the shaft gets silver bands
	if t >= 5:
		for k in 6:
			p.px(18 + (k % 2), 14 + k * 2, Color("b8b8d0"))
		p.disc(18.5, 27.0, 1.4, Color("60ffd0"))
		p.px(18, 25, Color("c0ffe8"))
		for y in [12, 17, 22, 27]:
			p.rect(15, y, 16, y, Color("c8c0e0"))
	# tier 6: a black-gold violet crown: a third crescent and gold trim, floating soul wisps round the blade
	if t >= 6:
		for i in 14:
			var u := i / 13.0
			var q := Vector2(16.0 + 7.0 * u, 11.0 + 3.0 * sin(u * PI * 0.9) + 4.0 * u)
			p.px(int(q.x), int(q.y), Color("d0a0ff") if i % 2 == 0 else Color("8a3ae0"))
		for q in [Vector2(27, 3), Vector2(5, 3), Vector2(7, 15), Vector2(27, 17)]:
			p.disc(q.x, q.y, 1.2, Color("60ffd0"))
		p.rect(14, 12, 17, 12, Paint.GOLD)
		p.rect(14, 20, 17, 20, Paint.GOLD)
		p.gem(16.0, 9.0, 1.8, Color("fff0ff"))

func draw_mindbender(p: Paint, t: int) -> void:
	if t == 1:
		p.rect(15, 12, 16, 31, Color("b89030"))
		p.rect(15, 12, 15, 31, Color("e8c040"))
		p.rect(13, 22, 18, 23, Color("e8c040"))
		p.disc(16.0, 8.0, 6.2, Color("3a6a8a"))
		p.disc(16.0, 8.0, 4.6, Color("c8f4ff"))
		p.disc(16.0, 8.0, 2.6, Color("2a9ad0"))
		p.disc(16.0, 8.0, 1.2, Color("101830"))
		for i in 5:
			var ang := -PI / 2.0 + (i - 2) * 0.55
			var q := Vector2(16.0, 8.0) + Vector2.from_angle(ang) * 9.0
			p.px(int(q.x), int(q.y), Color("e8c040"))
			p.px(int(q.x), int(q.y) + 1, Color("e8c040"))
		return
	var cy := 9.5
	var gold := Color("e8c040")
	var gold_d := Color("b89030")
	# tier 2: the eye sits in a gold ring, filigree bands on the shaft, a bigger collar, a gold orb at the butt
	p.rect(15, 14, 16, 31, gold_d)
	p.rect(15, 14, 15, 31, gold)
	for y in range(16, 30, 3):
		p.rect(15, y, 16, y, Paint.GOLD_L)
	p.rect(12, 22, 19, 23, gold)
	p.rect(12, 22, 19, 22, Paint.GOLD_L)
	p.disc(15.5, 31.0, 1.6, gold)
	p.disc(16.0, cy, 7.0, gold_d)
	p.ring(16.0, cy, 7.0, 1.4, gold)
	p.disc(16.0, cy, 5.6, Color("3a6a8a"))
	p.disc(16.0, cy, 4.4, Color("c8f4ff"))
	p.disc(16.0, cy, 2.6, Color("2a9ad0"))
	p.disc(16.0, cy, 1.2, Color("101830"))
	p.px(14, int(cy) - 2, Color.WHITE)
	var prongs := 5 if t < 3 else (7 if t < 5 else 9)
	for i in prongs:
		var ang := -PI / 2.0 + (i - (prongs - 1) / 2.0) * (0.55 if prongs == 5 else (0.42 if prongs == 7 else 0.36))
		var q := Vector2(16.0, cy) + Vector2.from_angle(ang) * 8.4
		p.px(int(q.x), int(q.y), gold)
		p.px(int(q.x), int(q.y) - 1, Paint.GOLD_L)
	# tier 3: a slit pupil, a crown of seven prongs and a ruby in the collar
	if t >= 3:
		p.rect(16, int(cy) - 2, 16, int(cy) + 2, Color("101830"))
		p.gem(15.5, 22.8, 1.0, Color("e04060"))
		for side in [-1, 1]:                                  # small gold wings flank the eye
			for k in 3:
				p.line(Vector2(16 + side * 8, cy + 1 + k * 2), Vector2(16 + side * (11 - k), cy - 2 + k * 3), gold if k % 2 == 0 else Paint.GOLD_L, 1)
	# tier 4: three gems orbit the eye on a thin ring, a second collar
	if t >= 4:
		for a in 3:
			var q := Vector2(16, cy) + Vector2.from_angle(a * TAU / 3.0 + 0.5) * 10.6
			p.gem(q.x, q.y, 1.8, Color("5be0ff"))
		p.rect(12, 27, 19, 28, gold)
		p.rect(12, 27, 19, 27, Paint.GOLD_L)
		p.ring(16.0, cy, 8.4, 1.0, gold_d)
	# tier 5: nine prongs, runes glowing in the iris, the shaft wrapped in silver
	if t >= 5:
		for a in 6:
			var q := Vector2(16, cy) + Vector2.from_angle(a * TAU / 6.0) * 3.6
			p.px(int(q.x), int(q.y), Color("e0f8ff"))
		for y in [18, 25]:
			p.rect(15, y, 16, y, Color("e8e8f0"))
	# tier 6: a halo of light rays, white-hot iris, a jewelled golden butt
	if t >= 6:
		for a in 12:
			var q := Vector2(16, cy) + Vector2.from_angle(a * TAU / 12.0 + 0.26) * 11.6
			p.px(int(q.x), int(q.y), Color("fff0a0") if a % 2 == 0 else Color("ffffff"))
		p.disc(16.0, cy, 2.6, Color("ffffff"))
		p.disc(16.0, cy, 1.2, Color("101830"))
		p.gem(15.5, 31.0, 1.5, Color("e04060"))
