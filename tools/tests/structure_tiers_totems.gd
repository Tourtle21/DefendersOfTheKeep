extends "res://tools/tests/structure_test_base.gd"
## Mender Totem and Frost Totem tiers 2 to 6 (docs/card_tiers/mender.md, frost_totem.md).
## Run: Godot --headless --path . --script res://tools/tests/structure_tiers_totems.gd [-- only=mender]
func sections() -> Array:
	return ["mender"]
func bar():
	return player().get_parent().get_node("Hud/Control2/ColorRect/Health")
func away() -> void:
	player().global_position = Vector2(0, 700)
	bar().size.x = 228.0
	player().shield_time = 0.0
## The biggest jump of the health bar between two frames, and the total gain, over `secs`.
func watch(secs: float) -> Array:
	var last: float = bar().size.x
	var start := last
	var mx := 0.0
	var t := 0.0
	while t < secs:
		await wait(0.02)
		t += 0.02
		mx = maxf(mx, bar().size.x - last)
		last = bar().size.x
	return [mx, last - start]
func mender() -> void:
	print("-- mender")
	var c := Vector2(0, 300)
	var p = player()
	# Blessing pulse (tier 2): an instant heal on top of the steady one, every 6 s
	var bl := {}
	for t in [1, 2]:
		var st = build("mender", t, c, false)
		p.global_position = c + Vector2(20, 0)
		bar().size.x = 100.0
		var heal: float = st.data.heal_per_sec
		var w := await watch(6.6)
		bl[t] = [snappedf(w[0] / heal, 0.01), snappedf(st._healed / (heal * 6.6), 0.01)]
		await clear()
		away()
	ok("tier 2 blesses with an instant heal of heal_per_sec, tier 1 only the steady one; the pulse uses no budget (%s)" % str(bl), bl[2][0] >= 0.9 and bl[1][0] < 0.3 and absf(bl[2][1] - bl[1][1]) < 0.05)
	# Shared mending (tier 3): guards and buildings in the field mend
	var sm := {}
	for t in [2, 3]:
		var st = build("mender", t, c, false)
		var g = load("res://cards/guard.gd").new()
		g.setup(game.stats_of(game.make_entry("guards", 1, "")), c + Vector2(15, 0))
		world.add_child(g)
		g.hp = 5.0
		var wall = build("barricade", 1, c + Vector2(-20, 0), false)
		wall.hp = wall.max_hp * 0.5
		var w0: float = wall.hp
		await wait(2.0)
		sm[t] = [snappedf(g.hp - 5.0, 0.1), snappedf(wall.hp - w0, 0.1)]
		g.queue_free()
		await clear()
	ok("tier 3 mends a guard and a wall in the field, tier 2 does not (%s)" % str(sm), sm[3][0] > 1.0 and sm[3][1] > 1.0 and sm[2][0] < 0.1 and sm[2][1] < 0.1)
	# Lifeline (tier 4): the badly hurt heal twice as fast; confusion is cleansed
	var ll := {}
	for hp in [40.0, 137.0]:
		var st = build("mender", 4, c, false)
		p.global_position = c + Vector2(20, 0)
		bar().size.x = hp
		var w := await watch(0.2)
		ll[hp] = snappedf(w[1], 0.1)
		await clear()
		away()
	p.global_position = c + Vector2(20, 0)
	var st4 = build("mender", 4, c, false)
	p.confused_time = 3.0
	bar().size.x = 100.0
	await wait(0.3)
	ok("tier 4 heals under 40%% twice as fast (%s) and cleanses confusion (%.1f)" % [str(ll), p.confused_time], absf(ll[40.0] / ll[137.0] - 2.0) < 0.3 and p.confused_time == 0.0)
	await clear()
	away()
	# Spirit link (tier 5): players just beyond the field are healed at half rate
	var lk := {}
	for t in [4, 5]:
		var st = build("mender", t, c, false)
		p.global_position = c + Vector2(st.radius * 1.3, 0)
		bar().size.x = 120.0
		var w := await watch(1.0)
		lk[t] = snappedf(w[1], 0.1)
		var rate_in: float = st.data.heal_per_sec
		lk[str(t) + "rate"] = rate_in
		await clear()
		away()
	ok("tier 5 heals a player 1.3 x radius away at about half rate, tier 4 not at all (%s)" % str(lk), lk[4] == 0.0 and absf(lk[5] / (lk["5rate"] * 0.5) - 1.0) < 0.2)
	# Guardian angel (tier 6): a player on the brink is saved, once per 30 s
	var st6 = build("mender", 6, c, false)
	p.global_position = c + Vector2(20, 0)
	bar().size.x = 20.0
	var seen := await fx_seen(0.3)
	var saved: float = bar().size.x / 228.0
	var shield: float = p.shield_time
	bar().size.x = 20.0
	await wait(0.3)
	var again: float = bar().size.x / 228.0
	ok("tier 6 saves a player under 15%% to 60%% with a shield; not again within 30 s (%.2f, shield %.1f, again %.2f, %s)" % [saved, shield, again, str(seen)], saved >= 0.59 and shield >= 1.6 and again < 0.55 and seen.get("pillar", 0) >= 1)
	await clear()
	away()
	# Budget: it still runs out when the steady healing has been spent (the blessing does not count)
	var stb = build("mender", 2, c, false)
	p.global_position = c + Vector2(20, 0)
	bar().size.x = 10.0
	stb._heal_budget = 5.0
	await wait(1.5)
	ok("the totem expires once its healing budget is spent", !is_instance_valid(stb) or stb.is_queued_for_deletion())
	away()
