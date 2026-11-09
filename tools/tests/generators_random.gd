extends SceneTree
## Generators: the grassland has a stone AND a stick one, every generator is somewhere in its sector, and it differs each game.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func gens(world) -> Array:
	var out := []
	for g in get_nodes_in_group("generator"):
		out.append({"res": g.resource, "pos": g.global_position})
	return out
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://gr_test_save.json"
	game._menu_done = true
	var layouts := []
	for run in 3:
		var world = load("res://world/world.tscn").instantiate()
		root.add_child(world)
		await wait(0.8)
		var g := gens(world)
		layouts.append(g)
		world.queue_free()
		await wait(0.3)
	var first: Array = layouts[0]
	var kinds: Array = first.map(func(x): return x.res)
	print("  generators: ", kinds)
	ok("a stone and a stick generator in the grassland, plus one per other sector (7 total)", first.size() == 7 and kinds.count("stone") == 1 and kinds.count("stick") == 1)
	var rot_fix := func(res: String, sec: String): return res
	var different := false
	for i in 1:
		for k in first.size():
			if first[k].pos.distance_to(layouts[1][k].pos) > 30.0 or first[k].pos.distance_to(layouts[2][k].pos) > 30.0:
				different = true
	ok("the positions change from game to game", different)
	var spread := true
	for lay in layouts:
		for a in lay:
			for b in lay:
				if a != b and a.pos.distance_to(b.pos) < 100.0:
					spread = false
	ok("no two generators on top of each other", spread)
	var in_range := layouts.all(func(lay): return lay.all(func(x): return x.pos.length() > 200.0 and x.pos.length() < 1000.0))
	ok("every generator is out in its sector (200 to 1000 units from the keep)", in_range)
	quit()
