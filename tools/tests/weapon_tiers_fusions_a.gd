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

## Is a WeaponFx of this kind (and radius) alive right now.
func has_fx(kind: String, radius := -1.0) -> bool:
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/fx.gd") and n.kind == kind and (radius < 0.0 or is_equal_approx(n.radius, radius)):
			return true
	return false

func t_rapier() -> void:
	var w
	# Flicker: Fleche marks the target and the 3rd stab of a chain is a double
	w = await equip("rapier", 2)
	var d = dummy(P + Vector2(70, 0))
	var per := []
	var kinds := {}
	for i in 3:
		w._ability_cd = 0.0
		var h0 := lost(d)
		w.use_ability()
		for k in 5:
			await wait(0.05)
			fx_kinds(kinds)
		per.append(lost(d) - h0)
		if i == 0:
			per.append(exposed_for(d))
		await wait(0.1)
	ok("rapier Flicker: tier 2 stab 3 is a double (%s) and the target is marked (%.1f s), streak %s" % [per, per[1], kinds.has("streak")], per[3] > per[0] * 1.3 and per[1] > 1.0 and kinds.has("streak"))
	# Rhythm: the 2nd thrust throws a wave from tier 3
	var wave := {}
	for t in [2, 3]:
		w = await equip("rapier", t, false)
		var dd = dummy(P + Vector2(70, 0))
		click(w)
		await wait(0.1)
		click(w)
		var r = await watch(0.5)
		wave[t] = [r.proj, lost(dd)]
	ok("rapier Rhythm: tier 3 throws a wave after the 2nd thrust %s, tier 2 none %s" % [wave[3], wave[2]], wave[3][0] >= 1 and wave[2][0] == 0 and wave[3][1] > 0.1)
	# Afterimage: the phantom stabs again 0.6 s later; the evade phantom thrusts 0.5 s later
	var after := {}
	for t in [3, 4]:
		w = await equip("rapier", t, false)
		var dd = dummy(P + Vector2(70, 0))
		w.use_ability()
		await wait(0.35)
		var h1 := lost(dd)
		await wait(0.5)
		var fl := lost(dd) - h1
		w = await equip("rapier", t, false)
		var ev = dummy(P + Vector2(30, 0))
		w.use_dash()
		await wait(0.3)
		var h2 := lost(ev)
		await wait(0.5)
		after[t] = [snappedf(fl, 0.01), snappedf(lost(ev) - h2, 0.01)]
	ok("rapier Afterimage: tier 4 Fleche phantom %s and Evade phantom thrust %s; tier 3 %s" % [after[4][0], after[4][1], after[3]], after[4][0] > 1.5 and after[4][1] > 1.0 and after[3][0] < 0.1 and after[3][1] < 0.1)
	# Dance: the thousand stabs slide forward with flurry cones from tier 5; Final Lunge adds a 110 px lunge at tier 6
	var dance := {}
	for t in [4, 5, 6]:
		w = await equip("rapier", t)
		var dd = dummy(P + Vector2(60, 0))
		w.use_ultimate()
		var seen := {}
		var x0: float = player.global_position.x
		var xm := 0.0
		for i in 40:
			await wait(0.05)
			fx_kinds(seen)
			if i == 19:
				xm = player.global_position.x
		await wait(0.3)
		dance[t] = [snappedf(xm - x0, 1.0), snappedf(player.global_position.x - xm, 1.0), seen.has("cone"), seen.has("shock"), snappedf(lost(dd), 0.1)]
	ok("rapier Dance: tier 5 slides %s and has cones; tier 4 stays %s" % [dance[5], dance[4]], dance[5][0] > 40.0 and dance[5][2] and absf(dance[4][0]) < 20.0 and !dance[4][2])
	ok("rapier Final Lunge: tier 6 lunges %s (>= 70 px after the stabs) with a shock, tier 5 does not %s" % [dance[6], dance[5]], dance[6][1] >= 70.0 and dance[6][3] and absf(dance[5][1]) < 15.0 and !dance[5][3] and dance[6][4] > dance[5][4])
	# Finisher: every 6th thrust pierces through (a cut r 18 appears)
	var fin := {}
	for t in [5, 6]:
		w = await equip("rapier", t)
		var dd = dummy(P + Vector2(30, 0))
		var saw := false
		for i in 6:
			click(w)
			await wait(0.05)
			if i == 5 and has_fx("cut", 18.0):
				saw = true
			await wait(0.3)
		fin[t] = saw
	ok("rapier Finisher: the 6th thrust pierces through at tier 6 %s, not at tier 5 %s" % [fin[6], fin[5]], fin[6] and !fin[5])
	await draw_smoke("rapier")

func t_bulwark() -> void:
	var w
	# Counterweight: a blow absorbed while braced shoves the attacker and pops a star
	w = await equip("bulwark", 2, false)
	var d = dummy(P + Vector2(14, 0))
	w.use_ability()
	await wait(0.1)
	d.knock_time = 0.0
	player.take_damage(d.global_position, 10.0)
	var r = await watch(0.4)
	ok("bulwark Counterweight: tier 2 absorbed blow shoves the attacker (knock %.2f) and pops a star %s; stored %d" % [d.knock_time, r.kinds.has("star"), w._stored], r.kinds.has("star") and w._stored == 1)
	w.release_ability()
	# Fortress Slam: the 3rd maul reaches a dummy at 46 px (outside the 32 arc); a braced click is a bash and extends the brace
	var hits := []
	w = await equip("bulwark", 3, false)
	var far = dummy(P + Vector2(46, 0))
	for i in 3:
		var h0 := lost(far)
		click(w)
		await wait(0.5)
		hits.append(lost(far) - h0)
		await wait(0.5)
	w = await equip("bulwark", 3, false)
	var near = dummy(P + Vector2(18, 0))
	w.use_ability()
	await wait(0.1)
	var secs0: float = w.brace_secs
	click(w)
	await wait(0.2)
	var bash: float = lost(near)
	ok("bulwark Fortress Slam: only the 3rd maul reaches 46 px %s; a braced click bashes (%.1f) and extends the brace %.1f -> %.1f" % [hits, bash, secs0, w.brace_secs], hits[0] < 0.1 and hits[1] < 0.1 and hits[2] > 1.0 and bash > 0.5 and w.brace_secs > secs0)
	w.release_ability()
	# Overpressure: 5 stored charges fire a cone beyond the release ring; Bulldozer slams at the end of the dash
	var cone := {}
	for t in [3, 4]:
		w = await equip("bulwark", t, false)
		var dd = dummy(P + Vector2(86, 0))
		w.use_ability()
		await wait(0.1)
		w._stored = 5
		w.release_ability()
		await wait(0.5)
		cone[t] = lost(dd)
	ok("bulwark Overpressure: tier 4 cone hits a dummy at 86 px (%.1f), tier 3 does not (%.1f)" % [cone[4], cone[3]], cone[4] > 5.0 and cone[3] < 0.1)
	var dz := {}
	for t in [3, 4]:
		w = await equip("bulwark", t, false)
		var dd = dummy(P + Vector2(55, 0))
		w.use_dash()
		var rr = await watch(0.9)
		dz[t] = [rr.kinds.has("shock"), snappedf(lost(dd), 0.1)]
	ok("bulwark Bulldozer: tier 4 dash slams with a shock %s and hits harder than tier 3 %s" % [dz[4], dz[3]], dz[4][0] and !dz[3][0] and dz[4][1] > dz[3][1] + 4.0)
	# Citadel Pulse: tier 5 throws shard rings and eats enemy shots; tier 4 does neither
	var cit := {}
	for t in [4, 5]:
		w = await equip("bulwark", t, false)
		var dd = dummy(P + Vector2(80, 0))
		var shot = load("res://enemies/spitter/enemy_projectile.gd").new()
		shot.position = P + Vector2(30, 0)
		shot.damage = 0.0
		shot.life = 99.0
		world.add_child(shot)
		w.use_ultimate()
		var ids := {}
		for i in 80:
			await wait(0.05)
			for n in world.get_children():
				if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/projectile.gd"):
					ids[n.get_instance_id()] = true
		cit[t] = [ids.size(), is_instance_valid(shot) and !shot.is_queued_for_deletion(), snappedf(lost(dd), 0.1)]
		if is_instance_valid(shot):
			shot.queue_free()
	ok("bulwark Citadel Pulse: tier 5 shard rings %s (>= 12) and the shot is eaten; tier 4 %s" % [cit[5], cit[4]], cit[5][0] >= 12 and !cit[5][1] and cit[4][0] == 0 and cit[4][1])
	# Titan's Judgment: the great slam when the fortress ends
	var ti := {}
	for t in [5, 6]:
		w = await equip("bulwark", t, false)
		var dd = dummy(P + Vector2(70, 0))
		w.use_ultimate()
		var seen := {}
		for i in 96:
			await wait(0.05)
			fx_kinds(seen)
		ti[t] = [snappedf(lost(dd), 0.1), seen.has("flash"), seen.has("sigil")]
	ok("bulwark Titan's Judgment: tier 6 flash + extra damage %s vs tier 5 %s" % [ti[6], ti[5]], ti[6][1] and !ti[5][1] and ti[6][0] > ti[5][0] + 10.0)
	# Finisher: the 6th maul rings twice (a shock r 52)
	var fin := {}
	for t in [5, 6]:
		w = await equip("bulwark", t, false)
		var saw := false
		for i in 6:
			click(w)
			await wait(0.5)
			if i == 5 and has_fx("shock", 52.0):
				saw = true
			await wait(0.3)
		fin[t] = saw
	ok("bulwark Finisher: the 6th maul rings twice at tier 6 %s, not at tier 5 %s" % [fin[6], fin[5]], fin[6] and !fin[5])
	await draw_smoke("bulwark")

func t_knightblade() -> void:
	var w
	# Oathkeeper: a successful riposte shields and shoves what stands round the attacker; a whiff costs 3.5 s
	w = await equip("knightblade", 2, false)
	var att = dummy(P + Vector2(30, 0))
	var nb = dummy(P + Vector2(30, 28))
	w.use_ability()
	await wait(0.1)
	player.take_damage(att.global_position, 10.0)
	var r = await watch(0.35)
	ok("knightblade Oathkeeper: tier 2 riposte shields %.2f s (>= 0.2), shoves the neighbour (knock %.2f) and pops a star %s" % [player.shield_time, nb.knock_time, r.kinds.has("star")], player.shield_time > 0.2 and nb.knock_time > 0.0 and r.kinds.has("star"))
	w = await equip("knightblade", 2, false)
	w.use_ability()
	await wait(0.85)
	ok("knightblade Oathkeeper: a whiffed riposte costs 3.5 s instead of 4.5 (cooldown %.2f)" % w._ability_cd, w._ability_cd > 3.1 and w._ability_cd <= 3.5)
	# Crescent Third: the third strike throws a crescent that reaches a dummy at 80 px
	var cres := {}
	for t in [2, 3]:
		w = await equip("knightblade", t, false)
		var dd = dummy(P + Vector2(80, 0))
		var peak := []
		for i in 3:
			click(w)
			var rr = await watch(0.3)
			peak.append(rr.proj)
			await wait(0.1)
		cres[t] = [peak, snappedf(lost(dd), 0.1)]
	ok("knightblade Crescent Third: tier 3 throws a crescent on the 3rd strike only %s and reaches 80 px; tier 2 %s" % [cres[3], cres[2]], cres[3][0][0] == 0 and cres[3][0][1] == 0 and cres[3][0][2] >= 1 and cres[3][1] > 0.5 and cres[2][1] < 0.1)
	# Counter-Thrust: the counter slash after the riposte; Vanguard Dash makes the next two strikes big
	var ct := {}
	for t in [3, 4]:
		w = await equip("knightblade", t, false)
		var at2 = dummy(P + Vector2(40, 0))
		var near2 = dummy(P + Vector2(82, 20))
		w.use_ability()
		await wait(0.1)
		player.take_damage(at2.global_position, 10.0)
		var rr = await watch(0.9)
		ct[t] = [snappedf(lost(near2), 0.1), snappedf(exposed_for(at2), 0.1), rr.kinds.has("slash")]
	ok("knightblade Counter-Thrust: tier 4 counter slash hurts the dummy at the arrival %s; tier 3 %s" % [ct[4], ct[3]], ct[4][0] > ct[3][0] + 3.0 and ct[4][1] > 1.5)
	var bigs := {}
	for t in [3, 4]:
		w = await equip("knightblade", t, false)
		w.use_dash()
		await wait(0.5)
		var seq := []
		for i in 3:
			click(w)
			await wait(0.1)
			seq.append(w._st.get("big", false))
			await wait(0.35)
		bigs[t] = seq
	ok("knightblade Vanguard Dash: tier 4 makes the next two strikes big %s; tier 3 only one %s" % [bigs[4], bigs[3]], bigs[4][0] and bigs[4][1] and !bigs[4][2] and bigs[3][0] and !bigs[3][1])
	# Knight's Vow: arcs in three directions and swords circle you
	var vow := {}
	for t in [4, 5]:
		w = await equip("knightblade", t, false)
		var dd = dummy(P + Vector2(40, 0))
		w.use_ultimate()
		var seen := {}
		var cones := 0
		for i in 70:
			await wait(0.05)
			fx_kinds(seen)
		vow[t] = [snappedf(lost(dd), 0.1), seen.get("cone", 0) > 0, seen.get("orbit", 0) > 0]
	ok("knightblade Vow: tier 5 has cones and the swords cut more %s than tier 4 %s" % [vow[5], vow[4]], vow[5][1] and vow[5][2] and !vow[4][1] and vow[5][0] > vow[4][0] + 2.0)
	# Judgment Day: the falling sword
	var jd := {}
	for t in [5, 6]:
		w = await equip("knightblade", t, false)
		var dd = dummy(P + Vector2(60, 0))
		w.use_ultimate()
		var seen := {}
		for i in 60:
			await wait(0.05)
			fx_kinds(seen)
		jd[t] = [snappedf(lost(dd), 0.1), seen.has("fall"), seen.has("flash")]
	ok("knightblade Judgment Day: tier 6 sword falls and flashes %s; tier 5 not %s" % [jd[6], jd[5]], jd[6][1] and jd[6][2] and !jd[5][1] and jd[6][0] > jd[5][0] + 6.0)
	# Finisher: the 9th strike raises a pillar and strikes down again
	var fin := {}
	for t in [5, 6]:
		w = await equip("knightblade", t, false)
		var dd = dummy(P + Vector2(30, 0))
		var saw := false
		for i in 9:
			click(w)
			await wait(0.1)
			if i == 8 and has_fx("pillar"):
				saw = true
			await wait(0.3)
		fin[t] = saw
	ok("knightblade Judgment Day finisher: the 9th strike raises a pillar at tier 6 %s, not at tier 5 %s" % [fin[6], fin[5]], fin[6] and !fin[5])
	await draw_smoke("knightblade")

func t_lance() -> void:
	var w
	# Shock Cone: the ram ends in a cone that hits what is 40 px beyond the end point (outside the ring)
	w = await equip("lance", 2, false)
	var d = dummy(P + Vector2(100, 0))
	w.use_ability()
	await wait(0.05)
	w.release_ability()
	var r = await watch(0.7)
	ok("lance Shock Cone: tier 2 ram cone hits a dummy 40 px beyond the end (%.1f), cone %s, shock %s" % [lost(d), r.kinds.has("cone"), r.kinds.has("shock")], lost(d) > 1.5 and r.kinds.has("cone") and r.kinds.has("shock"))
	# Long Lance: the 3rd Impale reaches 66 px
	var lens := {}
	for t in [2, 3]:
		w = await equip("lance", t, false)
		var dd = dummy(P + Vector2(66, 0))
		var per := []
		for i in 3:
			var h0 := lost(dd)
			click(w)
			await wait(0.3)
			per.append(snappedf(lost(dd) - h0, 0.1))
			await wait(0.3)
		lens[t] = per
	ok("lance Long Lance: tier 3 reaches 66 px only on the 3rd %s; tier 2 never %s" % [lens[3], lens[2]], lens[3][0] < 0.1 and lens[3][1] < 0.1 and lens[3][2] > 1.0 and lens[2][2] < 0.1)
	# Spikefall: three spikes round the landing
	var sp := {}
	for t in [3, 4]:
		w = await equip("lance", t, false)
		var land := P + Vector2(70, 0)
		var ds := []
		for k in 3:
			ds.append(dummy(land + Vector2.from_angle(float(k) * TAU / 3.0) * 15.0))
		w.use_dash()
		var rr = await watch(0.9)
		var tot := 0.0
		for e in ds:
			tot += lost(e)
		sp[t] = [snappedf(tot, 0.1), rr.kinds.get("crack", 0)]
	ok("lance Spikefall: tier 4 spikes add damage and cracks %s over tier 3 %s" % [sp[4], sp[3]], sp[4][0] > sp[3][0] + 3.0 and sp[4][1] >= 3 and sp[3][1] == 0)
	# Reverb: two rings after the crash hit a dummy 60 px beyond it
	var rev := {}
	for t in [4, 5]:
		w = await equip("lance", t, false)
		var crash: Vector2 = w.cursor_target(130.0)
		var dd = dummy(crash + Vector2(60, 0))
		w.use_ultimate()
		var steps := []
		for k in 3:
			await wait(0.5 if k < 2 else 0.45)
			steps.append(snappedf(lost(dd), 0.1))
		rev[t] = steps
	ok("lance Reverb: tier 5 hurts a dummy 60 px past the crash in steps %s; tier 4 not %s" % [rev[5], rev[4]], rev[5][0] < 0.1 and rev[5][1] > 0.5 and rev[5][2] > rev[5][1] + 0.5 and rev[4][2] < 0.1)
	# Dive Bomb: comet, flash, pillar, shock, six lances, a long stun
	var db := {}
	for t in [5, 6]:
		w = await equip("lance", t, false)
		var dd = dummy(P + Vector2(120, 0))
		w.use_ultimate()
		var seen := {}
		var ids := {}
		for i in 14:
			await wait(0.05)
			fx_kinds(seen)
			for n in world.get_children():
				if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/projectile.gd") and n.style == "lance":
					ids[n.get_instance_id()] = true
		db[t] = [seen.has("fall"), seen.has("flash"), seen.has("pillar"), ids.size(), snappedf(dd.slow_time, 0.1)]
	ok("lance Dive Bomb: tier 6 %s (fall, flash, pillar, lances, stun) vs tier 5 %s" % [db[6], db[5]], db[6][0] and db[6][1] and db[6][2] and db[6][3] >= 6 and db[6][4] >= 1.7 and !db[5][0] and db[5][3] == 0)
	# Finisher: the 6th Impale adds a cone
	var fin := {}
	for t in [5, 6]:
		w = await equip("lance", t, false)
		var dd = dummy(P + Vector2(30, 0))
		var saw := false
		for i in 6:
			click(w)
			await wait(0.08)
			if i == 5 and has_fx("cone"):
				saw = true
			await wait(0.3)
		fin[t] = saw
	ok("lance Finisher: the 6th Impale adds a cone at tier 6 %s, not tier 5 %s" % [fin[6], fin[5]], fin[6] and !fin[5])
	# the charge still scales the ram at tier 6
	w = await equip("lance", 6, false)
	w.use_ability()
	await wait(1.1)
	var x0: float = player.global_position.x
	w.release_ability()
	await wait(0.6)
	ok("lance: a full charge at tier 6 rams %.0f px (>= 120)" % (player.global_position.x - x0), player.global_position.x - x0 >= 120.0)
	await draw_smoke("lance")

func hazards(kind: String) -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("world/hazard.gd") and n.kind == kind:
			c += 1
	return c

func t_quakepick() -> void:
	var w
	# Branching Fissure: the 2nd eruption forks to either side
	w = await equip("quakepick", 2, false)
	var side = dummy(P + Vector2(40, 26))
	var out = dummy(P + Vector2(40, 62))
	w.use_ability()
	var r = await watch(1.2)
	ok("quakepick Branching Fissure: tier 2 fork hurts a dummy 26 px to the side (%.1f) and not one 62 px out (%.1f); crack %s" % [lost(side), lost(out), r.kinds.has("crack")], lost(side) > 0.5 and lost(out) < 0.1 and r.kinds.has("crack"))
	# Rock Spike: the 3rd swing raises a spike 40 px ahead
	var rs := {}
	for t in [2, 3]:
		w = await equip("quakepick", t, false)
		var dd = dummy(P + Vector2(44, 0))
		var per := []
		for i in 3:
			var h0 := lost(dd)
			click(w)
			await wait(0.9)
			per.append(snappedf(lost(dd) - h0, 0.1))
		rs[t] = per
	ok("quakepick Rock Spike: tier 3 spike hurts 44 px ahead only on the 3rd swing %s; tier 2 %s" % [rs[3], rs[2]], rs[3][0] < 0.1 and rs[3][1] < 0.1 and rs[3][2] > 1.0 and rs[2][2] < 0.1)
	# Tunnel: eruptions burst along the path behind you
	var tun := {}
	for t in [3, 4]:
		w = await equip("quakepick", t, false)
		var a = dummy(P + Vector2(22, 0))
		var b = dummy(P + Vector2(34, 0))
		w.use_dash()
		var rr = await watch(0.9)
		tun[t] = [snappedf(lost(a), 0.1), snappedf(lost(b), 0.1), rr.kinds.has("streak")]
	ok("quakepick Tunnel: tier 4 eruptions along the path hurt both dummies %s; tier 3 %s" % [tun[4], tun[3]], tun[4][0] > 1.0 and tun[4][1] > 1.0 and tun[4][2] and tun[3][0] < 0.1 and tun[3][1] < 0.1)
	# Chasm: the centre collapses (pull, slow patch)
	var ch := {}
	for t in [4, 5]:
		w = await equip("quakepick", t, false)
		var dd = dummy(P + Vector2(60, 0))
		w.use_ultimate()
		await wait(1.35)
		dd.knock_time = 0.0
		await wait(0.15)
		var pulled: bool = dd.knock_time > 0.0
		await wait(0.3)
		ch[t] = [pulled, hazards("slow")]
	ok("quakepick Chasm: tier 5 pulls and leaves a slow patch %s; tier 4 neither %s" % [ch[5], ch[4]], ch[5][0] and ch[5][1] >= 1 and !ch[4][0] and ch[4][1] == 0)
	# Cataclysm Prime: four pillars, the ring of cracks, the centre blast
	var fin := {}
	for t in [5, 6]:
		w = await equip("quakepick", t, false)
		var dd = dummy(P + Vector2(5, 0))
		w.use_ultimate()
		var seen := {}
		var most := 0
		for i in 80:
			await wait(0.05)
			fx_kinds(seen)
			var c := 0
			for n in world.get_children():
				if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/fx.gd") and n.kind == "pillar":
					c += 1
			most = maxi(most, c)
		fin[t] = [most, seen.has("shock"), snappedf(lost(dd), 0.1)]
	ok("quakepick Cataclysm Prime: tier 6 %s (pillars at once, shock, centre damage) vs tier 5 %s" % [fin[6], fin[5]], fin[6][0] >= 4 and fin[6][1] and fin[5][0] == 0 and fin[6][2] > fin[5][2] + 4.0)
	# Finisher: three spikes on the 6th swing
	var f6 := {}
	for t in [5, 6]:
		w = await equip("quakepick", t, false)
		var saw := false
		for i in 6:
			click(w)
			await wait(0.3)
			if i == 5 and has_fx("crack", 16.0):
				saw = true
			await wait(0.5)
		f6[t] = saw
	ok("quakepick Finisher: the 6th swing raises three spikes at tier 6 %s, not at tier 5 %s" % [f6[6], f6[5]], f6[6] and !f6[5])
	await draw_smoke("quakepick")

func run() -> void:
	if want("chainfangs"):
		await t_chainfangs()
	if want("rapier"):
		await t_rapier()
	if want("bulwark"):
		await t_bulwark()
	if want("knightblade"):
		await t_knightblade()
	if want("lance"):
		await t_lance()
	if want("quakepick"):
		await t_quakepick()
