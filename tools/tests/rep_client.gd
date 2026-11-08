extends SceneTree
# Replication test, client side: joins, shows the real client view, compares its puppets to the host's records.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func load_json(name: String) -> Dictionary:
	var f := FileAccess.open("user://rep_host_%s.json" % name, FileAccess.READ)
	if f == null: return {}
	return JSON.parse_string(f.get_as_text())
func puppets_in(group: String) -> Array:
	var out := []
	for n in get_nodes_in_group(group):
		if is_instance_valid(n) and n.has_meta("net_puppet") and !n.is_queued_for_deletion(): out.append(n)
	return out
func has_match(list: Array, pred: Callable) -> bool:
	for n in list:
		if pred.call(n): return true
	return false
func p2(n) -> Array:
	return [snapped(n.global_position.x, 1.0), snapped(n.global_position.y, 1.0)]
func near(a: Array, b: Array) -> bool:
	return absf(a[0] - b[0]) <= 3.0 and absf(a[1] - b[1]) <= 3.0
func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  "), label)
func compare(h: Dictionary, tag: String) -> void:
	print("--- ", tag)
	var enemies := puppets_in("enemy")
	check("%s enemies: host %d, client puppets %d" % [tag, h.enemies.size(), enemies.size()], h.enemies.size() == enemies.size())
	var ok_e := true
	for he in h.enemies:
		var found := has_match(enemies, func(n): return str(n.get_script().resource_path).get_file().get_basename() == he.t and near(p2(n), he.pos) and absf(n.health - he.hp) < 0.2)
		if !found:
			ok_e = false
			print("   enemy not matched: ", he)
	check(tag + " every enemy has a matching puppet (type, position, health)", ok_e)
	var structures := puppets_in("structure")
	check("%s structures: host %d, client %d" % [tag, h.structures.size(), structures.size()], h.structures.size() == structures.size())
	var ok_s := true
	for hs in h.structures:
		if !has_match(structures, func(n): return n.kind == hs.t and near(p2(n), hs.pos) and n.tier == hs.tier):
			ok_s = false
			print("   structure not matched: ", hs)
	check(tag + " every structure matches (kind, position, tier)", ok_s)
	var gens := puppets_in("generator")
	check("%s generators: host %d, client %d" % [tag, h.generators.size(), gens.size()], h.generators.size() == gens.size())
	var ok_g := true
	for hg in h.generators:
		if !has_match(gens, func(n): return n.resource == hg.res and near(p2(n), hg.pos) and n.level == hg.level and n.stored == hg.stored):
			ok_g = false
			print("   generator not matched: ", hg)
	check(tag + " every generator matches (resource, level, stored)", ok_g)
	var scen := 0
	for n in get_nodes_in_group("net"):
		pass
	var thing = null
	for n in get_nodes_in_group("puppet"):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("new_thing.gd"): thing = n
	check(tag + " NEW content type replicated with no multiplayer code: found " + str(thing != null), thing != null)
	if thing != null:
		var want_count := 3 if tag == "BEFORE" else 9
		var want_label := "hello" if tag == "BEFORE" else "changed"
		check("%s   its public vars synced (label %s, count %s, colors %s)" % [tag, thing.label, thing.count, thing.palette.size()], thing.label == want_label and thing.count == want_count and thing.palette.size() == 2)
		check(tag + "   its private var did not travel (_hidden stayed 42): " + str(thing._hidden), thing._hidden == 42)
	check("%s breakables host %d, client %d" % [tag, h.breakables, puppets_in("breakable").size()], h.breakables == puppets_in("breakable").size())
	check("%s chests %d/%d, pickups %d/%d, gold %d/%d, hazards %d/%d, turrets %d/%d, guards %d/%d" % [tag, h.chests.size(), puppets_in("chest").size(), h.pickups.size(), puppets_in("pickup").size(), h.gold.size(), puppets_in("gold").size(), h.hazards, puppets_in("hazard").size(), h.turrets, puppets_in("turret").size(), h.guards, puppets_in("guard").size()],
		h.chests.size() == puppets_in("chest").size() and h.pickups.size() == puppets_in("pickup").size() and h.gold.size() == puppets_in("gold").size() and h.hazards == puppets_in("hazard").size() and h.turrets == puppets_in("turret").size())
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var rep = root.get_node("Rep")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	print("CLIENT: connecting -> ", net.join_game("127.0.0.1"))
	var t := 0.0
	while !state.ok and t < 8.0:
		await wait(0.1)
		t += 0.1
	print("CLIENT: connected: ", state.ok)
	if !state.ok:
		quit()
		return
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	# wait for the host's "before" record
	t = 0.0
	while load_json("before").is_empty() and t < 40.0:
		await wait(0.5)
		t += 0.5
	await wait(1.5)
	compare(load_json("before"), "BEFORE")
	check("client puppets total: %d" % rep.puppet_count(), rep.puppet_count() > 40)
	var game = root.get_node("Game")
	print("CLIENT: game state: keep ", game.keep_hp, " sectors ", game.sectors_unlocked.size(), " hand ", game.hand.size(), " deck ", game.deck.size())
	check("game state synced (sectors unlocked 6)", game.sectors_unlocked.size() == 6)
	# wait for "after"
	t = 0.0
	while load_json("after").is_empty() and t < 30.0:
		await wait(0.5)
		t += 0.5
	await wait(1.0)
	compare(load_json("after"), "AFTER")
	check("keep hp synced after the change (123): %s" % game.keep_hp, absf(game.keep_hp - 123.0) < 0.5)
	# visuals work: effects arrive as events and puppets draw
	var fx := 0
	for n in view.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx.gd"): fx += 1
	print("CLIENT: sample of puppet scripts: ", puppets_in("structure").map(func(n): return n.kind).slice(0, 5))
	if DisplayServer.get_name() != "headless":
		var cam: Camera2D = view.cam
		cam.position = Vector2(100, 300)
		cam.zoom = Vector2.ONE * 1.6
		await wait(0.8)
		root.get_viewport().get_texture().get_image().save_png("user://rep_client.png")
	quit()
