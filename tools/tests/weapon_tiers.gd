extends SceneTree
# Weapon tiers: tier 1 has attack + dash only; tier 2 unlocks the ability, tier 3 the
# ultimate; Forge awakenings add tiers (cost materials) and damage/cooldown bonuses.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = 500.0
	e.health = 500.0
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var info = world.get_node("Collectable").item_info
	player.position = Vector2(-40, 260)
	player.equip_item(info.items["spear"])
	await wait(0.4)
	var w = player.item
	print("spear tier ", w.tier, " ability unlocked ", w.ability_unlocked(), " ultimate unlocked ", w.ultimate_unlocked())
	w.use_ability()
	print("  tier 1 use_ability -> cooldown left ", w.ability_cd_left(), " (0 = nothing happened)")
	w.use_ultimate()
	print("  tier 1 use_ultimate -> cooldown left ", w.ult_cd_left(), " (0 = nothing happened)")
	w.use_dash()
	print("  dash works at tier 1 -> cooldown ", snapped(w.dash_cd_left(), 0.1))
	# combining copies: costs, tiers, cap
	game.resources = {"stone": 0, "stick": 0, "gold": 0}
	print("combine two spears without resources: result ", game.combine_weapons("spear", "spear"), " cost ", game.combine_cost("spear"), " affordable ", game.can_afford(game.combine_cost("spear")))
	var tier_walk := []
	var cur := "spear"
	for i in 6:
		var nxt: String = game.combine_weapons(cur, cur)
		tier_walk.append("%s -> %s" % [game.weapon_tier_of(cur), game.weapon_tier_of(nxt) if nxt != "" else "stop"])
		if nxt == "": break
		cur = nxt
	print("spear copies combined step by step (cap ", game.weapon_tier_cap(), " with no fusion tiers): ", tier_walk)
	print("different tiers cannot combine: ", game.combine_weapons("spear", "spear:1"), " | different weapons: ", game.combine_weapons("spear", "hammer"))
	# a copy with its own bonus: tier 3 spear
	player.equip_item(game.weapon_info("spear:2"))
	await wait(0.4)
	w = player.item
	print("spear:2 equipped: tier ", w.tier, " ability ", w.ability_unlocked(), " ultimate ", w.ultimate_unlocked(), " power ", load("res://items/weapons/weapon_util.gd").power, " attack cd ", snapped(w.attack_cooldown, 0.001))
	w.use_ability()
	print("  tier 3 ability cooldown now ", snapped(w.ability_cd_left(), 0.1))
	var d = dummy(world, player.global_position + Vector2(18, 0))
	player.equip_item(game.weapon_info("spear"))
	await wait(0.3)
	player.item.aim = Vector2.RIGHT
	var base_hp: float = d.health
	player.item.use_item()
	await wait(0.5)
	var dmg_base: float = base_hp - d.health
	player.equip_item(game.weapon_info("spear:3"))
	await wait(0.3)
	d.health = 500.0
	player.item.aim = Vector2.RIGHT
	player.item.use_item()
	await wait(0.5)
	print("spear attack damage: tier 1 = ", snapped(dmg_base, 0.1), "  bonus 3 copy = ", snapped(500.0 - d.health, 0.1))
	root.get_viewport().get_texture().get_image().save_png("user://weapon_tiers.png") if DisplayServer.get_name() != "headless" else null
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
