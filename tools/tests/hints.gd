extends SceneTree
# First-run tips: each fires when relevant, once, persists, and can be switched off.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta = {"shards": 0, "unlocked": ["fireball", "frost_ring"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var hints = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("hints.gd"): hints = c
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	var player = world.get_node("Player")
	var hud = world.get_node("Hud")
	var info = load("res://world/item_info.tres")
	var order := []
	var step := func(label: String):
		hints._showing = 0.0
		await wait(0.8)
		hints._showing = 0.0
		print("%-22s -> %s" % [label, "(shown) " + hints.label.text.substr(0, 60) if hints.panel.visible else "(nothing)"])
	hints._t = 13.0
	await step.call("12s with no weapon")
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	hud.equip_item(info.items["spear"])
	player.equip_item(info.items["spear"])
	await step.call("weapon equipped")
	hints._t = 100.0
	hints._weapon_since = 70.0      # equipped 30 seconds ago
	await step.call("18s, nothing gathered")
	game.carried.stone = 3
	await step.call("carrying 3 resources")
	game.enter_base(player)
	await step.call("entered the keep")
	game.exit_base(player)
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(60, 60)
	world.add_child(chest)
	await step.call("a chest appears")
	load("res://collectables/gold/gold_coin.gd").spawn(world, Vector2(40, 40), 1)
	await step.call("a coin drops")
	game.run_stats.waves = 1
	await step.call("a wave starts")
	hud.equip_item(info.items["hammer"])
	await step.call("a second weapon")
	game.keep_hp = 40.0
	await step.call("keep below half")
	print("tips seen (in order): ", game.meta.hints_seen)
	print("each shown once: ", game.meta.hints_seen.size() == (game.meta.hints_seen.duplicate() as Array).filter(func(x): return true).size())
	game.load_meta()
	print("saved to disk: ", game.meta.hints_seen.size(), " tips")
	hints.hint("pickup")
	print("a seen tip is not queued again: ", hints._queue.is_empty())
	game.meta.hints_seen.erase("cards")
	game.meta["hints_enabled"] = false
	hints.hint("cards")
	print("tips off -> nothing queued: ", hints._queue.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
