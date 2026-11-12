extends SceneTree
## Wall buildings, tiers 2 to 6: Barricade, Iron Bulwark, Thorn Hedge (docs/card_tiers/<id>.md say what to check).
## Run: Godot --headless --path . --script res://tools/tests/structure_tiers_walls.gd [-- only=barricade]
var game
var world
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
## A still target (damage dealt = 99999 - health).
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
## Place a building of a card at a tier (its own stacked additions included, like a real one).
func build(id: String, tier: int, pos: Vector2, tough := true):
	game.meta.card_tiers[id] = 6
	var st = load("res://cards/structure.gd").new()
	st.setup(game.stats_of(game.make_entry(id, tier, game.twist_for(id, tier))), pos)
	world.add_child(st)
	if tough:
		st.max_hp = 99999.0
		st.hp = 99999.0
	return st
func clear() -> void:
	for n in world.get_children():
		if n.get_script() != null and (str(n.get_script().resource_path).ends_with("structure.gd") or str(n.get_script().resource_path).ends_with("projectile.gd") or str(n.get_script().resource_path).ends_with("hazard.gd") or str(n.get_script().resource_path).ends_with("spell.gd")):
			n.queue_free()
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.2)
func fx_seen(secs: float) -> Dictionary:
	var seen := {}
	var out := {}
	var t := 0.0
	while t < secs:
		await wait(0.05)
		t += 0.05
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx.gd") and !seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				out[n.kind] = int(out.get(n.kind, 0)) + 1
	return out
func exposed(e) -> bool:
	return load("res://items/weapons/weapon_util.gd").is_exposed(e)
func count_nodes(file: String) -> int:
	var n := 0
	for c in world.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with(file):
			n += 1
	return n
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://tier_walls_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 700)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for id in ["barricade", "iron_wall", "thorn_hedge"]:
		if only == "" or only == id:
			await call(id)
			await clear()
	quit()

# ================================================================== Barricade
func barricade() -> void:
	print("-- barricade")
	var c := Vector2(0, 300)
	# Shove (tier 2): the wall bucks every 4 s and knocks a gnawer back
	var kn := {}
	for t in [1, 2]:
		var st = build("barricade", t, c)
		var e = dummy(c + Vector2(20, 0))
		var mx := 0.0
		var mn := 1.0
		for i in 90:
			await wait(0.05)
			mx = maxf(mx, e.knock_vel.length())
			mn = minf(mn, e.slow_mult)
		kn[t] = [mx, mn]
		await clear()
	ok("tier 2 shoves a gnawer and stuns it, tier 1 does not (%s)" % str(kn), kn[2][0] > 100.0 and kn[2][1] == 0.0 and kn[1][0] == 0.0)
	# Stakes (tier 3): the gnawer nearest the middle is skewered and exposed
	var sk := {}
	for t in [2, 3]:
		var st = build("barricade", t, c)
		var e = dummy(c + Vector2(20, 0))
		var thorns: float = st.data.thorns
		var seen := await fx_seen(3.3)
		sk[t] = [seen.get("pillar", 0), exposed(e), snappedf(dealt(e) / thorns, 0.1)]
		await clear()
	ok("tier 3 skewers a gnawer (pillar, exposed), tier 2 does not (%s)" % str(sk), sk[3][0] >= 1 and sk[3][1] and sk[2][0] == 0 and !sk[2][1])
	# Ballista (tier 4): shoots what is within 100 px, even when nothing chews
	var bl := {}
	for t in [3, 4]:
		var st = build("barricade", t, c)
		var e = dummy(c + Vector2(80, 0))
		var seen := await fx_seen(1.8)
		bl[t] = [dealt(e), seen.get("line", 0)]
		await clear()
	ok("tier 4 shoots an enemy 80 px away, tier 3 does not (%s)" % str(bl), bl[4][0] > 1.0 and bl[4][1] >= 1 and bl[3][0] == 0.0)
	# Rebuke (tier 5): a shockwave each time it falls below 75% / 50% / 25%, once per fall
	var st5 = build("barricade", 5, c, false)
	var e5 = dummy(c + Vector2(35, 0))
	st5.hp = st5.max_hp
	await wait(0.2)
	e5.knock_vel = Vector2.ZERO
	st5.hp = 0.7 * st5.max_hp
	var seen5 := await fx_seen(0.4)
	var pushed: bool = e5.knock_vel.length() > 100.0
	var seen5b := await fx_seen(0.8)
	var again: int = seen5b.get("ripple", 0)
	st5.hp = 0.9 * st5.max_hp
	await wait(0.1)
	st5.hp = 0.7 * st5.max_hp
	var seen5c := await fx_seen(0.4)
	ok("tier 5 rebukes once when hp falls below 75%% and again after healing (%s %s %s)" % [str(seen5), str(seen5b), str(seen5c)], seen5.get("ripple", 0) == 1 and pushed and again == 0 and seen5c.get("ripple", 0) == 1)
	await clear()
	# Second wind (tier 6): once, heals to 60%, untouchable 3 s, bursts
	var st6 = build("barricade", 6, c, false)
	var e6 = dummy(c + Vector2(20, 0))
	var thorns6: float = st6.data.thorns
	st6.hp = 0.1 * st6.max_hp
	await wait(0.1)
	var hp_after: float = st6.hp / st6.max_hp
	var inv: float = st6._invuln
	await wait(1.0)
	var held: float = st6.hp / st6.max_hp
	ok("tier 6 second wind: heals to 60%% and is untouchable (hp %.2f, invuln %.1f, hp a second later %.2f, dome %s)" % [hp_after, inv, held, str(st6.invuln_view)], hp_after >= 0.55 and inv > 2.5 and held >= 0.59 and st6.invuln_view)
	await wait(2.5)
	st6.hp = 0.1 * st6.max_hp
	await wait(0.3)
	ok("the second wind comes only once", st6.hp < 0.2 * st6.max_hp and st6._invuln == 0.0)
	var t4thorns: float = build("barricade", 4, c + Vector2(200, 0)).data.thorns
	ok("tier 6 has thorns doubled by tier 5 (%.1f vs tier 4 %.1f)" % [thorns6, t4thorns], thorns6 > 3.0 * t4thorns)
	await clear()
	# Cumulative: tier 6 still skewers, shoots and shoves
	var st = build("barricade", 6, c)
	dummy(c + Vector2(20, 0))
	var seen := await fx_seen(4.6)
	ok("tier 6 still has stakes, ballista and shove (%s)" % str(seen), seen.get("pillar", 0) >= 1 and seen.get("line", 0) >= 1 and seen.get("shards", 0) >= 1)

# ================================================================== Iron Bulwark
## hp lost by a wall with a dummy gnawing it for `secs`
func chewed(id: String, tier: int, secs: float, aura_at = null) -> float:
	var c := Vector2(0, 300)
	var st = build(id, tier, c, false)
	var other = null
	if aura_at != null:
		other = build("iron_wall", 4, c - aura_at, true)
	var e = dummy(c + Vector2(20, 0))
	var hp0: float = st.hp
	await wait(secs)
	var lost: float = hp0 - st.hp
	await clear()
	return lost
func iron_wall() -> void:
	print("-- iron_wall")
	var c := Vector2(0, 300)
	var tl = load("res://cards/structure_tiers.gd")
	# Plating (tier 2): enemies chew less
	var l1: float = await chewed("iron_wall", 1, 6.0)
	var l2: float = await chewed("iron_wall", 2, 6.0)
	ok("tier 2 plating: a gnawer costs 75%% of the hp (tier 1 lost %.1f, tier 2 lost %.1f)" % [l1, l2], l1 > 3.0 and absf(l2 / l1 - 0.75) < 0.1)
	# Ram slam (tier 3)
	var rs := {}
	for t in [2, 3]:
		var st = build("iron_wall", t, c)
		var e = dummy(c + Vector2(22, 0))
		var mx := 0.0
		var mn := 1.0
		for i in 110:
			await wait(0.05)
			mx = maxf(mx, e.knock_vel.length())
			mn = minf(mn, e.slow_mult)
		rs[t] = [snappedf(mx, 1.0), mn]
		await clear()
	ok("tier 3 slams a gnawer away and stuns it, tier 2 never (%s)" % str(rs), rs[3][0] > 100.0 and rs[3][1] == 0.0 and rs[2][0] == 0.0)
	# Bulwark aura (tier 4): a neighbour takes 20% less
	var plain_loss: float = await chewed("barricade", 1, 6.0)
	var aura_loss: float = await chewed("barricade", 1, 6.0, Vector2(-40, 0))
	ok("tier 4 aura: a barricade 40 px away loses 20%% less (alone %.1f, near a bulwark %.1f)" % [plain_loss, aura_loss], plain_loss > 3.0 and absf(aura_loss / plain_loss - 0.8) < 0.1)
	# Deflect (tier 5)
	var df := {}
	for t in [4, 5]:
		var st = build("iron_wall", t, c)
		load("res://enemies/spitter/enemy_projectile.gd").fire(world, c + Vector2(45, 0), Vector2(-1, 0), 95.0, 30.0)
		var turned := false
		var gone := false
		for i in 40:
			await wait(0.05)
			for n in world.get_children():
				if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.vel.x > 0.0 and n.damage < 10.0 and n.get_script().resource_path.ends_with("/items/weapons/projectile.gd"):
					turned = true
		for n in get_nodes_of("enemy_shot"):
			gone = false
		df[t] = turned
		await clear()
	ok("tier 5 throws enemy shots back, tier 4 does not (%s)" % str(df), df[5] and !df[4])
	# Anvil bell (tier 6)
	var st6 = build("iron_wall", 6, c)
	var near = dummy(c + Vector2(80, 0))
	var ref = dummy(c + Vector2(500, 0))
	var thorns: float = st6.data.thorns
	ref.spell_damage(thorns * 6.0, "", true)
	var mn6 := 1.0
	var seen6 := {}
	var t6 := 0.0
	while t6 < 12.4:
		await wait(0.05)
		t6 += 0.05
		mn6 = minf(mn6, near.slow_mult)
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx.gd") and n.kind == "flash":
				seen6["flash"] = true
	ok("tier 6 bell tolls after 12 s: flash, hurts (%.1f, a plain hit of that size does %.1f), stuns (%.1f)" % [dealt(near), dealt(ref), mn6], seen6.has("flash") and dealt(near) >= dealt(ref) * 0.95 and mn6 == 0.0)
	await clear()
	# Cumulative: tier 6 keeps plating and slam
	var l6: float = await chewed("iron_wall", 6, 3.0)
	var lone = build("iron_wall", 6, c + Vector2(300, 0))
	ok("tier 6 keeps its plating (guard_mult %.2f)" % tl.guard_mult(lone), absf(tl.guard_mult(lone) - 0.75) < 0.01)
func thorn_hedge() -> void:
	pass
func get_nodes_of(g: String) -> Array:
	return world.get_tree().get_nodes_in_group(g)
