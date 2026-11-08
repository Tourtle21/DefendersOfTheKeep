extends SceneTree
const OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	player.shield_time = 99999.0
	var picked = [{"name": "blobbert", "amount": 2, "level": 1}, {"name": "goblin", "amount": 1, "level": 1}]
	print("--- wave plan growth (1 sector unlocked)")
	for w in range(1, 11):
		game.run_stats.waves = w
		var plan = world.wave_plan(picked)
		var parts := []
		var total := 0
		for e in plan:
			parts.append("%d %s L%d" % [e.amount, e.name, e.level])
			total += e.amount
		print("wave %2d: %2d enemies  (%s)" % [w, total, ", ".join(parts)])
	game.sectors_unlocked = ["s", "se", "ne"]
	game.run_stats.waves = 5
	print("--- spawn wave 6 with 3 sectors open")
	world.spawn_enemies(picked)
	world.get_node("SpawnTimer").stop()
	await wait(0.2)
	var by_kind := {}
	var by_dir := {}
	for e in world.get_node("Enemies").get_children():
		var k = str(e.get_script().resource_path).get_file()
		by_kind[k] = by_kind.get(k, 0) + 1
		var ang = snapped(fposmod(rad_to_deg(e.position.angle()), 360.0), 30.0)
		by_dir[ang] = by_dir.get(ang, 0) + 1
	print("kinds: ", by_kind)
	print("directions (deg, 90=south 30=SE 330=NE): ", by_dir)
	await wait(0.1)
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.2)

	print("--- turrets")
	game.sectors_unlocked = ["s"]
	var tower = world.get_node("Tower2")
	var turret = null
	for c in tower.get_children():
		if c.is_in_group("turret"): turret = c
	print("turrets in world: ", get_nodes_in_group("turret").size(), " ammo ", turret.ammo)
	var d = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	d.position = Vector2(0, 150 + 90)
	world.get_node("Enemies").add_child(d)
	d.set_physics_process(false)
	d.get_node("NavigationTimer").stop()
	d.max_health = 40.0
	d.health = 40.0
	await wait(4.0)
	print("after 4s: ammo ", turret.ammo, " target hp ", snapped(d.health, 0.1), " (turret shot it)")
	turret.ammo = 0
	var hp_before = d.health
	await wait(2.0)
	print("empty turret stays silent: hp change ", snapped(hp_before - d.health, 0.1))
	game.resources.stick = 5
	print("reload outside the keep refused: ", not turret.reload())
	game.enter_base(player)
	print("reload in keep: ", turret.reload(), " ammo ", turret.ammo, " sticks left ", game.resources.stick)
	turret.ammo = 3
	game.resources.stick = 1
	print("not enough sticks refused: ", not turret.reload())
	game.resources.stick = 4
	# a real click on the tower in the wide view
	player.base_zoom = 2.0
	await wait(0.4)
	root.warp_mouse(root.get_canvas_transform() * (tower.global_position + Vector2(0, -16)))
	await wait(0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = root.get_mouse_position()
	Input.parse_input_event(ev)
	await wait(0.3)
	print("real click on the tower reloaded it: ammo ", turret.ammo, " sticks ", game.resources.stick)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + "turrets.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
