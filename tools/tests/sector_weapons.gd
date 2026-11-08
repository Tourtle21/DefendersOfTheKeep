extends SceneTree
# Sector weapons: each runs all four actions, drops in its sector, fuses, and the helpers work.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var info = load("res://world/item_info.tres")
	var fusion = load("res://items/fusion.gd")
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	# drops when a sector unlocks, and the boss's own weapon
	for id in ["se", "ne", "n", "nw", "sw"]:
		sm.unlock(id)
	await wait(0.3)
	var drops := []
	for c in sm.get_children():
		if c is Area2D and c.get("item_type") != null and !(c.item_type in ["stone", "stick", "iron"]):
			drops.append(c.item_type)
	print("weapon pickups placed in the sectors: ", drops)
	sm._bosses["se"].spell_damage(99999)
	await wait(0.5)
	var boss_drop := []
	for c in sm.get_children():
		if c is Area2D and c.get("item_type") == "scimitar":
			boss_drop.append("scimitar")
	print("desert boss dropped its weapon too (scimitar pickups now ", boss_drop.size(), ")")
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"):
			e.queue_free()
	# recipes
	for pair in [["scimitar", "shield"], ["frostglaive", "spear"], ["emberflail", "hammer"], ["bogstaff", "staff"], ["crystalwand", "staff"]]:
		var r = fusion.recipe(pair[0], pair[1])
		print("%s + %s -> %s (tier %d, cost %s)" % [pair[0], pair[1], r.id, r.tier, fusion.cost(r.tier)])
	var P := Vector2(-40, 260)
	for id in ["scimitar", "frostglaive", "emberflail", "bogstaff", "crystalwand", "sultanguard", "rimelance", "magmamaul", "witchstaff", "prismstaff"]:
		player.equip_item(info.items[id])
		await wait(0.3)
		player.position = P
		player.speed_mult = 1.0
		player.shield_time = 0.0
		player.parry_time = 0.0
		world.get_node("Hud/Control2/ColorRect/Health").size.x = 228.0
		for e in world.get_node("Enemies").get_children():
			e.queue_free()
		await wait(0.1)
		root.warp_mouse(root.get_canvas_transform() * (P + Vector2(120, 0)))
		await wait(0.1)
		var w = player.item
		var ds = [dummy(world, P + Vector2(28, 0)), dummy(world, P + Vector2(58, 5)), dummy(world, P + Vector2(90, -5))]
		w.use_item()
		await wait(0.6)
		w._ability_cd = 0.0
		w.use_ability()
		if id == "sultanguard":
			await wait(0.1)
			player.take_damage(P + Vector2(40, 0))       # land a hit inside the parry window
		await wait(1.2)
		w.use_dash()
		await wait(0.6)
		w.use_ultimate()
		await wait(2.2)
		var total := 0.0
		for e in ds:
			total += 10.0 - (e.health if is_instance_valid(e) else 0.0)
		var patches := 0
		for h in get_nodes_in_group("hazard"):
			if h.lifetime > 0.0:
				patches += 1
		print("%-12s ran all actions, dmg %5.1f, temporary ground patches alive %d | %s / %s / %s / %s" % [id, total, patches, w.attack_name, w.ability_name, w.dash_name, w.ultimate_name])
		for h in get_nodes_in_group("hazard"):
			if h.lifetime > 0.0:
				h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
