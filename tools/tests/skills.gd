extends SceneTree
# Skill tree: prerequisites, cost scaling, every bonus hooked into the game.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var skills = load("res://core/skills.gd")
	game.meta.skills = {}
	game.meta.shards = 1000
	print("skills in tree: ", skills.TREE.size())
	print("locked skill (spell_power needs mana_regen needs mana_pool): ", game.buy_skill("spell_power"))
	print("mana_pool: ", game.buy_skill("mana_pool"), " | spell_power still locked: ", game.buy_skill("spell_power"), " | mana_regen: ", game.buy_skill("mana_regen"), " | spell_power now: ", game.buy_skill("spell_power"))
	print("cost scaling mana_pool lvl1->2: ", game.skill_cost("mana_pool"), " (base 5, level 1 so 10)")
	# baseline vs max for each effect
	var base := {}
	base.fire_dmg = game.scaled("fireball", 1).damage
	base.fire_rad = game.scaled("fireball", 1).radius
	base.wall_hp = game.scaled("barricade", 1).hp
	base.sentry_life = game.scaled("sentry", 1).duration
	base.keep = game.keep_max()
	base.mana = game.max_mana()
	base.regen = game.mana_regen()
	base.draw = game.draw_interval()
	base.shards = game.shards_for_run()
	game.run_stats = {"kills": 40, "gold": 80, "waves": 10, "bosses": 1}
	var shards_base: int = game.shards_for_run()
	game.meta.skills = {}
	var order := []
	var progress := true
	while progress:
		progress = false
		for id in skills.TREE:
			if game.buy_skill(id):
				progress = true
	var maxed := 0
	for id in skills.TREE:
		if game.skill_level(id) == skills.TREE[id].max: maxed += 1
	print("all skills bought: ", maxed, "/", skills.TREE.size(), " maxed, shards left ", game.meta.shards)
	print("fireball damage ", base.fire_dmg, " -> ", game.scaled("fireball", 1).damage, " | radius ", base.fire_rad, " -> ", snapped(game.scaled("fireball", 1).radius, 0.1))
	print("barricade hp ", base.wall_hp, " -> ", game.scaled("barricade", 1).hp, " | sentry lifetime ", base.sentry_life, " -> ", game.scaled("sentry", 1).duration)
	print("keep max ", base.keep, " -> ", game.keep_max(), " | max mana ", base.mana, " -> ", game.max_mana(), " | regen ", base.regen, " -> ", game.mana_regen(), " | draw interval ", base.draw, " -> ", game.draw_interval())
	print("shards for the same run: ", shards_base, " (no skills) -> ", game.shards_for_run(), " (all skills)")
	game.start_run()
	print("new run resources ", game.resources, " keep ", game.keep_hp)
	game.keep_hp = 100.0
	game.damage_keep(10.0)
	print("keep took ", snapped(100.0 - game.keep_hp, 0.01), " from 10 damage (fortify)")
	# weapon + move speed
	var player = world.get_node("Player")
	var info = world.get_node("Collectable").item_info
	player.equip_item(info.items["spear"])
	await wait(0.4)
	print("weapon power ", load("res://items/weapons/weapon_util.gd").power, " attack cd ", snapped(player.item.attack_cooldown, 0.001), " ult cd ", snapped(player.item.ultimate_cooldown, 0.1))
	# screenshot of the tree
	game.meta.skills = {"mana_pool": 2, "mana_regen": 1, "weapon_dmg": 3, "gold_find": 1, "build_hp": 5}
	game.meta.shards = 37
	var ui = load("res://ui/base/skill_tree_ui.gd").new()
	world.add_child(ui)
	ui.open()
	await wait(0.5)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("user://skill_tree.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
