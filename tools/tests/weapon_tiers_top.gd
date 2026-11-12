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
