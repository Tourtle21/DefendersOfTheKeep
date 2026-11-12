extends "res://tools/tests/wt_base.gd"
## Top-rarity fused weapons (docs/weapon_tiers): Warp Bow, Juggernaut, Earthshaker, Crystal Wand, Prismatic Staff.
## Each tier's own upgrade, kept by the next, absent from the one before. `-- only=<id>` runs one weapon.
func aura_data() -> Dictionary:
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("weapon_aura.gd"):
			return n.data
	return {}
func proj_near(p: Vector2, r: float) -> int:
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.global_position.distance_to(p) <= r:
			c += 1
	return c
func face(d: Vector2) -> void:                       # the pad cursor sits 70 px from the player along aim_dir (a headless mouse cannot be warped)
	await wait(0.1)
	var pad = root.get_node("Pad")
	pad.using_pad = true
	pad.aim_dir = d.normalized()
	await wait(0.2)
func own_proj() -> int:                              # projectiles fired by a player (owner_id set by the weapon module)
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.owner_id != 0:
			c += 1
	return c
func watch_own(secs: float) -> Dictionary:
	var seen := {}
	var peak := 0
	for i in int(secs / 0.05):
		await wait(0.05)
		fx_kinds(seen)
		peak = maxi(peak, own_proj())
	return {"kinds": seen, "proj": peak}
func shoot_arrow(w) -> void:                          # draw to full and release
	w.use_item()
	await wait(0.95)
	w.release_item()

func t_warpbow() -> void:
	var w
	var H: float = 1.0
	# Rift Gate: the anchor lives 6 s and warping leaves a way back for 2 s
	w = await equip("warpbow", 2)
	w.use_ability()
	await wait(0.3)
	var ng0: int = w._st.gates.size()
	await wait(5.3)
	var ng1: int = w._st.gates.size()
	var d: Dictionary = aura_data()
	ok("warpbow Rift Gate: tier 2 anchor still stands after 5.6 s (%d, %d) and is in the aura (%s)" % [ng0, ng1, d.get("g", []).size()], ng0 == 1 and ng1 == 1 and d.get("g", []).size() == 1)
	var from: Vector2 = player.global_position
	w.use_ability()
	await wait(0.3)
	var moved: float = player.global_position.distance_to(from)
	var back := 0
	for g in w._st.gates:
		if int(g.kind) == 1:
			back += 1
	ok("warpbow Rift Gate: the warp moved %.0f px and left a return gate (%d)" % [moved, back], moved > 50.0 and back == 1)
	w._ability_cd = 0.0
	w.use_ability()
	await wait(0.3)
	ok("warpbow Rift Gate: a second right click returns (%.0f px from the start)" % player.global_position.distance_to(from), player.global_position.distance_to(from) < 20.0)
	# Echo Arrow: an arrow through a gate is echoed from the hand at tier 3, not at tier 2; the departure point is struck
	var res := {}
	for t in [2, 3]:
		w = await equip("warpbow", t)
		var dd = dummy(P)
		await face(Vector2(1, 0))
		w.use_ability()
		await wait(0.2)
		await shoot_arrow(w)
		var r = await watch_own(0.9)
		var h1 := lost(dd)
		w._ability_cd = 0.0
		w.use_ability()                                 # warp: departure strike on the dummy that stands there
		await wait(0.4)
		res[t] = {"proj": r.proj, "dep": lost(dd) - h1}
	ok("warpbow Echo Arrow: tier 3 echoes a shot through the gate (%d projectiles vs %d at tier 2)" % [res[3].proj, res[2].proj], res[3].proj >= 2 and res[2].proj == 1)
	ok("warpbow Echo Gate: tier 3 warp strikes the departure point (%.1f vs %.1f)" % [res[3].dep, res[2].dep], res[3].dep > res[2].dep + 0.5)
	# Gate Chain: three gates, an arrow through one re-emerges from the others, the dash leaves a gate
	w = await equip("warpbow", 4)
	for off in [Vector2(1, 0), Vector2(1, -0.8), Vector2(1, 0.8)]:
		await face(off)
		w.use_ability()
		await wait(0.1)
	var plain := 0
	for g in w._st.gates:
		if int(g.kind) == 0:
			plain += 1
	ok("warpbow Gate Chain: three right clicks plant three gates (%d), the aura shows %d" % [plain, aura_data().get("g", []).size()], plain == 3 and aura_data().get("g", []).size() == 3)
	await face(Vector2(1, 0))
	await shoot_arrow(w)
	var r4 = await watch_own(0.8)
	ok("warpbow Gate Chain: an arrow through a gate re-emerges from the other gates (%d projectiles at once)" % r4.proj, r4.proj >= 3)
	w = await equip("warpbow", 4)
	await face(Vector2(1, 0))
	w.use_dash()
	await wait(0.3)
	var ph := 0
	for g in w._st.gates:
		if int(g.kind) == 2:
			ph += 1
	ok("warpbow Phase Gate: the tier 4 dash leaves a gate (%d)" % ph, ph == 1)
	# Rift Barrage: tier 5 fires from the gates too; the gate stands behind the player so no volley arrow crosses it
	var ub := {}
	for t in [4, 5]:
		w = await equip("warpbow", t)
		await face(Vector2(-1, 0))
		w.use_ability()
		await wait(0.1)
		await face(Vector2(1, 0))
		w.use_ultimate()
		ub[t] = await watch_own(1.4)
	ok("warpbow Rift Barrage: tier 5 volley reaches %d projectiles, tier 4 %d" % [ub[5].proj, ub[4].proj], ub[5].proj >= 12 and ub[4].proj <= 10)
	# Rift Storm
	w = await equip("warpbow", 6)
	await face(Vector2(1, 0))
	var sd = dummy(P + Vector2(90, 0))
	w.use_ultimate()
	await wait(1.6)
	ok("warpbow Rift Storm: the aura draws the ring of gates (storm %s) and the weapon knows it" % aura_data().get("storm", false), aura_data().get("storm", false) and w._st.storm_until > 0.0)
	await shoot_arrow(w)
	var rs = await watch_own(0.4)
	ok("warpbow Rift Storm: one shot becomes copies from all six gates (%d projectiles)" % rs.proj, rs.proj >= 6)
	var peak := 0
	var flashes := 0
	var seen := {}
	for i in 220:
		await wait(0.05)
		peak = maxi(peak, own_proj())
		fx_kinds(seen)
	ok("warpbow Rift Storm: gates fire on their own, the finale flashes (%s), peak projectiles %d <= 40, storm over %s" % [seen.get("flash", 0), peak, !aura_data().get("storm", false)], seen.get("flash", 0) >= 6 and peak <= 40 and !aura_data().get("storm", false))
	# Rift arrow finisher (every 5th shot at tier 6) opens a gate at the target
	w = await equip("warpbow", 6)
	await face(Vector2(1, 0))
	var fd = dummy(P + Vector2(70, 0))
	var target_gates := 0
	for i in 5:
		await shoot_arrow(w)
		await wait(0.25)
		for g in w._st.gates:
			if int(g.kind) == 3:
				target_gates += 1
	ok("warpbow Rift Storm finisher: the fifth arrow opened a gate at the target (%d)" % target_gates, target_gates >= 1)
	await draw_smoke("warpbow")
	# Stormcaller Bow still warps with its own strikes
	w = await equip("stormbow", 3)
	await aim_at(P + Vector2(100, 0))
	var from2: Vector2 = player.global_position
	w.use_ability()
	await wait(0.2)
	w.use_ability()
	await wait(0.3)
	ok("warpbow: the Stormcaller Bow still warps (%.0f px)" % player.global_position.distance_to(from2), player.global_position.distance_to(from2) > 60.0)

func distinct_proj(ids: Dictionary) -> void:        # remember every projectile seen (call each tick)
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.owner_id != 0:
			ids[n.get_instance_id()] = true

func t_juggernaut() -> void:
	var w
	# Siege Plate (entry, tier 3): plates in the aura, a block pushes (ring and star), the bash hurts and extends the brace, every third swing slams
	w = await equip("juggernaut", 3)
	var d0 = dummy(P + Vector2(20, 0))
	w.use_ability()
	await wait(0.1)
	var seen := {}
	w._on_absorb(P + Vector2(40, 0))
	for i in 6:
		await wait(0.05)
		fx_kinds(seen)
	var st0: float = float(w._stored)
	ok("juggernaut Siege Plate: a block stores a plate (%d), the aura shows it (%s) and pushes with ring and star %s" % [w._stored, aura_data_state(), seen.has("star")], w._stored == 1 and aura_data_state() == 1.0 and seen.has("star") and seen.has("ring"))
	var t0: float = w._brace_t
	var h0 := lost(d0)
	w.use_item()
	await wait(0.4)
	ok("juggernaut Siege Plate: the bash while braced hurts (%.1f) and extends the brace (%.2f s -> %.2f s)" % [lost(d0) - h0, t0, w._brace_t], lost(d0) - h0 >= 1.0 and w._brace_t < t0 + 0.4 - 0.3)
	w.release_ability()
	await wait(0.2)
	var sl := {}
	for t in [3]:
		w = await equip("juggernaut", t)
		dummy(P + Vector2(24, 0))
		var kinds := []
		for i in 3:
			var sn := {}
			w.use_item()
			for k in 9:
				await wait(0.05)
				fx_kinds(sn)
			kinds.append(sn.has("shock"))
			await wait(0.6)
		sl[t] = kinds
	ok("juggernaut Siege Plate: swing shards on every swing and the slam (shock) on the third only %s" % [sl[3]], sl[3] == [false, false, true])
	# Reactive Armour (tier 4): a block fires a shard back; eight plates make a cone; the charge carries and adds plates
	var ra := {}
	for t in [3, 4]:
		w = await equip("juggernaut", t)
		w.use_ability()
		await wait(0.1)
		w._on_absorb(P + Vector2(40, 0))
		var pk := 0
		for i in 8:
			await wait(0.05)
			pk = maxi(pk, own_proj())
		var dd = dummy(P + Vector2(90, 0))
		w._stored = 8
		var l0 := lost(dd)
		w.release_ability()
		await wait(0.5)
		ra[t] = {"proj": pk, "cone": lost(dd) - l0}
	ok("juggernaut Reactive Armour: tier 4 block fires a shard (%d vs %d) and 8 plates release a cone to 90 px (%.1f vs %.1f)" % [ra[4].proj, ra[3].proj, ra[4].cone, ra[3].cone], ra[4].proj >= 1 and ra[3].proj == 0 and ra[4].cone > ra[3].cone + 1.0)
	var ca := {}
	for t in [3, 4]:
		w = await equip("juggernaut", t)
		await face(Vector2(1, 0))
		var cd = dummy(P + Vector2(24, 0), HP, true)
		var x0: float = cd.global_position.x
		w.use_dash()
		await wait(0.9)
		ca[t] = {"dx": cd.global_position.x - x0, "plates": int(w._stored), "lost": lost(cd)}
	ok("juggernaut Reactive Charge: tier 4 carries the dummy (%.0f px vs %.0f), adds %d plates (tier 3: %d) and slams harder (%.1f vs %.1f)" % [ca[4].dx, ca[3].dx, ca[4].plates, ca[3].plates, ca[4].lost, ca[3].lost], ca[4].dx > ca[3].dx + 20.0 and ca[4].plates >= 1 and ca[3].plates == 0 and ca[4].lost > ca[3].lost)
	# Siege Engine (tier 5): growing pulses with shard rings; the fortress swallows enemy shots
	var se := {}
	for t in [4, 5]:
		w = await equip("juggernaut", t)
		var far = dummy(P + Vector2(90, 0))
		var shot := Node2D.new()
		shot.add_to_group("enemy_shot")
		world.add_child(shot)
		shot.global_position = P + Vector2(30, 0)
		w.use_ultimate()
		var ids := {}
		for i in 130:
			await wait(0.05)
			distinct_proj(ids)
		se[t] = {"far": lost(far), "proj": ids.size(), "shot": is_instance_valid(shot) and !shot.is_queued_for_deletion()}
		if is_instance_valid(shot):
			shot.queue_free()
	ok("juggernaut Siege Engine: tier 5 fires %d shards (tier 4: %d), the late pulses reach 90 px (%.1f vs %.1f), the enemy shot is swallowed (%s vs %s)" % [se[5].proj, se[4].proj, se[5].far, se[4].far, !se[5].shot, !se[4].shot], se[5].proj >= 24 and se[4].proj == 0 and se[5].far > 0.0 and se[4].far == 0.0 and !se[5].shot and se[4].shot)
	# Colossus (tier 6): bigger weapon, shocks at every footstep, the titanic slam at the end
	w = await equip("juggernaut", 6)
	var cdm = dummy(P + Vector2(70, 0))
	w._stored = 6
	w.use_ultimate()
	await wait(6.5)
	Input.action_press(player.controls.left)
	var steps := 0
	var big: float = w.scale.x
	var sn2 := {}
	var shocks := 0
	for i in 60:
		if i == 30:
			Input.action_release(player.controls.left)
			Input.action_press(player.controls.right)        # and back, so the dummy is under the final slam
		await wait(0.05)
		var s3 := {}
		fx_kinds(s3)
		shocks += int(s3.get("shock", 0) > 0)
	Input.action_release(player.controls.right)
	ok("juggernaut Colossus: weapon scale %.2f, shock fx present in %d of 60 frames while walking" % [big, shocks], big > 1.2 and shocks >= 4)
	await wait(3.6)
	var before := lost(cdm)
	var had_stun: bool = cdm.has_meta("stun_cd_until")
	var flash := false
	var stunned := false
	for i in 44:
		await wait(0.05)
		var s4 := {}
		fx_kinds(s4)
		flash = flash or s4.has("flash")
		if is_instance_valid(cdm) and cdm.has_meta("stun_cd_until"):
			stunned = !had_stun
	var final_hit := lost(cdm) - before
	ok("juggernaut Colossus: the final slam lands (flash %s, %.1f taken, stunned %s, scale back to %.2f)" % [flash, final_hit, stunned, w.scale.x], flash and final_hit >= 21.0 and stunned and w.scale.x < 1.05)
	await draw_smoke("juggernaut")

func hazards() -> int:
	return count_script("hazard.gd")
func health_px() -> float:
	return world.get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x

func t_earthshaker() -> void:
	var w
	var mod = load("res://items/weapons/tiers/earthshaker.gd")
	# Fault Lines (entry, tier 3): the fissure leaves faults, every third swing a spike leaves one
	w = await equip("earthshaker", 3)
	w.use_ability()
	await wait(1.4)
	var nf: int = hazards()
	ok("earthshaker Fault Lines: the fissure leaves %d fault patches (cap 14)" % nf, nf >= 10 and nf <= 14)
	w = await equip("earthshaker", 3)
	for h in world.get_children():
		if h.get_script() != null and str(h.get_script().resource_path).ends_with("hazard.gd"):
			h.queue_free()
	await wait(0.2)
	w._st.faults.clear()
	dummy(P + Vector2(40, 0))
	var f0 := hazards()
	var seen3 := {}
	for i in 3:
		w.use_item()
		for k in 9:
			await wait(0.05)
			fx_kinds(seen3)
		await wait(0.55)
	ok("earthshaker Fault Lines: the third swing's spike leaves a fault (%d -> %d), shards on the swing %s" % [f0, hazards(), seen3.has("shards")], hazards() - f0 == 1 and seen3.has("shards"))
	# Tremor: two extra hits on a swing, a return wave, the burrow erupts faults on arrival
	var tr := {}
	for t in [3, 4]:
		w = await equip("earthshaker", t)
		var d1 = dummy(P + Vector2(40, 0))
		w.use_item()
		await wait(0.7)
		tr[t] = lost(d1)
	ok("earthshaker Tremor: a swing hits a dummy at 40 px harder at tier 4 (%.1f vs %.1f)" % [tr[4], tr[3]], tr[4] > tr[3] + 0.5)
	var rw := {}
	for t in [3, 4]:
		w = await equip("earthshaker", t, false)
		var d2 = dummy(P + Vector2(22, 0))
		w.use_ability()
		await wait(1.2)
		var first := lost(d2)
		await wait(1.6)
		rw[t] = lost(d2) - first
	ok("earthshaker Tremor: the return wave hits the line's start again (%.1f vs %.1f at tier 3)" % [rw[4], rw[3]], rw[4] > rw[3] + 0.5)
	var bu := {}
	for t in [3, 4]:
		w = await equip("earthshaker", t)
		await face(Vector2(1, 0))
		w._st.faults.clear()
		for k in 3:
			mod.add_fault(w, P + Vector2(60 + 6.0 * k, 0))
		await wait(0.1)
		w.use_dash()
		await wait(1.0)
		bu[t] = hazards()
	ok("earthshaker Tremor: arriving erupts the faults within 60 px (%d left vs %d at tier 3)" % [bu[4], bu[3]], bu[4] < bu[3])
	# Tectonic Shift: the crowd is dragged in, an aftershock spends the faults
	var ts := {}
	for t in [4, 5]:
		w = await equip("earthshaker", t)
		var d3 = dummy(P + Vector2(100, 0), HP, true)
		w.use_ultimate()
		await wait(1.5)
		var x0: float = d3.global_position.distance_to(player.global_position)
		var pulled := 0.0
		for i in 30:
			await wait(0.05)
			pulled = maxf(pulled, x0 - d3.global_position.distance_to(player.global_position))
		await wait(1.0)
		ts[t] = {"pull": pulled, "haz": hazards()}
	ok("earthshaker Tectonic Shift: tier 5 drags the dummy %.0f px (tier 4: %.0f) and spends the faults (%d vs %d)" % [ts[5].pull, ts[4].pull, ts[5].haz, ts[4].haz], ts[5].pull > ts[4].pull + 15.0 and ts[5].haz < ts[4].haz)
	# World Shaker
	w = await equip("earthshaker", 6)
	var d4 = dummy(P + Vector2(100, 0))
	w.use_ultimate()
	await wait(3.6)
	Input.action_press(player.controls.left)
	var maxf_ := 0
	var pill := 0
	for i in 30:
		await wait(0.05)
		maxf_ = maxi(maxf_, hazards())
		var s5 := {}
		fx_kinds(s5)
		pill += int(s5.get("pillar", 0) > 0)
	Input.action_release(player.controls.left)
	Input.action_press(player.controls.right)
	for i in 30:
		await wait(0.05)
	Input.action_release(player.controls.right)
	var live := int(mod.fault_count(w))
	ok("earthshaker World Shaker: footsteps leave faults (%d live, max seen %d <= 14), pillars at the cursor in %d frames" % [live, maxf_, pill], live >= 3 and maxf_ <= 14 and pill >= 1)
	var b0 := lost(d4)
	var fl := false
	var peak2 := 0
	for i in 110:
		await wait(0.05)
		var s6 := {}
		fx_kinds(s6)
		fl = fl or s6.has("flash")
	ok("earthshaker World Shaker: the final quake lands (flash %s, %.1f taken, scale of the strike 2.0 H)" % [fl, lost(d4) - b0], fl and lost(d4) - b0 >= 12.0)
	# faults never hurt the player
	w = await equip("earthshaker", 3)
	mod.add_fault(w, player.global_position)
	var hp0 := health_px()
	await wait(3.0)
	ok("earthshaker: standing in a fault for 3 s costs no health (%.1f -> %.1f)" % [hp0, health_px()], is_equal_approx(hp0, health_px()))
	await draw_smoke("earthshaker")

func young_proj() -> int:                               # projectiles of the last 0.12 s (one fan)
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n._age < 0.15:
			c += 1
	return c

func t_crystalwand() -> void:
	var w
	var mod = load("res://items/weapons/tiers/crystalwand.gd")
	# Prism Shards (tier 2): five shards that embed crystals; tier 1 has three and no mark
	var fan := {}
	for t in [1, 2]:
		w = await equip("crystalwand", t, false)
		var d1 = dummy(P + Vector2(40, 0))
		w.use_item()
		await wait(0.1)
		var n1 := young_proj()
		await wait(0.5)
		fan[t] = {"n": n1, "mark": mod.crystals(d1)}
	ok("crystalwand Prism Shards: tier 2 fan %d shards and %d crystal (tier 1: %d shards, %d)" % [fan[2].n, fan[2].mark, fan[1].n, fan[1].mark], fan[2].n == 5 and fan[2].mark >= 1 and fan[1].n == 3 and fan[1].mark == 0)
	# Resonance (tier 3): the fourth crystal shatters and spreads two to a neighbour; a perfect rhythm makes a 7-shard cone
	var rs := {}
	for t in [2, 3]:
		w = await equip("crystalwand", t, false)
		var d2 = dummy(P + Vector2(40, 0))
		var nb = dummy(P + Vector2(40, 35))
		mod.set_crystals(d2, 3)
		await wait(0.2)
		w.use_item()
		await wait(0.7)
		rs[t] = {"lost": lost(d2), "nb": mod.crystals(nb), "nb_lost": lost(nb)}
	ok("crystalwand Resonance: tier 3 shatters (%.1f vs %.1f taken) and the neighbour gets crystals (%d vs %d, %.1f taken)" % [rs[3].lost, rs[2].lost, rs[3].nb, rs[2].nb, rs[3].nb_lost], rs[3].lost > rs[2].lost + 6.0 and rs[3].nb >= 2 and rs[2].nb == 0)
	w = await equip("crystalwand", 3, false)
	var counts := []
	for i in 3:
		w._attack_cd = 0.0
		w.use_item()
		await wait(0.1)
		counts.append(young_proj())
		await wait(0.38)
	ok("crystalwand Resonance: the third fan within 1.2 s is a cone of seven %s" % [counts], counts[2] == 7 and counts[0] == 5)
	var pu := {}
	for t in [2, 3]:
		w = await equip("crystalwand", t, false)
		var dp = dummy(P + Vector2(70, 0), HP, true)
		var x0: float = dp.global_position.x
		w.use_ability()
		await wait(0.5)
		pu[t] = x0 - dp.global_position.x
	ok("crystalwand Resonance Ring: tier 3 pulls the dummy in (%.0f px vs %.0f)" % [pu[3], pu[2]], pu[3] > pu[2] + 5.0)
	# Crystal Familiar (tier 4)
	w = await equip("crystalwand", 4, false)
	await wait(0.4)
	var fam: int = int(aura_data().get("fam", 0))
	w.use_item()
	await wait(0.15)
	var homing := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.homing > 0.0:
			homing += 1
	ok("crystalwand Crystal Familiar: aura shows %d familiar and an attack adds %d homing mirror shard" % [fam, homing], fam == 1 and homing == 1)
	w = await equip("crystalwand", 4, false)
	await face(Vector2(1, 0))
	w.use_dash()
	await wait(0.5)
	var mirror_ok: bool = aura_data().has("mirror")
	await face(Vector2(-1, 0))
	w.use_item()
	await wait(0.5)
	var echoed := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("projectile.gd") and n.gated:
			echoed += 1
	ok("crystalwand Refract: the dash leaves a mirror (%s) that echoes a shot (%d)" % [mirror_ok, echoed], mirror_ok and echoed >= 1)
	# Geode Garden (tier 5)
	var gg := {}
	for t in [4, 5]:
		w = await equip("crystalwand", t, false)
		await face(Vector2(1, 0))
		w.use_ultimate()
		var seen := {}
		var haz := 0
		var gdummy = null
		for i in 130:
			await wait(0.05)
			fx_kinds(seen)
			haz = maxi(haz, hazards())
			if t == 5 and gdummy == null and w._st.geodes.size() > 0:
				gdummy = dummy(w._st.geodes[0] + Vector2(4, 0))
				gdummy.max_health = HP
		gg[t] = {"pillar": int(seen.get("pillar", 0)), "haz": haz, "geo": w._st.geodes.size() if t == 5 else 0}
	ok("crystalwand Geode Garden: tier 5 leaves %d geodes (%d patches) and pillars in %d frames; tier 4 none (%d patches, %d frames)" % [gg[5].geo, gg[5].haz, gg[5].pillar, gg[4].haz, gg[4].pillar], gg[5].geo == 8 and gg[5].haz >= 6 and gg[5].pillar >= 8 and gg[4].haz == 0)
	# Crystal Ascension (tier 6)
	w = await equip("crystalwand", 6, false)
	await face(Vector2(1, 0))
	var ad = dummy(P + Vector2(60, 0))
	w.use_ultimate()
	await wait(3.6)
	var peak := 0
	var seen6 := {}
	var steps := []
	var prev := lost(ad)
	var biggest := 0.0
	var fam6: int = int(aura_data().get("fam", 0))
	for i in 270:
		await wait(0.05)
		peak = maxi(peak, own_proj())
		fx_kinds(seen6)
		if i == 200:
			mod.set_crystals(ad, 3)                         # marks on the dummy as the final shatter is about to come
		var l := lost(ad)
		if i * 0.05 > 10.0:
			biggest = maxf(biggest, l - prev)
		prev = l
	ok("crystalwand Crystal Ascension: %d familiars, beams %s, waves (ripple) %s, peak projectiles %d <= 40, biggest single jump near the end %.1f (final shatter >= 7.2)" % [fam6, seen6.has("beam"), seen6.has("ripple"), peak, biggest], fam6 == 3 and seen6.has("beam") and seen6.has("ripple") and peak <= 40 and biggest >= 7.2)
	await draw_smoke("crystalwand")
	w = await equip("prismstaff", 3, false)
	dummy(P + Vector2(40, 0))
	w.use_item()
	await wait(0.1)
	ok("crystalwand: the Prismatic Staff still fires its own five-shard fan (%d)" % young_proj(), young_proj() == 5)

func aura_data_state() -> float:
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("weapon_aura.gd"):
			return n.state
	return -1.0

func run() -> void:
	if only == "" or only == "warpbow":
		await t_warpbow()
	if only == "" or only == "juggernaut":
		await t_juggernaut()
	if only == "" or only == "earthshaker":
		await t_earthshaker()
	if only == "" or only == "crystalwand":
		await t_crystalwand()
