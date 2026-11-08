extends SceneTree
# Enemies and bosses get around towers/trees/rocks/barricades. Same layout, with and without the carved navigation.
var world
var game
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func towers() -> Array:
	var out := []
	for t in get_nodes_in_group("nav_obstacle"):
		if str(t.scene_file_path).ends_with("tower.tscn"): out.append(t)
	return out
func run_enemies(label: String, seconds: float) -> void:
	for e in world.get_node("Enemies").get_children(): e.queue_free()
	await wait(0.2)
	var center := Vector2(0, 50)
	var list := []
	for t in towers():
		var dir: Vector2 = (t.global_position - center).normalized()
		var e = load("res://enemies/goblin/goblin.tscn").instantiate()
		e.position = t.global_position + dir * 50.0
		world.get_node("Enemies").add_child(e)
		e.speed = 30
		e.max_health = 9999.0
		e.health = 9999.0
		list.append(e)
	var arrived := {}
	var t := 0.0
	while t < seconds:
		await wait(0.25)
		t += 0.25
		for i in list.size():
			if is_instance_valid(list[i]) and !arrived.has(i) and list[i].global_position.distance_to(center) < 22.0:
				arrived[i] = t
	var times := []
	for i in list.size(): times.append(snapped(arrived.get(i, -1.0), 0.1))
	var finals := []
	for e in list:
		if is_instance_valid(e):
			finals.append("%s->%s navfin=%s dist_to_target=%.0f" % [Vector2(snapped(e.global_position.x, 1.0), snapped(e.global_position.y, 1.0)), Vector2(snapped(e.nav_agent.target_position.x, 1.0), snapped(e.nav_agent.target_position.y, 1.0)), e.nav_agent.is_navigation_finished(), e.nav_agent.distance_to_target()])
	print("   final positions: ", finals)
	print("%-28s %d of %d enemies reached the keep in %.0fs, arrival times %s (-1 = never)" % [label, arrived.size(), list.size(), seconds, times])
func run_boss(label: String, seconds: float) -> void:
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	var boss = sm._bosses["s"]
	var t0 = towers()[0]
	var center := Vector2(0, 50)
	var dir: Vector2 = (t0.global_position - center).normalized()
	boss.global_position = t0.global_position + dir * 60.0
	boss.max_health = 99999.0
	boss.health = 99999.0
	boss.awake = true
	boss._state = "chase"
	boss._timer = 999.0
	boss.speed = 40.0
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.visible = true
	var player = world.get_node("Player")
	player.global_position = Vector2(0, 110) if t0.global_position.y < 0 else center + (-dir) * 20.0          # the player is on the far side of the tower
	boss.attacks = []                                          # chase only
	boss._unstick = load("res://enemies/unstick.gd").new()
	var best := 9999.0
	var t := 0.0
	while t < seconds:
		await wait(0.25)
		t += 0.25
		best = minf(best, boss.global_position.distance_to(player.global_position))
	print("%-28s boss started behind a tower; closest it got to the player: %.0f px (state %s)" % [label, best, boss._state])
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	game.keep_hp = 99999.0
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	var builder = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("nav_builder.gd"): builder = c
	print("towers ", towers().map(func(t): return t.global_position), " obstacles ", get_nodes_in_group("nav_obstacle").size(), " navmesh bakes ", builder.bakes)
	player.is_in_tower = true
	game.enter_base(player)
	player.global_position = Vector2(0, 110)       # off the pressure plate (it raises the crystal)
	await run_enemies("NEW carved navigation", 25.0)
	await run_boss("NEW carved navigation", 20.0)
	# old behaviour: tile navigation back on, carved polygon off
	builder.queue_free()
	world.get_node("GrassTilemap").navigation_enabled = true
	await wait(0.5)
	var unstick = load("res://enemies/unstick.gd")
	unstick.enabled = false
	await run_enemies("OLD (no carving, no unstick)", 25.0)
	await run_boss("OLD (no carving, no unstick)", 20.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
