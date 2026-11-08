extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
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
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	print("cards before sector unlocks: ", game.unlocked_cards)
	for id in ["se", "ne", "n", "nw", "sw"]:
		sm.unlock(id)
	print("cards after: ", game.unlocked_cards)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	game.enter_base(player)
	game.resources = {"stone": 0, "stick": 0, "gold": 0, "iron": 5, "frost": 5, "ember": 5, "moss": 5, "gem": 5}
	var P := Vector2(0, 180)
	for id in ["sandstorm", "blizzard", "lava_pool", "poison_cloud", "crystal_spikes"]:
		game.mana = 100
		game.hand = [id]
		var d = dummy(world, P + Vector2(0, 40))
		var cost_res = game.CARDS[id].res
		var before = game.resources.duplicate()
		print(id, " cast: ", game.cast(id, P + Vector2(0, 40), player))
		await wait(3.0)
		print("   dmg ", snapped(10.0 - (d.health if is_instance_valid(d) else 0.0), 0.1), " slow_mult now ", d.slow_mult if is_instance_valid(d) else "dead", " | resource spent: ", cost_res, " left ", before)
		for e in world.get_node("Enemies").get_children():
			e.queue_free()
		await wait(0.2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
