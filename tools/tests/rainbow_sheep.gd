extends SceneTree
# Rainbow sheep: spawns, flees, tires, can be hit by weapons/spells/the sword, drops loot, escapes on its own.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var spawner = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("critter_spawner.gd"): spawner = c
	print("spawner timer ~", snapped(spawner.timer.time_left, 1.0), "s to the first sheep")
	var sheep = spawner.spawn_sheep()
	await wait(0.3)
	print("sheep spawned at ", sheep.global_position.round(), " in sector ", game.sector_at(sheep.global_position), " | group critter ", sheep.is_in_group("critter"), " | enemies that turrets see: ", get_nodes_in_group("enemy").filter(func(e): return str(e.get_script().resource_path).ends_with("rainbow_sheep.gd")).size())
	# fleeing: the player walks at it
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	player.global_position = sheep.global_position + Vector2(-60, 0)
	var start_gap: float = player.global_position.distance_to(sheep.global_position)
	var min_gap: float = start_gap
	var max_gap := 0.0
	for i in 20:
		var dir: Vector2 = (sheep.global_position - player.global_position).normalized()
		player.global_position += dir * 14.0           # about 56 px/s chasing
		await wait(0.25)
		var gap: float = player.global_position.distance_to(sheep.global_position)
		min_gap = minf(min_gap, gap)
		max_gap = maxf(max_gap, gap)
	print("chase for 5 s: gap started ", snapped(start_gap, 1.0), ", closest ", snapped(min_gap, 1.0), ", furthest ", snapped(max_gap, 1.0), " (it runs away)")
	# weapons and spells can hit it
	var info = world.get_node("Collectable").item_info
	player.equip_item(info.items["spear"])
	await wait(0.3)
	sheep.global_position = player.global_position + Vector2(20, 0)
	sheep.velocity = Vector2.ZERO
	var load_before := get_nodes_in_group("pickup").size()
	var gold_before := get_nodes_in_group("gold").size()
	var util = load("res://items/weapons/weapon_util.gd")
	print("sheep found by a 40 px weapon circle: ", util.enemies_in_circle(self, player.global_position, 40.0).has(sheep))
	var hp0: float = sheep.health
	sheep.take_damage(Vector2.ZERO)
	print("starting sword hit: ", hp0, " -> ", sheep.health)
	await wait(0.3)
	hp0 = sheep.health
	util.hit(sheep, 3.0, player.global_position)
	print("weapon hit: ", hp0, " -> ", sheep.health)
	game.enter_base(player)
	game.mana = 100
	game.hand = ["fireball"]
	sheep.set_physics_process(false)          # hold still so the fireball lands
	hp0 = sheep.health
	print("cast result ", game.cast("fireball", sheep.global_position, player), " in_base ", game.in_base, " crystal away ", game.crystal_away(), " hand ", game.hand)
	for i in 8:
		await wait(0.4)
		var sp := get_nodes_in_group("net").filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("spell.gd"))
		print("   t+", snapped((i + 1) * 0.4, 0.1), " spells ", sp.size(), sp.map(func(n): return "landed=%s age=%.1f flight=%.1f pos=%s" % [n.landed, n.age, n.flight, n.position.round()]), " sheep hp ", sheep.health if is_instance_valid(sheep) else "-", " sheep pos ", sheep.global_position.round() if is_instance_valid(sheep) else "-")
	print("fireball: ", hp0, " -> ", sheep.health if is_instance_valid(sheep) else "dead")
	if is_instance_valid(sheep):
		sheep.spell_damage(99.0)
	await wait(0.6)
	var sector_resources := get_nodes_in_group("pickup").size() - load_before
	print("killed: gold coins ", get_nodes_in_group("gold").size() - gold_before, ", resource pickups ", sector_resources, ", chests ", get_nodes_in_group("chest").size())
	# escape on its own
	var s2 = spawner.spawn_sheep()
	s2.life = 0.2
	var gone := {"msg": false}
	game.announce.connect(func(t): if t.contains("got away"): gone.msg = true)
	await wait(0.6)
	print("a sheep nobody catches runs off: freed ", !is_instance_valid(s2), ", message shown ", gone.msg)
	if DisplayServer.get_name() != "headless":
		var s3 = spawner.spawn_sheep()
		game.exit_base(player)
		player.global_position = s3.global_position + Vector2(-40, 20)
		for c in world.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
		await wait(1.2)
		root.get_viewport().get_texture().get_image().save_png("user://rainbow_sheep.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
