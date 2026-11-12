extends "res://tools/tests/structure_test_base.gd"
## Spike Trap tiers 2 to 6 (docs/card_tiers/spike_trap.md). Run: Godot --headless --path . --script res://tools/tests/structure_tiers_spike_trap.gd
func sections() -> Array:
	return ["spike_trap"]
func slows() -> Array:
	return world.get_tree().get_nodes_in_group("hazard")
var base_hazards := 0
func spike_trap() -> void:
	print("-- spike_trap")
	base_hazards = slows().size()
	var c := Vector2(0, 300)
	# Snare (tier 2)
	var sn := {}
	for t in [1, 2]:
		var st = build("spike_trap", t, c)
		var e = dummy(c + Vector2(5, 0))
		await wait(0.6)
		sn[t] = e.slow_mult
		await clear()
	ok("tier 2 snares whoever triggers it, tier 1 does not (%s)" % str(sn), sn[2] <= 0.46 and sn[1] == 1.0)
	# Spring (tier 3): every third trigger the spikes shoot up
	var sp := {}
	for t in [2, 3]:
		var st = build("spike_trap", t, c)
		var e = dummy(c + Vector2(5, 0))
		var dmg: float = st.data.damage
		var seen := await fx_seen(1.9)
		sp[t] = [snappedf(dealt(e) / dmg, 0.1), seen.get("ripple", 0)]
		await clear()
	ok("tier 3 springs on the 3rd trigger (4x damage extra, ripple), tier 2 does not (%s)" % str(sp), sp[3][0] >= 8.0 and sp[3][1] >= 1 and sp[2][1] == 0 and sp[2][0] < 6.0)
	# Caltrops (tier 4): a slow patch lies round the trap
	var ct := {}
	for t in [3, 4]:
		var st = build("spike_trap", t, c)
		var e = dummy(c + Vector2(st.radius * 1.2, 0))
		await wait(3.8)
		ct[t] = [slows().size() - base_hazards, e.slow_mult]
		await clear()
	ok("tier 4 keeps slow ground (a dummy 1.2 r out is slowed), tier 3 does not (%s)" % str(ct), ct[4][0] >= 1 and ct[4][1] <= 0.61 and ct[3][0] == 0)
	# Barbed chain (tier 5): enemies near the plate are dragged on it and bleed
	var ch := {}
	for t in [4, 5]:
		var st = build("spike_trap", t, c)
		var near = dummy(c + Vector2(5, 0))
		var far = dummy(c + Vector2(st.radius * 1.4, 0))
		var x0: float = far.global_position.x - c.x
		var mx := 0.0
		for i in 12:
			await wait(0.05)
			mx = maxf(mx, far.knock_vel.length())
		await wait(1.4)
		ch[t] = [snappedf(mx, 1.0), snappedf(dealt(far), 0.1)]
		await clear()
	ok("tier 5 drags and bleeds an enemy 1.4 r away, tier 4 does not (%s)" % str(ch), ch[5][0] > 100.0 and ch[5][1] > 0.3 and ch[4][0] == 0.0 and ch[4][1] == 0.0)
	# Last gasp (tier 6)
	var lg := {}
	for t in [5, 6]:
		var st = build("spike_trap", t, c)
		st.uses = 1
		var dmg: float = st.data.damage
		var e = dummy(c + Vector2(st.radius * 2.0, 0))
		var mid = dummy(c + Vector2(4, 0))
		var seen := await fx_seen(1.0)
		lg[t] = [seen.get("flash", 0), snappedf(dealt(e) / dmg, 0.1), slows().size() - base_hazards, is_instance_valid(st) and !st.is_queued_for_deletion()]
		await clear()
	ok("tier 6 erupts when its last use is spent (flash, 12x damage at 2 r, slow patch), tier 5 just goes (%s)" % str(lg), lg[6][0] >= 1 and lg[6][1] >= 12.0 and lg[6][2] >= 1 and lg[5][0] == 0 and lg[5][1] == 0.0)
	# Cumulative: tier 6 still snares and springs
	var st6 = build("spike_trap", 6, c)
	var e6 = dummy(c + Vector2(5, 0))
	await wait(0.6)
	var snared: float = e6.slow_mult
	var seen6 := await fx_seen(1.5)
	ok("tier 6 still snares and springs (slow %.2f, %s)" % [snared, str(seen6)], snared <= 0.46 and seen6.get("ripple", 0) >= 1)
