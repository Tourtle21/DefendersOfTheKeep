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

func run() -> void:
	if want("rimelance"):
		await t_rimelance()
	if want("sultanguard"):
		await t_sultanguard()
