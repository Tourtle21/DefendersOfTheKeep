extends SceneTree
## Generates the 32x32 weapon icons (tip pointing up) into res://items/weapons/icons/.
## Run:  Godot --path . --headless --script res://tools/make_weapon_art.gd

const CLEAR := Color(0, 0, 0, 0)
const STEEL := Color("cfd8e3")
const STEEL_D := Color("8f9db0")
const WOOD := Color("8a5a2b")
const WOOD_L := Color("b07a3d")
const GOLD := Color("e8c040")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://items/weapons/icons"))
	save(spear(), "spear")
	save(hammer(), "hammer")
	save(bow(), "bow")
	save(daggers(), "daggers")
	save(whip(), "whip")
	save(shield(), "shield")
	save(staff(), "staff")
	save(scimitar(), "scimitar")
	save(frostglaive(), "frostglaive")
	save(emberflail(), "emberflail")
	save(bogstaff(), "bogstaff")
	save(crystalwand(), "crystalwand")
	make_fused_icons()
	print("weapon art written")
	quit()

func save(img: Image, name: String) -> void:
	outline(img)
	img.save_png(ProjectSettings.globalize_path("res://items/weapons/icons/%s.png" % name))

func new_img() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	return img

func px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < 32 and y < 32:
		img.set_pixel(x, y, c)

func rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(img, x, y, c)

func disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in 32:
		for x in 32:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, c)

func line(img: Image, a: Vector2, b: Vector2, c: Color, thick := 1) -> void:
	var steps := int(max(absf(b.x - a.x), absf(b.y - a.y))) * 2 + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for dx in thick:
			for dy in thick:
				px(img, int(p.x) + dx, int(p.y) + dy, c)

func outline(img: Image) -> void:
	var out := img.duplicate() as Image
	for y in 32:
		for x in 32:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 32 and q.y < 32 and img.get_pixel(q.x, q.y).a > 0.5:
					out.set_pixel(x, y, Color.BLACK)
					break
	img.copy_from(out)

func spear() -> Image:
	var img := new_img()
	rect(img, 15, 11, 16, 30, WOOD)
	rect(img, 15, 11, 15, 30, WOOD_L)
	for y in range(2, 11):
		var half := (y - 2) * 0.55
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			px(img, x, y, STEEL if x <= 15 else STEEL_D)
	rect(img, 13, 11, 18, 12, Color("c0392b"))
	return img

func hammer() -> Image:
	var img := new_img()
	rect(img, 15, 13, 16, 30, WOOD)
	rect(img, 15, 13, 15, 30, WOOD_L)
	rect(img, 7, 3, 24, 13, Color("9aa3ad"))
	rect(img, 7, 3, 24, 4, Color("c8d0d8"))
	rect(img, 7, 7, 24, 8, Color("5c6670"))
	rect(img, 7, 3, 8, 13, Color("707a85"))
	rect(img, 23, 3, 24, 13, Color("707a85"))
	return img

func bow() -> Image:
	var img := new_img()
	# limbs bulge toward the aim direction (up); string is straight below
	for i in 41:
		var t := i / 40.0
		var p := Vector2(3.0 + 26.0 * t, 16.0 - 10.0 * sin(PI * t))
		px(img, int(p.x), int(p.y), WOOD)
		px(img, int(p.x), int(p.y) + 1, WOOD_L)
	line(img, Vector2(3, 17), Vector2(29, 17), Color("e8e8e8"))
	line(img, Vector2(16, 6), Vector2(16, 25), Color("a07840"))
	for y in range(2, 7):
		var half := (y - 2) * 0.5
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			px(img, x, y, STEEL)
	rect(img, 14, 24, 18, 26, Color("d85a4a"))
	return img

func daggers() -> Image:
	var img := new_img()
	for cx in [9, 22]:
		for y in range(3, 20):
			var half := 1.6 if y >= 7 else (y - 3) * 0.4
			for x in range(int(cx - half), int(cx + half) + 1):
				px(img, x, y, STEEL if x <= cx else STEEL_D)
		rect(img, cx - 3, 20, cx + 3, 21, GOLD)
		rect(img, cx - 1, 22, cx, 27, WOOD)
		rect(img, cx - 2, 28, cx + 1, 29, GOLD)
	return img

func whip() -> Image:
	var img := new_img()
	rect(img, 14, 23, 17, 30, WOOD)
	rect(img, 14, 23, 14, 30, WOOD_L)
	var prev := Vector2(15.5, 23.0)
	for y in range(22, 2, -1):
		var p := Vector2(16.0 + 6.0 * sin((22 - y) * 0.55), y)
		line(img, prev, p, Color("a0522d"), 2)
		prev = p
	px(img, int(prev.x), 2, Color("e0b040"))
	px(img, int(prev.x) + 1, 2, Color("e0b040"))
	return img

func shield() -> Image:
	var img := new_img()
	disc(img, 16.0, 16.0, 13.0, Color("9aa3ad"))
	disc(img, 16.0, 16.0, 10.0, Color("3b6fd0"))
	disc(img, 15.0, 15.0, 6.0, Color("5b8ae8"))
	disc(img, 16.0, 16.0, 3.0, GOLD)
	for a in 8:
		var p := Vector2(16, 16) + Vector2.from_angle(a * TAU / 8.0) * 11.5
		px(img, int(p.x), int(p.y), Color("c8d0d8"))
	return img

func staff() -> Image:
	var img := new_img()
	rect(img, 15, 11, 16, 30, WOOD)
	rect(img, 15, 11, 15, 30, WOOD_L)
	line(img, Vector2(11, 3), Vector2(11, 8), WOOD, 2)
	line(img, Vector2(20, 3), Vector2(20, 8), WOOD, 2)
	rect(img, 11, 9, 20, 10, WOOD)
	disc(img, 16.0, 6.0, 5.0, Color("7f5bff"))
	disc(img, 14.5, 4.5, 1.6, Color("cbb8ff"))
	return img

func scimitar() -> Image:
	var img := new_img()
	# curved blade, tip up and bending right
	for i in 40:
		var t := i / 39.0
		var p := Vector2(14.0 + 7.0 * sin(t * 1.9), 27.0 - 25.0 * t)
		var w := 2.6 * (1.0 - 0.7 * t)
		for dx in range(-int(w), int(w) + 1):
			px(img, int(p.x) + dx, int(p.y), STEEL if dx <= 0 else STEEL_D)
	rect(img, 11, 25, 17, 26, GOLD)
	rect(img, 13, 27, 15, 30, WOOD)
	return img

func frostglaive() -> Image:
	var img := new_img()
	rect(img, 15, 12, 16, 30, Color("5a7a9a"))
	for y in range(2, 14):
		var half: float = 2.0 + sin((y - 2) / 11.0 * PI) * 4.0
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			px(img, x, y, Color("cfeaff") if x <= 15 else Color("8fc4ee"))
	return img

func emberflail() -> Image:
	var img := new_img()
	rect(img, 15, 15, 16, 30, WOOD)
	line(img, Vector2(15.5, 15), Vector2(10, 9), Color("8f9db0"), 1)
	line(img, Vector2(10, 9), Vector2(14, 5), Color("8f9db0"), 1)
	disc(img, 16.0, 6.0, 5.0, Color("b02a10"))
	disc(img, 16.0, 6.0, 3.6, Color("ff6a1a"))
	disc(img, 15.0, 5.0, 1.6, Color("ffd23a"))
	for a in 6:
		var q := Vector2(16, 6) + Vector2.from_angle(a * TAU / 6.0) * 5.5
		px(img, int(q.x), int(q.y), Color("ff9a2a"))
	return img

func bogstaff() -> Image:
	var img := new_img()
	line(img, Vector2(15, 30), Vector2(17, 12), Color("5a4a2a"), 2)
	line(img, Vector2(17, 12), Vector2(13, 8), Color("5a4a2a"), 2)
	line(img, Vector2(17, 12), Vector2(21, 8), Color("5a4a2a"), 2)
	disc(img, 16.0, 6.0, 4.5, Color("3f7a2a"))
	disc(img, 14.8, 4.8, 1.6, Color("b8f070"))
	return img

func crystalwand() -> Image:
	var img := new_img()
	rect(img, 15, 14, 16, 30, Color("6a5a8a"))
	for y in range(2, 15):
		var half: float = 1.0 + (7 - abs(y - 8)) * 0.6
		for x in range(int(15.5 - half), int(16.5 + half) + 1):
			px(img, x, y, Color("d9bfff") if x <= 15 else Color("9a6fe0"))
	return img

# ---------- fused (tier 2+) icons: the two parents crossed, with a tier-coloured outline ----------

const TIER_COLORS := {2: Color("e8c040"), 3: Color("5be0ff"), 4: Color("c080ff")}

func load_icon(id: String) -> Image:
	var path := ProjectSettings.globalize_path("res://items/weapons/icons/%s.png" % id)
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	var legacy := {"sword": "res://items/tools/sword/excalibur_.png", "pickaxe": "res://items/tools/pickaxe/pickaxe.png"}
	var img := Image.load_from_file(ProjectSettings.globalize_path(legacy[id]))
	img.convert(Image.FORMAT_RGBA8)
	return img.get_region(Rect2i(0, 0, 32, 32))

func composite(a: Image, b: Image, tier: int) -> Image:
	var out := new_img()
	for layer in [[b, 0.55, 3.0], [a, -0.55, -3.0]]:
		var src: Image = layer[0]
		var ang: float = layer[1]
		var shift: float = layer[2]
		for y in 32:
			for x in 32:
				var p := Vector2(x + 0.5 - shift - 16.0, y + 0.5 - 16.0).rotated(-ang) / 0.92 + Vector2(16, 16)
				var sx := int(p.x)
				var sy := int(p.y)
				if sx >= 0 and sy >= 0 and sx < 32 and sy < 32 and src.get_pixel(sx, sy).a > 0.5:
					out.set_pixel(x, y, src.get_pixel(sx, sy))
	# tier-coloured outline (gold for tier 2, cyan for tier 3)
	var col: Color = TIER_COLORS.get(tier, Color.WHITE)
	var edge := out.duplicate() as Image
	for y in 32:
		for x in 32:
			if out.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 32 and q.y < 32 and out.get_pixel(q.x, q.y).a > 0.5:
					edge.set_pixel(x, y, col)
					break
	return edge

func make_fused_icons() -> void:
	for tier in [2, 3, 4]:
		for key in Fusion.RECIPES:
			var r: Dictionary = Fusion.RECIPES[key]
			if r.tier != tier:
				continue
			var parts: PackedStringArray = key.split("+")
			var img := composite(load_icon(parts[0]), load_icon(parts[1]), tier)
			img.save_png(ProjectSettings.globalize_path("res://items/weapons/icons/%s.png" % r.id))
