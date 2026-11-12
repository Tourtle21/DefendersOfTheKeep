extends SceneTree
## Per-tier weapon art (items/weapons/art/weapon_tier_art.gd): every base weapon has its own drawing for tiers 1..6, tiers differ pairwise, each tier
## differs from the one below by a meaningful number of pixels, every tier fills a good part of the canvas, size is the same for all tiers, tier 1
## equals the weapon's icon file (so a weapon's art starts from the icon the player already knows). Fused weapons are checked when they have art.
## No game needed (pure drawing): runs in a second.
const TierArt = preload("res://items/weapons/art/weapon_tier_art.gd")
const BASE := ["sword", "pickaxe", "torch", "spear", "hammer", "bow", "daggers", "scimitar", "whip", "shield", "frostglaive", "staff", "emberflail", "bogstaff", "crystalwand", "dawnbringer", "voidreaver", "mindbender"]
const MIN_STEP := 14           # pixels that must change between tier N and N+1
var fails := 0

func ok(n: String, c: bool) -> void:
	if !c:
		print("FAIL " + n)
		fails += 1

func diff(a: Image, b: Image) -> int:
	var n := 0
	for y in mini(a.get_height(), b.get_height()):
		for x in mini(a.get_width(), b.get_width()):
			if !a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n

func opaque_count(a: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y).a > 0.5:
				n += 1
	return n

func _initialize() -> void:
	var ids: Array = BASE.duplicate()
	for id in Fusion.NAMES.keys():
		if !(id in ids) and TierArt.has(str(id)):
			ids.append(str(id))
	for id in ids:
		ok("%s has custom art" % id, TierArt.has(id))
		if !TierArt.has(id):
			continue
		var imgs: Array = []
		for t in range(1, 7):
			var im: Image = TierArt.image(id, t)
			ok("%s tier %d exists" % [id, t], im != null)
			imgs.append(im)
		if imgs.any(func(i): return i == null):
			continue
		var w: int = imgs[0].get_width()
		ok("%s same size every tier" % id, imgs.all(func(i): return i.get_width() == w and i.get_height() == w))
		for t in range(1, 6):
			var d := diff(imgs[t], imgs[t - 1])
			ok("%s tier %d vs %d differ by %d (>= %d)" % [id, t + 1, t, d, MIN_STEP], d >= MIN_STEP)
		for a in 6:
			for b in range(a + 1, 6):
				ok("%s tiers %d and %d differ" % [id, a + 1, b + 1], diff(imgs[a], imgs[b]) > 0)
		var n1 := opaque_count(imgs[0])
		var n6 := opaque_count(imgs[5])
		ok("%s tier 6 is richer than tier 1 (%d vs %d pixels)" % [id, n6, n1], n6 > n1 + 20)
		var icon := "res://items/weapons/icons/%s.png" % id
		if FileAccess.file_exists(icon):
			var base := Image.load_from_file(ProjectSettings.globalize_path(icon))
			base.convert(Image.FORMAT_RGBA8)
			ok("%s tier 1 is its icon file (%d px differ)" % [id, diff(imgs[0], base)], diff(imgs[0], base) == 0)
	print("weapon_art: %d weapons checked, %d failures" % [ids.size(), fails])
	quit(1 if fails > 0 else 0)
