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
	await fireball()
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
