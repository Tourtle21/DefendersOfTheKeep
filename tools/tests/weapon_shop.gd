extends SceneTree
# Shard shop for weapons, fusion tiers and the starting weapon.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.shards = 5
	print("pool at start: ", game.weapon_pool())
	print("buy daggers with 5 shards (cost 24): ", game.buy_weapon("daggers"))
	game.meta.shards = 100
	print("buy daggers: ", game.buy_weapon("daggers"), " shards ", game.meta.shards, " pool ", game.weapon_pool())
	print("tier 2 unlocked: ", game.fusion_tier_unlocked(2), " tier 3: ", game.fusion_tier_unlocked(3))
	print("buy tier 4 before 3: ", game.buy_fusion_tier(4))
	print("buy tier 3: ", game.buy_fusion_tier(3), " tier 3 now ", game.fusion_tier_unlocked(3), " shards ", game.meta.shards)
	print("start options: ", game.start_weapon_options())
	game.meta.weapons.append("scimitar")
	game.set_start_weapon("scimitar")
	print("realm weapon as start weapon: ", game.meta.start_weapon, " in options ", "scimitar" in game.start_weapon_options())
	game.meta.weapons.erase("scimitar")
	game.meta.start_weapon = "sword"
	game.set_start_weapon("whip")
	print("whip not owned -> start weapon stays: ", game.meta.start_weapon)
	game.set_start_weapon("daggers")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	print("start pickup item: ", world.get_node("Collectable").item_type)
	# run end UI builds the shop without errors
	game.end_run("test")
	await wait(0.5)
	game.meta.start_weapon = "sword"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
