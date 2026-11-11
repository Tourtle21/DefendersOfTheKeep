extends SceneTree
## The small resource icons used wherever a cost or a stock is shown (cards, HUD, forge, hints): one 16x16 pixel icon per resource.
## Run:  Godot --path . --headless --script res://tools/make_resource_icons.gd   (writes ui/cards/res_icons/<id>.png)
const N := 16
var img: Image

func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < N and y < N:
		img.set_pixel(x, y, c)

func fill_poly(pts: Array, c: Color) -> void:
	var poly := PackedVector2Array(pts)
	for y in N:
		for x in N:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				px(x, y, c)

func fill_ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in N:
		for x in N:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(x, y, c)

func line(a: Vector2, b: Vector2, c: Color, w := 1) -> void:
	var steps := int(a.distance_to(b)) * 2 + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for ox in w:
			for oy in w:
				px(int(p.x) + ox, int(p.y) + oy, c)

## 1 px dark outline around everything drawn
func outline() -> void:
	var out := img.duplicate() as Image
	for y in N:
		for x in N:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < N and ny < N and img.get_pixel(nx, ny).a > 0.5:
					out.set_pixel(x, y, Color(0.06, 0.05, 0.08))
					break
	img = out

func start() -> void:
	img = Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

func save(id: String) -> void:
	outline()
	img.save_png(ProjectSettings.globalize_path("res://ui/cards/res_icons/%s.png" % id))

func _initialize() -> void:
	start()                                                                   # stone: a grey boulder with a light top
	fill_poly([Vector2(2, 12), Vector2(3, 6), Vector2(7, 3), Vector2(12, 4), Vector2(14, 8), Vector2(13, 13), Vector2(5, 14)], Color(0.55, 0.56, 0.62))
	fill_poly([Vector2(4, 7), Vector2(7, 4), Vector2(11, 5), Vector2(9, 8), Vector2(5, 9)], Color(0.78, 0.79, 0.85))
	fill_poly([Vector2(9, 11), Vector2(13, 9), Vector2(13, 13), Vector2(8, 13)], Color(0.42, 0.43, 0.5))
	save("stone")
	start()                                                                   # stick: a brown twig with a branch
	line(Vector2(3, 13), Vector2(13, 3), Color(0.55, 0.36, 0.18), 2)
	line(Vector2(4, 12), Vector2(12, 4), Color(0.72, 0.5, 0.26), 1)
	line(Vector2(8, 8), Vector2(5, 5), Color(0.55, 0.36, 0.18), 1)
	save("stick")
	start()                                                                   # gold: a coin
	fill_ellipse(8, 8, 6.5, 6.5, Color(0.9, 0.62, 0.1))
	fill_ellipse(8, 8, 4.6, 4.6, Color(1.0, 0.85, 0.3))
	line(Vector2(6, 5), Vector2(6, 11), Color(0.9, 0.62, 0.1), 1)
	line(Vector2(9, 5), Vector2(9, 11), Color(0.9, 0.62, 0.1), 1)
	line(Vector2(5, 5), Vector2(10, 5), Color(1, 0.95, 0.6), 1)
	save("gold")
	start()                                                                   # iron: an ingot
	fill_poly([Vector2(1, 12), Vector2(4, 5), Vector2(13, 5), Vector2(15, 12)], Color(0.55, 0.62, 0.72))
	fill_poly([Vector2(4, 5), Vector2(13, 5), Vector2(12, 8), Vector2(3, 8)], Color(0.82, 0.88, 0.96))
	fill_poly([Vector2(3, 8), Vector2(12, 8), Vector2(15, 12), Vector2(1, 12)], Color(0.45, 0.5, 0.6))
	save("iron")
	start()                                                                   # frost: a snowflake
	var ice := Color(0.7, 0.92, 1.0)
	for a in 3:
		var ang := a * PI / 3.0
		line(Vector2(8, 8) - Vector2(cos(ang), sin(ang)) * 6.5, Vector2(8, 8) + Vector2(cos(ang), sin(ang)) * 6.5, ice, 1)
	fill_ellipse(8, 8, 2.0, 2.0, Color(0.4, 0.75, 1.0))
	save("frost")
	start()                                                                   # ember: a flame
	fill_poly([Vector2(8, 1), Vector2(12, 6), Vector2(13, 11), Vector2(10, 15), Vector2(5, 15), Vector2(3, 11), Vector2(5, 7), Vector2(6, 9), Vector2(7, 5)], Color(0.95, 0.35, 0.1))
	fill_poly([Vector2(8, 7), Vector2(11, 11), Vector2(9, 14), Vector2(6, 14), Vector2(5, 11)], Color(1.0, 0.75, 0.2))
	fill_ellipse(8, 12, 1.6, 1.6, Color(1.0, 0.95, 0.6))
	save("ember")
	start()                                                                   # moss: a leaf
	fill_poly([Vector2(2, 14), Vector2(3, 7), Vector2(8, 2), Vector2(14, 2), Vector2(14, 8), Vector2(9, 13)], Color(0.35, 0.75, 0.3))
	fill_poly([Vector2(5, 11), Vector2(6, 7), Vector2(9, 4), Vector2(12, 4), Vector2(12, 7), Vector2(9, 10)], Color(0.55, 0.9, 0.4))
	line(Vector2(3, 13), Vector2(11, 5), Color(0.2, 0.5, 0.2), 1)
	save("moss")
	start()                                                                   # gem: a cut diamond
	fill_poly([Vector2(8, 14), Vector2(1, 6), Vector2(4, 2), Vector2(12, 2), Vector2(15, 6)], Color(0.72, 0.35, 0.95))
	fill_poly([Vector2(4, 2), Vector2(12, 2), Vector2(15, 6), Vector2(1, 6)], Color(0.9, 0.62, 1.0))
	fill_poly([Vector2(5, 6), Vector2(11, 6), Vector2(8, 14)], Color(0.55, 0.22, 0.8))
	line(Vector2(5, 3), Vector2(7, 3), Color(1, 1, 1), 1)
	save("gem")
	print("resource icons written")
	quit()
