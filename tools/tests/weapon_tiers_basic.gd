extends "res://tools/tests/wt_base.gd"
## Tiers 2-6 of the base weapons (docs/weapon_tiers): torch, spear, hammer, bow, daggers, scimitar, whip, shield, frostglaive, staff, emberflail.
## Run all: `--script res://tools/tests/weapon_tiers_basic.gd`, one: `-- only=torch`.
func click(w) -> void:
	w.use_item()

func lights() -> Array:
	var out := []
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("light_source.gd"):
			out.append(n)
	return out

func t_torch() -> void:
	var w
	var kd := {}
	for t in [1, 2]:
		w = await equip("torch", t, false)
		var c: Vector2 = P + (player.aim_point() - P).limit_length(110.0)
		var d = dummy(c)
		w.use_ability()
		await wait(0.9)
		var a := lost(d)
		await wait(1.6)
		kd[t] = [a, lost(d) - a]
	ok("torch Kindle: tier 2 flare keeps burning after the hit (%.1f more vs %.1f at tier 1)" % [kd[2][1], kd[1][1]], kd[2][1] - kd[1][1] >= 0.5)
	var fan := {}
	for t in [2, 3]:
		w = await equip("torch", t, false)
		var d = dummy(P + Vector2(40, 0))
		var per := []
		var seen := {}
		for i in 3:
			var h0 := lost(d)
			click(w)
			for k in 8:
				await wait(0.05)
				fx_kinds(seen)
			per.append(lost(d) - h0)
			await wait(0.5)
		fan[t] = [per, seen]
	ok("torch Fan of Flame: tier 3 cone on the third burn only (%s), cone fx %s; tier 2 none %s" % [fan[3][0], fan[3][1].has("cone"), fan[2][1].has("cone")], fan[3][1].has("cone") and !fan[2][1].has("cone") and fan[3][0][2] > fan[3][0][1] + 1.0)
	var bt := {}
	for t in [3, 4]:
		w = await equip("torch", t, false)
		var d1 = dummy(P + Vector2(20, 0))
		var d2 = dummy(P + Vector2(40, 4))
		w.use_dash()
		var r = await watch(0.6)
		var hz := 0.0
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("hazard.gd"):
				hz = n.radius
		var l0 := lost(d1) + lost(d2)
		await wait(2.2)
		bt[t] = [r.kinds, hz, lost(d1) + lost(d2) - l0]
	ok("torch Blaze Trail: tier 4 streak and flash (%s), patch radius %.0f, enemies keep burning (+%.1f vs +%.1f)" % [bt[4][0].has("streak") and bt[4][0].has("flash"), bt[4][1], bt[4][2], bt[3][2]], bt[4][0].has("streak") and bt[4][0].has("flash") and bt[4][1] == 26.0 and bt[3][1] == 20.0 and bt[4][2] > bt[3][2] + 0.5)
	var ct := {}
	for t in [4, 5, 6]:
		w = await equip("torch", t, false)
		var d = dummy(P + Vector2(80, 0))
		w.use_ultimate()
		var big := 0.0
		var r := {}
		var seen := {}
		var peak := 0
		var rings := 0
		for i in 60:
			await wait(0.05)
			fx_kinds(seen)
			peak = maxi(peak, fx_count())
			for l in lights():
				big = maxf(big, l.light_radius)
		ct[t] = {"lost": lost(d), "kinds": seen, "light": big, "peak": peak}
	ok("torch Corona: tier 5 hits a dummy at 80 px harder (%.1f vs %.1f)" % [ct[5].lost, ct[4].lost], ct[5].lost > ct[4].lost + 2.0)
	ok("torch Noon: tier 6 flash and pillar (%s), sunburst light %.0f >= 190, hits harder (%.1f vs %.1f)" % [ct[6].kinds.has("flash") and ct[6].kinds.has("pillar"), ct[6].light, ct[6].lost, ct[5].lost], int(ct[6].kinds.get("pillar", 0)) > int(ct[5].kinds.get("pillar", 0)) and ct[6].light >= 190.0 and ct[6].lost > ct[5].lost + 2.0)
	ok("torch budget: live fx peak %d at tier 6" % ct[6].peak, ct[6].peak <= 120)
	var rad := []
	for t in range(1, 7):
		w = await equip("torch", t, false)
		rad.append(w.light_radius)
	ok("torch light radius grows with tier %s" % [rad], rad == [110.0, 110.0, 120.0, 130.0, 140.0, 150.0])
	await draw_smoke("torch")

func run() -> void:
	if only == "" or only == "torch":
		await t_torch()
