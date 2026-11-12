extends "res://tools/tests/wt_base.gd"
## The three named legendaries (docs/weapon_tiers): Dawnbringer, Voidreaver, Mindbender. Each tier's own upgrade, kept by the next, absent from the one before.
## `-- only=<id>` runs one weapon. (The pad cursor is always 70 px from the player along aim_dir, see face().)
func face(d: Vector2) -> void:
	await wait(0.1)
	var pad = root.get_node("Pad")
	pad.using_pad = true
	pad.aim_dir = d.normalized()
	await wait(0.2)
func aura_node():
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("weapon_aura.gd"):
			return n
	return null
func hazards() -> int:
	return count_script("hazard.gd")
func health_px() -> float:
	return world.get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x
func set_health(px: float) -> void:
	world.get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x = px
func young(max_age := 0.15) -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n._age < max_age:
			c += 1
	return c
func fx_list(kind: String) -> Array:
	var out := []
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/fx.gd") and n.kind == kind:
			out.append(n)
	return out
func slash(w) -> void:
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.12)

func t_dawnbringer() -> void:
	var w
	var mod = load("res://items/weapons/tiers/dawnbringer.gd")
	# First Light (tier 2): the third slash throws a ray, Daybreak makes rays and a heal patch
	var fl := {}
	for t in [1, 2]:
		w = await equip("dawnbringer", t, false)
		var seen := {}
		for i in 3:
			await slash(w)
			fx_kinds(seen)
			await wait(0.3)
		dummy(P + Vector2(80, 0))
		w.use_ability()
		var beams := 0
		for i in 60:
			await wait(0.05)
			beams = maxi(beams, fx_list("beam").size())
			fx_kinds(seen)
		fl[t] = {"beam": beams, "motes": seen.has("motes"), "haz": hazards()}
	ok("dawnbringer First Light: tier 2 slash motes %s, Daybreak rays %d beams and a heal patch (%d); tier 1: %s, %d, %d" % [fl[2].motes, fl[2].beam, fl[2].haz, fl[1].motes, fl[1].beam, fl[1].haz], fl[2].motes and fl[2].beam >= 3 and fl[2].haz >= 1 and !fl[1].motes and fl[1].haz == 0)
	w = await equip("dawnbringer", 2, false)
	var burn = dummy(P + Vector2(80, 0))
	var burn_d = dummy(P + Vector2(60, 30))
	w.use_ability()
	await wait(3.3)
	ok("dawnbringer First Light: the turning rays burn a dummy near them (%.1f, %.1f)" % [lost(burn), lost(burn_d)], lost(burn) > 0.0 or lost(burn_d) > 0.0)
	# Halo (tier 3): three suns that burn, the third slash a crescent wave, Daybreak lasts 14 s
	w = await equip("dawnbringer", 3, false)
	await wait(0.3)
	var an = aura_node()
	var suns: int = int(an.data.get("suns", 0))
	var sd = dummy(P + Vector2(28, 0))
	var steps := 0
	var last := 0.0
	for i in 50:
		await wait(0.05)
		if lost(sd) > last + 0.05:
			steps += 1
			last = lost(sd)
	var wave := 0
	for i in 3:
		await slash(w)
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.style == "crescent" and n.size == 2.0:
				wave += 1
		await wait(0.3)
	w.use_ability()
	await wait(0.2)
	var lasts: float = float(w._st.day.until) - float(w._st.day.t0)
	ok("dawnbringer Halo: %d suns, the dummy at 28 px was burned %d times, a crescent wave on slash 3 (%d seen), Daybreak lasts %.0f s" % [suns, steps, wave, lasts], suns == 3 and steps >= 2 and wave >= 1 and lasts >= 13.5)
	# Sunrise (tier 4): a triple fan on the third slash, pillars on the dash, a kill of a dummy gives +6 radiance and heals 1
	w = await equip("dawnbringer", 4, false)
	var fan := 0
	for i in 3:
		w._attack_cd = 0.0
		w.use_item()
		await wait(0.1)
		if i == 2:
			for n in world.get_children():
				if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.style == "crescent" and n._age < 0.15:
					fan += 1
		await wait(0.35)
	w = await equip("dawnbringer", 4, false)
	await face(Vector2(1, 0))
	w.use_dash()
	var seen4 := {}
	for i in 12:
		await wait(0.05)
		fx_kinds(seen4)
	w = await equip("dawnbringer", 4, false)
	var lowhp = dummy(P + Vector2(30, 0), 3.0)
	lowhp.max_health = 3.0
	lowhp.health = 3.0
	set_health(100.0)
	var r0: float = mod.rad(w)
	await slash(w)
	await wait(0.6)
	ok("dawnbringer Sunrise: %d crescents on slash 3, the dash raised pillars (%s), the kill gave radiance %.0f -> %.0f and healed %.1f px" % [fan, seen4.has("pillar"), r0, mod.rad(w), health_px() - 100.0], fan == 3 and seen4.has("pillar") and mod.rad(w) - r0 >= 7.0 and health_px() - 100.0 >= 0.9)
	# High Noon (tier 5): the noon beam 1 s after Daybreak, a noon sun striking from above after the judgment
	w = await equip("dawnbringer", 5, false)
	var tall := false
	w.use_ability()
	for i in 30:
		await wait(0.05)
		for p in fx_list("pillar"):
			if p.height == 160.0:
				tall = true
	await clear()
	for i in 6:
		dummy(P + Vector2(60 + i * 12, -25 + i * 10))
	w.use_ultimate()
	var ids := {}
	for i in 200:
		await wait(0.05)
		for b in fx_list("beam"):
			if b.dir.y > 0.9 and b.width == 6.0 and b.length >= 100.0:
				ids[b.get_instance_id()] = true
	ok("dawnbringer High Noon: the noon pillar (height 160) %s, %d sunbeam strikes from the noon sun" % [tall, ids.size()], tall and ids.size() >= 8)
	# Dawn of Days (tier 6): one slow-motion beat, radiance locked, five sunrise columns, the Dawn
	w = await equip("dawnbringer", 6, false)
	await face(Vector2(1, 0))
	var dd = dummy(P + Vector2(100, 0))
	set_health(100.0)
	var minhp := 100.0
	w.use_ultimate()
	var slow_runs := 0
	var run_len := 0
	var locked_ok := true
	var cols := {}
	var biggest := 0.0
	var prev := 0.0
	var flash150 := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await wait(0.05)
		if Engine.time_scale < 0.5:
			run_len += 1
		else:
			if run_len >= 4:
				slow_runs += 1
			run_len = 0
		for p in fx_list("pillar"):
			if p.height == 220.0:
				cols[p.get_instance_id()] = true
		for f in fx_list("flash"):
			if f.radius == 150.0:
				flash150 = true
		minhp = minf(minhp, health_px())
		var l := lost(dd)
		biggest = maxf(biggest, l - prev)
		prev = l
		if w._st.locked and mod.rad(w) < 99.0:
			locked_ok = false
		if flash150 and Time.get_ticks_msec() - t0 > 27000:
			break
	var pw: float = game.weapon_power("dawnbringer", 5)
	var hh: float = game.basic_hit("dawnbringer")
	ok("dawnbringer Dawn of Days: one slow-motion beat (%d), radiance locked %s, %d sunrise column pillars, the Dawn flashed %s, biggest hit %.1f = %.1f H (>= 3.0 H)" % [slow_runs, locked_ok, cols.size(), flash150, biggest, biggest / (hh * pw)], slow_runs == 1 and locked_ok and cols.size() >= 25 and flash150 and biggest >= 3.0 * hh * pw * 0.95)
	ok("dawnbringer: no effect ever hurt the player (health %.1f px never below the 100 it started at, final %.1f)" % [minhp, health_px()], minhp >= 99.9)
	await clear()
	await draw_smoke("dawnbringer")

func t_voidreaver() -> void:
	var w
	var mod = load("res://items/weapons/tiers/voidreaver.gd")
	# Hunger (tier 2): a heal for what is cut, a slash, the rift collapses twice
	w = await equip("voidreaver", 2, false)
	dummy(P + Vector2(30, 0))
	dummy(P + Vector2(30, 12))
	set_health(100.0)
	var seen := {}
	await slash(w)
	fx_kinds(seen)
	await wait(0.2)
	var healed: float = health_px() - 100.0
	ok("voidreaver Hunger: a swing across two dummies heals %.2f (>= the old min(3, 2) = 2, <= 4), slash fx %s" % [healed, seen.has("slash")], healed >= 1.99 and healed <= 4.01 and seen.has("slash"))
	var steps := {}
	for t in [2]:
		w = await equip("voidreaver", t, false)
		var held = dummy(P + Vector2(70, 0))
		w.use_ability()
		var last := 0.0
		var n := 0
		for i in 50:
			await wait(0.05)
			if lost(held) > last + 0.3:
				n += 1
				last = lost(held)
		steps[t] = n
	ok("voidreaver Hunger Rift: the held dummy took %d separate blows (pull, collapse, second collapse)" % steps[2], steps[2] >= 3)
	# Gravity (tier 3): the third swing pulls; the rift keeps pulling for 3 s
	var gv := {}
	for t in [2, 3]:
		w = await equip("voidreaver", t, false)
		var pd = dummy(P + Vector2(60, 0), HP, true)
		var x0: float = pd.global_position.x
		var minx := x0
		for i in 3:
			await slash(w)
			await wait(0.5)
			minx = minf(minx, pd.global_position.x)
		gv[t] = x0 - minx
	ok("voidreaver Gravity: the dummy at 60 px was pulled %.0f px by three swings (tier 2: %.0f)" % [gv[3], gv[2]], gv[3] > gv[2] + 12.0)
	var wl := {}
	for t in [2, 3]:
		w = await equip("voidreaver", t, false)
		var wd = dummy(P + Vector2(70 + 50, 0), HP, true)
		w.use_ability()
		await wait(2.6)
		wl[t] = wd.global_position.distance_to(P + Vector2(70, 0))
	ok("voidreaver Gravity Well: the dummy ends %.0f px from the rift at tier 3 (tier 2: %.0f)" % [wl[3], wl[2]], wl[3] < wl[2] - 8.0)
	# Singularity (tier 4): a hole after the collapse; a kill with a swing opens a micro hole
	w = await equip("voidreaver", 4, false)
	dummy(P + Vector2(70, 0))
	w.use_ability()
	await wait(2.2)
	var holes: int = aura_node().data.get("holes", []).size()
	w = await equip("voidreaver", 4, false)
	var frail = dummy(P + Vector2(30, 0), 3.0)
	frail.max_health = 3.0
	frail.health = 3.0
	await slash(w)
	await wait(0.5)
	var micro := 0
	for h in w._st.holes:
		if h.kind == "micro":
			micro += 1
	ok("voidreaver Singularity: the rift left %d hole in the aura, a kill with a swing opened %d micro hole" % [holes, micro], holes >= 1 and micro == 1)
	# Black Sun (tier 5): eclipse at full essence; the ultimate holds the crowd
	w = await equip("voidreaver", 5, false)
	var ed = dummy(P + Vector2(40, 0), HP, true)
	mod.add_ess(w, 100.0)
	var ecl: bool = mod.eclipse(w)
	var seen5 := {}
	await slash(w)
	fx_kinds(seen5)
	var pulled: bool = ed.knock_time > 0.0 or ed.global_position.x < P.x + 40.0
	ok("voidreaver Black Sun: full essence starts eclipse (%s), the swing is a wider slash and pulls (%s)" % [ecl, pulled], ecl and seen5.has("slash") and pulled)
	var hold := {}
	for t in [4, 5]:
		w = await equip("voidreaver", t, false)
		var hd = dummy(P + Vector2(50, 0))
		w.use_ultimate()
		var low := 1.0
		for i in 130:
			await wait(0.05)
			if i * 0.05 > 3.3:
				low = minf(low, hd.slow_mult)
		hold[t] = low
	ok("voidreaver Black Sun: the dark disc holds the dummy (slow %.2f at tier 5, %.2f at tier 4)" % [hold[5], hold[4]], hold[5] <= 0.11 and hold[4] > 0.5)
	# Oblivion (tier 6): the finisher erases the weak; the transformation
	w = await equip("voidreaver", 6, false)
	var weak = dummy(P + Vector2(30, 0))
	weak.max_health = HP
	weak.health = HP * 0.14
	for i in 6:
		await slash(w)
		await wait(0.3)
	await wait(0.3)
	ok("voidreaver Oblivion: the sixth swing erases a dummy below 15%% health (%s)" % [!is_instance_valid(weak) or weak.health <= 0.0 or weak.is_queued_for_deletion()], !is_instance_valid(weak) or weak.health <= 0.0 or weak.is_queued_for_deletion())
	w = await equip("voidreaver", 6, false)
	await face(Vector2(1, 0))
	var od = dummy(P + Vector2(100, 0))
	set_health(100.0)
	w.use_ultimate()
	var slow_runs := 0
	var run_len := 0
	var orbit_seen := 0
	var flash140 := false
	var biggest := 0.0
	var prev := 0.0
	var peak := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await wait(0.05)
		if Engine.time_scale < 0.5:
			run_len += 1
		else:
			if run_len >= 4:
				slow_runs += 1
			run_len = 0
		var an = aura_node()
		if an != null:
			var ks: Array = an.data.get("kinds", [])
			orbit_seen = maxi(orbit_seen, ks.count(1))
		for f in fx_list("flash"):
			if f.radius == 140.0:
				flash140 = true
		peak = maxi(peak, fx_count())
		var l := lost(od)
		biggest = maxf(biggest, l - prev)
		prev = l
		if flash140 and Time.get_ticks_msec() - t0 > 14000:
			await wait(0.6)
			break
	var pw: float = game.weapon_power("voidreaver", 5)
	var hh: float = game.basic_hit("voidreaver")
	ok("voidreaver Oblivion: one slow-motion beat (%d), %d orbiting singularities, the final flash %s, biggest hit %.1f = %.1f H (>= 3.0), healed %.1f px, peak fx %d" % [slow_runs, orbit_seen, flash140, biggest, biggest / (hh * pw), health_px() - 100.0, peak], slow_runs == 1 and orbit_seen == 3 and flash140 and biggest >= 3.0 * hh * pw * 0.95 and health_px() - 100.0 >= 15.0 and peak <= 120)
	await clear()
	await draw_smoke("voidreaver")

func bolt_at(w) -> void:
	w._attack_cd = 0.0
	w.use_item()
	await wait(0.45)

func t_mindbender() -> void:
	var w
	var mod = load("res://items/weapons/tiers/mindbender.gd")
	# Thralls (tier 2): three bolts convert; tier 1 never; Turncoat heals the convert to full
	var th := {}
	for t in [1, 2]:
		w = await equip("mindbender", t, false)
		var d1 = dummy(P + Vector2(60, 0))
		for i in 3:
			await bolt_at(w)
		th[t] = {"ct": d1.charm_time, "pw": d1.charm_power}
	ok("mindbender Thralls: three bolts convert at tier 2 (%.1f s, power %.1f), never at tier 1 (%.1f)" % [th[2].ct, th[2].pw, th[1].ct], th[2].ct > 3.0 and th[2].pw >= 1.3 and th[1].ct <= 0.0)
	w = await equip("mindbender", 2, false)
	var hurt = dummy(P + Vector2(40, 0))
	hurt.health = 100.0
	w.use_ability()
	await wait(0.8)
	ok("mindbender Thralls: Turncoat converts and heals to full (%.0f of %.0f, power %.1f)" % [hurt.health, hurt.max_health, hurt.charm_power], hurt.charm_time > 0.0 and hurt.health >= hurt.max_health and hurt.charm_power >= 1.3)
	# Banner (tier 3)
	var bn := {}
	for t in [2, 3]:
		w = await equip("mindbender", t, false)
		await face(Vector2(1, 0))
		var d3 = dummy(P + Vector2(70, 0))
		w.use_ability()
		await wait(0.9)
		bn[t] = d3.rally_point
	ok("mindbender Banner: tier 3 sets the convert's rally point (%s vs %s)" % [bn[3], bn[2]], bn[3] != Vector2.INF and bn[2] == Vector2.INF)
	# Puppeteer (tier 4): chain, command, gate
	w = await equip("mindbender", 4, false)
	var c1 = dummy(P + Vector2(60, 0))
	var c2 = dummy(P + Vector2(60, 40))
	await bolt_at(w)
	ok("mindbender Puppeteer: the bolt chains to a second dummy (%.1f taken)" % lost(c2), lost(c2) > 0.0)
	w = await equip("mindbender", 4, false)
	await face(Vector2(1, 0))
	var army1 = dummy(P + Vector2(50, 0))
	w.use_ability()
	await wait(0.9)
	w.use_ability()
	await wait(0.2)
	ok("mindbender Puppeteer: the second right click surges the army (power %.1f, rally %s)" % [army1.charm_power, army1.rally_point], army1.charm_power >= 2.0 and army1.rally_point != Vector2.INF)
	w = await equip("mindbender", 4, false)
	await face(Vector2(1, 0))
	var passer = dummy(P + Vector2(0, 8))
	w.use_dash()
	await wait(0.4)
	ok("mindbender Puppeteer Step: the dash leaves a gate that converts what passes (%.1f s, aura gates %d)" % [passer.charm_time, aura_node().data.get("gates", []).size()], passer.charm_time > 3.0 and aura_node().data.get("gates", []).size() == 1)
	# Lieutenants (tier 5)
	w = await equip("mindbender", 5, false)
	await face(Vector2(1, 0))
	var ds := []
	for i in 5:
		var dd = dummy(P + Vector2(50 + i * 4, -20 + i * 10), 100.0 * (i + 1))
		dd.max_health = 100.0 * (i + 1)
		dd.health = dd.max_health
		ds.append(dd)
	w.use_ability()
	await wait(1.4)
	var big := 0
	for dd in ds:
		if dd.charm_power >= 2.5:
			big += 1
	ok("mindbender Lieutenants: the three toughest were promoted (%d, powers %s)" % [big, ds.map(func(x): return x.charm_power)], big == 3 and ds[4].charm_power == 2.5 and ds[0].charm_power < 2.0)
	w = await equip("mindbender", 5, false)
	await face(Vector2(1, 0))
	var conv_d = dummy(P + Vector2(70, 0))
	var other = dummy(P + Vector2(70, 50))
	w.use_ultimate()
	await wait(3.2)
	ok("mindbender Lieutenants: the ultimate spreads to a dummy 50 px from a convert (%.1f s)" % other.charm_time, other.charm_time > 0.0)
	# Sovereign (tier 6)
	w = await equip("mindbender", 6, false)
	await face(Vector2(1, 0))
	var near = dummy(P + Vector2(60, 0))
	var foe = dummy(P + Vector2(60, 120))
	var boss = dummy(P + Vector2(50, 30))
	boss.add_to_group("boss")
	set_health(100.0)
	w.use_ultimate()
	var slow_runs := 0
	var run_len := 0
	var guards := 0
	var seen_bolt := {}
	var peak := 0
	var flash_rose := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await wait(0.05)
		if Engine.time_scale < 0.5:
			run_len += 1
		else:
			if run_len >= 4:
				slow_runs += 1
			run_len = 0
		guards = maxi(guards, w.get_tree().get_nodes_in_group("guard").size())
		for b in fx_list("bolt"):
			seen_bolt[b.get_instance_id()] = true
		for f in fx_list("flash"):
			if f.radius == 30.0:
				flash_rose = true
		peak = maxi(peak, w.get_tree().get_nodes_in_group("ally").size())
		if flash_rose:
			break
	ok("mindbender Sovereign: one slow-motion beat (%d), %d guards, %d thought-storm bolts, rebellion flash %s, boss never converted (%s), army peak %d <= 40" % [slow_runs, guards, seen_bolt.size(), flash_rose, boss.charm_time <= 0.0, peak], slow_runs == 1 and guards >= 5 and seen_bolt.size() >= 8 and flash_rose and boss.charm_time <= 0.0 and peak <= 40)
	for g in w.get_tree().get_nodes_in_group("guard"):
		g.queue_free()
	await clear()
	await draw_smoke("mindbender")

func run() -> void:
	if only == "" or only == "mindbender":
		await t_mindbender()
	if only == "" or only == "voidreaver":
		await t_voidreaver()
	if only == "" or only == "dawnbringer":
		await t_dawnbringer()
