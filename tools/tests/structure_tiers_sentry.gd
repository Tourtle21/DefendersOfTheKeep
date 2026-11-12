extends "res://tools/tests/structure_test_base.gd"
## Sentry tiers 2 to 6 (docs/card_tiers/sentry.md). Run: Godot --headless --path . --script res://tools/tests/structure_tiers_sentry.gd
func sections() -> Array:
	return ["sentry"]
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
