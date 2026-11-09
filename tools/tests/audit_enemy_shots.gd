extends SceneTree
## Window screenshots of the enemy changes: the "!", the lunge wind-up line, a brute's slam ring, elites, the ember trail.
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
func spawn(world, name: String, pos: Vector2):
	var e = load("res://enemies/%s/%s.tscn" % [name, name]).instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	return e
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window (screenshots); skipping")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	game.save_path = "user://audit_save.json"
	game._menu_done = true
	game._local_devices = []
	game.sectors_unlocked = ["s", "se", "ne", "n"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	p.global_position = Vector2(0, 330)
	await wait(1.2)
	# 1. a lunge wind-up (blobbert + scarab)
	var a = spawn(world, "blobbert", p.global_position + Vector2(-60, -20))
	var b = spawn(world, "scarab", p.global_position + Vector2(55, 25))
	for e in [a, b]:
		e.ability_cd = 0.0
		e.start_aggro(p)
	await wait(0.35)
	await shot("e1_lunge_windup")
	await wait(1.6)
	a.queue_free(); b.queue_free()
	# 2. brute slam telegraph and the "!" alert
	var br = spawn(world, "brute", p.global_position + Vector2(32, 0))
	br.ability_cd = 0.0
	br.start_aggro(p)
	await wait(0.4)
	await shot("e2_brute_slam")
	await wait(1.4)
	br.queue_free()
	# 3. elites
	var xs := [-70, -35, 0, 35, 70]
	var els := []
	for i in 3:
		var g = spawn(world, "goblin", p.global_position + Vector2(-50 + i * 50, -60))
		els.append(g)
		await wait(0.1)
		g.apply_affix(["shielded", "hasty", "leeching"][i])
	var plain = spawn(world, "goblin", p.global_position + Vector2(0, -100))
	for g in els + [plain]:
		g.set_physics_process(false)
	await wait(0.3)
	await shot("e3_elites")
	for g in els + [plain]:
		g.queue_free()
	# 4. ember trail and frost bolt
	var em = spawn(world, "ember_imp", p.global_position + Vector2(-90, 20))
	em.start_aggro(p)
	var fi = spawn(world, "frost_imp", p.global_position + Vector2(90, -20))
	fi.ability_cd = 0.0
	fi.start_aggro(p)
	await wait(1.3)
	await shot("e4_trail_and_bolt")
	quit()
