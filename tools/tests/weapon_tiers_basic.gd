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

func stun_secs(d, secs: float) -> float:
	var t := 0.0
	for i in int(secs / 0.05):
		await wait(0.05)
		if is_instance_valid(d) and d.slow_mult == 0.0:
			t += 0.05
	return t

func t_hammer() -> void:
	var w
	var rp := {}
	for t in [1, 2]:
		w = await equip("hammer", t, false)
		# tier 1 has no charged slam: a tier 1 dummy only shows what nothing does
		var r := 70.0
		var d = dummy(P + Vector2(r * 1.3, 0))
		w.use_ability()
		await wait(1.25)
		var state_seen: float = w._aura.state if w._aura != null else -1.0
		w.release_ability()
		var seen := {}
		var low := 1.0
		for i in 16:
			await wait(0.05)
			fx_kinds(seen)
			low = minf(low, d.slow_mult)
		rp[t] = [lost(d), low, seen, state_seen]
	ok("hammer Ripple: tier 2 second ring hurts a dummy at 1.3 x radius (%.1f), chills it (%.2f), ripple fx %s; tier 1 nothing (%.1f)" % [rp[2][0], rp[2][1], rp[2][2].has("ripple"), rp[1][0]], rp[2][0] > 0.5 and rp[2][1] <= 0.51 and rp[2][2].has("ripple") and rp[1][0] == 0.0)
	ok("hammer: the aura state rises while charging (%.0f at tier 2)" % rp[2][3], rp[2][3] >= 90.0)
	var gp := {}
	for t in [2, 3]:
		w = await equip("hammer", t, false)
		var d = dummy(P + Vector2(22 + 33, 0))
		var per := []
		var seen := {}
		for i in 3:
			var h0 := lost(d)
			w.use_item()
			for k in 9:
				await wait(0.05)
				fx_kinds(seen)
			per.append(lost(d) - h0)
			await wait(0.6)
		gp[t] = [per, seen]
	ok("hammer Ground Pound: tier 3 only the third smash reaches 33 px past the head (%s), shock and crack %s; tier 2 never %s" % [gp[3][0], gp[3][1].has("shock") and gp[3][1].has("crack"), gp[2][0]], gp[3][0][0] == 0.0 and gp[3][0][1] == 0.0 and gp[3][0][2] > 0.0 and gp[3][1].has("shock") and gp[2][0] == [0.0, 0.0, 0.0])
	var cl := {}
	for t in [3, 4]:
		w = await equip("hammer", t, false)
		var land: Vector2 = P + Vector2(70, 0)
		var inner = dummy(land + Vector2(0, 33))
		var outer = dummy(land + Vector2(0, 52))
		w.use_dash()
		await wait(0.22)
		var stun: float = await stun_secs(inner, 1.4)
		cl[t] = [lost(outer), stun, lost(inner)]
	ok("hammer Crater Leap: tier 4 outer dummy takes the rubble (%.1f vs %.1f), inner stunned %.2f s (tier 3 %.2f)" % [cl[4][0], cl[3][0], cl[4][1], cl[3][1]], cl[4][0] > 1.0 and cl[3][0] == 0.0 and cl[4][1] >= 0.7)
	var mt := {}
	for t in [4, 5, 6]:
		w = await equip("hammer", t, false)
		var c: Vector2 = P + (player.aim_point() - P).limit_length(120.0)
		var frag = dummy(c + Vector2(50, 0))
		w.use_ultimate()
		var seen := {}
		var slow_hz := 0.0
		var comet := false
		var big_after := 0.0
		var l_imp := 0.0
		for i in 60:
			await wait(0.05)
			fx_kinds(seen)
			for f in world.get_children():
				if f.get_script() == null:
					continue
				var sp: String = str(f.get_script().resource_path)
				if sp.ends_with("hazard.gd"):
					slow_hz = maxf(slow_hz, f.radius)
				if sp.ends_with("fx.gd") and f.kind == "fall" and f.radius >= 8.0:
					comet = true
			if i == 31:
				l_imp = lost(frag)
		mt[t] = {"lost": lost(frag), "seen": seen, "hz": slow_hz, "comet": comet, "imp": l_imp}
	ok("hammer Shatter: tier 5 fragments hurt a dummy at radius 50 (%.1f vs %.1f)" % [mt[5].lost, mt[4].lost], mt[5].lost > mt[4].lost + 2.0)
	ok("hammer Worldfall: tier 6 comet %s, slow crater r%.0f, more damage (%.1f vs %.1f); tier 5 no comet/crater (%s, %.0f)" % [mt[6].comet, mt[6].hz, mt[6].lost, mt[5].lost, mt[5].comet, mt[5].hz], mt[6].comet and mt[6].hz == 60.0 and !mt[5].comet and mt[5].hz == 0.0 and mt[6].lost > mt[5].lost + 3.0)
	await draw_smoke("hammer")

func shoot_hold(w, secs: float) -> void:
	w.use_item()
	await wait(secs)
	w.release_item()

func t_bow() -> void:
	var w
	var fan := {}
	for t in [1, 2]:
		w = await equip("bow", t, false)
		var ds := [dummy(P + Vector2(60, 0))]
		w.use_ability()
		await wait(0.02)
		var n := count_script("projectile.gd")
		await wait(0.5)
		fan[t] = [n, is_exposed(ds[0])]
	ok("bow Fan: tier 2 volley fires %d arrows (tier 1 has no volley: %d) and the lead arrow exposes the dummy %s" % [fan[2][0], fan[1][0], fan[2][1]], fan[2][0] == 7 and fan[1][0] == 0 and fan[2][1])
	var od := {}
	for t in [2, 3]:
		w = await equip("bow", t, false)
		var d = dummy(P + Vector2(40, 0))
		await shoot_hold(w, 0.9)
		var peak := 0
		var seen := {}
		for i in 14:
			await wait(0.05)
			peak = maxi(peak, count_script("projectile.gd"))
			fx_kinds(seen)
		od[t] = [peak, seen.has("star")]
	ok("bow Overdraw: tier 3 perfect shot splits (%d projectiles, star %s); tier 2 one (%d)" % [od[3][0], od[3][1], od[2][0]], od[3][0] >= 3 and od[3][1] and od[2][0] == 1 and !od[2][1])
	var sr := {}
	for t in [3, 4]:
		w = await equip("bow", t, false)
		w.use_dash()
		await wait(0.02)
		var n := count_script("projectile.gd")
		await wait(0.15)
		var hz := 0.0
		for f in world.get_children():
			if f.get_script() != null and str(f.get_script().resource_path).ends_with("hazard.gd"):
				hz = f.radius
		sr[t] = [n, hz]
	ok("bow Smoke Roll: tier 4 dash %d arrows and a slow patch r%.0f; tier 3 %d arrows, no patch (%.0f)" % [sr[4][0], sr[4][1], sr[3][0], sr[3][1]], sr[4][0] == 3 and sr[4][1] == 24.0 and sr[3][0] == 1 and sr[3][1] == 0.0)
	var st := {}
	for t in [4, 5, 6]:
		w = await equip("bow", t, false)
		var c: Vector2 = P + (player.aim_point() - P).limit_length(150.0)
		var ds := []
		for ring in [30.0, 45.0, 60.0]:
			for k in 8:
				ds.append(dummy(c + Vector2.from_angle(float(k) * TAU / 8.0) * ring))
		w.use_ultimate()
		var falls := 0
		var giant := false
		var proj_after := 0
		var seen_ids := {}
		var at_23 := 0.0
		for i in 70:
			await wait(0.05)
			for f in world.get_children():
				if f.get_script() != null and str(f.get_script().resource_path).ends_with("fx.gd") and f.kind == "fall":
					seen_ids[f.get_instance_id()] = f.radius
			if i >= 28:
				proj_after = maxi(proj_after, count_script("projectile.gd"))
			if i == 45:
				for d in ds:
					at_23 += lost(d)
		var total := 0.0
		for d in ds:
			total += lost(d)
		for k in seen_ids:
			if seen_ids[k] == 2.0:
				falls += 1
			if seen_ids[k] >= 6.0:
				giant = true
		var d = ds[0]
		st[t] = {"falls": falls, "giant": giant, "lost": total - at_23, "proj": proj_after}
	ok("bow Rainstorm: tier 5 drops %d arrows (tier 4: %d) and deals more after 2.3 s (%.1f vs %.1f)" % [st[5].falls, st[4].falls, st[5].lost, st[4].lost], st[5].falls >= 8 and st[4].falls == 0 and st[5].lost > st[4].lost + 1.0)
	ok("bow Skyfall: tier 6 giant arrow %s and %d radial arrows; tier 5 %s/%d" % [st[6].giant, st[6].proj, st[5].giant, st[5].proj], st[6].giant and st[6].proj >= 6 and !st[5].giant)
	# Piercing Gale: the sixth full draw
	w = await equip("bow", 6, false)
	var far = dummy(P + Vector2(100, 0))
	var beam := false
	for i in 6:
		w._attack_cd = 0.0
		w.use_item()
		await wait(0.85)
		w.release_item()
		var seen := {}
		for k in 4:
			await wait(0.05)
			fx_kinds(seen)
		if seen.has("beam"):
			beam = i == 5
		await wait(0.3)
	ok("bow Piercing Gale: the sixth full draw at tier 6 shows a beam %s" % beam, beam)
	await draw_smoke("bow")

## Hits on a dummy: count the drops of its health, sampling every 0.02 s for `secs`.
func hit_steps(d, secs: float) -> Array:
	var out := []
	var last := lost(d)
	for i in int(secs / 0.02):
		await wait(0.02)
		var l := lost(d)
		if l > last + 0.01:
			out.append(snappedf(i * 0.02, 0.02))
			last = l
	return out

func t_daggers() -> void:
	var w
	var kn := {}
	for t in [1, 2]:
		w = await equip("daggers", t, false)
		w.use_ability()
		await wait(0.02)
		kn[t] = count_script("projectile.gd")
	ok("daggers Fan of Knives: tier 2 throws %d knives (tier 1 has no ability)" % kn[2], kn[2] == 5)
	var fl := {}
	for t in [2, 3]:
		w = await equip("daggers", t, false)
		var d = dummy(P + Vector2(20, 0))
		var per := []
		var counts := []
		for i in 3:
			w._attack_cd = 0.0
			var h0 := lost(d)
			w.use_item()
			var st: Array = await hit_steps(d, 0.4)
			per.append(lost(d) - h0)
			counts.append(st.size())
			await wait(0.1)
		fl[t] = [per, counts]
	ok("daggers Flurry: tier 3 third slash adds two cuts after the first (%s later hits, damage %s); tier 2 %s" % [fl[3][1], fl[3][0], fl[2][1]], fl[3][1][2] == 2 and fl[3][1][0] == 0 and fl[2][1] == [0, 0, 0] and fl[3][0][2] > fl[3][0][0] * 1.8 and fl[2][0][2] < fl[2][0][0] * 1.2)
	var ph := {}
	for t in [3, 4]:
		w = await equip("daggers", t, false)
		var d = dummy(P + Vector2(0, 15))
		w.use_dash()
		await wait(0.9)
		ph[t] = [lost(d), is_exposed(d)]
	ok("daggers Phantom Step: tier 4 phantom strikes the dummy by the start point (%.1f vs %.1f), exposed %s" % [ph[4][0], ph[3][0], ph[4][1]], ph[4][0] > ph[3][0] + 1.0 and ph[4][1])
	var sc := {}
	for t in [4, 5]:
		w = await equip("daggers", t, false)
		var d = dummy(P + Vector2(80, 0))
		w.use_ultimate()
		var steps := await hit_steps(d, 3.0)
		sc[t] = steps
	ok("daggers Shadow Clones: tier 5 the marked dummy takes %d separate hits in 3 s, tier 4 %d" % [sc[5].size(), sc[4].size()], sc[5].size() >= 4 and sc[4].size() == 0)
	var tc := {}
	for t in [5, 6]:
		w = await equip("daggers", t, false)
		var d = dummy(P + Vector2(100, 0))
		w.use_ultimate()
		await wait(5.95)
		var seen := {}
		var st := []
		var last := lost(d)
		for i in 40:
			await wait(0.02)
			fx_kinds(seen)
			var l := lost(d)
			if l > last + 0.01:
				st.append(i)
				last = l
		tc[t] = [st.size(), seen]
	ok("daggers Thousand Cuts: tier 6 the end of the mark is %d quick hits (tier 5: %d), cut fx %s" % [tc[6][0], tc[5][0], tc[6][1].has("cut")], tc[6][0] >= 5 and tc[6][1].has("cut") and tc[5][0] <= 2)
	# finisher: the sixth slash at tier 6 hits harder than the fifth
	w = await equip("daggers", 6, false)
	var d6 = dummy(P + Vector2(20, 0))
	var dm := []
	for i in 6:
		w._attack_cd = 0.0
		d6.remove_meta("exposed_until") if d6.has_meta("exposed_until") else null
		var h0 := lost(d6)
		w.use_item()
		await wait(0.45)
		dm.append(lost(d6) - h0)
	ok("daggers Finisher: the sixth slash at tier 6 hits harder than the fifth (%.1f vs %.1f)" % [dm[5], dm[4]], dm[5] > dm[4] * 1.5)
	# the backstab refund still works at tier 6
	w = await equip("daggers", 6, false)
	var d7 = dummy(P + Vector2(20, 0))
	d7.set_meta("exposed_until", Time.get_ticks_msec() / 1000.0 + 5.0)
	w._dash_cd = 4.0
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.1)
	ok("daggers: the backstab still refunds the dash cooldown at tier 6 (%.2f left)" % w._dash_cd, w._dash_cd < 3.0)
	await draw_smoke("daggers")

func t_scimitar() -> void:
	var w
	w = await equip("scimitar", 2, false)
	var ds := []
	for i in 5:
		ds.append(dummy(P + Vector2(25 + 28 * i, 0)))
	w.use_ability()
	await wait(0.1)
	var steps := []
	var lasts := []
	for d in ds:
		lasts.append(lost(d))
		steps.append(0)
	for i in 100:
		await wait(0.05)
		for k in 5:
			var l := lost(ds[k])
			if l > lasts[k] + 0.01:
				steps[k] += 1
				lasts[k] = l
	ok("scimitar Wide Crescent: tier 2 wave cuts and bleeds all five dummies (bleed hits after the wave: %s, need >= 5 each)" % [steps], steps.all(func(x): return x >= 5))
	var dd := {}
	for t in [2, 3]:
		w = await equip("scimitar", t, false)
		var d = dummy(P + Vector2(25, 0))
		var per := []
		var seen := {}
		for i in 3:
			w._attack_cd = 0.0
			var h0 := lost(d)
			w.use_item()
			for k in 8:
				await wait(0.05)
				fx_kinds(seen)
			await wait(1.8)                    # let the bleed run out
			per.append(snappedf(lost(d) - h0, 0.1))
		dd[t] = [per, seen]
	ok("scimitar Dune Dance: tier 3 third slash is a double swing (%s, slash fx %s); tier 2 %s" % [dd[3][0], dd[3][1].has("slash"), dd[2][0]], dd[3][1].has("slash") and !dd[2][1].has("slash") and dd[3][0][2] > dd[3][0][0] + 0.8)
	var af := {}
	for t in [3, 4]:
		w = await equip("scimitar", t, false)
		var d = dummy(P + Vector2(50.0 / 3.0, 18))
		w.use_dash()
		await wait(1.0)
		af[t] = lost(d)
	ok("scimitar Afterimages: tier 4 an afterimage cuts a dummy beside the path (%.1f vs %.1f)" % [af[4], af[3]], af[4] > af[3] + 1.0)
	var sd := {}
	for t in [4, 5, 6]:
		w = await equip("scimitar", t, false)
		var d = dummy(P + Vector2(40, 0))
		var far = dummy(P + Vector2(90, 0))
		w.use_ultimate()
		var hz := 0.0
		var hz_at := -1.0
		var seen := {}
		var crescents := 0
		for i in 130:
			await wait(0.05)
			fx_kinds(seen)
			for f in world.get_children():
				if f.get_script() == null:
					continue
				var sp: String = str(f.get_script().resource_path)
				if sp.ends_with("hazard.gd") and hz == 0.0:
					hz = f.radius
					hz_at = i * 0.05
				if sp.ends_with("projectile.gd") and f.style == "crescent":
					crescents = maxi(crescents, count_script("projectile.gd"))
		sd[t] = {"hz": hz, "at": hz_at, "seen": seen, "cres": crescents, "far": lost(far)}
	ok("scimitar Sandstorm: tier 5 sand zone r%.0f at %.1f s and a vortex (%s); tier 4 none (%.0f)" % [sd[5].hz, sd[5].at, sd[5].seen.has("vortex"), sd[4].hz], sd[5].hz == 52.0 and sd[5].seen.has("vortex") and sd[4].hz == 0.0 and sd[5].at >= 1.3 and sd[5].at <= 1.8)
	ok("scimitar Desert Wrath: tier 6 pillar %s and %d crescents; far dummy takes more (%.1f vs %.1f); tier 5 none (%s, %d)" % [sd[6].seen.has("pillar"), sd[6].cres, sd[6].far, sd[5].far, sd[5].seen.has("pillar"), sd[5].cres], sd[6].seen.has("pillar") and sd[6].cres >= 6 and !sd[5].seen.has("pillar") and sd[6].far > sd[5].far + 1.0)
	w = await equip("scimitar", 6, false)
	var d6 = dummy(P + Vector2(25, 0))
	var maxp := 0
	for i in 6:
		w._attack_cd = 0.0
		w.use_item()
		await wait(0.1)
		maxp = maxi(maxp, count_script("projectile.gd"))
		await wait(0.35)
	ok("scimitar Finisher: the sixth slash at tier 6 throws a wave (%d projectiles alive)" % maxp, maxp >= 1)
	await draw_smoke("scimitar")

func t_whip() -> void:
	var w
	w = await equip("whip", 2, false)
	var target = dummy(P + Vector2(60, 0))
	var pack1 = dummy(P + Vector2(60, 30))
	var pack2 = dummy(P + Vector2(60, -30))
	w.use_ability()
	await wait(0.15)
	var a := lost(target)
	var all_exposed: bool = is_exposed(target) and is_exposed(pack1) and is_exposed(pack2)
	await wait(1.4)
	ok("whip Barbed Hook: tier 2 the whole pack is exposed %s and the target keeps bleeding (%.1f more)" % [all_exposed, lost(target) - a], all_exposed and lost(target) - a > 0.5)
	var dc := {}
	for t in [2, 3]:
		w = await equip("whip", t, false)
		var d = dummy(P + Vector2(56, 0))
		var per := []
		var seen := {}
		for i in 3:
			w._attack_cd = 0.0
			var h0 := lost(d)
			w.use_item()
			for k in 8:
				await wait(0.05)
				fx_kinds(seen)
			per.append(lost(d) - h0)
			await wait(0.3)
		dc[t] = [per, seen]
	ok("whip Double Crack: tier 3 only the second arc of the third swing reaches 56 px (%s), slash fx %s; tier 2 %s" % [dc[3][0], dc[3][1].has("slash"), dc[2][0]], dc[3][0][0] == 0.0 and dc[3][0][1] == 0.0 and dc[3][0][2] > 0.0 and dc[3][1].has("slash") and dc[2][0] == [0.0, 0.0, 0.0])
	var eh := {}
	for t in [3, 4]:
		w = await equip("whip", t, false)
		var d = dummy(P + Vector2(30, 0))
		w.use_ability()
		await wait(0.2)
		var h0 := lost(d)
		await wait(0.5)
		eh[t] = lost(d) - h0
	ok("whip Echo Hook: tier 4 a second snap hits the pulled dummy (%.1f vs %.1f)" % [eh[4], eh[3]], eh[4] > eh[3] + 2.0)
	var gp := {}
	for t in [3, 4]:
		w = await equip("whip", t, false)
		var d = dummy(P + Vector2(90, 0))
		w.use_dash()
		await wait(0.5)
		gp[t] = d.global_position.x - player.global_position.x
	ok("whip Grapple Swing: tier 4 the dash ends %.0f px from the dummy at 90 (tier 3: %.0f)" % [gp[4], gp[3]], gp[4] <= 20.0 and gp[3] > 20.0)
	var im := {}
	for t in [4, 5, 6]:
		w = await equip("whip", t, false)
		var ds := [dummy(P + Vector2(30, 0)), dummy(P + Vector2(-30, 5))]
		w.use_ultimate()
		var seen := {}
		var stunned := false
		for i in 60:
			await wait(0.05)
			fx_kinds(seen)
			if ds[0].slow_mult == 0.0 or ds[1].slow_mult == 0.0:
				stunned = true
		im[t] = {"lost": lost(ds[0]) + lost(ds[1]), "seen": seen, "stun": stunned}
	ok("whip Implosion: tier 5 vortex fx %s and more damage than tier 4 (%.1f vs %.1f; the dummies stand still, so the pull itself is not measured)" % [im[5].seen.has("vortex"), im[5].lost, im[4].lost], im[5].seen.has("vortex") and !im[4].seen.has("vortex") and im[5].lost > im[4].lost + 2.0)
	ok("whip Thunder Crack: tier 6 bolts %s, stun %s, more damage (%.1f vs %.1f); tier 5 no bolts %s" % [im[6].seen.has("bolt"), im[6].stun, im[6].lost, im[5].lost, im[5].seen.has("bolt")], im[6].seen.has("bolt") and im[6].stun and !im[5].seen.has("bolt") and im[6].lost > im[5].lost + 4.0)
	w = await equip("whip", 6, false)
	var d6 = dummy(P + Vector2(64, 0))
	var fin := false
	for i in 6:
		w._attack_cd = 0.0
		var h0 := lost(d6)
		w.use_item()
		await wait(0.4)
		if i == 5:
			fin = lost(d6) - h0 > 0.0                # 64 px is beyond the normal reach of 46: only the finisher (r 70) gets there
	ok("whip Finisher: the sixth crack at tier 6 reaches 64 px %s" % fin, fin)
	await draw_smoke("whip")

func parry(w, from_x := 20.0) -> void:
	w.use_ability()
	await wait(0.1)
	player.take_damage(player.global_position + Vector2(from_x, 0), 10.0)
	await wait(0.05)

func t_shield() -> void:
	var w
	# Reflection
	var rf := {}
	for t in [1, 2]:
		w = await equip("shield", t, false)
		var sh_class = load("res://enemies/spitter/enemy_projectile.gd")
		sh_class.fire(world, player.global_position + Vector2(60, 0), Vector2(-1, 0), 20.0, 30.0)
		await wait(0.1)
		var shots := get_nodes_in_group("enemy_shot")
		if t == 1:
			# tier 1 has no parry: the shot just keeps coming
			rf[t] = [shots.size(), shots[0].friendly if !shots.is_empty() else false]
		else:
			await parry(w)
			shots = get_nodes_in_group("enemy_shot")
			rf[t] = [shots.size(), shots[0].friendly if !shots.is_empty() else false, shots[0].vel.x if !shots.is_empty() else 0.0]
	ok("shield Reflection: tier 2 parry sends the shot back (friendly %s, vel.x %s); tier 1 has no parry" % [rf[2][1], rf[2][2]], rf[2][1] and rf[2][2] > 0.0 and !rf[1][1])
	for sh in get_nodes_in_group_safe("enemy_shot"):
		sh.queue_free()
	var sl := {}
	for t in [2, 3]:
		w = await equip("shield", t, false)
		var d = dummy(P + Vector2(31, 0))
		var per := []
		var seen := {}
		var stun := 0.0
		for i in 3:
			w._attack_cd = 0.0
			var h0 := lost(d)
			w.use_item()
			for k in 24:
				await wait(0.05)
				fx_kinds(seen)
				if d.slow_mult == 0.0:
					stun += 0.05
			per.append(lost(d) - h0)
			await wait(0.2)
		sl[t] = [per, seen, stun]
	ok("shield Shield Slam: tier 3 only the third bash reaches 31 px (%s), stunned %.2f s, cone fx %s; tier 2 %s" % [sl[3][0], sl[3][2], sl[3][1].has("cone"), sl[2][0]], sl[3][0][0] == 0.0 and sl[3][0][1] == 0.0 and sl[3][0][2] > 0.0 and sl[3][2] >= 0.8 and sl[3][1].has("cone") and sl[2][0] == [0.0, 0.0, 0.0])
	# Retaliation: the bash after a parry hits 1.5x
	w = await equip("shield", 4, false)
	var dr = dummy(P + Vector2(15, 0))
	await parry(w)
	await wait(0.5)
	var h0 := lost(dr)
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.3)
	var boosted := lost(dr) - h0
	await wait(4.5)
	w._st.retal = 0
	h0 = lost(dr)
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.3)
	var plain := lost(dr) - h0
	ok("shield Retaliation: tier 4 the bash after a parry does x1.5 (%.2f vs %.2f once the 4 s are over)" % [boosted, plain], plain > 0.1 and absf(boosted / plain - 1.5) < 0.1 and is_exposed(dr) == false)
	var rm := {}
	for t in [3, 4]:
		w = await equip("shield", t, false)
		var d1 = dummy(P + Vector2(20, 0))
		var d2 = dummy(P + Vector2(55 + 30, 0))
		w.use_dash()
		await wait(1.0)
		rm[t] = lost(d2)
	ok("shield Ram: tier 4 the end shock hits the dummy past the charge (%.1f vs %.1f)" % [rm[4], rm[3]], rm[4] > rm[3] + 3.0)
	var ci := {}
	for t in [4, 5, 6]:
		w = await equip("shield", t, false)
		var d = dummy(P + Vector2(60, 0))
		w.use_ultimate()
		var seen := {}
		var freed := false
		var sh_class = load("res://enemies/spitter/enemy_projectile.gd")
		sh_class.fire(world, player.global_position + Vector2(60, 0), Vector2(-1, 0), 15.0, 30.0, Color(0.5, 0.95, 0.3), 7.0, 8.0)
		var tstun := 0.0
		var flash80 := false
		var l_at_4 := 0.0
		for i in 112:
			await wait(0.05)
			fx_kinds(seen)
			if d.slow_mult == 0.0:
				tstun += 0.05
			if i == 50:
				l_at_4 = float(get_nodes_in_group("enemy_shot").size())
			for f in world.get_children():
				if f.get_script() != null and str(f.get_script().resource_path).ends_with("fx.gd") and f.kind == "flash" and f.radius >= 80.0:
					flash80 = true
		ci[t] = {"lost": lost(d), "seen": seen, "stun": tstun, "shots": int(l_at_4), "flash": flash80}
		for sh in get_nodes_in_group_safe("enemy_shot"):
			sh.queue_free()
	ok("shield Citadel: tier 5 ripples %s, eats the shot (alive at 2.5 s: %d vs tier 4: %d), hits the dummy at 60 px with its wider pulses (%.1f vs %.1f)" % [ci[5].seen.has("ripple"), ci[5].shots, ci[4].shots, ci[5].lost, ci[4].lost], ci[5].seen.has("ripple") and ci[5].shots == 0 and ci[4].shots == 1 and ci[5].lost > ci[4].lost + 3.0)
	ok("shield Aegis Eternal: tier 6 finale flash r80 %s and more damage (%.1f vs %.1f); tier 5 none %s" % [ci[6].flash, ci[6].lost, ci[5].lost, ci[5].flash], ci[6].flash and !ci[5].flash and ci[6].lost > ci[5].lost + 3.0)
	w = await equip("shield", 6, false)
	var d6 = dummy(P + Vector2(20, 0))
	var streak := false
	for i in 6:
		w._attack_cd = 0.0
		w.use_item()
		var seen := {}
		for k in 8:
			await wait(0.05)
			fx_kinds(seen)
		if i == 5:
			streak = seen.has("streak")
		await wait(0.3)
	ok("shield Finisher: the sixth bash at tier 6 follows with a streak %s" % streak, streak)
	await draw_smoke("shield")

func get_nodes_in_group_safe(g: String) -> Array:
	return get_nodes_in_group(g)

func hazards(factor := -1.0) -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("hazard.gd") and (factor < 0.0 or absf(n.factor - factor) < 0.01):
			c += 1
	return c

func t_frostglaive() -> void:
	var w
	w = await equip("frostglaive", 2, false)
	w.use_ability()
	await wait(0.9)
	var rime := hazards(0.6)
	ok("frostglaive Rime: tier 2 line leaves %d slow patches (factor 0.6) after 0.9 s" % rime, rime == 3)
	var ic := {}
	for t in [2, 3]:
		w = await equip("frostglaive", t, false)
		var d = dummy(P + Vector2(70, 0))
		var per := []
		var seen := {}
		var shards := 0
		for i in 3:
			w._attack_cd = 0.0
			var h0 := lost(d)
			w.use_item()
			for k in 10:
				await wait(0.05)
				fx_kinds(seen)
				shards = maxi(shards, count_script("projectile.gd"))
			per.append(lost(d) - h0)
			await wait(0.5)
		ic[t] = [per, shards]
	ok("frostglaive Ice Comb: tier 3 the third cleave throws shards that reach 70 px (%s, %d projectiles); tier 2 %s" % [ic[3][0], ic[3][1], ic[2][0]], ic[3][0][0] == 0.0 and ic[3][0][1] == 0.0 and ic[3][0][2] > 0.0 and ic[3][1] >= 3 and ic[2][0] == [0.0, 0.0, 0.0])
	var ff := {}
	for t in [3, 4]:
		w = await equip("frostglaive", t, false)
		var d = dummy(P + Vector2.from_angle(0.45) * 40.0)
		w.use_ability()
		await wait(1.3)
		ff[t] = lost(d)
	ok("frostglaive Frozen Fan: tier 4 spikes either side hit a dummy 0.45 rad off (%.1f vs %.1f)" % [ff[4], ff[3]], ff[4] > ff[3] + 1.0)
	var rk := {}
	for t in [3, 4]:
		w = await equip("frostglaive", t, false)
		var d = dummy(P + Vector2(50, 0))
		w.use_dash()
		await wait(0.5)
		rk[t] = [hazards(0.4), d.slow_mult]
	ok("frostglaive Ice Rink: tier 4 dash leaves %d frozen patches (tier 3: %d) and chills the dummy" % [rk[4][0], rk[3][0]], rk[4][0] == 3 and rk[3][0] == 0)
	var wo := {}
	for t in [4, 5, 6]:
		w = await equip("frostglaive", t, false)
		var d = dummy(P + Vector2(100, 0))
		w.use_ultimate()
		var ticks := 0
		var last := 0.0
		var slow_all := true
		var seen := {}
		var biggest := 0.0
		var step_at := 0.0
		await wait(0.6)
		last = lost(d)
		for i in 100:
			await wait(0.05)
			fx_kinds(seen)
			var l := lost(d)
			if l > last + 0.01:
				ticks += 1
				if l - last > biggest:
					biggest = l - last
					step_at = 0.6 + (i + 1) * 0.05
				last = l
		wo[t] = {"ticks": ticks, "big": biggest, "at": step_at, "seen": seen}
	ok("frostglaive Whiteout: tier 5 the dummy at 100 px takes %d blizzard ticks (tier 4: %d), vortex %s" % [wo[5].ticks, wo[4].ticks, wo[5].seen.has("vortex")], wo[5].ticks >= 3 and wo[4].ticks == 0 and wo[5].seen.has("vortex"))
	ok("frostglaive Absolute Zero: tier 6 shatters in one big step (%.1f at %.1f s vs tier 5 %.1f)" % [wo[6].big, wo[6].at, wo[5].big], wo[6].seen.has("flash") and wo[6].big >= 8.0 and wo[6].big > wo[5].big * 3.0)
	w = await equip("frostglaive", 6, false)
	var d6 = dummy(P + Vector2(40, 0))
	var stunned := false
	for i in 6:
		w._attack_cd = 0.0
		w.use_item()
		for k in 8:
			await wait(0.05)
			if i == 5 and d6.slow_mult == 0.0:
				stunned = true
		await wait(0.3)
	ok("frostglaive Finisher: the sixth cleave at tier 6 stuns a dummy at 40 px %s" % stunned, stunned)
	await draw_smoke("frostglaive")

func run() -> void:
	if only == "" or only == "frostglaive":
		await t_frostglaive()
	if only == "" or only == "shield":
		await t_shield()
	if only == "" or only == "whip":
		await t_whip()
	if only == "" or only == "scimitar":
		await t_scimitar()
	if only == "" or only == "daggers":
		await t_daggers()
	if only == "" or only == "bow":
		await t_bow()
	if only == "" or only == "hammer":
		await t_hammer()
	if only == "" or only == "spear":
		await t_spear()
	if only == "" or only == "torch":
		await t_torch()
