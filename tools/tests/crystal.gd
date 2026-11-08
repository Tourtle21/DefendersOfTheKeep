extends SceneTree
# Crystal theft: raised by the plate, stolen by an enemy once fully up, base powers offline until it is back.
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
	var crystal = world.get_node("Well/Crystal")
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	for tur in get_nodes_in_group("turret"): tur.ammo = 0        # a turret in range would shoot the test thief
	print("start: crystal state ", crystal.state, ", y ", crystal.position.y, ", visible ", crystal.visible, " | base powers away? ", game.crystal_away())
	# an enemy at the Well while the crystal is still down: nothing is stolen
	var e1 = load("res://enemies/goblin/goblin.tscn").instantiate()
	e1.position = crystal.global_position
	world.get_node("Enemies").add_child(e1)
	e1.set_physics_process(false)
	for i in 10:
		await wait(0.1)
		if !is_instance_valid(e1):
			print("   e1 freed at t=", i * 0.1)
			break
	print("enemy touching the Well while the crystal is lowered -> state ", crystal.state)
	# the plate raises it
	world.get_node("Well").activate()
	var t := 0.0
	while crystal.position.y > crystal.ending_position + 0.5 and t < 8.0:
		await wait(0.1)
		t += 0.1
	print("raised after ", snapped(t, 0.1), "s: y ", snapped(crystal.position.y, 0.1), " visible ", crystal.visible)
	await wait(0.6)
	print("enemy at the fully raised crystal -> state ", crystal.state, ", thief has_crystal ", e1.has_crystal, ", exit point ", crystal.exit_point.round())
	# base powers offline
	if DisplayServer.get_name() != "headless":
		player.global_position = crystal.global_position + Vector2(40, 60)
		for c in world.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
		await wait(0.8)
		root.get_viewport().get_texture().get_image().save_png("user://crystal_alert.png")
	game.enter_base(player)
	game.mana = 10.0
	game.hand = ["fireball"]
	game.resources = {"stone": 10, "stick": 10, "gold": 10}
	print("powers offline: away ", game.crystal_away(), " | can cast ", game.can_cast("fireball"), " | repair ", game.repair_keep())
	var m0: float = game.mana
	await wait(1.0)
	print("mana after 1s away: ", snapped(game.mana, 0.1), " (was ", m0, ", no regen)")
	var turret = get_nodes_in_group("turret")[0]
	print("turret online while away: ", turret.online())
	# kill the thief: the crystal drops
	e1.global_position = Vector2(60, 120)
	await wait(0.3)
	e1.spell_damage(9999.0)
	await wait(0.5)
	print("thief killed -> crystal state ", crystal.state, " at ", crystal.global_position.round())
	# a player walks over it, then back to the Well
	game.exit_base(player)
	player.is_in_tower = false
	player.global_position = crystal.global_position
	await wait(0.4)
	print("player on the crystal -> state ", crystal.state, ", player.has_crystal ", player.has_crystal)
	player.global_position = Vector2(8, 10)
	await wait(0.5)
	print("player at the Well -> state ", crystal.state, " | away ", game.crystal_away(), " | y ", crystal.position.y)
	game.enter_base(player)
	game.mana = 100.0
	game.hand = ["fireball"]
	var south = null
	for tur in get_nodes_in_group("turret"):
		if tur.get_parent().position == Vector2(0, 150): south = tur
	print("powers back: can cast ", game.can_cast("fireball"), " | south turret online ", south.online())
	# a thief that reaches the edge loses the run
	world.get_node("Well").activate()
	await wait(4.0)
	var e2 = load("res://enemies/goblin/goblin.tscn").instantiate()
	e2.position = crystal.global_position
	world.get_node("Enemies").add_child(e2)
	e2.set_physics_process(false)
	await wait(0.6)
	var state := {"over": ""}
	game.run_ended.connect(func(info): state.over = info.reason)
	e2.global_position = crystal.exit_point + Vector2(10, 0)
	e2.make_path()
	await wait(0.4)
	print("thief reaching the edge -> run ended: '", state.over, "'")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
