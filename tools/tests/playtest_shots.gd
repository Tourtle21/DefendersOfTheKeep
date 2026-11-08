extends SceneTree
# A scripted look at the game: saves screenshots of key moments to user://shots/ (needs a window).
var world
var player
var game
var n := 0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.4)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(1280, int(1280.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://shots")
	n += 1
	img.save_jpg("user://shots/%02d_%s.jpg" % [n, name], 0.85)
	print("saved ", name)
func help_panel(on: bool) -> void:
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = on
func hints_off() -> void:
	game.meta["hints_enabled"] = false
func fight(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var best = null
		for e in get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.visible and (!e.is_in_group("boss")) and (best == null or e.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
				best = e
		if best != null and player.item != null and !best.is_in_group("boss"):
			var d: Vector2 = best.global_position - player.global_position
			player.global_position += d.normalized() * min(d.length() - 14.0, 40.0 * 0.25) if d.length() > 16.0 else Vector2.ZERO
			player.item.aim = d.normalized()
			player.item.use_item()
		await wait(0.25)
		t += 0.25
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	player = world.get_node("Player")
	var info = world.get_node("Collectable").item_info
	# 1. what a new player sees
	await shot("start_with_help")
	help_panel(false)
	player.global_position = Vector2(60, 40)
	await shot("start_world")
	# 2. a weapon in hand, a first wave coming
	player.equip_item(info.items["spear"])
	game.resources = {"stone": 12, "stick": 12, "gold": 14}
	world.spawn_enemies([{"name": "blobbert", "amount": 4, "level": 1}, {"name": "goblin", "amount": 3, "level": 1}])
	world.get_node("SpawnTimer").start(600.0)
	await wait(0.2)
	player.global_position = Vector2(0, 100)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.global_position = Vector2(randf_range(-120, 120), randf_range(170, 260))
	await wait(1.0)
	await shot("wave_arrives")
	await fight(2.5)
	await shot("fighting")
	# 3. cooldown HUD after using moves
	player.item.use_dash()
	player.item._attack_cd = 0.3
	player.item._ult_cd = 40.0
	await wait(0.5)
	await shot("cooldown_hud")
	# 4. in the keep: cards, builds, a cast
	game.enter_base(player)
	player.is_in_tower = true
	game.mana = 90
	game.hand = []
	for id in ["fireball", "frost_ring", "barricade", "spike_trap", "sentry"]:
		game.add_to_group_dummy if false else null
		game.add_to_hand(id)
	game.unlocked_cards.append("sentry")
	game.resources = {"stone": 20, "stick": 20, "gold": 20}
	game.hand_changed.emit()
	await wait(0.8)
	await shot("keep_hand")
	for p in [["barricade", Vector2(-30, 190)], ["spike_trap", Vector2(20, 200)], ["sentry", Vector2(60, 185)]]:
		game.hand = [p[0]]
		game.cast(p[0], p[1], player)
		await wait(1.0)
	game.hand = ["fireball"]
	game.mana = 80
	game.cast("fireball", Vector2(10, 230), player)
	await wait(1.6)
	await shot("keep_buildings")
	# 5. a new biome with its own enemies and generator
	game.exit_base(player)
	player.is_in_tower = false
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	sm.unlock("se")
	await wait(0.5)
	player.global_position = Vector2(280, 560)
	await wait(1.2)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"):
			e.global_position = player.global_position + Vector2(randf_range(-70, 70), randf_range(-50, 50))
	game.carried = {"gold": 12}
	await wait(1.0)
	await shot("desert_biome")
	# 6. the sector boss
	var boss = sm._bosses["se"]
	player.global_position = boss.global_position + Vector2(0, 90)
	await wait(2.2)
	await shot("boss_fight")
	# 7. run end with rewards, and the skill tree
	game.run_stats = {"kills": 64, "gold": 120, "waves": 9, "bosses": 1}
	game.sectors_unlocked = ["s", "se", "ne"]
	game.meta.shards = 60
	game.end_run("The keep has fallen")
	await wait(0.8)
	await shot("run_end_rewards")
	var ui = null
	for c in world.get_children():
		if c is CanvasLayer and c.get("skills") != null: ui = c
	ui.skills.open()
	await wait(0.6)
	await shot("skill_tree")
	ui.skills.root_ctl.visible = false
	ui.collection.open()
	await wait(0.6)
	await shot("card_collection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
