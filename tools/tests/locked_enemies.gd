extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var by := {}
	for e in get_nodes_in_group("enemy"):
		var k := "%s | mode %d | vis %s | parent %s" % [e.get_script().resource_path.get_file() if e.get_script() else e.name, e.process_mode, e.is_visible_in_tree(), e.get_parent().name]
		by[k] = by.get(k, 0) + 1
	for k in by: print(by[k], " x ", k)
	var near := []
	for e in get_nodes_in_group("enemy"):
		if e.global_position.length() < 450 and !e.is_in_group("boss"): near.append("%s at %s" % [e.name, e.global_position.round()])
	print("enemies within 450 px of keep: ", near)
	quit()
