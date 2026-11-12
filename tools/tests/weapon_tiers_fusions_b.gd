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

func run() -> void:
	if want("rimelance"):
		await t_rimelance()
