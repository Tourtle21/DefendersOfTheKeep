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
	ok("torch Kindle: tier 2 flare keeps burning after the hit (%.1f more vs %.1f at tier 1)" % [kd[2][1], kd[1][1]], kd[2][1] >= 0.5 and kd[1][1] < 0.1)
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

func is_exposed(e) -> bool:
	return is_instance_valid(e) and e.has_meta("exposed_until") and e.get_meta("exposed_until") > Time.get_ticks_msec() / 1000.0

func t_spear() -> void:
	var w
	var jav := {}
	for t in [1, 2]:
		w = await equip("spear", t, false)
		var ds := [dummy(P + Vector2(40, 0)), dummy(P + Vector2(65, 0)), dummy(P + Vector2(90, 0)), dummy(P + Vector2(115, 0))]
		w.use_ability()
		await wait(0.6)
		var hit := 0
		var exp := 0
		for d in ds:
			if lost(d) > 0.0:
				hit += 1
			if is_exposed(d):
				exp += 1
		jav[t] = [hit, exp]
	ok("spear Barbed: tier 2 javelin hits %d and exposes %d of 4 (pierce 3); tier 1 has no javelin (%d)" % [jav[2][0], jav[2][1], jav[1][0]], jav[2][0] == 4 and jav[2][1] == 4 and jav[1][0] == 0)
	var sk := {}
	for t in [2, 3]:
		w = await equip("spear", t, false)
		var d = dummy(P + Vector2(56, 0))
		var per := []
		var seen := {}
		for i in 3:
			var h0 := lost(d)
			w.use_item()
			for k in 6:
				await wait(0.05)
				fx_kinds(seen)
			per.append(lost(d) - h0)
			await wait(0.4)
		sk[t] = [per, seen]
	ok("spear Skewer: tier 3 only the 3rd thrust reaches 56 px (%s), streak fx %s; tier 2 never (%s)" % [sk[3][0], sk[3][1].has("streak"), sk[2][0]], sk[3][0][0] == 0.0 and sk[3][0][1] == 0.0 and sk[3][0][2] > 0.0 and sk[3][1].has("streak") and sk[2][0] == [0.0, 0.0, 0.0])
	# Primed: a connecting lunge, then a thrust at 15 px does the full hit; 2 s later it is back to half
	w = await equip("spear", 4, false)
	var l1 = dummy(P + Vector2(30, 0))
	w.use_dash()
	await wait(0.6)
	var near1 = dummy(player.global_position + Vector2(15, 0))
	await aim_at(player.global_position + Vector2(100, 0))
	var h0 := lost(near1)
	w.use_item()
	await wait(0.4)
	var primed := lost(near1) - h0
	await wait(2.0)
	h0 = lost(near1)
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.4)
	var plain := lost(near1) - h0
	ok("spear Primed: the thrust after a connecting lunge deals twice the close-in hit (%.2f vs %.2f)" % [primed, plain], plain > 0.1 and absf(primed / plain - 2.0) < 0.1)
	# Second Wave
	var wv := {}
	for t in [4, 5]:
		w = await equip("spear", t, false)
		var c: Vector2 = P + (player.aim_point() - P).limit_length(120.0)
		var ds := [dummy(c + Vector2(80, 0)), dummy(c + Vector2(-80, 0)), dummy(c + Vector2(0, 80))]
		w.use_ultimate()
		await wait(2.4)
		var a := 0.0
		for d in ds:
			a += lost(d)
		await wait(1.2)
		var b := 0.0
		for d in ds:
			b += lost(d)
		wv[t] = [a, b - a]
	ok("spear Second Wave: tier 5 deals more in the 2.4-3.6 s window (%.1f vs %.1f)" % [wv[5][1], wv[4][1]], wv[5][1] > wv[4][1] + 2.5)
	# Heaven's Spear
	var hs := {}
	for t in [5, 6]:
		w = await equip("spear", t, false)
		var c: Vector2 = P + (player.aim_point() - P).limit_length(120.0)
		var d = dummy(c)
		w.use_ultimate()
		var big := false
		var pillar := false
		var stunned := false
		for i in 90:
			await wait(0.05)
			for f in world.get_children():
				if f.get_script() != null and str(f.get_script().resource_path).ends_with("fx.gd"):
					if f.kind == "fall" and f.radius >= 7.0:
						big = true
					if f.kind == "pillar":
						pillar = true
			if is_instance_valid(d) and d.slow_mult == 0.0:
				stunned = true
		hs[t] = [big, pillar, stunned]
	ok("spear Heaven's Spear: tier 6 big fall, pillar and stun %s; tier 5 none %s" % [hs[6], hs[5]], hs[6][0] and hs[6][1] and hs[6][2] and !hs[5][0] and !hs[5][1])
	# the lunge refund still works at tier 6
	w = await equip("spear", 6, false)
	dummy(P + Vector2(30, 0))
	w.use_dash()
	await wait(0.5)
	ok("spear: the Lunge refund still works at tier 6 (cooldown left %.2f of %.2f)" % [w._dash_cd, w.dash_cooldown], w._dash_cd <= w.dash_cooldown * 0.36)
	await draw_smoke("spear")

func run() -> void:
	if only == "" or only == "spear":
		await t_spear()
	if only == "" or only == "torch":
		await t_torch()
