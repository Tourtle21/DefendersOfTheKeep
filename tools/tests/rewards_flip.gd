extends SceneTree
# Window test: the end-of-run reward screen with face-down cards, then flipping them.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {}
	game.meta.weapons = []
	game.meta.pending = []
	if "spare" in OS.get_cmdline_user_args():
		game.meta.card_tiers = {}
		for id in game.CARDS:
			if !game.is_legendary_card(id):
				if !(id in game.meta.unlocked): game.meta.unlocked.append(id)
				game.meta.card_tiers[id] = 2
		game.meta["best_level"] = 6
		game.meta.pending = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	if "spare" in OS.get_cmdline_user_args():
		game.meta.pending = []
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	game.run_stats = {"kills": 80, "gold": 200, "waves": 12, "bosses": 5}
	if "win" in OS.get_cmdline_user_args():
		game.win_run()
	else:
		game.end_run("You fell in battle")
	await wait(1.0)
	var ui = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("run_end_ui.gd"): ui = c
	await wait(0.25)
	root.get_viewport().get_texture().get_image().save_png("user://rewards_dealing.png")
	await wait(1.5)
	root.get_viewport().get_texture().get_image().save_png("user://rewards_facedown.png")
	print("face-down rewards: ", ui._flippers.size(), " | rarities: ", ui._rewards.map(func(e): return game.rarity_name(game.rarity_of(e.kind, str(e.id)))))
	# flip two by hand, then the rest
	ui._flippers[0].call()
	await wait(0.9)
	root.get_viewport().get_texture().get_image().save_png("user://rewards_one_flipped.png")
	ui._flip_all()
	for i in 14:
		await wait(0.9)
		root.get_viewport().get_texture().get_image().save_png("user://rewards_seq_%02d.png" % i)
	print("best pull: ", ui.pull_label.text, " | visible ", ui.pull_label.visible)
	quit()
