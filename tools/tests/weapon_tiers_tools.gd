extends "res://tools/tests/wt_base.gd"
## Sword and Pickaxe tiers (docs/weapon_tiers/sword.md, pickaxe.md): each tier's own upgrade, kept by the next, absent from the one before.
func click() -> void:
	player.item.use_item()
	player.is_using_item = true

func t_sword() -> void:
	var w
	# Gale: the third pulse shoves and chills at tier 2, not at tier 1
	var res := {}
	for t in [1, 2]:
		w = await equip("sword", t, false)
		var d = dummy(P + Vector2(30, 0))
		w.use_ability()
		var low := 1.0
		var seen := {}
		for i in 22:
			await wait(0.05)
			fx_kinds(seen)
			low = minf(low, d.slow_mult)
		res[t] = {"slow": low, "kinds": seen}
	ok("sword Gale: tier 2 chills the dummy (slow %.2f vs %.2f) and has slash fx %s" % [res[2].slow, res[1].slow, res[2].kinds.has("slash")], res[2].slow <= 0.51 and res[1].slow > 0.9 and res[2].kinds.has("slash") and !res[1].kinds.has("slash"))
	# Crescent: every third swing, tier 3 only
	var dmg := {}
	var kinds := {}
	for t in [2, 3]:
		w = await equip("sword", t)
		var d = dummy(P + Vector2(30, 0))
		var per := []
		var seen := {}
		for i in 3:
			var h0 := lost(d)
			click()
			for k in 10:
				await wait(0.05)
				fx_kinds(seen)
			per.append(lost(d) - h0)
			await wait(0.4)
		dmg[t] = per
		kinds[t] = seen
	ok("sword Crescent: tier 3 third swing lands the crescent (%s vs tier 2 %s); slash fx only at tier 3 (%s)" % [dmg[3], dmg[2], kinds[2].has("slash")], dmg[3][2] >= dmg[2][2] + 0.5 and kinds[3].has("slash") and !kinds[2].has("slash"))
	# Riposte Step: the return cut reaches a dummy behind the arrival point
	var back := {}
	for t in [3, 4]:
		w = await equip("sword", t)
		var d = dummy(P + Vector2(50 + 30, 0))        # arrival is ~50 px away; the dummy sits 25-30 px past it
		var o: float = d.global_position.x
		await aim_at(P + Vector2(120, 0))
		w.use_dash()
		var r = await watch(0.8)
		back[t] = [lost(d), r.kinds]
	ok("sword Riposte Step: tier 4 dash has a streak and damages more than tier 3 (%.1f vs %.1f)" % [back[4][0], back[3][0]], back[4][1].has("streak") and !back[3][1].has("streak"))
	# Bladestorm: blades and an orbit at tier 5, not at tier 4
	var bs := {}
	for t in [4, 5]:
		w = await equip("sword", t)
		var d = dummy(P + Vector2(40, 0))
		w.use_ultimate()
		bs[t] = await watch(3.0)
	ok("sword Bladestorm: tier 5 throws blades (%d) and an orbit; tier 4 none (%d)" % [bs[5].proj, bs[4].proj], bs[5].proj >= 2 and bs[5].kinds.has("orbit") and bs[4].proj == 0)
	# Last Cut
	var lc := {}
	for t in [5, 6]:
		w = await equip("sword", t, false)
		var d = dummy(P + Vector2(50, 0))
		w.use_ultimate()
		var r = await watch(3.2)
		lc[t] = [lost(d), r.kinds, r.peak]
	ok("sword Last Cut: tier 6 has cut and shock (%s) and hits harder than tier 5 (%.1f vs %.1f)" % [lc[6][1].has("cut") and lc[6][1].has("shock"), lc[6][0], lc[5][0]], lc[6][1].has("cut") and lc[6][1].has("shock") and !lc[5][1].has("cut") and lc[6][0] > lc[5][0] + 4.0)
	ok("sword budget: live fx peak at tier 6 is %d (<= 120)" % lc[6][2], lc[6][2] <= 120)
	# Gale kept at tier 6
	w = await equip("sword", 6)
	var d6 = dummy(P + Vector2(30, 0))
	w.use_ability()
	var r6 = await watch(1.1)
	ok("sword tier 6 still has Gale (slash fx, slowed or shoved)", r6.kinds.has("slash"))
	await draw_smoke("sword")

func t_pickaxe() -> void:
	var w
	# Shatter: the strike throws debris at a dummy outside the core
	var res := {}
	for t in [1, 2]:
		w = await equip("pickaxe", t, false)
		await aim_at(P + Vector2(80, 0))
		var r: float = 24.0 * w.area() * (1.0 + 0.25 * maxi(0, t - 2))
		var c: Vector2 = P + (player.aim_point() - P).limit_length(80.0)
		var d = dummy(c + Vector2(r * 1.3, 0))
		w.use_ability()
		var rr = await watch(1.2)
		res[t] = [lost(d), rr.kinds]
	ok("pickaxe Shatter: tier 2 debris hurts a dummy outside the core (%.1f vs %.1f), crack and shards seen %s" % [res[2][0], res[1][0], res[2][1].keys()], res[2][0] - res[1][0] >= 0.9 and res[2][1].has("crack") and res[2][1].has("shards"))
	# Heavy Mine: the third swing sends a shockwave
	var sw := {}
	for t in [2, 3]:
		w = await equip("pickaxe", t, false)
		var d = dummy(P + Vector2(24, 0))
		var kinds := {}
		var shock_at := []
		for i in 3:
			var seen := {}
			click()
			for k in 8:
				await wait(0.05)
				fx_kinds(seen)
			shock_at.append(seen.has("shock"))
			await wait(0.5)
		sw[t] = shock_at
	ok("pickaxe Heavy Mine: tier 3 shock on swing 3 only %s; tier 2 never %s" % [sw[3], sw[2]], sw[3] == [false, false, true] and sw[2] == [false, false, false])
	# Rubble Trail
	var tr := {}
	for t in [3, 4]:
		w = await equip("pickaxe", t, false)
		var d = dummy(P + Vector2(40, 0))
		w.use_dash()
		await wait(0.2)
		tr[t] = count_script("hazard.gd")
	ok("pickaxe Rubble Trail: tier 4 dash leaves %d slow patches, tier 3 %d" % [tr[4], tr[3]], tr[4] == 3 and tr[3] == 0)
	# Aftershocks and Rockfall
	var au := {}
	for t in [4, 5, 6]:
		w = await equip("pickaxe", t, false)
		var er: float = 150.0 * w.area()
		var d = dummy(P + Vector2(er * 0.4, 0))
		var steps := []
		var last := 0.0
		var falls := 0
		w.use_ultimate()
		for i in 60:
			await wait(0.05)
			var seen := {}
			fx_kinds(seen)
			var n := 0
			for f in world.get_children():
				if f.get_script() != null and str(f.get_script().resource_path).ends_with("fx.gd") and f.kind == "fall":
					n += 1
			falls = maxi(falls, n)
			var l := lost(d)
			if l > last + 0.05:
				steps.append(snappedf(float(i) * 0.05, 0.05))
				last = l
		au[t] = {"steps": steps, "falls": falls, "lost": last}
	ok("pickaxe Aftershocks: tier 5 loses health in more steps (%s) than tier 4 (%s)" % [au[5].steps, au[4].steps], au[5].steps.size() > au[4].steps.size() and au[5].lost > au[4].lost)
	ok("pickaxe Rockfall: tier 6 drops %d boulders (tier 5: %d) and hits harder (%.1f vs %.1f)" % [au[6].falls, au[5].falls, au[6].lost, au[5].lost], au[6].falls >= 4 and au[5].falls == 0 and au[6].lost > au[5].lost + 2.0)
	await draw_smoke("pickaxe")

func run() -> void:
	if only == "" or only == "sword":
		await t_sword()
	if only == "" or only == "pickaxe":
		await t_pickaxe()
