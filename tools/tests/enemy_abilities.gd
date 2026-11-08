extends SceneTree
# Biome enemy abilities and the crush element.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func make(world, type: String, pos: Vector2):
	var e = load("res://enemies/%s/%s.tscn" % [type, type]).instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
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
	player.global_position = Vector2(-300, 250)       # keep away from the imps' patches
	# frost imp leaves freezing ground
	var f = make(world, "frost_imp", Vector2(-40, 250))
	f.set_physics_process(false)
	var before := get_nodes_in_group("hazard").size()
	f.spell_damage(99.0, "fire")
	await wait(0.3)
	var slow_patch = null
	for h in get_nodes_in_group("hazard"):
		if h.global_position.distance_to(Vector2(-40, 250)) < 3.0: slow_patch = h
	print("frost imp death: patch kind ", slow_patch.kind if slow_patch else "none", " lifetime ", slow_patch.lifetime if slow_patch else 0)
	# ember imp leaves burning ground
	var m = make(world, "ember_imp", Vector2(40, 250))
	m.set_physics_process(false)
	m.spell_damage(99.0, "ice")
	await wait(0.3)
	var burn_patch = null
	for h in get_nodes_in_group("hazard"):
		if h.global_position.distance_to(Vector2(40, 250)) < 3.0: burn_patch = h
	print("ember imp death: patch kind ", burn_patch.kind if burn_patch else "none")
	# golem stomp hurts a player next to it
	var g = make(world, "golem", Vector2(0, 330))
	player.global_position = Vector2(0, 345)
	g.speed = 0
	var hr = world.get_node("Hud/Control2/ColorRect/Health")
	var hp0: float = hr.size.x
	await wait(6.5)
	print("golem stomp: player health bar ", snapped(hp0, 0.1), " -> ", snapped(hr.size.x, 0.1), " (lost health to the stomp)")
	g.queue_free()
	player.global_position = Vector2(-300, 250)
	# crystal guard shield
	var c = make(world, "crystal_guard", Vector2(0, 250))
	c.set_physics_process(false)
	c.health = 1000.0
	c.max_health = 1000.0
	var d1 := 0.0
	var t0: float = c.health
	c.spell_damage(3.0, "")
	print("crystal guard: shield ", c.shield, " after a 3 hit (armor 2.5 left 0.75 hmm shield soaks): health lost ", snapped(t0 - c.health, 0.01))
	t0 = c.health
	c.spell_damage(10.0, "")
	print("  10 phys: lost ", snapped(t0 - c.health, 0.01), " shield now ", c.shield)
	t0 = c.health
	c.spell_damage(10.0, "pierce")
	print("  10 pierce (ignores armor and shield): lost ", snapped(t0 - c.health, 0.01))
	c.set_physics_process(true)
	c._regrow = 7.9
	await wait(0.5)
	print("  shield regrown after the pause: ", c.shield)
	c.queue_free()
	# crush vs armor
	var b = make(world, "brute", Vector2(0, 250))
	b.set_physics_process(false)
	b.health = 1000.0
	b.max_health = 1000.0
	var res := {}
	for el in ["", "crush", "pierce"]:
		b.health = 1000.0
		b.spell_damage(4.0, el)
		res[el if el != "" else "phys"] = snapped(1000.0 - b.health, 0.01)
	print("brute (armor 2) taking 4: ", res)
	var info = world.get_node("Collectable").item_info
	for w in ["hammer", "quakepick", "bulwark", "juggernaut", "earthshaker", "worldbreaker"]:
		player.equip_item(info.items[w])
		await wait(0.15)
		print("weapon ", w, " element: ", player.item.element)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
