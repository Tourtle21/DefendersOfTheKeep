extends "res://tools/tests/wt_base.gd"
## Damage budget probe: the tier 6 ultimate of each legendary, used on a cluster of three stationary dummies, measured over 20 s.
## Prints the damage per dummy so the legendaries can be compared (the Prismatic Staff must not outdo the three earned ones).
func total(ds: Array) -> float:
	var t := 0.0
	for d in ds:
		t += lost(d)
	return t
func run() -> void:
	for id in ["dawnbringer", "voidreaver", "mindbender", "prismstaff"]:
		var w = await equip(id, 6, false)
		var a = dummy(P + Vector2(90, 0))
		var b = dummy(P + Vector2(100, 22))
		var c = dummy(P + Vector2(100, -22))
		w.use_ultimate()
		var marks := []
		for i in 10:
			await wait(2.0)
			marks.append(int(total([a, b, c])))
		print("   %s damage every 2 s: %s" % [id, str(marks)])
		var t := total([a, b, c])
		print("BUDGET %s tier 6 ultimate on 3 dummies over 20 s: %.0f total (%.0f each)" % [id, t, t / 3.0])
