extends SceneTree
## Spell and building tiers 2 to 6: each tier looks different and adds an ability, and keeps what the lower tiers had.
## One section per card (docs/card_tiers/<card id>.md says what to check). Run: Godot --headless --path . --script res://tools/tests/tier_abilities.gd
var game
var world
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
## A still target: it takes hits and keeps its health (damage dealt = 99999 - health).
func dummy(pos: Vector2, hp := 99999.0):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.health = hp
	e.set_physics_process(false)
	return e
func dealt(e) -> float:
	return 99999.0 - e.health
## Cast a spell card at a tier on `pos`. `plain` drops its stacked additions so only the tier's own ability is measured.
func spell(id: String, tier: int, pos: Vector2, plain := true, extra := {}):
	var d: Dictionary = game.stats_of(game.make_entry(id, tier, game.twist_for(id, tier)))
	if plain:
		d.adds = []
		d.twist = ""
	for k in extra:
		d[k] = extra[k]
	var s = load("res://cards/spell.gd").new()
	s.setup(d, pos, pos)
	world.add_child(s)
	return s
func clear() -> void:
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("spell.gd"):
			n.queue_free()
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.2)
## The kinds of one-shot effect that appear during `secs` (and how many of each, by distinct node).
func fx_seen(secs: float, only_life := -1.0) -> Dictionary:
	var seen := {}
	var out := {}
	var t := 0.0
	while t < secs:
		await wait(0.05)
		t += 0.05
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx.gd") and !seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				if only_life < 0.0 or absf(n.life - only_life) < 0.001:
					out[n.kind] = int(out.get(n.kind, 0)) + 1
	return out
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://ct_test_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 700)
	var only := ""                                       # `-- only=frost_ring` runs one card's section
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for id in ["fireball", "frost_ring", "flare", "rejuvenation"]:
		if only == "" or only == id:
			await call(id)
			await clear()
	quit()

# ================================================================== Fireball
func fireball() -> void:
	print("-- fireball")
	var c := Vector2(0, 300)
	# Concussion (tier 2): the blast shoves enemies away from the centre
	var kn := {}
	for t in [1, 2]:
		var e = dummy(c + Vector2(20, 0))
		spell("fireball", t, c)
		await wait(0.45)
		kn[t] = e.knock_vel.length()
		await clear()
	ok("tier 2 shoves enemies off the centre, tier 1 does not (%s)" % str(kn), kn[2] > 100.0 and kn[1] == 0.0)
	# Bullseye (tier 3): the middle takes double damage
	var bs := {}
	for t in [2, 3]:
		var mid = dummy(c + Vector2(5, 0))
		var edge = dummy(c + Vector2(0, 36))
		spell("fireball", t, c)
		await wait(0.45)
		bs[t] = [dealt(mid), dealt(edge)]
		await clear()
	ok("tier 3 hits the core for double, tier 2 does not (%s)" % str(bs), bs[3][0] >= bs[3][1] * 1.9 and absf(bs[2][0] - bs[2][1]) < 0.01)
	# Kindling (tier 4): a kill pops and singes its neighbour
	var kd := {}
	for t in [3, 4]:
		var a = dummy(c + Vector2(36, 0), 3.0)             # (outside the double-damage core, next to its neighbour)
		var b = dummy(c + Vector2(56, 0))
		var s = spell("fireball", t, c)
		var d: float = s.data.damage
		await wait(0.45)
		kd[t] = dealt(b) / d
		await clear()
	ok("tier 4 pops a killed enemy onto its neighbour: blast plus 45%% (damage ratios %s)" % str(kd), absf(kd[3] - 1.0) < 0.01 and absf(kd[4] - 1.45) < 0.02)
	# Pillar (tier 5): the spot keeps burning in pulses; tier 4 has none
	var pl := {}
	for t in [4, 5]:
		var e = dummy(c + Vector2(0, 30))
		var s = spell("fireball", t, c)
		await wait(0.65)
		var early := dealt(e)
		await wait(1.3)
		pl[t] = [snappedf(dealt(e) - early, 0.01), s.effect_time if is_instance_valid(s) else 1.6]
		await clear()
	ok("tier 5 keeps burning for 1.6 s with pulses, tier 4 does not (%s)" % str(pl), pl[5][0] > 0.0 and pl[5][1] >= 1.6 and pl[4][0] == 0.0)
	# Finale (tier 6): flash, ripple and a ring of meteors; a copy skips it
	var fin := {}
	for cp in [false, true]:
		spell("fireball", 6, c, true, {"copy": cp})
		fin[cp] = await fx_seen(1.8)
	ok("tier 6 ends with a ripple and meteor strikes, a copy does not (%s)" % str(fin), fin[false].has("ripple") and fin[false].get("ring", 0) >= 6 and !fin[true].has("ripple") and fin[true].get("ring", 0) < fin[false].get("ring", 0))
	await clear()
	var fx := {}
	for t in range(1, 7):
		spell("fireball", t, c)
		fx[t] = await fx_seen(0.8)
		await clear()
	ok("each tier adds its own effects: shards and a flash from 2, a white bullseye ring from 3 (%s)" % str(fx), !fx[1].has("flash") and fx[2].has("shards") and fx[2].has("flash") and fx[3].has("burst") and fx[6].has("ripple"))
	# nothing lost: tier 6 still has every lower ability, and its total stays modest
	var e6 = dummy(c + Vector2(70, 0))
	var e1 = dummy(c + Vector2(0, -30))
	var s6 = spell("fireball", 6, c, true)
	await wait(0.45)
	ok("tier 6 shoves too (knock %.0f)" % e6.knock_vel.length(), e6.knock_vel.length() > 100.0)
	var dmg6: float = s6.data.damage
	await wait(2.0)
	var total: float = dealt(e6) / dmg6
	var d_pop := dealt(e1)
	print("  tier 6 total on an enemy 70 px from the centre: %.2f x one blast (%.2f)" % [total, d_pop])
	ok("the whole tier 6 cast stays below 3 blasts", total < 3.0)
	await clear()
	# drawing every tier in flight and landed raises no error
	for t in range(1, 7):
		var far = spell("fireball", t, c)
		far.origin = c + Vector2(120, -80)
		far.flight = 0.4
		far.queue_redraw()
		await wait(0.2)
		await wait(1.0)
		await clear()
	ok("every tier draws in flight and landed without errors", true)

# ================================================================== Frost Ring
func frost_ring() -> void:
	print("-- frost_ring")
	var c := Vector2(0, 300)
	var bite := [0.0, 0.0, 1.5, 2.5, 4.0, 6.0]
	# Flash freeze (tier 2)
	var fz := {}
	for t in [1, 2]:
		var e = dummy(c + Vector2(10, 0))
		spell("frost_ring", t, c)
		await wait(0.3)
		fz[t] = [e.slow_mult, e.slow_time]
		await clear()
	ok("tier 2 freezes what is inside when it lands, tier 1 only slows (%s)" % str(fz), fz[2][0] == 0.0 and fz[2][1] > 0.4 and fz[1][0] > 0.0 and fz[1][0] < 1.0)
	# Frostbite (tier 3+): ice damage over time
	var fb := {}
	for t in [2, 3, 4, 6]:
		var e = dummy(c + Vector2(10, 0))
		var s = spell("frost_ring", t, c, true, {"duration": 20.0})
		await wait(0.3)
		var h0: float = e.health
		await wait(2.0)
		fb[t] = snappedf((h0 - e.health) / 2.0, 0.1)
		await clear()
	ok("frostbite: nothing at tier 2, about 1.5 / s at tier 3, more at 4 and 6 (%s per second; icicles add from tier 4)" % str(fb), fb[2] == 0.0 and absf(fb[3] - 1.5) < 0.6 and fb[4] > fb[3] and fb[6] > fb[4])
	# Icicle fall (tier 4): telegraphed strikes on distinct enemies
	var ic := {}
	for t in [3, 4]:
		var es := []
		for i in 5:
			es.append(dummy(c + Vector2.from_angle(i * TAU / 5.0) * 25.0))
		spell("frost_ring", t, c, true, {"duration": 20.0})
		var seen := await fx_seen(3.0, 0.3)
		var total := 0.0
		for e in es:
			total += dealt(e)
		ic[t] = [seen.get("ring", 0), snappedf(total, 0.1)]
		await clear()
	ok("tier 4 drops icicles (ring telegraphs and extra damage), tier 3 does not (%s)" % str(ic), ic[4][0] >= ic[3][0] + 3 and ic[4][1] > ic[3][1] * 1.5)
	# Shatter (tier 5): a death freezes its neighbour
	var sh := {}
	for t in [4, 5]:
		var a = dummy(c + Vector2(0, 5), 1.0)
		var b = dummy(c + Vector2(20, 5))
		spell("frost_ring", t, c, true, {"duration": 20.0, "slow": 0.35})
		await wait(0.2)
		b.slow_mult = 1.0
		b.slow_time = 0.0                                  # (clear the landing freeze so only a nova can freeze it)
		await wait(1.2)
		sh[t] = [snappedf(b.slow_mult, 0.01), is_instance_valid(a)]
		await clear()
	ok("tier 5: a death inside bursts into a frost nova that freezes its neighbour, tier 4 does not (%s)" % str(sh), sh[5][0] == 0.0 and sh[4][0] > 0.0)
	# Absolute zero (tier 6): the finale at the end
	var fin := {}
	for cp in [false, true]:
		var e = dummy(c + Vector2(10, 0))
		spell("frost_ring", 6, c, true, {"duration": 1.5, "copy": cp})
		var seen := await fx_seen(2.2)
		fin[cp] = [seen.has("ripple"), game.get_node_or_null("/root") != null and load("res://items/weapons/weapon_util.gd").is_exposed(e)]
		await clear()
	ok("tier 6 ends in absolute zero (ripple, exposed), a copy does not (%s)" % str(fin), fin[false][0] and fin[false][1] and !fin[true][0])

# ================================================================== Flare
func flare() -> void:
	print("-- flare")
	var c := Vector2(0, 300)
	var d0 = game.stats_of("flare")
	# Dazzle (tier 2)
	var dz := {}
	for t in [1, 2]:
		var e = dummy(c + Vector2(10, 0))
		spell("flare", t, c, true, {"duration": 30.0})
		await wait(0.6)
		dz[t] = e.slow_mult
		await clear()
	ok("tier 2 dazzles (slower), tier 1 does not (%s)" % str(dz), dz[2] <= 0.81 and dz[1] == 1.0)
	# Searing rays (tier 3): more damage than the plain burn
	var rs := {}
	for t in [2, 3]:
		var s = spell("flare", t, c, true, {"duration": 30.0})
		var r: float = s.radius
		var es := []
		for k in 8:
			es.append(dummy(c + Vector2.from_angle(k * TAU / 8.0) * r * 0.7))
		await wait(5.0)
		var total := 0.0
		for e in es:
			total += dealt(e)
		rs[t] = [snappedf(total, 0.1), s._ray_hit.size()]
		await clear()
	ok("tier 3 beams sweep round and hit harder (%s)" % str(rs), rs[3][0] > rs[2][0] * 1.5 and rs[3][1] > 0 and rs[2][1] == 0)
	# Solar pulse (tier 4): enemies are shoved outward
	var pu := {}
	for t in [3, 4]:
		var e = dummy(c + Vector2(30, 0))
		e.set_physics_process(true)
		spell("flare", t, c, true, {"duration": 30.0})
		await wait(1.4)
		pu[t] = snappedf(e.global_position.x - c.x, 1.0)
		await clear()
	ok("tier 4 pulses push enemies out (distance from the centre %s)" % str(pu), pu[4] > pu[3] + 5.0)
	# Orbiting suns (tier 5): bolts
	var su := {}
	for t in [4, 5]:
		var es := []
		for k in 3:
			es.append(dummy(c + Vector2.from_angle(k * 2.0) * 40.0))
		spell("flare", t, c, true, {"duration": 30.0})
		var n := 0
		var seen := {}
		var el := 0.0
		while el < 3.0:
			await wait(0.05)
			el += 0.05
			for nd in world.get_children():
				if nd.get_script() != null and str(nd.get_script().resource_path).ends_with("projectile.gd") and !seen.has(nd.get_instance_id()):
					seen[nd.get_instance_id()] = true
					n += 1
		su[t] = n
		await clear()
	ok("tier 5 suns shoot (%s bolts in 3 s; the keep towers add a few at both tiers)" % str(su), su[5] >= su[4] + 3)
	# Daybreak (tier 6): a finale, and the flare follows the aimer
	var fin := {}
	for cp in [false, true]:
		var e = dummy(c + Vector2(100, 0))
		var s = spell("flare", 6, c, true, {"duration": 1.5, "copy": cp})
		var r6: float = s.radius
		e.global_position = c + Vector2(r6 * 1.2, 0)
		var seen := await fx_seen(2.0)
		fin[cp] = [seen.has("star") and seen.has("flash"), snappedf(dealt(e), 0.1)]
		await clear()
	ok("tier 6 ends in daybreak (flash, star, big hit), a copy does not (%s)" % str(fin), fin[false][0] and fin[false][1] > 3.0 and !fin[true][0])
	var p = world.get_node("Player")
	var fl = spell("flare", 6, c, true, {"duration": 5.0})
	fl.caster = p
	await wait(0.5)
	ok("the flare still follows the aimer (%s vs %s)" % [str(fl.position), str(p.aim_point())], fl.position.distance_to(p.aim_point()) < 1.0)

# ================================================================== Rejuvenation
func rejuvenation() -> void:
	print("-- rejuvenation")
	var c := Vector2(0, 300)
	var p = world.get_node("Player")
	var rect = world.get_node("Hud/Control2/ColorRect/Health")
	var make_guard := func(pos: Vector2):
		var g = load("res://cards/guard.gd").new()
		g.setup(game.scaled("guards", 1), pos)
		world.add_child(g)
		g.set_physics_process(false)
		g.hp = 5.0
		return g
	# Shared mending (tier 2): guards are healed
	var gm := {}
	for t in [1, 2]:
		var g = make_guard.call(c + Vector2(10, 0))
		spell("rejuvenation", t, c, true, {"duration": 20.0})
		await wait(2.0)
		gm[t] = snappedf(g.hp, 0.1)
		g.queue_free()
		await clear()
	ok("tier 2 heals guards inside, tier 1 does not (%s)" % str(gm), gm[2] > 5.5 and gm[1] == 5.0)
	# Mending roots (tier 3): buildings are repaired
	var mr := {}
	for t in [2, 3]:
		var st = load("res://cards/structure.gd").new()
		st.setup(game.stats_of(game.make_entry("barricade", 1, "")), c + Vector2(10, 0))
		world.add_child(st)
		await wait(0.1)
		st.hp = st.max_hp * 0.5
		spell("rejuvenation", t, c, true, {"duration": 20.0})
		await wait(2.0)
		mr[t] = snappedf(st.hp / st.max_hp, 0.01)
		st.queue_free()
		await clear()
	ok("tier 3 mends buildings inside, tier 2 does not (%s)" % str(mr), mr[3] > 0.52 and mr[2] == 0.5)
	# Sprout ward (tier 4): stepping in shields you, once per six seconds
	var wd := {}
	for t in [3, 4]:
		p.global_position = Vector2(300, 600)
		p.shield_time = 0.0
		spell("rejuvenation", t, c, true, {"duration": 20.0})
		await wait(0.4)
		p.global_position = c + Vector2(5, 0)
		await wait(0.3)
		var first: float = p.shield_time
		p.shield_time = 0.0
		p.global_position = Vector2(300, 600)
		await wait(0.3)
		p.global_position = c + Vector2(5, 0)
		await wait(0.3)
		wd[t] = [snappedf(first, 0.1), snappedf(p.shield_time, 0.1)]
		p.global_position = Vector2(0, 700)
		await clear()
	ok("tier 4 shields a player who steps in, but not again within 6 s; tier 3 never (%s)" % str(wd), wd[4][0] >= 0.5 and wd[4][1] < 0.3 and wd[3][0] == 0.0)
	# Vines (tier 5): slow and thorns
	var vn := {}
	for t in [4, 5]:
		var e = dummy(c + Vector2(10, 0))
		spell("rejuvenation", t, c, true, {"duration": 20.0})
		await wait(1.5)
		vn[t] = [snappedf(e.slow_mult, 0.01), snappedf(dealt(e), 0.1)]
		await clear()
	ok("tier 5 vines slow and hurt, tier 4 does neither (%s)" % str(vn), vn[5][0] <= 0.61 and vn[5][1] > 0.0 and vn[4][0] == 1.0 and vn[4][1] == 0.0)
	# Tree of life (tier 6): heal waves every 2 s, and the finale heals and shields
	var tl := {}
	for t in [3, 6]:
		p.global_position = c + Vector2(5, 0)
		rect.size.x = 20.0
		spell("rejuvenation", t, c, true, {"duration": 3.0})
		var kinds := await fx_seen(3.3)
		tl[t] = [kinds.get("ripple", 0), snappedf(p.shield_time, 0.1), snappedf(rect.size.x, 1.0)]
		await clear()
	rect.size.x = 228.0
	p.shield_time = 0.0
	p.global_position = Vector2(0, 700)
	ok("tier 6 sends heal waves (ripples) and ends by healing and shielding, tier 3 does not (%s)" % str(tl), tl[6][0] >= 1 and tl[3][0] == 0 and tl[6][1] > 1.0 and tl[3][1] == 0.0 and tl[6][2] > tl[3][2])
