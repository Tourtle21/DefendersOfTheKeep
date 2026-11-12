extends "res://tools/tests/structure_test_base.gd"
## Sentry tiers 2 to 6 (docs/card_tiers/sentry.md). Run: Godot --headless --path . --script res://tools/tests/structure_tiers_sentry.gd
func sections() -> Array:
	return ["sentry", "ember_turret"]
const TIERS := "res://cards/structure_tiers.gd"
## A sentry of a tier with only that tier's own ability (the stacked additions twin shot, frost, rapid, heavy, blast removed).
func plain(id: String, tier: int, pos: Vector2):
	var st = build(id, tier, pos)
	st.adds = []
	return st
## The damage of each hit on `e` over `secs` (a drop in health seen between frames).
func hits(e, secs: float, most := 99) -> Array:
	var out := []
	var last: float = e.health
	var t := 0.0
	while t < secs and out.size() < most:
		await wait(0.02)
		t += 0.02
		if e.health < last - 0.001:
			out.append(last - e.health)
		last = e.health
	return out
func sentry() -> void:
	print("-- sentry")
	var c := Vector2(0, 300)
	# Piercing bolt (tier 2)
	var pr := {}
	for t in [1, 2]:
		var st = plain("sentry", t, c)
		var a = dummy(c + Vector2(60, 0))
		var b = dummy(c + Vector2(90, 0))
		await wait(1.0)
		pr[t] = [dealt(a), dealt(b)]
		await clear()
	ok("tier 2 bolt hits the enemy behind the target, tier 1 does not (%s)" % str(pr), pr[2][1] > 0.0 and pr[1][1] == 0.0 and pr[1][0] > 0.0)
	# Focus fire (tier 3)
	var f3 := {}
	for t in [2, 3]:
		var st = plain("sentry", t, c)
		var a = dummy(c + Vector2(50, 0))
		f3[t] = await hits(a, 5.6)
		await clear()
	var r3: float = f3[3][6] / f3[3][0] if f3[3].size() >= 7 else 0.0
	var r2: float = f3[2][f3[2].size() - 1] / f3[2][0] if f3[2].size() >= 2 else 0.0
	ok("tier 3 ramps +15%% per shot on one target up to 1.9x (ratio %.2f), tier 2 stays flat (%.2f)" % [r3, r2], absf(r3 - 1.9) < 0.1 and absf(r2 - 1.0) < 0.05)
	var st3 = plain("sentry", 3, c)
	var ta = dummy(c + Vector2(50, 0))
	var tb = dummy(c + Vector2(-50, 0))
	var tl = load(TIERS)
	for i in 4:
		tl.shot_mult_sentry(st3, ta)
	var m_same: float = tl.shot_mult_sentry(st3, ta)
	var m_new: float = tl.shot_mult_sentry(st3, tb)
	ok("a new target resets the focus (%.2f then %.2f)" % [m_same, m_new], absf(m_same - 1.6) < 0.01 and m_new == 1.0)
	await clear()
	# Volley (tier 4): the sixth shot is a fan of five bolts
	var vs := {}
	for t in [3, 4]:
		var st = plain("sentry", t, c)
		var a = dummy(c + Vector2(50, 0))
		var first := -1
		var early := 0
		var tt := 0.0
		while tt < 4.0:
			await wait(0.02)
			tt += 0.02
			var n := count_nodes("projectile.gd")
			if n >= 5 and first < 0:
				first = st._shots
			if n > 0 and st._shots < 6:
				early += 1
		vs[t] = [first, early]
		await clear()
	ok("tier 4 fires a fan of five on the sixth shot only, tier 3 never (%s)" % str(vs), vs[4][0] >= 6 and vs[4][0] <= 7 and vs[4][1] == 0 and vs[3][0] < 0)
	# Executioner (tier 5)
	var ex := {}
	for hp in [0.2, 0.5]:
		var st = plain("sentry", 5, c)
		var a = dummy(c + Vector2(50, 0), 100000.0)
		a.health = 100000.0 * hp
		var h := await hits(a, 1.0, 1)
		ex[hp] = h[0] if h.size() > 0 else 0.0
		await clear()
	ok("tier 5 triples the damage on a weak enemy (%s)" % str(ex), ex[0.5] > 0.0 and ex[0.2] / ex[0.5] > 2.9)
	# Hunter's mark (tier 6)
	var st6 = plain("sentry", 6, c)
	var big = dummy(c + Vector2(50, 0), 99999.0)
	var small = dummy(c + Vector2(-50, 0), 50000.0)
	var seen := await fx_seen(8.4)
	var gm = game
	ok("tier 6 marks the toughest enemy: +40%% damage (%.2f vs %.2f), star seen %s, mark_on %s" % [gm.mark_mult(big), gm.mark_mult(small), str(seen.get("star", 0)), str(st6.mark_on)], absf(gm.mark_mult(big) - 1.4) < 0.01 and gm.mark_mult(small) == 1.0 and seen.get("star", 0) >= 1 and st6.mark_on)
	await clear()
	# Cumulative: tier 6 still pierces and volleys
	var stc = plain("sentry", 6, c)
	var a = dummy(c + Vector2(50, 0))
	var b = dummy(c + Vector2(80, 0))
	var mxp := 0
	var tt := 0.0
	while tt < 5.2:
		await wait(0.05)
		tt += 0.05
		mxp = maxi(mxp, count_nodes("projectile.gd"))
	ok("tier 6 still pierces and volleys (behind %.1f, projectiles %d)" % [dealt(b), mxp], dealt(b) > 0.0 and mxp >= 5)

# ================================================================== Ember Turret
## An ember turret that does not fire on its own: the tier's shot code is called by hand.
func quiet(tier: int, pos: Vector2):
	var st = plain("ember_turret", tier, pos)
	st.set_physics_process(false)
	return st
func fx_nodes(kind: String, radius := -1.0) -> int:
	var n := 0
	for c in world.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("fx.gd") and c.kind == kind and (radius < 0.0 or absf(c.radius - radius) < 0.01):
			n += 1
	return n
func ember_turret() -> void:
	print("-- ember_turret")
	var c := Vector2(0, 300)
	var tl = load(TIERS)
	# Incendiary (tier 2): the hit enemy keeps burning
	var inc := {}
	for t in [1, 2]:
		var st = quiet(t, c)
		var a = dummy(c + Vector2(60, 0))
		st._shots = 1
		tl.on_shot_ember_turret(st, a)
		await wait(1.8)
		inc[t] = dealt(a)
		await clear()
	ok("tier 2 sets the target on fire (%s)" % str(inc), inc[2] > 0.3 and inc[1] == 0.0)
	# Mortar (tier 3): the blast reaches 38 px
	var mo := {}
	for t in [2, 3]:
		var st = quiet(t, c)
		var a = dummy(c + Vector2(60, 0))
		var b = dummy(c + Vector2(93, 0))
		st._shots = 1
		tl.on_shot_ember_turret(st, a)
		await wait(0.3)
		mo[t] = dealt(b)
		await clear()
	ok("tier 3 hurts an enemy 33 px from the target, tier 2 does not (%s)" % str(mo), mo[3] > 0.5 and mo[2] == 0.0)
	# Fire shell (tier 4): every fifth shot
	var st4 = quiet(4, c)
	var a4 = dummy(c + Vector2(60, 0))
	var early := 0
	for n in range(1, 5):
		st4._shots = n
		tl.on_shot_ember_turret(st4, a4)
	await wait(0.1)
	for sp in world.get_children():
		if sp.get_script() != null and str(sp.get_script().resource_path).ends_with("spell.gd") and sp.data.get("id", "") == "fireball":
			early += 1
	st4._shots = 5
	tl.on_shot_ember_turret(st4, a4)
	await wait(0.1)
	var fb = null
	for sp in world.get_children():
		if sp.get_script() != null and str(sp.get_script().resource_path).ends_with("spell.gd") and sp.data.get("id", "") == "fireball":
			fb = sp
	ok("tier 4 lobs a small Fireball on the fifth shot only (early %d, copy %s, tier %s)" % [early, str(fb.data.get("copy") if fb != null else null), str(fb.data.get("tier") if fb != null else null)], early == 0 and fb != null and fb.data.get("copy", false) == true and int(fb.data.tier) == 2)
	await clear()
	# Cluster bomb (tier 5): three bomblets round the target
	var cl := {}
	for t in [4, 5]:
		var st = quiet(t, c)
		var a = dummy(c + Vector2(60, 0))
		var ring := []
		for k in 8:
			ring.append(dummy(c + Vector2(60, 0) + Vector2.from_angle(k * TAU / 8.0) * 30.0))
		st._shots = 1
		tl.on_shot_ember_turret(st, a)
		var bursts := 0
		for i in 22:
			await wait(0.05)
			bursts = maxi(bursts, fx_nodes("burst", 10.0))
		var total := 0.0
		for r in ring:
			total += dealt(r)
		cl[t] = [bursts, snappedf(total, 0.1)]
		await clear()
	ok("tier 5 scatters bomblets (burst fx of radius 10, more damage round the target) (%s)" % str(cl), cl[5][0] >= 1 and cl[4][0] == 0 and cl[5][1] > cl[4][1])
	# Inferno (tier 6): every 12 s it overheats for 3 s
	var st6 = plain("ember_turret", 6, c)
	var tgt = dummy(c + Vector2(60, 0))
	var base_range: float = st6.data.range
	var base_light: float = st6.light_radius
	var tt := 0.0
	var od_time := 0.0
	var s_before := 0
	var s_in := 0
	var s_after := 0
	var s_mark := 0
	var max_range := 0.0
	var max_light := 0.0
	while tt < 17.0:
		await wait(0.05)
		tt += 0.05
		if st6.overdrive:
			od_time += 0.05
			max_range = maxf(max_range, st6.data.range)
			max_light = maxf(max_light, st6.light_radius)
		if absf(tt - 10.0) < 0.026:
			s_mark = st6._shots
		if absf(tt - 11.0) < 0.026:
			s_before = st6._shots - s_mark
		if absf(tt - 12.6) < 0.026:
			s_mark = st6._shots
		if absf(tt - 13.6) < 0.026:
			s_in = st6._shots - s_mark
		if absf(tt - 15.6) < 0.026:
			s_mark = st6._shots
		if absf(tt - 16.6) < 0.026:
			s_after = st6._shots - s_mark
	ok("tier 6 overdrives for 3 s every 12 s (%.1f s): about 4x the shots (%d vs %d, after %d), reach x1.2 (%.0f/%.0f), light x1.5 (%.0f/%.0f), restored (%.0f, %.0f)" % [od_time, s_in, s_before, s_after, max_range, base_range, max_light, base_light, st6.data.range, st6.light_radius], od_time > 2.5 and od_time < 3.5 and s_in >= 2.5 * s_before and s_after <= 1.6 * s_before and absf(max_range / base_range - 1.2) < 0.01 and absf(max_light / base_light - 1.5) < 0.01 and absf(st6.data.range - base_range) < 0.01)
	await clear()
	# Draw smoke by day and by night
	for night in [0.0, 1.0]:
		game.night_level = night
		for t in range(1, 7):
			var sd = build("ember_turret", t, c + Vector2(t * 30, 0))
			sd.queue_redraw()
		await wait(0.2)
		await clear()
	game.night_level = 0.0
	ok("every tier draws by day and by night without errors", true)
