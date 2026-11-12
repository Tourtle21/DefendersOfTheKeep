extends RefCounted
## ONE art module for per-tier weapon pictures. `image(id, tier)` draws the weapon's 32x32 icon for tier 1..6 from scratch, in code, with the
## pixel kit in weapon_paint.gd, tip up, grip at the bottom centre (that is the hand anchor), and the same dark outline as the tier 1 icons.
## Higher tiers keep every part the lower tiers had and add parts (a longer blade, a crossguard, studs, a gem, filigree ...), so a weapon looks
## better and more worked each tier, relative to itself, the way the buildings do (cards/structure_art.gd).
##
## Where a weapon's art lives:
##   base_art.gd   the base weapons (sword ... mindbender): one `draw_<id>(p, t)` each.
##   fused_art.gd  the fused weapons: one `draw_<id>(p, t)` each, drawn from scratch (they do NOT start from their parents' icons).
## To add a weapon: add `func draw_<id>(p: Paint, t: int) -> void:` to the right file. Nothing else: this module finds it by name.
## A weapon with no such function has no custom art yet and WeaponArt falls back to the old glow overlay on its icon.
## Custom canvas size: `func size_<id>() -> int` (default 32); WeaponArt/Weapon scale the picture by texture size, so any size lines up
## as long as the weapon's grip stays at the bottom centre.
##
## Pure drawing, no autoload is touched: this runs in a --script test and in tools/make_weapon_tier_art.gd (the contact sheet).
const Paint = preload("res://items/weapons/art/weapon_paint.gd")
const GROUPS := [
	preload("res://items/weapons/art/base_art.gd"),
	preload("res://items/weapons/art/fused_art.gd"),
]

static var _insts: Array = []

static func _group_of(id: String) -> Object:
	if _insts.is_empty():
		for g in GROUPS:
			_insts.append(g.new())
	for o in _insts:
		if o.has_method("draw_" + id):
			return o
	return null

static func has(id: String) -> bool:
	return _group_of(id) != null

static func canvas(id: String) -> int:
	var g := _group_of(id)
	if g != null and g.has_method("size_" + id):
		return int(g.call("size_" + id))
	return 32

## The weapon's icon at `tier` (1..6) as an RGBA8 Image, outlined, or null when the weapon has no custom art.
static func image(id: String, tier: int) -> Image:
	var g := _group_of(id)
	if g == null:
		return null
	var p := Paint.new(canvas(id))
	g.call("draw_" + id, p, clampi(tier, 1, 6))
	p.outline()
	return p.img
