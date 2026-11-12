extends "res://tools/tests/weapon_tiers_fusions_b.gd"
## Fused weapons, Ancient batch (docs/weapon_tiers): witchstaff, soulreaper (and later starfall, stormbow, worldbreaker if built here).
## Helpers come from fusions_a / fusions_b.   One weapon:  ... -- only=witchstaff

func hexed(e) -> bool:
	return is_instance_valid(e) and e.has_meta("hexed_until") and e.get_meta("hexed_until") > Time.get_ticks_msec() / 1000.0

func t_witchstaff() -> void:
	var w
	var game_mark: float = 1.0
	# Hex Mark: the third bolt in a row hexes (+20% from everything); the Hex circle marks every dummy in it
	w = await equip("witchstaff", 2, false)
	var d = dummy(P + Vector2(40, 0))
	for i in 3:
		click(w)
		await wait(0.55)
	game_mark = game.mark_mult(d)
	ok("witchstaff Hex Mark: 3 bolts hex the dummy (mark_mult %.2f >= 1.19), Rot %d" % [game_mark, rot_of(d)], hexed(d) and game_mark >= 1.19 and rot_of(d) >= 2)
	w = await equip("witchstaff", 2, false)
	var ds := []
	for off in [Vector2(100, 0), Vector2(110, 20), Vector2(95, -25)]:
		ds.append(dummy(P + off))
	w.use_ability()
	var r = await watch(0.6)
	var n := 0
	for e in ds:
		if hexed(e):
			n += 1
	ok("witchstaff Hex Mark: the Hex circle marks %d of 3 dummies, sigil %s, star %s" % [n, r.kinds.has("sigil"), r.kinds.has("star")], n == 3 and r.kinds.has("sigil") and r.kinds.has("star"))
	# Pox: a hexed enemy dies, the curse jumps to the neighbours and the corpse bursts into a cloud (tier 3)
	var pox := {}
	for t in [2, 3]:
		w = await equip("witchstaff", t, false)
		var weak = dummy(P + Vector2(60, 0), 5.0)
		var nb = dummy(P + Vector2(88, 0))
		var nb2 = dummy(P + Vector2(60, 30))
		w.get_script().get_method_list()
		var mod = load("res://items/weapons/tiers/witchstaff.gd")
		mod.hex(w, weak)
		await wait(0.3)
		weak.spell_damage(100.0)
		await wait(0.5)
		pox[t] = [hexed(nb) or hexed(nb2), snappedf(lost(nb) + lost(nb2), 0.1)]
	ok("witchstaff Pox: the curse jumps %s at both tiers; tier 3 also bursts a pox cloud (damage %s vs tier 2 %s)" % [pox[3][0], pox[3][1], pox[2][1]], pox[3][0] and pox[2][0] and pox[3][1] > pox[2][1] + 3.0)
	# Cauldron: spits globs; the 4th bolt is a witch-bolt
	var cau := {}
	for t in [3, 4]:
		w = await equip("witchstaff", t, false)
		var dd = dummy(P + Vector2(120, 30))
		w.use_ability()
		var ids := {}
		for i in 80:
			await wait(0.05)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "glob" and nd.size == 1.4:
					ids[nd.get_instance_id()] = true
		cau[t] = ids.size()
	w = await equip("witchstaff", 4, false)
	var far = dummy(P + Vector2(190, 0))
	var biggest := 0.0
	for i in 4:
		click(w)
		for x in await glob_sizes(0.1):
			biggest = maxf(biggest, x)
		await wait(0.3)
	ok("witchstaff Cauldron: tier 4 cauldron spits %d globs (>= 3), tier 3 %d; the 4th bolt is size %.1f (>= 1.5)" % [cau[4], cau[3], biggest], cau[4] >= 3 and cau[3] == 0 and biggest >= 1.5)
	# Witch Hop: slow patches on the trail and a burst on arrival
	var hop := {}
	for t in [3, 4]:
		w = await equip("witchstaff", t, false)
		var before := hazards("slow")
		var near = dummy(P + Vector2(20, 0))
		w.use_dash()
		await wait(0.4)
		hop[t] = [hazards("slow") - before, hexed(near)]
	ok("witchstaff Witch Hop: tier 4 trail %s (patches, start hexed) vs tier 3 %s" % [hop[4], hop[3]], hop[4][0] >= 4 and hop[4][1] and !hop[3][1])
	# Coven: three witch spirits for ~8 s and hexing homing bolts
	var cov := {}
	for t in [4, 5]:
		w = await equip("witchstaff", t, false)
		var dd = dummy(P + Vector2(80, 0))
		w.use_ultimate()
		await wait(1.6)
		var nw: int = w._aura.data.get("w", 0)
		var ids := {}
		for i in 60:
			await wait(0.05)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "orb":
					ids[nd.get_instance_id()] = true
		cov[t] = [nw, ids.size(), hexed(dd)]
	ok("witchstaff Coven: tier 5 witches %s; tier 4 %s" % [cov[5], cov[4]], cov[5][0] == 3 and cov[5][1] >= 2 and cov[5][2] and cov[4][0] == 0 and cov[4][1] == 0)
	# Witch Queen: everything near is hexed, a death leaves toads, the Wrath at ~17.5 s
	w = await equip("witchstaff", 6, false)
	var q1 = dummy(P + Vector2(70, 0))
	var q2 = dummy(P + Vector2(40, 40))
	w.use_ultimate()
	await wait(7.0)
	var auto := hexed(q1)
	q2.spell_damage(1000000.0)
	var ids := {}
	for i in 14:
		await wait(0.05)
		for nd in world.get_children():
			if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "glob" and nd.size < 1.1:
				ids[nd.get_instance_id()] = true
	await wait(9.0)
	var h1 := lost(q1)
	var flash := false
	for i in 40:
		await wait(0.05)
		if has_fx("flash", 85.0):
			flash = true
	ok("witchstaff Witch Queen: auto hex %s, toads %d (>= 5), wrath flash %s, wrath damage %.1f (>= 12)" % [auto, ids.size(), flash, lost(q1) - h1], auto and ids.size() >= 5 and flash and lost(q1) - h1 >= 12.0)
	# Finisher: the 6th bolt is a curse nova (ripple r 80)
	w = await equip("witchstaff", 6, false)
	var fa = dummy(P + Vector2(40, 0))
	var fb = dummy(P + Vector2(40, 45))
	var nova := false
	for i in 6:
		click(w)
		for k in 14:
			await wait(0.05)
			if i == 5 and has_fx("ripple", 80.0):
				nova = true
		await wait(0.3)
	ok("witchstaff Finisher: the 6th bolt novas (%s) and hexes the neighbour %s" % [nova, hexed(fb)], nova and hexed(fb))
	await draw_smoke("witchstaff")

func t_soulreaper() -> void:
	var w
	# Entry: kills in melee leave souls; the cap is 4 at tier 3 (6 at tier 4)
	w = await equip("soulreaper", 3, false)
	var d = dummy(P + Vector2(30, 0), 1.0)
	await wait(0.3)
	click(w)
	await wait(0.5)
	var one: int = w._st.souls
	var seen_aura: int = w._aura.data.get("s", -1)
	for i in 6:
		var x = dummy(P + Vector2(30, 0), 1.0)
		await wait(0.3)
		x.spell_damage(10.0)
		await wait(0.25)
	ok("soulreaper Soul Harvest: a kill gives %d soul (aura %d); after 7 kills %d (cap 4)" % [one, seen_aura, w._st.souls], one == 1 and seen_aura == 1 and w._st.souls == 4)
	# Soul Bolt: with 3+ souls a swing spends one and throws a homing wisp
	var sb := {}
	for t in [3, 4]:
		w = await equip("soulreaper", t, false)
		var tg = dummy(P + Vector2(80, 0))
		w._st.souls = 3
		click(w)
		var ids := {}
		for i in 8:
			await wait(0.05)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "orb":
					ids[nd.get_instance_id()] = true
		sb[t] = [ids.size(), w._st.souls]
	ok("soulreaper Soul Bolt: tier 4 swing spends a soul %s for a wisp; tier 3 %s" % [sb[4], sb[3]], sb[4][0] >= 1 and sb[4][1] == 2 and sb[3][0] == 0 and sb[3][1] == 3)
	# Reaping Hook: the grapple with 3 souls chains through three more enemies
	var hk := {}
	for t in [3, 4]:
		w = await equip("soulreaper", t, false)
		var a = dummy(P + Vector2(70, 0))
		var b = dummy(P + Vector2(70, 40))
		var c = dummy(P + Vector2(70, 80))
		var e2 = dummy(P + Vector2(70, 120))
		w._st.souls = 3
		w.use_ability()
		await wait(1.0)
		hk[t] = [exposed_for(b) > 1.0 and exposed_for(c) > 1.0 and exposed_for(e2) > 1.0, w._st.souls]
	ok("soulreaper Reaping Hook: tier 4 chains through B, C and D and spends 3 souls %s; tier 3 %s" % [hk[4], hk[3]], hk[4][0] and hk[4][1] == 0 and !hk[3][0] and hk[3][1] == 3)
	# Spectral Chains: the sweep roots what it passes
	var sc := {}
	for t in [3, 4]:
		w = await equip("soulreaper", t, false)
		var dd = dummy(P + Vector2(22, 20))
		w.use_dash()
		await wait(0.6)
		sc[t] = [snappedf(dd.slow_mult, 0.1), snappedf(lost(dd), 0.1)]
	ok("soulreaper Spectral Chains: tier 4 roots a dummy beside the path %s; tier 3 %s" % [sc[4], sc[3]], sc[4][0] <= 0.5 and sc[4][1] > sc[3][1] + 1.0)
	# Soul Tide: wisps and two ghost reapers
	var st := {}
	for t in [4, 5]:
		w = await equip("soulreaper", t, false)
		var dd = dummy(P + Vector2(60, 0))
		w._st.souls = 5
		w.use_ultimate()
		await wait(3.65)
		var rp: int = w._aura.data.get("rp", 0)
		var ids := {}
		for i in 12:
			await wait(0.05)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "orb":
					ids[nd.get_instance_id()] = true
		st[t] = [ids.size(), rp]
	ok("soulreaper Soul Tide: tier 5 wisps and reapers %s; tier 4 %s" % [st[5], st[4]], st[5][0] >= 5 and st[5][1] == 2 and st[4][0] == 0 and st[4][1] == 0)
	# Grim Reaper: scythe for ~12 s, execution (not a boss stand-in), Reap Harvest at ~16 s
	w = await equip("soulreaper", 6, false)
	var big = dummy(P + Vector2(120, 0))
	var weak = dummy(P + Vector2(60, 40), 100.0)
	weak.health = 15.0
	var boss = dummy(P + Vector2(-60, 40), 1000000.0)
	boss.add_to_group("boss")
	boss.health = 200000.0
	w._st.souls = 6
	w.use_ultimate()
	await wait(4.6)
	var sy: float = w._aura.data.get("sy", 0.0)
	var slash := false
	for i in 40:
		await wait(0.05)
		if has_fx("slash", 90.0):
			slash = true
	var dead: bool = !is_instance_valid(weak) or weak.health <= 0.0
	await wait(8.6)
	var h1 := lost(big)
	var flash := false
	for i in 50:
		await wait(0.05)
		if has_fx("flash", 85.0):
			flash = true
	ok("soulreaper Grim Reaper: scythe r %.0f, slash r 90 %s, the weak dummy executed %s, the boss stand-in alive %s" % [sy, slash, dead, is_instance_valid(boss)], sy == 90.0 and slash and dead and is_instance_valid(boss))
	ok("soulreaper Reap Harvest: flash r 85 %s, a dummy at 120 px takes %.1f (>= 3.6) and the souls are spent (%d)" % [flash, lost(big) - h1, w._st.souls], flash and lost(big) - h1 >= 3.6 and w._st.souls <= 1)
	await draw_smoke("soulreaper")

func run() -> void:
	if want("witchstaff"):
		await t_witchstaff()
	if want("soulreaper"):
		await t_soulreaper()
