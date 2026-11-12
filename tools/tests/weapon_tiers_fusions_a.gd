extends "res://tools/tests/wt_base.gd"
## Fused weapons, first batch (docs/weapon_tiers): chainfangs, rapier, bulwark, knightblade, lance, quakepick.
## Each tier's own upgrade, kept by the next, absent from the one before.   Run all: --script res://tools/tests/weapon_tiers_fusions_a.gd
## One weapon:  ... -- only=chainfangs
func click(w) -> void:
	w._attack_cd = 0.0
	w.use_item()

func ready_all(w) -> void:
	w._ability_cd = 0.0
	w._dash_cd = 0.0
	w._ult_cd = 0.0

func exposed_for(e) -> float:
	if !is_instance_valid(e) or !e.has_meta("exposed_until"):
		return 0.0
	return e.get_meta("exposed_until") - Time.get_ticks_msec() / 1000.0

func want(id: String) -> bool:
	return only == "" or only == id

func t_chainfangs() -> void:
	var w
	# Barbed Chain: the grapple exposes 3 s and bleeds; the target is tethered
	w = await equip("chainfangs", 2)
	var d = dummy(P + Vector2(70, 0))
	w.use_ability()
	var r = await watch(0.35)
	var ex := exposed_for(d)
	var h0 := lost(d)
	await wait(1.5)
	ok("chainfangs Barbed Chain: tier 2 grapple exposes %.1f s (>= 2.5), bleeds %.2f after the hit, flash+line seen %s" % [ex, lost(d) - h0, r.kinds.keys()], ex >= 2.5 and lost(d) - h0 > 0.2 and r.kinds.has("flash"))
	# Reel: the 6th swing (3rd pair) yanks the neighbour of the target (a static dummy keeps its knock timer, so the pull shows there)
	var moved := []
	w = await equip("chainfangs", 3)
	var a0 = dummy(P + Vector2(24, 0))
	var b0 = dummy(P + Vector2(24, 52))
	for i in 6:
		b0.knock_time = 0.0
		b0.slow_time = 0.0
		click(w)
		await wait(0.12)
		moved.append([snappedf(b0.knock_time, 0.01), snappedf(b0.slow_time, 0.01)])
		await wait(0.3)
	ok("chainfangs Reel: only the 6th swing pulls and slows the neighbour %s" % [moved], moved[5][0] > 0.05 and moved[5][1] > 0.5 and moved[1][0] <= 0.0 and moved[3][0] <= 0.0 and moved[4][0] <= 0.0)
	# Chain Lightning: the tether jumps A -> B -> C at tier 4, only to A at tier 3
	var res := {}
	for t in [3, 4]:
		w = await equip("chainfangs", t)
		var a = dummy(P + Vector2(70, 0))
		var b = dummy(P + Vector2(70, 40))
		var c = dummy(P + Vector2(70, 80))
		w.use_ability()
		await wait(0.8)
		res[t] = [exposed_for(b) > 0.5, exposed_for(c) > 0.5, lost(b), lost(c)]
	ok("chainfangs Chain Lightning: tier 4 jumps to B and C %s, tier 3 does not %s" % [res[4], res[3]], res[4][0] and res[4][1] and !res[3][0] and !res[3][1])
	# Chain Lash: a dummy 25 px off the dash path is reeled in
	var lash := {}
	for t in [3, 4]:
		w = await equip("chainfangs", t)
		var a = dummy(P + Vector2(28, 25), HP, true)
		var p0: Vector2 = a.global_position
		w.use_dash()
		var rr = await watch(0.9)
		lash[t] = [snappedf(a.global_position.distance_to(p0), 0.1), rr.kinds.has("streak")]
	ok("chainfangs Chain Lash: tier 4 reels a dummy off the path %s and draws a streak; tier 3 %s" % [lash[4], lash[3]], lash[4][1] and lash[4][0] > lash[3][0] + 8.0)
	# Dragnet: tier 5 pulls and exposes the pack around the final position; tier 4 not
	var net := {}
	for t in [4, 5]:
		w = await equip("chainfangs", t)
		var ds := []
		for off in [Vector2(80, 0), Vector2(90, 40), Vector2(90, -40)]:
			ds.append(dummy(P + off, HP, true))
		w.use_ultimate()
		var rr = await watch(2.4)
		var ex2 := 0
		for e in ds:
			if exposed_for(e) > 1.0:
				ex2 += 1
		net[t] = [ex2, rr.kinds.has("vortex")]
	ok("chainfangs Dragnet: tier 5 vortex + exposed %s, tier 4 %s" % [net[5], net[4]], net[5][1] and net[5][0] >= 2 and !net[4][1])
	# Execution: the finale executes a nearly dead exposed dummy (not a boss stand-in)
	w = await equip("chainfangs", 6)
	var weak = dummy(P + Vector2(60, 0), 100.0)
	weak.health = 15.0
	var strong = dummy(P + Vector2(-60, 0))
	strong.add_to_group("boss")
	strong.health = strong.max_health * 0.1
	w.use_ultimate()
	var rf = await watch(3.2)
	ok("chainfangs Execution: tier 6 finale shock seen %s, the weak dummy is gone %s, the boss stand-in lives %s" % [rf.kinds.has("shock"), !is_instance_valid(weak) or weak.health <= 0, is_instance_valid(strong)], rf.kinds.has("shock") and (!is_instance_valid(weak) or weak.health <= 0) and is_instance_valid(strong))
	await draw_smoke("chainfangs")

func run() -> void:
	if want("chainfangs"):
		await t_chainfangs()
