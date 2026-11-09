extends SceneTree
## Draws a 64x64 pixel-art sprite for each sector boss and the final boss.
##   Godot --headless --path . --script res://tools/make_boss_art.gd
## Writes enemies/boss/art/<sector id>.png (s, se, ne, n, nw, sw, final) and a preview to user://boss_preview.png.

const OUT := Color(0.06, 0.04, 0.08)
const SIZE := 64

var img: Image

func px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))

func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			px(x + i, y + j, c)

func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(x, y, c)

func poly(pts: Array, c: Color) -> void:
	var arr := PackedVector2Array()
	var minx := 999.0
	var maxx := -999.0
	var miny := 999.0
	var maxy := -999.0
	for p in pts:
		arr.append(Vector2(p[0], p[1]))
		minx = minf(minx, p[0]); maxx = maxf(maxx, p[0])
		miny = minf(miny, p[1]); maxy = maxf(maxy, p[1])
	for y in range(int(miny), int(maxy) + 1):
		for x in range(int(minx), int(maxx) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), arr):
				px(x, y, c)

func line(x0: int, y0: int, x1: int, y1: int, c: Color, w := 1) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in n + 1:
		var t := float(i) / maxf(1.0, n)
		var x := int(round(lerpf(x0, x1, t)))
		var y := int(round(lerpf(y0, y1, t)))
		rect(x, y, w, w, c)

func outline() -> void:
	var src := img.duplicate()
	for y in SIZE:
		for x in SIZE:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < SIZE and ny < SIZE and src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, OUT)
					break

func start() -> void:
	img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

func finish(id: String) -> void:
	outline()
	img.save_png("res://enemies/boss/art/%s.png" % id)
	print("wrote ", id)

# ------------------------------------------------------------------ the bosses

func blobbert() -> void:
	var g := Color(0.3, 0.72, 0.32)
	ell(32, 40, 25, 19, g.darkened(0.25))
	ell(32, 38, 24, 18, g)
	ell(24, 30, 12, 8, g.lightened(0.18))
	ell(32, 47, 15, 9, g.lightened(0.3))                       # belly
	ell(10, 46, 5, 5, g.darkened(0.1)); ell(54, 46, 5, 5, g.darkened(0.1))   # little arms
	for ex in [24, 40]:                                         # big googly eyes
		ell(ex, 33, 6, 7, Color.WHITE)
		ell(ex + 1, 34, 3, 4, Color(0.05, 0.05, 0.1))
		px(ex, 32, Color.WHITE)
	ell(32, 45, 10, 4, Color(0.15, 0.05, 0.08))                # grin
	for t in [24, 29, 34, 39]:
		rect(t, 42, 3, 2, Color(0.95, 0.95, 0.85))
	ell(17, 41, 3, 2, Color(0.95, 0.5, 0.55, 0.7)); ell(47, 41, 3, 2, Color(0.95, 0.5, 0.55, 0.7))
	# the crown
	var gold := Color(0.95, 0.78, 0.2)
	rect(20, 18, 24, 6, gold)
	for i in 5:
		poly([[20 + i * 6, 18], [23 + i * 6, 9 + (i % 2) * 2], [26 + i * 6, 18]], gold.lightened(0.1))
	rect(20, 22, 24, 2, gold.darkened(0.25))
	px(32, 20, Color(0.9, 0.15, 0.2)); px(25, 20, Color(0.2, 0.5, 1.0)); px(39, 20, Color(0.2, 0.5, 1.0))
	for gx in [6, 14, 50, 58]:                                  # grass tufts
		line(gx, 57, gx - 2, 52, Color(0.25, 0.6, 0.2)); line(gx, 57, gx + 2, 51, Color(0.3, 0.7, 0.25))
	finish("s")

func colossus() -> void:
	var st := Color(0.82, 0.66, 0.38)
	var hi := Color(0.95, 0.82, 0.55)
	var lo := Color(0.58, 0.44, 0.24)
	ell(32, 58, 26, 5, lo.darkened(0.2))                        # sand drift
	rect(14, 24, 36, 28, st)                                     # torso
	rect(14, 24, 36, 3, hi)
	rect(14, 49, 36, 3, lo)
	for by in [31, 38, 45]:
		rect(14, by, 36, 1, lo)                                  # brick courses
	for bx in [22, 34, 44, 27, 39]:
		rect(bx, 24 + ((bx % 3) * 7), 1, 7, lo)
	ell(10, 29, 8, 8, st); ell(54, 29, 8, 8, st)                # boulder shoulders
	ell(8, 26, 5, 4, hi); ell(52, 26, 5, 4, hi)
	rect(5, 34, 9, 18, st.darkened(0.08)); rect(50, 34, 9, 18, st.darkened(0.08))   # arms
	rect(4, 48, 11, 7, lo); rect(49, 48, 11, 7, lo)             # fists
	rect(20, 6, 24, 20, st)                                      # head block
	rect(20, 6, 24, 3, hi)
	rect(26, 14, 4, 4, Color(1.0, 0.65, 0.1)); rect(35, 14, 4, 4, Color(1.0, 0.65, 0.1))
	px(27, 15, Color(1, 0.95, 0.5)); px(36, 15, Color(1, 0.95, 0.5))
	rect(27, 21, 10, 2, lo.darkened(0.4))                        # mouth slit
	poly([[28, 6], [32, 0], [36, 6]], hi)                        # headdress peak
	poly([[32, 34], [27, 41], [32, 48], [37, 41]], Color(0.9, 0.45, 0.1))    # scarab emblem in the chest
	poly([[32, 36], [29, 41], [32, 46], [35, 41]], Color(1.0, 0.75, 0.2))
	line(18, 30, 22, 36, lo.darkened(0.3)); line(44, 40, 47, 46, lo.darkened(0.3))   # cracks
	finish("se")

func wyrm() -> void:
	var blue := Color(0.45, 0.72, 0.95)
	var pale := Color(0.85, 0.95, 1.0)
	var deep := Color(0.25, 0.45, 0.8)
	var pts := []
	for i in 40:
		var t := i / 39.0
		pts.append([10 + t * 38, 56 - t * 34 + sin(t * 8.5) * 7.0, 9.0 - t * 1.5])
	for p in pts:
		ell(p[0], p[1], p[2], p[2], deep)
	for p in pts:
		ell(p[0], p[1] - 1, p[2] - 1.5, p[2] - 2, blue)
	for p in pts:
		ell(p[0] + 1, p[1] + 2, p[2] - 4, p[2] - 5, pale)      # pale belly
	for i in range(2, 40, 5):                                    # ice spikes along the back
		var p: Array = pts[i]
		poly([[p[0] - 3, p[1] - p[2] + 2], [p[0], p[1] - p[2] - 7], [p[0] + 3, p[1] - p[2] + 2]], Color(0.8, 0.97, 1.0))
	# head
	ell(51, 19, 10, 8, deep); ell(51, 18, 9, 7, blue)
	poly([[43, 14], [41, 5], [47, 11]], pale); poly([[55, 12], [58, 4], [60, 14]], pale)   # horns
	ell(48, 16, 2.5, 2.5, Color(0.1, 0.2, 0.5)); px(48, 15, Color.WHITE)
	poly([[55, 21], [63, 19], [63, 27], [55, 25]], Color(0.12, 0.2, 0.45))                  # open mouth
	for fx in [57, 60]:
		poly([[fx, 21], [fx + 1, 25], [fx + 2, 21]], Color.WHITE)
	for c in [[60, 12, 3], [63, 8, 2], [57, 8, 2]]:                                         # frost breath
		ell(c[0], c[1], c[2], c[2], Color(0.9, 0.97, 1.0, 0.8))
	finish("ne")

func titan() -> void:
	var rock := Color(0.2, 0.14, 0.14)
	var rock_hi := Color(0.33, 0.24, 0.22)
	var lava := Color(1.0, 0.45, 0.1)
	var glow := Color(1.0, 0.85, 0.3)
	ell(32, 40, 22, 20, rock)                                    # torso
	ell(26, 33, 11, 9, rock_hi)
	ell(10, 28, 9, 8, rock); ell(54, 28, 9, 8, rock)             # shoulder boulders
	ell(8, 26, 5, 4, rock_hi); ell(52, 26, 5, 4, rock_hi)
	rect(4, 34, 9, 14, rock); rect(51, 34, 9, 14, rock)
	ell(8, 51, 7, 6, lava); ell(56, 51, 7, 6, lava); ell(8, 50, 4, 3, glow); ell(56, 50, 4, 3, glow)   # glowing fists
	for dx in [6, 9]:
		line(dx, 56, dx, 62, lava)                               # dripping lava
	for dx in [54, 57]:
		line(dx, 56, dx, 61, lava)
	rect(20, 56, 8, 7, rock); rect(36, 56, 8, 7, rock)           # legs
	# lava cracks across the body
	line(24, 28, 30, 36, lava); line(30, 36, 27, 44, lava); line(27, 44, 33, 52, lava)
	line(40, 30, 36, 38, lava); line(36, 38, 41, 46, lava); line(41, 46, 38, 54, lava)
	line(32, 36, 34, 40, glow); line(30, 36, 28, 40, glow)
	ell(32, 17, 11, 10, rock); ell(29, 14, 5, 4, rock_hi)        # head
	ell(27, 17, 2, 2, glow); ell(37, 17, 2, 2, glow)
	rect(28, 22, 9, 2, lava)                                     # molten mouth
	for i in 5:                                                   # flame crown
		var fx := 22 + i * 5
		poly([[fx - 3, 9], [fx, 0 + (i % 2) * 3], [fx + 3, 9]], lava)
		poly([[fx - 1, 9], [fx, 3 + (i % 2) * 3], [fx + 1, 9]], glow)
	finish("n")

func mother() -> void:
	var g := Color(0.32, 0.46, 0.2)
	var dark := Color(0.18, 0.28, 0.12)
	var belly := Color(0.62, 0.68, 0.38)
	ell(32, 42, 28, 18, dark)
	ell(32, 40, 27, 17, g)
	ell(26, 33, 14, 8, g.lightened(0.15))
	ell(32, 50, 17, 8, belly)                                    # belly
	for w in [[14, 38], [20, 32], [44, 36], [50, 42], [38, 30], [10, 46], [54, 48]]:
		ell(w[0], w[1], 2.5, 2, g.darkened(0.2)); px(w[0] - 1, w[1] - 1, g.lightened(0.3))   # warts
	# huge mouth
	ell(32, 44, 20, 5, Color(0.1, 0.06, 0.08))
	for tx in [16, 21, 27, 33, 39, 45]:
		rect(tx, 42, 2, 3, Color(0.92, 0.9, 0.78))
	ell(32, 49, 11, 3, Color(0.8, 0.35, 0.45))                  # tongue
	# bulging eyes on top
	for ex in [20, 44]:
		ell(ex, 22, 8, 8, g)
		ell(ex, 22, 6, 6, Color(0.95, 0.85, 0.25))
		rect(ex - 1, 18, 2, 8, Color(0.08, 0.06, 0.05))
	# mushrooms and moss on her back
	rect(30, 21, 2, 6, Color(0.9, 0.85, 0.75)); ell(31, 20, 5, 3, Color(0.8, 0.2, 0.2)); px(29, 19, Color.WHITE); px(33, 20, Color.WHITE)
	rect(56, 31, 2, 4, Color(0.9, 0.85, 0.75)); ell(57, 30, 3, 2, Color(0.8, 0.2, 0.2))
	ell(10, 36, 5, 2, Color(0.25, 0.55, 0.2)); ell(48, 27, 4, 2, Color(0.25, 0.55, 0.2))
	ell(10, 56, 7, 5, dark); ell(54, 56, 7, 5, dark)              # webbed feet
	for dx in [24, 40]:
		line(dx, 52, dx, 58, Color(0.5, 0.8, 0.3))                # slime drips
	finish("nw")

func warden() -> void:
	var lite := Color(0.82, 0.65, 1.0)
	var mid := Color(0.58, 0.38, 0.9)
	var dark := Color(0.36, 0.2, 0.62)
	var core := Color(1.0, 0.9, 1.0)
	# legs
	poly([[22, 44], [30, 44], [28, 62], [20, 62]], dark); poly([[34, 44], [42, 44], [44, 62], [36, 62]], dark)
	# torso, lit on the left
	poly([[32, 22], [14, 34], [22, 52], [32, 56]], mid)
	poly([[32, 22], [50, 34], [42, 52], [32, 56]], dark)
	poly([[32, 22], [14, 34], [32, 38]], lite)
	# arms of crystal
	poly([[14, 34], [6, 46], [10, 58], [16, 46]], mid); poly([[50, 34], [58, 46], [54, 58], [48, 46]], dark)
	# shoulder spikes
	poly([[14, 33], [6, 22], [18, 28]], lite); poly([[50, 33], [58, 22], [46, 28]], mid)
	# head
	poly([[32, 4], [22, 14], [32, 24], [42, 14]], mid); poly([[32, 4], [22, 14], [32, 14]], lite)
	rect(28, 13, 3, 2, core); rect(34, 13, 3, 2, core)
	# crown shards
	poly([[24, 8], [21, 0], [28, 6]], lite); poly([[40, 8], [43, 0], [36, 6]], lite); poly([[32, 4], [32, -2 + 2], [34, 0]], core)
	# glowing core
	ell(32, 38, 6, 6, Color(1.0, 0.7, 1.0, 0.5)); ell(32, 38, 4, 4, core)
	# floating shards
	for s in [[5, 14], [58, 12], [3, 38], [60, 40]]:
		poly([[s[0], s[1] - 4], [s[0] + 3, s[1]], [s[0], s[1] + 4], [s[0] - 3, s[1]]], lite)
	finish("sw")

func devourer() -> void:
	var v := Color(0.28, 0.08, 0.38)
	var dk := Color(0.12, 0.03, 0.18)
	for i in 8:                                                   # writhing tendrils
		var a := i * TAU / 8.0 + 0.3
		for j in 14:
			var t := j / 13.0
			var r := 22.0 + t * 12.0
			var wob := sin(t * 5.0 + i) * 4.0
			ell(32 + cos(a) * r + wob * -sin(a), 34 + sin(a) * r * 0.9 + wob * cos(a), 4.0 - t * 2.5, 4.0 - t * 2.5, v.darkened(0.2 + t * 0.2))
	ell(32, 34, 24, 23, dk)
	ell(32, 33, 22, 21, v)
	ell(26, 24, 10, 8, v.lightened(0.15))
	ell(32, 38, 15, 13, Color(0.04, 0.0, 0.06))                   # the maw
	for i in 12:                                                  # ring of teeth
		var a := i * TAU / 12.0
		poly([[32 + cos(a - 0.12) * 15, 38 + sin(a - 0.12) * 13], [32 + cos(a) * 9, 38 + sin(a) * 8], [32 + cos(a + 0.12) * 15, 38 + sin(a + 0.12) * 13]], Color(0.95, 0.92, 0.85))
	ell(32, 38, 4, 3, Color(0.7, 0.1, 0.5))
	for e in [[18, 20], [46, 20], [32, 14], [12, 32], [52, 32]]:   # red eyes
		ell(e[0], e[1], 3.5, 3.5, Color(0.95, 0.15, 0.2)); px(e[0], e[1] - 1, Color(1, 0.9, 0.6)); rect(e[0] - 1, e[1] - 1, 2, 3, Color(0.1, 0.0, 0.05))
	finish("final")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://enemies/boss/art"))
	for f in ["blobbert", "colossus", "wyrm", "titan", "mother", "warden", "devourer"]:
		start()
		call(f)
	var ids := ["s", "se", "ne", "n", "nw", "sw", "final"]
	var sheet := Image.create(SIZE * 7 + 6 * 4, SIZE, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.55, 0.3))
	for i in ids.size():
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://enemies/boss/art/%s.png" % ids[i]))
		sheet.blend_rect(im, Rect2i(0, 0, SIZE, SIZE), Vector2i(i * (SIZE + 4), 0))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png("user://boss_preview.png")
	quit()
