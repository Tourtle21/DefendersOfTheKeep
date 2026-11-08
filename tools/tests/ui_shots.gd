extends SceneTree
# Window test: collection (legendary card), codex (new weapons) and the Forge numbers.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "sunspire"]
	game.meta.weapons = ["torch", "spear", "scimitar", "dawnbringer"]
	game.meta.card_tiers = {"sunspire": 2}
	game.meta.shards = 300
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	game.run_stats = {"kills": 40, "gold": 60, "waves": 3, "bosses": 0}
	game.end_run("Playtest")
	await wait(0.6)
	var ui = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("run_end_ui.gd"): ui = c
	ui.collection.selected = "meteor_shower"
	ui.collection.open()
	await wait(0.6)
	root.get_viewport().get_texture().get_image().save_png("user://ui_collection.png")
	ui.collection.selected = "sunspire"
	ui.collection._refresh()
	await wait(0.3)
	root.get_viewport().get_texture().get_image().save_png("user://ui_collection_owned.png")
	ui.collection.root_ctl.visible = false
	ui.codex.selected = "torch"
	ui.codex.open()
	await wait(0.6)
	root.get_viewport().get_texture().get_image().save_png("user://ui_codex.png")
	quit()
