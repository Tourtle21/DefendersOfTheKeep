extends SceneTree
# Replication test, host side. Run with rep_client.gd (see README): the host builds content,
# writes what exists to user://rep_host.json (before and after changes) for the client to compare.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func record() -> Dictionary:
	var out := {"enemies": [], "structures": [], "generators": [], "chests": [], "pickups": [], "gold": [], "hazards": 0, "turrets": 0, "guards": 0, "breakables": 0, "scenery": 0}
	for n in get_nodes_in_group("net"):
		if !is_instance_valid(n) or n.is_queued_for_deletion() or n.has_meta("net_puppet"): continue
		var base: String = str(n.get_script().resource_path).get_file().get_basename() if n.get_script() != null else str(n.name)
		var pos := [snapped(n.global_position.x, 1.0), snapped(n.global_position.y, 1.0)]
		if n.is_in_group("enemy"): out.enemies.append({"t": base, "pos": pos, "hp": snapped(n.health, 0.1)})
		elif n.is_in_group("structure"): out.structures.append({"t": n.kind, "pos": pos, "tier": n.tier, "hp": snapped(n.hp, 0.1)})
		elif n.is_in_group("generator"): out.generators.append({"res": n.resource, "pos": pos, "level": n.level, "stored": n.stored})
		elif n.is_in_group("chest"): out.chests.append({"kind": n.kind, "pos": pos})
		elif n.is_in_group("pickup"): out.pickups.append({"item": n.item_type, "pos": pos})
		elif n.is_in_group("gold"): out.gold.append({"pos": pos})
		elif n.is_in_group("hazard"): out.hazards += 1
		elif n.is_in_group("turret"): out.turrets += 1
		elif n.is_in_group("guard"): out.guards += 1
		elif n.is_in_group("breakable"): out.breakables += 1
		else: out.scenery += 1
	return out
## Stop everything that changes by itself so host and client can be compared exactly.
func freeze(world) -> void:
	for t in get_nodes_in_group("turret"): t.set_process(false)
	for s in get_nodes_in_group("structure"): s.set_physics_process(false)
	for g in get_nodes_in_group("guard"): g.set_physics_process(false)
	for c in get_nodes_in_group("gold"): c.set_process(false); c.set_physics_process(false)
	for c in get_nodes_in_group("chest"): c.set_process(false)
	for g in get_nodes_in_group("generator"): g.set_process(false)

func save(name: String) -> void:
	var f := FileAccess.open("user://rep_host_%s.json" % name, FileAccess.WRITE)
	f.store_string(JSON.stringify(record()))
	f.close()
func _initialize() -> void:
	for n in ["before", "after"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rep_host_%s.json" % n))     # a stale file would let the client compare too early
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	print("HOST: listening -> ", net.host_game())
	for i in 40:
		await wait(0.5)
		if net.remote_players.size() > 0: break
	print("HOST: client joined: ", net.remote_players.size() > 0)
	await wait(2.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for id in ["se", "ne", "n", "nw", "sw"]: sm.unlock(id)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	await wait(0.3)
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.resources = {"stone": 40, "stick": 40, "gold": 40, "iron": 10, "frost": 10, "ember": 10, "moss": 10, "gem": 10}
	var plan := [["barricade", Vector2(40, 330)], ["sentry", Vector2(80, 330)], ["sentry", Vector2(80, 330)], ["spike_trap", Vector2(120, 330)], ["iron_wall", Vector2(160, 330)], ["mender", Vector2(200, 330)]]
	for p in plan:
		game.hand = [p[0]]
		game.cast(p[0], p[1], player)
		await wait(1.1)
	game.hand = ["guards"]
	game.cast("guards", Vector2(0, 280), player)
	var types := ["golem", "frost_imp", "crystal_guard", "scarab", "blobbert", "brute"]
	var x := -150.0
	for t in types:
		var e = load("res://enemies/%s/%s.tscn" % [t, t]).instantiate()
		e.position = Vector2(x, 400)
		world.get_node("Enemies").add_child(e)
		e.set_physics_process(false)
		e.get_node("NavigationTimer").stop()
		x += 40.0
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(-80, 260)
	world.add_child(chest)
	load("res://collectables/gold/gold_coin.gd").spawn(world, Vector2(-100, 260), 3)
	var gen = null
	for g in get_nodes_in_group("generator"):
		if g.resource == "stone": gen = g
	game.carried = {"gold": 30}
	gen.use()
	gen.stored = 7
	var thing = load("res://tools/tests/fixtures/new_thing.gd").new()
	thing.position = Vector2(0, 360)
	thing.label = "hello"
	thing.count = 3
	world.add_child(thing)
	await wait(1.5)
	freeze(world)
	await wait(1.5)
	save("before")
	print("HOST: before saved: ", JSON.stringify(record()).length(), " bytes, net nodes ", get_nodes_in_group("net").size())
	await wait(5.0)
	# changes: damage an enemy, kill a structure, upgrade the generator, a boss wakes
	for e in get_nodes_in_group("enemy"):
		if !e.is_in_group("boss") and str(e.get_script().resource_path).ends_with("brute.gd"): e.spell_damage(3.0, "pierce")
		if str(e.get_script().resource_path).ends_with("scarab.gd"): e.queue_free()
	for s in get_nodes_in_group("structure"):
		if s.kind == "barricade": s.queue_free()
	game.carried = {"gold": 99, "stone": 99}
	gen.stored = 0
	gen.use()
	game.hand = ["frost_totem"]
	game.cast("frost_totem", Vector2(240, 330), player)
	game.keep_hp = 123.0
	thing.count = 9
	thing.label = "changed"
	thing._hidden = 7
	await wait(2.0)
	freeze(world)
	await wait(2.0)
	save("after")
	print("HOST: after saved, keep ", game.keep_hp)
	await wait(10.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
