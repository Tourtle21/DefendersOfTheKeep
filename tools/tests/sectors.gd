extends SceneTree
const OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	var announced := []
	game.announce.connect(func(t): announced.append(t))
	print("sector bosses: ", sm._bosses.keys(), " props+bosses under manager: ", sm.get_child_count())
	print("gate before: south ", game.gate_open(deg_to_rad(90)), " east-south-east ", game.gate_open(deg_to_rad(30)), " north ", game.gate_open(deg_to_rad(270)))

	# --- fight the first boss
	var boss = sm._bosses["s"]
	print("boss: ", boss.boss_name, " at ", boss.position, " hp ", boss.health)
	player.position = boss.position + Vector2(0, -180)
	await wait(0.5)
	for t in 8:
		player.shield_time = 5.0
		player.position = boss.position + Vector2(0, -110)
		await wait(0.8)
	print("boss awake: ", boss.awake, " state ", boss._state, " last attack ", boss._attack, " | announcements: ", announced)
	boss.spell_damage(boss.max_health * 0.55)
	print("enraged at half hp: ", boss.enraged)
	await shot("sec_boss")
	boss.spell_damage(9999)
	await wait(0.6)
	print("boss dead -> unlocked: ", game.sectors_unlocked, " | cover hidden: ", not world.get_node("CanvasLayer/Polygon2D6").visible, " | gate 30deg open: ", game.gate_open(deg_to_rad(30)), " | bosses: ", game.run_stats.bosses)
	var scarabs := 0
	for e in get_nodes_in_group("enemy"):
		if e.get_script() and str(e.get_script().resource_path).ends_with("scarab.gd"): scarabs += 1
	print("sector natives spawned: ", scarabs, " | announcements: ", announced.slice(-2))
	print("coins dropped by boss: ", get_nodes_in_group("gold").size(), " chests: ", get_nodes_in_group("chest").size())

	# --- walk out of the keep through the new gate
	player.position = Vector2(60, 36)
	await wait(0.3)
	Input.action_press("move_right")
	await wait(1.6)
	Input.action_release("move_right")
	print("walked east through the new gate: x = ", snapped(player.position.x, 1), " (>120 means the gate works)")
	player.position = Vector2(0, -60)
	Input.action_press("move_up")
	await wait(1.6)
	Input.action_release("move_up")
	print("walking north is still blocked: y = ", snapped(player.position.y, 1), " (stays near -120)")

	# --- desert look + mining iron
	var ore = null
	for c in sm.find_children("*", "StaticBody2D", true, false):
		if c.get("drop_type") == "iron": ore = c
	print("iron ore nodes exist: ", ore != null)
	player.position = Vector2(300, 175)
	player.shield_time = 99.0
	await wait(0.6)
	await shot("sec_desert")
	if ore:
		var drops_before := get_nodes_in_group("gold").size()
		ore.global_position = player.global_position + Vector2(20, 0)
		for i in 20:
			if !is_instance_valid(ore): break
			ore.take_damage(player.global_position)
			await wait(0.1)
		await wait(0.4)
		var iron_pickups := 0
		for c in world.get_children():
			if c is Area2D and c.get("item_type") == "iron": iron_pickups += 1
		for c in sm.find_children("*", "Area2D", true, false):
			if c.get("item_type") == "iron": iron_pickups += 1
		print("mined ore dropped iron pickups: ", iron_pickups)

	# --- the rest of the chain and the final boss
	for id in ["se", "ne", "n", "nw", "sw"]:
		sm._bosses[id].spell_damage(99999)
		await wait(0.2)
	print("all sectors unlocked: ", game.sectors_unlocked)
	var final = null
	for b in get_nodes_in_group("boss"):
		if b.boss_name == "The Devourer": final = b
	print("final boss spawned: ", final != null, " announcements: ", announced.slice(-2))
	final.spell_damage(99999)
	await wait(0.5)
	print("run over after final boss: ", game.run_over, " bosses beaten: ", game.run_stats.bosses, " shards this run would be ", game.meta.shards)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
