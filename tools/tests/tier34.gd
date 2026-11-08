extends SceneTree
# Tier 3 / 4 weapons: recipes resolve, costs, each weapon runs all four actions, journal remembers recipes.
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
	game.meta = {"shards": 0, "unlocked": ["fireball", "frost_ring"], "best_wave": 0, "recipes_seen": []}
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var info = load("res://world/item_info.tres")
	var fusion = load("res://items/fusion.gd")
	for pair in [["lance", "rapier"], ["chainfangs", "spellblade"], ["bulwark", "quakepick"], ["spellblade", "tempest"], ["earthshaker", "juggernaut"], ["sword", "bow"]]:
		var r = fusion.recipe(pair[0], pair[1])
		print("%s + %s -> %s  cost %s" % [pair[0], pair[1], r.get("id", "(no recipe)"), fusion.cost(r.tier) if !r.is_empty() else "-"])
	var P := Vector2(-40, 260)
	for id in ["dragoonpike", "soulreaper", "earthshaker", "starfall", "worldbreaker"]:
		player.equip_item(info.items[id])
		await wait(0.3)
		player.position = P
		player.speed_mult = 1.0
		player.shield_time = 0.0
		player.parry_time = 0.0
		world.get_node("Hud/Control2/ColorRect/Health").size.x = 228.0
		for e in world.get_node("Enemies").get_children():
			e.queue_free()
		await wait(0.1)
		root.warp_mouse(root.get_canvas_transform() * (P + Vector2(120, 0)))
		await wait(0.1)
		var w = player.item
		var ds = [dummy(world, P + Vector2(28, 0)), dummy(world, P + Vector2(58, 5)), dummy(world, P + Vector2(90, -5))]
		w.use_item()
		await wait(0.5)
		w._ability_cd = 0.0
		w.use_ability()
		if w.hold_ability:
			await wait(0.6)
			w.release_ability()
		await wait(1.2)
		w.use_dash()
		await wait(0.6)
		w.use_ultimate()
		await wait(2.0)
		var total := 0.0
		for e in ds:
			total += 10.0 - (e.health if is_instance_valid(e) else 0.0)
		print("%-12s ran all actions, dmg %.1f | %s / %s / %s / %s" % [id, total, w.attack_name, w.ability_name, w.dash_name, w.ultimate_name])
	# journal
	var forge = get_first_node_in_group("forge_ui")
	var hud = world.get_node("Hud")
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	hud.equip_item(info.items["spear"])
	hud.equip_item(info.items["hammer"])
	forge.open()
	forge._toggle(0)
	forge._toggle(1)
	print("journal after previewing spear+hammer: ", forge.journal.text.split("\n")[0], " | ", forge.journal.text.split("\n")[1])
	game.load_meta()
	print("saved to disk: ", game.meta.recipes_seen)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
