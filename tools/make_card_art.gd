extends SceneTree
## Generates the pixel-art card frames, icons and card back into res://ui/cards/.
## Run:  Godot --path . --headless --script res://tools/make_card_art.gd
## Style matches the wave tokens (ui/hud/tokens): navy fill, black outline,
## grey-blue corner studs. Tweak colours/shapes here and re-run, or paint over
## the PNGs by hand afterwards.

const W := 48
const H := 80
const NAVY := Color("252c52")
const NAVY_DARK := Color("1b2040")
const STUD := Color("658292")
const STUD_HI := Color("9db8c8")
const BLACK := Color("000000")
const CLEAR := Color(0, 0, 0, 0)

const ACCENTS := {
	"fireball": Color("ff7a1a"),
	"frost_ring": Color("6fd0ff"),
	"rejuvenation": Color("5be37a"),
	"aegis": Color("b39bff"),
	"magnet": Color("ffd23a"),
	"sandstorm": Color("e8c870"),
	"blizzard": Color("cfeaff"),
	"lava_pool": Color("ff6a1a"),
	"poison_cloud": Color("8be04a"),
	"crystal_spikes": Color("c89cff"),
	"barricade": Color("b8844a"),
	"spike_trap": Color("c0c4d0"),
	"sentry": Color("e8cc66"),
	"mender": Color("6df08a"),
	"iron_wall": Color("c9ced8"),
	"frost_totem": Color("9fdcff"),
	"ember_turret": Color("ff7a33"),
	"thorn_hedge": Color("7fd04f"),
	"crystal_pylon": Color("c89cff"),
	"storm_spire": Color("b0d4ff"),
	"magma_wall": Color("ff7a3a"),
	"venom_tower": Color("8fe04a"),
	"prism_tower": Color("ffc8ff"),
	"healing_grove": Color("6dffaa"),
	"guards": Color("8fb4ff"),
	"charm": Color("ff8fd0"),
	"torch": Color("ffb040"),
	"flare": Color("fff0a0"),
	"meteor_shower": Color("ffb030"),
	"stasis": Color("bfe6ff"),
	"sunspire": Color("ffe070"),
	"phoenix_shrine": Color("ff8a3a"),
}

# Card Fuser hybrids: id -> [parent a, parent b, frame accent]. The icon is the two parents' icons joined along a diagonal.
const FUSED := {
	"frostfire": ["fireball", "frost_ring", Color("a9c8ff")],
	"solar_burst": ["fireball", "flare", Color("ffe07a")],
	"spiked_wall": ["barricade", "spike_trap", Color("d0c0a0")],
	"spiked_sentry": ["spike_trap", "sentry", Color("e0d890")],
	"beacon_turret": ["torch", "sentry", Color("ffb860")],
	"healing_lantern": ["mender", "torch", Color("9affc0")],
	"bonfire_wall": ["barricade", "torch", Color("ff9a4a")],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/cards"))
	if "only=frames" in OS.get_cmdline_user_args():
		# every frame in its kind's look (spell / build), plus the weapon frame: icons and hand-painted art are left alone
		var styles := {}
		var game = root.get_node("Game")
		for id in game.CARDS:
			var c: Dictionary = game.CARDS[id]
			styles[str(c.get("art", c.kind))] = "build" if c.kind == "build" else "spell"
		for kind in ACCENTS:
			save(make_frame(ACCENTS[kind], false, styles.get(kind, "spell")), "frame_%s" % kind)
		for id in FUSED:
			save(make_frame(FUSED[id][2], false, styles.get(id, "spell")), "frame_%s" % id)
		save(make_frame(Color("b8c4d8"), false, "weapon"), "frame_weapon")
		print("card frames written")
		quit()
		return
	if "only=legend" in OS.get_cmdline_user_args():
		for kind in ["meteor_shower", "stasis", "sunspire", "phoenix_shrine"]:
			save(make_frame(ACCENTS[kind], false), "frame_%s" % kind)
		save(make_meteor(), "icon_meteor_shower")
		save(make_stasis(), "icon_stasis")
		save(make_turret(Color("ffe070")), "icon_sunspire")
		save(make_totem(Color("ff8a3a")), "icon_phoenix_shrine")
		print("legendary card art written")
		quit()
		return
	if "only=fused" in OS.get_cmdline_user_args():
		for id in FUSED:
			save(make_frame(FUSED[id][2], false), "frame_%s" % id)
			save(blend(parent_icon(FUSED[id][0]), parent_icon(FUSED[id][1])), "icon_%s" % id)
		print("fused card art written")
		quit()
		return
	if "only=night" in OS.get_cmdline_user_args():
		# just the newest cards, so hand-painted art for the older ones is left alone
		for kind in ["torch", "flare"]:
			save(make_frame(ACCENTS[kind], false), "frame_%s" % kind)
		save(make_torch(), "icon_torch")
		save(make_flare(), "icon_flare")
		print("night card art written")
		quit()
		return
	for kind in ACCENTS:
		save(make_frame(ACCENTS[kind], false), "frame_%s" % kind)
	save(make_frame(Color("8a93b8"), true), "card_back")
	save(make_flame(), "icon_fireball")
	save(make_snowflake(), "icon_frost_ring")
	save(make_cross(), "icon_rejuvenation")
	save(make_shield(), "icon_aegis")
	save(make_coin(), "icon_magnet")
	save(make_sandstorm(), "icon_sandstorm")
	save(make_blizzard(), "icon_blizzard")
	save(make_lava(), "icon_lava_pool")
	save(make_poison(), "icon_poison_cloud")
	save(make_spikes(), "icon_crystal_spikes")
	save(make_wall(Color("a9743c")), "icon_barricade")
	save(make_wall(Color("b9bfcc")), "icon_iron_wall")
	save(make_hedge(), "icon_thorn_hedge")
	save(make_trap(), "icon_spike_trap")
	save(make_turret(Color("e8cc66")), "icon_sentry")
	save(make_turret(Color("ff7a33")), "icon_ember_turret")
	save(make_turret(Color("c89cff")), "icon_crystal_pylon")
	save(make_totem(Color("5be37a")), "icon_mender")
	save(make_totem(Color("9fdcff")), "icon_frost_totem")
	save(make_turret(Color("b0d4ff")), "icon_storm_spire")
	save(make_wall(Color("e0602a")), "icon_magma_wall")
	save(make_turret(Color("8fe04a")), "icon_venom_tower")
	save(make_turret(Color("ffc8ff")), "icon_prism_tower")
	save(make_totem(Color("6dffaa")), "icon_healing_grove")
	save(make_guard(), "icon_guards")
	save(make_heart(), "icon_charm")
	print("card art written")
	quit()

func parent_icon(id: String) -> Image:
	match id:
		"fireball": return make_flame()
		"frost_ring": return make_snowflake()
		"flare": return make_flare()
		"torch": return make_torch()
		"barricade": return make_wall(Color("a9743c"))
		"spike_trap": return make_trap()
		"sentry": return make_turret(Color("e8cc66"))
		"mender": return make_totem(Color("5be37a"))
	return new_img(32, 32)

## Left-below the diagonal from `a`, right-above it from `b`, then a fresh outline.
func blend(a: Image, b: Image) -> Image:
	for im in [a, b]:
		if im.get_width() != 32:
			im.resize(32, 32, Image.INTERPOLATE_NEAREST)          # some icons are drawn at 16 px
	var img := new_img(32, 32)
	for y in 32:
		for x in 32:
			var src: Image = a if (x + y) < 32 else b
			img.set_pixel(x, y, src.get_pixel(x, y))
	outline(img)
	return img

func save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path("res://ui/cards/%s.png" % name))

func make_torch() -> Image:
	var img := new_img(32, 32)
	for y in range(14, 29):
		for x in range(14, 18):
			img.set_pixel(x, y, Color("8a5a2b") if x > 14 else Color("b07a3d"))
	for x in range(12, 20):
		for y in range(12, 15):
			img.set_pixel(x, y, Color("5a3a1c"))
	disc(img, 16.0, 8.0, 6.5, Color("ff7a1a"))
	disc(img, 16.0, 7.0, 4.6, Color("ffb52e"))
	disc(img, 16.0, 6.0, 2.6, Color("fff0a0"))
	outline(img)
	return img

func make_meteor() -> Image:
	var img := new_img(32, 32)
	for i in 9:                                        # a fiery tail up and to the right
		disc(img, 24.0 - i * 2.2, 7.0 + i * 2.2, 3.6 - i * 0.3, Color("ff7a1a", 0.9 - i * 0.08))
	disc(img, 10.0, 22.0, 6.0, Color("8a6a50"))
	disc(img, 9.0, 21.0, 4.0, Color("c8a070"))
	disc(img, 8.0, 20.0, 1.8, Color("ffe9a0"))
	outline(img)
	return img

func make_stasis() -> Image:
	var img := new_img(32, 32)
	var c := Color("bfe6ff")
	for x in range(8, 24):
		img.set_pixel(x, 6, c)
		img.set_pixel(x, 25, c)
	for i in 8:                                        # an hourglass
		for x in range(8 + i, 24 - i):
			if x == 8 + i or x == 23 - i:
				img.set_pixel(x, 7 + i, c)
				img.set_pixel(x, 24 - i, c)
	for y in range(19, 24):
		for x in range(14 - (24 - y) / 2 + 3, 18 + (24 - y) / 2 - 2):
			img.set_pixel(x, y, Color("ffe9a0"))
	outline(img)
	return img

func make_flare() -> Image:
	var img := new_img(32, 32)
	disc(img, 16.0, 16.0, 11.0, Color("ffe9a0", 0.35))
	disc(img, 16.0, 16.0, 7.0, Color("ffd45a"))
	disc(img, 16.0, 16.0, 4.0, Color("fffbe0"))
	for i in 8:
		var a := i * TAU / 8.0
		for r in range(9, 15):
			var p := Vector2(16, 16) + Vector2.from_angle(a) * r
			img.set_pixel(clampi(int(p.x), 0, 31), clampi(int(p.y), 0, 31), Color("ffe07a"))
	outline(img)
	return img

# ---------- helpers ----------

func new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	return img

func in_round(x: int, y: int, x0: int, y0: int, x1: int, y1: int, r: int) -> bool:
	if x < x0 or x > x1 or y < y0 or y > y1:
		return false
	var cx := clampi(x, x0 + r, x1 - r)
	var cy := clampi(y, y0 + r, y1 - r)
	return Vector2(x - cx, y - cy).length() <= r + 0.35

func rect_outline(img: Image, x0: int, y0: int, x1: int, y1: int, fill: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var edge := x == x0 or x == x1 or y == y0 or y == y1
			img.set_pixel(x, y, BLACK if edge else fill)

func disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, col)

# add a 1px black outline around every filled pixel
func outline(img: Image) -> void:
	var out := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					if img.get_pixel(p.x, p.y).a > 0.5 and img.get_pixel(p.x, p.y) != BLACK:
						out.set_pixel(x, y, BLACK)
						break
	img.copy_from(out)

# ---------- card frame ----------

## Card frames come in three looks so the kind of card reads at a glance (the accent colour is per card):
##   "spell"  rounded corners, round studs, a smooth accent border (the original look)
##   "build"  square corners, a brick-pattern border and square rivets: stone and timber
##   "weapon" chamfered corners, a steel border and diamond studs
func in_chamfer(x: int, y: int, x0: int, y0: int, x1: int, y1: int, c: int) -> bool:
	if x < x0 or x > x1 or y < y0 or y > y1:
		return false
	return !(x - x0 + y - y0 < c or x1 - x + y - y0 < c or x - x0 + y1 - y < c or x1 - x + y1 - y < c)

func frame_shape(style: String, x: int, y: int, x0: int, y0: int, x1: int, y1: int, r: int) -> bool:
	match style:
		"build":
			return in_round(x, y, x0, y0, x1, y1, 1)
		"weapon":
			return in_chamfer(x, y, x0, y0, x1, y1, r + 2)
	return in_round(x, y, x0, y0, x1, y1, r)

func make_frame(accent: Color, is_back: bool, style := "spell") -> Image:
	var img := new_img(W, H)
	for y in H:
		for x in W:
			if frame_shape(style, x, y, 0, 0, W - 1, H - 1, 4):
				img.set_pixel(x, y, BLACK)
				if frame_shape(style, x, y, 1, 1, W - 2, H - 2, 3):
					img.set_pixel(x, y, NAVY)
					# the border band
					if !frame_shape(style, x, y, 3, 3, W - 4, H - 4, 2):
						var band := accent.darkened(0.35)
						if style == "build":
							band = accent.darkened(0.55 if (x / 3 + y / 2) % 2 == 0 else 0.25)           # bricks
						elif style == "weapon":
							band = Color("98a2b4") if (x + y) % 6 < 3 else Color("6c7688")               # brushed steel
						img.set_pixel(x, y, band)
	if is_back:
		# like the token back: big red gem in the middle
		var gem := [
			"..........", ".rrrrrrrr.", "rRRRRRRRRr", "rRyRRRRyRr",
			".rRRRRRRr.", "..rRRRRr..", "...rRRr...", "....rr....",
		]
		var pal := {"r": Color("7a1414"), "R": Color("991111"), "y": Color("f12323")}
		var ox := (W - 10) / 2
		var oy := (H - 8) / 2
		for j in gem.size():
			for i in gem[j].length():
				var ch: String = gem[j][i]
				if ch != ".":
					img.set_pixel(ox + i, oy + j, pal[ch])
	else:
		# art window (icon goes here), name banner, description box
		rect_outline(img, 5, 5, 42, 38, NAVY_DARK.lerp(accent, 0.16))
		rect_outline(img, 5, 40, 42, 51, NAVY_DARK)
		rect_outline(img, 5, 53, 42, 74, NAVY_DARK)
		# accent underline in the banner
		for x in range(6, 42):
			img.set_pixel(x, 50, accent.darkened(0.2))
	# corner studs, like the token corners (round for spells, square rivets for buildings, diamonds for weapons)
	for c in [Vector2(3.5, 3.5), Vector2(W - 3.5, 3.5), Vector2(3.5, H - 3.5), Vector2(W - 3.5, H - 3.5)]:
		match style:
			"build":
				for dy in range(-2, 2):
					for dx in range(-2, 2):
						img.set_pixel(int(c.x) + dx, int(c.y) + dy, BLACK if dx == -2 or dy == -2 or dx == 1 or dy == 1 else STUD)
				img.set_pixel(int(c.x) - 1, int(c.y) - 1, STUD_HI)
			"weapon":
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var d := absi(dx) + absi(dy)
						if d <= 3:
							img.set_pixel(clampi(int(c.x) + dx, 0, W - 1), clampi(int(c.y) + dy, 0, H - 1), BLACK if d == 3 else STUD)
				img.set_pixel(int(c.x), int(c.y) - 1, STUD_HI)
			_:
				disc(img, c.x, c.y, 3.6, BLACK)
				disc(img, c.x, c.y, 2.7, STUD)
				img.set_pixel(int(c.x) - 1, int(c.y) - 1, STUD_HI)
	return img

# ---------- icons (16x16) ----------

func make_flame() -> Image:
	var img := new_img(16, 16)
	# half-widths per row, tip leans slightly right
	var half := [0.0, 0.6, 1.2, 1.8, 2.6, 3.4, 4.2, 4.8, 5.2, 5.5, 5.5, 5.2, 4.4, 3.2]
	for j in half.size():
		var y := j + 1
		var lean := 0.9 if j < 4 else (0.4 if j < 7 else 0.0)
		for x in 16:
			if absf(x + 0.5 - (8.0 + lean)) <= half[j] + 0.5:
				var t := float(j) / half.size()
				img.set_pixel(x, y, Color("991111") if t < 0.25 else Color("f12323") if t < 0.55 else Color("ff7a1a"))
	# hot core
	for j in range(7, 13):
		var hw := 2.6 - absf(j - 10.0) * 0.5
		for x in 16:
			if absf(x + 0.5 - 8.0) <= hw:
				img.set_pixel(x, j + 1, Color("ffd23a") if j > 8 else Color("ff9a2a"))
	outline(img)
	return img

func make_snowflake() -> Image:
	var img := new_img(16, 16)
	var c := Vector2(7.5, 7.5)
	for k in 6:
		var dir := Vector2.RIGHT.rotated(k * TAU / 6.0 + PI / 2.0)
		for s in range(0, 14):
			var p := c + dir * (s * 0.5)
			img.set_pixel(clampi(int(p.x), 0, 15), clampi(int(p.y), 0, 15), Color("6fd0ff"))
		# little branches two thirds out
		var b := c + dir * 4.2
		for side in [-1, 1]:
			for s in range(1, 3):
				var q: Vector2 = b + dir.rotated(side * PI / 3.0) * s * 0.9
				img.set_pixel(clampi(int(q.x), 0, 15), clampi(int(q.y), 0, 15), Color("6fd0ff"))
	disc(img, 8.0, 8.0, 1.4, Color("ffffff"))
	var shadow := new_img(16, 16)
	shadow.copy_from(img)
	outline(shadow)
	return shadow

func make_cross() -> Image:
	var img := new_img(16, 16)
	for y in range(2, 14):
		for x in range(2, 14):
			var vert := x >= 6 and x <= 9
			var horiz := y >= 6 and y <= 9
			if vert or horiz:
				var col := Color("5be37a")
				if x <= 6 or y <= 6:
					col = Color("a8f5b8")
				if x >= 9 or y >= 9:
					col = Color("2fa84f")
				img.set_pixel(x, y, col)
	outline(img)
	return img

func make_shield() -> Image:
	var img := new_img(16, 16)
	var half := [5.5, 6.0, 6.0, 6.0, 6.0, 6.0, 5.8, 5.4, 4.8, 4.0, 3.2, 2.4, 1.4, 0.5]
	for j in half.size():
		var y := j + 1
		for x in 16:
			var dx := x + 0.5 - 8.0
			if absf(dx) <= half[j]:
				img.set_pixel(x, y, Color("c9b8ff") if dx < 0 else Color("8a6fe8"))
	# emblem
	for j in range(4, 9):
		img.set_pixel(7, j, Color("ffffff"))
		img.set_pixel(8, j, Color("ffffff"))
	for x in range(5, 11):
		img.set_pixel(x, 6, Color("ffffff"))
	outline(img)
	return img

func make_coin() -> Image:
	var img := new_img(16, 16)
	disc(img, 8.0, 8.0, 6.2, Color("c98a10"))
	disc(img, 8.0, 8.0, 4.8, Color("ffd23a"))
	disc(img, 6.6, 6.4, 1.6, Color("fff1a8"))
	# little sparkles
	for p in [Vector2i(13, 2), Vector2i(2, 13)]:
		img.set_pixel(p.x, p.y, Color.WHITE)
		img.set_pixel(p.x - 1, p.y, Color(1, 1, 1, 0.7))
		img.set_pixel(p.x + 1, p.y, Color(1, 1, 1, 0.7))
		img.set_pixel(p.x, p.y - 1, Color(1, 1, 1, 0.7))
		img.set_pixel(p.x, p.y + 1, Color(1, 1, 1, 0.7))
	outline(img)
	return img

func make_sandstorm() -> Image:
	var img := new_img(16, 16)
	for i in 60:
		var t := i / 60.0
		var p := Vector2(8, 8) + Vector2.from_angle(t * TAU * 2.2) * (1.0 + t * 6.2)
		img.set_pixel(clampi(int(p.x), 0, 15), clampi(int(p.y), 0, 15), Color("e8c870") if i % 3 else Color("b8903c"))
		img.set_pixel(clampi(int(p.x) + 1, 0, 15), clampi(int(p.y), 0, 15), Color("f5e2a8"))
	outline(img)
	return img

func make_blizzard() -> Image:
	var img := new_img(16, 16)
	for row in [4, 8, 12]:
		for x in range(1 + (row % 3), 15):
			img.set_pixel(x, row, Color("cfeaff") if (x + row) % 4 else Color.WHITE)
	for p in [Vector2i(3, 2), Vector2i(10, 6), Vector2i(6, 10), Vector2i(12, 13), Vector2i(2, 14)]:
		img.set_pixel(p.x, p.y, Color.WHITE)
		img.set_pixel(p.x + 1, p.y, Color("9fd0ff"))
	outline(img)
	return img

func make_lava() -> Image:
	var img := new_img(16, 16)
	disc(img, 6.0, 9.0, 5.0, Color("b02a10"))
	disc(img, 10.5, 7.5, 4.0, Color("b02a10"))
	disc(img, 6.0, 9.0, 3.6, Color("ff6a1a"))
	disc(img, 10.5, 7.5, 2.8, Color("ff6a1a"))
	disc(img, 6.0, 9.0, 1.8, Color("ffd23a"))
	img.set_pixel(10, 7, Color("ffd23a"))
	img.set_pixel(5, 3, Color("ff9a2a"))
	img.set_pixel(12, 3, Color("ff9a2a"))
	outline(img)
	return img

func make_poison() -> Image:
	var img := new_img(16, 16)
	disc(img, 5.5, 9.0, 4.0, Color("5fa832"))
	disc(img, 10.5, 9.0, 4.5, Color("5fa832"))
	disc(img, 8.0, 6.0, 4.5, Color("5fa832"))
	disc(img, 8.0, 6.0, 3.2, Color("8be04a"))
	disc(img, 10.5, 9.5, 2.6, Color("8be04a"))
	img.set_pixel(6, 6, Color("1c3a10"))
	img.set_pixel(9, 6, Color("1c3a10"))
	img.set_pixel(7, 9, Color("1c3a10"))
	img.set_pixel(8, 9, Color("1c3a10"))
	outline(img)
	return img

func make_spikes() -> Image:
	var img := new_img(16, 16)
	for spec in [[4, 14, 6], [8, 14, 11], [12, 14, 7]]:
		var cx: int = spec[0]
		for y in range(spec[2], spec[1] + 1):
			var half: float = (y - spec[2]) * 0.45
			for x in range(int(cx - half), int(cx + half) + 1):
				img.set_pixel(clampi(x, 0, 15), y, Color("c89cff") if x <= cx else Color("8a5fe0"))
	outline(img)
	return img

func make_wall(col: Color) -> Image:
	var img := new_img(16, 16)
	for row in 3:
		var y0 := 3 + row * 4
		for y in range(y0, y0 + 3):
			for x in range(1, 15):
				img.set_pixel(x, y, col if (x + row) % 5 != 0 else col.darkened(0.35))
	outline(img)
	return img

func make_hedge() -> Image:
	var img := make_wall(Color("4f8f33"))
	for x in [3, 7, 11]:
		img.set_pixel(x, 2, Color("b8e060"))
		img.set_pixel(x, 1, Color("b8e060"))
	return img

func make_trap() -> Image:
	var img := new_img(16, 16)
	for y in range(10, 14):
		for x in range(1, 15):
			img.set_pixel(x, y, Color("6a6f7e"))
	for cx in [3, 8, 12]:
		for y in range(3, 10):
			var half := int((y - 3) * 0.3)
			for x in range(cx - half, cx + half + 1):
				img.set_pixel(clampi(x, 0, 15), y, Color("d4d8e0"))
	outline(img)
	return img

func make_turret(col: Color) -> Image:
	var img := new_img(16, 16)
	disc(img, 8, 7, 4.5, col)
	for y in range(11, 15):
		for x in range(4, 12):
			img.set_pixel(x, y, col.darkened(0.35))
	for x in range(8, 15):
		img.set_pixel(x, 6, col.lightened(0.4))
		img.set_pixel(x, 7, col.lightened(0.4))
	outline(img)
	return img

func make_totem(col: Color) -> Image:
	var img := new_img(16, 16)
	for y in range(5, 15):
		for x in range(6, 10):
			img.set_pixel(x, y, Color("8a6a44"))
	disc(img, 8, 4, 3.5, col)
	for x in range(2, 14):
		img.set_pixel(x, 9, col.darkened(0.2))
	outline(img)
	return img

func make_guard() -> Image:
	var img := new_img(16, 16)
	disc(img, 8, 4, 3.0, Color("e8ecff"))
	for y in range(7, 13):
		for x in range(5, 11):
			img.set_pixel(x, y, Color("7a9cf0"))
	for y in range(2, 10):
		img.set_pixel(13, y, Color("fff2b0"))
	outline(img)
	return img

func make_heart() -> Image:
	var img := new_img(16, 16)
	disc(img, 5.5, 6, 3.5, Color("ff6fb4"))
	disc(img, 10.5, 6, 3.5, Color("ff6fb4"))
	for y in range(7, 14):
		var half := 7 - (y - 7)
		for x in range(8 - half, 8 + half):
			img.set_pixel(clampi(x, 0, 15), y, Color("ff6fb4"))
	outline(img)
	return img
