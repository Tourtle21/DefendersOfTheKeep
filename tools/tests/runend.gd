extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	game.meta = {"shards": 0, "unlocked": ["fireball", "frost_ring"], "best_wave": 0}
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	print("fresh run: unlocked cards ", game.unlocked_cards, " deck ", game.deck)
	# play a little: two waves, some kills and gold
	world.spawn_enemies([{"name": "blobbert", "amount": 4, "level": 1}])
	world.get_node("SpawnTimer").stop()
	world.spawn_enemies([{"name": "goblin", "amount": 2, "level": 1}])
	world.get_node("SpawnTimer").stop()
	await wait(0.2)
	for e in world.get_node("Enemies").get_children():
		e.spell_damage(999)
	await wait(0.3)
	game.pick_up_resource("gold")
	game.add_resource("gold", 3)
	print("stats: ", game.run_stats, " shards would be ", game.shards_for_run())
	# die
	var hp = world.get_node("Hud/Control2/ColorRect/Health")
	for i in 12:
		player.shield_time = 0.0
		player.is_taking_damage = false
		player.take_damage(Vector2(0, 100))
		await wait(0.05)
		if game.run_over: break
	await wait(0.3)
	var ui = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("run_end_ui.gd"): ui = c
	print("run over: ", game.run_over, " paused: ", paused, " ui visible: ", ui.root_ctl.visible, " title: ", ui.title.text)
	print("meta after: ", game.meta, " save file exists: ", FileAccess.file_exists("user://test_save.json"))
	root.get_viewport().get_texture().get_image().save_png("user://run_end.png")
	# buy an unlock (gold magnet costs 5)
	game.meta.shards = max(game.meta.shards, 5)
	print("buy gold_magnet: ", game.buy_unlock("gold_magnet"), " shards left ", game.meta.shards, " | too poor for aegis: ", game.buy_unlock("aegis") if game.meta.shards < 8 else "n/a")
	game.load_meta()
	print("after reload from disk, unlocked: ", game.unlocked_cards)
	game.start_run()
	print("new run: unlocked ", game.unlocked_cards, " run_over ", game.run_over, " stats ", game.run_stats)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
