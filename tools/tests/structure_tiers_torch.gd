extends "res://tools/tests/structure_test_base.gd"
## Torch tiers 2 to 6 (docs/card_tiers/torch.md). Run: Godot --headless --path . --script res://tools/tests/structure_tiers_torch.gd
func sections() -> Array:
	return ["torch"]
func bar():
	return world.get_node("Player").get_parent().get_node("Hud/Control2/ColorRect/Health")
func torch() -> void:
	print("-- torch")
	var c := Vector2(0, 300)
	# Flame guard (tier 2)
	var fg := {}
	for t in [1, 2]:
		var st = build("torch", t, c)
		var e = dummy(c + Vector2(20, 0))
		var mx := 0.0
		for i in 10:
			await wait(0.05)
			mx = maxf(mx, e.knock_vel.length())
		fg[t] = [dealt(e), mx]
		await clear()
	ok("tier 2 flares at an enemy 20 px away (hurts and shoves), tier 1 does not (%s)" % str(fg), fg[2][0] > 0.0 and fg[2][1] > 50.0 and fg[1][0] == 0.0)
	# Ember flick (tier 3)
	var em := {}
	for t in [2, 3]:
		var st = build("torch", t, c)
		var e = dummy(c + Vector2(60, 0))
		var seen_proj := 0
		for i in 60:
			await wait(0.05)
			seen_proj = maxi(seen_proj, count_nodes("projectile.gd"))
		await wait(0.4)
		em[t] = [seen_proj, dealt(e)]
		await clear()
	ok("tier 3 flicks embers at an enemy in its light, tier 2 does not (%s)" % str(em), em[3][0] >= 1 and em[3][1] > 0.0 and em[2][0] == 0 and em[2][1] == 0.0)
	# Hearth (tier 4)
	var hh := {}
	for t in [3, 4]:
		var st = build("torch", t, c)
		var p = player()
		p.global_position = c + Vector2(30, 0)
		bar().size.x = 100.0
		await wait(1.2)
		hh[t] = bar().size.x
		await clear()
		p.global_position = Vector2(0, 700)
	ok("tier 4 heals a player standing in its light, tier 3 does not (%s)" % str(hh), hh[4] > 101.0 and hh[3] < 101.0)
	bar().size.x = 228.0
	# Fire orbs (tier 5)
	var st5 = build("torch", 5, c)
	st5._timers["ember"] = -1.0e9                                    # (only the orbs may hit it here)
	st5._timers["flame"] = -1.0e9
	var p0: Vector2 = load("res://cards/structure_tiers.gd").orb_pos(st5, 0)
	await wait(0.5)
	var p1: Vector2 = load("res://cards/structure_tiers.gd").orb_pos(st5, 0)
	var e5 = dummy(c + Vector2(st5.light_radius * 0.45, 0))
	var seen5 := await fx_seen(3.2)
	ok("tier 5 orbs circle and burn what they touch (moved %.0f px, dealt %.1f, %s)" % [p0.distance_to(p1), dealt(e5), str(seen5)], p0.distance_to(p1) > 10.0 and dealt(e5) > 0.0)
	await clear()
	# Sunburst (tier 6)
	var st6 = build("torch", 6, c)
	st6._timers["ember"] = -1.0e9
	st6._timers["flame"] = -1.0e9
	var e6 = dummy(c + Vector2(70, 0))
	var before := 0.0
	var seen6 := await fx_seen(8.4)
	ok("tier 6 sunburst every 8 s: flash, hurts (%.1f), lights the enemy (%s) (%s)" % [dealt(e6), str(e6.has_meta("lit_until")), str(seen6)], seen6.get("flash", 0) >= 1 and dealt(e6) >= 36.0 and e6.has_meta("lit_until"))
	await clear()
	# Cumulative: tier 6 keeps flame guard, ember, hearth, orbs
	var st = build("torch", 6, c)
	var near = dummy(c + Vector2(20, 0))
	var p = player()
	p.global_position = c + Vector2(30, 40)
	bar().size.x = 100.0
	var mxp := 0
	var seenc := {}
	for i in 50:
		await wait(0.05)
		mxp = maxi(mxp, count_nodes("projectile.gd"))
	ok("tier 6 still has flame guard, ember and hearth (knock %s, projectiles %d, hp bar %.0f)" % [str(near.knock_vel.length() > 0.0 or dealt(near) > 0.0), mxp, bar().size.x], dealt(near) > 0.0 and mxp >= 1 and bar().size.x > 101.0)
	p.global_position = Vector2(0, 700)
	bar().size.x = 228.0
