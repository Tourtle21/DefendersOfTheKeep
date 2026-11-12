extends "res://tools/tests/weapon_tiers_fusions_a.gd"
## Fused weapons, second batch (docs/weapon_tiers): rimelance, sultanguard, dragoonpike, magmamaul, spellblade, tempest.
## Same helpers as weapon_tiers_fusions_a.gd.   Run all: --script res://tools/tests/weapon_tiers_fusions_b.gd   One weapon: ... -- only=rimelance

func hazard_r(kind: String, radius: float) -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("world/hazard.gd") and n.kind == kind and is_equal_approx(n.radius, radius):
			c += 1
	return c

func t_rimelance() -> void:
	var w
	# Icicle: the thrown glaive chills everything it passes for 2.5 s and shatters at the end
	w = await equip("rimelance", 2, false)
	var a = dummy(P + Vector2(40, 0))
	var b = dummy(P + Vector2(80, 0))
	w.use_ability()
	var r = await watch(0.7)
	ok("rimelance Icicle: tier 2 chills both dummies on its path (slow_time %.1f / %.1f >= 2.0) and shatters into shards %s" % [a.slow_time, b.slow_time, r.kinds.has("shards")], a.slow_time >= 2.0 and b.slow_time >= 2.0 and r.kinds.has("shards"))
	# Frostbite: three tip thrusts freeze and shatter the dummy
	var fb := {}
	for t in [2, 3]:
		w = await equip("rimelance", t, false)
		var dd = dummy(P + Vector2(40, 0))
		var seq := []
		for i in 3:
			click(w)
			await wait(0.25)
			seq.append(snappedf(dd.slow_mult, 0.1))
			await wait(0.25)
		fb[t] = [seq, snappedf(lost(dd), 0.1)]
	ok("rimelance Frostbite: tier 3 freezes the dummy at the 3rd thrust %s (slow_mult 0); tier 2 never %s" % [fb[3], fb[2]], fb[3][0][2] == 0.0 and fb[3][0][1] > 0.0 and fb[2][0][2] > 0.0 and fb[3][1] > fb[2][1] + 3.0)
	# Winter's Edge: the glaive returns; the skate leaves an ice ribbon
	var we := {}
	for t in [3, 4]:
		w = await equip("rimelance", t, false)
		var dd = dummy(P + Vector2(60, 0))
		w.use_ability()
		var seen := {}
		var proj := 0
		for i in 26:
			await wait(0.05)
			if i >= 14:
				proj = maxi(proj, count_script("items/weapons/projectile.gd"))
		we[t] = [proj, snappedf(lost(dd), 0.1)]
	ok("rimelance Winter's Edge: tier 4 glaive comes back %s; tier 3 stays %s" % [we[4], we[3]], we[4][0] >= 1 and we[3][0] == 0 and we[4][1] > we[3][1] + 1.5)
	var rib := {}
	for t in [3, 4]:
		w = await equip("rimelance", t, false)
		var before := hazards("slow")
		w.use_dash()
		await wait(0.5)
		rib[t] = hazards("slow") - before
	ok("rimelance Winter's Edge: tier 4 skate leaves %d slow patches, tier 3 %d" % [rib[4], rib[3]], rib[4] >= 4 and rib[3] == 0)
	# Permafrost: a slow field of r 110 and icicles on the frozen
	var pf := {}
	for t in [4, 5]:
		w = await equip("rimelance", t, false)
		var dd = dummy(P + Vector2(50, 0))
		w.use_ultimate()
		await wait(1.0)
		var field := hazard_r("slow", 110.0)
		var h1 := lost(dd)
		await wait(5.5)
		pf[t] = [field, snappedf(lost(dd) - h1, 0.1)]
	ok("rimelance Permafrost: tier 5 field %s and icicles keep hurting the frozen dummy %s; tier 4 %s" % [pf[5][0], pf[5][1], pf[4]], pf[5][0] >= 1 and pf[4][0] == 0 and pf[5][1] > pf[4][1] + 3.0)
	# Glacier: the finale when the permafrost ends
	var gl := {}
	for t in [5, 6]:
		w = await equip("rimelance", t, false)
		var dd = dummy(P + Vector2(100, 0))
		w.use_ultimate()
		var seen := {}
		var late := false
		for i in 160:
			await wait(0.05)
			var before: int = seen.get("flash", 0)
			fx_kinds(seen)
			if i > 100 and seen.get("flash", 0) > before:
				late = true
		gl[t] = [late, snappedf(lost(dd), 0.1)]
	ok("rimelance Glacier: tier 6 shatters late with a flash %s and hits harder; tier 5 %s" % [gl[6], gl[5]], gl[6][0] and !gl[5][0] and gl[6][1] > gl[5][1] + 7.0)
	# Finisher: the 6th thrust is a beam
	var fin := {}
	for t in [5, 6]:
		w = await equip("rimelance", t, false)
		var saw := false
		for i in 6:
			click(w)
			await wait(0.08)
			if i == 5 and has_fx("beam"):
				saw = true
			await wait(0.35)
		fin[t] = saw
	ok("rimelance Finisher: the 6th thrust is a beam at tier 6 %s, not at tier 5 %s" % [fin[6], fin[5]], fin[6] and !fin[5])
	await draw_smoke("rimelance")

## Distinct projectiles of a style seen over `secs`.
func proj_ids(secs: float, style := "") -> int:
	var ids := {}
	for i in int(secs / 0.05):
		await wait(0.05)
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/projectile.gd") and (style == "" or n.style == style):
				ids[n.get_instance_id()] = true
	return ids.size()

func enemy_shot(pos: Vector2):
	var shot = load("res://enemies/spitter/enemy_projectile.gd").new()
	shot.position = pos
	shot.damage = 0.0
	shot.life = 99.0
	world.add_child(shot)
	return shot

func t_sultanguard() -> void:
	var w
	# Mirrored Wave: six crescents instead of four, and a shot near you is reversed
	w = await equip("sultanguard", 2, false)
	var att = dummy(P + Vector2(60, 0))
	var shot = enemy_shot(P + Vector2(40, 10))
	w.use_ability()
	await wait(0.1)
	player.take_damage(att.global_position, 10.0)
	var n: int = await proj_ids(0.3, "crescent")
	ok("sultanguard Mirrored Wave: tier 2 parry sends %d crescents (6) and reverses the shot (freed %s)" % [n, !is_instance_valid(shot) or shot.is_queued_for_deletion()], n >= 6 and (!is_instance_valid(shot) or shot.is_queued_for_deletion()))
	# Desert Shield: the 3rd slash is a double with a bash; the window is 0.55 s; a whiff raises a veil
	var ds := {}
	for t in [2, 3]:
		w = await equip("sultanguard", t, false)
		var dd = dummy(P + Vector2(20, 0))
		var seen := {}
		for i in 3:
			click(w)
			for k in 5:
				await wait(0.04)
				fx_kinds(seen)
			dd.slow_time = 0.0
			dd.slow_mult = 1.0
			await wait(0.2)
		ds[t] = seen.has("slash")
	w = await equip("sultanguard", 3, false)
	w.use_ability()
	await wait(0.05)
	var window: float = player.parry_time
	await wait(0.75)
	ok("sultanguard Desert Shield: tier 3 third slash bashes with a slash fx %s (tier 2 %s), the window is %.2f s, the whiff raises a veil (shield %.2f)" % [ds[3], ds[2], window, player.shield_time], ds[3] and !ds[2] and window > 0.45 and player.shield_time > 0.0)
	# Oasis Mirage: a mirage keeps cutting after the parry; the dash leaves one too
	var om := {}
	for t in [3, 4]:
		w = await equip("sultanguard", t, false)
		var at2 = dummy(P + Vector2(20, 0))
		w.use_ability()
		await wait(0.1)
		player.take_damage(at2.global_position, 10.0)
		await wait(1.2)
		var h1 := lost(at2)
		await wait(1.0)
		var parry_gain := lost(at2) - h1
		w = await equip("sultanguard", t, false)
		var near = dummy(P + Vector2(12, 0))
		w.use_dash()
		await wait(0.2)
		near.slow_time = 0.0
		near.slow_mult = 1.0
		var d1 := lost(near)
		await wait(1.0)
		om[t] = [snappedf(parry_gain, 0.1), snappedf(lost(near) - d1, 0.1), near.slow_mult]
	ok("sultanguard Oasis Mirage: tier 4 mirages keep cutting %s (parry, dash, slow); tier 3 %s" % [om[4], om[3]], om[4][0] > om[3][0] + 3.0 and om[4][1] > om[3][1] + 3.0 and om[4][2] < 1.0 and om[3][2] >= 1.0)
	# Sandwall: the cyclone eats a shot and leaves a slow patch with a dust devil
	var sw := {}
	for t in [4, 5]:
		w = await equip("sultanguard", t, false)
		var sh = enemy_shot(P + Vector2(30, 0))
		w.use_ultimate()
		await wait(2.0)
		sw[t] = [!is_instance_valid(sh) or sh.is_queued_for_deletion(), hazard_r("slow", 70.0)]
		if is_instance_valid(sh):
			sh.queue_free()
	ok("sultanguard Sandwall: tier 5 eats the shot and leaves a slow patch %s; tier 4 %s" % [sw[5], sw[4]], sw[5][0] and sw[5][1] >= 1 and !sw[4][0] and sw[4][1] == 0)
	# Sultan's Judgment: eight great scimitars and a pillar
	var sj := {}
	for t in [5, 6]:
		w = await equip("sultanguard", t, false)
		var dd = dummy(P + Vector2(100, 0))
		w.use_ultimate()
		var seen := {}
		var ids := {}
		for i in 50:
			await wait(0.05)
			fx_kinds(seen)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "crescent" and nd.size > 1.5:
					ids[nd.get_instance_id()] = true
		sj[t] = [ids.size(), seen.has("pillar"), snappedf(lost(dd), 0.1)]
	ok("sultanguard Sultan's Judgment: tier 6 %s (blades, pillar, damage) vs tier 5 %s" % [sj[6], sj[5]], sj[6][0] >= 8 and sj[6][1] and sj[5][0] == 0 and sj[6][2] > sj[5][2] + 2.0)
	# Finisher: the 6th slash is a free riposte wave
	var fin := {}
	for t in [5, 6]:
		w = await equip("sultanguard", t, false)
		var dd = dummy(P + Vector2(200, 0))
		var got := 0
		for i in 6:
			click(w)
			if i == 5:
				got = await proj_ids(0.25, "crescent")
			else:
				await wait(0.3)
			await wait(0.3)
		fin[t] = got
	ok("sultanguard Finisher: the 6th slash throws %d crescents at tier 6, %d at tier 5" % [fin[6], fin[5]], fin[6] >= 2 and fin[5] == 0)
	await draw_smoke("sultanguard")

func t_dragoonpike() -> void:
	var w
	# Entry (tier 3): Shock Cone, the rhythm wave after the 2nd thrust, the long 3rd thrust, fang lunges that mark
	w = await equip("dragoonpike", 3, false)
	var d0 = dummy(P + Vector2(100, 0))
	w.use_ability()
	await wait(0.05)
	w.release_ability()
	var r = await watch(1.4)
	ok("dragoonpike Wyvern's Fang: tier 3 ram ends in a cone %s and the lunges are marked (exposed %.1f s) with cuts %s" % [r.kinds.has("cone"), exposed_for(d0), r.kinds.has("cut")], r.kinds.has("cone") and r.kinds.has("cut") and exposed_for(d0) > 0.0)
	w = await equip("dragoonpike", 3, false)
	var tgt = dummy(P + Vector2(66, 0))
	var per := []
	var waves := []
	for i in 3:
		var h0 := lost(tgt)
		click(w)
		var rr = await watch(0.15)
		waves.append(rr.proj)
		per.append(snappedf(lost(tgt) - h0, 0.1))
	ok("dragoonpike Wyvern's Fang: the 2nd thrust throws a wave %s and only the 3rd reaches 66 px %s" % [waves, per], waves[1] >= 1 and waves[0] == 0 and per[2] > 1.0)
	# Dragonfire: a fourth lunge that burns
	var df := {}
	for t in [3, 4]:
		w = await equip("dragoonpike", t, false)
		var ds := []
		for off in [Vector2(60, 0), Vector2(60, 30), Vector2(60, -30), Vector2(90, 0)]:
			ds.append(dummy(P + off))
		w.use_ability()
		await wait(0.05)
		w.release_ability()
		await wait(1.6)
		var marked := 0
		for e in ds:
			if exposed_for(e) > 0.0:
				marked += 1
		var h1 := 0.0
		for e in ds:
			h1 += lost(e)
		await wait(1.0)
		var h2 := 0.0
		for e in ds:
			h2 += lost(e)
		df[t] = [marked, snappedf(h2 - h1, 0.1)]
	ok("dragoonpike Dragonfire: tier 4 lunges at four dummies and they burn %s; tier 3 three, no fire %s" % [df[4], df[3]], df[4][0] == 4 and df[3][0] == 3 and df[4][1] > df[3][1] + 1.0)
	# Dragonfire Vault: the landing cone burns what is ahead
	var vl := {}
	for t in [3, 4]:
		w = await equip("dragoonpike", t, false)
		var dd = dummy(P + Vector2(150, 0))
		w.use_dash()
		var rr = await watch(1.2)
		vl[t] = [snappedf(lost(dd), 0.1), rr.kinds.has("cone")]
	ok("dragoonpike Dragonfire Vault: tier 4 landing cone hurts a dummy 40 px ahead %s; tier 3 %s" % [vl[4], vl[3]], vl[4][1] and !vl[3][1] and vl[4][0] > vl[3][0] + 4.0)
	# Wyrm Chase: five lunges after the crash, back to the crash point
	var wc := {}
	for t in [4, 5]:
		w = await equip("dragoonpike", t, false)
		var crash: Vector2 = w.cursor_target(130.0)
		var ds := []
		for k in 5:
			ds.append(dummy(crash + Vector2.from_angle(float(k) * 1.26) * 60.0))
		w.use_ultimate()
		await wait(2.6)
		var tot := 0.0
		for e in ds:
			tot += lost(e)
		wc[t] = [snappedf(tot, 0.1), snappedf(player.global_position.distance_to(crash), 1.0)]
	ok("dragoonpike Wyrm Chase: tier 5 hits the pack harder %s than tier 4 %s and ends near the crash point" % [wc[5], wc[4]], wc[5][0] > wc[4][0] + 10.0 and wc[5][1] < 40.0)
	# Dragon Descent: the red comet, the sigil, the great crash with eight lances
	var dd6 := {}
	for t in [5, 6]:
		w = await equip("dragoonpike", t, false)
		var crash: Vector2 = w.cursor_target(130.0)
		var cen = dummy(crash + Vector2(20, 0))
		w.use_ultimate()
		var seen := {}
		var ids := {}
		var comet := false
		for i in 70:
			await wait(0.05)
			fx_kinds(seen)
			if has_fx("fall", 9.0):
				comet = true
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "lance":
					ids[nd.get_instance_id()] = true
		dd6[t] = [comet, ids.size(), seen.has("pillar"), snappedf(lost(cen), 0.1)]
	ok("dragoonpike Dragon Descent: tier 6 %s (comet, lances, pillar, damage) vs tier 5 %s" % [dd6[6], dd6[5]], dd6[6][0] and dd6[6][1] >= 8 and dd6[6][2] and dd6[5][1] == 0 and dd6[6][3] > dd6[5][3] + 7.0)
	# Roar: the 6th thrust
	var roar := {}
	for t in [5, 6]:
		w = await equip("dragoonpike", t, false)
		var saw := false
		for i in 6:
			click(w)
			await wait(0.08)
			if i == 5 and has_fx("cone", 70.0):
				saw = true
			await wait(0.4)
		roar[t] = saw
	ok("dragoonpike Roar: the 6th thrust roars at tier 6 %s, not at tier 5 %s" % [roar[6], roar[5]], roar[6] and !roar[5])
	await draw_smoke("dragoonpike")

func burn_hazards() -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("world/hazard.gd") and n.kind == "burn":
			c += 1
	return c

func t_magmamaul() -> void:
	var w
	# Heat: swings build it, it decays after 3 s without a gain
	w = await equip("magmamaul", 2, false)
	for i in 3:
		click(w)
		await wait(0.3)
	var h1: float = w._st.heat
	var aura_state: float = w._aura.state if w._aura != null else -1.0
	await wait(5.0)
	ok("magmamaul Heat gauge, tier 2 three swings give %.0f heat (aura state %.0f), after 5 idle seconds %.0f" % [h1, aura_state, w._st.heat], h1 >= 30.0 and aura_state >= 30.0 and w._st.heat < h1 - 8.0)
	# Heat Surge: the 3rd swing is a lava slap that reaches a dummy 44 px from the swing centre
	var hs := {}
	for t in [2, 3]:
		w = await equip("magmamaul", t, false)
		var dd = dummy(P + Vector2(62, 0))
		var per := []
		var seen := {}
		for i in 3:
			var h0 := lost(dd)
			click(w)
			for k in 8:
				await wait(0.05)
				fx_kinds(seen)
			per.append(snappedf(lost(dd) - h0, 0.1))
			await wait(0.6)
		hs[t] = [per, seen.has("shock")]
	ok("magmamaul Heat Surge: tier 3 slap reaches 38 px from the centre only on the 3rd %s with a shock; tier 2 %s" % [hs[3], hs[2]], hs[3][0][0] < 0.1 and hs[3][0][2] > 1.0 and hs[3][1] and hs[2][0][2] < 0.1 and !hs[2][1])
	# Molten: at 100 heat the swing is a full slam in r 44, the Magma Slam doubles, the state ends after 6 s
	w = await equip("magmamaul", 4, false)
	w._st.heat = 95.0
	click(w)
	await wait(0.1)
	var molten: bool = w._st.molten_until > Time.get_ticks_msec() / 1000.0
	await wait(0.9)
	var wide = dummy(P + Vector2(24 + 42, 0))
	click(w)
	await wait(0.6)
	var molten_hit := lost(wide)
	w._ability_cd = 0.0
	var seen := {}
	var c: Vector2 = w.cursor_target(100.0)
	var dd2 = dummy(c + w.aim.orthogonal() * 40.0)
	var dd3 = dummy(c - w.aim.orthogonal() * 40.0)
	w.use_ability()
	for i in 34:
		await wait(0.05)
		fx_kinds(seen)
	var second := lost(dd2) + lost(dd3)
	await wait(4.0)
	ok("magmamaul Molten: tier 4 goes molten at 100 heat %s, the swing hits r 44 (%.1f at 42 px from the centre), the slam strikes again at the side (%.1f), the state ends after 6 s %s" % [molten, molten_hit, second, !(w._st.molten_until > Time.get_ticks_msec() / 1000.0)], molten and molten_hit > 3.0 and second > 5.0 and !(w._st.molten_until > Time.get_ticks_msec() / 1000.0))
	# Meltdown: a geyser at every strike of the ring, and you end molten
	w = await equip("magmamaul", 5, false)
	var dm = dummy(P + Vector2(85, 0))
	w.use_ultimate()
	var seen2 := {}
	for i in 70:
		await wait(0.05)
		fx_kinds(seen2)
	ok("magmamaul Meltdown: tier 5 ring leaves geysers (%d pillar samples >= 12) and you end molten %s" % [seen2.get("pillar", 0), is_instance_valid(w) and w._st.molten_until > Time.get_ticks_msec() / 1000.0], seen2.get("pillar", 0) >= 12 and w._st.molten_until > Time.get_ticks_msec() / 1000.0)
	# Eruption Titan: eight seconds of bombs, then the eruption; no new burn patches beyond the old ring
	var burn := {}
	var tit := {}
	for t in [3, 6]:
		w = await equip("magmamaul", t, false)
		var cen = dummy(P + Vector2(30, 0))
		var rr = dummy(P + Vector2(60, 40))
		var peak := 0
		w.use_ultimate()
		var seen3 := {}
		var falls := 0
		var late := false
		for i in 240:
			await wait(0.05)
			var before: int = seen3.get("flash", 0)
			fx_kinds(seen3)
			peak = maxi(peak, burn_hazards())
			if has_fx("fall", 5.0):
				falls += 1
			if i > 190 and seen3.get("flash", 0) > before and has_fx("flash", 90.0):
				late = true
		burn[t] = peak
		tit[t] = [falls, late, snappedf(lost(cen), 0.1)]
	ok("magmamaul Eruption Titan: tier 6 bombs and a late eruption %s vs tier 3 %s; burn patches at once %d <= %d" % [tit[6], tit[3], burn[6], burn[3]], tit[6][0] >= 6 and tit[6][1] and tit[6][2] > tit[3][2] + 18.0 and burn[6] <= burn[3])
	await draw_smoke("magmamaul")

func t_spellblade() -> void:
	var w
	var mod = load("res://items/weapons/tiers/spellblade.gd")
	# Spirit blades: every second slash that hits conjures one (max 2 at tier 2); they cut what they touch
	w = await equip("spellblade", 2, false)
	var near = dummy(P + Vector2(17, 0))
	for i in 4:
		click(w)
		await wait(0.55)
	var sp: int = w._aura.data.get("sp", -1) if w._aura != null else -1
	var h0 := lost(near)
	await wait(2.0)
	ok("spellblade Spirit Blades: tier 2 four hitting slashes conjure %d blades (max %d), a dummy beside you takes %.1f from contact" % [sp, mod.spirit_max(w), lost(near) - h0], sp == 2 and mod.spirit_max(w) == 2 and lost(near) - h0 > 0.5)
	# Spellweave: the storm has six blades that the aura draws (n equals the storm's blade count)
	w = await equip("spellblade", 2, false)
	w.use_ability()
	await wait(0.3)
	var n_storm: int = w._aura.data.get("n", -1)
	ok("spellblade Spellweave: tier 2 storm has %d blades (6) and the aura says so (n %d); the old local drawing is gone" % [w.blades_now(), n_storm], w.blades_now() == 6 and n_storm == 6)
	# Sword Choir: the blades are thrown when the storm ends (tier 3), the cap is 3
	var choir := {}
	for t in [2, 3]:
		w = await equip("spellblade", t, false)
		w.use_ability()
		await wait(3.7)
		choir[t] = await proj_ids(1.0, "blade")
	ok("spellblade Sword Choir: tier 3 throws %d blades when the storm ends (tier 2 %d), the spirit cap is %d" % [choir[3], choir[2], mod.spirit_max(w)], choir[3] >= 6 and choir[2] == 0 and mod.spirit_max(w) == 3)
	# Phantom Edge: the 4th slash has a phantom swing and a chaining wave; the dash exposes 2.5 s
	var pe := {}
	for t in [3, 4]:
		w = await equip("spellblade", t, false)
		var a = dummy(P + Vector2(45, 0))
		var b = dummy(P + Vector2(45, 40))
		var seen := {}
		var gains := []
		for i in 4:
			var hb := lost(b)
			click(w)
			for k in 12:
				await wait(0.05)
				fx_kinds(seen)
			gains.append(snappedf(lost(b) - hb, 0.1))
			await wait(0.3)
		pe[t] = [gains, seen.get("slash", 0)]
	ok("spellblade Phantom Edge: tier 4 4th slash chains to the dummy off the line %s and shows a phantom slash (%d); tier 3 %s" % [pe[4][0], pe[4][1], pe[3]], pe[4][0][3] > 0.2 and pe[4][1] >= 1 and pe[3][0][3] < 0.05 and pe[3][1] == 0)
	w = await equip("spellblade", 4, false)
	var ex = dummy(P + Vector2(30, 0))
	w.use_dash()
	await wait(0.35)
	ok("spellblade Phantom Dash: tier 4 dash exposes for %.1f s (>= 1.8; the old dash gave 1.5 s)" % exposed_for(ex), exposed_for(ex) >= 1.8)
	# Blade Tempest: the cyclone after the 5 s and twelve blades at the end
	var bt := {}
	for t in [4, 5]:
		w = await equip("spellblade", t, false)
		var dd = dummy(P + Vector2(50, 0))
		w.use_ultimate()
		await wait(5.25)
		var h1 := lost(dd)
		var seen := {}
		var ids := {}
		for i in 50:
			await wait(0.05)
			fx_kinds(seen)
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "blade":
					ids[nd.get_instance_id()] = true
		bt[t] = [seen.has("vortex"), ids.size(), snappedf(lost(dd) - h1, 0.1)]
	ok("spellblade Blade Tempest: tier 5 cyclone, 12 blades and damage %s; tier 4 %s" % [bt[5], bt[4]], bt[5][0] and bt[5][1] >= 12 and bt[5][2] > bt[4][2] + 2.0 and !bt[4][0])
	# Sword Saint: the avatar for 10 s with big slashes, then the crash
	var ss := {}
	for t in [5, 6]:
		w = await equip("spellblade", t, false)
		var dd = dummy(P + Vector2(50, 0))
		w.use_ultimate()
		await wait(8.4)
		var avatar: int = w._aura.data.get("av", 0)
		click(w)
		await wait(0.08)
		var big := has_fx("slash", 60.0)
		await wait(8.5)
		var h1 := lost(dd)
		var late := false
		for i in 30:
			await wait(0.05)
			if has_fx("flash", 80.0):
				late = true
		var avatar_off: bool = w._aura.data.get("av", 0) == 0
		ss[t] = [avatar, big, late, avatar_off, snappedf(lost(dd) - h1, 0.1)]
	ok("spellblade Sword Saint: tier 6 avatar, big slash, final crash %s; tier 5 %s" % [ss[6], ss[5]], ss[6][0] == 1 and ss[6][1] and ss[6][2] and ss[6][3] and ss[6][4] > 10.0 and ss[5][0] == 0 and !ss[5][1] and !ss[5][2])
	await draw_smoke("spellblade")

func t_tempest() -> void:
	var w
	# Static: every link is a jagged bolt
	w = await equip("tempest", 2, false)
	var a = dummy(P + Vector2(40, 0))
	var b = dummy(P + Vector2(70, 0))
	click(w)
	var r = await watch(0.4)
	ok("tempest Static: tier 2 chain draws bolts %s and bursts %s; both dummies charged (%d, %d)" % [r.kinds.has("bolt"), r.kinds.has("burst"), a.get_meta("charge", 0), b.get_meta("charge", 0)], r.kinds.has("bolt") and r.kinds.has("burst") and a.get_meta("charge", 0) == 1 and b.get_meta("charge", 0) == 1)
	# charge motes for clients
	await wait(0.6)
	var seen_m := {}
	for i in 12:
		await wait(0.05)
		fx_kinds(seen_m)
	ok("tempest: charged enemies show motes (%s)" % [seen_m.keys()], seen_m.has("motes"))
	# Overcharge: the 5th charge overloads: two neighbours take damage, the charge drops to 2
	var oc := {}
	for t in [2, 3]:
		w = await equip("tempest", t, false)
		var c0 = dummy(P + Vector2(50, 0))
		var n1 = dummy(P + Vector2(100, 0))
		var n2 = dummy(P + Vector2(50, 50))
		c0.set_meta("charge", 4)
		w._charge(c0, 1)
		await wait(0.4)
		oc[t] = [c0.get_meta("charge", 0), snappedf(lost(n1) + lost(n2), 0.1)]
	ok("tempest Overcharge: tier 3 overloads (charge %s, neighbours lose %s); tier 2 stays at 5 %s" % [oc[3][0], oc[3][1], oc[2]], oc[3][0] == 2 and oc[3][1] > 1.0 and oc[2][0] == 5 and oc[2][1] < 0.1)
	# Overcharge splash: Thunderclap also hits the neighbours of every detonation
	var sp := {}
	for t in [2, 3]:
		w = await equip("tempest", t, false)
		var c0 = dummy(P + Vector2(50, 0))
		var nb = dummy(P + Vector2(75, 0))
		c0.set_meta("charge", 3)
		w.use_ability()
		await wait(0.4)
		sp[t] = snappedf(lost(nb), 0.1)
	ok("tempest Overcharge splash: tier 3 clap hurts the neighbour at 25 px (%.1f), tier 2 not (%.1f)" % [sp[3], sp[2]], sp[3] > 1.0 and sp[2] < 0.1)
	# Ball Lightning: the 4th attack launches a ball that zaps
	var bl := {}
	for t in [3, 4]:
		w = await equip("tempest", t, false)
		var dd = dummy(P + Vector2(50, 12))
		var seen := {}
		var most := 0
		for i in 4:
			click(w)
			for k in 4:
				await wait(0.05)
				for nd in world.get_children():
					if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/projectile.gd") and nd.style == "orb" and nd.size >= 1.5:
						most += 1
			await wait(0.4)
		await wait(1.0)
		bl[t] = [most > 0, snappedf(lost(dd), 0.1)]
	ok("tempest Ball Lightning: tier 4 launches an orb on the 4th attack %s; tier 3 %s" % [bl[4], bl[3]], bl[4][0] and !bl[3][0] and bl[4][1] > bl[3][1] + 1.0)
	# Ball Lightning Dash: the dash drops a ball behind you that zaps
	var bd := {}
	for t in [3, 4]:
		w = await equip("tempest", t, false)
		var dd = dummy(P + Vector2(12, 12))
		w.use_dash()
		await wait(2.4)
		bd[t] = snappedf(lost(dd), 0.1)
	ok("tempest Ball Lightning Dash: tier 4 ball zaps a dummy at the start (%.1f vs tier 3 %.1f)" % [bd[4], bd[3]], bd[4] > bd[3] + 1.0)
	# Thunderhead: strikes on charged dummies for 6 s
	var th := {}
	for t in [4, 5]:
		w = await equip("tempest", t, false)
		var dd = dummy(P + Vector2(60, 0))
		w.use_ultimate()
		await wait(1.0)
		var h1 := lost(dd)
		var kinds := {}
		for i in 100:
			await wait(0.05)
			fx_kinds(kinds)
		th[t] = [snappedf(lost(dd) - h1, 0.1), kinds.get("bolt", 0)]
	ok("tempest Thunderhead: tier 5 strikes the charged dummy %s; tier 4 %s" % [th[5], th[4]], th[5][0] > th[4][0] + 6.0 and th[5][1] >= 6)
	# Stormlord: cooldown capped at 1.0 s for 8 s, mega-clap at ~14.5 s
	var sl := {}
	for t in [5, 6]:
		w = await equip("tempest", t, false)
		var dd = dummy(P + Vector2(60, 0))
		var far = dummy(P + Vector2(150, 0))
		far.set_meta("charge", 5)
		w.use_ultimate()
		await wait(7.0)
		w._ability_cd = 6.0
		await wait(0.1)
		var capped: bool = w._ability_cd <= 1.0
		await wait(6.7)
		far.set_meta("charge", 5)
		await wait(0.6)
		var h1 := lost(far)
		var flash := false
		var seen := {}
		for i in 30:
			await wait(0.05)
			fx_kinds(seen)
			if has_fx("flash", 90.0):
				flash = true
		sl[t] = [capped, flash, snappedf(lost(far) - h1, 0.1)]
	ok("tempest Stormlord: tier 6 cooldown capped %s, mega-clap flash %s, detonation %s; tier 5 %s" % [sl[6][0], sl[6][1], sl[6][2], sl[5]], sl[6][0] and sl[6][1] and !sl[5][0] and !sl[5][1])
	# Finisher: the 6th attack forks to five targets
	var fin := {}
	for t in [5, 6]:
		w = await equip("tempest", t, false)
		var ds := []
		for k in 6:
			ds.append(dummy(P + Vector2(45 + 10 * k, -25 + 10 * k)))
		var forks := 0
		for i in 6:
			click(w)
			await wait(0.1)
			if i == 5:
				var kinds := {}
				await wait(0.0)
				for nd in world.get_children():
					if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("items/weapons/fx.gd") and nd.kind == "bolt":
						forks += 1
			await wait(0.4)
		fin[t] = forks
	ok("tempest Finisher: the 6th attack forks (%d bolts alive) at tier 6, %d at tier 5" % [fin[6], fin[5]], fin[6] >= fin[5] + 3)
	await draw_smoke("tempest")

func run() -> void:
	if want("rimelance"):
		await t_rimelance()
	if want("sultanguard"):
		await t_sultanguard()
	if want("dragoonpike"):
		await t_dragoonpike()
	if want("magmamaul"):
		await t_magmamaul()
	if want("spellblade"):
		await t_spellblade()
	if want("tempest"):
		await t_tempest()
