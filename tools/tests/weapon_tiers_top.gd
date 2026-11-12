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

func run() -> void:
	if only == "" or only == "warpbow":
		await t_warpbow()
