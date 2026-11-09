extends SceneTree
## Enemy pathfinding covers only the playable ground: paths never cross the grey locked area, enemies still reach the keep,
## and a newly opened sector joins the map.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://np2_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var map: RID = world.get_world_2d().navigation_map
	await wait(0.3)
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, Vector2(0, 1100), Vector2(0, 40), true)
	var inside := path.size() > 2 and path.size() > 0
	for p in path:
		if !game.in_playable(p): inside = false
	print("  path from the grassland's far end: %d points, ends at %s" % [path.size(), path[path.size() - 1].round() if path.size() > 0 else "none"])
	ok("a route from the grassland to the keep exists and stays on the playable ground", inside and path[path.size() - 1].length() < 60.0)
	var grey: PackedVector2Array = NavigationServer2D.map_get_path(map, Vector2(700, -700), Vector2(0, 40), true)
	var crosses := false
	for p in grey:
		if !game.in_playable(p) and p.distance_to(Vector2(700, -700)) > 40.0: crosses = true
	ok("from the locked grey ground there is no route that crosses it (%d points)" % grey.size(), !crosses)
	# an enemy still walks to the keep
	var e = load("res://enemies/goblin/goblin.tscn").instantiate()
	e.position = Vector2(0, 700)
	world.get_node("Enemies").add_child(e)
	await wait(0.3)
	var d0: float = e.global_position.distance_to(e.center)
	await wait(5.0)
	var d1: float = e.global_position.distance_to(e.center) if is_instance_valid(e) else 0.0
	print("  enemy distance to the keep: %.0f -> %.0f" % [d0, d1])
	ok("an enemy still walks to the keep along the new map", d1 < d0 - 60.0)
	# a new sector opens: it joins the walkable map
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	var far_se := Vector2(0, 600).rotated(deg_to_rad(game.SECTOR_ANGLES["se"] - 90.0))
	var before: PackedVector2Array = NavigationServer2D.map_get_path(map, far_se, Vector2(0, 40), true)
	sm.unlock("se")
	await wait(0.6)
	var after: PackedVector2Array = NavigationServer2D.map_get_path(map, far_se, Vector2(0, 40), true)
	print("  route from the desert: %d points before it opened, %d after" % [before.size(), after.size()])
	ok("once the desert opens there is a route from it to the keep", after.size() > 1 and after[after.size() - 1].length() < 60.0)
	quit()
