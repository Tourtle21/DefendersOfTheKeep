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

func run() -> void:
	if only == "" or only == "dawnbringer":
		await t_dawnbringer()
