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
