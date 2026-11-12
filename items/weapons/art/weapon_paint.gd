extends RefCounted
## The pixel kit every weapon's per-tier art is drawn with (see weapon_tier_art.gd): a square canvas (32 by default), tip up, the grip at the
## bottom centre, plus the same helpers as tools/make_weapon_art.gd (px, rect, disc, line) and a few more (ellipse, polygon, ring, diamond,
## gem, bands). Pure drawing: no autoload is touched, so it also runs in a --script test and in the contact sheet tool.

const CLEAR := Color(0, 0, 0, 0)
const STEEL := Color("cfd8e3")
const STEEL_D := Color("8f9db0")
const STEEL_L := Color("f2f6fb")
const IRON := Color("9aa3ad")
const IRON_D := Color("5c6670")
const WOOD := Color("8a5a2b")
const WOOD_L := Color("b07a3d")
const WOOD_D := Color("5a3a1c")
const GOLD := Color("e8c040")
const GOLD_L := Color("fff0a0")
const GOLD_D := Color("a07818")
const RED := Color("c0392b")
const WHITE := Color(1, 1, 1)

var img: Image
var size := 32

func _init(s := 32) -> void:
	size = s
	img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)

func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < size and y < size:
		img.set_pixel(x, y, c)

## Draws only where the canvas is still empty (for shading behind what is already there).
func px_under(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < size and y < size and img.get_pixel(x, y).a < 0.5:
		img.set_pixel(x, y, c)

func get_px(x: int, y: int) -> Color:
	if x >= 0 and y >= 0 and x < size and y < size:
		return img.get_pixel(x, y)
	return CLEAR

func rect(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(x, y, c)

func disc(cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - r) - 1), mini(size, int(cy + r) + 2)):
		for x in range(maxi(0, int(cx - r) - 1), mini(size, int(cx + r) + 2)):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, c)

func ring(cx: float, cy: float, r: float, w: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - r) - 1), mini(size, int(cy + r) + 2)):
		for x in range(maxi(0, int(cx - r) - 1), mini(size, int(cx + r) + 2)):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r and d > r - w:
				img.set_pixel(x, y, c)

func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - ry) - 1), mini(size, int(cy + ry) + 2)):
		for x in range(maxi(0, int(cx - rx) - 1), mini(size, int(cx + rx) + 2)):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			if d.length() <= 1.0:
				img.set_pixel(x, y, c)

func line(a: Vector2, b: Vector2, c: Color, thick := 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) * 2 + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for dx in thick:
			for dy in thick:
				px(int(p.x) + dx, int(p.y) + dy, c)

## Filled polygon (even-odd) from points in pixel coordinates.
func poly(pts: PackedVector2Array, c: Color) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(maxi(0, int(lo.y)), mini(size, int(hi.y) + 1)):
		for x in range(maxi(0, int(lo.x)), mini(size, int(hi.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, c)

## A diamond (rhombus) of half-width rx and half-height ry.
func diamond(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	poly(PackedVector2Array([Vector2(cx, cy - ry), Vector2(cx + rx, cy), Vector2(cx, cy + ry), Vector2(cx - rx, cy)]), c)

## A faceted gem: body colour, a light facet top-left and a dark one bottom-right.
func gem(cx: float, cy: float, r: float, c: Color) -> void:
	disc(cx, cy, r, c)
	if r >= 1.5:
		disc(cx - r * 0.3, cy - r * 0.3, maxf(0.6, r * 0.45), c.lightened(0.55))
		px(int(cx + r * 0.4), int(cy + r * 0.4), c.darkened(0.35))

## A blade-like column: from y0 (top, narrow `w0` half-width) to y1 (bottom, `w1`), light left half and dark right half, centre column cx.
func column(cx: float, y0: int, y1: int, w0: float, w1: float, light: Color, dark: Color) -> void:
	for y in range(y0, y1 + 1):
		var t := float(y - y0) / maxf(1.0, float(y1 - y0))
		var half := lerpf(w0, w1, t)
		for x in range(int(cx - half), int(cx + half) + 1):
			px(x, y, light if x <= cx else dark)

## Replaces every opaque pixel of colour `from` with `to` (used for tinting a finished part).
func recolor(from: Color, to: Color) -> void:
	for y in size:
		for x in size:
			if img.get_pixel(x, y).is_equal_approx(from):
				img.set_pixel(x, y, to)

## The dark one-pixel outline round everything drawn (same as tools/make_weapon_art.gd).
func outline(c := Color.BLACK) -> void:
	var out := img.duplicate() as Image
	for y in size:
		for x in size:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < size and q.y < size and img.get_pixel(q.x, q.y).a > 0.5:
					out.set_pixel(x, y, c)
					break
	img.copy_from(out)
