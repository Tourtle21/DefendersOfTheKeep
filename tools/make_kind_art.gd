extends "res://tools/make_enemy_art.gd"
## Draws the sheets for the six level 4-6 enemy kinds (enemies/kinds/*.gd); uses the helpers of make_enemy_art.gd.
##   Godot --headless --path . --script res://tools/make_kind_art.gd
## Bipeds are 3x4 frames of 19x19, blobs 2x2 of 12x14 (the same layouts as their base enemies, so the scenes just swap the texture).

func cinder_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var lava := Color(1.0, 0.6, 0.15)
	r(6, 9 + bob, 7, 5, Color(0.16, 0.13, 0.13))                  # a barrel of embers strapped to the chest
	r(6, 10 + bob, 7, 1, lava); r(6, 12 + bob, 7, 1, lava)         # glowing hoops
	p(9, 11 + bob, Color(1.0, 0.9, 0.4))
	r(9, 7 + bob, 1, 2, Color(0.7, 0.55, 0.35))                    # fuse
	var sp: Color = [Color(1, 0.9, 0.3), Color(1, 0.5, 0.1), Color(1, 0.25, 0.1)][f % 3]
	p(9, 6 + bob - (f % 2), sp); p(10 - (f % 2) * 2, 5 + bob, sp)   # the spark
	p(hx + 2, top + 1, lava); p(hx + 5, top + 4, lava)             # ember cracks in the skin

func lobber_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var sac := Color(0.55, 0.85, 0.25)
	var bub := Color(0.85, 1.0, 0.45)
	r(hx + 1, top - 3, 5, 3, sac); r(hx + 2, top - 4, 3, 1, sac)   # a swollen sac on its head
	var b: int = [0, 1, 2, 1][f % 4]
	p(hx + 2, top - 3 - b + 1, bub); p(hx + 4, top - 2, bub.lightened(0.3))
	r(hx + 1, top + 3, 5, 2, Color(0.1, 0.14, 0.05))              # mouth full of sludge
	p(hx + 3, top + 5 + b, bub)
	r(3, 10 + bob, 2, 3, Color(0.3, 0.22, 0.12)); r(2, 9 + bob, 4, 1, Color(0.4, 0.3, 0.16))   # a mud mortar on its hip
	p(3, 8 + bob - b, bub)

func prism_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var ice := Color(0.85, 0.95, 1.0)
	var pink := Color(1.0, 0.6, 0.95)
	var cy := Color(0.5, 1.0, 1.0)
	r(hx, top - 2, 1, 2, pink); r(hx + 2, top - 3, 1, 3, cy); r(hx + 4, top - 2, 1, 2, ice)   # a crown of shards
	var gl := f % 3
	p(hx + 2, top - 3 - (f % 2), Color.WHITE)
	p(4 + gl * 4, 7 + (f % 2) * 6, Color.WHITE)                    # glints
	r(8, 9 + bob, 1, 4, pink); r(10, 9 + bob, 1, 4, cy)            # prism seams down the body

func charger(f: int) -> void:
	var rock := Color(0.28, 0.2, 0.2)
	var lava := Color(1.0, 0.55, 0.12)
	var hot := Color(1.0, 0.9, 0.4)
	var w: int = [0, 1, 0, -1][f]
	r(2, 4, 9, 7, rock); r(2, 4, 9, 1, rock.lightened(0.15))      # a low, bull-shaped body
	r(1, 3, 3, 4, rock.lightened(0.08))                            # head, lowered and pointing left
	p(0, 2, Color(0.85, 0.8, 0.7)); p(0, 1, Color(0.85, 0.8, 0.7)); p(4, 2, Color(0.85, 0.8, 0.7)); p(4, 1, Color(0.85, 0.8, 0.7))   # horns
	p(1, 4, hot); p(3, 4, hot)                                     # eyes
	r(4, 6, 1, 3, lava); r(6, 5, 1, 4, lava); r(8, 6, 1, 3, lava); r(5, 9, 3, 1, lava)   # cracks of lava
	r(2, 11, 2, 2 + (1 if f % 2 == 0 else 0), rock.darkened(0.2)); r(8, 11, 2, 2 + (1 if f % 2 == 1 else 0), rock.darkened(0.2))
	r(10 + w, 5, 2, 2, lava.darkened(0.2))                         # a smouldering tail

func burrower(f: int) -> void:
	var skin := Color(0.45, 0.28, 0.6)
	var belly := Color(0.7, 0.55, 0.85)
	var venom := Color(0.55, 1.0, 0.3)
	var claw := Color(0.9, 0.88, 0.8)
	var dig: int = [0, 1, 0, 1][f]
	r(3, 4, 6, 8, skin); r(4, 3, 4, 1, skin)                       # a long mole-worm
	r(5, 5, 2, 6, belly)
	for i in 3:
		r(3, 6 + i * 2, 6, 1, skin.darkened(0.2))                  # body rings
	r(4, 1, 4, 3, skin.lightened(0.1))                             # head
	p(5, 0, claw); p(6, 0, claw)                                   # drill snout
	p(4, 2, venom); p(7, 2, venom)
	r(1, 4 + dig, 2, 3, claw); r(9, 4 + (1 - dig), 2, 3, claw)      # digging claws
	p(1, 7 + dig, claw.darkened(0.2)); p(10, 7 + (1 - dig), claw.darkened(0.2))
	p(5, 12, venom); p(6, 13, venom); p(3, 10, venom)              # venom drips

func shard(f: int) -> void:
	var lite := Color(0.9, 0.8, 1.0)
	var mid := Color(0.66, 0.46, 0.95)
	var dark := Color(0.42, 0.26, 0.7)
	var sq: int = [0, 1, 0, -1][f]
	var widths := [2, 4, 6, 8, 10, 10, 10, 9, 8, 6]
	for i in widths.size():
		var wd: int = widths[i] + (sq if i > 3 and i < 8 else 0)
		var x0 := 6 - wd / 2
		r(x0, 2 + i, wd / 2, 1, lite if i < 5 else mid)
		r(x0 + wd / 2, 2 + i, wd - wd / 2, 1, mid if i < 5 else dark)
	p(6, 5, Color.WHITE); p(5, 7, dark); p(6, 8, dark); p(5, 9, dark); p(6, 10, dark)   # the crack it will burst along
	r(1, 6, 2, 2, mid); p(0, 5, lite); r(9, 7, 2, 2, dark); p(11, 6, mid)               # shards sticking out
	p(3, 5, Color.WHITE); p(8, 6, lite)

func _initialize() -> void:
	var gobs := {
		"cinder_bomber": {"skin": Color(0.32, 0.26, 0.24), "dark": Color(0.2, 0.15, 0.14), "body_w": 5, "head_w": 7, "leg_h": 4, "ears": true, "eye": Color(1, 0.7, 0.2), "extra": "cinder_extra", "belly": Color(0.4, 0.3, 0.26)},
		"mire_lobber": {"skin": Color(0.4, 0.45, 0.2), "dark": Color(0.25, 0.28, 0.12), "body_w": 8, "head_w": 7, "lean": -2, "leg_h": 3, "eye": Color(0.95, 1.0, 0.3), "extra": "lobber_extra", "belly": Color(0.55, 0.6, 0.28)},
		"prism_blinker": {"skin": Color(0.6, 0.55, 0.95), "dark": Color(0.4, 0.38, 0.75), "body_w": 3, "head_w": 5, "lean": 1, "leg_h": 5, "eye": Color(1, 1, 1), "extra": "prism_extra", "belly": Color(0.85, 0.8, 1.0)},
	}
	for name in gobs:
		begin(19, 19, 3, 4)
		for f in 12:
			at(f, 3)
			biped(gobs[name], f)
		save("res://enemies/kinds/%s.png" % name)
	for name in {"magma_charger": "charger", "venom_burrower": "burrower", "shard_splitter": "shard"}:
		begin(12, 14, 2, 2)
		for f in 4:
			at(f, 2)
			call({"magma_charger": "charger", "venom_burrower": "burrower", "shard_splitter": "shard"}[name], f)
		save("res://enemies/kinds/%s.png" % name)
	var names := ["cinder_bomber", "mire_lobber", "prism_blinker", "magma_charger", "venom_burrower", "shard_splitter"]
	var ims := []
	var tw := 0
	for n in names:
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://enemies/kinds/%s.png" % n))
		ims.append(im)
		tw += im.get_width() + 4
	var sheet := Image.create(tw, 76, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.55, 0.3))
	var x := 0
	for im in ims:
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, 0))
		x += im.get_width() + 4
	sheet.resize(tw * 4, 76 * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png("user://kind_preview.png")
	quit()
