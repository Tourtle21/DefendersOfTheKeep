extends RefCounted
class_name WeaponArt
## Per-tier weapon art, composed at run time from the base icon (no extra PNGs). Tier 1 keeps the old icon; each tier adds to the
## one before: 2 polished + highlight edge, 3 a glow ring and sparkles, 4 a second ring, a white tip cross and a gem, 5 a stronger
## glow, a shine stripe and more sparkles, 6 a white-gold glow, more sparkles and edge pixels pulled to the weapon's main colour.
## The colours of a weapon come from its tiers module (`palette()` returns [main, hot, core]), else from its rarity.

static var _cache := {}

## [main, hot, core] of a weapon.
static func palette(id: String) -> Array:
	var m = WeaponTiers.mod(id)
	if m != null and m.has_method("palette"):
		return m.palette()
	var rim: Color = Game.rarity_color(Game.weapon_rarity(id))
	return [rim, rim.lightened(0.3), Color(1, 1, 1)]

static func icon(id: String, tier: int, path := "") -> Texture2D:
	if path == "":
		path = _path_of(id)
	var key := "%s:%d:%s" % [id, tier, path]
	if _cache.has(key):
		return _cache[key]
	var base: Texture2D = load(path)
	if tier < 2 or base == null:
		_cache[key] = base
		return base
	var img: Image = base.get_image()
	if img == null:
		return base
	img.convert(Image.FORMAT_RGBA8)
	var out := _compose(img, id, tier)
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex

static func hud_icon(id: String, tier: int, path := "") -> Texture2D:
	return icon(id, tier, path)

static func _path_of(id: String) -> String:
	var items: Dictionary = load("res://world/item_info.tres").items
	if items.has(id):
		return str(items[id].texture)
	return "res://items/weapons/icons/%s.png" % id

static func _opaque(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.3

static func _over(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var o := img.get_pixel(x, y)
	var a := c.a + o.a * (1.0 - c.a)
	if a <= 0.0:
		return
	var rgb := (Vector3(c.r, c.g, c.b) * c.a + Vector3(o.r, o.g, o.b) * o.a * (1.0 - c.a)) / a
	img.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a))

static func _compose(src: Image, id: String, tier: int) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var pal := palette(id)
	var main: Color = pal[0]
	var hot: Color = pal[1]
	var core: Color = pal[2]
	var rim: Color = Game.rarity_color(Game.weapon_rarity(id))
	var img := src.duplicate()
	var opaque := []
	var tip := Vector2i(w / 2, h)
	var sat_best := []
	for y in h:
		for x in w:
			if _opaque(src, x, y):
				opaque.append(Vector2i(x, y))
				if y < tip.y or (y == tip.y and absi(x - w / 2) < absi(tip.x - w / 2)):
					tip = Vector2i(x, y)
	# tier 2: polished, with a highlight along the upper-left edge
	for p in opaque:
		var c: Color = img.get_pixel(p.x, p.y)
		if c.get_luminance() > 0.12:
			c = c.lightened(0.08)
		if !_opaque(src, p.x - 1, p.y) or !_opaque(src, p.x, p.y - 1):
			c = c.lightened(0.22)
		img.set_pixel(p.x, p.y, c)
	if tier >= 3:
		var gold := Color(1.0, 0.9, 0.5)
		var glow := rim if tier < 6 else rim.lerp(gold, 0.5)
		var mult := 1.0 if tier < 5 else 1.4
		var reach := 3 if tier >= 6 else (2 if tier >= 4 else 1)
		var ring := []
		for y in range(-reach, h + reach):
			for x in range(-reach, w + reach):
				if _opaque(src, x, y):
					continue
				var d := 99
				for oy in range(-reach, reach + 1):
					for ox in range(-reach, reach + 1):
						if _opaque(src, x + ox, y + oy):
							d = mini(d, maxi(absi(ox), absi(oy)))
				if d <= reach:
					ring.append([x, y, d])
		for r in ring:
			var a: float = (0.55 if r[2] == 1 else 0.25) * mult
			_over(img, r[0], r[1], Color(glow, minf(a, 0.9)))
		# sparkles at fixed anchors along the opaque pixels
		var spark_n := 2 if tier < 5 else (4 if tier < 6 else 6)
		for i in spark_n:
			if opaque.is_empty():
				break
			var q: Vector2i = opaque[int(fposmod(sin(float(i) * 12.9898 + float(id.length())) * 43758.5453, 1.0) * float(opaque.size())) % opaque.size()]
			img.set_pixel(q.x, q.y, core)
	if tier >= 4:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_over(img, tip.x + off.x, tip.y + off.y, Color(1, 1, 1, 0.95 if off == Vector2i.ZERO else 0.7))
		# a gem where the picture is most saturated
		var best := Vector2i(w / 2, h / 2)
		var bs := -1.0
		for p in opaque:
			var c2: Color = src.get_pixel(p.x, p.y)
			var s := c2.s * c2.v
			if s > bs and p.y > tip.y + 3:
				bs = s
				best = p
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			if _opaque(src, best.x + off.x, best.y + off.y):
				img.set_pixel(best.x + off.x, best.y + off.y, hot)
	if tier >= 5:
		# a shine stripe along the brightest pixels
		var lum := []
		for p in opaque:
			lum.append([src.get_pixel(p.x, p.y).get_luminance(), p])
		lum.sort_custom(func(a, b): return a[0] > b[0])
		for i in mini(7, lum.size()):
			var p: Vector2i = lum[i][1]
			img.set_pixel(p.x, p.y, Color(1, 1, 1, 0.9).lerp(img.get_pixel(p.x, p.y), 0.15))
	if tier >= 6:
		for p in opaque:
			if !_opaque(src, p.x + 1, p.y) or !_opaque(src, p.x, p.y + 1):
				img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(main, 0.45))
	return img
