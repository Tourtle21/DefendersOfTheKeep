extends SceneTree
## Contact sheet of the per-tier weapon art (items/weapons/art/weapon_tier_art.gd): one row per weapon, tiers 1..6 side by side, scaled up
## with nearest filtering on a grass-green background, plus the old tier 1 PNG at the left of each row for comparison.
## Run:  Godot --path . --headless --script res://tools/make_weapon_tier_art.gd -- ids=sword,bow out=/path/sheet.png scale=6 [all=1]
## `ids` defaults to every weapon with custom art. Prints how many pixels tier 1 differs from the icon PNG and tier N from tier N-1.
const TierArt = preload("res://items/weapons/art/weapon_tier_art.gd")

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var ids: Array = []
	if args.has("ids"):
		ids = Array(String(args.ids).split(","))
	else:
		ids = ["sword", "pickaxe", "torch", "spear", "hammer", "bow", "daggers", "scimitar", "whip", "shield", "frostglaive", "staff", "emberflail", "bogstaff", "crystalwand", "dawnbringer", "voidreaver", "mindbender"]
	var k := int(args.get("scale", "6"))
	var cell := 32 * k + 8
	var sheet := Image.create(cell * 7 + 8, cell * ids.size() + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5f8a4a"))
	for r in ids.size():
		var id: String = ids[r]
		var prev: Image = null
		var line := id + ":"
		var base := _base_icon(id)
		if base != null:
			_blit(sheet, base, 4, 4 + r * cell, k)
		for t in range(1, 7):
			var im: Image = TierArt.image(id, t)
			if im == null:
				line += " none"
				break
			_blit(sheet, im, 4 + t * cell, 4 + r * cell, k)
			if t == 1 and base != null:
				line += " t1vsPNG=%d" % _diff(im, base)
			if prev != null:
				line += " d%d=%d" % [t, _diff(im, prev)]
			prev = im
		print(line)
	var out := String(args.get("out", "user://weapon_tiers.png"))
	sheet.save_png(out)
	print("saved ", out)
	quit()

func _base_icon(id: String) -> Image:
	var p := "res://items/weapons/icons/%s.png" % id
	if FileAccess.file_exists(p):
		var im := Image.load_from_file(ProjectSettings.globalize_path(p))
		im.convert(Image.FORMAT_RGBA8)
		return im
	var sheets := {"sword": ["res://items/tools/sword/excalibur_.png", 32], "pickaxe": ["res://items/tools/pickaxe/pickaxe.png", 32]}
	if sheets.has(id):
		var im := Image.load_from_file(ProjectSettings.globalize_path(sheets[id][0]))
		im.convert(Image.FORMAT_RGBA8)
		return im.get_region(Rect2i(0, 0, 32, 32))
	return null

func _blit(dst: Image, src: Image, ox: int, oy: int, k: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			for dy in k:
				for dx in k:
					var X := ox + x * k + dx
					var Y := oy + y * k + dy
					if X < dst.get_width() and Y < dst.get_height():
						dst.set_pixel(X, Y, dst.get_pixel(X, Y).blend(c))

func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in mini(a.get_height(), b.get_height()):
		for x in mini(a.get_width(), b.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if !(ca.is_equal_approx(cb) or (ca.a < 0.01 and cb.a < 0.01)):
				n += 1
	return n
